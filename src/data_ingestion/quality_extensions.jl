"""
    quality_extensions.jl — Data quality extensions for ingested encounters

Adds three orthogonal quality lenses on top of the existing per-record
validators:

- Duplicate detection: hashes a configurable subset of fields per
  `PatientEncounter` and flags records that collide.
- Outlier detection: marks numeric outliers via z-score and IQR rules
  for charges, length-of-stay, and any user-supplied numeric field.
- Completeness profiling: per-field non-null rate plus an overall
  completeness score, computed across a vector of encounters or a
  generic `Vector{Dict}` upstream of the `PatientEncounter` cast.

All routines return plain structs that compose with `IngestionResult`'s
`quality_summary` Dict so callers can merge them into their own audit.
"""

using SHA
using Statistics
using Dates

# ============================================================================
# DUPLICATE DETECTION
# ============================================================================

"""
    DuplicateReport

Outcome of duplicate detection over a vector of encounters.

# Fields
- duplicate_count::Int: Number of records flagged as duplicate (excluding the first occurrence in each group)
- group_count::Int: Number of distinct duplicate groups
- groups::Vector{Vector{Int}}: Index groups (1-based positions in the input) sharing the same key
- key_fields::Vector{String}: Fields used to compute the dedupe key
"""
struct DuplicateReport
    duplicate_count::Int
    group_count::Int
    groups::Vector{Vector{Int}}
    key_fields::Vector{String}
end

"""
    detect_duplicates(encounters::Vector{PatientEncounter};
                      key_fields::Vector{String} = ["patient_id", "encounter_id", "admission_date"])
        -> DuplicateReport

Group encounters by SHA-256 hash of the concatenated `key_fields` and
return any group with more than one member.
"""
function detect_duplicates(
    encounters::Vector{PatientEncounter};
    key_fields::Vector{String} = ["patient_id", "encounter_id", "admission_date"],
)::DuplicateReport
    buckets = Dict{String,Vector{Int}}()
    for (i, enc) in pairs(encounters)
        key = _encounter_key(enc, key_fields)
        push!(get!(buckets, key, Int[]), i)
    end
    groups = [v for v in values(buckets) if length(v) > 1]
    sort!(groups, by = first)
    dup_count = sum(length(g) - 1 for g in groups; init = 0)
    return DuplicateReport(dup_count, length(groups), groups, key_fields)
end

function _encounter_key(enc::PatientEncounter, fields::Vector{String})::String
    parts = String[]
    for f in fields
        v = if f == "patient_id"; enc.patient_id
            elseif f == "encounter_id"; enc.encounter_id
            elseif f == "admission_date"; string(enc.admission_date)
            elseif f == "discharge_date"; string(enc.discharge_date)
            elseif f == "primary_diagnosis"; enc.primary_diagnosis
            elseif f == "total_charges"; string(enc.total_charges)
            else; string(get(enc.metadata, f, ""))
            end
        push!(parts, String(v))
    end
    return bytes2hex(sha256(join(parts, "|")))
end

# ============================================================================
# OUTLIER DETECTION
# ============================================================================

"""
    OutlierReport

Per-field outlier flags for a numeric series.

# Fields
- field::String: Name of the field analyzed
- method::String: "zscore" or "iqr"
- threshold::Float64: Cutoff used (z-score limit or IQR multiplier)
- outlier_indices::Vector{Int}: 1-based positions flagged as outliers
- mean::Float64
- std::Float64
- q1::Float64
- q3::Float64
"""
struct OutlierReport
    field::String
    method::String
    threshold::Float64
    outlier_indices::Vector{Int}
    mean::Float64
    std::Float64
    q1::Float64
    q3::Float64
end

"""
    detect_outliers(values::AbstractVector{<:Real};
                    field::String = "value",
                    method::Symbol = :zscore,
                    threshold::Float64 = 3.0)
        -> OutlierReport

Flag outliers in a numeric vector. `:zscore` flags |z| > threshold;
`:iqr` flags points outside `[Q1 - threshold·IQR, Q3 + threshold·IQR]`
(default `threshold = 1.5`).
"""
function detect_outliers(
    values::AbstractVector{<:Real};
    field::String = "value",
    method::Symbol = :zscore,
    threshold::Float64 = 3.0,
)::OutlierReport
    n = length(values)
    n == 0 && return OutlierReport(field, String(method), threshold, Int[], 0.0, 0.0, 0.0, 0.0)

    μ = mean(values)
    σ = n > 1 ? std(values) : 0.0
    q1 = n > 1 ? quantile(values, 0.25) : float(values[1])
    q3 = n > 1 ? quantile(values, 0.75) : float(values[1])

    indices = Int[]
    if method === :zscore
        if σ > 0
            for (i, v) in pairs(values)
                abs((v - μ) / σ) > threshold && push!(indices, i)
            end
        end
    elseif method === :iqr
        iqr = q3 - q1
        lo, hi = q1 - threshold * iqr, q3 + threshold * iqr
        for (i, v) in pairs(values)
            (v < lo || v > hi) && push!(indices, i)
        end
    else
        throw(ArgumentError("Unknown outlier method: $method (expected :zscore or :iqr)"))
    end

    return OutlierReport(field, String(method), threshold, indices, μ, σ, q1, q3)
end

"""
    detect_encounter_outliers(encounters::Vector{PatientEncounter};
                              method::Symbol = :iqr,
                              threshold::Float64 = 1.5)
        -> Dict{String,OutlierReport}

Run outlier detection across the standard numeric fields on
`PatientEncounter`: `total_charges`, `length_of_stay`, `paid_amount`.
"""
function detect_encounter_outliers(
    encounters::Vector{PatientEncounter};
    method::Symbol = :iqr,
    threshold::Float64 = 1.5,
)::Dict{String,OutlierReport}
    out = Dict{String,OutlierReport}()
    isempty(encounters) && return out
    out["total_charges"]   = detect_outliers([e.total_charges   for e in encounters]; field = "total_charges",   method = method, threshold = threshold)
    out["length_of_stay"]  = detect_outliers([Float64(e.length_of_stay) for e in encounters]; field = "length_of_stay",  method = method, threshold = threshold)
    out["paid_amount"]     = detect_outliers([e.paid_amount     for e in encounters]; field = "paid_amount",     method = method, threshold = threshold)
    return out
end

# ============================================================================
# COMPLETENESS PROFILING
# ============================================================================

"""
    CompletenessReport

Per-field non-null rates plus an overall score.

# Fields
- field_completeness::Dict{String,Float64}: 0.0–1.0 per field
- field_missing_counts::Dict{String,Int}: Count of nulls/empties per field
- overall_score::Float64: Mean completeness across all fields (0.0–1.0)
- record_count::Int
- source::String: Identifier for the dataset profiled
"""
struct CompletenessReport
    field_completeness::Dict{String,Float64}
    field_missing_counts::Dict{String,Int}
    overall_score::Float64
    record_count::Int
    source::String
end

"""
    profile_completeness(rows::AbstractVector;
                         fields::Union{Nothing,Vector{String}} = nothing,
                         source::String = "unknown") -> CompletenessReport

Profile a vector of `Dict` rows or `PatientEncounter` records. If
`fields` is `nothing`, the union of all keys (or the encounter struct
fieldnames) is used.

A value counts as "missing" when it is `nothing`, `missing`, an empty
`String`, an empty collection, or `NaN`.
"""
function profile_completeness(
    rows::AbstractVector;
    fields::Union{Nothing,Vector{String}} = nothing,
    source::String = "unknown",
)::CompletenessReport
    n = length(rows)
    if n == 0
        return CompletenessReport(Dict{String,Float64}(), Dict{String,Int}(), 0.0, 0, source)
    end

    field_list = fields === nothing ? _infer_fields(rows) : fields
    missing_counts = Dict{String,Int}(f => 0 for f in field_list)

    for r in rows
        for f in field_list
            v = _row_get(r, f)
            _is_missing(v) && (missing_counts[f] += 1)
        end
    end

    completeness = Dict(f => 1.0 - missing_counts[f] / n for f in field_list)
    overall = isempty(completeness) ? 0.0 : mean(values(completeness))

    return CompletenessReport(completeness, missing_counts, overall, n, source)
end

function _infer_fields(rows::AbstractVector)::Vector{String}
    isempty(rows) && return String[]
    first_row = rows[1]
    if first_row isa PatientEncounter
        return String[String(f) for f in fieldnames(PatientEncounter) if f !== :metadata]
    elseif first_row isa AbstractDict
        keys_set = Set{String}()
        for r in rows
            r isa AbstractDict || continue
            for k in keys(r); push!(keys_set, String(k)); end
        end
        return sort!(collect(keys_set))
    else
        return String[String(f) for f in fieldnames(typeof(first_row))]
    end
end

function _row_get(r, field::String)
    if r isa AbstractDict
        return haskey(r, field) ? r[field] :
               haskey(r, Symbol(field)) ? r[Symbol(field)] : nothing
    elseif r isa PatientEncounter
        sym = Symbol(field)
        return sym in fieldnames(PatientEncounter) ? getfield(r, sym) : nothing
    else
        sym = Symbol(field)
        return sym in fieldnames(typeof(r)) ? getfield(r, sym) : nothing
    end
end

function _is_missing(v)::Bool
    v === nothing      && return true
    v === missing      && return true
    v isa AbstractString && return isempty(v)
    v isa AbstractArray && return isempty(v)
    v isa Real          && return isnan(float(v))
    return false
end

# ============================================================================
# SUMMARY HELPER
# ============================================================================

"""
    quality_summary_dict(dup::DuplicateReport,
                         outliers::Dict{String,OutlierReport},
                         completeness::CompletenessReport)
        -> Dict{String,Any}

Flatten the three reports into a single `Dict` suitable for merging into
`IngestionResult.quality_summary`.
"""
function quality_summary_dict(
    dup::DuplicateReport,
    outliers::Dict{String,OutlierReport},
    completeness::CompletenessReport,
)::Dict{String,Any}
    return Dict{String,Any}(
        "duplicates" => Dict(
            "count" => dup.duplicate_count,
            "groups" => dup.group_count,
            "key_fields" => dup.key_fields,
        ),
        "outliers" => Dict(
            f => Dict("count" => length(r.outlier_indices), "method" => r.method, "threshold" => r.threshold)
            for (f, r) in outliers
        ),
        "completeness" => Dict(
            "overall_score" => completeness.overall_score,
            "record_count" => completeness.record_count,
            "by_field" => completeness.field_completeness,
        ),
    )
end
