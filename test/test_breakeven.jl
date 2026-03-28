# ============================================================================
# Tests for break-even analysis (src/finance/breakeven.jl)
# ============================================================================

using Test
using Dates
using UUIDs

# Include only the required source files
include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "financial.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "breakeven.jl"))

@testset "Break-Even Analysis" begin

    @testset "calculate_break_even positive CM" begin
        result = calculate_break_even(500_000.0, 200.0, 500.0; current_volume=2000.0)
        # CM = 500 - 200 = 300; BE = 500_000 / 300 ≈ 1666.67
        @test result.break_even_volume ≈ 500_000.0 / 300.0
        @test result.contribution_margin_per_unit ≈ 300.0
        @test result.fixed_costs ≈ 500_000.0
        @test result.current_volume ≈ 2000.0
        # Cushion = (2000 - 1666.67) / 1666.67
        expected_cushion = (2000.0 - 500_000.0 / 300.0) / (500_000.0 / 300.0)
        @test result.cushion_pct ≈ expected_cushion
        @test result.cushion_pct > 0.0  # above break-even
    end

    @testset "calculate_break_even zero CM" begin
        result = calculate_break_even(100_000.0, 400.0, 400.0)
        @test result.break_even_volume == Inf
        @test result.contribution_margin_per_unit ≈ 0.0
        @test result.cushion_pct == -1.0
    end

    @testset "calculate_break_even negative CM" begin
        result = calculate_break_even(100_000.0, 600.0, 400.0; current_volume=500.0)
        @test result.break_even_volume == Inf
        @test result.contribution_margin_per_unit ≈ -200.0
        @test result.cushion_pct == -1.0
    end

    @testset "calculate_break_even below break-even" begin
        result = calculate_break_even(500_000.0, 200.0, 500.0; current_volume=1000.0)
        be = 500_000.0 / 300.0  # ≈ 1666.67
        @test result.cushion_pct < 0.0  # below break-even
        @test result.cushion_pct ≈ (1000.0 - be) / be
    end

    @testset "target_margin_volume" begin
        # volume = fixed / (rev * (1 - margin) - var_cost)
        vol = target_margin_volume(500_000.0, 200.0, 500.0, 0.03)
        effective_cm = 500.0 * (1.0 - 0.03) - 200.0
        @test vol ≈ 500_000.0 / effective_cm

        # Zero target margin should equal break-even
        vol_zero = target_margin_volume(500_000.0, 200.0, 500.0, 0.0)
        @test vol_zero ≈ 500_000.0 / 300.0
    end

    @testset "target_margin_volume unachievable" begin
        # Very high target margin makes effective CM <= 0
        vol = target_margin_volume(500_000.0, 490.0, 500.0, 0.50)
        # effective_cm = 500 * 0.5 - 490 = -240 <= 0
        @test vol == Inf
    end

    @testset "BreakEvenResult show method" begin
        result = calculate_break_even(300_000.0, 100.0, 400.0; current_volume=1200.0)
        io = IOBuffer()
        show(io, result)
        s = String(take!(io))
        @test contains(s, "BreakEvenResult")
        @test contains(s, "BE=")
    end
end
