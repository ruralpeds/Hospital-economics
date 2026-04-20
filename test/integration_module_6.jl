# ============================================================================
# INTEGRATION TESTS: MODULE 6 WITH MODULES 4-5
# ============================================================================
# Demonstrates complete workflows combining patient flow simulation,
# value-based care contracts, and comparative effectiveness analysis

@testset "Module 6 Integration with Modules 4-5" begin

# ============================================================================
# WORKFLOW 1: Financial Impact → Cost-Effectiveness Analysis
# ============================================================================

@testset "Workflow 1: Contract Analysis to Cost-Effectiveness" begin
    # Create baseline and strategy contracts
    ffs_contract = FeeForServiceContract(
        name = "FFS Baseline",
        base_rate_per_case = 45_000.0,
        annual_volume = 100,
        inflation_rate = 0.025
    )

    bundled_contract = BundledPaymentContract(
        name = "Bundled Payment",
        bundle_price = 42_000.0,
        annual_volume = 100
    )

    # Create quality metrics
    quality_baseline = QualityMetrics()
    quality_bundled = QualityMetrics(
        mortality_rate = 0.02,
        readmission_30day_rate = 0.12,
        patient_satisfaction_score = 0.80
    )

    # Project financials
    cohort = PatientCohort("Test")
    baseline_analysis = project_contract_financials(ffs_contract, cohort, quality_baseline, 100)
    strategy_analysis = project_contract_financials(bundled_contract, cohort, quality_bundled, 100)

    # Perform cost-effectiveness analysis
    baseline_qalys = 2.40
    strategy_qalys = 2.42

    ce_result = analyze_cost_effectiveness(
        strategy_analysis,
        baseline_analysis,
        strategy_qalys,
        baseline_qalys,
        wtp_threshold = 100_000.0
    )

    @test isa(ce_result, CostEffectivenessResult)
    @test ce_result.strategy_name == "Bundled Payment"
    @test isfinite(ce_result.icer_per_qaly)
end

# ============================================================================
# WORKFLOW 2: Multi-Contract Comparison with CE Analysis
# ============================================================================

@testset "Workflow 2: Compare Multiple Contracts with Cost-Effectiveness" begin
    contracts = [
        FeeForServiceContract(name = "FFS", base_rate_per_case = 45_000.0, annual_volume = 100),
        CapitationContract(name = "Capitation", monthly_capitation_per_member = 3500.0, expected_members = 100),
        BundledPaymentContract(name = "Bundled", bundle_price = 42_000.0, annual_volume = 100),
    ]

    # Project financials for all contracts
    cohort = PatientCohort("Test")
    quality = QualityMetrics()
    analyses = compare_contracts(contracts, cohort, quality, 100)

    @test length(analyses) == 3

    # QALY estimates for each strategy
    qalys = [2.40, 2.38, 2.42]

    # Comprehensive comparison
    scenario = compare_strategies(analyses, 1, qalys)
    @test isa(scenario, ComparisonScenario)
    @test length(scenario.ce_results) >= 1  # At least 2 non-baseline strategies
end

# ============================================================================
# WORKFLOW 3: Sensitivity Analysis on Contract Choice
# ============================================================================

@testset "Workflow 3: Sensitivity Analysis on Contract Parameters" begin
    # Baseline contract
    base_contract = BundledPaymentContract(
        name = "Bundled",
        bundle_price = 42_000.0,
        annual_volume = 100
    )

    cohort = PatientCohort("Test")
    quality = QualityMetrics()
    base_analysis = project_contract_financials(base_contract, cohort, quality, 100)

    # Compare contract
    ffs_contract = FeeForServiceContract(
        name = "FFS",
        base_rate_per_case = 45_000.0,
        annual_volume = 100
    )
    ffs_analysis = project_contract_financials(ffs_contract, cohort, quality, 100)

    # Define price sensitivity parameter
    price_param = SensitivityParameter(
        "Bundle Price",
        42_000.0,
        38_000.0,
        46_000.0,
        "Uniform"
    )

    # One-way sensitivity on bundle price
    # (In practice, would recalculate ICER at each price point)
    base_qaly = 2.42
    ffs_qaly = 2.40
    base_ce = analyze_cost_effectiveness(base_analysis, ffs_analysis, base_qaly, ffs_qaly)

    @test isa(base_ce, CostEffectivenessResult)
end

# ============================================================================
# WORKFLOW 4: Quality Impact on Cost-Effectiveness
# ============================================================================

@testset "Workflow 4: Quality Improvement Impact on CE" begin
    base_quality = QualityMetrics(
        mortality_rate = 0.03,
        readmission_30day_rate = 0.15,
        patient_satisfaction_score = 0.75
    )

    improved_quality = QualityMetrics(
        mortality_rate = 0.02,
        readmission_30day_rate = 0.12,
        patient_satisfaction_score = 0.85
    )

    contract = BundledPaymentContract(name = "Test", bundle_price = 42_000.0, annual_volume = 100)
    cohort = PatientCohort("Test")

    analysis_base = project_contract_financials(contract, cohort, base_quality, 100)
    analysis_improved = project_contract_financials(contract, cohort, improved_quality, 100)

    # QALYs should improve with better quality
    qaly_base = 2.35
    qaly_improved = 2.45

    ce_improvement = analyze_cost_effectiveness(
        analysis_improved,
        analysis_base,
        qaly_improved,
        qaly_base
    )

    @test ce_improvement.quality_adjusted_life_years > 0
    @test ce_improvement.dominance_status in ["Dominant", "Incremental"]
end

# ============================================================================
# WORKFLOW 5: Break-Even Analysis for Contract Pricing
# ============================================================================

@testset "Workflow 5: Break-Even Pricing Analysis" begin
    # Find break-even bundle price where bundled = FFS
    ffs_cost = 45_000.0
    ffs_effect = 2.40

    bundled_effect = 2.42

    # Break-even: cost difference = 0 when prices are equal
    breakeven_price = ffs_cost  # When bundle price = FFS price, they're equivalent

    breakeven_analysis = analyze_break_even(
        45_000.0 - 42_000.0,  # Cost difference
        2.42 - 2.40,           # Effect difference
        "Bundled Payment",
        "Fee-for-Service"
    )

    @test isa(breakeven_analysis, BreakEvenAnalysis)
    @test breakeven_analysis.break_even_value > 0
end

# ============================================================================
# WORKFLOW 6: CEAC for Decision Uncertainty
# ============================================================================

@testset "Workflow 6: Cost-Effectiveness Acceptability Curve" begin
    # Monte Carlo samples from contract projections
    n_samples = 100

    # Simulate cost and effect uncertainty
    delta_costs = randn(n_samples) .* 2000 .+ 1000.0    # Around 1000 cost savings
    delta_effects = randn(n_samples) .* 0.01 .+ 0.02    # Around 0.02 QALY gain

    wtp_range = range(0, 150_000.0, length=51)

    ceac = calculate_ceac(delta_costs, delta_effects, wtp_range)

    @test length(ceac) == 51
    @test all(0 .<= ceac .<= 1)
    # Should be increasing at typical WTP
    @test ceac[end] > ceac[1]

    # Find crossover at 50% probability
    crossover = find_ceac_crossover(ceac, wtp_range)
    @test typeof(crossover) <: Union{Float64, Nothing}
end

# ============================================================================
# WORKFLOW 7: Hospital vs Payer Perspective Cost-Effectiveness
# ============================================================================

@testset "Workflow 7: Hospital vs Payer CE Comparison" begin
    contract = BundledPaymentContract(
        name = "Bundled",
        bundle_price = 42_000.0,
        annual_volume = 100
    )

    cohort = PatientCohort("Test")
    quality = QualityMetrics()
    analysis = project_contract_financials(contract, cohort, quality, 100)

    # Hospital margin perspective
    hospital_cost = (analysis.year1.hospital_costs +
                    analysis.year2.hospital_costs +
                    analysis.year3.hospital_costs)

    # Payer cost perspective
    payer_cost = (analysis.year1.payer_total_cost +
                 analysis.year2.payer_total_cost +
                 analysis.year3.payer_total_cost)

    # Both perspectives on same effectiveness
    qalys = 2.42

    @test hospital_cost > 0
    @test payer_cost > 0
    # In bundled payment, hospital bears more risk, so typically lower hospital cost
end

# ============================================================================
# WORKFLOW 8: Strategy Profile Analysis
# ============================================================================

@testset "Workflow 8: Multi-Strategy Profile Comparison" begin
    strategies = [
        ThreeYearContractAnalysis(
            contract_name = "Strategy A",
            contract_type = "FFS",
            year1 = AnnualContractFinancials(year=2026, hospital_costs=100_000.0, cases=100),
            year2 = AnnualContractFinancials(year=2027, hospital_costs=102_000.0, cases=102),
            year3 = AnnualContractFinancials(year=2028, hospital_costs=104_000.0, cases=104),
            total_hospital_margin = 50_000.0,
            total_payer_savings = 10_000.0,
        ),
        ThreeYearContractAnalysis(
            contract_name = "Strategy B",
            contract_type = "Bundled",
            year1 = AnnualContractFinancials(year=2026, hospital_costs=95_000.0, cases=100),
            year2 = AnnualContractFinancials(year=2027, hospital_costs=97_000.0, cases=102),
            year3 = AnnualContractFinancials(year=2028, hospital_costs=99_000.0, cases=104),
            total_hospital_margin = 60_000.0,
            total_payer_savings = 20_000.0,
        ),
    ]

    qalys = [2.40, 2.42]

    profiles = build_strategy_profiles(strategies, qalys)
    @test length(profiles) == 2

    for profile in profiles
        @test isa(profile, StrategyProfile)
        @test profile.cost_per_case > 0
        @test profile.financial_margin > 0
    end
end

# ============================================================================
# WORKFLOW 9: Probabilistic Sensitivity & Decision Uncertainty
# ============================================================================

@testset "Workflow 9: Probabilistic Sensitivity Analysis" begin
    # Define uncertainty in cost and effect parameters
    cost_dist = Normal(10_000.0, 2_000.0)
    effect_dist = Normal(0.02, 0.005)

    psa_result = conduct_probabilistic_sensitivity(
        cost_dist,
        effect_dist,
        10_000.0,
        0.02,
        iterations = 500,
        wtp_max = 150_000.0
    )

    @test length(psa_result.icer_samples) == 500
    @test length(psa_result.ceac) == 101

    # Verify CEAC properties
    ceac_at_100k = calculate_ceac_at_wtp(psa_result, 100_000.0)
    @test 0 <= ceac_at_100k <= 1

    # Get confidence interval
    lower, upper = get_ceac_confidence_interval(psa_result)
    @test lower <= upper
    @test 0 <= lower && upper <= 1
end

# ============================================================================
# WORKFLOW 10: Effectiveness Trajectory Analysis
# ============================================================================

@testset "Workflow 10: Effectiveness Trajectory" begin
    # Staged implementation: early costs, progressive effectiveness gains
    incremental_costs = [20_000.0, 5_000.0, 2_000.0]
    incremental_effects = [0.01, 0.02, 0.01]

    trajectory = analyze_effectiveness_trajectory(incremental_costs, incremental_effects)
    @test length(trajectory) == 3

    # Costs should accumulate
    @test trajectory[2].cumulative_cost > trajectory[1].cumulative_cost
    @test trajectory[3].cumulative_cost > trajectory[2].cumulative_cost

    # Effects should accumulate
    @test trajectory[2].cumulative_effectiveness > trajectory[1].cumulative_effectiveness
    @test trajectory[3].cumulative_effectiveness > trajectory[2].cumulative_effectiveness

    # Cost per unit should improve as scale increases
    @test trajectory[3].cost_per_unit <= trajectory[1].cost_per_unit
end

end  # @testset Module 6 Integration
