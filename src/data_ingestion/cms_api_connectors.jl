"""
    cms_api_connectors.jl — Connectors for CMS public-data APIs

Pull hospital-level reference data directly from CMS public endpoints
(no PHI; these are population-level and hospital-aggregate datasets).

Connectors covered:
- Hospital Compare / Care Compare general info dataset
- Provider of Services (POS) hospital file
- Medicare Outpatient Standard Analytical File (OPSAF) summary
- Medicare Provider Utilization & Payment Data — Inpatient (PUF)

All connectors:
- Cache responses to disk (default `data/cms_cache/`)
- Return a `DataFrame` with normalized column names
- Emit `AuditLogEntry` records for the pull
"""

using HTTP
using JSON3
using CSV
using DataFrames
using Dates

const CMS_DEFAULT_CACHE = joinpath(@__DIR__, "..", "..", "data", "cms_cache")

# CMS Provider Data Catalog dataset IDs (stable resource UUIDs published by CMS).
# Override at call site if CMS reissues a dataset under a new UUID.
const CMS_DATASET_IDS = Dict(
    "hospital_general_info" => "xubh-q36u",   # Hospital General Information
    "pos_hospital"          => "p2hk-2it7",   # Provider of Services (Hospital)
    "opsaf_summary"         => "kawe-3vwn",   # Medicare Outpatient by Provider
    "puf_inpatient"         => "97k6-zzx3",   # Medicare Inpatient Hospitals by Provider
)

const CMS_BASE_URL = "https://data.cms.gov/provider-data/api/1/datastore/query"

"""
    CmsPullResult

Outcome of a CMS dataset pull.
"""
struct CmsPullResult
    dataset::String
    rows::DataFrame
    cached::Bool
    cache_path::String
    fetched_at::DateTime
    audit::AuditLogEntry
end

"""
    fetch_cms_dataset(dataset_key::String;
                      cache_dir::String = CMS_DEFAULT_CACHE,
                      force_refresh::Bool = false,
                      limit::Int = 0,
                      filters::Dict{String,Any} = Dict{String,Any}(),
                      user_id::String = "system")::CmsPullResult

Generic CMS Provider Data Catalog datastore query. `dataset_key` is one of
the keys in `CMS_DATASET_IDS` or a raw CMS resource UUID.

`limit = 0` means "fetch all pages". `filters` are passed through as
field-equality conditions in the CMS datastore query DSL.
"""
function fetch_cms_dataset(
    dataset_key::String;
    cache_dir::String = CMS_DEFAULT_CACHE,
    force_refresh::Bool = false,
    limit::Int = 0,
    filters::Dict{String,Any} = Dict{String,Any}(),
    user_id::String = "system",
)::CmsPullResult
    resource_id = get(CMS_DATASET_IDS, dataset_key, dataset_key)
    mkpath(cache_dir)
    cache_path = joinpath(cache_dir, "$(dataset_key).csv")

    if isfile(cache_path) && !force_refresh
        df = CSV.read(cache_path, DataFrame)
        audit = AuditLogEntry(
            user_id, "CMS_FETCH_CACHED", "INGESTION";
            resource_type = "CMS_DATASET",
            resource_id = dataset_key,
            details = Dict{String,Any}("rows" => nrow(df), "path" => cache_path),
            status = "SUCCESS",
            record_count = nrow(df),
        )
        return CmsPullResult(dataset_key, df, true, cache_path, now(), audit)
    end

    rows = _cms_paged_query(resource_id; limit = limit, filters = filters)
    df = isempty(rows) ? DataFrame() : DataFrame(rows)
    df = _normalize_column_names(df)
    CSV.write(cache_path, df)

    audit = AuditLogEntry(
        user_id, "CMS_FETCH", "INGESTION";
        resource_type = "CMS_DATASET",
        resource_id = dataset_key,
        details = Dict{String,Any}(
            "rows" => nrow(df),
            "resource_uuid" => resource_id,
            "path" => cache_path,
        ),
        status = "SUCCESS",
        record_count = nrow(df),
    )
    return CmsPullResult(dataset_key, df, false, cache_path, now(), audit)
end

"""
    fetch_hospital_general_info(; kwargs...) -> CmsPullResult

Hospital Compare / Care Compare general info (one row per hospital,
including overall star rating, ownership type, hospital type).
"""
fetch_hospital_general_info(; kwargs...) =
    fetch_cms_dataset("hospital_general_info"; kwargs...)

"""
    fetch_pos_hospital(; kwargs...) -> CmsPullResult

Provider of Services file (hospital subset) — facility-level
Medicare certification, bed counts, services offered.
"""
fetch_pos_hospital(; kwargs...) =
    fetch_cms_dataset("pos_hospital"; kwargs...)

"""
    fetch_opsaf_summary(; kwargs...) -> CmsPullResult

Medicare Outpatient Standard Analytical File summary — aggregate
outpatient utilization and spending by provider/HCPCS.
"""
fetch_opsaf_summary(; kwargs...) =
    fetch_cms_dataset("opsaf_summary"; kwargs...)

"""
    fetch_puf_inpatient(; kwargs...) -> CmsPullResult

Medicare Inpatient Hospitals by Provider — PUF with average covered
charges, total payments, and beneficiary counts by MS-DRG.
"""
fetch_puf_inpatient(; kwargs...) =
    fetch_cms_dataset("puf_inpatient"; kwargs...)

# ── Internal helpers ──────────────────────────────────────────────────────────

const _CMS_PAGE_SIZE = 1000

function _cms_paged_query(
    resource_id::String;
    limit::Int = 0,
    filters::Dict{String,Any} = Dict{String,Any}(),
)
    rows = Vector{Dict{String,Any}}()
    offset = 0
    while true
        page_size = limit > 0 ? min(_CMS_PAGE_SIZE, limit - length(rows)) : _CMS_PAGE_SIZE
        page_size <= 0 && break

        body = Dict{String,Any}(
            "resources" => [Dict("id" => resource_id, "alias" => "t")],
            "limit" => page_size,
            "offset" => offset,
        )
        if !isempty(filters)
            body["conditions"] = [
                Dict("resource" => "t", "property" => k, "value" => v, "operator" => "=")
                for (k, v) in filters
            ]
        end

        resp = HTTP.request(
            "POST",
            CMS_BASE_URL;
            headers = ["Content-Type" => "application/json", "Accept" => "application/json"],
            body = JSON3.write(body),
            readtimeout = 60,
            retry = false,
        )
        resp.status >= 400 && error("CMS API HTTP $(resp.status): $(String(resp.body))")

        payload = JSON3.read(resp.body)
        page_rows = haskey(payload, :results) ? payload[:results] : payload[:data]
        page_rows === nothing && break
        page = [Dict{String,Any}(string(k) => v for (k, v) in pairs(r)) for r in page_rows]
        append!(rows, page)

        length(page) < page_size && break
        offset += page_size
        limit > 0 && length(rows) >= limit && break
    end
    return rows
end

function _normalize_column_names(df::DataFrame)::DataFrame
    isempty(df) && return df
    rename!(df, Dict(
        n => Symbol(replace(lowercase(String(n)), r"[^a-z0-9]+" => "_"))
        for n in names(df)
    ))
    return df
end

"""
    join_pos_to_general_info(general::DataFrame, pos::DataFrame) -> DataFrame

Inner-join Care Compare general info with POS hospital metadata on the
6-digit CMS Certification Number (CCN). Returns one row per hospital
present in both feeds.
"""
function join_pos_to_general_info(general::DataFrame, pos::DataFrame)::DataFrame
    g_key = _find_ccn_column(general)
    p_key = _find_ccn_column(pos)
    (g_key === nothing || p_key === nothing) &&
        error("CCN column not found (general=$(names(general)), pos=$(names(pos)))")
    g = copy(general); rename!(g, g_key => :ccn)
    p = copy(pos); rename!(p, p_key => :ccn)
    g.ccn = lpad.(string.(g.ccn), 6, '0')
    p.ccn = lpad.(string.(p.ccn), 6, '0')
    return innerjoin(g, p, on = :ccn, makeunique = true)
end

function _find_ccn_column(df::DataFrame)
    for n in names(df)
        s = lowercase(String(n))
        (s == "ccn" || s == "provider_id" || s == "facility_id" ||
         occursin("ccn", s) || occursin("provider_number", s)) && return n
    end
    return nothing
end
