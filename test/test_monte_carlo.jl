# ============================================================================
# Tests for Monte Carlo simulation engine
# ============================================================================

using Test
using Random
using Statistics

# Include deterministic engine (Monte Carlo builds on it)
include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "simulation", "deterministic.jl"))

# ---------------------------------------------------------------------------
# Stub Monte Carlo engine for testing (until full implementation exists)
# ---------------------------------------------------------------------------

"""
    MonteCarloParams <: AbstractSimulationParams

Parameters for Monte Carlo simulation.
"""
struct MonteCarloParams <: AbstractSimulationParams
    n_simulations::Int
    seed::Int
    projection_years::Int
    volume_growth_mean::Float64
    volume_growth_std::Float64
    cost_inflation_mean::Float64
    cost_inflation_std::Float64
    reimbursement_adj_mean::Float64
    reimbursement_adj_std::Float64
end

function MonteCarloParams(;
    n_simulations=1000,
    seed=42,
    projection_years=10,
    volume_growth_mean=-0.01,
    volume_growth_std=0.02,
    cost_inflation_mean=0.03,
    cost_inflation_std=0.01,
    reimbursement_adj_mean=0.015,
    reimbursement_adj_std=0.005,
)
    MonteCarloParams(n_simulations, seed, projection_years,
        volume_growth_mean, volume_growth_std,
        cost_inflation_mean, cost_inflation_std,
        reimbursement_adj_mean, reimbursement_adj_std)
end

struct MonteCarloResult <: AbstractSimulationResult
    terminal_margins::Vector{Float64}
    closure_probabilities::Vector{Float64}
    mean_terminal_margin::Float64
    p5_terminal_margin::Float64
    p95_terminal_margin::Float64
    closure_probability::Float64
end

function run_monte_carlo(base_financials::NamedTuple, params::MonteCarloParams)
    rng = MersenneTwister(params.seed)
    terminal_margins = Float64[]
    closure_flags = Bool[]

    for _ in 1:params.n_simulations
        vol_growth = params.volume_growth_mean + randn(rng) * params.volume_growth_std
        cost_infl = params.cost_inflation_mean + randn(rng) * params.cost_inflation_std
        reimb_adj = params.reimbursement_adj_mean + randn(rng) * params.reimbursement_adj_std

        det_params = DeterministicParams(;
            projection_years=params.projection_years,
            volume_growth_rate=vol_growth,
            cost_inflation_rate=cost_infl,
            salary_inflation_rate=cost_infl + 0.005,
            supply_inflation_rate=cost_infl + 0.01,
            reimbursement_adjustment=reimb_adj,
            payer_mix_shift=0.005,
        )
        result = project_financials(base_financials, det_params)
        push!(terminal_margins, result.terminal_operating_margin)
        push!(closure_flags, result.closure_risk_year !== nothing)
    end

    sorted_margins = sort(terminal_margins)
    n = length(sorted_margins)
    p5_idx = max(1, Int(ceil(0.05 * n)))
    p95_idx = min(n, Int(ceil(0.95 * n)))

    closure_prob = mean(closure_flags)
    # Per-year closure probability (simplified)
    closure_probs_by_year = [closure_prob * (i / params.projection_years) for i in 1:params.projection_years]

    MonteCarloResult(
        terminal_margins,
        closure_probs_by_year,
        mean(terminal_margins),
        sorted_margins[p5_idx],
        sorted_margins[p95_idx],
        closure_prob,
    )
end

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------
function make_mc_base_financials()
    (
        inpatient_revenue=3_000_000.0,
        outpatient_revenue=8_000_000.0,
        salary_expense=6_500_000.0,
        supply_expense=1_800_000.0,
        other_expense=2_200_000.0,
        cash_reserves=2_500_000.0,
        depreciation=500_000.0,
        annual_debt_service=400_000.0,
        payer_mix_government=0.73,
    )
end

@testset "Monte Carlo Engine" begin

    # -----------------------------------------------------------------------
    @testset "MonteCarloParams construction" begin
        params = MonteCarloParams()
        @test params.n_simulations == 1000
        @test params.seed == 42
        @test params.projection_years == 10
        @test params.volume_growth_mean == -0.01
        @test params.volume_growth_std == 0.02
    end

    # -----------------------------------------------------------------------
    @testset "Reproducibility with same seed" begin
        bf = make_mc_base_financials()
        params = MonteCarloParams(; n_simulations=100, seed=12345)

        result1 = run_monte_carlo(bf, params)
        result2 = run_monte_carlo(bf, params)

        @test result1.terminal_margins == result2.terminal_margins
        @test result1.mean_terminal_margin == result2.mean_terminal_margin
        @test result1.closure_probability == result2.closure_probability
    end

    # -----------------------------------------------------------------------
    @testset "Different seeds produce different results" begin
        bf = make_mc_base_financials()
        result_a = run_monte_carlo(bf, MonteCarloParams(; n_simulations=100, seed=1))
        result_b = run_monte_carlo(bf, MonteCarloParams(; n_simulations=100, seed=999))

        @test result_a.terminal_margins != result_b.terminal_margins
    end

    # -----------------------------------------------------------------------
    @testset "Distribution of results" begin
        bf = make_mc_base_financials()
        params = MonteCarloParams(; n_simulations=500, seed=42)
        result = run_monte_carlo(bf, params)

        @test length(result.terminal_margins) == 500
        @test result.p5_terminal_margin < result.mean_terminal_margin
        @test result.p95_terminal_margin > result.mean_terminal_margin
        @test result.p5_terminal_margin < result.p95_terminal_margin
        @test 0.0 <= result.closure_probability <= 1.0

        # Standard deviation should be non-zero (real variation)
        @test std(result.terminal_margins) > 0.0

        # Mean should be in a reasonable range for a typical CAH
        @test -0.50 < result.mean_terminal_margin < 0.50
    end

    # -----------------------------------------------------------------------
    @testset "Closure probability bounds" begin
        bf = make_mc_base_financials()
        params = MonteCarloParams(; n_simulations=200, seed=42)
        result = run_monte_carlo(bf, params)

        @test length(result.closure_probabilities) == params.projection_years
        @test all(0.0 .<= result.closure_probabilities .<= 1.0)
    end

    # -----------------------------------------------------------------------
    @testset "Stressed scenario — high closure probability" begin
        bf = (
            inpatient_revenue=1_500_000.0,
            outpatient_revenue=4_000_000.0,
            salary_expense=5_000_000.0,
            supply_expense=1_200_000.0,
            other_expense=1_500_000.0,
            cash_reserves=200_000.0,
            depreciation=300_000.0,
            annual_debt_service=300_000.0,
            payer_mix_government=0.80,
        )
        params = MonteCarloParams(;
            n_simulations=300,
            seed=42,
            volume_growth_mean=-0.03,
            volume_growth_std=0.02,
            cost_inflation_mean=0.05,
            cost_inflation_std=0.01,
        )
        result = run_monte_carlo(bf, params)

        # An already-losing, declining hospital should have significant closure risk
        @test result.closure_probability > 0.3
        @test result.mean_terminal_margin < 0.0
    end
end
