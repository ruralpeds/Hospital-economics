# ============================================================================
# Data Export Utilities
# ============================================================================

using CSV
using DataFrames
using JSON3

"""
    export_results_to_csv(results::Vector{<:Any}, filepath::String;
                          columns::Vector{String}=String[]) -> String

Export simulation or analysis results to a CSV file.

# Arguments
- `results`: vector of named tuples, dictionaries, or structs to export
- `filepath`: output file path (will be created or overwritten)
- `columns`: optional list of column names to include; if empty, all fields
  are exported

# Returns
The absolute path of the written file.
"""
function export_results_to_csv(results::Vector{<:Any}, filepath::String;
                                columns::Vector{String}=String[])
    if isempty(results)
        error("No results to export")
    end

    # Convert to DataFrame
    df = _results_to_dataframe(results)

    # Filter columns if specified
    if !isempty(columns)
        available = string.(names(df))
        selected = filter(c -> c in available, columns)
        if isempty(selected)
            error("None of the requested columns found in results")
        end
        df = df[:, Symbol.(selected)]
    end

    # Ensure output directory exists
    dir = dirname(filepath)
    if !isempty(dir) && !isdir(dir)
        mkpath(dir)
    end

    CSV.write(filepath, df)
    return abspath(filepath)
end

"""
    export_results_to_json(results, filepath::String;
                           pretty::Bool=true) -> String

Export simulation or analysis results to a JSON file.

# Arguments
- `results`: any JSON-serializable data (dict, named tuple, vector, struct)
- `filepath`: output file path (will be created or overwritten)
- `pretty`: if true, format with indentation for readability

# Returns
The absolute path of the written file.
"""
function export_results_to_json(results, filepath::String;
                                 pretty::Bool=true)
    # Ensure output directory exists
    dir = dirname(filepath)
    if !isempty(dir) && !isdir(dir)
        mkpath(dir)
    end

    serializable = _to_serializable(results)

    open(filepath, "w") do io
        if pretty
            JSON3.pretty(io, serializable)
        else
            JSON3.write(io, serializable)
        end
    end

    return abspath(filepath)
end

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

"""Convert a vector of results (named tuples, dicts, or structs) to a DataFrame."""
function _results_to_dataframe(results::Vector{<:Any})
    if isempty(results)
        return DataFrame()
    end

    first_item = results[1]

    if first_item isa Dict
        rows = [Dict{Symbol,Any}(Symbol(k) => v for (k, v) in d) for d in results]
        return DataFrame(rows)
    elseif first_item isa NamedTuple
        return DataFrame([r for r in results])
    else
        # Struct: extract fieldnames
        fnames = fieldnames(typeof(first_item))
        rows = [Dict{Symbol,Any}(f => getfield(item, f) for f in fnames)
                for item in results]
        return DataFrame(rows)
    end
end

"""Recursively convert structs and named tuples to plain dicts for JSON serialization."""
function _to_serializable(obj)
    if obj isa Dict
        return Dict(string(k) => _to_serializable(v) for (k, v) in obj)
    elseif obj isa NamedTuple
        return Dict(string(k) => _to_serializable(v) for (k, v) in pairs(obj))
    elseif obj isa AbstractVector
        return [_to_serializable(item) for item in obj]
    elseif obj isa Number || obj isa AbstractString || obj isa Bool || obj === nothing
        return obj
    elseif isstructtype(typeof(obj))
        fnames = fieldnames(typeof(obj))
        return Dict(string(f) => _to_serializable(getfield(obj, f)) for f in fnames)
    else
        return string(obj)
    end
end
