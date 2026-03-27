# ============================================================================
# CMS Form 2552-10 Cost Report Simulation
# ============================================================================

# Uses CostCenter and CostReport types from types/financial.jl —
# no duplicate struct definitions needed here.

"""
    default_cah_cost_centers() -> Vector{CostCenter}

Return a standard set of cost centers typical for a Critical Access Hospital,
using CMS codes 0500 through 6500. Values represent realistic medians.
"""
function default_cah_cost_centers()
    return CostCenter[
        CostCenter(cost_center_code="0500", name="Adults & Pediatrics (General)", category=:direct_patient, is_revenue_producing=true, direct_costs=1_200_000.0, charges=3_000_000.0),
        CostCenter(cost_center_code="0600", name="Intensive Care Unit", category=:direct_patient, is_revenue_producing=true, direct_costs=0.0, charges=0.0),
        CostCenter(cost_center_code="1100", name="Skilled Nursing Facility", category=:direct_patient, is_revenue_producing=true, direct_costs=800_000.0, charges=1_600_000.0),
        CostCenter(cost_center_code="2500", name="Operating Room", category=:ancillary, is_revenue_producing=true, direct_costs=600_000.0, charges=2_400_000.0),
        CostCenter(cost_center_code="2600", name="Recovery Room", category=:ancillary, is_revenue_producing=true, direct_costs=120_000.0, charges=300_000.0),
        CostCenter(cost_center_code="2900", name="Radiology - Diagnostic", category=:ancillary, is_revenue_producing=true, direct_costs=450_000.0, charges=1_800_000.0),
        CostCenter(cost_center_code="3000", name="Radiology - Therapeutic", category=:ancillary, is_revenue_producing=true, direct_costs=80_000.0, charges=320_000.0),
        CostCenter(cost_center_code="3200", name="Laboratory", category=:ancillary, is_revenue_producing=true, direct_costs=500_000.0, charges=2_000_000.0),
        CostCenter(cost_center_code="3400", name="Respiratory Therapy", category=:ancillary, is_revenue_producing=true, direct_costs=150_000.0, charges=600_000.0),
        CostCenter(cost_center_code="3500", name="Physical Therapy", category=:ancillary, is_revenue_producing=true, direct_costs=200_000.0, charges=800_000.0),
        CostCenter(cost_center_code="3600", name="Occupational Therapy", category=:ancillary, is_revenue_producing=true, direct_costs=100_000.0, charges=400_000.0),
        CostCenter(cost_center_code="3700", name="Speech Pathology", category=:ancillary, is_revenue_producing=true, direct_costs=60_000.0, charges=240_000.0),
        CostCenter(cost_center_code="4000", name="Medical Supplies", category=:ancillary, is_revenue_producing=true, direct_costs=350_000.0, charges=1_400_000.0),
        CostCenter(cost_center_code="4100", name="Drugs Charged to Patients", category=:ancillary, is_revenue_producing=true, direct_costs=400_000.0, charges=1_600_000.0),
        CostCenter(cost_center_code="6000", name="Clinic", category=:direct_patient, is_revenue_producing=true, direct_costs=300_000.0, charges=750_000.0),
        CostCenter(cost_center_code="6100", name="Emergency", category=:direct_patient, is_revenue_producing=true, direct_costs=500_000.0, charges=2_000_000.0),
        CostCenter(cost_center_code="6200", name="Observation", category=:direct_patient, is_revenue_producing=true, direct_costs=100_000.0, charges=400_000.0),
        CostCenter(cost_center_code="6500", name="Other Outpatient Services", category=:direct_patient, is_revenue_producing=true, direct_costs=150_000.0, charges=600_000.0),
        # Overhead cost centers
        CostCenter(cost_center_code="8800", name="Administrative & General", category=:overhead, is_revenue_producing=false, direct_costs=1_500_000.0, charges=0.0),
        CostCenter(cost_center_code="8810", name="Maintenance & Repairs", category=:overhead, is_revenue_producing=false, direct_costs=350_000.0, charges=0.0),
        CostCenter(cost_center_code="8820", name="Employee Benefits", category=:overhead, is_revenue_producing=false, direct_costs=1_200_000.0, charges=0.0),
        CostCenter(cost_center_code="8830", name="Housekeeping", category=:overhead, is_revenue_producing=false, direct_costs=200_000.0, charges=0.0),
        CostCenter(cost_center_code="8840", name="Dietary", category=:overhead, is_revenue_producing=false, direct_costs=280_000.0, charges=0.0),
        CostCenter(cost_center_code="8850", name="Depreciation", category=:overhead, is_revenue_producing=false, direct_costs=600_000.0, charges=0.0),
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
    charges_map = Dict{String,Float64}()

    for cc in cost_centers
        if !cc.is_revenue_producing
            overhead[cc.cost_center_code] = cc.direct_costs
        else
            revenue[cc.cost_center_code] = cc.direct_costs
            charges_map[cc.cost_center_code] = cc.charges
        end
    end

    total_rev_charges = sum(values(charges_map))

    # Allocate each overhead center in order
    for oh_code in order
        if !haskey(overhead, oh_code)
            continue
        end
        amount_to_allocate = overhead[oh_code]
        if total_rev_charges <= 0.0 || amount_to_allocate <= 0.0
            continue
        end

        for (rev_code, rev_charges) in charges_map
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

    cc_lookup = Dict(cc.cost_center_code => cc for cc in cost_centers if cc.is_revenue_producing)

    for (code, total_cost) in allocated_costs
        cc = get(cc_lookup, code, nothing)
        if cc === nothing || cc.charges <= 0.0
            continue
        end
        # Use cost_to_charge_ratio as a proxy for Medicare share when available
        medicare_ratio = cc.cost_to_charge_ratio > 0.0 ? cc.cost_to_charge_ratio : 0.0
        medicare_cost += total_cost * medicare_ratio
    end

    return medicare_cost
end

"""
    build_cost_report(provider_number::String, fiscal_year_begin::Date,
                      fiscal_year_end::Date,
                      cost_centers::Vector{CostCenter}) -> CostReport

Build a complete cost report from a set of cost centers by performing
step-down allocation and computing Medicare cost shares.
"""
function build_cost_report(provider_number::String, fiscal_year_begin::Date,
                           fiscal_year_end::Date,
                           cost_centers::Vector{CostCenter})
    allocated = step_down_allocation(cost_centers)

    total_costs = sum(cc.direct_costs for cc in cost_centers)
    total_charges = sum(cc.charges for cc in cost_centers if cc.is_revenue_producing)

    ccr = total_charges > 0.0 ? total_costs / total_charges : 0.0
    medicare_share = calculate_medicare_cost_share(allocated, cost_centers)

    # Update each cost center's allocated_costs and total_costs
    for cc in cost_centers
        if cc.is_revenue_producing && haskey(allocated, cc.cost_center_code)
            cc.allocated_costs = allocated[cc.cost_center_code] - cc.direct_costs
            cc.total_costs = allocated[cc.cost_center_code]
            cc.cost_to_charge_ratio = cc.charges > 0.0 ? cc.total_costs / cc.charges : 0.0
        end
    end

    return CostReport(
        provider_number = provider_number,
        fiscal_year_begin = fiscal_year_begin,
        fiscal_year_end = fiscal_year_end,
        cost_centers = cost_centers,
        allocation_basis = AllocationBasis(method=:step_down, overhead_order=default_step_down_order()),
        total_costs = total_costs,
        total_charges = total_charges,
        overall_cost_to_charge_ratio = ccr,
        medicare_allowable_costs = medicare_share,
    )
end
