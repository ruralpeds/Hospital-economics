# Monte Carlo Simulation Engine
# Runs stochastic financial projections by sampling uncertain parameters
# from specified distributions and aggregating results.

using Distributions
using Random
using Statistics

"""
    DistributionalParameter{D<:Distribution}

A wrapper that pairs a named parameter with a probability distribution
from which values will be sampled during Monte Carlo iterations.

# Fields
- `name::Symbol`: Identifier for the parameter.
- `distribution::D`: A `Distributions.jl` distribution to sample from.
"""
struct DistributionalParameter{D<:Distribution}
    name::Symbol
    distribution::D
end

"""
    sample(dp::DistributionalParameter, rng::AbstractRNG) -> Float64

Draw a single sample from the distributional parameter.
"""
function sample(dp::DistributionalParameter, rng::AbstractRNG)::Float64
    return rand(rng, dp.distribution)
end

"""
    MonteCarloParams <: AbstractSimulationParams

Parameters governing Monte Carlo simulation of rural hospital financials.

# Fields
- `n_iterations::Int`: Number of Monte Carlo iterations to run.
- `projection_years::Int`: Projection horizon per iteration.
- `random_seed::Int`: Seed for reproducibility.
- `confidence_levels::Vector{Float64}`: Confidence levels for summary statistics (e.g., [0.05, 0.50, 0.95]).
- `volume_growth::DistributionalParameter`: Distribution for annual volume growth rate.
- `cost_inflation::DistributionalParameter`: Distribution for general cost inflation.
- `salary_inflation::DistributionalParameter`: Distribution for salary inflation.
- `supply_inflation::DistributionalParameter`: Distribution for supply cost inflation.
- `payer_mix_shift::DistributionalParameter`: Distribution for payer mix shift.
- `ma_penetration_growth::DistributionalParameter`: Distribution for Medicare Advantage penetration growth.
- `staffing_turnover::DistributionalParameter`: Distribution for annual staff turnover rate.
- `travel_nurse_premium::DistributionalParameter`: Distribution for travel nurse cost premium multiplier.
"""
struct MonteCarloParams <: AbstractSimulationParams
    n_iterations::Int
    projection_years::Int
    random_seed::Int
    confidence_levels::Vector{Float64}
    volume_growth::DistributionalParameter
    cost_inflation::DistributionalParameter
    salary_inflation::DistributionalParameter
    supply_inflation::DistributionalParameter
    payer_mix_shift::DistributionalParameter
    ma_penetration_growth::DistributionalParameter
    staffing_turnover::DistributionalParameter
    travel_nurse_premium::DistributionalParameter
end

"""
    MonteCarloParams(; kwargs...)

Construct `MonteCarloParams` with keyword arguments and reasonable default distributions
calibrated to rural hospital environments.
"""
function MonteCarloParams(;
    n_iterations::Int = 10_000,
    projection_years::Int = 10,
    random_seed::Int = 42,
    confidence_levels::Vector{Float64} = [0.05, 0.25, 0.50, 0.75, 0.95],
    volume_growth = DistributionalParameter(:volume_growth, Normal(-0.01, 0.02)),
    cost_inflation = DistributionalParameter(:cost_inflation, Normal(0.03, 0.01)),
    salary_inflation = DistributionalParameter(:salary_inflation, Normal(0.035, 0.015)),
    supply_inflation = DistributionalParameter(:supply_inflation, Normal(0.04, 0.012)),
    payer_mix_shift = DistributionalParameter(:payer_mix_shift, Normal(0.005, 0.003)),
    ma_penetration_growth = DistributionalParameter(:ma_penetration_growth, Normal(0.02, 0.01)),
    staffing_turnover = DistributionalParameter(:staffing_turnover, Beta(3.0, 12.0)),
    travel_nurse_premium = DistributionalParameter(:travel_nurse_premium, LogNormal(log(1.8), 0.2)),
)
    MonteCarloParams(
        n_iterations, projection_years, random_seed, confidence_levels,
        volume_growth, cost_inflation, salary_inflation, supply_inflation,
        payer_mix_shift, ma_penetration_growth, staffing_turnover, travel_nurse_premium,
    )
end

"""
    IterationResult

Results from a single Monte Carlo iteration.

# Fields
- `iteration::Int`: Iteration index.
- `terminal_operating_margin::Float64`: Operating margin in the final projection year.
- `cumulative_operating_income::Float64`: Sum of operating income over projection horizon.
- `closure_risk_year::Union{Int, Nothing}`: First year where margin < -10%, or `nothing`.
- `terminal_days_cash::Float64`: Days cash on hand at projection end.
- `sampled_params::Dict{Symbol, Float64}`: Parameter values sampled for this iteration.
"""
struct IterationResult
    iteration::Int
    terminal_operating_margin::Float64
    cumulative_operating_income::Float64
    closure_risk_year::Union{Int, Nothing}
    terminal_days_cash::Float64
    sampled_params::Dict{Symbol, Float64}
end

# MonteCarloSummary is defined in src/types/results.jl — do not redefine here.

# ---------------------------------------------------------------------------
# Core simulation
# ---------------------------------------------------------------------------

"""
    _sample_deterministic_params(mc_params, rng) -> DeterministicParams

Sample a single set of deterministic parameters from the distributional
parameters in `mc_params`.
"""
function _sample_deterministic_params(mc_params::MonteCarloParams, rng::AbstractRNG)
    return DeterministicParams(
        projection_years = mc_params.projection_years,
        volume_growth_rate = sample(mc_params.volume_growth, rng),
        cost_inflation_rate = sample(mc_params.cost_inflation, rng),
        salary_inflation_rate = sample(mc_params.salary_inflation, rng),
        supply_inflation_rate = sample(mc_params.supply_inflation, rng),
        reimbursement_adjustment = sample(mc_params.cost_inflation, rng) * 0.5,  # reimbursement lags inflation
        payer_mix_shift = sample(mc_params.payer_mix_shift, rng),
    )
end

"""
    _collect_sampled_params(mc_params, rng) -> Dict{Symbol, Float64}

Collect the sampled distributional parameter values into a dictionary
for record-keeping.
"""
function _collect_sampled_params(mc_params::MonteCarloParams, rng::AbstractRNG)::Dict{Symbol, Float64}
    return Dict{Symbol, Float64}(
        :volume_growth => sample(mc_params.volume_growth, rng),
        :cost_inflation => sample(mc_params.cost_inflation, rng),
        :salary_inflation => sample(mc_params.salary_inflation, rng),
        :supply_inflation => sample(mc_params.supply_inflation, rng),
        :payer_mix_shift => sample(mc_params.payer_mix_shift, rng),
        :ma_penetration_growth => sample(mc_params.ma_penetration_growth, rng),
        :staffing_turnover => sample(mc_params.staffing_turnover, rng),
        :travel_nurse_premium => sample(mc_params.travel_nurse_premium, rng),
    )
end

"""
    run_monte_carlo(hospital, params::MonteCarloParams) -> MonteCarloSummary

Run a full Monte Carlo simulation for `hospital`.

Each iteration samples parameter values from the distributional parameters,
runs a deterministic projection, and collects results. Iterations are
parallelised across available threads using `Threads.@threads`.
"""
function run_monte_carlo(hospital, params::MonteCarloParams)::MonteCarloSummary
    results = Vector{IterationResult}(undef, params.n_iterations)

    # Create per-thread RNGs for thread safety
    base_rng = MersenneTwister(params.random_seed)
    thread_seeds = rand(base_rng, UInt64, params.n_iterations)

    Threads.@threads for i in 1:params.n_iterations
        rng = MersenneTwister(thread_seeds[i])
        det_params = _sample_deterministic_params(params, rng)
        det_result = project_financials(hospital, det_params)

        sampled = _collect_sampled_params(params, rng)
        terminal_dcoh = isempty(det_result.projections) ? 0.0 : det_result.projections[end].days_cash_on_hand

        results[i] = IterationResult(
            i,
            det_result.terminal_operating_margin,
            det_result.cumulative_operating_income,
            det_result.closure_risk_year,
            terminal_dcoh,
            sampled,
        )
    end

    return _compute_summary(params, results)
end

"""
    _compute_summary(params, results) -> MonteCarloSummary

Aggregate individual iteration results into a summary with descriptive
statistics and risk metrics.
"""
function _compute_summary(params::MonteCarloParams, results::Vector{IterationResult})::MonteCarloSummary
    margins = [r.terminal_operating_margin for r in results]
    incomes = [r.cumulative_operating_income for r in results]
    cash_days = [r.terminal_days_cash for r in results]

    n = length(results)
    mean_margin = mean(margins)
    std_margin = std(margins)
    median_margin = quantile(margins, 0.50)

    p_closure = sum(!isnothing(r.closure_risk_year) for r in results) / n
    closure_years = [Float64(r.closure_risk_year) for r in results if !isnothing(r.closure_risk_year)]
    mean_cy = isempty(closure_years) ? nothing : mean(closure_years)

    # Conversion probability: fraction of iterations where margin is negative enough
    # that REH conversion would be financially beneficial (margin < -0.05 but no closure)
    conversion_candidates = count(r ->
        r.terminal_operating_margin < -0.05 && isnothing(r.closure_risk_year),
        results)
    conversion_prob = conversion_candidates / n

    mean_income = mean(incomes)
    prob_neg = count(x -> x < 0.0, incomes) / n
    mean_min_cash = mean(cash_days)

    # Year-by-year statistics are not tracked per-iteration here; provide empty vectors
    annual_means = Float64[]
    annual_closures = Float64[]

    return MonteCarloSummary(
        scenario_name = "",
        n_trials = n,
        n_years = params.projection_years,
        mean_operating_margin = mean_margin,
        median_operating_margin = median_margin,
        std_operating_margin = std_margin,
        p5_operating_margin = quantile(margins, 0.05),
        p25_operating_margin = quantile(margins, 0.25),
        p75_operating_margin = quantile(margins, 0.75),
        p95_operating_margin = quantile(margins, 0.95),
        closure_probability = p_closure,
        mean_closure_year = mean_cy,
        conversion_probability = conversion_prob,
        mean_cumulative_income = mean_income,
        prob_negative_cumulative = prob_neg,
        mean_min_cash_days = mean_min_cash,
        annual_mean_margins = annual_means,
        annual_closure_rates = annual_closures,
    )
end

# ---------------------------------------------------------------------------
# Risk metric helpers
# ---------------------------------------------------------------------------

"""
    probability_of_loss(results::Vector{IterationResult}) -> Float64

Compute the probability that the terminal operating margin is negative
(i.e., the hospital is operating at a loss in the final projected year).
"""
function probability_of_loss(results::Vector{IterationResult})::Float64
    isempty(results) && return 0.0
    return count(r -> r.terminal_operating_margin < 0.0, results) / length(results)
end

"""
    value_at_risk(values::Vector{Float64}, alpha::Float64) -> Float64

Compute the Value-at-Risk at confidence level `alpha`.
For `alpha = 0.05`, returns the 5th percentile of the distribution,
representing the worst-case outcome at 95% confidence.
"""
function value_at_risk(values::Vector{Float64}, alpha::Float64)::Float64
    isempty(values) && return 0.0
    return quantile(values, alpha)
end
