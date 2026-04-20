# ============================================================================
# TESTS: COMPARATIVE EFFECTIVENESS ANALYSIS (Module 6)
# ============================================================================

@testset "Module 6: Comparative Effectiveness Analysis" begin

# ============================================================================
# COST-EFFECTIVENESS ANALYSIS TESTS
# ============================================================================

@testset "Cost-Effectiveness Calculations" begin
    # Test ICER calculation
    icer = calculate_icer(50_000.0, 40_000.0, 0.8, 0.75)
    @test icer ≈ 2_000_000.0

    # Test ICER with zero effectiveness
    icer_zero = calculate_icer(10_000.0, 0.0, 0.0, 0.0)
    @test isinf(icer_zero)

    # Test NMB calculation
    nmb = calculate_net_monetary_benefit(50_000.0, 40_000.0, 0.8, 0.75, 100_000.0)
    @test nmb ≈ (0.05 * 100_000.0) - 10_000.0

    # Test dominance classification
    dominance_dom = classify_dominance(30_000.0, 40_000.0, 0.8, 0.75)
    @test dominance_dom == "Dominant"

    dominance_dominated = classify_dominance(50_000.0, 40_000.0, 0.7, 0.75)
    @test dominance_dominated == "Dominated"
end

@testset "Cost-Effectiveness Result" begin
    # Create sample contracts
    contract1 = ThreeYearContractAnalysis(
        contract_name = "Contract 1",
        contract_type = "Fee-for-Service",
        year1 = AnnualContractFinancials(year=2026, hospital_costs=100_000.0),
        year2 = AnnualContractFinancials(year=2027, hospital_costs=102_000.0),
        year3 = AnnualContractFinancials(year=2028, hospital_costs=104_000.0),
        total_hospital_margin = 50_000.0,
        total_payer_savings = 10_000.0
    )

    contract2 = ThreeYearContractAnalysis(
        contract_name = "Contract 2",
        contract_type = "Bundled Payment",
        year1 = AnnualContractFinancials(year=2026, hospital_costs=95_000.0),
        year2 = AnnualContractFinancials(year=2027, hospital_costs=97_000.0),
        year3 = AnnualContractFinancials(year=2028, hospital_costs=99_000.0),
        total_hospital_margin = 60_000.0,
        total_payer_savings = 20_000.0
    )

    ce_result = analyze_cost_effectiveness(contract1, contract2, 2.4, 2.25)
    @test isa(ce_result, CostEffectivenessResult)
    @test ce_result.strategy_name == "Contract 1"
    @test ce_result.comparator_name == "Contract 2"
    @test isfinite(ce_result.icer_per_qaly)
end

# ============================================================================
# QALY CALCULATOR TESTS
# ============================================================================

@testset "Health State Utility" begin
    # Perfect health
    health_perfect = HealthState(0.0, 0.0, 0, false, 5)
    utility_perfect = get_utility_weight(health_perfect)
    @test utility_perfect ≈ 1.0

    # Moderate illness
    health_moderate = HealthState(0.05, 0.3, 2, false, 5)
    utility_moderate = get_utility_weight(health_moderate)
    @test utility_moderate > 0.3
    @test utility_moderate < 1.0

    # Severe illness
    health_severe = HealthState(0.2, 0.7, 5, true, 5)
    utility_severe = get_utility_weight(health_severe)
    @test utility_severe > 0.0
    @test utility_severe < utility_moderate
end

@testset "Diagnosis Utility Weights" begin
    # Acute MI utilities
    util_mi_moderate = get_utility_by_diagnosis("I21", "Moderate")
    @test util_mi_moderate ≈ 0.65

    util_mi_severe = get_utility_by_diagnosis("I21", "Severe")
    @test util_mi_severe ≈ 0.45

    # Default for unknown diagnosis
    util_unknown = get_utility_by_diagnosis("Z99", "Moderate")
    @test util_unknown ≈ 0.65
end

@testset "QALY Calculation" begin
    health_state = HealthState(0.05, 0.2, 1, false, 10)
    qaly_calc = calculate_qaly(health_state)

    @test isa(qaly_calc, QALYCalculation)
    @test qaly_calc.base_life_years > 0
    @test qaly_calc.utility_weight > 0
    @test qaly_calc.quality_adjusted_life_years > 0
    @test qaly_calc.quality_adjusted_life_years <= qaly_calc.base_life_years
end

@testset "Life Years Calculation" begin
    # No mortality: should get nearly 10 years
    ly_none = calculate_life_years(10, 0.0)
    @test ly_none ≈ 10.0

    # High mortality: should get fewer years
    ly_high = calculate_life_years(10, 0.5)
    @test ly_high < 5.0

    # Very high mortality
    ly_very_high = calculate_life_years(10, 1.0)
    @test ly_very_high ≈ 0.0
end

@testset "Cohort QALY Calculation" begin
    # Create sample cohort simulation result
    cohort_sim = CohortSimulationResult(
        cohort_name = "Test Cohort",
        n_simulations = 1,
        n_patients = 100,
        mean_cost = 50_000.0,
        mean_los = 5.0,
        mortality_rate = 0.05,
        readmission_30day_rate = 0.10,
        mean_quality_score = 0.75,
        cost_percentiles = Dict(0.5 => 50_000.0),
        los_percentiles = Dict(0.5 => 5.0),
        service_line_metrics = Dict()
    )

    diagnoses = ["I21", "J18"]
    total_qalys = calculate_cohort_qalys(cohort_sim, diagnoses, years_projected=10)
    @test total_qalys > 0
    @test total_qalys <= 100 * 10  # At most 100 patients × 10 years
end

# ============================================================================
# SENSITIVITY ANALYSIS TESTS
# ============================================================================

@testset "One-Way Sensitivity Analysis" begin
    param = SensitivityParameter(
        "Cost", 50_000.0, 40_000.0, 60_000.0, "Uniform"
    )

    # Define analysis function
    analysis_fn = (cost) -> cost / 0.8  # ICER proxy

    result = conduct_one_way_sensitivity(param, analysis_fn, steps=5)
    @test isa(result, OneWaySensitivityResult)
    @test length(result.results) == 5
    @test length(result.parameter_values) == 5
    @test result.parameter_name == "Cost"
end

@testset "Tornado Analysis" begin
    params = [
        SensitivityParameter("Cost", 50_000.0, 40_000.0, 60_000.0, "Uniform"),
        SensitivityParameter("Effect", 0.8, 0.7, 0.9, "Uniform"),
    ]

    analysis_fn = (x) -> abs(x - 50_000.0)  # Simple proxy

    impacts = tornado_analysis(params, analysis_fn)
    @test length(impacts) == 2
    # Should be sorted by impact (largest first)
    @test impacts[1][2] >= impacts[2][2]
end

@testset "Probabilistic Sensitivity Analysis" begin
    cost_dist = Normal(10_000.0, 2_000.0)
    effect_dist = Normal(0.05, 0.01)

    psa_result = conduct_probabilistic_sensitivity(
        cost_dist, effect_dist,
        10_000.0, 0.05,
        iterations=100,
        wtp_max=150_000.0
    )

    @test isa(psa_result, ProbabilisticSensitivityResult)
    @test psa_result.iterations == 100
    @test length(psa_result.icer_samples) == 100
    @test length(psa_result.ceac) == 101  # 0 to max in 101 steps
    @test all(0 .<= psa_result.ceac .<= 1)
end

# ============================================================================
# THRESHOLD ANALYSIS TESTS
# ============================================================================

@testset "Break-Even Analysis" begin
    be = analyze_break_even(10_000.0, 0.05, "Strategy A", "Strategy B")
    @test isa(be, BreakEvenAnalysis)
    @test be.break_even_value ≈ 200_000.0
end

@testset "WTP Threshold Evaluation" begin
    wtp_eval = evaluate_at_wtp_threshold(75_000.0, "Strategy X")
    @test isa(wtp_eval, WTPThreshold)
    @test wtp_eval.icer ≈ 75_000.0
    @test wtp_eval.cost_effectiveness
end

@testset "Optimal WTP Analysis" begin
    strategy_icers = Dict(
        "Strategy A" => 50_000.0,
        "Strategy B" => 75_000.0,
        "Strategy C" => 120_000.0,
    )

    optimal = find_optimal_wtp(strategy_icers)
    @test haskey(optimal, "low_wtp_preferred")
    @test optimal["low_wtp_preferred"] == "Strategy A"
end

@testset "CEAC Calculation" begin
    delta_costs = randn(100) .* 5000 .+ 10_000.0
    delta_effects = randn(100) .* 0.01 .+ 0.05
    wtp_range = range(0, 150_000.0, length=11)

    ceac = calculate_ceac(delta_costs, delta_effects, wtp_range)
    @test length(ceac) == 11
    @test all(0 .<= ceac .<= 1)
    # Should be increasing (higher WTP = more likely CE)
    @test ceac[end] >= ceac[1]
end

# ============================================================================
# COMPARATIVE EFFECTIVENESS INTEGRATION TESTS
# ============================================================================

@testset "Strategy Comparison Scenario" begin
    # Create sample strategies
    strategies = [
        ThreeYearContractAnalysis(
            contract_name = "Strategy A",
            contract_type = "Fee-for-Service",
            year1 = AnnualContractFinancials(year=2026, hospital_costs=100_000.0),
            year2 = AnnualContractFinancials(year=2027, hospital_costs=102_000.0),
            year3 = AnnualContractFinancials(year=2028, hospital_costs=104_000.0),
            total_hospital_margin = 50_000.0,
        ),
        ThreeYearContractAnalysis(
            contract_name = "Strategy B",
            contract_type = "Bundled Payment",
            year1 = AnnualContractFinancials(year=2026, hospital_costs=95_000.0),
            year2 = AnnualContractFinancials(year=2027, hospital_costs=97_000.0),
            year3 = AnnualContractFinancials(year=2028, hospital_costs=99_000.0),
            total_hospital_margin = 60_000.0,
        ),
    ]

    qalys = [2.4, 2.45]

    scenario = compare_strategies(strategies, 1, qalys)
    @test isa(scenario, ComparisonScenario)
    @test !isempty(scenario.ranking)
    @test !isempty(scenario.recommendations)
end

@testset "Strategy Profiles" begin
    strategies = [
        ThreeYearContractAnalysis(
            contract_name = "Contract A",
            contract_type = "FFS",
            year1 = AnnualContractFinancials(year=2026, hospital_costs=100_000.0, cases=100),
            year2 = AnnualContractFinancials(year=2027, hospital_costs=102_000.0, cases=102),
            year3 = AnnualContractFinancials(year=2028, hospital_costs=104_000.0, cases=104),
            total_hospital_margin = 50_000.0,
        ),
    ]

    qalys = [2.4]
    profiles = build_strategy_profiles(strategies, qalys)
    @test length(profiles) == 1
    @test isa(profiles[1], StrategyProfile)
    @test profiles[1].strategy_name == "Contract A"
end

end  # @testset Module 6
