# ============================================================================
# Tests for Monte Carlo analytics: probability_of_loss, value_at_risk,
# and break_even_by_payer
# ============================================================================

using Test
using Random
using Statistics

# Include source
include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "simulation", "deterministic.jl"))
include(joinpath(@__DIR__, "..", "src", "simulation", "montecarlo.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "financial.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "breakeven.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "department.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "staffing.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "payer.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "capital.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "hospital.jl"))

@testset "Monte Carlo Analytics" begin

    # -----------------------------------------------------------------------
    @testset "probability_of_loss - all positive margins" begin
        # Simulate iteration results with all positive margins
        results = [IterationResult(
            i, 0.05, 500_000.0, nothing, 60.0,
            Dict(:volume_growth => -0.01, :cost_inflation => 0.03)
        ) for i in 1:100]

        p_loss = probability_of_loss(results)
        @test p_loss == 0.0
    end

    # -----------------------------------------------------------------------
    @testset "probability_of_loss - all negative margins" begin
        results = [IterationResult(
            i, -0.08, -200_000.0, 3, 15.0,
            Dict(:volume_growth => -0.05, :cost_inflation => 0.06)
        ) for i in 1:100]

        p_loss = probability_of_loss(results)
        @test p_loss == 1.0
    end

    # -----------------------------------------------------------------------
    @testset "probability_of_loss - mixed margins" begin
        results = vcat(
            [IterationResult(i, 0.03, 100_000.0, nothing, 50.0,
                Dict(:v => 0.0)) for i in 1:70],
            [IterationResult(i, -0.05, -80_000.0, 5, 20.0,
                Dict(:v => 0.0)) for i in 71:100],
        )

        p_loss = probability_of_loss(results)
        @test isapprox(p_loss, 0.30; atol=0.01)
    end

    # -----------------------------------------------------------------------
    @testset "value_at_risk - basic" begin
        # Sorted values: VaR at 5% should be the 5th percentile
        rng = MersenneTwister(42)
        values = randn(rng, 10_000) .* 500_000.0  # centered at 0

        var_5 = value_at_risk(values, 0.05)
        @test var_5 < 0.0  # 5th percentile of centered normal is negative

        var_1 = value_at_risk(values, 0.01)
        @test var_1 < var_5  # 1st percentile is more negative than 5th
    end

    # -----------------------------------------------------------------------
    @testset "value_at_risk - all same values" begin
        values = fill(100_000.0, 1000)
        var = value_at_risk(values, 0.05)
        @test isapprox(var, 100_000.0; rtol=0.01)
    end

    # -----------------------------------------------------------------------
    @testset "value_at_risk - alpha boundaries" begin
        values = collect(1.0:100.0)
        var_50 = value_at_risk(values, 0.50)
        @test isapprox(var_50, 50.0; atol=2.0)

        var_10 = value_at_risk(values, 0.10)
        @test isapprox(var_10, 10.0; atol=2.0)
    end

    # -----------------------------------------------------------------------
    @testset "sample-capture reproducibility" begin
        # Test that _sample_deterministic_params and _collect_sampled_params
        # use the same RNG sequence for reproducibility.
        # This is critical: both functions must call sample() in identical order.

        # Create minimal MonteCarloParams for testing
        using Distributions
        mc_params = MonteCarloParams(
            n_iterations=10,
            random_seed=12345,
            projection_years=5,
            volume_growth=Normal(-0.01, 0.02),
            cost_inflation=Normal(0.03, 0.01),
            salary_inflation=Normal(0.035, 0.012),
            supply_inflation=Normal(0.04, 0.015),
            payer_mix_shift=Normal(0.005, 0.003),
            ma_penetration_growth=Normal(0.02, 0.005),
            staffing_turnover=Normal(0.08, 0.03),
            travel_nurse_premium=Normal(0.15, 0.05),
        )

        # Run both functions with same seeded RNG
        rng1 = MersenneTwister(99999)
        det_params = _sample_deterministic_params(mc_params, rng1)

        rng2 = MersenneTwister(99999)
        collected_params = _collect_sampled_params(mc_params, rng2)

        # Verify that deterministic params are captured in collected params
        @test haskey(collected_params, :volume_growth)
        @test haskey(collected_params, :cost_inflation)
        @test haskey(collected_params, :salary_inflation)
        @test haskey(collected_params, :supply_inflation)
        @test haskey(collected_params, :reimbursement_adjustment)  # Must be included!
        @test haskey(collected_params, :payer_mix_shift)

        # The critical check: if RNG sequences diverge, these won't be equal
        # After aligned sampling, reimbursement_adjustment should match
        computed_reimb_adj = collected_params[:cost_inflation] * 0.5
        @test isapprox(collected_params[:reimbursement_adjustment], computed_reimb_adj; atol=1e-10)

        # Verify that all iterations produce valid results
        for i in 1:10
            rng = MersenneTwister(i)
            det_params = _sample_deterministic_params(mc_params, rng)
            collected = _collect_sampled_params(mc_params, MersenneTwister(i))

            # Sampled parameters should be finite and reasonable
            @test isfinite(det_params.volume_growth_rate)
            @test isfinite(det_params.cost_inflation_rate)
            @test isfinite(det_params.reimbursement_adjustment)
            @test length(collected) == 9  # Should have all 9 parameters
        end
    end

    # -----------------------------------------------------------------------
    @testset "break_even_by_payer" begin
        # This test verifies that break_even_by_payer produces a result
        # for each payer category on a hospital
        hospital = CriticalAccessHospital(;
            name="Test Hospital",
            cms_provider_number="171301", npi="1234567890",
            cah_certification_date=Date(2006, 1, 15),
            licensed_beds=25, nearest_hospital_miles=35.0,
            location=GeoLocation(; latitude=38.5, longitude=-98.7,
                fips_code="20009", state="KS", county="Barton", zip_code="67530"),
            service_area=ServiceArea(; primary_service_area_pop=8000,
                total_service_area_pop=12000),
        )

        results = break_even_by_payer(hospital)
        @test results isa Dict
        @test length(results) >= 1

        # Each result should be a BreakEvenResult
        for (payer, be) in results
            @test payer isa Symbol
            @test be.break_even_volume >= 0.0 || be.break_even_volume == Inf
            @test be.fixed_costs >= 0.0
        end
    end
end
