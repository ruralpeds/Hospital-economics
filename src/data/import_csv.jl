# ============================================================================
# Data Import Utilities
# ============================================================================

using CSV
using DataFrames
using JSON3

"""
    import_hospital_from_csv(filepath::String;
                             hospital_type::Symbol=:cah) -> Vector{Dict{String,Any}}

Import hospital data from a CSV file and return a vector of dictionaries,
one per hospital record.

# Arguments
- `filepath`: path to the CSV file
- `hospital_type`: expected hospital type (:cah, :reh, :pps, :sch)

# Returns
A vector of dictionaries with standardized field names.
"""
function import_hospital_from_csv(filepath::String;
                                   hospital_type::Symbol=:cah)
    if !isfile(filepath)
        error("CSV file not found: $filepath")
    end

    df = CSV.read(filepath, DataFrame)

    # Standardize column names to lowercase with underscores
    rename!(df, [n => Symbol(lowercase(replace(string(n), r"[\s\-]" => "_")))
                 for n in names(df)]...)

    hospitals = Dict{String,Any}[]

    for row in eachrow(df)
        hospital = Dict{String,Any}()
        hospital["source_type"] = hospital_type

        # Map common field names
        field_map = Dict(
            "provider_id"         => ["provider_id", "provider_number", "cms_id"],
            "name"                => ["name", "hospital_name", "facility_name"],
            "beds"                => ["beds", "bed_count", "certified_beds"],
            "state"               => ["state", "state_code"],
            "total_costs"         => ["total_costs", "total_cost"],
            "total_charges"       => ["total_charges", "total_charge", "gross_charges"],
            "medicare_charges"    => ["medicare_charges", "medicare_charge"],
            "medicare_days"       => ["medicare_days", "medicare_inpatient_days"],
            "case_mix_index"      => ["case_mix_index", "cmi"],
            "wage_index"          => ["wage_index", "cbsa_wage_index"],
            "outpatient_visits"   => ["outpatient_visits", "op_visits"],
            "ed_visits"           => ["ed_visits", "emergency_visits"],
        )

        for (std_name, aliases) in field_map
            for alias in aliases
                sym = Symbol(alias)
                if hasproperty(row, sym)
                    val = getproperty(row, sym)
                    if !ismissing(val)
                        hospital[std_name] = val
                    end
                    break
                end
            end
        end

        # Compute derived fields
        if haskey(hospital, "total_costs") && haskey(hospital, "total_charges")
            tc = hospital["total_charges"]
            if tc > 0
                hospital["cost_to_charge_ratio"] = hospital["total_costs"] / tc
            end
        end

        push!(hospitals, hospital)
    end

    return hospitals
end

"""
    import_hospital_from_json(filepath::String) -> Dict{String,Any}

Import a single hospital record from a JSON file.

The JSON file should contain a top-level object with hospital fields.
Nested objects (e.g., payer_mix, cost_centers) are preserved.

# Returns
A dictionary with the hospital's data fields.
"""
function import_hospital_from_json(filepath::String)
    if !isfile(filepath)
        error("JSON file not found: $filepath")
    end

    json_str = read(filepath, String)
    data = JSON3.read(json_str)

    # Convert JSON3 object to plain Dict
    hospital = _json3_to_dict(data)

    return hospital
end

"""Recursively convert a JSON3 object to a plain Dict{String,Any}."""
function _json3_to_dict(obj)
    if obj isa JSON3.Object
        d = Dict{String,Any}()
        for (k, v) in obj
            d[string(k)] = _json3_to_dict(v)
        end
        return d
    elseif obj isa JSON3.Array
        return Any[_json3_to_dict(item) for item in obj]
    else
        return obj
    end
end
