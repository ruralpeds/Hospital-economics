# ============================================================================
# Tests for payer contract negotiation modeling
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "analysis", "payer_negotiation.jl"))

@testset "Payer Negotiation" begin

    @testset "single category negotiation" begin
        cat = NegotiationCategory(
            name            = "ED Level 4-5",
            current_volume  = 1000,
            current_charges = 2000.0,
            current_rate    = 0.40,
            proposed_rate   = 0.50,
        )
        result = simulate_negotiation([cat])
        # current = 1000 * 2000 * 0.40 = 800_000
        @test result.current_total_revenue ≈ 800_000.0
        # proposed = 1000 * 2000 * 0.50 = 1_000_000
        @test result.proposed_total_revenue ≈ 1_000_000.0
        @test result.revenue_increase ≈ 200_000.0
        @test result.revenue_increase_pct ≈ 0.25
        @test result.strongest_leverage == "ED Level 4-5"
    end

    @testset "multi-category strongest leverage" begin
        cats = [
            NegotiationCategory(
                name="Small", current_volume=100,
                current_charges=500.0, current_rate=0.40, proposed_rate=0.50,
            ),
            NegotiationCategory(
                name="Big", current_volume=5000,
                current_charges=3000.0, current_rate=0.45, proposed_rate=0.55,
            ),
        ]
        result = simulate_negotiation(cats)
        # Small delta = 100 * 500 * 0.10 = 5_000
        # Big delta = 5000 * 3000 * 0.10 = 1_500_000
        @test result.strongest_leverage == "Big"
        @test result.revenue_increase ≈ 5_000.0 + 1_500_000.0
    end

    @testset "revenue_increase_pct calculation" begin
        cat = NegotiationCategory(
            name="Test", current_volume=200,
            current_charges=1000.0, current_rate=0.50, proposed_rate=0.60,
        )
        result = simulate_negotiation([cat])
        # current = 100_000, proposed = 120_000, increase = 20_000
        @test result.revenue_increase_pct ≈ 20_000.0 / 100_000.0
    end

    @testset "no rate change means zero increase" begin
        cat = NegotiationCategory(
            name="Flat", current_volume=500,
            current_charges=1000.0, current_rate=0.50, proposed_rate=0.50,
        )
        result = simulate_negotiation([cat])
        @test result.revenue_increase ≈ 0.0
        @test result.revenue_increase_pct ≈ 0.0
    end

    @testset "error on empty categories" begin
        @test_throws ErrorException simulate_negotiation(NegotiationCategory[])
    end

    @testset "NegotiationResult fields" begin
        cat = NegotiationCategory(
            name="Cat1", current_volume=100,
            current_charges=100.0, current_rate=0.50, proposed_rate=0.60,
        )
        result = simulate_negotiation([cat])
        @test result isa NegotiationResult
        @test length(result.categories) == 1
        @test result.categories[1].name == "Cat1"
    end
end
