# ============================================================================
# Tests for community economic impact analysis
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "analysis", "community.jl"))

@testset "Community Impact" begin

    @testset "basic impact calculation" begin
        params = CommunityImpactParams(
            annual_payroll  = 10_000_000.0,
            total_employees = 200,
            local_purchasing = 2_000_000.0,
            economic_multiplier = 1.5,
        )
        result = calculate_community_impact(params)
        # Direct = payroll + local_purchasing
        @test result.direct_economic_impact ≈ 12_000_000.0
        # Total = direct * multiplier
        @test result.total_economic_impact ≈ 18_000_000.0
        # Indirect = total - direct
        @test result.indirect_economic_impact ≈ 6_000_000.0
    end

    @testset "jobs supported includes induced" begin
        params = CommunityImpactParams(
            annual_payroll  = 10_000_000.0,
            total_employees = 200,
            local_purchasing = 2_000_000.0,
        )
        result = calculate_community_impact(params)
        @test result.jobs_supported >= params.total_employees
    end

    @testset "devastation score is 0-100" begin
        params = CommunityImpactParams(
            annual_payroll  = 12_000_000.0,
            total_employees = 250,
            local_purchasing = 3_000_000.0,
        )
        result = calculate_community_impact(params)
        @test 0.0 <= result.closure_devastation_score <= 100.0
    end

    @testset "tax revenue impact" begin
        params = CommunityImpactParams(
            annual_payroll  = 10_000_000.0,
            total_employees = 200,
            local_purchasing = 2_000_000.0,
            economic_multiplier = 2.0,
            tax_rate = 0.03,
        )
        result = calculate_community_impact(params)
        # tax = total * tax_rate = 12e6 * 2.0 * 0.03
        @test result.tax_revenue_impact ≈ 24_000_000.0 * 0.03
    end

    @testset "property value loss calculation" begin
        params = CommunityImpactParams(
            annual_payroll = 5_000_000.0,
            total_employees = 100,
            local_purchasing = 1_000_000.0,
            property_value_impact = 0.05,
            avg_home_value = 200_000.0,
            homes_in_service_area = 2000,
        )
        result = calculate_community_impact(params)
        # loss = 200000 * 0.05 * 2000 = 20_000_000
        @test result.property_value_loss ≈ 20_000_000.0
    end

    @testset "closure projection returns correct years" begin
        params = CommunityImpactParams(
            annual_payroll  = 10_000_000.0,
            total_employees = 200,
            local_purchasing = 2_000_000.0,
        )
        proj = closure_impact_projection(params; years=5)
        @test length(proj) == 5
        @test proj[1].year == 1
        @test proj[5].year == 5
    end

    @testset "cumulative losses increase over time" begin
        params = CommunityImpactParams(
            annual_payroll  = 10_000_000.0,
            total_employees = 200,
            local_purchasing = 2_000_000.0,
        )
        proj = closure_impact_projection(params; years=5)
        for i in 2:5
            @test proj[i].cumulative_economic_loss >= proj[i-1].cumulative_economic_loss
        end
    end

    @testset "closure projection year=1 error" begin
        params = CommunityImpactParams(
            annual_payroll = 5e6, total_employees = 100, local_purchasing = 1e6,
        )
        @test_throws ErrorException closure_impact_projection(params; years=0)
    end
end
