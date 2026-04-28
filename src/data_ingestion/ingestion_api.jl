# ============================================================================
# INGESTION API IMPLEMENTATION
# ============================================================================
# Main orchestrator for HIPAA-compliant patient data ingestion.

using Dates
using CSV
using DataFrames
using SHA
using UUIDs

# Constants for valid values
const VALID_ADMISSION_TYPES = ["Emergency", "Urgent", "Scheduled", "Unknown"]
const VALID_PAYERS = ["Medicare", "Medicaid", "Commercial", "Uninsured", "Other", "Unknown"]
const VALID_SEXES = ["M", "F", "O"]
const VALID_RACE_CODES = ["W", "B", "H", "A", "N", "2+", "O", "Unknown"]
const VALID_DISPOSITIONS = ["Home", "SNF", "LTC", "Hospice", "AMA", "Expired", "Transferred", "Unknown"]
const DEFAULT_ORG_SALT = "HealthcareEconomicsOrg2024"

"""
    ingest_csv(config::IngestionConfig, user_id::String="system"; org_salt::String=DEFAULT_ORG_SALT)::IngestionResult

Ingest patient encounter data from CSV file with validation and de-identification.
"""
function ingest_csv(
    config::IngestionConfig,
    user_id::String = "system";
    org_salt::String = DEFAULT_ORG_SALT,
)::IngestionResult
    # Initialize tracking
    start_time = time()
    records_loaded = 0
    records_valid = 0
    records_with_warnings = 0
    records_rejected = 0
    encounters = PatientEncounter[]
    validation_errors = ValidationError[]
    audit_log = AuditLogEntry[]
    quality_summary = Dict{String, Any}()
    
    # Log ingestion start
    push!(audit_log, AuditLogEntry(
        user_id, "INGESTION_START", "INGESTION";
        status = "SUCCESS"
    ))
    
    try
        # Read CSV
        if !isfile(config.filepath)
            throw(ErrorException("File not found: $(config.filepath)"))
        end
        
        df = CSV.read(config.filepath, DataFrame)
        records_loaded = nrow(df)
        
        # Process each row
        for (idx, row) in enumerate(eachrow(df))
            try
                # Map fields
                raw_data = Dict{String, Any}()
                for (csv_col, enc_field) in config.field_mapping
                    if haskey(row, Symbol(csv_col))
                        raw_data[enc_field] = row[Symbol(csv_col)]
                    end
                end
                
                # De-identify if configured
                if config.deidentify
                    enc = deidentify_encounter(raw_data, org_salt)
                else
                    # Create encounter without de-identification
                    enc = PatientEncounter(
                        get(raw_data, "patient_id", "UNKNOWN"),
                        get(raw_data, "encounter_id", string(uuid4())),
                        Date(get(raw_data, "admission_date", today())),
                        Date(get(raw_data, "discharge_date", today() + Day(1)))
                    )
                end
                
                # Validate if configured
                if config.validate
                    val_result = validate_patient_encounter(enc)
                    if !val_result.is_valid
                        records_rejected += 1
                        for err in val_result.errors
                            push!(validation_errors, err)
                        end
                        continue
                    end
                    if !isempty(val_result.warnings)
                        records_with_warnings += 1
                    end
                end
                
                push!(encounters, enc)
                records_valid += 1
                
            catch e
                records_rejected += 1
                push!(validation_errors, ValidationError(
                    idx, "record", "", "PARSE_ERROR", string(e), "ERROR"
                ))
            end
        end
        
        # Generate quality summary
        quality_summary = Dict(
            "total" => records_loaded,
            "valid" => records_valid,
            "invalid" => records_rejected,
            "warnings" => records_with_warnings,
            "validity_pct" => records_loaded > 0 ? round(records_valid / records_loaded * 100, digits=1) : 0.0,
            "quality_score" => records_loaded > 0 ? round((records_valid / records_loaded) * 100, digits=1) : 0.0
        )
        
        # Log completion
        push!(audit_log, AuditLogEntry(
            user_id, "INGESTION_COMPLETE", "INGESTION";
            status = records_rejected == 0 ? "SUCCESS" : "PARTIAL_SUCCESS",
            record_count = records_loaded
        ))
        
        success = records_rejected == 0
        
    catch e
        push!(audit_log, AuditLogEntry(
            user_id, "INGESTION_ERROR", "INGESTION";
            status = "FAILED",
            outcome = string(e)
        ))
        return IngestionResult(
            false, records_loaded, records_valid, records_with_warnings,
            records_rejected;
            encounters = encounters,
            validation_errors = validation_errors,
            audit_log_entries = audit_log,
            processing_time = time() - start_time
        )
    end
    
    return IngestionResult(
        records_rejected == 0,
        records_loaded,
        records_valid,
        records_with_warnings,
        records_rejected;
        encounters = encounters,
        validation_errors = validation_errors,
        quality_summary = quality_summary,
        audit_log_entries = audit_log,
        processing_time = time() - start_time
    )
end

# Placeholder for other API functions referenced in exports
function log_data_access(user_id::String, resource_id::String)::AuditLogEntry
    AuditLogEntry(user_id, "DATA_ACCESS", "READ"; resource_id = resource_id)
end

function generate_encounter_id()::String
    string(uuid4())
end

# ============================================================================
# MULTI-FORMAT INGESTION (E2 — extended format support)
# ============================================================================

"""
    SUPPORTED_FORMATS

Canonical list of format tags supported by the ingestion API.
"""
const SUPPORTED_FORMATS = [
    "csv", "tsv", "xls", "xlsx", "json", "jsonl",
    "parquet", "feather", "sav", "dta", "sas7bdat", "hcris_rpt",
]

"""
    detect_format(filename::String) -> String

Determine the ingestion format from the file extension.
Returns a canonical format tag (e.g. "csv", "xlsx", "jsonl").
"""
function detect_format(filename::String)::String
    ext = lowercase(splitext(filename)[2])
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
    parse_upload_file(filepath::String, format::String)
        -> (rows::Vector{Dict{String,Any}}, columns::Vector{String})

Parse a file of the given `format` and return all rows as a vector of
column-name => value dictionaries, plus an ordered list of column names.

Dispatches to:
  - CSV/TSV:  stdlib (built-in, no external dep)
  - XLSX:     XLSX.jl (already in Project.toml)
  - JSON:     stdlib JSON parser
  - JSONL:    stdlib JSON Lines parser
  - Parquet:  Parquet2.jl (optional)
  - Feather:  Arrow.jl (optional)
  - SAV/DTA/SAS7BDAT: ReadStatTables.jl (optional)

# Arguments
- filepath::String: Absolute path to the staged upload file.
- format::String: Canonical format tag from `detect_format`.

# Returns
Tuple of (rows, columns) where each row is a Dict{String,Any}.

# Throws
- ErrorException with a user-friendly message if the file cannot be parsed
  or a required optional package is not installed.
"""
function parse_upload_file(
    filepath::String,
    format::String,
)::Tuple{Vector{Dict{String,Any}},Vector{String}}
    if format in ("csv", "tsv", "hcris_rpt")
        return _parse_delimited_file(filepath, format == "tsv" ? '\t' : ',')
    elseif format in ("xls", "xlsx")
        return _parse_xlsx_file(filepath)
    elseif format in ("json", "jsonl")
        return _parse_json_file(filepath, format)
    elseif format == "parquet"
        return _parse_parquet_file(filepath)
    elseif format == "feather"
        return _parse_feather_file(filepath)
    elseif format in ("sav", "dta", "sas7bdat")
        return _parse_readstat_file(filepath, format)
    else
        return _parse_delimited_file(filepath, ',')  # fallback
    end
end

# ── Internal parsers ──────────────────────────────────────────────────────────

function _parse_delimited_file(filepath::String, delim::Char)
    content = read(filepath, String)
    lines = split(content, '\n'; keepempty=false)
    isempty(lines) && return (Dict{String,Any}[], String[])
    header_line = strip(lines[1])
    columns = String[strip(f, ['"', ' ']) for f in split(header_line, delim)]
    rows = Dict{String,Any}[]
    for line in lines[2:end]
        s = strip(line)
        isempty(s) && continue
        fields = split(s, delim)
        row = Dict{String,Any}()
        for (i, col) in enumerate(columns)
            row[col] = i <= length(fields) ? String(strip(fields[i], ['"', ' '])) : ""
        end
        push!(rows, row)
    end
    return rows, columns
end

function _parse_xlsx_file(filepath::String)
    try
        xf = XLSX.readxlsx(filepath)
        sh = xf[XLSX.sheetnames(xf)[1]]
        data = collect(XLSX.eachrow(sh))
        isempty(data) && return (Dict{String,Any}[], String[])
        columns = String[string(isnothing(c) ? "col_$(i)" : c) for (i, c) in enumerate(data[1])]
        rows = Dict{String,Any}[]
        for raw_row in data[2:end]
            row = Dict{String,Any}()
            for (i, col) in enumerate(columns)
                row[col] = i <= length(raw_row) ? raw_row[i] : nothing
            end
            push!(rows, row)
        end
        return rows, columns
    catch e
        error("XLSX parsing failed. Ensure XLSX.jl is installed. Error: $e")
    end
end

function _json_scalar(s::AbstractString)
    s = strip(s)
    s == "null"  && return nothing
    s == "true"  && return true
    s == "false" && return false
    startswith(s, '"') && endswith(s, '"') && return String(s[2:end-1])
    n = tryparse(Float64, s)
    isnothing(n) || return n
    return String(s)
end

function _json_obj(s::AbstractString)::Dict{String,Any}
    row = Dict{String,Any}()
    inner = strip(s)
    (startswith(inner, '{') && endswith(inner, '}')) && (inner = inner[2:end-1])
    depth = 0; in_str = false; esc_next = false
    seg_start = 1
    segments = String[]
    for (i, c) in enumerate(inner)
        if esc_next; esc_next = false; continue; end
        (c == '\\' && in_str) && (esc_next = true; continue)
        c == '"' && (in_str = !in_str; continue)
        in_str && continue
        c in ('{', '[') && (depth += 1; continue)
        c in ('}', ']') && (depth -= 1; continue)
        if c == ',' && depth == 0
            push!(segments, String(inner[seg_start:i-1])); seg_start = i + 1
        end
    end
    push!(segments, String(inner[seg_start:end]))
    for seg in segments
        seg = strip(seg); isempty(seg) && continue
        cp = findfirst(':', seg); isnothing(cp) && continue
        key = String(strip(strip(seg[1:cp-1]), '"'))
        row[key] = _json_scalar(strip(seg[cp+1:end]))
    end
    return row
end

function _json_arr(s::AbstractString)::Vector{Dict{String,Any}}
    rows = Dict{String,Any}[]
    inner = strip(s)
    startswith(inner, '[') && (inner = inner[2:end])
    endswith(inner, ']')   && (inner = inner[1:end-1])
    depth = 0; in_str = false; esc_next = false; seg_start = 1
    for (i, c) in enumerate(inner)
        if esc_next; esc_next = false; continue; end
        (c == '\\' && in_str) && (esc_next = true; continue)
        c == '"' && (in_str = !in_str; continue)
        in_str && continue
        c == '{' && (depth += 1; continue)
        if c == '}'
            depth -= 1
            if depth == 0
                push!(rows, _json_obj(String(strip(inner[seg_start:i]))))
                seg_start = i + 2
            end
        end
    end
    return rows
end

function _parse_json_file(filepath::String, format::String)
    content = read(filepath, String)
    if format == "jsonl"
        lines = filter(!isempty, [strip(l) for l in split(content, '\n')])
        isempty(lines) && return (Dict{String,Any}[], String[])
        rows = Dict{String,Any}[]
        all_keys = Set{String}()
        for line in lines
            row = _json_obj(line)
            push!(rows, row)
            union!(all_keys, keys(row))
        end
        columns = sort!(collect(all_keys))
        return rows, columns
    else
        rows = _json_arr(content)
        columns = isempty(rows) ? String[] : sort!(collect(keys(rows[1])))
        return rows, columns
    end
end

function _parse_parquet_file(filepath::String)
    try
        pf = Base.invokelatest(Base.Main.Parquet2.ParquetFile, filepath)
        cols = String[]
        all_rows = Dict{String,Any}[]
        for batch in Base.invokelatest(Base.Main.Parquet2.RecordBatch, pf)
            isempty(cols) && (cols = collect(keys(batch)))
            n = length(first(values(batch)))
            for i in 1:n
                push!(all_rows, Dict{String,Any}(c => batch[c][i] for c in cols))
            end
        end
        return all_rows, cols
    catch e
        error("Parquet parsing requires Parquet2.jl. Install with `using Pkg; Pkg.add(\"Parquet2\")`. Error: $e")
    end
end

function _parse_feather_file(filepath::String)
    try
        tbl = Base.invokelatest(Base.Main.Arrow.Table, filepath)
        schema = Base.invokelatest(Base.Main.Arrow.Schema, tbl)
        cols = [string(n) for n in schema.names]
        n = length(first(tbl))
        rows = [Dict{String,Any}(c => tbl[Symbol(c)][i] for c in cols) for i in 1:n]
        return rows, cols
    catch e
        error("Feather/Arrow parsing requires Arrow.jl. Install with `using Pkg; Pkg.add(\"Arrow\")`. Error: $e")
    end
end

function _parse_readstat_file(filepath::String, format::String)
    fmt_name = Dict("sav" => "SPSS", "dta" => "Stata", "sas7bdat" => "SAS")[format]
    try
        tbl = Base.invokelatest(Base.Main.ReadStatTables.readstat, filepath)
        cols = [string(n) for n in Base.invokelatest(propertynames, tbl)]
        n = length(tbl[Symbol(cols[1])])
        rows = [Dict{String,Any}(c => tbl[Symbol(c)][i] for c in cols) for i in 1:n]
        return rows, cols
    catch e
        error("$fmt_name parsing requires ReadStatTables.jl. Install with `using Pkg; Pkg.add(\"ReadStatTables\")`. Error: $e")
    end
end
