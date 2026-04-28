# test/test_state_level_policy.jl
# Tests for StateLevelPolicySimulation module
# Phase 2.3: State-Level Population Health Policy Simulation Framework

using Test
using Statistics

include("../src/policy/StateLevelPolicySimulation.jl")
using .StateLevelPolicySimulation

@testset "StateLevelPolicySimulation Tests" begin

    # ──────────────────────────────────────────────────────────────────────────
    # Hospital struct
    # ──────────────────────────────────────────────────────────────────────────
    @testset "Hospital Construction" begin
        h = Hospital(id="H1", name="Test Hospital", beds=200, is_rural=false,
                     baseline_margin=0.05, baseline_volume=5000.0,
                     quality_score=0.90, cost_per_case=11_000.0)
        @test h.id == "H1"
        @test h.name == "Test Hospital"
        @test h.beds == 200
        @test !h.is_rural
        @test h.baseline_margin ≈ 0.05
        @test h.baseline_volume ≈ 5000.0
        @test h.quality_score ≈ 0.90
        @test h.cost_per_case ≈ 11_000.0

        # Keyword constructor defaults
        h_default = Hospital()
        @test h_default.beds == 100
        @test h_default.baseline_margin ≈ 0.04
        @test haskey(h_default.payer_mix, "Medicare")
        @test haskey(h_default.payer_mix, "Medicaid")
        @test haskey(h_default.payer_mix, "Commercial")
        @test haskey(h_default.payer_mix, "Uninsured")

        # Rural flag
        rural = Hospital(id="R1", is_rural=true)
        @test rural.is_rural

        # Custom payer mix
        h_mix = Hospital(id="H2", payer_mix=Dict("Medicare"=>0.50,"Medicaid"=>0.30,
                                                   "Commercial"=>0.15,"Uninsured"=>0.05))
        @test h_mix.payer_mix["Medicare"] ≈ 0.50
        @test h_mix.payer_mix["Uninsured"] ≈ 0.05
    end

    # ──────────────────────────────────────────────────────────────────────────
    # MedicaidExpansion policy type
    # ──────────────────────────────────────────────────────────────────────────
    @testset "MedicaidExpansion" begin
        policy = MedicaidExpansion(coverage_increase=0.15, payment_rate_multiplier=1.0,
                                   eligibility_age=65)
        @test policy isa PolicyIntervention
        @test policy.coverage_increase ≈ 0.15
        @test policy.payment_rate_multiplier ≈ 1.0
        @test policy.eligibility_age == 65

        # Defaults
        policy_default = MedicaidExpansion()
        @test policy_default.coverage_increase == 0.0
        @test policy_default.payment_rate_multiplier ≈ 1.0
        @test policy_default.eligibility_age == 65

        # Non-default rate multiplier (e.g., enhanced federal FMAP)
        policy_enhanced = MedicaidExpansion(coverage_increase=0.20,
                                            payment_rate_multiplier=1.05,
                                            eligibility_age=64)
        @test policy_enhanced.payment_rate_multiplier ≈ 1.05
        @test policy_enhanced.eligibility_age == 64

        # Subtype check
        @test MedicaidExpansion <: PolicyIntervention
    end

    # ──────────────────────────────────────────────────────────────────────────
    # HospitalRateSetting policy type
    # ──────────────────────────────────────────────────────────────────────────
    @testset "HospitalRateSetting" begin
        payers = Set(["Medicare", "Medicaid", "Commercial"])
        policy = HospitalRateSetting(target_margin=0.03, affected_payers=payers,
                                     adjustment_period=4)
        @test policy isa PolicyIntervention
        @test policy.target_margin ≈ 0.03
        @test "Medicare" in policy.affected_payers
        @test policy.adjustment_period == 4

        # Defaults
        default_rs = HospitalRateSetting()
        @test default_rs.target_margin ≈ 0.03
        @test isempty(default_rs.affected_payers)
        @test default_rs.adjustment_period == 3

        # Maryland-style all-payer
        md_policy = HospitalRateSetting(target_margin=0.02,
                                        affected_payers=Set(["Medicare","Medicaid","Commercial","Uninsured"]),
                                        adjustment_period=5)
        @test length(md_policy.affected_payers) == 4
        @test HospitalRateSetting <: PolicyIntervention
    end

    # ──────────────────────────────────────────────────────────────────────────
    # RuralHospitalSupport policy type
    # ──────────────────────────────────────────────────────────────────────────
    @testset "RuralHospitalSupport" begin
        criteria_fn = h -> h.is_rural
        policy = RuralHospitalSupport(supplemental_payment_per_bed=500.0,
                                      criteria=criteria_fn,
                                      funding_source="state")
        @test policy isa PolicyIntervention
        @test policy.supplemental_payment_per_bed ≈ 500.0
        @test policy.funding_source == "state"

        # criteria is callable
        rural_h = Hospital(id="R", is_rural=true)
        urban_h = Hospital(id="U", is_rural=false)
        @test policy.criteria(rural_h) == true
        @test policy.criteria(urban_h) == false

        # Defaults
        default_rhs = RuralHospitalSupport()
        @test default_rhs.supplemental_payment_per_bed == 0.0
        @test default_rhs.funding_source == "state"
        @test default_rhs.criteria(rural_h) == true

        # Federal funding
        fed_policy = RuralHospitalSupport(supplemental_payment_per_bed=1000.0,
                                          funding_source="federal")
        @test fed_policy.funding_source == "federal"
        @test RuralHospitalSupport <: PolicyIntervention
    end

    # ──────────────────────────────────────────────────────────────────────────
    # PayerMixShift policy type
    # ──────────────────────────────────────────────────────────────────────────
    @testset "PayerMixShift" begin
        policy = PayerMixShift(from_payer="Uninsured", to_payer="Medicaid",
                               volume_shift=0.50)
        @test policy isa PolicyIntervention
        @test policy.from_payer == "Uninsured"
        @test policy.to_payer == "Medicaid"
        @test policy.volume_shift ≈ 0.50

        # Defaults
        default_pms = PayerMixShift()
        @test default_pms.from_payer == ""
        @test default_pms.volume_shift == 0.0

        # Medicare -> Commercial shift (price transparency scenario)
        pt_policy = PayerMixShift(from_payer="Medicare", to_payer="Commercial",
                                   volume_shift=0.05)
        @test pt_policy.from_payer == "Medicare"
        @test PayerMixShift <: PolicyIntervention
    end

    # ──────────────────────────────────────────────────────────────────────────
    # StateHealthcareSystem
    # ──────────────────────────────────────────────────────────────────────────
    @testset "StateHealthcareSystem Construction" begin
        hospitals = [
            Hospital(id="H1", beds=300),
            Hospital(id="H2", beds=100, is_rural=true),
        ]
        state = StateHealthcareSystem(
            hospitals=hospitals,
            state_population=2_000_000,
            payer_mix=Dict("Medicare"=>0.20,"Medicaid"=>0.25,
                           "Commercial"=>0.45,"Uninsured"=>0.10),
        )
        @test length(state.hospitals) == 2
        @test state.state_population == 2_000_000
        @test state.payer_mix["Medicare"] ≈ 0.20
        @test state.payer_mix["Uninsured"] ≈ 0.10

        # Defaults
        default_state = StateHealthcareSystem()
        @test isempty(default_state.hospitals)
        @test default_state.state_population == 1_000_000
        @test haskey(default_state.payer_mix, "Medicaid")
        @test haskey(default_state.baseline_outcomes, "mortality_rate")
        @test haskey(default_state.baseline_utilization, "inpatient")

        # Check baseline outcomes populated
        state2 = StateHealthcareSystem(hospitals=hospitals)
        @test state2.baseline_outcomes["readmission_rate"] ≈ 0.15
    end

    # ──────────────────────────────────────────────────────────────────────────
    # simulate_policy_intervention! — MedicaidExpansion
    # ──────────────────────────────────────────────────────────────────────────
    @testset "Simulate MedicaidExpansion" begin
        hospitals = [
            Hospital(id="H1", beds=300, is_rural=false,
                     payer_mix=Dict("Medicare"=>0.38,"Medicaid"=>0.22,
                                    "Commercial"=>0.30,"Uninsured"=>0.10),
                     baseline_margin=0.04, baseline_volume=10_000.0,
                     quality_score=0.85, cost_per_case=11_000.0),
            Hospital(id="H2", beds=80, is_rural=true,
                     payer_mix=Dict("Medicare"=>0.44,"Medicaid"=>0.28,
                                    "Commercial"=>0.16,"Uninsured"=>0.12),
                     baseline_margin=0.02, baseline_volume=2_000.0,
                     quality_score=0.78, cost_per_case=9_000.0),
        ]
        state = StateHealthcareSystem(
            hospitals=hospitals,
            state_population=3_000_000,
            payer_mix=Dict("Medicare"=>0.18,"Medicaid"=>0.22,
                           "Commercial"=>0.46,"Uninsured"=>0.14),
        )

        policy = MedicaidExpansion(coverage_increase=0.50,
                                   payment_rate_multiplier=1.0,
                                   eligibility_age=65)
        outcomes = simulate_policy_intervention!(state, policy, 3)

        # Basic structural tests
        @test outcomes.years == 3
        @test occursin("MedicaidExpansion", outcomes.policy_type)

        # Each hospital has baseline + 3 years of data
        @test length(outcomes.hospital_margins["H1"]) == 4
        @test length(outcomes.hospital_margins["H2"]) == 4

        # Baseline is recorded correctly
        @test outcomes.hospital_margins["H1"][1] ≈ 0.04
        @test outcomes.hospital_margins["H2"][1] ≈ 0.02

        # Coverage rate should increase over time
        @test outcomes.patient_access["coverage_rate"][end] >
              outcomes.patient_access["coverage_rate"][1]

        # Uninsured rate should decrease
        @test outcomes.patient_access["uninsured_rate"][end] <
              outcomes.patient_access["uninsured_rate"][1]

        # Medicaid rate should increase
        @test outcomes.patient_access["medicaid_rate"][end] >
              outcomes.patient_access["medicaid_rate"][1]

        # Access impact summary
        @test outcomes.access_impact["coverage_change"] > 0.0
        @test outcomes.access_impact["uninsured_reduction"] > 0.0

        # Financial impact keys present
        @test haskey(outcomes.financial_impact, "baseline_avg_margin")
        @test haskey(outcomes.financial_impact, "final_avg_margin")
        @test haskey(outcomes.financial_impact, "hospital_closures")

        # total_cost vector: year 0 through year 3
        @test length(outcomes.total_cost) == 4

        # No closures for healthy hospitals under expansion
        @test isempty(outcomes.hospital_closures)
    end

    # ──────────────────────────────────────────────────────────────────────────
    # simulate_policy_intervention! — HospitalRateSetting
    # ──────────────────────────────────────────────────────────────────────────
    @testset "Simulate HospitalRateSetting" begin
        hospitals = [
            Hospital(id="H1", beds=400,
                     payer_mix=Dict("Medicare"=>0.40,"Medicaid"=>0.20,
                                    "Commercial"=>0.30,"Uninsured"=>0.10),
                     baseline_margin=0.06, baseline_volume=15_000.0,
                     quality_score=0.87, cost_per_case=12_000.0),
        ]
        state = StateHealthcareSystem(hospitals=hospitals, state_population=1_500_000)

        # Target margin below current → margins should move toward target
        policy = HospitalRateSetting(target_margin=0.03,
                                     affected_payers=Set(["Medicare","Medicaid","Commercial"]),
                                     adjustment_period=3)
        outcomes = simulate_policy_intervention!(state, policy, 3)

        @test outcomes.years == 3
        @test length(outcomes.hospital_margins["H1"]) == 4

        # Margin should move toward 0.03 from 0.06
        baseline_m  = outcomes.hospital_margins["H1"][1]
        year3_m     = outcomes.hospital_margins["H1"][4]
        # At full phase-in (year 3 / period 3 = 1.0), margin should be at target
        @test year3_m < baseline_m || isapprox(year3_m, 0.03, atol=0.01)

        # Quality metrics present
        @test haskey(outcomes.quality_metrics, "H1")

        # Financial impact
        @test haskey(outcomes.financial_impact, "margin_change")

        # Access rates unchanged (rate-setting doesn't affect coverage)
        @test outcomes.patient_access["coverage_rate"][1] ≈
              outcomes.patient_access["coverage_rate"][end]
    end

    # ──────────────────────────────────────────────────────────────────────────
    # simulate_policy_intervention! — RuralHospitalSupport
    # ──────────────────────────────────────────────────────────────────────────
    @testset "Simulate RuralHospitalSupport" begin
        rural = Hospital(id="R1", beds=60, is_rural=true,
                         payer_mix=Dict("Medicare"=>0.50,"Medicaid"=>0.30,
                                        "Commercial"=>0.12,"Uninsured"=>0.08),
                         baseline_margin=0.005, baseline_volume=800.0,
                         quality_score=0.74, cost_per_case=8_500.0)
        urban = Hospital(id="U1", beds=300, is_rural=false,
                         payer_mix=Dict("Medicare"=>0.35,"Medicaid"=>0.20,
                                        "Commercial"=>0.38,"Uninsured"=>0.07),
                         baseline_margin=0.05, baseline_volume=12_000.0,
                         quality_score=0.88, cost_per_case=11_000.0)
        state = StateHealthcareSystem(hospitals=[rural, urban], state_population=500_000)

        policy = RuralHospitalSupport(supplemental_payment_per_bed=2_000.0,
                                      criteria=h -> h.is_rural,
                                      funding_source="state")
        outcomes = simulate_policy_intervention!(state, policy, 3)

        @test outcomes.years == 3

        # Rural hospital margin should improve
        rural_margins = outcomes.hospital_margins["R1"]
        @test length(rural_margins) == 4
        @test rural_margins[end] > rural_margins[1]

        # Urban hospital margin should be largely unchanged
        urban_margins = outcomes.hospital_margins["U1"]
        @test isapprox(urban_margins[end], urban_margins[1], atol=0.01)

        # Rural access score should be 1.0 (no closures)
        @test outcomes.equity_metrics["rural_access_score"][end] ≈ 1.0

        # No closures
        @test isempty(outcomes.hospital_closures)

        # Quality should improve for rural hospital
        @test outcomes.quality_metrics["R1"][end] >= outcomes.quality_metrics["R1"][1]
    end

    # ──────────────────────────────────────────────────────────────────────────
    # simulate_policy_intervention! — PayerMixShift
    # ──────────────────────────────────────────────────────────────────────────
    @testset "Simulate PayerMixShift" begin
        # Hospital with significant uninsured population
        hospital = Hospital(id="H1", beds=250,
                            payer_mix=Dict("Medicare"=>0.35,"Medicaid"=>0.20,
                                           "Commercial"=>0.25,"Uninsured"=>0.20),
                            baseline_margin=0.02, baseline_volume=8_000.0,
                            quality_score=0.80, cost_per_case=10_000.0)
        state = StateHealthcareSystem(
            hospitals=[hospital],
            state_population=1_000_000,
            payer_mix=Dict("Medicare"=>0.18,"Medicaid"=>0.22,
                           "Commercial"=>0.40,"Uninsured"=>0.20),
        )

        # Shift 50% of uninsured to Medicaid (e.g., via outreach/enrollment)
        policy = PayerMixShift(from_payer="Uninsured", to_payer="Medicaid",
                               volume_shift=0.50)
        outcomes = simulate_policy_intervention!(state, policy, 3)

        @test outcomes.years == 3
        @test length(outcomes.hospital_margins["H1"]) == 4

        # Margin should improve because Medicaid pays better than Uninsured
        @test outcomes.hospital_margins["H1"][end] > outcomes.hospital_margins["H1"][1]

        # Structural completeness
        @test haskey(outcomes.access_impact, "coverage_change")
        @test haskey(outcomes.equity_metrics, "rural_access_score")

        # PayerMixShift from Uninsured should reduce state-level uninsured rate
        @test outcomes.patient_access["uninsured_rate"][end] <=
              outcomes.patient_access["uninsured_rate"][1]
    end

    # ──────────────────────────────────────────────────────────────────────────
    # Quality metric tracking
    # ──────────────────────────────────────────────────────────────────────────
    @testset "Quality Metric Tracking" begin
        hospital = Hospital(id="H1", beds=200, is_rural=false,
                            payer_mix=Dict("Medicare"=>0.40,"Medicaid"=>0.20,
                                           "Commercial"=>0.30,"Uninsured"=>0.10),
                            baseline_margin=0.04, baseline_volume=5_000.0,
                            quality_score=0.85, cost_per_case=10_500.0)
        state = StateHealthcareSystem(hospitals=[hospital], state_population=800_000)

        # Medicaid expansion should slightly improve quality
        policy = MedicaidExpansion(coverage_increase=0.30, payment_rate_multiplier=1.0)
        outcomes = simulate_policy_intervention!(state, policy, 3)

        @test haskey(outcomes.quality_metrics, "H1")
        @test length(outcomes.quality_metrics["H1"]) == 4
        @test outcomes.quality_metrics["H1"][1] ≈ 0.85
        # Quality clamped to [0, 1]
        @test all(0.0 .<= outcomes.quality_metrics["H1"] .<= 1.0)
    end

    # ──────────────────────────────────────────────────────────────────────────
    # Hospital closure detection
    # ──────────────────────────────────────────────────────────────────────────
    @testset "Hospital Closure Detection" begin
        # A very marginal rural hospital with a high-shift payer-mix policy
        marginal = Hospital(id="R_MARGINAL", beds=30, is_rural=true,
                            payer_mix=Dict("Medicare"=>0.50,"Medicaid"=>0.35,
                                           "Commercial"=>0.10,"Uninsured"=>0.05),
                            baseline_margin=-0.03,   # already near closure
                            baseline_volume=400.0,
                            quality_score=0.70, cost_per_case=8_000.0)
        state = StateHealthcareSystem(hospitals=[marginal], state_population=100_000)

        # A rate-setting policy that drives margin further negative
        policy = HospitalRateSetting(target_margin=-0.10,
                                     affected_payers=Set(["Medicare","Medicaid"]),
                                     adjustment_period=1)
        outcomes = simulate_policy_intervention!(state, policy, 2)

        # Closure should be detected
        @test "R_MARGINAL" in outcomes.hospital_closures

        # Rural access score should fall below 1.0
        @test outcomes.equity_metrics["rural_access_score"][end] < 1.0
    end

    # ──────────────────────────────────────────────────────────────────────────
    # Equity metrics
    # ──────────────────────────────────────────────────────────────────────────
    @testset "Equity Metrics" begin
        hospitals = [
            Hospital(id="R1", beds=60, is_rural=true, baseline_margin=0.02,
                     payer_mix=Dict("Medicare"=>0.45,"Medicaid"=>0.30,
                                    "Commercial"=>0.15,"Uninsured"=>0.10)),
            Hospital(id="U1", beds=300, is_rural=false, baseline_margin=0.05,
                     payer_mix=Dict("Medicare"=>0.35,"Medicaid"=>0.20,
                                    "Commercial"=>0.38,"Uninsured"=>0.07)),
        ]
        state = StateHealthcareSystem(hospitals=hospitals, state_population=600_000)

        policy = MedicaidExpansion(coverage_increase=0.40)
        outcomes = simulate_policy_intervention!(state, policy, 3)

        # Equity metrics populated for all years
        @test length(outcomes.equity_metrics["rural_access_score"]) == 4
        @test length(outcomes.equity_metrics["low_income_access_score"]) == 4

        # Low income score should improve with Medicaid expansion
        @test outcomes.equity_metrics["low_income_access_score"][end] >=
              outcomes.equity_metrics["low_income_access_score"][1]
    end

    # ──────────────────────────────────────────────────────────────────────────
    # analyze_policy_outcomes utility
    # ──────────────────────────────────────────────────────────────────────────
    @testset "analyze_policy_outcomes" begin
        hospital = Hospital(id="H1", beds=200,
                            payer_mix=Dict("Medicare"=>0.40,"Medicaid"=>0.20,
                                           "Commercial"=>0.30,"Uninsured"=>0.10),
                            baseline_margin=0.04, baseline_volume=5_000.0,
                            quality_score=0.85, cost_per_case=10_500.0)
        state = StateHealthcareSystem(hospitals=[hospital], state_population=800_000)

        policy = MedicaidExpansion(coverage_increase=0.20)
        outcomes = simulate_policy_intervention!(state, policy, 3)
        summary = analyze_policy_outcomes(outcomes)

        @test haskey(summary, "policy_type")
        @test haskey(summary, "years_simulated")
        @test haskey(summary, "hospitals_closed")
        @test haskey(summary, "coverage_improvement")
        @test haskey(summary, "uninsured_reduction")
        @test summary["years_simulated"] == 3
        @test summary["hospitals_closed"] == 0
        @test summary["coverage_improvement"] >= 0.0
    end

    # ──────────────────────────────────────────────────────────────────────────
    # compare_scenarios utility
    # ──────────────────────────────────────────────────────────────────────────
    @testset "compare_scenarios" begin
        hospital = Hospital(id="H1", beds=200,
                            payer_mix=Dict("Medicare"=>0.40,"Medicaid"=>0.20,
                                           "Commercial"=>0.30,"Uninsured"=>0.10),
                            baseline_margin=0.04, baseline_volume=5_000.0,
                            quality_score=0.85, cost_per_case=10_500.0)
        state = StateHealthcareSystem(hospitals=[hospital], state_population=800_000)

        policy_low  = MedicaidExpansion(coverage_increase=0.10)
        policy_high = MedicaidExpansion(coverage_increase=0.40)

        outcomes_low  = simulate_policy_intervention!(state, policy_low,  3)
        outcomes_high = simulate_policy_intervention!(state, policy_high, 3)
        diff = compare_scenarios(outcomes_low, outcomes_high)

        @test haskey(diff, "margin_difference")
        @test haskey(diff, "coverage_difference")
        @test haskey(diff, "closures_difference")
        # Higher expansion → more coverage
        @test diff["coverage_difference"] > 0.0
    end

    # ──────────────────────────────────────────────────────────────────────────
    # Kentucky Medicaid Expansion Scenario (validation)
    # ──────────────────────────────────────────────────────────────────────────
    @testset "Kentucky 2014 Medicaid Expansion Scenario" begin
        state, policy = kentucky_medicaid_expansion_scenario()

        # State configuration
        @test state.state_population == 4_395_000
        @test length(state.hospitals) == 4
        @test state.payer_mix["Uninsured"] ≈ 0.14

        # Policy configuration
        @test policy isa MedicaidExpansion
        @test policy.coverage_increase ≈ 0.57
        @test policy.eligibility_age == 65

        # Run 3-year simulation (2014–2016)
        outcomes = simulate_policy_intervention!(state, policy, 3)

        @test outcomes.years == 3

        # Uninsured rate should drop significantly (from ~14% toward ~6%)
        baseline_uninsured = outcomes.patient_access["uninsured_rate"][1]
        final_uninsured    = outcomes.patient_access["uninsured_rate"][end]
        @test final_uninsured < baseline_uninsured
        # Should be roughly halved after full expansion
        @test final_uninsured < baseline_uninsured * 0.75

        # Coverage rate should increase
        @test outcomes.patient_access["coverage_rate"][end] >
              outcomes.patient_access["coverage_rate"][1]

        # Both rural hospitals (KY_003, KY_004) should still be open
        @test "KY_003" ∉ outcomes.hospital_closures
        @test "KY_004" ∉ outcomes.hospital_closures

        # Rural access score should be maintained
        @test outcomes.equity_metrics["rural_access_score"][end] ≈ 1.0

        # All 4 hospitals tracked
        @test length(outcomes.hospital_margins) == 4

        # Access impact summary
        @test outcomes.access_impact["coverage_change"] > 0.0
        @test outcomes.access_impact["uninsured_reduction"] > 0.0
    end

    # ──────────────────────────────────────────────────────────────────────────
    # Edge cases
    # ──────────────────────────────────────────────────────────────────────────
    @testset "Edge Cases" begin
        # Zero years: only baseline recorded
        hospital = Hospital(id="H1", baseline_margin=0.04)
        state = StateHealthcareSystem(hospitals=[hospital], state_population=500_000)
        policy = MedicaidExpansion(coverage_increase=0.10)
        outcomes = simulate_policy_intervention!(state, policy, 0)

        @test outcomes.years == 0
        @test length(outcomes.hospital_margins["H1"]) == 1
        @test length(outcomes.total_cost) == 1

        # Empty hospital list: no crash
        empty_state = StateHealthcareSystem()
        outcomes_empty = simulate_policy_intervention!(empty_state,
                                                       MedicaidExpansion(coverage_increase=0.10),
                                                       3)
        @test isempty(outcomes_empty.hospital_margins)
        @test length(outcomes_empty.total_cost) == 4

        # Zero coverage increase: no change in uninsured rate
        no_change_policy = MedicaidExpansion(coverage_increase=0.0)
        state2 = StateHealthcareSystem(hospitals=[Hospital(id="H2")],
                                       state_population=500_000)
        out2 = simulate_policy_intervention!(state2, no_change_policy, 2)
        @test out2.patient_access["uninsured_rate"][1] ≈
              out2.patient_access["uninsured_rate"][end]

        # RuralHospitalSupport with criteria that matches nothing
        no_match = RuralHospitalSupport(supplemental_payment_per_bed=1000.0,
                                        criteria=h -> false)
        out3 = simulate_policy_intervention!(state2, no_match, 2)
        @test !isempty(out3.hospital_margins)

        # Single year simulation
        out4 = simulate_policy_intervention!(state, policy, 1)
        @test out4.years == 1
        @test length(out4.hospital_margins["H1"]) == 2
    end

    # ──────────────────────────────────────────────────────────────────────────
    # All-Payer Rate Setting: margin convergence
    # ──────────────────────────────────────────────────────────────────────────
    @testset "All-Payer Rate Setting Convergence" begin
        # Two hospitals with different baseline margins → both converge toward target
        h_high = Hospital(id="HIGH", beds=400, baseline_margin=0.08,
                          payer_mix=Dict("Medicare"=>0.38,"Medicaid"=>0.20,
                                         "Commercial"=>0.35,"Uninsured"=>0.07))
        h_low  = Hospital(id="LOW",  beds=150, baseline_margin=0.01,
                          payer_mix=Dict("Medicare"=>0.45,"Medicaid"=>0.25,
                                         "Commercial"=>0.20,"Uninsured"=>0.10))
        state = StateHealthcareSystem(hospitals=[h_high, h_low], state_population=2_000_000)

        policy = HospitalRateSetting(target_margin=0.04,
                                     affected_payers=Set(["Medicare","Medicaid","Commercial"]),
                                     adjustment_period=4)
        outcomes = simulate_policy_intervention!(state, policy, 4)

        # HIGH margin hospital should fall toward 0.04
        @test outcomes.hospital_margins["HIGH"][end] <
              outcomes.hospital_margins["HIGH"][1]
        # LOW margin hospital should rise toward 0.04
        @test outcomes.hospital_margins["LOW"][end] >
              outcomes.hospital_margins["LOW"][1]
    end

    # ──────────────────────────────────────────────────────────────────────────
    # Multi-hospital network with mixed policy effects
    # ──────────────────────────────────────────────────────────────────────────
    @testset "Multi-Hospital Network" begin
        hospitals = [
            Hospital(id="U1", beds=500, is_rural=false,
                     payer_mix=Dict("Medicare"=>0.35,"Medicaid"=>0.20,
                                    "Commercial"=>0.38,"Uninsured"=>0.07),
                     baseline_margin=0.06, baseline_volume=20_000.0,
                     quality_score=0.90, cost_per_case=13_000.0),
            Hospital(id="U2", beds=300, is_rural=false,
                     payer_mix=Dict("Medicare"=>0.38,"Medicaid"=>0.22,
                                    "Commercial"=>0.33,"Uninsured"=>0.07),
                     baseline_margin=0.04, baseline_volume=10_000.0,
                     quality_score=0.85, cost_per_case=11_500.0),
            Hospital(id="R1", beds=80, is_rural=true,
                     payer_mix=Dict("Medicare"=>0.45,"Medicaid"=>0.28,
                                    "Commercial"=>0.18,"Uninsured"=>0.09),
                     baseline_margin=0.015, baseline_volume=2_500.0,
                     quality_score=0.77, cost_per_case=9_000.0),
            Hospital(id="R2", beds=40, is_rural=true,
                     payer_mix=Dict("Medicare"=>0.48,"Medicaid"=>0.30,
                                    "Commercial"=>0.12,"Uninsured"=>0.10),
                     baseline_margin=0.008, baseline_volume=900.0,
                     quality_score=0.72, cost_per_case=8_500.0),
        ]
        state = StateHealthcareSystem(
            hospitals=hospitals,
            state_population=5_000_000,
            payer_mix=Dict("Medicare"=>0.18,"Medicaid"=>0.23,
                           "Commercial"=>0.45,"Uninsured"=>0.14),
        )

        policy = MedicaidExpansion(coverage_increase=0.40, payment_rate_multiplier=1.0)
        outcomes = simulate_policy_intervention!(state, policy, 5)

        @test outcomes.years == 5
        @test length(outcomes.hospital_margins) == 4
        # All hospitals tracked (assuming none closed under expansion)
        for hid in ["U1", "U2", "R1", "R2"]
            @test haskey(outcomes.hospital_margins, hid)
            @test length(outcomes.hospital_margins[hid]) >= 2
        end
        # Financial impact summary populated
        @test outcomes.financial_impact["active_hospitals"] >= 0.0
        # Total cost vector has correct length
        @test length(outcomes.total_cost) == 6   # year 0 through year 5
    end

end  # @testset "StateLevelPolicySimulation Tests"
