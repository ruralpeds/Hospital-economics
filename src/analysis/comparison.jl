# ============================================================================
# Scenario Comparison Framework
# ============================================================================

"""
    ScenarioComparison

Tabular comparison of multiple simulation scenarios across a common set of
financial and operational metrics.

# Fields
- `scenario_names::Vector{String}`: human-readable labels for each scenario.
- `metric_names::Vector{String}`: names of the metrics being compared.
- `values::Matrix{Float64}`: matrix of size `(n_scenarios, n_metrics)`.
- `base_scenario_idx::Int`: 1-based index of the baseline scenario.

# Example
```julia
cmp = ScenarioComparison(
    scenario_names = ["Baseline", "REH Conversion", "Service Expansion"],
    metric_names   = ["operating_margin", "total_revenue", "days_cash_on_hand"],
    values         = [0.02 15_000_000 45.0;
                      0.05 12_000_000 60.0;
                     -0.01 18_000_000 30.0],
    base_scenario_idx = 1,
)
```
"""
struct ScenarioComparison
    scenario_names::Vector{String}
    metric_names::Vector{String}
    values::Matrix{Float64}   # scenarios × metrics
    base_scenario_idx::Int

    function ScenarioComparison(scenario_names, metric_names, values, base_scenario_idx)
        n_scen, n_met = size(values)
        length(scenario_names) == n_scen ||
            error("scenario_names length ($(length(scenario_names))) must match rows of values ($n_scen)")
        length(metric_names) == n_met ||
            error("metric_names length ($(length(metric_names))) must match columns of values ($n_met)")
        1 <= base_scenario_idx <= n_scen ||
            error("base_scenario_idx ($base_scenario_idx) out of range 1:$n_scen")
        new(scenario_names, metric_names, values, base_scenario_idx)
    end
end

function Base.show(io::IO, sc::ScenarioComparison)
    n = length(sc.scenario_names)
    m = length(sc.metric_names)
    base = sc.scenario_names[sc.base_scenario_idx]
    print(io, "ScenarioComparison($(n) scenarios, $(m) metrics, base=\"$(base)\")")
end

# ---------------------------------------------------------------------------
# Metric extraction helpers
# ---------------------------------------------------------------------------

const DEFAULT_COMPARISON_METRICS = [:operating_margin, :total_revenue, :days_cash_on_hand]

"""
    _extract_metric(result::AbstractSimulationResult, metric::Symbol) -> Float64

Extract a numeric metric from a simulation result.  Falls back to `getfield`
when the result carries the field directly; otherwise applies common derived
metric logic for Monte Carlo summaries and system dynamics results.
"""
function _extract_metric(result::AbstractSimulationResult, metric::Symbol)::Float64
    # MonteCarloResult (single trial)
    if result isa MonteCarloResult
        metric == :operating_margin && return result.final_year_margin
        metric == :total_revenue && return isempty(result.net_revenues) ? 0.0 : last(result.net_revenues)
        metric == :days_cash_on_hand && return isempty(result.cash_on_hand_days) ? 0.0 : last(result.cash_on_hand_days)
        metric == :closure_probability && return result.is_closure ? 1.0 : 0.0
    end

    # DeterministicResult
    if result isa DeterministicResult
        metric == :operating_margin && return result.terminal_operating_margin
        metric == :total_revenue && return isempty(result.projections) ? 0.0 : result.projections[end].total_revenue
        metric == :days_cash_on_hand && return isempty(result.projections) ? 0.0 : result.projections[end].days_cash_on_hand
    end

    if result isa SystemDynamicsResult
        metric == :operating_margin && return isempty(result.operating_margin) ? 0.0 : last(result.operating_margin)
        metric == :total_revenue && return isempty(result.net_revenue) ? 0.0 : last(result.net_revenue)
        metric == :days_cash_on_hand && return 0.0  # not directly available
    end

    # Generic field access
    if hasfield(typeof(result), metric)
        val = getfield(result, metric)
        return val isa Number ? Float64(val) : 0.0
    end

    return 0.0
end

# ---------------------------------------------------------------------------
# Core API
# ---------------------------------------------------------------------------

"""
    compare_scenarios(results::Vector{<:AbstractSimulationResult};
                      names::Vector{String}=String[],
                      metrics::Vector{Symbol}=DEFAULT_COMPARISON_METRICS) -> ScenarioComparison

Build a `ScenarioComparison` from a vector of simulation results.  The first
result is used as the baseline by default.

# Arguments
- `results`: one result per scenario.
- `names`: optional friendly names (defaults to `"Scenario 1"`, `"Scenario 2"`, ...).
- `metrics`: which numeric metrics to extract from each result.

# Example
```julia
r1 = run_monte_carlo(hospital1, params1)
r2 = run_monte_carlo(hospital2, params2)
cmp = compare_scenarios([r1, r2]; names=["Status Quo", "Growth"], metrics=[:operating_margin, :total_revenue])
```
"""
function compare_scenarios(results::Vector{<:AbstractSimulationResult};
                           names::Vector{String}=String[],
                           metrics::Vector{Symbol}=DEFAULT_COMPARISON_METRICS)
    n = length(results)
    n >= 1 || error("At least one result is required for comparison")

    scenario_names = if isempty(names)
        # Try to pull scenario_name field; fall back to numbered labels
        map(enumerate(results)) do (i, r)
            if hasfield(typeof(r), :scenario_name)
                sn = getfield(r, :scenario_name)
                isempty(sn) ? "Scenario $i" : sn
            else
                "Scenario $i"
            end
        end
    else
        length(names) == n || error("names length ($(length(names))) must match results length ($n)")
        names
    end

    metric_names = String.(metrics)
    values = Matrix{Float64}(undef, n, length(metrics))

    for (i, result) in enumerate(results)
        for (j, metric) in enumerate(metrics)
            values[i, j] = _extract_metric(result, metric)
        end
    end

    return ScenarioComparison(scenario_names, metric_names, values, 1)
end

"""
    rank_scenarios(comparison::ScenarioComparison;
                   weights::Dict{String,Float64}=Dict{String,Float64}()) -> Vector{Int}

Rank scenarios from best (index 1) to worst using a weighted-sum scoring method.

Each metric is min-max normalised across scenarios so that the *best* value
receives a score of 1.0 and the *worst* receives 0.0.  By default every metric
is equally weighted; supply `weights` (metric name -> weight) to override.

Returns a vector of scenario indices sorted from best to worst.

# Example
```julia
ranking = rank_scenarios(cmp; weights=Dict("operating_margin" => 0.6, "total_revenue" => 0.4))
println("Best scenario: ", cmp.scenario_names[ranking[1]])
```
"""
function rank_scenarios(comparison::ScenarioComparison;
                        weights::Dict{String,Float64}=Dict{String,Float64}())
    n_scen, n_met = size(comparison.values)
    n_scen <= 1 && return [1]

    # Build weight vector; default to equal weights
    w = Float64[]
    for mname in comparison.metric_names
        push!(w, get(weights, mname, 1.0))
    end
    total_w = sum(w)
    total_w > 0 && (w ./= total_w)

    # Min-max normalise each metric column (higher is assumed better)
    normed = similar(comparison.values)
    for j in 1:n_met
        col = comparison.values[:, j]
        lo, hi = minimum(col), maximum(col)
        if lo ≈ hi
            normed[:, j] .= 0.5
        else
            normed[:, j] .= (col .- lo) ./ (hi - lo)
        end
    end

    # Weighted composite score per scenario
    scores = normed * w

    # Return indices sorted by score descending (best first)
    return sortperm(scores; rev=true)
end

"""
    scenario_delta(comparison::ScenarioComparison, scenario_idx::Int) -> Dict{String,Float64}

Compute the absolute difference between a given scenario and the base scenario
for every metric.

# Example
```julia
delta = scenario_delta(cmp, 2)
println("Operating margin change: ", delta["operating_margin"])
```
"""
function scenario_delta(comparison::ScenarioComparison, scenario_idx::Int)
    1 <= scenario_idx <= length(comparison.scenario_names) ||
        error("scenario_idx ($scenario_idx) out of range")
    base = comparison.base_scenario_idx
    deltas = Dict{String,Float64}()
    for (j, mname) in enumerate(comparison.metric_names)
        deltas[mname] = comparison.values[scenario_idx, j] - comparison.values[base, j]
    end
    return deltas
end
