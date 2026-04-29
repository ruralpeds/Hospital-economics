"""
    test_mba_p1_bundle1.jl — Tests for MBA P1 Bundle 1

Covers:
  A-10  Working capital (CCC, target DSO, AR aging, scenarios)
  C-02  Stochastic Frontier Analysis (translog matrix, JLMS, efficiency ranking)
  C-05  TDABC (resource pools, time equations, encounter costing, unused capacity)
  D-01  Cox PH closure model (survival curves, risk tiers, portfolio risk)
  E-04  RHC AIR cap (CAA 2021 phase-in, payment calculation, projection)
"""

using Test
using Statistics

# ═════════════════════════════════════════════════════════════════════════════
# A-10: Working Capital
# ═════════════════════════════════════════════════════════════════════════════

@testset "A-10 Working Capital Optimization" begin

    base = WorkingCapitalInputs(
        net_patient_revenue       = 8_500_000.0,
        total_operating_expenses  = 8_262_000.0,
        cost_of_supplies          = 820_000.0,
        accounts_receivable_net   = 1_220_000.0,
        inventory                 = 185_000.0,
        accounts_payable          = 395_000.0,
        current_assets            = 2_100_000.0,
        current_liabilities       = 1_280_000.0,
        cash_and_investments      = 695_000.0,
    )

    @testset "compute_working_capital — DSO formula" begin
        m = compute_working_capital(base)
        expected_dso = 1_220_000.0 / (8_500_000.0 / 365.0)
        @test m.dso ≈ expected_dso atol=0.01
    end

    @testset "compute_working_capital — DIO formula" begin
        m = compute_working_capital(base)
        expected_dio = 185_000.0 / (820_000.0 / 365.0)
        @test m.dio ≈ expected_dio atol=0.01
    end

    @testset "compute_working_capital — CCC = DSO + DIO - DPO" begin
        m = compute_working_capital(base)
        @test m.ccc ≈ m.dso + m.dio - m.dpo atol=0.01
    end

    @testset "compute_working_capital — current ratio" begin
        m = compute_working_capital(base)
        @test m.current_ratio ≈ 2_100_000.0 / 1_280_000.0 atol=1e-4
    end

    @testset "compute_working_capital — quick ratio" begin
        m = compute_working_capital(base)
        expected_qr = (695_000.0 + 1_220_000.0) / 1_280_000.0
        @test m.quick_ratio ≈ expected_qr atol=1e-4
    end

    @testset "target_dso_model — AR reduction calculated" begin
        r = target_dso_model(
            net_patient_revenue = 8_500_000.0,
            current_dso = 52.4,
            target_dso  = 42.0,
        )
        daily_rev = 8_500_000.0 / 365.0
        expected_reduction = (52.4 - 42.0) * daily_rev
        @test r.ar_reduction_needed ≈ expected_reduction atol=1.0
        @test r.one_time_cash_benefit < r.ar_reduction_needed   # bad-debt haircut
        @test r.dso_improvement_days ≈ 10.4 atol=0.01
    end

    @testset "target_dso_model — annual interest savings positive" begin
        r = target_dso_model(
            net_patient_revenue = 8_500_000.0,
            current_dso = 55.0,
            target_dso  = 40.0,
        )
        @test r.annual_interest_savings > 0
        @test r.one_time_cash_benefit > 0
    end

    @testset "target_dso_model — no improvement when target >= current" begin
        r = target_dso_model(
            net_patient_revenue = 8_500_000.0,
            current_dso = 40.0,
            target_dso  = 55.0,
        )
        @test r.ar_reduction_needed == 0.0
    end

    @testset "ar_aging_analysis — buckets sum to gross AR" begin
        r = ar_aging_analysis(
            balance_0_30   = 620_000.0,
            balance_31_60  = 380_000.0,
            balance_61_90  = 150_000.0,
            balance_90_plus = 70_000.0,
        )
        @test r.total_gross_ar ≈ 620_000.0 + 380_000.0 + 150_000.0 + 70_000.0 atol=1.0
        @test length(r.buckets) == 4
    end

    @testset "ar_aging_analysis — net realizable ≤ gross AR" begin
        r = ar_aging_analysis(
            balance_0_30=500_000.0, balance_31_60=300_000.0,
            balance_61_90=100_000.0, balance_90_plus=80_000.0,
        )
        @test r.total_net_realizable < r.total_gross_ar
        @test r.total_bad_debt_provision ≈ r.total_gross_ar - r.total_net_realizable atol=1.0
    end

    @testset "ar_aging_analysis — action priority urgent if > 25% in 90+" begin
        r = ar_aging_analysis(
            balance_0_30=100_000.0, balance_31_60=80_000.0,
            balance_61_90=50_000.0, balance_90_plus=200_000.0,   # 46% > 90d
        )
        @test r.action_priority == :urgent
        @test r.pct_90_plus_days > 0.25
    end

    @testset "ar_aging_analysis — healthy when low 90+ balance" begin
        r = ar_aging_analysis(
            balance_0_30=700_000.0, balance_31_60=200_000.0,
            balance_61_90=50_000.0, balance_90_plus=30_000.0,   # 3% > 90d
        )
        @test r.action_priority == :healthy
    end

    @testset "working_capital_scenarios — DSO reduction frees AR" begin
        levers = [
            (label="AR Acceleration", dso_change=-8.0, dpo_change=0.0, inventory_change_pct=0.0),
        ]
        scenarios = working_capital_scenarios(base; levers=levers)
        @test length(scenarios) == 1
        @test scenarios[1].ar_cash_released > 0
        @test scenarios[1].ccc_improvement > 0
    end

    @testset "working_capital_scenarios — DPO extension frees AP cash" begin
        levers = [(label="Extend AP", dso_change=0.0, dpo_change=12.0, inventory_change_pct=0.0)]
        scenarios = working_capital_scenarios(base; levers=levers)
        @test scenarios[1].ap_cash_released > 0
    end

end  # A-10


# ═════════════════════════════════════════════════════════════════════════════
# C-02: Stochastic Frontier Analysis
# ═════════════════════════════════════════════════════════════════════════════

@testset "C-02 Stochastic Frontier Analysis" begin

    function sample_sfa_hospitals(n=10)
        # Generate synthetic panel with known efficiency variation
        rng = MersenneTwister(42)
        map(1:n) do i
            discharges = 400 + rand(rng, 1:800)
            ed_visits  = 2000 + rand(rng, 1:4000)
            # Efficient hospitals: lower cost given same outputs
            efficiency  = 0.7 + rand(rng) * 0.3
            true_cost   = discharges * 8000 + ed_visits * 400
            actual_cost = true_cost / efficiency + rand(rng, -50_000:50_000)
            SFAHospital(
                id           = "CAH-$(lpad(i, 3, '0'))",
                total_cost   = max(1_000_000.0, Float64(actual_cost)),
                outputs      = Dict(:discharges => Float64(discharges),
                                    :ed_visits  => Float64(ed_visits)),
                input_prices = Dict(:labour_price  => 48.0 + rand(rng) * 10,
                                    :capital_price => 1.5  + rand(rng) * 0.5),
                year         = 2023,
            )
        end
    end

    @testset "build_translog_matrix — correct dimensions" begin
        hospitals = sample_sfa_hospitals(8)
        X, y = build_translog_matrix(hospitals;
                   output_keys=[:discharges, :ed_visits],
                   price_keys=[:labour_price, :capital_price])
        n = length(hospitals)
        @test size(X, 1) == n
        @test length(y) == n
        @test size(X, 2) > 5   # intercept + 2 outputs + 2 prices + interactions
    end

    @testset "build_translog_matrix — first column is intercept" begin
        hospitals = sample_sfa_hospitals(8)
        X, _ = build_translog_matrix(hospitals;
                   output_keys=[:discharges], price_keys=[:labour_price])
        @test all(X[:,1] .== 1.0)
    end

    @testset "run_sfa — returns SFAAnalysis" begin
        hospitals = sample_sfa_hospitals(10)
        analysis = run_sfa(hospitals;
                           output_keys=[:discharges, :ed_visits],
                           price_keys=[:labour_price, :capital_price])
        @test analysis isa SFAAnalysis
        @test length(analysis.results) == 10
        @test analysis.n_observations == 10
    end

    @testset "run_sfa — efficiency scores in (0,1]" begin
        hospitals = sample_sfa_hospitals(12)
        analysis  = run_sfa(hospitals;
                            output_keys=[:discharges, :ed_visits],
                            price_keys=[:labour_price, :capital_price])
        for r in analysis.results
            @test 0.0 < r.efficiency_score <= 1.0 + 1e-6
        end
    end

    @testset "run_sfa — results sorted by efficiency descending" begin
        hospitals = sample_sfa_hospitals(10)
        analysis  = run_sfa(hospitals;
                            output_keys=[:discharges, :ed_visits],
                            price_keys=[:labour_price, :capital_price])
        scores = [r.efficiency_score for r in analysis.results]
        @test scores == sort(scores; rev=true)
    end

    @testset "run_sfa — excess cost + frontier cost = total cost" begin
        hospitals = sample_sfa_hospitals(10)
        analysis  = run_sfa(hospitals;
                            output_keys=[:discharges, :ed_visits],
                            price_keys=[:labour_price, :capital_price])
        for (r, h) in zip(analysis.results, hospitals[sortperm([r.efficiency_rank for r in analysis.results])])
            # Allow for rounding: frontier_cost + excess ≈ actual_cost
            @test r.frontier_cost_usd + r.excess_cost_usd ≈ h.total_cost atol=h.total_cost * 0.001
        end
    end

    @testset "run_sfa — lambda > 0" begin
        hospitals = sample_sfa_hospitals(12)
        analysis  = run_sfa(hospitals;
                            output_keys=[:discharges, :ed_visits],
                            price_keys=[:labour_price, :capital_price])
        @test analysis.lambda > 0
        @test analysis.sigma_u > 0
        @test analysis.sigma_v > 0
    end

    @testset "run_sfa — too few hospitals" begin
        @test_throws ArgumentError run_sfa(sample_sfa_hospitals(3))
    end

    @testset "jlms_efficiency — scores in (0,1]" begin
        residuals = randn(MersenneTwister(1), 50) .+ 0.2  # skewed positive
        result = jlms_efficiency(residuals)
        @test all(0.0 .< result.efficiency_scores .<= 1.0 + 1e-6)
        @test result.sigma_u > 0
        @test result.sigma_v > 0
        @test result.lambda > 0
    end

end  # C-02


# ═════════════════════════════════════════════════════════════════════════════
# C-05: TDABC
# ═════════════════════════════════════════════════════════════════════════════

@testset "C-05 Time-Driven Activity-Based Costing" begin

    function build_sample_model()
        model = TDABCModel()

        # Resource pools
        add_resource_pool!(model, ResourcePool(
            id=:med_surg, name="Med-Surg Nursing",
            total_annual_cost=1_200_000.0,
            total_capacity_minutes=365 * 8 * 60.0 * 12,  # 12 FTE × 8hr × 365d
        ))
        add_resource_pool!(model, ResourcePool(
            id=:ed, name="Emergency Department",
            total_annual_cost=850_000.0,
            total_capacity_minutes=365 * 24 * 60.0 * 4,  # 24/7 × 4 nurses
        ))

        # Time equations
        add_time_equation!(model, TimeEquation(
            activity_name = "nursing_assessment",
            resource_pool_id = :med_surg,
            base_minutes = 15.0,
            time_drivers = [(name="complex_case", coeff=8.0), (name="wound_care", coeff=5.0)],
        ))
        add_time_equation!(model, TimeEquation(
            activity_name = "medication_admin",
            resource_pool_id = :med_surg,
            base_minutes = 10.0,
            time_drivers = [(name="n_meds", coeff=2.5)],
        ))
        add_time_equation!(model, TimeEquation(
            activity_name = "ed_triage",
            resource_pool_id = :ed,
            base_minutes = 12.0,
            time_drivers = [(name="high_acuity", coeff=8.0)],
        ))
        model
    end

    @testset "ResourcePool — cost_per_minute calculated" begin
        pool = ResourcePool(id=:test, name="Test", total_annual_cost=500_000.0,
                            total_capacity_minutes=100_000.0)
        @test pool.cost_per_minute ≈ 500_000.0 / 100_000.0 atol=1e-6
    end

    @testset "ResourcePool — zero capacity raises error" begin
        @test_throws ArgumentError ResourcePool(
            id=:bad, name="Bad", total_annual_cost=100_000.0, total_capacity_minutes=0.0)
    end

    @testset "evaluate_time_equation — base only" begin
        eq = TimeEquation(activity_name="test", resource_pool_id=:x, base_minutes=20.0)
        @test evaluate_time_equation(eq, Dict{String,Float64}()) ≈ 20.0
    end

    @testset "evaluate_time_equation — with drivers" begin
        eq = TimeEquation(
            activity_name = "nursing_assessment",
            resource_pool_id = :med_surg,
            base_minutes = 15.0,
            time_drivers = [(name="complex_case", coeff=8.0)],
        )
        t = evaluate_time_equation(eq, Dict("complex_case" => 1.0))
        @test t ≈ 23.0 atol=0.01
    end

    @testset "evaluate_time_equation — missing drivers default to 0" begin
        eq = TimeEquation(
            activity_name = "test", resource_pool_id = :x, base_minutes = 10.0,
            time_drivers = [(name="optional_driver", coeff=5.0)],
        )
        @test evaluate_time_equation(eq, Dict{String,Float64}()) ≈ 10.0
    end

    @testset "cost_encounter — total cost positive" begin
        model = build_sample_model()
        enc = TDABCEncounter(
            id="IP-standard", encounter_type="Standard Inpatient",
            volume=200,
            activities=[
                (equation_id="nursing_assessment",
                 driver_values=Dict("complex_case"=>0.0, "wound_care"=>0.0)),
                (equation_id="medication_admin",
                 driver_values=Dict("n_meds"=>4.0)),
            ],
        )
        r = cost_encounter(model, enc; benchmark_ctc_cost=850.0)
        @test r.cost_per_encounter > 0
        @test r.total_annual_cost ≈ r.cost_per_encounter * 200 atol=1.0
    end

    @testset "cost_encounter — complex case costs more" begin
        model = build_sample_model()
        simple = TDABCEncounter(
            id="simple", encounter_type="Simple",
            volume=1,
            activities=[(equation_id="nursing_assessment",
                         driver_values=Dict("complex_case"=>0.0, "wound_care"=>0.0))],
        )
        complex = TDABCEncounter(
            id="complex", encounter_type="Complex",
            volume=1,
            activities=[(equation_id="nursing_assessment",
                         driver_values=Dict("complex_case"=>1.0, "wound_care"=>1.0))],
        )
        r_s = cost_encounter(model, simple)
        r_c = cost_encounter(model, complex)
        @test r_c.cost_per_encounter > r_s.cost_per_encounter
    end

    @testset "run_tdabc — sorted by total_annual_cost" begin
        model = build_sample_model()
        encounters = [
            TDABCEncounter(id="ED", encounter_type="ED Visit", volume=4_200,
                activities=[(equation_id="ed_triage", driver_values=Dict("high_acuity"=>0.3))]),
            TDABCEncounter(id="IP", encounter_type="Inpatient", volume=620,
                activities=[(equation_id="nursing_assessment",
                             driver_values=Dict("complex_case"=>0.4, "wound_care"=>0.1)),
                            (equation_id="medication_admin",
                             driver_values=Dict("n_meds"=>3.0))]),
        ]
        r = run_tdabc(model, encounters)
        costs = [enc.total_annual_cost for enc in r.results]
        @test costs == sort(costs; rev=true)
        @test r.total_costed_cost > 0
    end

    @testset "run_tdabc — unknown equation raises error" begin
        model = build_sample_model()
        enc = TDABCEncounter(
            id="bad", encounter_type="Bad",
            volume=1,
            activities=[(equation_id="nonexistent_eq", driver_values=Dict{String,Float64}())],
        )
        @test_throws ArgumentError cost_encounter(model, enc)
    end

end  # C-05


# ═════════════════════════════════════════════════════════════════════════════
# D-01: Cox PH Closure Model
# ═════════════════════════════════════════════════════════════════════════════

@testset "D-01 Cox PH Closure Hazard" begin

    healthy_hospital = ClosureRiskInputs(
        hospital_id              = "Healthy CAH",
        operating_margin         = 0.06,    # positive margin
        days_cash_on_hand        = 90.0,    # strong liquidity
        debt_to_cap              = 0.25,    # low debt
        rural_pop_decline_pct_pa = 0.3,
        is_cah                   = true,
        medicaid_pct             = 0.18,
        outpatient_pct           = 0.72,
    )

    distressed_hospital = ClosureRiskInputs(
        hospital_id              = "Distressed CAH",
        operating_margin         = -0.08,   # operating losses
        days_cash_on_hand        = 15.0,    # critically low cash
        debt_to_cap              = 0.72,    # high leverage
        rural_pop_decline_pct_pa = 2.5,     # population declining fast
        is_cah                   = false,   # no CAH protection
        medicaid_pct             = 0.38,    # high Medicaid
        outpatient_pct           = 0.45,
    )

    @testset "cox_ph_closure_risk — healthy hospital low risk" begin
        r = cox_ph_closure_risk(healthy_hospital)
        @test r.closure_prob_3yr < 0.10   # < 10% closure probability
        @test r.risk_tier in (:low, :moderate)
        @test r.hazard_ratio < 1.0   # below average hazard
    end

    @testset "cox_ph_closure_risk — distressed hospital elevated risk" begin
        r = cox_ph_closure_risk(distressed_hospital)
        @test r.closure_prob_3yr > 0.15   # > 15% closure probability
        @test r.risk_tier in (:elevated, :high)
        @test r.hazard_ratio > 1.0   # above average hazard
    end

    @testset "cox_ph_closure_risk — distressed worse than healthy" begin
        r_h = cox_ph_closure_risk(healthy_hospital)
        r_d = cox_ph_closure_risk(distressed_hospital)
        @test r_d.hazard_ratio > r_h.hazard_ratio
        @test r_d.closure_prob_3yr > r_h.closure_prob_3yr
        @test r_d.closure_prob_5yr > r_h.closure_prob_5yr
    end

    @testset "cox_ph_closure_risk — survival probabilities decrease over time" begin
        r = cox_ph_closure_risk(distressed_hospital)
        @test r.survival_1yr >= r.survival_3yr >= r.survival_5yr
        @test r.closure_prob_1yr <= r.closure_prob_3yr <= r.closure_prob_5yr
    end

    @testset "cox_ph_closure_risk — survival probabilities in [0,1]" begin
        for inputs in [healthy_hospital, distressed_hospital]
            r = cox_ph_closure_risk(inputs)
            @test 0.0 <= r.survival_1yr <= 1.0
            @test 0.0 <= r.survival_3yr <= 1.0
            @test 0.0 <= r.survival_5yr <= 1.0
            @test 0.0 <= r.closure_prob_3yr <= 1.0
        end
    end

    @testset "cox_ph_closure_risk — risk tier consistent with closure probability" begin
        r_h = cox_ph_closure_risk(healthy_hospital)
        @test (r_h.risk_tier == :low) == (r_h.closure_prob_3yr < 0.05)
    end

    @testset "cox_ph_closure_risk — dominant risk factors identified" begin
        r = cox_ph_closure_risk(distressed_hospital)
        @test !isempty(r.dominant_risk_factors)
        @test length(r.dominant_risk_factors) <= 3
    end

    @testset "cox_ph_closure_risk — CAH status protective" begin
        cah     = ClosureRiskInputs(; healthy_hospital..., is_cah=true)
        non_cah = ClosureRiskInputs(; healthy_hospital..., is_cah=false)
        r_cah     = cox_ph_closure_risk(cah)
        r_non_cah = cox_ph_closure_risk(non_cah)
        @test r_cah.hazard_ratio < r_non_cah.hazard_ratio
        @test r_cah.closure_prob_3yr < r_non_cah.closure_prob_3yr
    end

    @testset "cox_ph_portfolio_risk — aggregates correctly" begin
        portfolio = [healthy_hospital, distressed_hospital]
        result = cox_ph_portfolio_risk(portfolio)
        @test length(result.results) == 2
        # Sorted by closure_prob_3yr descending
        probs = [r.closure_prob_3yr for r in result.results]
        @test probs == sort(probs; rev=true)
        @test 0.0 <= result.mean_3yr_closure_prob <= 1.0
        @test result.system_survival_3yr <= minimum(probs -> 1.0-p, probs) + 1.0
    end

    @testset "RURAL_HOSPITAL_BASELINE_SURVIVAL — decreasing" begin
        keys_sorted = sort(collect(keys(RURAL_HOSPITAL_BASELINE_SURVIVAL)))
        vals = [RURAL_HOSPITAL_BASELINE_SURVIVAL[k] for k in keys_sorted]
        @test vals == sort(vals; rev=true)   # survival decreases over time
        @test RURAL_HOSPITAL_BASELINE_SURVIVAL[0] == 1.0
    end

end  # D-01


# ═════════════════════════════════════════════════════════════════════════════
# E-04: RHC AIR Cap & CAA 2021
# ═════════════════════════════════════════════════════════════════════════════

@testset "E-04 RHC AIR Cap & CAA 2021 Phase-In" begin

    @testset "CAA2021_PROVIDER_BASED_CAPS — all transition years defined" begin
        for yr in 2022:2028
            @test haskey(CAA2021_PROVIDER_BASED_CAPS, yr) "Missing cap for $yr"
        end
        # Caps should be increasing over the phase-in
        for yr in 2022:2027
            @test CAA2021_PROVIDER_BASED_CAPS[yr] < CAA2021_PROVIDER_BASED_CAPS[yr+1]
        end
    end

    @testset "INDEPENDENT_RHC_CAPS — defined for recent years" begin
        for yr in 2022:2025
            @test haskey(INDEPENDENT_RHC_CAPS, yr) "Missing cap for $yr"
        end
    end

    @testset "rhc_applicable_cap — provider-based uses phase-in" begin
        cap2022 = rhc_applicable_cap(provider_based, 2022)
        cap2025 = rhc_applicable_cap(provider_based, 2025)
        @test cap2022 ≈ 100.00 atol=0.01
        @test cap2025 ≈ 152.00 atol=0.01
        @test cap2025 > cap2022
    end

    @testset "rhc_applicable_cap — independent uses MEI-indexed cap" begin
        cap = rhc_applicable_cap(independent, 2025)
        @test cap ≈ INDEPENDENT_RHC_CAPS[2025] atol=0.01
    end

    @testset "rhc_applicable_cap — extrapolates beyond table" begin
        cap2030 = rhc_applicable_cap(provider_based, 2030)
        @test cap2030 > 0
        @test cap2030 > CAA2021_PROVIDER_BASED_CAPS[2028]
    end

    @testset "calculate_rhc_air_payment — basic provider-based CY2025" begin
        inputs = RHCAIRInputs(
            rhc_id                = "Valley RHC",
            rhc_type              = provider_based,
            calendar_year         = 2025,
            total_allowable_costs = 1_250_000.0,
            total_visits          = 6_800,
            medicare_visits       = 3_900,
        )
        r = calculate_rhc_air_payment(inputs)
        expected_air = 1_250_000.0 / 6_800.0
        @test r.calculated_air_per_visit ≈ expected_air atol=0.01
        @test r.applicable_cap ≈ 152.00 atol=0.01
        @test r.effective_rate_per_visit ≈ min(expected_air, 152.00) atol=0.01
    end

    @testset "calculate_rhc_air_payment — is_capped when AIR > cap" begin
        # High-cost clinic: AIR > cap
        inputs = RHCAIRInputs(
            rhc_id="High Cost", rhc_type=provider_based, calendar_year=2024,
            total_allowable_costs=2_000_000.0, total_visits=5_000,
            medicare_visits=3_000,
        )
        r = calculate_rhc_air_payment(inputs)
        @test r.calculated_air_per_visit > r.applicable_cap
        @test r.is_capped == true
        @test r.cap_impact_per_visit > 0
        @test r.annual_cap_impact > 0
    end

    @testset "calculate_rhc_air_payment — not capped when AIR < cap" begin
        # Low-cost clinic: AIR < cap
        inputs = RHCAIRInputs(
            rhc_id="Low Cost", rhc_type=provider_based, calendar_year=2025,
            total_allowable_costs=500_000.0, total_visits=5_000,
            medicare_visits=3_000,
        )
        r = calculate_rhc_air_payment(inputs)
        @test r.is_capped == false
        @test r.cap_impact_per_visit ≈ 0.0 atol=0.01
        @test r.effective_rate_per_visit ≈ r.calculated_air_per_visit atol=0.01
    end

    @testset "calculate_rhc_air_payment — Medicare payment = 80% rule" begin
        inputs = RHCAIRInputs(
            rhc_id="Test", rhc_type=independent, calendar_year=2025,
            total_allowable_costs=600_000.0, total_visits=4_000,
            medicare_visits=2_500,
        )
        r = calculate_rhc_air_payment(inputs)
        expected_payment = r.effective_rate_per_visit * 2_500 * 0.80
        @test r.medicare_payment ≈ expected_payment atol=0.01
    end

    @testset "calculate_rhc_air_payment — zero visits raises error" begin
        @test_throws ArgumentError calculate_rhc_air_payment(RHCAIRInputs(
            rhc_id="X", rhc_type=provider_based, calendar_year=2025,
            total_allowable_costs=500_000.0, total_visits=0, medicare_visits=0,
        ))
    end

    @testset "rhc_cap_projection — returns one result per year" begin
        inputs = RHCAIRInputs(
            rhc_id="Valley", rhc_type=provider_based, calendar_year=2022,
            total_allowable_costs=900_000.0, total_visits=5_500, medicare_visits=3_200,
        )
        results = rhc_cap_projection(inputs; years=2022:2028)
        @test length(results) == 7
        @test results[1].calendar_year == 2022
        @test results[end].calendar_year == 2028
    end

    @testset "rhc_cap_projection — caps increase over phase-in" begin
        inputs = RHCAIRInputs(
            rhc_id="X", rhc_type=provider_based, calendar_year=2022,
            total_allowable_costs=2_000_000.0, total_visits=8_000,
            medicare_visits=4_500,
        )
        results = rhc_cap_projection(inputs; years=2022:2026)
        caps = [r.applicable_cap for r in results]
        @test caps == sort(caps)   # caps increase over phase-in
    end

    @testset "rhc_caa2021_summary — renders without error" begin
        txt = rhc_caa2021_summary("Valley RHC", provider_based)
        @test contains(txt, "Valley RHC")
        @test contains(txt, "Provider-Based")
        @test contains(txt, "2022")
        @test contains(txt, "2028")
    end

end  # E-04

println("\n✅  P1 Bundle 1 (A-10/C-02/C-05/D-01/E-04) test suite complete.")
