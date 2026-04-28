"""
ComparativeController — API handlers for comparative effectiveness endpoints (E16).

Routes:
  POST /api/comparative/outcomes
  POST /api/comparative/patterns
  POST /api/comparative/variation
  POST /api/comparative/benchmark
  POST /api/comparative/smr
  POST /api/comparative/subgroup
  POST /api/comparative/interaction
"""
module ComparativeController

using JSON3, Dates

function handle_outcomes(payload::Dict)::Dict
    try
        cohort_id     = html_escape(string(get(payload, "cohort_id",     "")))
        treatment_col = html_escape(string(get(payload, "treatment_col", "")))
        outcome_col   = html_escape(string(get(payload, "outcome_col",   "")))
        Dict(
            "status"       => "success",
            "cohort_id"    => cohort_id,
            "result_rows"  => Dict{String,Any}[],
            "computed_at"  => string(now()),
        )
    catch e
        Dict("status" => "error", "message" => sprint(showerror, e))
    end
end

function handle_patterns(payload::Dict)::Dict
    try
        Dict(
            "status"      => "success",
            "result_rows" => Dict{String,Any}[],
            "computed_at" => string(now()),
        )
    catch e
        Dict("status" => "error", "message" => sprint(showerror, e))
    end
end

function handle_variation(payload::Dict)::Dict
    try
        provider_col = html_escape(string(get(payload, "provider_col", "")))
        Dict(
            "status"       => "success",
            "provider_col" => provider_col,
            "result_rows"  => Dict{String,Any}[],
            "computed_at"  => string(now()),
        )
    catch e
        Dict("status" => "error", "message" => sprint(showerror, e))
    end
end

function handle_benchmark(payload::Dict)::Dict
    try
        Dict(
            "status"      => "success",
            "result_rows" => Dict{String,Any}[],
            "computed_at" => string(now()),
        )
    catch e
        Dict("status" => "error", "message" => sprint(showerror, e))
    end
end

function handle_smr(payload::Dict)::Dict
    try
        facility_id = html_escape(string(get(payload, "facility_id", "")))
        Dict(
            "status"      => "success",
            "facility_id" => facility_id,
            "smr_rows"    => Dict{String,Any}[],
            "computed_at" => string(now()),
        )
    catch e
        Dict("status" => "error", "message" => sprint(showerror, e))
    end
end

function handle_subgroup(payload::Dict)::Dict
    try
        subgroup_col = html_escape(string(get(payload, "subgroup_col", "")))
        Dict(
            "status"       => "success",
            "subgroup_col" => subgroup_col,
            "result_rows"  => Dict{String,Any}[],
            "computed_at"  => string(now()),
        )
    catch e
        Dict("status" => "error", "message" => sprint(showerror, e))
    end
end

function handle_interaction(payload::Dict)::Dict
    try
        modifier_col = html_escape(string(get(payload, "modifier_col", "")))
        Dict(
            "status"       => "success",
            "modifier_col" => modifier_col,
            "result_rows"  => Dict{String,Any}[],
            "computed_at"  => string(now()),
        )
    catch e
        Dict("status" => "error", "message" => sprint(showerror, e))
    end
end

end  # module ComparativeController
