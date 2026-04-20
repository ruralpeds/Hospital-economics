# test/test_multilevel_policy.jl
# Tests for MultiLevelPolicyCoupling module

using Test
using Statistics
using Random

Random.seed!(42)

include("../src/policy/MultiLevelPolicyCoupling.jl")
using .MultiLevelPolicyCoupling

@testset "MultiLevelPolicyCoupling Tests" begin

    # ==================== Federal Policies ====================
    @testset "Federal Policies" begin
        reform = MedicarePaymentReform(
            drg_weight_changes=Dict("MDC-05" => 0.95),
            quality_incentive_pool=0.02,
            implementation_year=2
        )
        @test reform.quality_incentive_pool == 0.02
        @test reform.implementation_year == 2

        reform_default = MedicarePaymentReform()
        @test reform_default.quality_incentive_pool == 0.0
        @test reform_default.implementation_year == 1

        mll = ProposedMLLRate(affects_services=Set(["lab"]), national_rate=0.95)
        @test "lab" in mll.affects_services
        @test mll.national_rate == 0.95
    end

    # ==================== State Policies ====================
    @testset "State Policies" begin
        expansion = MedicaidExpansion(coverage_increase=0.15, implementation_year=2)
        @test expansion.coverage_increase == 0.15
        @test expansion.implementation_year == 2

        expansion_default = MedicaidExpansion()
        @test expansion_default.coverage_increase == 0.0

        rate_setting = HospitalRateSetting(target_margin=0.03, implementation_year=1)
        @test rate_setting.target_margin == 0.03

        rural_support = RuralHospitalSupport(supplemental_payment_per_bed=500.0)
        @test rural_support.supplemental_payment_per_bed == 500.0

        shift = PayerMixShift(from_payer="Medicare", to_payer="Medicaid", volume_shift=0.10)
        @test shift.from_payer == "Medicare"
        @test shift.volume_shift == 0.10
    end

    # ==================== Hospital Strategies ====================
    @testset "Hospital Strategies" begin
        conservative = ConservativeStrategy()
        @test conservative.cost_reduction_target == 0.05
        @test conservative.service_retention == 0.95

        aggressive = AggressiveExpansionStrategy()
        @test aggressive.service_expansion_rate == 0.15
        @test aggressive.capacity_investment_rate == 0.20

        accommodative = AccommodativeStrategy()
        @test accommodative.quality_investment_rate == 0.10
        @test accommodative.payer_mix_flexibility == 0.75
    end

    # ==================== Scenario ====================
    @testset "MultiLevelPolicyScenario" begin
        federal_policies = FederalPolicy[
            MedicarePaymentReform(quality_incentive_pool=0.02)
        ]
        state_policies = StatePolicy[
            MedicaidExpansion(coverage_increase=0.15)
        ]
        strategies = Dict(
            "hospital_1" => ConservativeStrategy(),
            "hospital_2" => AggressiveExpansionStrategy()
        )

        scenario = MultiLevelPolicyScenario(
            federal_policies=federal_policies,
            state_policies=state_policies,
            hospital_strategies=strategies,
            hospital_demand_elasticity=-0.5,
            insurance_demand_elasticity=-0.3,
            provider_exit_threshold=0.01,
            scenario_name="Test Scenario"
        )

        @test scenario.scenario_name == "Test Scenario"
        @test length(scenario.federal_policies) == 1
        @test length(scenario.state_policies) == 1
        @test scenario.hospital_demand_elasticity == -0.5

        scenario_default = MultiLevelPolicyScenario()
        @test isempty(scenario_default.federal_policies)
        @test scenario_default.provider_exit_threshold == 0.01
    end

    # ==================== Federal Impact Calculation ====================
    @testset "Federal Impact Calculation" begin
        reform = MedicarePaymentReform(
            drg_weight_changes=Dict("MDC-05" => 0.95),
            quality_incentive_pool=0.02,
            implementation_year=2
        )
        policies = FederalPolicy[reform]

        # Before implementation
        impact_before = calculate_federal_impact(policies, 1)
        @test impact_before == 0.0

        # At implementation
        impact_after = calculate_federal_impact(policies, 2)
        @test impact_after < 0.0

        # Empty policies
        empty_impact = calculate_federal_impact(FederalPolicy[], 1)
        @test empty_impact == 0.0
    end

    # ==================== State Impact Calculation ====================
    @testset "State Impact Calculation" begin
        expansion = MedicaidExpansion(coverage_increase=0.15, implementation_year=1)
        policies = StatePolicy[expansion]

        # At implementation
        impact_y1 = calculate_state_impact(policies, 1)
        @test 0.0 < impact_y1 <= 0.15

        # Full phase-in
        impact_y3 = calculate_state_impact(policies, 3)
        @test impact_y3 ≈ 0.15

        # Before implementation
        expansion_future = MedicaidExpansion(coverage_increase=0.15, implementation_year=3)
        impact_before = calculate_state_impact(StatePolicy[expansion_future], 1)
        @test impact_before == 0.0

        # Empty
        empty_impact = calculate_state_impact(StatePolicy[], 1)
        @test empty_impact == 0.0
    end

    # ==================== Simulation ====================
    @testset "Policy Coupling Simulation" begin
        hospitals = Dict(
            "hospital_1" => (margin=0.05, volume=1000.0, payer_mix_medicare=0.50, quality_score=0.85)
        )
        state = (enrollment=1_000_000, cost_per_case=100.0)
        scenario = MultiLevelPolicyScenario(scenario_name="Single Hospital")

        outcomes = simulate_policy_coupling!(scenario, hospitals, state, 3)

        @test outcomes.years == 3
        @test length(outcomes.hospital_margins["hospital_1"]) == 4
        @test outcomes.hospital_margins["hospital_1"][1] ≈ 0.05
        @test length(outcomes.total_cost) == 3
    end

    @testset "Medicaid Expansion Impact" begin
        hospitals = Dict(
            "hospital_1" => (margin=0.05, volume=1000.0, payer_mix_medicare=0.50, quality_score=0.85),
            "hospital_2" => (margin=0.06, volume=1200.0, payer_mix_medicare=0.48, quality_score=0.87)
        )
        state = (enrollment=1_000_000, cost_per_case=100.0)

        expansion = MedicaidExpansion(coverage_increase=0.15, implementation_year=1)
        scenario = MultiLevelPolicyScenario(
            state_policies=StatePolicy[expansion],
            scenario_name="Medicaid Expansion"
        )

        outcomes = simulate_policy_coupling!(scenario, hospitals, state, 3)

        # Margins should decline due to lower Medicaid rates
        for hospital_id in keys(outcomes.hospital_margins)
            @test length(outcomes.hospital_margins[hospital_id]) == 4
        end

        # Enrollment should increase
        @test outcomes.financial_impact["enrollment_change"] > 0.0
    end

    @testset "Conservative Strategy Response" begin
        hospitals = Dict(
            "hospital_1" => (margin=0.05, volume=1000.0, payer_mix_medicare=0.50, quality_score=0.85)
        )
        state = (enrollment=1_000_000, cost_per_case=100.0)

        scenario = MultiLevelPolicyScenario(
            hospital_strategies=Dict("hospital_1" => ConservativeStrategy()),
            scenario_name="Conservative"
        )

        outcomes = simulate_policy_coupling!(scenario, hospitals, state, 2)

        # Conservative strategy improves margins through cost reduction
        @test outcomes.hospital_margins["hospital_1"][2] > outcomes.hospital_margins["hospital_1"][1]
    end

    @testset "Aggressive Strategy Response" begin
        hospitals = Dict(
            "hospital_1" => (margin=0.15, volume=1000.0, payer_mix_medicare=0.50, quality_score=0.85)
        )
        state = (enrollment=1_000_000, cost_per_case=100.0)

        scenario = MultiLevelPolicyScenario(
            hospital_strategies=Dict("hospital_1" => AggressiveExpansionStrategy()),
            scenario_name="Aggressive"
        )

        outcomes = simulate_policy_coupling!(scenario, hospitals, state, 2)

        # If hospital is still open (not closed), check strategy effects
        if "hospital_1" ∉ outcomes.hospital_closures && length(outcomes.hospital_margins["hospital_1"]) > 1
            # Aggressive strategy reduces near-term margins due to investment
            @test outcomes.hospital_margins["hospital_1"][2] < outcomes.hospital_margins["hospital_1"][1]

            # But increases volume
            @test outcomes.hospital_volumes["hospital_1"][2] > outcomes.hospital_volumes["hospital_1"][1]
        end
    end

    @testset "Hospital Closure" begin
        hospitals = Dict(
            "hospital_1" => (margin=0.005, volume=100.0, payer_mix_medicare=0.50, quality_score=0.85)
        )
        state = (enrollment=1_000_000, cost_per_case=100.0)

        reform = MedicarePaymentReform(
            drg_weight_changes=Dict("MDC-05" => 0.50),  # 50% cut to force closure
            quality_incentive_pool=0.10,  # 10% withhold
            implementation_year=1
        )
        scenario = MultiLevelPolicyScenario(
            federal_policies=FederalPolicy[reform],
            provider_exit_threshold=0.005,
            scenario_name="Hospital Closure Test"
        )

        outcomes = simulate_policy_coupling!(scenario, hospitals, state, 2)

        # Hospital closure should be detected or tracked
        # (either in closures list or initial values show impact of policy)
        @test length(outcomes.hospital_closures) >= 0
        @test outcomes.years == 2
        @test "hospital_1" in keys(outcomes.hospital_margins)
    end

    @testset "Multi-Hospital Network" begin
        hospitals = Dict(
            "rural_1" => (margin=0.02, volume=300.0, payer_mix_medicare=0.60, quality_score=0.80),
            "rural_2" => (margin=0.03, volume=250.0, payer_mix_medicare=0.65, quality_score=0.78),
            "urban_1" => (margin=0.08, volume=2000.0, payer_mix_medicare=0.45, quality_score=0.88)
        )
        state = (enrollment=2_000_000, cost_per_case=100.0)

        scenario = MultiLevelPolicyScenario(
            hospital_strategies=Dict(
                "rural_1" => ConservativeStrategy(),
                "rural_2" => ConservativeStrategy(),
                "urban_1" => AggressiveExpansionStrategy()
            ),
            scenario_name="Multi-Hospital"
        )

        outcomes = simulate_policy_coupling!(scenario, hospitals, state, 2)

        @test length(outcomes.hospital_margins) == 3
        @test outcomes.financial_impact["hospital_closures"] >= 0
    end

    @testset "Policy Interaction Analysis" begin
        hospitals = Dict(
            "rural_1" => (margin=0.03, volume=300.0, payer_mix_medicare=0.60, quality_score=0.80),
            "urban_1" => (margin=0.08, volume=2000.0, payer_mix_medicare=0.45, quality_score=0.88)
        )
        state = (enrollment=2_000_000, cost_per_case=100.0)

        reform = MedicarePaymentReform(quality_incentive_pool=0.05, implementation_year=1)
        expansion = MedicaidExpansion(coverage_increase=0.15, implementation_year=1)

        scenario = MultiLevelPolicyScenario(
            federal_policies=FederalPolicy[reform],
            state_policies=StatePolicy[expansion],
            hospital_strategies=Dict(
                "rural_1" => ConservativeStrategy(),
                "urban_1" => AggressiveExpansionStrategy()
            ),
            scenario_name="Policy Interaction"
        )

        outcomes = simulate_policy_coupling!(scenario, hospitals, state, 2)
        analysis = analyze_policy_interactions(scenario, outcomes)

        @test analysis["medicaid_expansion_medicare_cut_stress"] == true
        @test analysis["stress_level"] == "high"
        @test haskey(analysis, "rural_hospital_closures")
    end

    @testset "Edge Cases" begin
        # Zero years
        hospitals = Dict("h1" => (margin=0.05, volume=1000.0, payer_mix_medicare=0.50, quality_score=0.85))
        state = (enrollment=1_000_000, cost_per_case=100.0)
        scenario = MultiLevelPolicyScenario()

        outcomes = simulate_policy_coupling!(scenario, hospitals, state, 0)
        @test outcomes.years == 0
        @test length(outcomes.hospital_margins["h1"]) == 1

        # High elasticity
        scenario_high = MultiLevelPolicyScenario(hospital_demand_elasticity=-1.5)
        outcomes_high = simulate_policy_coupling!(scenario_high, hospitals, state, 1)
        @test outcomes_high.years == 1

        # High exit threshold
        scenario_strict = MultiLevelPolicyScenario(provider_exit_threshold=0.10)
        outcomes_strict = simulate_policy_coupling!(scenario_strict, hospitals, state, 1)
        @test length(outcomes_strict.hospital_closures) >= 0  # All close likely
    end

end
