using Test
using Random
using Distributions
using Statistics

include(joinpath(@__DIR__, "..", "src", "finance", "debt_capacity.jl"))

@testset "Debt Capacity Analysis" begin
    @testset "struct construction" begin
        p = DebtCapacityParams(current_operating_income=5_000_000.0,
                               current_depreciation=1_000_000.0,
                               current_debt_service=2_000_000.0)
        @test p.projection_years == 10
        @test p.n_simulations == 1000
        @test p.base_interest_rate == 0.05
        @test p.min_dscr_threshold == 1.25
        @test p.target_confidence == 0.95
        @test p.random_seed == 42
    end

    @testset "calculate_debt_capacity" begin
        p = DebtCapacityParams(current_operating_income=5_000_000.0,
                               current_depreciation=1_000_000.0,
                               current_debt_service=2_000_000.0,
                               n_simulations=500, random_seed=123)
        r = calculate_debt_capacity(p)

        @test r.max_annual_debt_service > 0.0
        @test r.max_debt_principal > 0.0
        # Current DSCR = (5M + 1M) / 2M = 3.0
        @test r.current_dscr == 3.0
        @test 0.0 <= r.prob_dscr_below_threshold <= 1.0
        @test haskey(r.dscr_percentiles, 0.05)
        @test haskey(r.dscr_percentiles, 0.50)
        @test haskey(r.dscr_percentiles, 0.95)
        @test r.dscr_percentiles[0.05] <= r.dscr_percentiles[0.50]
        @test r.dscr_percentiles[0.50] <= r.dscr_percentiles[0.95]
        @test r.estimated_credit_tier isa String
    end

    @testset "credit tier assignment" begin
        @test _assign_credit_tier(4.5) == "AA"
        @test _assign_credit_tier(3.5) == "A+"
        @test _assign_credit_tier(2.7) == "A"
        @test _assign_credit_tier(2.2) == "A-"
        @test _assign_credit_tier(1.8) == "BBB+"
        @test _assign_credit_tier(1.6) == "BBB"
        @test _assign_credit_tier(1.3) == "BBB-"
        @test _assign_credit_tier(1.15) == "BB"
        @test _assign_credit_tier(1.05) == "B"
        @test _assign_credit_tier(0.8) == "Below B"
    end

    @testset "annuity principal" begin
        # At zero rate, principal = payment * years
        @test _annuity_principal(100_000.0, 0.0, 10) == 1_000_000.0
        @test _annuity_principal(100_000.0, -0.01, 10) == 1_000_000.0
        # At positive rate, principal < payment * years
        p = _annuity_principal(100_000.0, 0.05, 10)
        @test p > 0.0
        @test p < 1_000_000.0
    end

    @testset "debt_capacity_sensitivity" begin
        p = DebtCapacityParams(current_operating_income=5_000_000.0,
                               current_depreciation=1_000_000.0,
                               current_debt_service=2_000_000.0,
                               n_simulations=200, random_seed=42)
        results = debt_capacity_sensitivity(p)

        @test length(results) == 5
        @test results[1].rate_shift_bp == -200
        @test results[3].rate_shift_bp == 0
        @test results[5].rate_shift_bp == 200
        # Higher rates should generally reduce max principal
        @test results[1].max_debt_principal >= results[5].max_debt_principal ||
              abs(results[1].max_debt_principal - results[5].max_debt_principal) < 1_000_000
    end

    @testset "edge cases" begin
        @test_throws ErrorException calculate_debt_capacity(
            DebtCapacityParams(current_operating_income=0.0,
                               current_depreciation=0.0, current_debt_service=1.0))
        @test_throws ErrorException calculate_debt_capacity(
            DebtCapacityParams(current_operating_income=-100.0,
                               current_depreciation=0.0, current_debt_service=1.0))
        # Zero current debt service => Inf DSCR
        p = DebtCapacityParams(current_operating_income=1_000_000.0,
                               current_depreciation=200_000.0,
                               current_debt_service=0.0, n_simulations=100)
        r = calculate_debt_capacity(p)
        @test r.current_dscr == Inf
    end
end
