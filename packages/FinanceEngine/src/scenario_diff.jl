"""
    scenario_diff.jl — Scenario Diff and Comparison Engine (MBA Gap F-05)

Provides structured comparison between named financial scenarios:

1. **ScenarioDiff** — compares two or more scenarios against a baseline,
   producing a per-metric delta table with absolute and percentage changes.

2. **WaterfallBridge** — decomposes the difference between two scenarios into
   attributed line-item contributions, ready for a Plotly waterfall chart.

3. **ScenarioSet** — a named group of scenarios with metadata (assumptions,
   provenance, timestamps) for version-controlled scenario management.

4. **ScenarioRanking** — ranks scenarios by a user-chosen metric for board
   presentation (e.g. "which scenario produces the best 5-year operating margin?").

## Relationship to existing modules
- `scenario_persistence.jl` handles SQLite storage/retrieval of raw scenario data.
- `montecarlo.jl` produces distribution-level scenario outputs.
- This module is the **display layer**: it takes scenario outputs from any source
  and structures them for comparison, visualization, and memo generation.

## Design principle
All comparison types work with plain `Dict{String,Float64}` metric snapshots,
making them compatible with any upstream model (WACC, DCF, MC, stress test, etc.).
"""

using Dates
using Printf
using Statistics

# ─────────────────────────────────────────────────────────────────────────────
# Scenario snapshot (language-agnostic container)
# ─────────────────────────────────────────────────────────────────────────────

"""
    ScenarioSnapshot

One named scenario's financial metric values.

# Fields
- `id::Any`
- `name::String`
- `description::String`
- `metrics::Dict{String,Float64}`: Key-value pairs of metric name → value.
- `created_at::DateTime`
- `tags::Vector{String}`: e.g. ["adverse", "FY2026", "board-approved"]
- `source::String`: e.g. "CCAR stress test", "management projection", "DCF"
"""
@kwdef struct ScenarioSnapshot
    id::Any                          = 1
    name::String
    description::String              = ""
    metrics::Dict{String,Float64}
    created_at::DateTime             = now()
    tags::Vector{String}             = String[]
    source::String                   = ""
end

# ─────────────────────────────────────────────────────────────────────────────
# Scenario diff
# ─────────────────────────────────────────────────────────────────────────────

"""
    ScenarioDiffRow

One metric row in a scenario comparison table.

# Fields
- `metric::String`
- `baseline_value::Float64`
- `values::Dict{String,Float64}`: Scenario name → value.
- `deltas::Dict{String,Float64}`: Scenario name → (value − baseline).
- `delta_pcts::Dict{String,Float64}`: Scenario name → % change from baseline.
- `direction::Symbol`: `:higher_is_better`, `:lower_is_better`, or `:neutral`.
- `worst_scenario::String`: Scenario with the most unfavourable value.
- `best_scenario::String`: Scenario with the most favourable value.
"""
struct ScenarioDiffRow
    metric::String
    baseline_value::Float64
    values::Dict{String,Float64}
    deltas::Dict{String,Float64}
    delta_pcts::Dict{String,Float64}
    direction::Symbol
    worst_scenario::String
    best_scenario::String
end

"""
    ScenarioDiff

Complete structured comparison between a baseline and one or more scenarios.

# Fields
- `baseline::ScenarioSnapshot`
- `comparisons::Vector{ScenarioSnapshot}`: The non-baseline scenarios.
- `rows::Vector{ScenarioDiffRow}`: One per shared metric, sorted by metric name.
- `n_metrics::Int`
- `metric_directions::Dict{String,Symbol}`: User-supplied directional hints.
"""
struct ScenarioDiff
    baseline::ScenarioSnapshot
    comparisons::Vector{ScenarioSnapshot}
    rows::Vector{ScenarioDiffRow}
    n_metrics::Int
    metric_directions::Dict{String,Symbol}
end

"""
    STANDARD_METRIC_DIRECTIONS

Known direction conventions for common hospital financial metrics.
`:higher_is_better` or `:lower_is_better`.
"""
const STANDARD_METRIC_DIRECTIONS = Dict{String,Symbol}(
    "operating_margin"             => :higher_is_better,
    "total_margin"                 => :higher_is_better,
    "days_cash_on_hand"            => :higher_is_better,
    "mads_dscr"                    => :higher_is_better,
    "current_ratio"                => :higher_is_better,
    "net_patient_revenue"          => :higher_is_better,
    "net_operating_income"         => :higher_is_better,
    "free_cash_flow"               => :higher_is_better,
    "debt_to_cap"                  => :lower_is_better,
    "avg_age_of_plant"             => :lower_is_better,
    "salary_to_revenue"            => :lower_is_better,
    "days_ar_outstanding"          => :lower_is_better,
    "denial_rate"                  => :lower_is_better,
    "readmission_rate"             => :lower_is_better,
    "contract_labor_pct"           => :lower_is_better,
    "closure_probability_3yr"      => :lower_is_better,
)

"""
    compare_scenarios(
        baseline::ScenarioSnapshot,
        comparisons::Vector{ScenarioSnapshot};
        metric_directions, include_metrics
    ) -> ScenarioDiff

Build a structured scenario comparison table.

Only metrics present in the baseline are included. If a comparison scenario
is missing a metric, its value is shown as `NaN`.

# Arguments
- `baseline`: The reference scenario.
- `comparisons`: One or more scenarios to compare against the baseline.
- `metric_directions::Dict{String,Symbol}`: Overrides / additions to `STANDARD_METRIC_DIRECTIONS`.
- `include_metrics::Union{Nothing,Vector{String}}`: If provided, restricts to only these metrics.

# Example
```julia
baseline = ScenarioSnapshot(name="FY2026 Budget",
    metrics=Dict("operating_margin"=>0.028, "days_cash_on_hand"=>52.0,
                 "mads_dscr"=>1.32, "net_patient_revenue"=>8_500_000.0))
adverse  = ScenarioSnapshot(name="CCAR Adverse",
    metrics=Dict("operating_margin"=>-0.012, "days_cash_on_hand"=>38.0,
                 "mads_dscr"=>0.98, "net_patient_revenue"=>7_900_000.0))
diff = compare_scenarios(baseline, [adverse])
for r in diff.rows
    println(r.metric, " | baseline: ", r.baseline_value,
            " | adverse: ", get(r.values, "CCAR Adverse", NaN))
end
```
"""
function compare_scenarios(
    baseline::ScenarioSnapshot,
    comparisons::Vector{ScenarioSnapshot};
    metric_directions::Dict{String,Symbol} = Dict{String,Symbol}(),
    include_metrics::Union{Nothing,Vector{String}} = nothing,
)::ScenarioDiff

    all_directions = merge(STANDARD_METRIC_DIRECTIONS, metric_directions)

    metrics_to_compare = isnothing(include_metrics) ?
        sort(collect(keys(baseline.metrics))) :
        filter(m -> haskey(baseline.metrics, m), include_metrics)

    rows = map(metrics_to_compare) do metric
        base_val = baseline.metrics[metric]
        direction = get(all_directions, metric, :neutral)

        vals    = Dict{String,Float64}()
        deltas  = Dict{String,Float64}()
        pcts    = Dict{String,Float64}()
        for sc in comparisons
            v = get(sc.metrics, metric, NaN)
            vals[sc.name]   = v
            deltas[sc.name] = isnan(v) ? NaN : v - base_val
            pcts[sc.name]   = (isnan(v) || base_val == 0) ? NaN :
                               (v - base_val) / abs(base_val) * 100
        end

        # Best/worst scenario
        valid_comparisons = filter(kv -> !isnan(kv[2]), vals)
        best_sc  = if isempty(valid_comparisons)
            "—"
        elseif direction == :higher_is_better
            first(sort(collect(valid_comparisons); by=kv->-kv[2]))[1]
        elseif direction == :lower_is_better
            first(sort(collect(valid_comparisons); by=kv->kv[2]))[1]
        else
            first(sort(collect(valid_comparisons); by=kv->-abs(kv[2] - base_val)))[1]
        end
        worst_sc = if isempty(valid_comparisons)
            "—"
        elseif direction == :higher_is_better
            first(sort(collect(valid_comparisons); by=kv->kv[2]))[1]
        elseif direction == :lower_is_better
            first(sort(collect(valid_comparisons); by=kv->-kv[2]))[1]
        else
            best_sc
        end

        ScenarioDiffRow(metric, base_val, vals, deltas, pcts, direction, worst_sc, best_sc)
    end

    ScenarioDiff(baseline, comparisons, rows, length(rows), all_directions)
end

# ─────────────────────────────────────────────────────────────────────────────
# Waterfall bridge
# ─────────────────────────────────────────────────────────────────────────────

"""
    WaterfallStep

One step in a waterfall chart.

# Fields
- `label::String`
- `value::Float64`: Contribution (positive = upward bar, negative = downward).
- `running_total::Float64`: Cumulative sum after this step.
- `category::Symbol`: `:start`, `:positive`, `:negative`, `:subtotal`, `:total`.
- `color::String`: Plotly color hex.
"""
struct WaterfallStep
    label::String
    value::Float64
    running_total::Float64
    category::Symbol
    color::String
end

"""
    build_waterfall(
        start_label::String, start_value::Float64,
        contributions::Vector{NamedTuple},
        end_label::String
    ) -> Vector{WaterfallStep}

Build a waterfall chart data structure from a set of labelled contributions.

`contributions`: Vector of NamedTuples with `(label, value)` fields.
Positive values add to the running total; negative values subtract.

# Example
```julia
steps = build_waterfall(
    "FY2025 Revenue", 8_500_000.0,
    [
        (label="Volume growth",    value= 210_000.0),
        (label="Rate improvement", value= 185_000.0),
        (label="MA penetration",   value=-145_000.0),
        (label="Medicaid shift",   value= -88_000.0),
    ],
    "FY2026 Revenue"
)
```
"""
function build_waterfall(
    start_label::String,
    start_value::Float64,
    contributions::Vector{<:NamedTuple},
    end_label::String,
)::Vector{WaterfallStep}
    steps = WaterfallStep[
        WaterfallStep(start_label, start_value, start_value, :start, "#6366f1"),
    ]
    running = start_value

    for c in contributions
        v = Float64(c.value)
        running += v
        cat = v >= 0 ? :positive : :negative
        color = v >= 0 ? "#22c55e" : "#ef4444"
        push!(steps, WaterfallStep(string(c.label), v, running, cat, color))
    end

    push!(steps, WaterfallStep(end_label, running, running, :total, "#6366f1"))
    steps
end

# ─────────────────────────────────────────────────────────────────────────────
# Scenario set management
# ─────────────────────────────────────────────────────────────────────────────

"""
    ScenarioSet

A versioned collection of related scenarios (e.g. FY2026 budget cycle).

# Fields
- `id::Any`
- `name::String`: e.g. "FY2026 CCAR Scenarios".
- `description::String`
- `scenarios::Vector{ScenarioSnapshot}`: The scenarios in this set.
- `baseline_id::Any`: ID of the baseline scenario.
- `created_at::DateTime`
- `approved_by::String`
- `version::Int`
"""
@kwdef struct ScenarioSet
    id::Any                                = 1
    name::String
    description::String                    = ""
    scenarios::Vector{ScenarioSnapshot}
    baseline_id::Any                       = nothing
    created_at::DateTime                   = now()
    approved_by::String                    = ""
    version::Int                           = 1
end

"""
    scenario_set_diff(set::ScenarioSet; metric::String = "operating_margin") -> ScenarioDiff

Compare all scenarios in a set against the designated baseline.
"""
function scenario_set_diff(
    set::ScenarioSet;
    kwargs...
)::ScenarioDiff
    isempty(set.scenarios) && throw(ArgumentError("ScenarioSet has no scenarios"))

    baseline_idx = if !isnothing(set.baseline_id)
        findfirst(s -> s.id == set.baseline_id, set.scenarios)
    else
        1
    end
    baseline_idx = isnothing(baseline_idx) ? 1 : baseline_idx
    baseline  = set.scenarios[baseline_idx]
    others    = [s for s in set.scenarios if s.id != baseline.id]

    compare_scenarios(baseline, others; kwargs...)
end

# ─────────────────────────────────────────────────────────────────────────────
# Scenario ranking
# ─────────────────────────────────────────────────────────────────────────────

"""
    rank_scenarios(
        scenarios::Vector{ScenarioSnapshot},
        rank_metric::String;
        higher_is_better = true,
        include_baseline_id = nothing
    ) -> Vector{NamedTuple}

Rank scenarios by a single metric, with optional baseline reference.

Returns sorted Vector of NamedTuples:
`(rank, name, metric_value, delta_from_baseline, id, tags)`.
"""
function rank_scenarios(
    scenarios::Vector{ScenarioSnapshot},
    rank_metric::String;
    higher_is_better::Bool = true,
    include_baseline_id = nothing,
)::Vector{NamedTuple}
    scored = map(scenarios) do sc
        val = get(sc.metrics, rank_metric, NaN)
        (id=sc.id, name=sc.name, metric_value=val,
         tags=sc.tags, source=sc.source)
    end

    # Sort by metric value
    sort!(scored; by=r -> isnan(r.metric_value) ? -Inf : r.metric_value,
          rev=higher_is_better)

    # Add rank and baseline delta
    baseline_val = if !isnothing(include_baseline_id)
        idx = findfirst(s -> s.id == include_baseline_id, scenarios)
        isnothing(idx) ? NaN : get(scenarios[idx].metrics, rank_metric, NaN)
    else
        NaN
    end

    map(enumerate(scored)) do (i, r)
        delta = isnan(baseline_val) ? NaN : r.metric_value - baseline_val
        (
            rank              = i,
            name              = r.name,
            metric_value      = r.metric_value,
            delta_from_base   = delta,
            id                = r.id,
            tags              = r.tags,
        )
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Rendering
# ─────────────────────────────────────────────────────────────────────────────

"""
    scenario_diff_table(diff::ScenarioDiff) -> String

Render a `ScenarioDiff` as a Markdown table.
"""
function scenario_diff_table(diff::ScenarioDiff)::String
    io = IOBuffer()
    n_sc = length(diff.comparisons)
    scenario_names = [s.name for s in diff.comparisons]

    # Header
    header_cols = ["Metric", "Baseline", scenario_names..., "Direction"]
    println(io, "| " * join(header_cols, " | ") * " |")
    println(io, "|" * join(["---" for _ in header_cols], "|") * "|")

    for row in diff.rows
        dir_icon = row.direction == :higher_is_better ? "▲ better" :
                   row.direction == :lower_is_better  ? "▼ better" : "●"
        base_str = _fmt_scenario_val(row.baseline_value, row.metric)
        sc_strs  = [begin
            v = get(row.values, n, NaN)
            d = get(row.delta_pcts, n, NaN)
            isnan(v) ? "—" : _fmt_scenario_val(v, row.metric) *
                (isnan(d) ? "" : @sprintf(" (%+.1f%%)", d))
        end for n in scenario_names]
        println(io, "| $(row.metric) | $(base_str) | " *
            join(sc_strs, " | ") * " | $(dir_icon) |")
    end
    String(take!(io))
end

function _fmt_scenario_val(v::Float64, metric::String)::String
    if contains(metric, "margin") || contains(metric, "pct") || contains(metric, "rate")
        @sprintf("%.1f%%", v * 100)
    elseif contains(metric, "revenue") || contains(metric, "income") || contains(metric, "cost")
        abs(v) >= 1e6 ? @sprintf("\$%.1fM", v/1e6) : @sprintf("\$%.0fK", v/1e3)
    elseif contains(metric, "days") || contains(metric, "dso") || contains(metric, "dcoh")
        @sprintf("%.0f d", v)
    elseif contains(metric, "dscr") || contains(metric, "ratio")
        @sprintf("%.2f×", v)
    else
        @sprintf("%.2f", v)
    end
end
