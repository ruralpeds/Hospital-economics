# ============================================================================
# HCRIS Cost Report Parser
# ============================================================================

"""
    HCRISRecord

Parsed record from the Healthcare Cost Report Information System (HCRIS).
"""
struct HCRISRecord
    provider_id::String
    fiscal_year_start::String
    fiscal_year_end::String
    worksheet::String
    line::Int
    column::Int
    value::Union{Float64,String,Nothing}
end

"""
    parse_hcris_cost_report(filepath::String;
                            provider_filter::String="") -> Dict{String,Any}

Parse a CMS HCRIS cost report file (CSV format from CMS public use files)
and extract structured financial data.

The HCRIS data is organized by worksheet, line number, and column number.
This parser reads the flat file and reconstructs the hierarchical structure.

# Arguments
- `filepath`: path to the HCRIS CSV file
- `provider_filter`: if non-empty, only parse records for this provider ID

# Returns
A dictionary with keys for each worksheet (e.g., "A", "B", "C") containing
parsed financial data.
"""
function parse_hcris_cost_report(filepath::String;
                                  provider_filter::String="")
    if !isfile(filepath)
        error("HCRIS file not found: $filepath")
    end

    records = HCRISRecord[]

    open(filepath, "r") do io
        for line in eachline(io)
            fields = split(line, ',')
            if length(fields) < 6
                continue
            end

            provider = strip(fields[1], '"')
            if !isempty(provider_filter) && provider != provider_filter
                continue
            end

            fy_start = strip(fields[2], '"')
            fy_end = strip(fields[3], '"')
            worksheet = strip(fields[4], '"')
            line_num = tryparse(Int, fields[5])
            col_num = tryparse(Int, fields[6])
            raw_val = length(fields) >= 7 ? strip(fields[7], '"') : ""

            if line_num === nothing || col_num === nothing
                continue
            end

            parsed_val = tryparse(Float64, raw_val)
            val = parsed_val !== nothing ? parsed_val :
                  (isempty(raw_val) ? nothing : raw_val)

            push!(records, HCRISRecord(
                provider, fy_start, fy_end, worksheet,
                line_num, col_num, val
            ))
        end
    end

    # Organize by worksheet
    result = Dict{String,Any}(
        "provider_id" => isempty(provider_filter) ? "ALL" : provider_filter,
        "records" => records,
        "worksheet_a" => parse_worksheet_a(records),
        "worksheet_b" => parse_worksheet_b(records),
        "worksheet_c" => parse_worksheet_c(records),
    )

    return result
end

"""
    parse_worksheet_a(records::Vector{HCRISRecord}) -> Dict{String,Any}

Parse Worksheet A — Reclassification and Adjustment of Trial Balance.

Extracts cost center costs, salaries, and total cost data from the
trial balance reclassification worksheet.
"""
function parse_worksheet_a(records::Vector{HCRISRecord})
    ws_a = filter(r -> r.worksheet == "A000000", records)

    cost_centers = Dict{Int,Dict{String,Any}}()
    for rec in ws_a
        if !haskey(cost_centers, rec.line)
            cost_centers[rec.line] = Dict{String,Any}("line" => rec.line)
        end
        center = cost_centers[rec.line]

        if rec.column == 1 && rec.value isa Float64
            center["salaries"] = rec.value
        elseif rec.column == 2 && rec.value isa Float64
            center["other_costs"] = rec.value
        elseif rec.column == 3 && rec.value isa Float64
            center["total_costs"] = rec.value
        end
    end

    total_costs = sum(
        get(c, "total_costs", 0.0)
        for c in values(cost_centers);
        init=0.0
    )

    return Dict{String,Any}(
        "cost_centers" => cost_centers,
        "total_costs"  => total_costs,
    )
end

"""
    parse_worksheet_b(records::Vector{HCRISRecord}) -> Dict{String,Any}

Parse Worksheet B — Cost Allocation: General Service Costs.

Extracts the step-down allocation data showing how overhead costs
are distributed to revenue-producing cost centers.
"""
function parse_worksheet_b(records::Vector{HCRISRecord})
    ws_b = filter(r -> startswith(r.worksheet, "B"), records)

    allocations = Dict{Int,Dict{Int,Float64}}()
    for rec in ws_b
        if rec.value isa Float64
            if !haskey(allocations, rec.line)
                allocations[rec.line] = Dict{Int,Float64}()
            end
            allocations[rec.line][rec.column] = rec.value
        end
    end

    return Dict{String,Any}(
        "allocations" => allocations,
    )
end

"""
    parse_worksheet_c(records::Vector{HCRISRecord}) -> Dict{String,Any}

Parse Worksheet C — Ratio of Costs to Charges.

Extracts cost-to-charge ratios for each cost center, which are used to
determine Medicare reimbursement amounts.
"""
function parse_worksheet_c(records::Vector{HCRISRecord})
    ws_c = filter(r -> startswith(r.worksheet, "C"), records)

    ratios = Dict{Int,Dict{String,Any}}()
    for rec in ws_c
        if !haskey(ratios, rec.line)
            ratios[rec.line] = Dict{String,Any}("line" => rec.line)
        end
        center = ratios[rec.line]

        if rec.value isa Float64
            if rec.column == 1
                center["total_costs"] = rec.value
            elseif rec.column == 2
                center["total_charges"] = rec.value
            elseif rec.column == 3
                center["cost_to_charge_ratio"] = rec.value
            elseif rec.column == 4
                center["medicare_charges"] = rec.value
            elseif rec.column == 5
                center["medicare_costs"] = rec.value
            end
        end
    end

    return Dict{String,Any}(
        "cost_to_charge_ratios" => ratios,
    )
end
