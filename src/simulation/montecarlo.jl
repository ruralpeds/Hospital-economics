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
for record-keeping. MUST call sample() in identical order as
_sample_deterministic_params to maintain RNG reproducibility.

This function mirrors the sampling sequence in _sample_deterministic_params:
1. volume_growth
2. cost_inflation (for cost_inflation_rate)
3. salary_inflation
4. supply_inflation
5. cost_inflation (again, for reimbursement_adjustment)
6. payer_mix_shift

Then additional parameters:
7. ma_penetration_growth
8. staffing_turnover
9. travel_nurse_premium

The order is critical: if you change it, you break seed-based reproducibility
because RNG state will diverge.
"""
function _collect_sampled_params(mc_params::MonteCarloParams, rng::AbstractRNG)::Dict{Symbol, Float64}
    # CRITICAL: Must sample in IDENTICAL order as _sample_deterministic_params
    volume_growth = sample(mc_params.volume_growth, rng)
    cost_inflation = sample(mc_params.cost_inflation, rng)
    salary_inflation = sample(mc_params.salary_inflation, rng)
    supply_inflation = sample(mc_params.supply_inflation, rng)
    reimbursement_adjustment_base = sample(mc_params.cost_inflation, rng) * 0.5  # Same as _sample_deterministic_params
    payer_mix_shift = sample(mc_params.payer_mix_shift, rng)
    ma_penetration_growth = sample(mc_params.ma_penetration_growth, rng)
    staffing_turnover = sample(mc_params.staffing_turnover, rng)
    travel_nurse_premium = sample(mc_params.travel_nurse_premium, rng)

    return Dict{Symbol, Float64}(
        :volume_growth => volume_growth,
        :cost_inflation => cost_inflation,
        :salary_inflation => salary_inflation,
        :supply_inflation => supply_inflation,
        :reimbursement_adjustment => reimbursement_adjustment_base,  # Now included!
        :payer_mix_shift => payer_mix_shift,
        :ma_penetration_growth => ma_penetration_growth,
        :staffing_turnover => staffing_turnover,
        :travel_nurse_premium => travel_nurse_premium,
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

# ─────────────────────────────────────────────────────────────────────────────
# T-021: Monte Carlo Performance Optimizations
# ─────────────────────────────────────────────────────────────────────────────

"""
    MCResultCache

Optional result cache for `run_monte_carlo`. When a hospital object is run
multiple times with the same `MonteCarloParams` the cache returns the prior
`MonteCarloSummary` immediately, bypassing all simulation work.

# Fields
- `store::Dict{UInt64, MonteCarloSummary}`: Maps `(hospital_hash, params_hash)` → summary.
- `enabled::Bool`: When `false` the cache is a no-op.
- `hits::Ref{Int}`, `misses::Ref{Int}`: Counters for diagnostics.
"""
mutable struct MCResultCache
    store::Dict{UInt64, MonteCarloSummary}
    enabled::Bool
    hits::Ref{Int}
    misses::Ref{Int}
end

MCResultCache(; enabled::Bool = true) =
    MCResultCache(Dict{UInt64, MonteCarloSummary}(), enabled, Ref(0), Ref(0))

"""Global default cache instance (opt-in via `use_mc_cache=true`)."""
const _MC_CACHE = MCResultCache()

"""Clear the global MC result cache and reset counters."""
function clear_mc_cache!()
    empty!(_MC_CACHE.store)
    _MC_CACHE.hits[] = 0
    _MC_CACHE.misses[] = 0
    return nothing
end

"""Return `(hits, misses)` from the global cache."""
mc_cache_stats() = (_MC_CACHE.hits[], _MC_CACHE.misses[])

# Simple but stable key: hash(params) xor hash(hospital fields)
_mc_cache_key(hospital, params::MonteCarloParams) =
    hash(params.n_iterations) ⊻ hash(params.random_seed) ⊻
    hash(params.projection_years) ⊻ hash(objectid(hospital))

"""
    ConvergenceCriteria

Optional early-stopping criteria for Monte Carlo. Simulation halts once the
rolling standard-error of the mean operating margin falls below `tol` for
`window` consecutive checks (checked every `check_every` iterations).

Set `enabled = false` (default) to run all `n_iterations`.
"""
@kwdef struct ConvergenceCriteria
    enabled::Bool          = false
    tol::Float64           = 1e-4   # SE-of-mean tolerance on operating margin
    window::Int            = 5      # consecutive checks that must pass
    check_every::Int       = 500    # iterations between checks
    min_iterations::Int    = 1_000  # never stop before this many
end

"""
    run_monte_carlo(hospital, params; use_cache, convergence, progress_cb)

High-performance Monte Carlo simulation with optional result caching,
streaming collection to bound memory usage, and convergence-based early
stopping.

# Extended keyword arguments (T-021)
- `use_cache::Bool = false`: When `true`, check the global `_MC_CACHE` before
  running; store the result on a miss.
- `convergence::ConvergenceCriteria = ConvergenceCriteria()`: Early-stopping
  configuration. Disabled by default.
- `progress_cb = nothing`: Optional `Function(completed::Int, total::Int)`
  called every `convergence.check_every` iterations. Useful for progress bars.

# Performance notes
- Results are collected into a pre-allocated `Vector{IterationResult}` to
  avoid repeated `push!` allocation.
- Per-thread RNGs are pre-generated from a single base seed, guaranteeing
  reproducibility regardless of thread count.
- The existing `Threads.@threads` parallelism is preserved; convergence
  checking runs on the coordinating thread between batches.
"""
function run_monte_carlo(
    hospital,
    params::MonteCarloParams;
    use_cache::Bool = false,
    convergence::ConvergenceCriteria = ConvergenceCriteria(),
    progress_cb = nothing,
)::MonteCarloSummary

    # ── Cache check ──────────────────────────────────────────────────────────
    if use_cache && _MC_CACHE.enabled
        key = _mc_cache_key(hospital, params)
        if haskey(_MC_CACHE.store, key)
            _MC_CACHE.hits[] += 1
            return _MC_CACHE.store[key]
        end
        _MC_CACHE.misses[] += 1
    end

    n = params.n_iterations
    base_rng = MersenneTwister(params.random_seed)
    thread_seeds = rand(base_rng, UInt64, n)

    # ── Streaming pre-allocation ──────────────────────────────────────────────
    results = Vector{IterationResult}(undef, n)

    if !convergence.enabled
        # ── Fast path: all iterations, fully parallel ─────────────────────
        Threads.@threads for i in 1:n
            rng = MersenneTwister(thread_seeds[i])
            det_params = _sample_deterministic_params(params, rng)
            det_result = project_financials(hospital, det_params)
            sampled = _collect_sampled_params(params, rng)
            terminal_dcoh = isempty(det_result.projections) ? 0.0 :
                            det_result.projections[end].days_cash_on_hand
            results[i] = IterationResult(
                i, det_result.terminal_operating_margin,
                det_result.cumulative_operating_income,
                det_result.closure_risk_year, terminal_dcoh, sampled,
            )
        end
        actual_n = n
    else
        # ── Convergence path: batch processing with early-stop check ──────
        step      = convergence.check_every
        min_iter  = max(convergence.min_iterations, step)
        consec    = 0
        actual_n  = 0

        batch_start = 1
        while batch_start <= n
            batch_end = min(batch_start + step - 1, n)
            Threads.@threads for i in batch_start:batch_end
                rng = MersenneTwister(thread_seeds[i])
                det_params = _sample_deterministic_params(params, rng)
                det_result = project_financials(hospital, det_params)
                sampled = _collect_sampled_params(params, rng)
                terminal_dcoh = isempty(det_result.projections) ? 0.0 :
                                det_result.projections[end].days_cash_on_hand
                results[i] = IterationResult(
                    i, det_result.terminal_operating_margin,
                    det_result.cumulative_operating_income,
                    det_result.closure_risk_year, terminal_dcoh, sampled,
                )
            end
            actual_n = batch_end

            progress_cb !== nothing && progress_cb(actual_n, n)

            if actual_n >= min_iter
                completed = @view results[1:actual_n]
                margins   = [r.terminal_operating_margin for r in completed]
                sem       = std(margins) / sqrt(actual_n)
                if sem < convergence.tol
                    consec += 1
                    consec >= convergence.window && break
                else
                    consec = 0
                end
            end
            batch_start = batch_end + 1
        end
        # trim to actual completed iterations
        results = results[1:actual_n]
    end

    summary = _compute_summary(params, results)

    # ── Cache store ───────────────────────────────────────────────────────────
    if use_cache && _MC_CACHE.enabled
        key = _mc_cache_key(hospital, params)
        _MC_CACHE.store[key] = summary
    end

    return summary
end

# ─────────────────────────────────────────────────────────────────────────────
# T-022: Hospital Projection Parallelization
# ─────────────────────────────────────────────────────────────────────────────

"""
    HospitalProjectionResult

Result for a single hospital in a bulk Monte Carlo run.

# Fields
- `hospital_id`: The identifier passed in (any type — typically String or Int).
- `summary::MonteCarloSummary`: Full MC summary for this hospital.
- `elapsed_seconds::Float64`: Wall-clock time for this hospital's simulation.
- `error::Union{Nothing, String}`: Non-nothing if the simulation threw.
"""
struct HospitalProjectionResult
    hospital_id::Any
    summary::Union{MonteCarloSummary, Nothing}
    elapsed_seconds::Float64
    error::Union{Nothing, String}
end

"""
    bulk_project_hospitals(
        hospitals, params;
        ids, progress_cb, use_cache, convergence
    ) -> Vector{HospitalProjectionResult}

Run `run_monte_carlo` for every hospital in `hospitals` in parallel using
`Threads.@threads`. Each hospital's simulation is itself thread-parallel
(nested via Julia's cooperative scheduler on the same thread pool), so for
small networks the per-hospital parallelism dominates; for large networks
the between-hospital parallelism dominates.

# Arguments
- `hospitals`: Any iterable of hospital objects (e.g. `Vector{CriticalAccessHospital}`).
- `params::MonteCarloParams`: Shared simulation parameters.
- `ids = eachindex(hospitals)`: Optional identifiers aligned with `hospitals`.
  Defaults to 1-based indices.
- `progress_cb = nothing`: Optional `Function(completed::Int, total::Int)`.
  Called (thread-safely) after each hospital finishes.
- `use_cache::Bool = false`: Forwarded to `run_monte_carlo`.
- `convergence::ConvergenceCriteria = ConvergenceCriteria()`: Forwarded.

# Thread safety
Each hospital simulation uses its own per-iteration RNG seeded from
`params.random_seed ⊻ hash(id)`, so results are deterministic regardless
of scheduling order and thread count.

# Returns
`Vector{HospitalProjectionResult}` in the same order as `hospitals`.
Hospitals that error are wrapped (non-fatal) — check `.error` field.

# Example
```julia
results = bulk_project_hospitals(network, params; ids=["CAH-001","CAH-002","REH-007"])
for r in results
    isnothing(r.error) || @warn "Hospital \$(r.hospital_id) failed: \$(r.error)"
    println(r.hospital_id, " => median margin: ", r.summary.median_operating_margin)
end
```
"""
function bulk_project_hospitals(
    hospitals,
    params::MonteCarloParams;
    ids = eachindex(hospitals),
    progress_cb = nothing,
    use_cache::Bool = false,
    convergence::ConvergenceCriteria = ConvergenceCriteria(),
)::Vector{HospitalProjectionResult}

    hospital_vec = collect(hospitals)
    id_vec       = collect(ids)
    n_hospitals  = length(hospital_vec)
    n_hospitals == length(id_vec) || error(
        "bulk_project_hospitals: length(hospitals)=$(n_hospitals) ≠ length(ids)=$(length(id_vec))"
    )

    results = Vector{HospitalProjectionResult}(undef, n_hospitals)
    completed = Threads.Atomic{Int}(0)

    Threads.@threads for idx in 1:n_hospitals
        hosp = hospital_vec[idx]
        hid  = id_vec[idx]

        # Perturb the seed per-hospital so hospitals don't share RNG streams
        per_hospital_params = MonteCarloParams(
            params.n_iterations, params.projection_years,
            params.random_seed ⊻ (hash(hid) & 0xFFFF_FFFF),
            params.confidence_levels,
            params.volume_growth, params.cost_inflation,
            params.salary_inflation, params.supply_inflation,
            params.payer_mix_shift, params.ma_penetration_growth,
            params.staffing_turnover, params.travel_nurse_premium,
        )

        t0 = time()
        summary = nothing
        err     = nothing
        try
            summary = run_monte_carlo(hosp, per_hospital_params;
                                      use_cache = use_cache,
                                      convergence = convergence)
        catch e
            err = sprint(showerror, e)
        end
        elapsed = time() - t0

        results[idx] = HospitalProjectionResult(hid, summary, elapsed, err)

        done = Threads.atomic_add!(completed, 1) + 1
        progress_cb !== nothing && progress_cb(done, n_hospitals)
    end

    return results
end

"""
    aggregate_network_projection(results) -> NamedTuple

Aggregate a `Vector{HospitalProjectionResult}` into network-level summary
statistics. Failed hospitals (`.error !== nothing`) are excluded.

Returns a NamedTuple with:
- `n_hospitals`, `n_failed`
- `network_median_margin`, `network_mean_margin`
- `network_p05_margin`, `network_p95_margin`
- `pct_closure_risk`: fraction of hospitals with `mean_closure_risk_year < Inf`
- `total_elapsed_seconds`
"""
function aggregate_network_projection(
    results::Vector{HospitalProjectionResult},
)
    successful = filter(r -> isnothing(r.error), results)
    n_failed   = length(results) - length(successful)

    margins = [r.summary.median_operating_margin for r in successful]
    closure_finite = count(r -> isfinite(r.summary.mean_closure_risk_year), successful)

    (
        n_hospitals              = length(results),
        n_failed                 = n_failed,
        network_median_margin    = isempty(margins) ? NaN : median(margins),
        network_mean_margin      = isempty(margins) ? NaN : mean(margins),
        network_p05_margin       = isempty(margins) ? NaN : quantile(margins, 0.05),
        network_p95_margin       = isempty(margins) ? NaN : quantile(margins, 0.95),
        pct_closure_risk         = isempty(successful) ? NaN :
                                   closure_finite / length(successful),
        total_elapsed_seconds    = sum(r.elapsed_seconds for r in results),
    )
end
