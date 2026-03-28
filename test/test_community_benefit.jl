# ============================================================================
# Tests for Community Benefit Valuation (src/analysis/community_benefit.jl)
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "analysis", "community_benefit.jl"))

@testset "Community Benefit" begin

    @testset "struct construction" begin
        data = CommunityBenefitData(total_expenses=80_000_000.0)
        @test data.charity_care_costs == 0.0
        @test data.total_expenses == 80_000_000.0

        data2 = CommunityBenefitData(
            charity_care_costs=2_000_000.0,
            medicaid_shortfall=3_000_000.0,
            total_expenses=80_000_000.0,
        )
        @test data2.charity_care_costs == 2_000_000.0
    end

    @testset "calculate_community_benefit" begin
        data = CommunityBenefitData(
            charity_care_costs=2_500_000.0,
            medicaid_shortfall=4_000_000.0,
            community_health_services=800_000.0,
            health_professions_education=200_000.0,
            cash_contributions=100_000.0,
            total_expenses=80_000_000.0,
        )
        result = calculate_community_benefit(data; assessed_value=25_000_000.0)

        # Total benefit = sum of categories
        expected_total = 2_500_000.0 + 4_000_000.0 + 800_000.0 + 200_000.0 + 100_000.0
        @test result.total_community_benefit ≈ expected_total

        # Benefit pct = total / expenses
        @test result.benefit_as_pct_expenses ≈ expected_total / 80_000_000.0 atol=0.001

        # Tax exemption includes property tax on assessed value
        @test result.estimated_tax_exemption_value > 0.0

        # With large benefit, should meet AHA standard
        @test result.meets_aha_standard == true

        # Category breakdown has 8 entries
        @test length(result.category_breakdown) == 8
    end

    @testset "calculate_community_benefit — below AHA" begin
        # Minimal benefit, large expenses -> benefit < tax exemption
        data = CommunityBenefitData(
            charity_care_costs=50_000.0,
            total_expenses=100_000_000.0,
        )
        result = calculate_community_benefit(data; assessed_value=50_000_000.0)
        @test result.meets_aha_standard == false
        @test result.net_community_investment < 0.0
    end

    @testset "community_benefit_comparison" begin
        data = CommunityBenefitData(
            charity_care_costs=5_000_000.0,
            medicaid_shortfall=3_000_000.0,
            total_expenses=80_000_000.0,
        )
        comp = community_benefit_comparison(data)
        @test haskey(comp, :hospital_pct)
        @test haskey(comp, :rating)
        @test haskey(comp, :percentile_estimate)
        @test comp.national_median_pct == 0.076
        # 8M / 80M = 10% > 7.6% median
        @test comp.hospital_pct > comp.national_median_pct
        @test comp.rating in (:exemplary, :above_average)
        @test 1 <= comp.percentile_estimate <= 99
    end

    @testset "community_benefit_comparison — below average" begin
        data = CommunityBenefitData(
            charity_care_costs=1_000_000.0,
            total_expenses=100_000_000.0,
        )
        comp = community_benefit_comparison(data)
        @test comp.hospital_pct < comp.national_median_pct
        @test comp.rating in (:below_average, :needs_improvement)
    end

    @testset "edge cases" begin
        # All zeros except required total_expenses
        data = CommunityBenefitData(total_expenses=50_000_000.0)
        result = calculate_community_benefit(data)
        @test result.total_community_benefit == 0.0
        @test result.benefit_as_pct_expenses == 0.0
        @test result.meets_aha_standard == false
    end
end
