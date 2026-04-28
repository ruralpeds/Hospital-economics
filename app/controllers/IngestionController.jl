"""
IngestionController — handlers for /data/intake (E4).

Provides three operations on top of the `DataAsset`s produced by
`DataController.handle_universal_upload` (Phase 0):

  - `tag_asset_metadata(payload)` — merges source-type tags into an
    existing asset's `meta.json`.
  - `list_recent_assets(limit)` — reads `data/uploads/audit.log` and the
    per-asset `meta.json` so the UI can show recently committed uploads.
  - `run_validation(asset_id, rules)` — runs a small set of structural
    rules against the asset's CSV. Catalog functions like
    `validate_data_source` and `detect_data_quality_issues` will replace
    these stubs as the domain layer adds them.
"""
module IngestionController

using Dates, UUIDs, Logging
using ..DataController: UPLOAD_DIR

# ─── Tagging ──────────────────────────────────────────────────────────────────

"""
    tag_asset_metadata(payload::Dict) -> Dict

Merge source-type metadata into an existing asset's `meta.json`. Idempotent:
calling twice with the same payload produces the same file. Returns a
status Dict suitable for JSON serialisation.

Expected payload keys: asset_id, source_type, plus any of date_from /
date_to / payer_id / ehr_system / facility_id / registry_name /
cohort_filters. Empty values are skipped so partial updates don't clobber
existing tags.
"""
function tag_asset_metadata(payload::Dict)::Dict{String,Any}
    asset_id = String(get(payload, "asset_id", ""))
    isempty(asset_id) && return Dict{String,Any}(
        "status"  => "error",
        "message" => "Missing required field: asset_id",
    )

    asset_dir = joinpath(UPLOAD_DIR, asset_id)
    meta_path = joinpath(asset_dir, "meta.json")
    if !isfile(meta_path)
        return Dict{String,Any}(
            "status"  => "error",
            "message" => "Asset not found: $(asset_id)",
        )
    end

    raw  = read(meta_path, String)
    meta = _parse_meta(raw)

    tags_added = String[]
    for key in ("source_type", "date_from", "date_to", "payer_id",
                "ehr_system", "facility_id", "registry_name", "cohort_filters")
        v = String(get(payload, key, ""))
        if !isempty(v)
            meta[key] = v
            push!(tags_added, key)
        end
    end
    meta["tagged_at"] = string(now())

    write(meta_path, _emit_json(meta))

    return Dict{String,Any}(
        "status"     => "success",
        "asset_id"   => asset_id,
        "tags_added" => tags_added,
        "tagged_at"  => meta["tagged_at"],
    )
end

# ─── Recent assets list ───────────────────────────────────────────────────────

"""
    list_recent_assets(limit::Int=20) -> Vector{Dict}

Read `data/uploads/audit.log` and join with each asset's `meta.json` to
produce a UI-friendly summary. Most recent first. Missing or unreadable
metadata files are skipped silently — the UI shows what it can.

Audit log columns (tab-separated):
  ts, audit_entry_id, user_id, action, asset_id, filename, format,
  row_count, deidentified, size_bytes
"""
function list_recent_assets(limit::Int = 20)::Vector{Dict{String,Any}}
    audit_path = joinpath(UPLOAD_DIR, "audit.log")
    isfile(audit_path) || return Dict{String,Any}[]

    rows = Dict{String,Any}[]
    for line in reverse(readlines(audit_path))   # newest first
        length(rows) >= limit && break
        fields = split(line, '\t')
        length(fields) < 10 && continue
        fields[4] == "UPLOAD_COMMITTED" || continue

        asset_id = String(fields[5])
        meta_path = joinpath(UPLOAD_DIR, asset_id, "meta.json")
        source_type = "—"
        if isfile(meta_path)
            try
                m = _parse_meta(read(meta_path, String))
                source_type = String(get(m, "source_type", "—"))
            catch
                # silently fall through to the audit-log defaults
            end
        end

        push!(rows, Dict{String,Any}(
            "committed_at" => String(fields[1]),
            "asset_id"     => asset_id,
            "filename"     => String(fields[6]),
            "format"       => String(fields[7]),
            "source_type"  => source_type,
            "row_count"    => something(tryparse(Int, fields[8]),  0),
            "deidentified" => fields[9] == "true",
        ))
    end
    return rows
end

# ─── Validation ───────────────────────────────────────────────────────────────

"""
    run_validation(asset_id::String, rules::Vector) -> Dict

Run a minimum set of structural rules against the asset's committed CSV.

This is intentionally a small, dependency-free implementation that
delivers a usable validation panel today. When the domain layer adds
`validate_data_source`, `validate_icd10_code`, `validate_cpt_code`,
`validate_patient_encounter`, swap in those calls and keep the same
return shape.

Returns:
  Dict("status" => "success",
       "rules"  => [Dict("rule" => …, "passed" => …, "failed" => …,
                         "row_count" => …, "message" => …), ...])
"""
function run_validation(asset_id::String, rules::Vector)::Dict{String,Any}
    isempty(asset_id) && return Dict{String,Any}(
        "status"  => "error",
        "message" => "Missing required field: asset_id",
    )

    csv_path = joinpath(UPLOAD_DIR, asset_id, "data.csv")
    isfile(csv_path) || return Dict{String,Any}(
        "status"  => "error",
        "message" => "Committed CSV not found for asset $(asset_id)",
    )

    header, rows = _read_csv_header_and_rows(csv_path)
    n = length(rows)
    enabled = Set(string.(rules))
    rule_rows = Dict{String,Any}[]

    if "schema" in enabled
        # Schema rule: every row has a value (non-empty) for every header column.
        failed = 0
        for r in rows, col in header
            v = String(get(r, col, ""))
            if isempty(strip(v))
                failed += 1
            end
        end
        push!(rule_rows, Dict{String,Any}(
            "rule"      => "Schema completeness",
            "passed"    => n * length(header) - failed,
            "failed"    => failed,
            "row_count" => n,
            "message"   => failed == 0 ? "All cells populated." :
                           "$(failed) empty cells across $(n) rows.",
        ))
    end

    if "icd10" in enabled
        push!(rule_rows, _regex_rule(header, rows, "ICD-10 codes",
            r"\bicd|diagnosis"i,
            r"^[A-TV-Z][0-9][0-9AB]\.?[0-9A-Z]{0,4}$",
            "ICD-10 column found; format check applied.",
            "No ICD-10-shaped column detected (skipped).",
        ))
    end

    if "cpt" in enabled
        push!(rule_rows, _regex_rule(header, rows, "CPT/HCPCS codes",
            r"\bcpt|hcpcs|procedure"i,
            r"^[0-9]{5}$|^[A-Z][0-9]{4}$",
            "CPT/HCPCS column found; format check applied.",
            "No CPT/HCPCS-shaped column detected (skipped).",
        ))
    end

    if "encounter" in enabled
        # Encounter rule: each row has at least patient_id + admission_date or
        # encounter_id. Presence-based, not value validation.
        required_either = [["patient_id", "admission_date"], ["encounter_id"]]
        failed = 0
        for r in rows
            ok = any(group -> all(c -> !isempty(strip(String(get(r, c, "")))), group),
                     required_either)
            ok || (failed += 1)
        end
        push!(rule_rows, Dict{String,Any}(
            "rule"      => "Patient encounter",
            "passed"    => n - failed,
            "failed"    => failed,
            "row_count" => n,
            "message"   => failed == 0 ?
                "All rows have a patient_id+admission_date or an encounter_id." :
                "$(failed) rows missing both (patient_id+admission_date) and encounter_id.",
        ))
    end

    return Dict{String,Any}(
        "status" => "success",
        "rules"  => rule_rows,
    )
end

# ─── Internals ────────────────────────────────────────────────────────────────

"""
    _regex_rule(header, rows, label, col_pat, val_pat, hit_msg, miss_msg) -> Dict

Helper: find the first header column whose name matches `col_pat`. If
present, validate every value against `val_pat`. If absent, return a
"skipped" row so the UI can show that the rule didn't apply rather than
treating it as a pass.
"""
function _regex_rule(header::Vector{String}, rows::Vector{Dict{String,Any}},
                     label::String, col_pat::Regex, val_pat::Regex,
                     hit_msg::String, miss_msg::String)::Dict{String,Any}
    matched_col = ""
    for h in header
        if occursin(col_pat, h)
            matched_col = h
            break
        end
    end
    if isempty(matched_col)
        return Dict{String,Any}(
            "rule"      => label,
            "passed"    => 0,
            "failed"    => 0,
            "row_count" => length(rows),
            "message"   => miss_msg,
        )
    end
    failed = 0
    for r in rows
        v = strip(String(get(r, matched_col, "")))
        isempty(v) && continue
        occursin(val_pat, v) || (failed += 1)
    end
    return Dict{String,Any}(
        "rule"      => label,
        "passed"    => length(rows) - failed,
        "failed"    => failed,
        "row_count" => length(rows),
        "message"   => "$(hit_msg) Column: $(matched_col).",
    )
end

"""Read a CSV file's header and rows-as-Dicts. Trivial parser — handles
no quoting beyond stripping `\"` and whitespace, matching the writer used
in `DataController._write_rows_csv`."""
function _read_csv_header_and_rows(path::String)
    lines = readlines(path)
    isempty(lines) && return (String[], Dict{String,Any}[])
    header = [strip(s, ['"', ' ']) for s in split(lines[1], ',')]
    rows = Dict{String,Any}[]
    for line in lines[2:end]
        isempty(strip(line)) && continue
        fields = split(line, ',')
        row = Dict{String,Any}()
        for (i, h) in enumerate(header)
            row[String(h)] = i <= length(fields) ? strip(fields[i], ['"', ' ']) : ""
        end
        push!(rows, row)
    end
    return (String.(header), rows)
end

# ─── Tiny JSON read/write (no external dep, matches DataController._simple_json) ─

function _emit_json(v)::String
    if v isa AbstractDict
        inner = join(["$(_emit_json(string(k))):$(_emit_json(val))" for (k, val) in v], ",")
        return "{" * inner * "}"
    elseif v isa AbstractVector
        return "[" * join([_emit_json(x) for x in v], ",") * "]"
    elseif v isa AbstractString
        s = replace(v, "\\" => "\\\\", "\"" => "\\\"",
                       "\n" => "\\n", "\r" => "\\r", "\t" => "\\t")
        return "\"" * s * "\""
    elseif v isa Bool
        return v ? "true" : "false"
    elseif v === nothing || v === missing
        return "null"
    elseif v isa Number
        return string(v)
    else
        return _emit_json(string(v))
    end
end

"""Best-effort flat-JSON parser sufficient for `meta.json` files we wrote
ourselves. Falls back to JSON3 when it's available."""
function _parse_meta(raw::String)::Dict{String,Any}
    try
        j3 = Base.require(Base.PkgId(
            Base.UUID("0f8b85d8-7281-11e9-16c2-39a750bddbf1"), "JSON3"))
        parsed = j3.read(raw)
        return Dict{String,Any}(string(k) => v for (k, v) in pairs(parsed))
    catch
        # Naive fallback — split top-level "key":<value> pairs.
        return _parse_flat_json(raw)
    end
end

function _parse_flat_json(raw::String)::Dict{String,Any}
    out = Dict{String,Any}()
    s = strip(raw)
    startswith(s, '{') && (s = s[2:end])
    endswith(s, '}')   && (s = s[1:end-1])
    depth = 0; in_str = false; esc = false; seg_start = 1
    segments = String[]
    for (i, c) in enumerate(s)
        if esc; esc = false; continue; end
        if in_str
            c == '\\' && (esc = true; continue)
            c == '"'  && (in_str = false; continue)
            continue
        end
        c == '"' && (in_str = true; continue)
        c in ('{', '[') && (depth += 1; continue)
        c in ('}', ']') && (depth -= 1; continue)
        if c == ',' && depth == 0
            push!(segments, s[seg_start:i-1])
            seg_start = i + 1
        end
    end
    push!(segments, s[seg_start:end])
    for seg in segments
        seg = strip(seg)
        isempty(seg) && continue
        colon = findfirst(':', seg)
        isnothing(colon) && continue
        key = strip(strip(seg[1:colon-1]), '"')
        val = strip(seg[colon+1:end])
        out[String(key)] = _scalar(val)
    end
    return out
end

function _scalar(s::AbstractString)
    s = strip(s)
    s == "null"  && return nothing
    s == "true"  && return true
    s == "false" && return false
    if startswith(s, '"') && endswith(s, '"')
        return s[2:end-1]
    end
    n = tryparse(Float64, s)
    isnothing(n) || return n
    return s
end

end # module IngestionController
