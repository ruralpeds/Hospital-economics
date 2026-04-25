# ── Hospital cost accounting ───────────────────────────────────────────────
#
# Activity-based costing (ABC), step-down cost allocation, cost-to-charge
# ratio, department-level cost analysis, and marginal cost estimation.

"""
    cost_to_charge_ratio(total_costs::Float64, total_charges::Float64) -> Float64

Compute the hospital-wide cost-to-charge ratio (CCR).
CMS uses CCR to convert charges to estimated costs for outlier payments.
"""
function cost_to_charge_ratio(total_costs::Float64, total_charges::Float64)::Float64
    total_charges > 0 || throw(DomainValidationError("total_charges", string(total_charges),
        "> 0", "Total charges must be positive"))
    return total_costs / total_charges
end

"""
    estimate_cost_from_charges(charges::Float64, ccr::Float64) -> Float64

Convert charges to estimated costs using the cost-to-charge ratio.
"""
estimate_cost_from_charges(charges::Float64, ccr::Float64)::Float64 = charges * ccr

"""
    step_down_allocation(direct_costs::Vector{Float64}, allocation_matrix::Matrix{Float64}) -> Vector{Float64}

Step-down (sequential) cost allocation across departments.

# Arguments
- `direct_costs`: vector of direct costs per department (length n)
- `allocation_matrix`: n×n matrix where `[i,j]` = fraction of department i's
  costs allocated to department j.  Row i is the allocation basis for department i.
  Departments are allocated in order (index 1 first, n last).

# Returns
Vector of fully-allocated costs per department.
"""
function step_down_allocation(direct_costs::Vector{Float64},
                              allocation_matrix::Matrix{Float64})::Vector{Float64}
    n = length(direct_costs)
    size(allocation_matrix) == (n, n) || throw(
        DomainValidationError("allocation_matrix", "$(size(allocation_matrix))",
            "$(n)×$(n)", "Matrix dimensions must match department count"))

    allocated = copy(direct_costs)
    for i in 1:n
        # Allocate department i's total cost to downstream departments
        total = allocated[i]
        for j in (i+1):n
            share = total * allocation_matrix[i, j]
            allocated[j] += share
        end
        # Department i retains only its direct cost for reporting
    end
    return allocated
end

"""
    activity_based_cost(activities::Vector{NamedTuple}) -> DataFrame

Activity-based costing (ABC) for healthcare services.

Each activity is a NamedTuple with fields:
- `name::String` — activity name
- `cost_driver::String` — what drives the cost (e.g., "lab_tests", "nursing_hours")
- `total_cost::Float64` — total cost pool for this activity
- `volume::Int` — total driver volume
- `patient_volumes::Dict{String,Int}` — per-patient-type driver volumes

Returns DataFrame with cost per patient type per activity.
"""
function activity_based_cost(activities::Vector)::DataFrame
    rows = NamedTuple[]
    for act in activities
        rate = act.volume > 0 ? act.total_cost / act.volume : 0.0
        for (patient_type, vol) in act.patient_volumes
            push!(rows, (
                activity=act.name,
                cost_driver=act.cost_driver,
                patient_type=patient_type,
                driver_volume=vol,
                rate_per_unit=rate,
                allocated_cost=rate * vol,
            ))
        end
    end
    return DataFrame(rows)
end

"""
    marginal_cost(fixed_costs::Float64, variable_cost_per_unit::Float64,
                  current_volume::Int, additional_volume::Int) -> NamedTuple

Compute marginal cost of serving additional patients.

Returns `(marginal_cost_per_unit, total_incremental_cost, new_average_cost)`.
"""
function marginal_cost(fixed_costs::Float64, variable_cost_per_unit::Float64,
                       current_volume::Int, additional_volume::Int)
    additional_volume >= 0 || throw(DomainValidationError("additional_volume",
        string(additional_volume), "≥ 0", "Additional volume must be non-negative"))
    current_total = fixed_costs + variable_cost_per_unit * current_volume
    new_total = fixed_costs + variable_cost_per_unit * (current_volume + additional_volume)
    incremental = new_total - current_total
    mc_per_unit = additional_volume > 0 ? incremental / additional_volume : variable_cost_per_unit
    new_avg = (current_volume + additional_volume) > 0 ?
        new_total / (current_volume + additional_volume) : 0.0
    return (marginal_cost_per_unit=mc_per_unit, total_incremental_cost=incremental,
            new_average_cost=new_avg)
end

"""
    department_profitability(departments::Vector{NamedTuple}) -> DataFrame

Compute profitability metrics per department.

Each department is a NamedTuple: `(name, revenue, direct_costs, allocated_overhead, volume)`.
"""
function department_profitability(departments::Vector)::DataFrame
    rows = NamedTuple[]
    for d in departments
        total_cost = d.direct_costs + d.allocated_overhead
        margin = d.revenue - total_cost
        margin_pct = d.revenue > 0 ? margin / d.revenue : 0.0
        cost_per_case = d.volume > 0 ? total_cost / d.volume : 0.0
        rev_per_case = d.volume > 0 ? d.revenue / d.volume : 0.0
        push!(rows, (
            department=d.name,
            revenue=d.revenue,
            direct_costs=d.direct_costs,
            allocated_overhead=d.allocated_overhead,
            total_cost=total_cost,
            margin=margin,
            margin_pct=margin_pct,
            cost_per_case=cost_per_case,
            revenue_per_case=rev_per_case,
            volume=d.volume,
        ))
    end
    return DataFrame(rows)
end
