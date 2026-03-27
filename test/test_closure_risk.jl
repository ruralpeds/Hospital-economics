# ============================================================================
# Tests for closure risk assessment
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "types", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "utils", "constants.jl"))
using .Constants

# ---------------------------------------------------------------------------
# Stub closure risk assessment model
# ---------------------------------------------------------------------------

struct ClosureRiskFactors
    operating_margin::Float64
    days_cash_on_hand::Float64
    debt_service_coverage::Float64
    current_ratio::Float64
    average_daily_census::Float64
    bed_capacity::Int
    occupancy_rate::Float64
    payer_mix_government::Float64
    age_of_plant::Float64
    is_sole_community_provider::Bool
    nearest_hospital_miles::Float64
    population_trend::Float64       # annual growth rate
    physician_supply::Float64       # per 100k
end

struct ClosureRiskScore
    overall_score::Float64          # 0-100 (higher = more risk)
    financial_score::Float64
    operational_score::Float64
    market_score::Float64
    risk_category::Symbol           # :low, :moderate, :elevated, :high, :critical
    contributing_factors::Vector{String}
end

function assess_closure_risk(factors::ClosureRiskFactors)::ClosureRiskScore
    contributing = String[]

    # Financial score (0-40 points)
    financial = 0.0
    if factors.operating_margin < -0.05
        financial += min(15.0, abs(factors.operating_margin) * 100)
        push!(contributing, "negative_operating_margin")
    end
    if factors.days_cash_on_hand < Constants.BENCHMARK_DAYS_CASH
        financial += min(10.0, (Constants.BENCHMARK_DAYS_CASH - factors.days_cash_on_hand) / 10.0)
        push!(contributing, "low_cash_reserves")
    end
    if factors.debt_service_coverage < 1.5
        financial += min(10.0, (1.5 - factors.debt_service_coverage) * 10.0)
        push!(contributing, "weak_debt_service_coverage")
    end
    if factors.current_ratio < 1.5
        financial += min(5.0, (1.5 - factors.current_ratio) * 5.0)
        push!(contributing, "low_current_ratio")
    end
    financial = min(financial, 40.0)

    # Operational score (0-30 points)
    operational = 0.0
    if factors.occupancy_rate < 0.30
        operational += min(10.0, (0.30 - factors.occupancy_rate) * 50.0)
        push!(contributing, "low_occupancy")
    end
    if factors.age_of_plant > 15.0
        operational += min(10.0, (factors.age_of_plant - 15.0) / 2.0)
        push!(contributing, "aging_facility")
    end
    if factors.payer_mix_government > 0.80
        operational += min(10.0, (factors.payer_mix_government - 0.80) * 50.0)
        push!(contributing, "high_government_payer_dependence")
    end
    operational = min(operational, 30.0)

    # Market score (0-30 points)
    market = 0.0
    if factors.population_trend < -0.01
        market += min(10.0, abs(factors.population_trend) * 500.0)
        push!(contributing, "population_decline")
    end
    if factors.physician_supply < 30.0
        market += min(10.0, (30.0 - factors.physician_supply) / 3.0)
        push!(contributing, "physician_shortage")
    end
    if !factors.is_sole_community_provider && factors.nearest_hospital_miles < 20.0
        market += 5.0
        push!(contributing, "competitive_pressure")
    end
    market = min(market, 30.0)

    overall = financial + operational + market

    category = if overall < 20.0
        :low
    elseif overall < 40.0
        :moderate
    elseif overall < 60.0
        :elevated
    elseif overall < 80.0
        :high
    else
        :critical
    end

    return ClosureRiskScore(overall, financial, operational, market,
                            category, contributing)
end

"""
    community_impact_score(factors::ClosureRiskFactors) -> Float64

Estimate the community impact (0-100) if the hospital closes.
Higher score = greater negative impact on community.
"""
function community_impact_score(factors::ClosureRiskFactors)::Float64
    impact = 0.0

    # Sole community provider: massive impact
    if factors.is_sole_community_provider
        impact += 40.0
    end

    # Distance to next hospital
    if factors.nearest_hospital_miles > 30.0
        impact += min(20.0, (factors.nearest_hospital_miles - 30.0) / 2.0)
    end

    # Physician shortage amplifies impact
    if factors.physician_supply < 40.0
        impact += min(15.0, (40.0 - factors.physician_supply) / 3.0)
    end

    # Aging population more dependent on local hospital
    if factors.payer_mix_government > 0.70
        impact += min(15.0, (factors.payer_mix_government - 0.70) * 50.0)
    end

    # Population size (smaller = more dependent)
    impact += min(10.0, 10.0 * (1.0 - factors.occupancy_rate))

    return min(impact, 100.0)
end

@testset "Closure Risk Assessment" begin

    # -----------------------------------------------------------------------
    @testset "Healthy hospital — low risk" begin
        factors = ClosureRiskFactors(
            0.03,    # positive operating margin
            120.0,   # strong days cash
            2.5,     # strong DSCR
            2.8,     # strong current ratio
            12.0,    # decent census
            25,
            0.48,    # moderate occupancy for CAH
            0.72,    # typical government payer mix
            10.0,    # reasonable plant age
            true,    # sole community provider
            45.0,    # distant from competitors
            0.005,   # slight population growth
            55.0,    # adequate physician supply
        )
        score = assess_closure_risk(factors)

        @test score.overall_score < 20.0
        @test score.risk_category == :low
        @test score.financial_score < 10.0
        @test isempty(score.contributing_factors) || length(score.contributing_factors) < 3
    end

    # -----------------------------------------------------------------------
    @testset "Struggling hospital — high risk" begin
        factors = ClosureRiskFactors(
            -0.08,   # negative margin
            30.0,    # low cash
            0.8,     # below 1.0 DSCR
            1.1,     # weak current ratio
            5.0,     # very low census
            25,
            0.20,    # low occupancy
            0.85,    # high government payer dependence
            22.0,    # aging plant
            false,   # not sole provider
            15.0,    # competitor nearby
            -0.02,   # declining population
            20.0,    # severe physician shortage
        )
        score = assess_closure_risk(factors)

        @test score.overall_score > 50.0
        @test score.risk_category in (:elevated, :high, :critical)
        @test score.financial_score > 15.0
        @test score.operational_score > 10.0
        @test score.market_score > 10.0

        @test "negative_operating_margin" in score.contributing_factors
        @test "low_cash_reserves" in score.contributing_factors
        @test "low_occupancy" in score.contributing_factors
        @test "population_decline" in score.contributing_factors
    end

    # -----------------------------------------------------------------------
    @testset "Score component bounds" begin
        # Worst case scenario
        factors = ClosureRiskFactors(
            -0.30, 5.0, 0.2, 0.5, 2.0, 25, 0.08,
            0.95, 30.0, false, 10.0, -0.05, 10.0,
        )
        score = assess_closure_risk(factors)

        @test 0.0 <= score.financial_score <= 40.0
        @test 0.0 <= score.operational_score <= 30.0
        @test 0.0 <= score.market_score <= 30.0
        @test 0.0 <= score.overall_score <= 100.0
        @test score.risk_category == :critical
    end

    # -----------------------------------------------------------------------
    @testset "Risk categories" begin
        # Test each category boundary
        for (margin, expected_low_risk) in [
            (0.05, true), (-0.15, false)
        ]
            factors = ClosureRiskFactors(
                margin, 100.0, 2.0, 2.5, 10.0, 25, 0.40,
                0.72, 10.0, true, 40.0, 0.0, 50.0,
            )
            score = assess_closure_risk(factors)
            if expected_low_risk
                @test score.risk_category in (:low, :moderate)
            else
                @test score.risk_category in (:moderate, :elevated, :high, :critical)
            end
        end
    end

    # -----------------------------------------------------------------------
    @testset "Community impact — sole provider" begin
        factors = ClosureRiskFactors(
            -0.05, 50.0, 1.2, 1.8, 8.0, 25, 0.32,
            0.78, 15.0, true, 65.0, -0.01, 25.0,
        )
        impact = community_impact_score(factors)

        @test impact > 50.0  # sole provider + distant + physician shortage
        @test impact <= 100.0
    end

    # -----------------------------------------------------------------------
    @testset "Community impact — urban competitor" begin
        factors = ClosureRiskFactors(
            0.02, 100.0, 2.0, 2.5, 15.0, 25, 0.60,
            0.65, 8.0, false, 5.0, 0.01, 80.0,
        )
        impact = community_impact_score(factors)

        # Not sole provider, nearby alternatives, good physician supply
        @test impact < 30.0
    end

    # -----------------------------------------------------------------------
    @testset "Contributing factors are meaningful" begin
        factors = ClosureRiskFactors(
            -0.10, 20.0, 0.9, 1.0, 4.0, 25, 0.16,
            0.90, 25.0, false, 12.0, -0.03, 15.0,
        )
        score = assess_closure_risk(factors)

        # Should have multiple contributing factors
        @test length(score.contributing_factors) >= 4
        @test allunique(score.contributing_factors)
    end
end
