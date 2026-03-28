using Test

include(joinpath(@__DIR__, "..", "src", "finance", "rhc_optimization.jl"))

@testset "RHC Optimization" begin
    @testset "struct construction" begin
        p = RHCParams(annual_visits=5000, current_cost_per_visit=140.0)
        @test p.payment_cap_per_visit == 165.0
        @test p.behavioral_health_visits == 0
        @test p.telehealth_visits == 0
        @test p.ccm_eligible_patients == 0
        @test p.ccm_monthly_revenue == 62.0
        @test isempty(p.allowable_cost_categories)
    end

    @testset "optimize_rhc_revenue — cost below cap" begin
        p = RHCParams(annual_visits=5000, current_cost_per_visit=140.0,
                      payment_cap_per_visit=165.0)
        r = optimize_rhc_revenue(p)

        @test r.current_air == 140.0  # min(140, 165)
        @test r.optimized_air == 165.0  # can capture up to cap
        @test r.current_revenue == 140.0 * 5000
        @test r.optimized_revenue > r.current_revenue
        @test r.revenue_increase > 0.0
        @test length(r.recommendations) > 0
        # Should have cost report optimization in service additions
        @test any(sa -> sa.service == "Cost Report Optimization", r.service_additions)
    end

    @testset "optimize_rhc_revenue — cost at cap" begin
        p = RHCParams(annual_visits=5000, current_cost_per_visit=170.0,
                      payment_cap_per_visit=165.0)
        r = optimize_rhc_revenue(p)

        @test r.current_air == 165.0  # capped
        @test r.optimized_air == 165.0  # no room to improve
        # No cost report optimization addition (cost >= cap)
        @test !any(sa -> sa.service == "Cost Report Optimization", r.service_additions)
    end

    @testset "optimize_rhc_revenue — with service lines" begin
        p = RHCParams(annual_visits=4000, current_cost_per_visit=150.0,
                      payment_cap_per_visit=165.0,
                      behavioral_health_visits=500,
                      telehealth_visits=300,
                      ccm_eligible_patients=100)
        r = optimize_rhc_revenue(p)

        # Should include BH, telehealth, CCM in service_additions
        services = [sa.service for sa in r.service_additions]
        @test "Behavioral Health" in services
        @test "Telehealth" in services
        @test "Chronic Care Management" in services

        # CCM revenue = 100 * 62.0 * 12
        ccm_sa = filter(sa -> sa.service == "Chronic Care Management", r.service_additions)
        @test length(ccm_sa) == 1
        @test ccm_sa[1].annual_revenue == 100 * 62.0 * 12.0

        # Optimized revenue includes BH and telehealth visits at AIR + CCM
        optimized_air = min(165.0, 165.0)  # cost 150 < cap, so optimized to 165
        expected = optimized_air * (4000 + 500 + 300) + 100 * 62.0 * 12.0
        @test r.optimized_revenue == expected
    end

    @testset "rhc_vs_hopd_comparison" begin
        p = RHCParams(annual_visits=5000, current_cost_per_visit=150.0,
                      payment_cap_per_visit=165.0,
                      behavioral_health_visits=200)
        comp = rhc_vs_hopd_comparison(p, 120.0)

        rhc_air = min(150.0, 165.0)  # 150.0
        total_visits = 5000 + 200
        @test comp.rhc_revenue == rhc_air * total_visits
        @test comp.opps_revenue == 120.0 * total_visits
        @test comp.revenue_difference == comp.rhc_revenue - comp.opps_revenue
        @test comp.rhc_advantage == true  # 150 > 120
        @test comp.breakeven_opps_rate == rhc_air

        # When OPPS rate exceeds AIR, RHC is disadvantaged
        comp2 = rhc_vs_hopd_comparison(p, 200.0)
        @test comp2.rhc_advantage == false
    end

    @testset "edge cases" begin
        # Zero visits should error
        @test_throws ErrorException optimize_rhc_revenue(
            RHCParams(annual_visits=0, current_cost_per_visit=100.0))
        @test_throws ErrorException rhc_vs_hopd_comparison(
            RHCParams(annual_visits=0, current_cost_per_visit=100.0), 100.0)
        # Negative OPPS rate
        @test_throws ErrorException rhc_vs_hopd_comparison(
            RHCParams(annual_visits=100, current_cost_per_visit=100.0), -10.0)
        # Negative cost per visit
        @test_throws ErrorException optimize_rhc_revenue(
            RHCParams(annual_visits=100, current_cost_per_visit=-5.0))
        # No service additions requested — just base visits
        p = RHCParams(annual_visits=3000, current_cost_per_visit=165.0,
                      payment_cap_per_visit=165.0)
        r = optimize_rhc_revenue(p)
        @test r.current_revenue == r.current_air * 3000
        @test length(r.recommendations) >= 1
    end
end
