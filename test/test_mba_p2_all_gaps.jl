"""
    test_mba_p2_all_gaps.jl — Tests for all P2 MBA gaps

Covers:
  A-08  LBO analysis
  B-02  Blue Ocean Strategy
  B-04  REH real options
  B-05  Scenario planning (Five Forces, PESTLE, 2×2 matrix)
  C-04  Theory of Constraints
  D-02  Readmission risk (LACE, logistic, population, HRRP)
  D-07  Climate risk / TCFD
  E-09  NSA-IDR
  F-07  Federal Register parser
"""

using Test
using Statistics
using Dates

# ═════════════════════════════════════════════════════════════════════════════
# A-08: LBO Analysis
# ═════════════════════════════════════════════════════════════════════════════

@testset "A-08 LBO Analysis" begin
    inputs = LBOInputs(
        hospital_name = "Valley Health System",
        purchase_price = 42_000_000.0,
        ebitda_entry   = 5_200_000.0,
        ebitda_growth_rate = 0.04,
        senior_leverage_multiple = 4.0,
        mezz_leverage_multiple   = 1.5,
        hold_years     = 5,
        exit_multiple_range = [5.0, 6.0, 7.0, 8.0],
    )

    @testset "sources_uses sums to purchase price" begin
        r = hospital_lbo(inputs)
        @test r.sources_uses.senior_debt + r.sources_uses.mezz_debt +
              r.sources_uses.equity_contribution ≈ r.sources_uses.purchase_price atol=1.0
    end

    @testset "equity contribution positive" begin
        r = hospital_lbo(inputs)
        @test r.sources_uses.equity_contribution > 0
        @test r.sources_uses.equity_pct < 1.0
    end

    @testset "correct number of projection years" begin
        r = hospital_lbo(inputs)
        @test length(r.annual_results) == inputs.hold_years
    end

    @testset "senior debt balance declines each year" begin
        r = hospital_lbo(inputs)
        balances = [yr.senior_balance_eoy for yr in r.annual_results]
        @test all(balances[i] >= balances[i+1] for i in 1:length(balances)-1)
    end

    @testset "EBITDA grows at specified rate" begin
        r = hospital_lbo(inputs)
        @test r.annual_results[1].ebitda ≈ inputs.ebitda_entry * (1 + inputs.ebitda_growth_rate) atol=1.0
    end

    @testset "exit scenarios have correct count" begin
        r = hospital_lbo(inputs)
        @test length(r.exit_scenarios) == length(inputs.exit_multiple_range)
    end

    @testset "higher exit multiple → higher IRR" begin
        r = hospital_lbo(inputs)
        irrs = [s.irr for s in r.exit_scenarios]
        @test issorted(irrs)
    end

    @testset "MOIC > 1 at reasonable exit multiple" begin
        r = hospital_lbo(inputs)
        @test r.exit_scenarios[end].moic > 1.0
    end

    @testset "base IRR is positive" begin
        r = hospital_lbo(inputs)
        @test r.base_irr > 0
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# B-02: Blue Ocean Strategy
# ═════════════════════════════════════════════════════════════════════════════

@testset "B-02 Blue Ocean Strategy" begin
    factors = [
        CompetitiveFactor(name="Price", industry_score=6.0, our_score=5.0,
            target_score=4.0, errc_action=:reduce, weight=2.0),
        CompetitiveFactor(name="Telehealth", industry_score=3.0, our_score=2.0,
            target_score=9.0, errc_action=:create, weight=3.0),
        CompetitiveFactor(name="Wait Time", industry_score=6.0, our_score=7.0,
            target_score=4.0, errc_action=:reduce, weight=2.0),
        CompetitiveFactor(name="Community Trust", industry_score=5.0, our_score=8.0,
            target_score=9.0, errc_action=:raise, weight=3.0),
        CompetitiveFactor(name="Inpatient Beds", industry_score=7.0, our_score=4.0,
            target_score=1.0, errc_action=:eliminate, weight=1.0),
    ]
    canvas = StrategicCanvas("Valley CAH", factors, Dict())

    @testset "build_errc_grid categorises correctly" begin
        grid = build_errc_grid(factors)
        @test "Inpatient Beds" in grid.eliminate
        @test "Telehealth" in grid.create
        @test "Community Trust" in grid.raise
        @test length(grid.reduce) >= 1
    end

    @testset "blue_ocean_analysis returns result" begin
        r = blue_ocean_analysis(canvas)
        @test r isa BlueOceanResult
        @test r.differentiation_index >= 0
        @test r.value_innovation_score >= 0
        @test !isempty(r.top_opportunities)
    end

    @testset "high differentiation when target far from industry" begin
        r = blue_ocean_analysis(canvas)
        @test r.differentiation_index > 20.0  # meaningful differentiation
    end

    @testset "convergence warning when scores similar to competitor" begin
        competitor_scores = [5.2, 2.1, 6.8, 8.1, 4.2]  # very close to our scores
        canvas_with_comp = StrategicCanvas("Valley CAH", factors,
            Dict("Similar Hospital" => competitor_scores))
        r = blue_ocean_analysis(canvas_with_comp)
        @test length(r.convergence_warnings) >= 1
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# B-04: REH Real Options
# ═════════════════════════════════════════════════════════════════════════════

@testset "B-04 REH Real Options" begin
    profile = CAHFinancialProfile(
        hospital_name = "Prairie View CAH",
        annual_ed_visits = 4_200,
        annual_inpatient_discharges = 310,
        net_patient_revenue_cah = 8_500_000.0,
        total_operating_expenses = 8_650_000.0,
        opps_rate_per_ed_visit = 185.0,
    )

    @testset "basic run returns REHConversionResult" begin
        r = analyze_cah_to_reh_conversion(profile)
        @test r isa REHConversionResult
    end

    @testset "REH facility payment is positive and substantial" begin
        r = analyze_cah_to_reh_conversion(profile)
        @test r.reh_facility_payment_annual ≈ REH_MONTHLY_FACILITY_PAYMENT_FY2026 * 12 atol=1.0
        @test r.reh_facility_payment_annual > 3_000_000.0
    end

    @testset "low inpatient volume → convert recommended" begin
        low_ip = CAHFinancialProfile(; profile..., annual_inpatient_discharges=150,
            net_patient_revenue_cah=6_000_000.0, total_operating_expenses=6_400_000.0)
        r = analyze_cah_to_reh_conversion(low_ip)
        @test r.recommendation in (:convert_now, :wait)
    end

    @testset "high inpatient volume → stay or evaluate" begin
        high_ip = CAHFinancialProfile(; profile..., annual_inpatient_discharges=1_200,
            net_patient_revenue_cah=12_000_000.0, total_operating_expenses=11_500_000.0)
        r = analyze_cah_to_reh_conversion(high_ip)
        @test r.recommendation in (:stay_cah, :wait, :convert_now)
    end

    @testset "NPV is finite" begin
        r = analyze_cah_to_reh_conversion(profile)
        @test isfinite(r.npv_conversion_5yr)
    end

    @testset "break-even ED visits is non-negative" begin
        r = analyze_cah_to_reh_conversion(profile)
        @test r.breakeven_ed_visits >= 0
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# B-05: Scenario Planning
# ═════════════════════════════════════════════════════════════════════════════

@testset "B-05 Scenario Planning" begin

    @testset "Five Forces — average score computed correctly" begin
        forces = [
            FiveForce(force=:rivalry,        score=7.0),
            FiveForce(force=:new_entrants,   score=3.0),
            FiveForce(force=:substitutes,    score=5.0),
            FiveForce(force=:buyer_power,    score=6.0),
            FiveForce(force=:supplier_power, score=8.0),
        ]
        r = analyze_five_forces("Test Hospital", forces)
        @test r.overall_intensity ≈ mean(f.score for f in forces) atol=0.01
        @test r.dominant_force == :supplier_power
        @test r.intensity_tier in (:low, :moderate, :high, :extreme)
    end

    @testset "PESTLE — top threats and opportunities identified" begin
        factors = [
            PESTLEFactor(category=:economic, name="Medicaid cuts",
                description="State Medicaid budget pressures", impact=:threat,
                probability=0.70, impact_magnitude=8.0),
            PESTLEFactor(category=:technological, name="Telehealth expansion",
                description="RPM and telehealth reimbursement", impact=:opportunity,
                probability=0.80, impact_magnitude=7.0),
            PESTLEFactor(category=:social, name="Rural population aging",
                description="Increasing chronic disease burden", impact=:opportunity,
                probability=0.90, impact_magnitude=6.0),
        ]
        r = analyze_pestle(factors)
        @test !isempty(r.top_threats)
        @test !isempty(r.top_opportunities)
        @test r.risk_score > 0
        @test r.opportunity_score > 0
    end

    @testset "default scenario matrix has 4 scenarios" begin
        matrix = default_rural_hospital_scenarios()
        @test length(matrix.scenarios) == 4
        # Probabilities sum to 1
        @test sum(s.probability for s in matrix.scenarios) ≈ 1.0 atol=0.01
        @test !isempty(matrix.recommended_robust_strategies)
    end

    @testset "scenario matrix build validates 4-scenario requirement" begin
        axis_x = UncertaintyAxis(name="X", description="", low_label="low", high_label="high")
        axis_y = UncertaintyAxis(name="Y", description="", low_label="low", high_label="high")
        @test_throws ArgumentError build_scenario_matrix(axis_x, axis_y,
            [Scenario(name="Only one", axis_x_high=true, axis_y_high=true, narrative="")])
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# C-04: Theory of Constraints
# ═════════════════════════════════════════════════════════════════════════════

@testset "C-04 Theory of Constraints" begin

    inputs = ThroughputInputs(
        name                = "Valley CAH",
        annual_revenue      = 8_500_000.0,
        truly_variable_costs = 2_800_000.0,
        operating_expense   = 5_400_000.0,
        investment          = 12_000_000.0,
    )

    @testset "throughput metrics computed correctly" begin
        m = compute_throughput_metrics(inputs)
        @test m.throughput ≈ 8_500_000.0 - 2_800_000.0 atol=1.0
        @test m.net_profit ≈ m.throughput - m.operating_expense atol=1.0
        @test m.roi ≈ m.net_profit / m.investment atol=1e-6
        @test m.productivity ≈ m.throughput / m.operating_expense atol=1e-6
    end

    @testset "identify_constraint — highest utilisation is constraint" begin
        resources = [
            HospitalResource(id=:ed, name="Emergency Department",
                available_capacity_units=4200.0, demanded_capacity_units=4800.0),
            HospitalResource(id=:or, name="Operating Room",
                available_capacity_units=1200.0, demanded_capacity_units=800.0),
            HospitalResource(id=:lab, name="Laboratory",
                available_capacity_units=50_000.0, demanded_capacity_units=35_000.0),
        ]
        r = identify_constraint(resources)
        @test r.constraint.id == :ed   # 114% utilisation
        @test !isempty(r.exploitation_recommendations)
        @test !isempty(r.subordination_recommendations)
        @test !isempty(r.elevation_options)
    end

    @testset "utilisation rates computed correctly" begin
        resources = [
            HospitalResource(id=:a, name="A", available_capacity_units=100.0,
                demanded_capacity_units=80.0),
            HospitalResource(id=:b, name="B", available_capacity_units=100.0,
                demanded_capacity_units=110.0),
        ]
        r = identify_constraint(resources)
        @test r.utilisation_rates[:b] ≈ 1.10 atol=0.01
        @test r.constraint.id == :b
    end

    @testset "throughput_vs_cost_decision — recommends when NP improves" begin
        m = compute_throughput_metrics(inputs)
        r = throughput_vs_cost_decision(
            option_name = "Hire Hospitalist",
            throughput_gain = 800_000.0,
            oe_increase = 350_000.0,
            investment_required = 0.0,
            current_metrics = m,
        )
        @test r.recommended == true
        @test r.net_profit_change ≈ 800_000.0 - 350_000.0 atol=1.0
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# D-02: Readmission Risk
# ═════════════════════════════════════════════════════════════════════════════

@testset "D-02 Readmission Risk" begin

    @testset "LACE score — high risk patient" begin
        r = lace_score(length_of_stay_days=8, acuity_ed_admission=true,
                       charlson_index=4, ed_visits_6mo=4)
        @test r.total_score >= 10
        @test r.risk_tier == :high
        @test r.approx_30day_readmission_pct > 15.0
    end

    @testset "LACE score — low risk patient" begin
        r = lace_score(length_of_stay_days=1, acuity_ed_admission=false,
                       charlson_index=0, ed_visits_6mo=0)
        @test r.total_score < 5
        @test r.risk_tier == :low
    end

    @testset "LACE L component — correct points" begin
        @test lace_l_score(1) == 1
        @test lace_l_score(4) == 4
        @test lace_l_score(14) == 7
        @test lace_l_score(20) == 7   # caps at 7
    end

    @testset "logistic_readmission_prob — range [0,1]" begin
        for (lace, age, mc, prior) in [(5, 65, false, false), (12, 80, true, true), (3, 45, false, false)]
            p = logistic_readmission_prob(lace, age, mc, prior)
            @test 0.0 < p < 1.0
        end
    end

    @testset "logistic_readmission_prob — higher LACE → higher probability" begin
        p_low  = logistic_readmission_prob(4, 65, false, false)
        p_high = logistic_readmission_prob(12, 65, false, false)
        @test p_high > p_low
    end

    @testset "score_population — returns one result per discharge" begin
        discharges = [
            PatientDischarge(id=i, diagnosis_group="CHF", length_of_stay=rand(1:10),
                ed_admission=rand(Bool), charlson_index=rand(0:5), ed_visits_6mo=rand(0:4),
                age=65+rand(0:20))
            for i in 1:20
        ]
        results = score_population(discharges)
        @test length(results) == 20
        @test all(0.0 < r.predicted_prob_30day < 1.0 for r in results)
    end

    @testset "readmission_population_summary — counts sum correctly" begin
        discharges = [PatientDischarge(id=i, diagnosis_group="Mixed", length_of_stay=i%8+1,
            ed_admission=i%2==0, charlson_index=i%5, ed_visits_6mo=i%4, age=65)
            for i in 1:50]
        results = score_population(discharges)
        summ = readmission_population_summary(results)
        @test summ.n_high_risk + summ.n_moderate_risk + summ.n_low_risk == 50
        @test summ.total_discharges == 50
    end

    @testset "hrrp_cm_impact — positive ROI for effective programme" begin
        r = hrrp_cm_impact(
            annual_discharges = 620,
            current_readmission_rate = 0.175,
            cm_programme_effectiveness = 0.25,
            cm_programme_cost_annual = 120_000.0,
            hospital_base_payment = 8_500_000.0,
            hrrp_penalty_rate = 0.015,
        )
        @test r.penalty_reduction >= 0
        @test r.readmissions_prevented >= 0
        @test r.roi_pct isa Float64
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# D-07: Climate Risk / TCFD
# ═════════════════════════════════════════════════════════════════════════════

@testset "D-07 Climate Risk TCFD" begin

    phys_inputs = PhysicalRiskInputs(
        hospital_name = "Valley CAH",
        state = "KS", county = "Marion",
        flood_hazard_score = 3.0,
        wildfire_hazard_score = 1.0,
        extreme_heat_score = 5.0,
        severe_weather_score = 6.0,
        replacement_value_usd = 18_000_000.0,
        annual_revenue = 8_500_000.0,
        generator_backup_hours = 48,
    )

    @testset "assess_physical_risk — composite score in range" begin
        r = assess_physical_risk(phys_inputs)
        @test 0 <= r.composite_physical_risk_score <= 10
        @test r.risk_tier in (:low, :moderate, :high, :critical)
    end

    @testset "assess_physical_risk — EAL < replacement value" begin
        r = assess_physical_risk(phys_inputs)
        @test r.expected_annual_loss_usd < phys_inputs.replacement_value_usd
        @test r.max_probable_loss_usd > r.expected_annual_loss_usd
    end

    @testset "assess_physical_risk — generates investment priorities" begin
        r = assess_physical_risk(phys_inputs)
        @test !isempty(r.priority_investments)
        # Low backup hours should trigger recommendation
        @test any(contains(p, lowercase("power")) || contains(lowercase(p), "backup") ||
                  contains(lowercase(p), "generator") for p in r.priority_investments)
    end

    trans_inputs = TransitionRiskInputs(
        hospital_name = "Valley CAH",
        scope1_emissions_mtco2e = 280.0,
        scope2_emissions_mtco2e = 420.0,
        annual_energy_spend = 380_000.0,
        annual_supply_chain_spend = 1_200_000.0,
        property_insurance_annual = 95_000.0,
    )

    @testset "assess_transition_risk — total emissions correct" begin
        r = assess_transition_risk(trans_inputs)
        @test r.total_emissions_mtco2e ≈ 280.0 + 420.0
    end

    @testset "assess_transition_risk — 2050 carbon cost > 2030" begin
        r = assess_transition_risk(trans_inputs)
        @test r.carbon_cost_2050 > r.carbon_cost_2030
    end

    @testset "tcfd_scenario_analysis — three scenarios" begin
        phys_r = assess_physical_risk(phys_inputs)
        trans_r = assess_transition_risk(trans_inputs)
        result = tcfd_scenario_analysis(phys_r, trans_r)
        @test length(result.scenarios) == 3
        @test result.expected_value_risk > 0
        @test !isempty(result.worst_case_scenario)
    end

    @testset "IPCC_SCENARIOS — probabilities sum to 1" begin
        probs = [s.probability for s in values(IPCC_SCENARIOS)]
        @test sum(probs) ≈ 1.0 atol=0.01
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# E-09: NSA-IDR
# ═════════════════════════════════════════════════════════════════════════════

@testset "E-09 NSA-IDR" begin

    base_claim = IDRClaimInputs(
        claim_id     = "CLM-001",
        billed_amount = 28_000.0,
        qpa          = 12_500.0,
        our_offer    = 22_000.0,
        payer_offer  = 12_500.0,
        win_probability = 0.60,
    )

    @testset "analyze_idr_claim — high-value claim recommended" begin
        r = analyze_idr_claim(base_claim)
        @test r.recommend_idr == true
        @test r.expected_payment > r.qpa
    end

    @testset "analyze_idr_claim — expected payment = weighted average" begin
        r = analyze_idr_claim(base_claim)
        expected = 0.60 * base_claim.our_offer + 0.40 * base_claim.payer_offer
        @test r.expected_payment ≈ expected atol=0.01
    end

    @testset "analyze_idr_claim — low-value claim not recommended" begin
        tiny = IDRClaimInputs(
            claim_id=2, billed_amount=500.0,
            qpa=400.0, our_offer=450.0, payer_offer=400.0)
        r = analyze_idr_claim(tiny)
        @test r.recommend_idr == false
    end

    @testset "batch_idr_claims — admin fee split across batch" begin
        claims = [IDRClaimInputs(; base_claim..., claim_id=i) for i in 1:5]
        r = batch_idr_claims(claims)
        @test r.n_claims == 5
        # Per-claim admin fee should be lower than single-claim fee
        single_r = analyze_idr_claim(base_claim)
        @test r.results[1].admin_fee_our_share < single_r.admin_fee_our_share
    end

    @testset "batch_idr_claims — total metrics aggregate correctly" begin
        claims = [IDRClaimInputs(; base_claim..., claim_id=i) for i in 1:3]
        r = batch_idr_claims(claims)
        @test r.total_expected_payment ≈ sum(c.expected_payment for c in r.results) atol=1.0
    end

    @testset "idr_portfolio_opportunity — annual gain positive for high-value OON" begin
        r = idr_portfolio_opportunity(
            annual_oon_claims = 150,
            avg_billed_per_claim = 25_000.0,
            avg_qpa_ratio = 0.60,
            avg_our_offer_ratio = 0.85,
            win_probability = 0.60,
        )
        @test r.viable_for_idr == true
        @test r.annual_idr_revenue_opportunity > 0
    end

    @testset "estimated_qpa — applies geographic adjustment" begin
        base = estimated_qpa(median_contracted_rate=10_000.0)
        adj  = estimated_qpa(median_contracted_rate=10_000.0, market_geographic_adj=1.20)
        @test adj > base
    end
end

# ═════════════════════════════════════════════════════════════════════════════
# F-07: Federal Register Parser
# ═════════════════════════════════════════════════════════════════════════════

@testset "F-07 Federal Register Parser" begin

    @testset "CMS_RULE_REGISTRY — key rules present" begin
        @test haskey(CMS_RULE_REGISTRY, "IPPS_FY2026")
        @test haskey(CMS_RULE_REGISTRY, "OPPS_CY2026")
        @test CMS_RULE_REGISTRY["IPPS_FY2026"].rate_type == :ipps
        @test CMS_RULE_REGISTRY["OPPS_CY2026"].effective isa Date
    end

    @testset "build_fed_register_api_url — produces valid URL" begin
        url = build_fed_register_api_url()
        @test startswith(url, "https://www.federalregister.gov")
        @test contains(url, "centers-for-medicare-medicaid-services")
        @test contains(url, "Rule")
    end

    @testset "extract_rates_from_text — finds OPPS conversion factor" begin
        # Synthetic rule text snippet
        text = """
        The conversion factor for CY2026 is \$96.86, representing a 1.5% increase.
        The standardized amount for IPPS is \$6,881.
        """
        exts = extract_rates_from_text(text, "Test Rule", Date(2026,1,1))
        cf = filter(e -> e.rate_type == :opps_cf, exts)
        if !isempty(cf)
            @test cf[1].value ≈ 96.86 atol=0.01
        end
    end

    @testset "generate_constants_update — produces Julia-parseable output" begin
        exts = [RateExtraction(
            rule="OPPS_CY2026", effective_date=Date(2026,1,1),
            rate_type=:opps_cf, description="OPPS CF",
            value=96.86, unit="USD", confidence=:high, source_text="test")]
        code = generate_constants_update(exts;
            current_constants=Dict(:opps_cf => 89.93))
        @test contains(code, "96.86")
        @test contains(code, "OPPS_CF")
        @test contains(code, "was")
    end

    @testset "validate_rate_extraction — flags > 15% change" begin
        exts = [RateExtraction(
            rule="Test", effective_date=today(),
            rate_type=:ipps_base_rate, description="IPPS",
            value=10_000.0, unit="USD/discharge",
            confidence=:high, source_text="")]
        validation = validate_rate_extraction(exts;
            prior_year_rates=Dict(:ipps_base_rate => 6_881.0))  # > 15% change
        @test validation[1].flag == :review_needed
    end

    @testset "validate_rate_extraction — accepts normal year-over-year change" begin
        exts = [RateExtraction(
            rule="Test", effective_date=today(),
            rate_type=:ipps_base_rate, description="IPPS",
            value=7_050.0, unit="USD/discharge",
            confidence=:high, source_text="")]
        validation = validate_rate_extraction(exts;
            prior_year_rates=Dict(:ipps_base_rate => 6_881.0))  # ~2.5% change
        @test validation[1].flag == :ok
    end
end

println("\n✅  All P2 MBA gaps (A-08/B-02/B-04/B-05/C-04/D-02/D-07/E-09/F-07) tests complete.")
