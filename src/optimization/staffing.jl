# Staffing Optimization
# Extracted from engines/optimization.jl

using JuMP
using HiGHS

# ---------------------------------------------------------------------------
# Staffing Optimization
# ---------------------------------------------------------------------------

"""
    StaffingResult

Result of the staffing optimization problem.

# Fields
- `status::Symbol`: Solver termination status (e.g., `:OPTIMAL`).
- `objective_value::Float64`: Minimised total staffing cost.
- `permanent_ftes::Dict{Symbol, Float64}`: Optimal permanent FTEs by department.
- `travel_ftes::Dict{Symbol, Float64}`: Optimal travel/agency FTEs by department.
- `shift_assignments::Dict{Tuple{Symbol, Symbol}, Float64}`: (department, shift) -> FTE assignments.
- `overtime_hours::Dict{Symbol, Float64}`: Overtime hours by department.
- `total_permanent_cost::Float64`: Total cost of permanent staff.
- `total_travel_cost::Float64`: Total cost of travel/agency staff.
- `total_overtime_cost::Float64`: Total overtime cost.
"""
struct StaffingResult
    status::Symbol
    objective_value::Float64
    permanent_ftes::Dict{Symbol, Float64}
    travel_ftes::Dict{Symbol, Float64}
    shift_assignments::Dict{Tuple{Symbol, Symbol}, Float64}
    overtime_hours::Dict{Symbol, Float64}
    total_permanent_cost::Float64
    total_travel_cost::Float64
    total_overtime_cost::Float64
end

"""
    optimize_staffing(;
        departments, shifts, demand, regulatory_minimums,
        permanent_salary, travel_salary_premium, overtime_rate,
        max_overtime_fraction, budget, ed_departments
    ) -> StaffingResult

Optimise hospital staffing to minimise total labor cost while satisfying
clinical and regulatory constraints.

# Arguments
- `departments::Vector{Symbol}`: List of departments (e.g., `[:ed, :medsurg, :ob, :lab, :radiology]`).
- `shifts::Vector{Symbol}`: Shift types (e.g., `[:day, :evening, :night]`).
- `demand::Dict{Tuple{Symbol, Symbol}, Float64}`: Required FTEs by `(department, shift)`.
- `regulatory_minimums::Dict{Symbol, Float64}`: Minimum total FTEs per department (regulatory floor).
- `permanent_salary::Dict{Symbol, Float64}`: Annual salary per permanent FTE by department.
- `travel_salary_premium::Float64`: Multiplier on permanent salary for travel staff (e.g., 1.8).
- `overtime_rate::Float64`: Multiplier on base hourly rate for overtime (e.g., 1.5).
- `max_overtime_fraction::Float64`: Maximum overtime as a fraction of regular hours (e.g., 0.2).
- `budget::Float64`: Total annual staffing budget constraint.
- `ed_departments::Vector{Symbol}`: Departments requiring 24/7 coverage.

# Constraints
1. **Demand coverage**: Each `(department, shift)` must have assigned FTEs >= demand.
2. **Regulatory minimums**: Each department's total FTEs >= regulatory minimum.
3. **24/7 ED coverage**: ED departments must have >= 2 FTEs on every shift.
4. **Budget**: Total staffing cost <= budget.
5. **Overtime cap**: Overtime hours <= `max_overtime_fraction` * regular capacity.

# Objective
Minimise total cost = permanent cost + travel cost + overtime cost.
"""
function optimize_staffing(;
    departments::Vector{Symbol},
    shifts::Vector{Symbol},
    demand::Dict{Tuple{Symbol, Symbol}, Float64},
    regulatory_minimums::Dict{Symbol, Float64},
    permanent_salary::Dict{Symbol, Float64},
    travel_salary_premium::Float64 = 1.8,
    overtime_rate::Float64 = 1.5,
    max_overtime_fraction::Float64 = 0.2,
    budget::Float64 = 10_000_000.0,
    ed_departments::Vector{Symbol} = [:ed],
)::StaffingResult

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    n_dept = length(departments)
    n_shift = length(shifts)

    # --- Decision Variables ---

    # Permanent FTEs per department
    @variable(model, perm[d in departments] >= 0)

    # Travel/agency FTEs per department
    @variable(model, travel[d in departments] >= 0)

    # Shift assignments: permanent staff assigned to each (department, shift)
    @variable(model, shift_assign[d in departments, s in shifts] >= 0)

    # Overtime hours per department (annualised FTE-equivalent)
    @variable(model, overtime[d in departments] >= 0)

    # --- Objective: Minimise total staffing cost ---
    permanent_cost = @expression(model, sum(perm[d] * permanent_salary[d] for d in departments))
    travel_cost = @expression(model, sum(travel[d] * permanent_salary[d] * travel_salary_premium for d in departments))
    overtime_cost = @expression(model, sum(overtime[d] * permanent_salary[d] * overtime_rate / n_shift for d in departments))

    @objective(model, Min, permanent_cost + travel_cost + overtime_cost)

    # --- Constraints ---

    # 1. Demand coverage: assigned permanent + travel + overtime >= demand for each (dept, shift)
    for d in departments
        for s in shifts
            key = (d, s)
            dem = get(demand, key, 0.0)
            @constraint(model,
                shift_assign[d, s] + travel[d] / n_shift + overtime[d] / n_shift >= dem
            )
        end
    end

    # 2. Shift assignments must sum to total permanent FTEs per department
    for d in departments
        @constraint(model, sum(shift_assign[d, s] for s in shifts) == perm[d])
    end

    # 3. Regulatory minimums
    for d in departments
        min_fte = get(regulatory_minimums, d, 0.0)
        @constraint(model, perm[d] + travel[d] >= min_fte)
    end

    # 4. 24/7 ED coverage: ED departments need at least 2 FTEs on every shift
    for d in ed_departments
        for s in shifts
            @constraint(model, shift_assign[d, s] + travel[d] / n_shift >= 2.0)
        end
    end

    # 5. Budget constraint
    @constraint(model, permanent_cost + travel_cost + overtime_cost <= budget)

    # 6. Overtime cap
    for d in departments
        @constraint(model, overtime[d] <= max_overtime_fraction * perm[d])
    end

    # --- Solve ---
    optimize!(model)

    status = Symbol(termination_status(model))
    obj_val = has_values(model) ? objective_value(model) : Inf

    # Extract results
    perm_result = Dict(d => (has_values(model) ? value(perm[d]) : 0.0) for d in departments)
    travel_result = Dict(d => (has_values(model) ? value(travel[d]) : 0.0) for d in departments)
    shift_result = Dict(
        (d, s) => (has_values(model) ? value(shift_assign[d, s]) : 0.0)
        for d in departments for s in shifts
    )
    ot_result = Dict(d => (has_values(model) ? value(overtime[d]) : 0.0) for d in departments)

    perm_total = has_values(model) ? value(permanent_cost) : 0.0
    trav_total = has_values(model) ? value(travel_cost) : 0.0
    ot_total = has_values(model) ? value(overtime_cost) : 0.0

    return StaffingResult(
        status, obj_val,
        perm_result, travel_result, shift_result, ot_result,
        perm_total, trav_total, ot_total,
    )
end
