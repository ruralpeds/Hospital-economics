# ============================================================================
# Tests for Social Determinants of Health (src/analysis/sdoh.jl)
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "analysis", "sdoh.jl"))

@testset "SDOH Analysis" begin

    @testset "struct construction" begin
        p = SDOHProfile()
        @test p.svi_score == 0.5
        @test p.adi_national_rank == 50
        @test p.broadband_pct == 0.80
        @test p.transportation_desert == false

        p2 = SDOHProfile(svi_score=0.9, poverty_rate=0.35, uninsured_rate=0.25)
        @test p2.svi_score == 0.9
        @test p2.poverty_rate == 0.35

        a = SDOHAdjustment()
        @test a.volume_adjustment == 1.0
        @test a.composite_risk_score == 0.0
    end

    @testset "calculate_sdoh_adjustments — high vulnerability" begin
        high = SDOHProfile(
            svi_score=0.90, adi_national_rank=95, food_desert_pct=0.30,
            broadband_pct=0.40, transportation_desert=true,
            health_literacy_score=0.3, uninsured_rate=0.25, poverty_rate=0.35,
            median_household_income=25_000.0,
        )
        adj = calculate_sdoh_adjustments(high)
        @test adj.cost_per_case_adjustment > 1.15
        @test adj.ed_utilization_multiplier > 1.3
        @test adj.readmission_risk_multiplier > 1.05
        @test adj.telehealth_viability_score < 0.5
        @test adj.composite_risk_score > 0.6
    end

    @testset "calculate_sdoh_adjustments — low vulnerability" begin
        low = SDOHProfile(
            svi_score=0.10, adi_national_rank=10, food_desert_pct=0.0,
            broadband_pct=0.95, transportation_desert=false,
            health_literacy_score=0.9, uninsured_rate=0.03, poverty_rate=0.05,
            median_household_income=80_000.0,
        )
        adj = calculate_sdoh_adjustments(low)
        @test adj.cost_per_case_adjustment < 1.10
        @test adj.ed_utilization_multiplier < 1.10
        @test adj.telehealth_viability_score > 0.8
        @test adj.composite_risk_score < 0.25
    end

    @testset "sdoh_financial_impact" begin
        profile = SDOHProfile(svi_score=0.7, uninsured_rate=0.20, poverty_rate=0.25)
        result = sdoh_financial_impact(profile, 50_000_000.0, 48_000_000.0)
        @test haskey(result, :adjusted_revenue)
        @test haskey(result, :adjusted_expenses)
        @test haskey(result, :net_margin_impact)
        # High uninsured rate should drag revenue down
        @test result.revenue_impact < 0.0
        # Expenses should increase
        @test result.expense_impact > 0.0
    end

    @testset "sdoh_risk_tier" begin
        @test sdoh_risk_tier(SDOHProfile(svi_score=0.05, adi_national_rank=5,
            uninsured_rate=0.02, poverty_rate=0.03)) == :low
        @test sdoh_risk_tier(SDOHProfile(svi_score=0.50, adi_national_rank=50)) == :moderate
        @test sdoh_risk_tier(SDOHProfile(svi_score=0.80, adi_national_rank=85,
            uninsured_rate=0.20, poverty_rate=0.30)) == :high
        @test sdoh_risk_tier(SDOHProfile(svi_score=0.95, adi_national_rank=99,
            uninsured_rate=0.30, poverty_rate=0.40, food_desert_pct=0.40,
            transportation_desert=true)) == :critical
    end

    @testset "edge cases" begin
        # Default profile should not error
        adj = calculate_sdoh_adjustments(SDOHProfile())
        @test adj.volume_adjustment > 0.0
        @test 0.0 <= adj.composite_risk_score <= 1.0

        # Zero base revenue/expenses
        result = sdoh_financial_impact(SDOHProfile(), 0.0, 0.0)
        @test result.adjusted_revenue == 0.0
        @test result.adjusted_expenses == 0.0
    end
end
