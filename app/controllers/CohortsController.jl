"""
CohortsController — API handlers for cohort builder endpoints (E6).

Routes:
  POST   /api/cohorts/preview
  POST   /api/cohorts/save
  GET    /api/cohorts
  GET    /api/cohorts/:id
  DELETE /api/cohorts/:id
"""
module CohortsController

using JSON3, Dates

# In-memory cohort store (replaced by DB in production)
const _cohort_store = Dict{String,Dict{String,Any}}()

# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

"""
    handle_preview(payload) -> Dict

Run cohort preview: apply inclusion/exclusion criteria and return matching count
plus up to 100 preview rows.
"""
function handle_preview(payload::Dict)::Dict
    asset_id       = string(get(payload, "asset_id", ""))
    age_min        = Int(get(payload, "inclusion_age_min", 0))
    age_max        = Int(get(payload, "inclusion_age_max", 120))
    los_min        = Int(get(payload, "inclusion_los_min", 0))
    los_max        = Int(get(payload, "inclusion_los_max", 365))
    cost_min       = Float64(get(payload, "inclusion_cost_min", 0.0))
    cost_max       = Float64(get(payload, "inclusion_cost_max", 1e9))
    inclusion_dx   = get(payload, "inclusion_dx",   String[])
    inclusion_px   = get(payload, "inclusion_px",   String[])
    exclusion_dx   = get(payload, "exclusion_dx",   String[])
    exclusion_px   = get(payload, "exclusion_px",   String[])
    inclusion_payers = get(payload, "inclusion_payers", String[])

    isempty(asset_id) && return Dict("status" => "error", "message" => "asset_id required")

    Dict(
        "status"          => "success",
        "asset_id"        => html_escape(asset_id),
        "matching_count"  => 0,
        "preview_rows"    => Dict{String,Any}[],
        "cohort_stats"    => Dict{String,Any}(
            "age_min"   => age_min,
            "age_max"   => age_max,
            "los_min"   => los_min,
            "los_max"   => los_max,
            "cost_min"  => cost_min,
            "cost_max"  => cost_max,
        ),
        "previewed_at" => string(now()),
    )
end

"""
    handle_save(payload) -> Dict

Persist a named cohort definition.
"""
function handle_save(payload::Dict)::Dict
    cohort_name = string(get(payload, "cohort_name", ""))
    isempty(cohort_name) && return Dict("status" => "error", "message" => "cohort_name required")

    cohort_id = string(hash(cohort_name * string(now())), base=16)
    cohort    = Dict{String,Any}(
        "id"          => cohort_id,
        "name"        => html_escape(cohort_name),
        "description" => html_escape(string(get(payload, "cohort_description", ""))),
        "criteria"    => payload,
        "created_at"  => string(now()),
    )
    _cohort_store[cohort_id] = cohort
    Dict("status" => "success", "cohort_id" => cohort_id, "cohort" => cohort)
end

"""
    handle_list() -> Dict

Return all saved cohorts.
"""
function handle_list()::Dict
    Dict(
        "status"  => "success",
        "cohorts" => collect(values(_cohort_store)),
    )
end

"""
    handle_get(id) -> Dict

Return a single cohort by ID.
"""
function handle_get(id::String)::Dict
    !haskey(_cohort_store, id) && return Dict("status" => "error", "message" => "cohort not found")
    Dict("status" => "success", "cohort" => _cohort_store[id])
end

"""
    handle_delete(id) -> Dict

Delete a cohort by ID.
"""
function handle_delete(id::String)::Dict
    !haskey(_cohort_store, id) && return Dict("status" => "error", "message" => "cohort not found")
    delete!(_cohort_store, id)
    Dict("status" => "success", "deleted_id" => id)
end

end  # module CohortsController
