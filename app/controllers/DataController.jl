"""
DataController — API handlers for data import/export endpoints.

Routes:
  POST /api/import/hcris
  POST /api/import/csv
  POST /api/export/csv
  POST /api/export/json
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

end # module DataController
