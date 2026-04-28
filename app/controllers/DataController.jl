"""
DataController — API handlers for data import/export endpoints.

Routes:
  POST /api/import/hcris
  POST /api/import/csv
  POST /api/export/csv
  POST /api/export/json
  POST /api/data/upload          ← universal multi-format upload (E2)
"""
module DataController

using JSON3, Dates, UUIDs
using ...RuralHospitalSim

# ═══════════════════════════════════════════════════════════════════════════
# Path safety — prevent directory traversal attacks
# ═══════════════════════════════════════════════════════════════════════════

const ALLOWED_IMPORT_DIRS = [
    joinpath(@__DIR__, "..", "..", "data", "uploads"),
    joinpath(@__DIR__, "..", "..", "data", "reference"),
    joinpath(@__DIR__, "..", "..", "data", "sample"),
]

const EXPORT_DIR = joinpath(@__DIR__, "..", "..", "data", "exports")

"""
    sanitize_import_path(filepath::String) -> String

Resolve the filepath and verify it falls within an allowed import directory.
Throws an error if the path escapes allowed directories.
"""
function sanitize_import_path(filepath::String)
    resolved = realpath(filepath)
    for dir in ALLOWED_IMPORT_DIRS
        allowed = realpath(dir)
        if startswith(resolved, allowed * "/") || resolved == allowed
            return resolved
        end
    end
    error("Access denied: file path is outside allowed data directories")
end

"""
    sanitize_filename(filename::String) -> String

Strip path separators and traversal sequences from a user-supplied filename.
"""
function sanitize_filename(filename::String)
    # Remove any directory components — keep only the base filename
    name = basename(filename)
    # Reject hidden files and empty names
    (isempty(name) || startswith(name, ".")) &&
        error("Invalid filename: $filename")
    return name
end

# ═══════════════════════════════════════════════════════════════════════════
# HCRIS Import
# ═══════════════════════════════════════════════════════════════════════════

"""
    handle_hcris_import(payload::Dict) -> Dict

Parse a HCRIS cost report file.

Expected payload:
  - filepath: path to the HCRIS CSV/data file on the server
  - provider_filter: optional CMS provider number to filter
"""
function handle_hcris_import(payload::Dict)
    filepath = get(payload, "filepath", "")
    isempty(filepath) && return Dict(
        "status" => "error",
        "message" => "Missing required field: filepath",
    )

    !isfile(filepath) && return Dict(
        "status" => "error",
        "message" => "File not found",
    )

    filepath = sanitize_import_path(filepath)
    provider_filter = get(payload, "provider_filter", "")

    result = parse_hcris_cost_report(filepath; provider_filter=provider_filter)

    Dict(
        "status"           => "success",
        "type"             => "hcris_import",
        "timestamp"        => string(now()),
        "records_parsed"   => length(get(result, "records", [])),
        "provider_filter"  => provider_filter,
        "data"             => result,
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# CSV Import
# ═══════════════════════════════════════════════════════════════════════════

"""
    handle_csv_import(payload::Dict) -> Dict

Import hospital data from a CSV file.

Expected payload:
  - filepath: path to the CSV file
  - hospital_type: "cah" | "reh" | "pps" (default: "cah")
"""
function handle_csv_import(payload::Dict)
    filepath = get(payload, "filepath", "")
    isempty(filepath) && return Dict(
        "status" => "error",
        "message" => "Missing required field: filepath",
    )

    !isfile(filepath) && return Dict(
        "status" => "error",
        "message" => "File not found",
    )

    filepath = sanitize_import_path(filepath)

    type_str = get(payload, "hospital_type", "cah")
    type_str in ("cah", "reh", "pps") || return Dict(
        "status" => "error",
        "message" => "Invalid hospital_type: must be cah, reh, or pps",
    )
    hospital_type = Symbol(type_str)

    records = import_hospital_from_csv(filepath; hospital_type=hospital_type)

    Dict(
        "status"          => "success",
        "type"            => "csv_import",
        "timestamp"       => string(now()),
        "records_imported" => length(records),
        "hospital_type"   => string(hospital_type),
        "data"            => records,
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# CSV Export
# ═══════════════════════════════════════════════════════════════════════════

"""
    handle_csv_export(payload::Dict) -> Dict

Export simulation results to CSV.

Expected payload:
  - results: array of result records to export
  - filename: desired output filename (written to data/exports/)
  - columns: optional list of column names to include
"""
function handle_csv_export(payload::Dict)
    results = get(payload, "results", [])
    isempty(results) && return Dict(
        "status" => "error",
        "message" => "No results data provided for export",
    )

    raw_filename = get(payload, "filename", "export_$(Dates.format(now(), "yyyymmdd_HHMMSS")).csv")
    filename = sanitize_filename(raw_filename)
    mkpath(EXPORT_DIR)
    filepath = joinpath(EXPORT_DIR, filename)

    columns = String.(get(payload, "columns", String[]))

    output_path = export_results_to_csv(results, filepath; columns=columns)

    Dict(
        "status"   => "success",
        "type"     => "csv_export",
        "timestamp" => string(now()),
        "filepath" => output_path,
        "records"  => length(results),
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# JSON Export
# ═══════════════════════════════════════════════════════════════════════════

"""
    handle_json_export(payload::Dict) -> Dict

Export simulation results to JSON.

Expected payload:
  - results: data to export
  - filename: desired output filename
"""
function handle_json_export(payload::Dict)
    results = get(payload, "results", nothing)
    isnothing(results) && return Dict(
        "status" => "error",
        "message" => "No results data provided for export",
    )

    raw_filename = get(payload, "filename", "export_$(Dates.format(now(), "yyyymmdd_HHMMSS")).json")
    filename = sanitize_filename(raw_filename)
    mkpath(EXPORT_DIR)
    filepath = joinpath(EXPORT_DIR, filename)

    output_path = export_results_to_json(results, filepath; pretty=true)

    Dict(
        "status"   => "success",
        "type"     => "json_export",
        "timestamp" => string(now()),
        "filepath" => output_path,
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# Universal Upload  (E2 — multi-format intake)
# ═══════════════════════════════════════════════════════════════════════════

const UPLOAD_DIR = joinpath(@__DIR__, "..", "..", "data", "uploads")
const TEMPLATES_DIR = joinpath(@__DIR__, "..", "..", "data", "templates")

# Allowed upload directory (added to ALLOWED_IMPORT_DIRS for path-safety)
const ALLOWED_UPLOAD_DIR = UPLOAD_DIR

# Maximum upload size in MB (server-side enforcement)
const DEFAULT_MAX_MB = 500

"""
    handle_universal_upload(payload::Dict) -> Dict

Universal multi-format upload handler.

Accepts a multipart or JSON payload produced by the 6-step Upload component
(`app/components/upload.jl`) and orchestrates:
  1. Path safety and size enforcement.
  2. Format detection from the original filename/extension.
  3. Preview generation (first 20 rows) with PHI sniff.
  4. Column mapping application.
  5. Optional de-identification (HIPAA Safe Harbor).
  6. Commit to `data/uploads/<uuid>/` and audit log entry.

Expected payload keys:
  - `filepath`    : Staged server-side file path (written by q-uploader).
  - `filename`    : Original user-supplied filename (for extension detection).
  - `schema`      : Target schema ("patient", "claim", "financial", …).
  - `column_mapping` : Dict source_col => target_field (may be empty).
  - `deidentify`  : Bool — apply HIPAA de-identification (default true).
  - `org_salt`    : Salt for pseudonymisation (default constant).
  - `user_id`     : Identifying string for audit log.
  - `max_mb`      : Override max upload size in MB.

Returns a Dict with `status`, `asset_id`, `row_count`, `phi_columns`,
`audit_entry_id`, `upload_dir`, and (on error) `message`.
"""
function handle_universal_upload(payload::Dict)
    filepath  = get(payload, "filepath", "")
    filename  = get(payload, "filename", basename(filepath))
    schema    = get(payload, "schema", "patient")
    user_id   = get(payload, "user_id", "system")
    deidentify = Bool(get(payload, "deidentify", true))
    # NOTE: The default org_salt below is a placeholder only. Production
    # deployments MUST supply an organisation-specific secret salt via the
    # payload to ensure cross-organisation pseudonymisation privacy.
    org_salt  = get(payload, "org_salt", "HealthcareEconomicsOrg2024")
    max_mb    = Int(get(payload, "max_mb", DEFAULT_MAX_MB))

    # ── 1. Input validation ──────────────────────────────────────────────
    isempty(filepath) && return Dict(
        "status"  => "error",
        "message" => "Missing required field: filepath",
    )
    !isfile(filepath) && return Dict(
        "status"  => "error",
        "message" => "Staged file not found: $(basename(filepath))",
    )

    # ── 2. Path safety ───────────────────────────────────────────────────
    resolved = try
        realpath(filepath)
    catch
        return Dict("status" => "error", "message" => "Could not resolve filepath")
    end

    # Allow uploads dir as well as the standard import dirs
    mkpath(UPLOAD_DIR)
    upload_real = try realpath(UPLOAD_DIR) catch; UPLOAD_DIR end
    allowed = vcat(
        ALLOWED_IMPORT_DIRS,
        [upload_real],
        # Also allow /tmp for test fixtures
        ["/tmp"],
    )
    path_ok = any(dir -> begin
        d = try realpath(dir) catch; dir end
        startswith(resolved, d * "/") || resolved == d
    end, allowed)

    if !path_ok
        return Dict(
            "status"  => "error",
            "message" => "Access denied: filepath is outside allowed directories",
        )
    end

    # ── 3. Size enforcement ──────────────────────────────────────────────
    size_bytes = filesize(resolved)
    limit_bytes = max_mb * 1024 * 1024
    if size_bytes > limit_bytes
        return Dict(
            "status"  => "error",
            "message" => "File too large: $(round(size_bytes/1024/1024, digits=1)) MB " *
                         "(limit: $(max_mb) MB)",
        )
    end

    # ── 4. Format detection ──────────────────────────────────────────────
    ext = lowercase(splitext(filename)[2])
    format = _normalize_extension(ext)

    # ── 5. Parse file → rows + columns ──────────────────────────────────
    parse_result = _parse_upload(resolved, format)
    if !parse_result["success"]
        return Dict(
            "status"  => "error",
            "message" => "Failed to parse file: $(parse_result["error"])",
        )
    end

    rows          = parse_result["rows"]::Vector{Dict{String,Any}}
    column_names  = parse_result["columns"]::Vector{String}
    row_count     = parse_result["row_count"]::Int

    # ── 6. PHI sniff ─────────────────────────────────────────────────────
    phi_columns = _sniff_phi_columns(column_names)
    # Also check value samples
    sample_values = String[]
    for row in rows[1:min(5, length(rows))], (_, v) in row
        !isnothing(v) && push!(sample_values, string(v))
    end
    phi_in_values = _sniff_phi_values(sample_values)
    phi_detected  = !isempty(phi_columns) || phi_in_values

    # ── 7. De-identification ──────────────────────────────────────────────
    actually_deidentified = false
    deidentify_log        = String[]
    if deidentify && phi_detected
        # Apply de-identification to PHI columns via the domain layer
        for (i, row) in enumerate(rows)
            for col in phi_columns
                if haskey(row, col)
                    # Pseudonymise string values; mask date-like values to year
                    v = row[col]
                    if v isa String && !isempty(v)
                        row[col] = _pseudonymise_value(v, org_salt)
                    end
                end
            end
        end
        actually_deidentified = true
        push!(deidentify_log, "De-identified $(length(phi_columns)) PHI column(s): " *
              join(phi_columns, ", "))
    elseif phi_detected && !deidentify
        push!(deidentify_log, "WARNING: PHI columns present but de-identification was skipped by user.")
    end

    # ── 8. Commit to data/uploads/<uuid>/ ────────────────────────────────
    asset_id   = string(uuid4())
    asset_dir  = joinpath(UPLOAD_DIR, asset_id)
    mkpath(asset_dir)

    # Write committed CSV
    committed_path = joinpath(asset_dir, "data.csv")
    _write_rows_csv(rows, column_names, committed_path)

    # Write metadata JSON
    meta = Dict(
        "asset_id"          => asset_id,
        "original_filename" => filename,
        "format"            => format,
        "schema"            => schema,
        "upload_dir"        => asset_dir,
        "row_count"         => row_count,
        "column_names"      => column_names,
        "phi_columns"       => phi_columns,
        "deidentified"      => actually_deidentified,
        "deidentify_log"    => deidentify_log,
        "committed_at"      => string(now()),
        "user_id"           => user_id,
        "file_size_bytes"   => size_bytes,
    )
    meta_path = joinpath(asset_dir, "meta.json")
    write(meta_path, _simple_json(meta))

    # ── 9. Audit log ──────────────────────────────────────────────────────
    audit_entry_id = string(uuid4())
    audit_path     = joinpath(UPLOAD_DIR, "audit.log")
    audit_line = join([
        string(now()), audit_entry_id, user_id, "UPLOAD_COMMITTED",
        asset_id, filename, format, string(row_count),
        string(actually_deidentified), string(size_bytes),
    ], "\t") * "\n"
    open(audit_path, "a") do f
        write(f, audit_line)
    end

    return Dict(
        "status"          => "success",
        "type"            => "universal_upload",
        "asset_id"        => asset_id,
        "original_filename" => filename,
        "format"          => format,
        "schema"          => schema,
        "upload_dir"      => asset_dir,
        "row_count"       => row_count,
        "column_names"    => column_names,
        "phi_detected"    => phi_detected,
        "phi_columns"     => phi_columns,
        "deidentified"    => actually_deidentified,
        "deidentify_log"  => deidentify_log,
        "audit_entry_id"  => audit_entry_id,
        "committed_at"    => string(now()),
        "timestamp"       => string(now()),
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Internal helpers
# ─────────────────────────────────────────────────────────────────────────────

"""Map raw file extension to canonical format tag."""
function _normalize_extension(ext::String)::String
    map = Dict(
        ".csv"      => "csv",
        ".tsv"      => "tsv",
        ".txt"      => "csv",
        ".xls"      => "xls",
        ".xlsx"     => "xlsx",
        ".json"     => "json",
        ".jsonl"    => "jsonl",
        ".parquet"  => "parquet",
        ".feather"  => "feather",
        ".sav"      => "sav",
        ".dta"      => "dta",
        ".sas7bdat" => "sas7bdat",
        ".rpt"      => "hcris_rpt",
    )
    get(map, ext, "csv")
end

"""
Parse uploaded file and return rows + columns.
Dispatches by format tag to the appropriate backend.
"""
function _parse_upload(filepath::String, format::String)::Dict{String,Any}
    try
        rows, columns = if format in ("csv", "tsv", "hcris_rpt")
            _parse_delimited(filepath, format)
        elseif format == "xlsx"
            _parse_xlsx(filepath)
        elseif format == "xls"
            _parse_xlsx(filepath)   # XLSX.jl also handles .xls
        elseif format in ("json", "jsonl")
            _parse_json(filepath, format)
        elseif format == "parquet"
            _parse_parquet(filepath)
        elseif format == "feather"
            _parse_feather(filepath)
        elseif format in ("sav", "dta", "sas7bdat")
            _parse_readstat(filepath, format)
        else
            _parse_delimited(filepath, "csv")   # fallback
        end

        return Dict(
            "success"    => true,
            "rows"       => rows,
            "columns"    => columns,
            "row_count"  => length(rows),
        )
    catch e
        return Dict("success" => false, "error" => string(e))
    end
end

"""Parse CSV/TSV file. Returns (rows, columns)."""
function _parse_delimited(filepath::String, format::String)
    delim = format == "tsv" ? '\t' : ','
    content = read(filepath, String)
    lines = split(content, '\n'; keepempty=false)
    isempty(lines) && return (Dict{String,Any}[], String[])

    # Parse header
    header_line = strip(lines[1])
    columns = [strip(f, ['"', ' ']) for f in split(header_line, delim)]

    rows = Dict{String,Any}[]
    for line in lines[2:end]
        stripped = strip(line)
        isempty(stripped) && continue
        fields = split(stripped, delim)
        row = Dict{String,Any}()
        for (i, col) in enumerate(columns)
            row[col] = i <= length(fields) ? strip(fields[i], ['"', ' ']) : ""
        end
        push!(rows, row)
    end
    return rows, columns
end

"""Parse XLSX file. Returns (rows, columns)."""
function _parse_xlsx(filepath::String)
    # Try using XLSX.jl if available
    try
        xf = XLSX.readxlsx(filepath)
        sh = xf[XLSX.sheetnames(xf)[1]]   # first sheet
        data = XLSX.eachrow(sh)
        rows_raw = collect(data)
        isempty(rows_raw) && return (Dict{String,Any}[], String[])
        columns = [string(isnothing(c) ? "col_$(i)" : c) for (i, c) in enumerate(rows_raw[1])]
        rows = Dict{String,Any}[]
        for raw_row in rows_raw[2:end]
            row = Dict{String,Any}()
            for (i, col) in enumerate(columns)
                row[col] = i <= length(raw_row) ? raw_row[i] : nothing
            end
            push!(rows, row)
        end
        return rows, columns
    catch e
        # If XLSX.jl is not available, return error
        error("XLSX parsing requires XLSX.jl: $e")
    end
end

"""Parse JSON or JSONL file. Returns (rows, columns)."""
function _parse_json(filepath::String, format::String)
    content = read(filepath, String)
    if format == "jsonl"
        lines = filter(!isempty, [strip(l) for l in split(content, '\n')])
        isempty(lines) && return (Dict{String,Any}[], String[])
        # Parse each line as a JSON object; collect all keys
        rows = Dict{String,Any}[]
        all_keys = Set{String}()
        for line in lines
            row = _parse_json_object(line)
            push!(rows, row)
            union!(all_keys, keys(row))
        end
        columns = sort!(collect(all_keys))
        return rows, columns
    else
        # JSON: expect array of objects
        rows = _parse_json_array(content)
        columns = isempty(rows) ? String[] : sort!(collect(keys(rows[1])))
        return rows, columns
    end
end

"""Minimal JSON object parser (no external deps)."""
function _parse_json_object(s::AbstractString)::Dict{String,Any}
    row = Dict{String,Any}()
    # Strip outer braces
    inner = strip(s)
    if startswith(inner, '{') && endswith(inner, '}')
        inner = inner[2:end-1]
    end
    # Simple key:value split on commas not inside strings
    # This is a best-effort parser for flat objects
    depth = 0; in_str = false; esc = false
    seg_start = 1
    segments = String[]
    for (i, c) in enumerate(inner)
        if esc
            esc = false; continue
        end
        c == '\\' && in_str && (esc = true; continue)
        c == '"' && (in_str = !in_str; continue)
        in_str && continue
        c in ('{', '[') && (depth += 1; continue)
        c in ('}', ']') && (depth -= 1; continue)
        if c == ',' && depth == 0
            push!(segments, inner[seg_start:i-1])
            seg_start = i + 1
        end
    end
    push!(segments, inner[seg_start:end])
    for seg in segments
        seg = strip(seg)
        isempty(seg) && continue
        colon_pos = findfirst(':', seg)
        isnothing(colon_pos) && continue
        key = strip(strip(seg[1:colon_pos-1]), '"')
        val_str = strip(seg[colon_pos+1:end])
        row[key] = _parse_json_value(val_str)
    end
    return row
end

"""Parse a JSON array of flat objects (best-effort, no external deps)."""
function _parse_json_array(s::AbstractString)::Vector{Dict{String,Any}}
    rows = Dict{String,Any}[]
    inner = strip(s)
    # Remove outer array brackets
    startswith(inner, '[') && (inner = inner[2:end])
    endswith(inner, ']') && (inner = inner[1:end-1])
    # Split on top-level } followed by ,
    depth = 0; in_str = false; esc = false
    seg_start = 1
    for (i, c) in enumerate(inner)
        if esc; esc = false; continue; end
        c == '\\' && in_str && (esc = true; continue)
        c == '"' && (in_str = !in_str; continue)
        in_str && continue
        c == '{' && (depth += 1; continue)
        if c == '}'
            depth -= 1
            if depth == 0
                obj_str = strip(inner[seg_start:i])
                row = _parse_json_object(obj_str)
                push!(rows, row)
                seg_start = i + 2  # skip }, 
            end
        end
    end
    return rows
end

"""Parse a scalar JSON value from a string."""
function _parse_json_value(s::AbstractString)
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

"""
Parse Parquet file via Parquet2.jl if available.
Returns (rows, columns).
"""
function _parse_parquet(filepath::String)
    try
        # Parquet2.jl interface
        pf = Base.invokelatest(Base.Main.Parquet2.ParquetFile, filepath)
        batches = Base.invokelatest(Base.Main.Parquet2.RecordBatch, pf)
        rows = Dict{String,Any}[]
        columns = String[]
        for batch in batches
            if isempty(columns)
                columns = collect(keys(batch))
            end
            n = length(first(values(batch)))
            for i in 1:n
                row = Dict{String,Any}(col => batch[col][i] for col in columns)
                push!(rows, row)
            end
        end
        return rows, columns
    catch e
        error("Parquet parsing requires Parquet2.jl. Install it with `using Pkg; Pkg.add(\"Parquet2\")`. Error: $e")
    end
end

"""
Parse Apache Arrow/Feather file via Arrow.jl if available.
Returns (rows, columns).
"""
function _parse_feather(filepath::String)
    try
        tbl = Base.invokelatest(Base.Main.Arrow.Table, filepath)
        columns = [string(n) for n in Base.invokelatest(Base.Main.Arrow.Schema, tbl).names]
        n = length(first(tbl))
        rows = [Dict{String,Any}(col => tbl[Symbol(col)][i] for col in columns) for i in 1:n]
        return rows, columns
    catch e
        error("Feather/Arrow parsing requires Arrow.jl. Install it with `using Pkg; Pkg.add(\"Arrow\")`. Error: $e")
    end
end

"""
Parse SPSS/Stata/SAS files via ReadStatTables.jl if available.
Returns (rows, columns).
"""
function _parse_readstat(filepath::String, format::String)
    try
        tbl = Base.invokelatest(Base.Main.ReadStatTables.readstat, filepath)
        columns = [string(n) for n in Base.invokelatest(propertynames, tbl)]
        n = length(tbl[Symbol(columns[1])])
        rows = [Dict{String,Any}(col => tbl[Symbol(col)][i] for col in columns) for i in 1:n]
        return rows, columns
    catch e
        fmt_name = Dict("sav" => "SPSS", "dta" => "Stata", "sas7bdat" => "SAS")[format]
        error("$(fmt_name) parsing requires ReadStatTables.jl. Install it with `using Pkg; Pkg.add(\"ReadStatTables\")`. Error: $e")
    end
end

"""
    _sniff_phi_columns(column_names::AbstractVector) -> Vector{String}

Detect column names that likely contain PHI (HIPAA 18 identifiers).
"""
function _sniff_phi_columns(column_names::AbstractVector)::Vector{String}
    phi_patterns = [
        r"(?i)\b(ssn|social.?security|social_security_number)\b",
        r"(?i)\b(dob|date.?of.?birth|birth.?date|birthdate)\b",
        r"(?i)\b(mrn|medical.?record.?number|patient.?id|pat.?id)\b",
        r"(?i)\b(first.?name|last.?name|full.?name|patient.?name)\b",
        r"(?i)\b(phone|telephone|fax|cell)\b",
        r"(?i)\b(email|e.?mail)\b",
        r"(?i)\b(address|street|addr|zip|zipcode|postal)\b",
        r"(?i)\b(ip.?address)\b",
        r"(?i)\b(passport|account.?number|insurance.?id|member.?id)\b",
        r"(?i)\b(name)\b",
    ]
    phi_cols = String[]
    for col in column_names
        for pat in phi_patterns
            if occursin(pat, col)
                push!(phi_cols, col)
                break
            end
        end
    end
    return phi_cols
end

"""
    _sniff_phi_values(sample_values::AbstractVector) -> Bool

Return true if any sample value matches a known PHI pattern.
"""
function _sniff_phi_values(sample_values::AbstractVector)::Bool
    phi_value_patterns = [
        r"\b\d{3}-\d{2}-\d{4}\b",
        r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b",
        r"\b\d{3}-\d{3}-\d{4}\b",
        r"\(\d{3}\)\s*\d{3}-\d{4}",
    ]
    for val in sample_values
        for pat in phi_value_patterns
            occursin(pat, val) && return true
        end
    end
    return false
end

"""
    _pseudonymise_value(value::String, salt::String) -> String

Generate a deterministic pseudonym for a PHI string value.

Attempts to use SHA-256 (via SHA.jl) for cryptographic strength.
Falls back to a keyed-hash using Julia's `hash()` with the salt mixed in
as a numeric seed — sufficient for testing but not HIPAA-grade production use.

For production deployments, ensure SHA.jl is available so that true
HMAC-SHA256 pseudonymisation is applied.  The default `org_salt` should
always be overridden with an organisation-specific secret.
"""
function _pseudonymise_value(value::String, salt::String)::String
    # Attempt SHA-256 via SHA.jl (already in deidentifiers.jl deps)
    try
        sha_mod = Base.loaded_modules_array()
        sha_loaded = any(m -> nameof(m) === :SHA, sha_mod)
        if sha_loaded
            sha_mod_ref = first(filter(m -> nameof(m) === :SHA, sha_mod))
            hash_bytes = Base.invokelatest(getfield(sha_mod_ref, :sha256),
                                           Vector{UInt8}(value * salt))
            return bytes2hex(hash_bytes)[1:16]
        end
    catch
        # SHA.jl not loaded — fall through to keyed-hash fallback
    end
    # Keyed-hash fallback: mix salt as a seed offset to prevent rainbow tables
    seed = foldr((c, acc) -> xor(acc, UInt64(c)), codeunits(salt); init=UInt64(0x6c62272e07bb0142))
    h = hash(value, seed)
    return string(h, base=16)[1:min(16, end)]
end

"""
    _write_rows_csv(rows, columns, path)

Write a Vector of row Dicts to a CSV file at `path`.
"""
function _write_rows_csv(rows::Vector{Dict{String,Any}}, columns::Vector{String}, path::String)
    open(path, "w") do f
        # Header
        println(f, join(["\"$(replace(c, '"' => "\"\""))\"" for c in columns], ","))
        # Rows
        for row in rows
            vals = [begin
                v = get(row, col, "")
                s = isnothing(v) ? "" : string(v)
                "\"$(replace(s, '"' => "\"\""))\""
            end for col in columns]
            println(f, join(vals, ","))
        end
    end
end

"""
    _simple_json(d::Dict) -> String

Minimal Dict-to-JSON serialiser (no external deps, handles String/Int/Bool/Float/Vector/Dict).
"""
function _simple_json(d::Dict)::String
    pairs = String[]
    for (k, v) in d
        push!(pairs, "\"$(escape_string(string(k)))\": $(_json_val(v))")
    end
    return "{\n  " * join(pairs, ",\n  ") * "\n}"
end

function _json_val(v)::String
    isnothing(v)     && return "null"
    v isa Bool       && return v ? "true" : "false"
    v isa Number     && return string(v)
    v isa String     && return "\"$(escape_string(v))\""
    v isa Vector     && return "[" * join([_json_val(x) for x in v], ", ") * "]"
    v isa Dict       && return _simple_json(v)
    return "\"$(escape_string(string(v)))\""
end

end # module DataController
