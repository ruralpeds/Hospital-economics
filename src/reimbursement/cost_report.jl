# ============================================================================
# CMS Form 2552-10 Cost Report Simulation
# ============================================================================

"""
    CostCenter

Represents a single cost center in the Medicare cost report.
"""
struct CostCenter
    code::String
    name::String
    direct_cost::Float64
    total_charges::Float64
    medicare_charges::Float64
    is_overhead::Bool
end

"""
    CostReport

Aggregated cost report data following CMS Form 2552-10 structure.
"""
struct CostReport
    provider_id::String
    fiscal_year::Int
    cost_centers::Vector{CostCenter}
    total_costs::Float64
    total_charges::Float64
    total_medicare_charges::Float64
    cost_to_charge_ratio::Float64
    medicare_cost_share::Float64
    allocated_costs::Dict{String,Float64}
end

"""
    default_cah_cost_centers() -> Vector{CostCenter}

Return a standard set of cost centers typical for a Critical Access Hospital,
using CMS codes 0500 through 6500. Values represent realistic medians.
"""
function default_cah_cost_centers()
    return CostCenter[
        CostCenter("0500", "Adults & Pediatrics (General)", 1_200_000.0, 3_000_000.0, 1_350_000.0, false),
        CostCenter("0600", "Intensive Care Unit", 0.0, 0.0, 0.0, false),
        CostCenter("1100", "Skilled Nursing Facility", 800_000.0, 1_600_000.0, 1_120_000.0, false),
        CostCenter("2500", "Operating Room", 600_000.0, 2_400_000.0, 960_000.0, false),
        CostCenter("2600", "Recovery Room", 120_000.0, 300_000.0, 120_000.0, false),
        CostCenter("2900", "Radiology - Diagnostic", 450_000.0, 1_800_000.0, 810_000.0, false),
        CostCenter("3000", "Radiology - Therapeutic", 80_000.0, 320_000.0, 144_000.0, false),
        CostCenter("3200", "Laboratory", 500_000.0, 2_000_000.0, 900_000.0, false),
        CostCenter("3400", "Respiratory Therapy", 150_000.0, 600_000.0, 270_000.0, false),
        CostCenter("3500", "Physical Therapy", 200_000.0, 800_000.0, 360_000.0, false),
        CostCenter("3600", "Occupational Therapy", 100_000.0, 400_000.0, 180_000.0, false),
        CostCenter("3700", "Speech Pathology", 60_000.0, 240_000.0, 108_000.0, false),
        CostCenter("4000", "Medical Supplies", 350_000.0, 1_400_000.0, 630_000.0, false),
        CostCenter("4100", "Drugs Charged to Patients", 400_000.0, 1_600_000.0, 720_000.0, false),
        CostCenter("6000", "Clinic", 300_000.0, 750_000.0, 337_500.0, false),
        CostCenter("6100", "Emergency", 500_000.0, 2_000_000.0, 900_000.0, false),
        CostCenter("6200", "Observation", 100_000.0, 400_000.0, 180_000.0, false),
        CostCenter("6500", "Other Outpatient Services", 150_000.0, 600_000.0, 270_000.0, false),
        # Overhead cost centers
        CostCenter("8800", "Administrative & General", 1_500_000.0, 0.0, 0.0, true),
        CostCenter("8810", "Maintenance & Repairs", 350_000.0, 0.0, 0.0, true),
        CostCenter("8820", "Employee Benefits", 1_200_000.0, 0.0, 0.0, true),
        CostCenter("8830", "Housekeeping", 200_000.0, 0.0, 0.0, true),
        CostCenter("8840", "Dietary", 280_000.0, 0.0, 0.0, true),
        CostCenter("8850", "Depreciation", 600_000.0, 0.0, 0.0, true),
    ]
end

"""
    default_step_down_order() -> Vector{String}

Return the standard step-down cost allocation order for overhead cost centers,
per CMS guidelines. Overhead centers are allocated in sequence from least
to most revenue-producing.
"""
function default_step_down_order()
    return [
        "8850",  # Depreciation
        "8800",  # Administrative & General
        "8820",  # Employee Benefits
        "8810",  # Maintenance & Repairs
        "8830",  # Housekeeping
        "8840",  # Dietary
    ]
end

"""
    step_down_allocation(cost_centers::Vector{CostCenter};
                         order::Vector{String}=default_step_down_order()) -> Dict{String,Float64}

Perform step-down cost allocation following CMS cost-finding methodology.

Overhead cost centers are allocated to revenue-producing centers based on
each center's share of total charges. Once an overhead center has been
allocated, it receives no further allocations from subsequent overhead centers.

Returns a dictionary mapping each revenue-producing cost center code to its
fully-allocated total cost.
"""
function step_down_allocation(cost_centers::Vector{CostCenter};
                              order::Vector{String}=default_step_down_order())
    # Separate overhead from revenue-producing centers
    overhead = Dict{String,Float64}()
    revenue = Dict{String,Float64}()
    charges = Dict{String,Float64}()

    for cc in cost_centers
        if cc.is_overhead
            overhead[cc.code] = cc.direct_cost
        else
            revenue[cc.code] = cc.direct_cost
            charges[cc.code] = cc.total_charges
        end
    end

    total_rev_charges = sum(values(charges))

    # Allocate each overhead center in order
    for oh_code in order
        if !haskey(overhead, oh_code)
            continue
        end
        amount_to_allocate = overhead[oh_code]
        if total_rev_charges <= 0.0 || amount_to_allocate <= 0.0
            continue
        end

        for (rev_code, rev_charges) in charges
            share = rev_charges / total_rev_charges
            revenue[rev_code] += amount_to_allocate * share
        end

        delete!(overhead, oh_code)
    end

    return revenue
end

"""
    calculate_medicare_cost_share(allocated_costs::Dict{String,Float64},
                                  cost_centers::Vector{CostCenter}) -> Float64

Calculate Medicare's share of total allocated costs using the ratio of
Medicare charges to total charges for each revenue-producing cost center.
"""
function calculate_medicare_cost_share(allocated_costs::Dict{String,Float64},
                                       cost_centers::Vector{CostCenter})
    medicare_cost = 0.0

    cc_lookup = Dict(cc.code => cc for cc in cost_centers if !cc.is_overhead)

    for (code, total_cost) in allocated_costs
        cc = get(cc_lookup, code, nothing)
        if cc === nothing || cc.total_charges <= 0.0
            continue
        end
        medicare_ratio = cc.medicare_charges / cc.total_charges
        medicare_cost += total_cost * medicare_ratio
    end

    return medicare_cost
end

"""
    build_cost_report(provider_id::String, fiscal_year::Int,
                      cost_centers::Vector{CostCenter}) -> CostReport

Build a complete cost report from a set of cost centers by performing
step-down allocation and computing Medicare cost shares.
"""
function build_cost_report(provider_id::String, fiscal_year::Int,
                           cost_centers::Vector{CostCenter})
    allocated = step_down_allocation(cost_centers)

    total_costs = sum(cc.direct_cost for cc in cost_centers)
    total_charges = sum(cc.total_charges for cc in cost_centers if !cc.is_overhead)
    total_medicare = sum(cc.medicare_charges for cc in cost_centers if !cc.is_overhead)

    ccr = total_charges > 0.0 ? total_costs / total_charges : 0.0
    medicare_share = calculate_medicare_cost_share(allocated, cost_centers)

    return CostReport(
        provider_id,
        fiscal_year,
        cost_centers,
        total_costs,
        total_charges,
        total_medicare,
        ccr,
        medicare_share,
        allocated,
    )
end
