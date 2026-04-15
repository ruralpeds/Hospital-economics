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

    @testset "calculate_break_even - positive CM" begin
        # Fixed costs = 500k, var cost = 200/unit, revenue = 500/unit
        # CM = 300/unit, BE volume = 500000/300 = 1666.67
        result = calculate_break_even(500_000.0, 200.0, 500.0; current_volume=2000.0)
        @test result.contribution_margin_per_unit ≈ 300.0
        @test result.break_even_volume ≈ 500_000.0 / 300.0
        @test result.current_volume ≈ 2000.0
        @test result.fixed_costs ≈ 500_000.0
        @test result.variable_cost_per_unit ≈ 200.0
        @test result.revenue_per_unit ≈ 500.0
    end

    @testset "calculate_break_even - cushion above BE" begin
        # BE volume = 1000, current = 1200 => cushion = (1200-1000)/1000 = 0.20
        result = calculate_break_even(100_000.0, 50.0, 150.0; current_volume=1200.0)
        be_vol = 100_000.0 / 100.0  # = 1000
        @test result.break_even_volume ≈ be_vol
        @test result.cushion_pct ≈ (1200.0 - be_vol) / be_vol
        @test result.cushion_pct > 0.0
    end

    @testset "calculate_break_even - cushion below BE" begin
        result = calculate_break_even(500_000.0, 200.0, 500.0; current_volume=1000.0)
        be = 500_000.0 / 300.0
        @test result.cushion_pct < 0.0
        @test result.cushion_pct ≈ (1000.0 - be) / be
    end

    @testset "calculate_break_even - zero CM returns Inf" begin
        result = calculate_break_even(100_000.0, 400.0, 400.0)
        @test result.break_even_volume == Inf
        @test result.contribution_margin_per_unit ≈ 0.0
        @test result.cushion_pct == -1.0
    end

    @testset "calculate_break_even - negative CM returns Inf" begin
        result = calculate_break_even(100_000.0, 600.0, 400.0; current_volume=500.0)
        @test result.break_even_volume == Inf
        @test result.contribution_margin_per_unit ≈ -200.0
        @test result.cushion_pct == -1.0
    end

    @testset "calculate_break_even - no current volume" begin
        result = calculate_break_even(200_000.0, 100.0, 300.0)
        @test result.current_volume ≈ 0.0
        be = 200_000.0 / 200.0
        @test result.cushion_pct ≈ (0.0 - be) / be
    end

    @testset "target_margin_volume - achievable target" begin
        # fixed=500k, var=200, rev=500, target=0.03
        # effective_cm = 500*(1-0.03) - 200 = 485 - 200 = 285
        vol = target_margin_volume(500_000.0, 200.0, 500.0, 0.03)
        effective_cm = 500.0 * (1.0 - 0.03) - 200.0
        @test vol ≈ 500_000.0 / effective_cm
        @test isfinite(vol)
    end

    @testset "target_margin_volume - zero margin equals break-even" begin
        vol = target_margin_volume(500_000.0, 200.0, 500.0, 0.0)
        @test vol ≈ 500_000.0 / 300.0
        be = calculate_break_even(500_000.0, 200.0, 500.0)
        @test vol ≈ be.break_even_volume
    end

    @testset "target_margin_volume - unachievable returns Inf" begin
        # effective_cm = 500 * 0.5 - 490 = -240 <= 0
        vol = target_margin_volume(500_000.0, 490.0, 500.0, 0.50)
        @test vol == Inf
    end

    @testset "target_margin_volume - higher margin needs more volume" begin
        vol_low = target_margin_volume(500_000.0, 200.0, 500.0, 0.02)
        vol_high = target_margin_volume(500_000.0, 200.0, 500.0, 0.10)
        @test vol_high > vol_low
    end

    @testset "BreakEvenResult show method" begin
        result = calculate_break_even(300_000.0, 100.0, 400.0; current_volume=1200.0)
        io = IOBuffer()
        show(io, result)
        s = String(take!(io))
        @test contains(s, "BreakEvenResult")
        @test contains(s, "BE=")
        @test contains(s, "cushion=")
    end
end
