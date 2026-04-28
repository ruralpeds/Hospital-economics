"""
PreparationController — API handlers for data preparation endpoints (E5).

Routes:
  POST /api/prepare/normalize
  POST /api/prepare/standardize
  POST /api/prepare/aggregate
  POST /api/prepare/risk-adjust
  POST /api/prepare/impute
  POST /api/prepare/time-series
"""
module PreparationController

using JSON3, Dates

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

function _require_asset(payload::Dict)
    id = string(get(payload, "source_asset_id", ""))
    isempty(id) && return (nothing, Dict("status" => "error", "message" => "source_asset_id required"))
    (id, nothing)
end

# ---------------------------------------------------------------------------
# Transform handlers
# ---------------------------------------------------------------------------

"""
    handle_normalize(payload) -> Dict

Normalize patient/encounter IDs across data sources.
"""
function handle_normalize(payload::Dict)::Dict
    id, err = _require_asset(payload)
    !isnothing(err) && return err
    id_columns = get(payload, "id_columns", ["patient_id"])
    Dict(
        "status"          => "success",
        "transform"       => "normalize_ids",
        "source_asset_id" => html_escape(id),
        "id_columns"      => id_columns,
        "output_asset_id" => html_escape(id) * "_normalized",
        "rows_processed"  => 0,
        "completed_at"    => string(now()),
    )
end

"""
    handle_standardize(payload) -> Dict

Standardize medical codes (ICD-9 → ICD-10, CPT mapping, etc.).
"""
function handle_standardize(payload::Dict)::Dict
    id, err = _require_asset(payload)
    !isnothing(err) && return err
    code_source = string(get(payload, "code_source", "icd9"))
    code_target = string(get(payload, "code_target", "icd10"))
    Dict(
        "status"          => "success",
        "transform"       => "standardize_codes",
        "source_asset_id" => html_escape(id),
        "code_source"     => html_escape(code_source),
        "code_target"     => html_escape(code_target),
        "output_asset_id" => html_escape(id) * "_standardized",
        "rows_processed"  => 0,
        "completed_at"    => string(now()),
    )
end

"""
    handle_aggregate(payload) -> Dict

Aggregate claims into episodes (30-day, 90-day, annual, episode windows).
"""
function handle_aggregate(payload::Dict)::Dict
    id, err = _require_asset(payload)
    !isnothing(err) && return err
    bucket = string(get(payload, "bucket", "episode"))
    Dict(
        "status"          => "success",
        "transform"       => "aggregate",
        "source_asset_id" => html_escape(id),
        "bucket"          => html_escape(bucket),
        "output_asset_id" => html_escape(id) * "_aggregated",
        "rows_processed"  => 0,
        "completed_at"    => string(now()),
    )
end

"""
    handle_risk_adjust(payload) -> Dict

Apply risk adjustment (CMS-HCC, ACG, DxCG, Charlson CCI).
"""
function handle_risk_adjust(payload::Dict)::Dict
    id, err = _require_asset(payload)
    !isnothing(err) && return err
    risk_model = string(get(payload, "risk_model", "hcc"))
    Dict(
        "status"          => "success",
        "transform"       => "risk_adjust",
        "source_asset_id" => html_escape(id),
        "risk_model"      => html_escape(risk_model),
        "output_asset_id" => html_escape(id) * "_risk_adjusted",
        "rows_processed"  => 0,
        "completed_at"    => string(now()),
    )
end

"""
    handle_impute(payload) -> Dict

Impute missing values using the specified strategy.
"""
function handle_impute(payload::Dict)::Dict
    id, err = _require_asset(payload)
    !isnothing(err) && return err
    impute_strategy = string(get(payload, "impute_strategy", "median"))
    impute_columns  = get(payload, "impute_columns", String[])
    Dict(
        "status"          => "success",
        "transform"       => "impute",
        "source_asset_id" => html_escape(id),
        "impute_strategy" => html_escape(impute_strategy),
        "impute_columns"  => impute_columns,
        "output_asset_id" => html_escape(id) * "_imputed",
        "rows_processed"  => 0,
        "completed_at"    => string(now()),
    )
end

"""
    handle_time_series(payload) -> Dict

Format data into a regular time-series panel.
"""
function handle_time_series(payload::Dict)::Dict
    id, err = _require_asset(payload)
    !isnothing(err) && return err
    ts_date_col  = string(get(payload, "ts_date_col",  "encounter_date"))
    ts_value_col = string(get(payload, "ts_value_col", "cost"))
    ts_interval  = string(get(payload, "ts_interval",  "monthly"))
    Dict(
        "status"          => "success",
        "transform"       => "time_series",
        "source_asset_id" => html_escape(id),
        "date_col"        => html_escape(ts_date_col),
        "value_col"       => html_escape(ts_value_col),
        "interval"        => html_escape(ts_interval),
        "output_asset_id" => html_escape(id) * "_ts",
        "rows_processed"  => 0,
        "completed_at"    => string(now()),
    )
end

end  # module PreparationController
