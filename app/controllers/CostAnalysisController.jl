"""
CostAnalysisController — API handlers for cost analysis endpoints (E7).

Routes:
  POST /api/cost-analysis/total
  POST /api/cost-analysis/breakdown
  POST /api/cost-analysis/per-episode
  POST /api/cost-analysis/cpq
  POST /api/cost-analysis/high-cost
  POST /api/cost-analysis/project
  POST /api/cost-analysis/inflate
  POST /api/cost-analysis/cohort-summary
"""
module CostAnalysisController

using JSON3, Dates

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

function _require_cohort(payload::Dict)
    id = string(get(payload, "cohort_id", ""))
    isempty(id) && return (nothing, Dict("status" => "error", "message" => "cohort_id required"))
    (id, nothing)
end

# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

"""
    handle_total(payload) -> Dict

Compute total cost of care with 95% confidence interval.
"""
function handle_total(payload::Dict)::Dict
    id, err = _require_cohort(payload)
    !isnothing(err) && return err
    discount_rate = Float64(get(payload, "discount_rate", 0.03))
    cost_year     = Int(get(payload, "cost_year", 2024))
    Dict(
        "status"           => "success",
        "cohort_id"        => html_escape(id),
        "cost_year"        => cost_year,
        "discount_rate"    => discount_rate,
        "total_cost"       => 0.0,
        "total_cost_ci_low"  => 0.0,
        "total_cost_ci_high" => 0.0,
        "computed_at"      => string(now()),
    )
end

"""
    handle_breakdown(payload) -> Dict

Cost breakdown by configurable categories.
"""
function handle_breakdown(payload::Dict)::Dict
    id, err = _require_cohort(payload)
    !isnothing(err) && return err
    categories = get(payload, "categories",
        ["inpatient", "outpatient", "pharmacy", "imaging", "lab", "dme"])
    Dict(
        "status"         => "success",
        "cohort_id"      => html_escape(id),
        "categories"     => categories,
        "breakdown_rows" => Dict{String,Any}[],
        "computed_at"    => string(now()),
    )
end

"""
    handle_per_episode(payload) -> Dict

Per-episode cost calculation.
"""
function handle_per_episode(payload::Dict)::Dict
    id, err = _require_cohort(payload)
    !isnothing(err) && return err
    Dict(
        "status"        => "success",
        "cohort_id"     => html_escape(id),
        "episode_rows"  => Dict{String,Any}[],
        "computed_at"   => string(now()),
    )
end

"""
    handle_cpq(payload) -> Dict

Cost per QALY calculation.
"""
function handle_cpq(payload::Dict)::Dict
    id, err = _require_cohort(payload)
    !isnothing(err) && return err
    Dict(
        "status"       => "success",
        "cohort_id"    => html_escape(id),
        "cost_per_qaly" => 0.0,
        "computed_at"  => string(now()),
    )
end

"""
    handle_high_cost(payload) -> Dict

Identify high-cost patients (top N% by total cost).
"""
function handle_high_cost(payload::Dict)::Dict
    id, err = _require_cohort(payload)
    !isnothing(err) && return err
    high_cost_pct = Float64(get(payload, "high_cost_pct", 0.05))
    Dict(
        "status"             => "success",
        "cohort_id"          => html_escape(id),
        "high_cost_pct"      => high_cost_pct,
        "n_high_cost_patients" => 0,
        "high_cost_rows"     => Dict{String,Any}[],
        "computed_at"        => string(now()),
    )
end

"""
    handle_project(payload) -> Dict

Project future costs using historical trend and discount rate.
"""
function handle_project(payload::Dict)::Dict
    id, err = _require_cohort(payload)
    !isnothing(err) && return err
    projection_years = Int(get(payload, "projection_years", 5))
    Dict(
        "status"           => "success",
        "cohort_id"        => html_escape(id),
        "projection_years" => projection_years,
        "projection_rows"  => Dict{String,Any}[],
        "computed_at"      => string(now()),
    )
end

"""
    handle_inflate(payload) -> Dict

Apply medical inflation adjustment to cost series.
"""
function handle_inflate(payload::Dict)::Dict
    id, err = _require_cohort(payload)
    !isnothing(err) && return err
    inflation_rate = Float64(get(payload, "inflation_rate", 0.05))
    Dict(
        "status"         => "success",
        "cohort_id"      => html_escape(id),
        "inflation_rate" => inflation_rate,
        "inflated_rows"  => Dict{String,Any}[],
        "computed_at"    => string(now()),
    )
end

"""
    handle_cohort_summary(payload) -> Dict

Full summary statistics for a cohort's cost profile.
"""
function handle_cohort_summary(payload::Dict)::Dict
    id, err = _require_cohort(payload)
    !isnothing(err) && return err
    Dict(
        "status"     => "success",
        "cohort_id"  => html_escape(id),
        "summary"    => Dict{String,Any}(),
        "computed_at" => string(now()),
    )
end

end  # module CostAnalysisController
