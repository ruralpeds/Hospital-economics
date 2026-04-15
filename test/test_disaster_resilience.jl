# ============================================================================
# Tests for Disaster Resilience (src/risk/disaster_resilience.jl)
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "risk", "disaster_resilience.jl"))

@testset "Disaster Resilience" begin

    @testset "struct construction" begin
        p = DisasterProfile()
        @test p.fema_risk_score == 0.5
        @test p.flood_zone == :minimal
        @test p.insurance_coverage_pct == 0.80

        r = DisasterImpactResult(
            infrastructure_vulnerability_score=0.5, financial_exposure=1e6,
            revenue_interruption_days=14.0, surge_cost_estimate=200_000.0,
            recovery_time_estimate_days=21.0, insurance_gap=100_000.0,
            resilience_score=50.0, recommendations=["Test"])
        @test r.resilience_score == 50.0
    end

    @testset "assess_disaster_resilience — prepared hospital" begin
        prepared = DisasterProfile(
            fema_risk_score=0.2, flood_zone=:minimal, wildfire_risk=:low,
            hurricane_zone=false, earthquake_zone=false,
            days_generator_fuel=7.0, has_helipad=true,
            surge_bed_capacity=20, supply_chain_redundancy=0.9,
            insurance_coverage_pct=0.95,
        )
        result = assess_disaster_resilience(prepared, 50_000_000.0, 48_000_000.0)
        @test result.resilience_score > 70.0
        @test result.infrastructure_vulnerability_score < 0.3
        @test result.insurance_gap >= 0.0
        @test result.recovery_time_estimate_days > 0.0
    end

    @testset "assess_disaster_resilience — vulnerable hospital" begin
        vulnerable = DisasterProfile(
            fema_risk_score=0.9, flood_zone=:very_high, wildfire_risk=:high,
            hurricane_zone=true, earthquake_zone=true,
            days_generator_fuel=1.0, has_helipad=false,
            surge_bed_capacity=0, supply_chain_redundancy=0.2,
            insurance_coverage_pct=0.50,
        )
        result = assess_disaster_resilience(vulnerable, 50_000_000.0, 48_000_000.0)
        @test result.resilience_score < 40.0
        @test result.infrastructure_vulnerability_score > 0.5
        @test result.financial_exposure > 0.0
        @test length(result.recommendations) >= 3
    end

    @testset "disaster_stress_test" begin
        profile = DisasterProfile(fema_risk_score=0.6, flood_zone=:moderate,
            insurance_coverage_pct=0.80, supply_chain_redundancy=0.5)
        results = disaster_stress_test(profile, 40_000_000.0, 2_000_000.0;
            scenarios=[:flood, :tornado, :pandemic, :ice_storm])
        @test length(results) == 4
        @test results[1].scenario == :flood

        for r in results
            @test r.revenue_loss >= 0.0
            @test r.extra_costs >= 0.0
            @test haskey(r, :cash_reserves_survive)
            @test haskey(r, :days_to_recovery)
        end

        # Tornado should be worse than ice_storm
        tornado = results[2]
        ice = results[4]
        @test tornado.total_financial_impact >= ice.total_financial_impact
    end

    @testset "disaster_stress_test — high reserves survive" begin
        profile = DisasterProfile()
        results = disaster_stress_test(profile, 30_000_000.0, 100_000_000.0;
            scenarios=[:ice_storm])
        @test results[1].cash_reserves_survive == true
    end

    @testset "disaster_stress_test — unknown scenario" begin
        profile = DisasterProfile()
        results = disaster_stress_test(profile, 10_000_000.0, 500_000.0;
            scenarios=[:alien_invasion])
        @test length(results) == 1
        @test results[1].revenue_loss == 0.0
        @test results[1].cash_reserves_survive == true
    end

    @testset "edge cases" begin
        # Default profile should produce valid assessment
        result = assess_disaster_resilience(DisasterProfile(), 20_000_000.0, 18_000_000.0)
        @test 0.0 <= result.resilience_score <= 100.0
        @test 0.0 <= result.infrastructure_vulnerability_score <= 1.0
        @test result.revenue_interruption_days >= 7.0
    end
end
