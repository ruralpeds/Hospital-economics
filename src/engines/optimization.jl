# Mathematical Optimization Engine
# Staffing and service portfolio optimization using JuMP.jl with the HiGHS solver.

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

# ---------------------------------------------------------------------------
# Service Portfolio Optimization
# ---------------------------------------------------------------------------

"""
    ServicePortfolioResult

Result of the service line portfolio optimization.

# Fields
- `status::Symbol`: Solver termination status.
- `objective_value::Float64`: Maximised total contribution margin.
- `selected_services::Dict{Symbol, Bool}`: Whether each service is selected.
- `allocated_capacity::Dict{Symbol, Float64}`: Capacity (FTEs/beds) allocated to each selected service.
- `expected_revenue::Dict{Symbol, Float64}`: Projected revenue per service.
- `expected_cost::Dict{Symbol, Float64}`: Projected cost per service.
- `contribution_margins::Dict{Symbol, Float64}`: Contribution margin per service.
"""
struct ServicePortfolioResult
    status::Symbol
    objective_value::Float64
    selected_services::Dict{Symbol, Bool}
    allocated_capacity::Dict{Symbol, Float64}
    expected_revenue::Dict{Symbol, Float64}
    expected_cost::Dict{Symbol, Float64}
    contribution_margins::Dict{Symbol, Float64}
end

"""
    optimize_service_portfolio(;
        services, revenue_per_unit, cost_per_unit, volume_potential,
        capacity_requirement, total_capacity, fixed_costs,
        required_services, max_services, community_need_weight,
        community_need_scores
    ) -> ServicePortfolioResult

Optimise the portfolio of clinical service lines to maximise total
contribution margin subject to capacity, regulatory, and community need constraints.

# Arguments
- `services::Vector{Symbol}`: Candidate service lines (e.g., `[:ed, :primary_care, :ob, :surgery, :telehealth]`).
- `revenue_per_unit::Dict{Symbol, Float64}`: Expected revenue per unit of service.
- `cost_per_unit::Dict{Symbol, Float64}`: Variable cost per unit of service.
- `volume_potential::Dict{Symbol, Float64}`: Estimated annual volume per service line.
- `capacity_requirement::Dict{Symbol, Float64}`: Capacity units (FTEs/beds) required per service.
- `total_capacity::Float64`: Total available capacity units.
- `fixed_costs::Dict{Symbol, Float64}`: Fixed annual cost to operate each service line.
- `required_services::Vector{Symbol}`: Services that must be included (regulatory requirement).
- `max_services::Int`: Maximum number of service lines to operate.
- `community_need_weight::Float64`: Weight given to community need in the objective (0.0-1.0).
- `community_need_scores::Dict{Symbol, Float64}`: Community benefit score per service (0.0-1.0).

# Objective
Maximise: (1 - w) * contribution_margin + w * community_benefit

where `w = community_need_weight`.
"""
function optimize_service_portfolio(;
    services::Vector{Symbol},
    revenue_per_unit::Dict{Symbol, Float64},
    cost_per_unit::Dict{Symbol, Float64},
    volume_potential::Dict{Symbol, Float64},
    capacity_requirement::Dict{Symbol, Float64},
    total_capacity::Float64,
    fixed_costs::Dict{Symbol, Float64},
    required_services::Vector{Symbol} = Symbol[],
    max_services::Int = length(services),
    community_need_weight::Float64 = 0.2,
    community_need_scores::Dict{Symbol, Float64} = Dict(s => 0.5 for s in services),
)::ServicePortfolioResult

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    # --- Decision Variables ---

    # Binary: whether to offer each service
    @variable(model, select[s in services], Bin)

    # Continuous: capacity allocated to each service
    @variable(model, capacity[s in services] >= 0)

    # --- Derived Expressions ---

    # Revenue per service = revenue_per_unit * min(volume_potential, capacity-driven volume)
    # Simplified: volume scales linearly with allocated capacity up to potential
    service_revenue = Dict{Symbol, Any}()
    service_cost = Dict{Symbol, Any}()
    service_margin = Dict{Symbol, Any}()

    for s in services
        vol = volume_potential[s]
        rev = @expression(model, revenue_per_unit[s] * vol * select[s])
        cost_var = @expression(model, cost_per_unit[s] * vol * select[s] + fixed_costs[s] * select[s])
        service_revenue[s] = rev
        service_cost[s] = cost_var
        service_margin[s] = @expression(model, rev - cost_var)
    end

    total_margin = @expression(model, sum(service_margin[s] for s in services))
    community_benefit = @expression(model,
        sum(community_need_scores[s] * volume_potential[s] * select[s] for s in services)
    )

    # Normalise community benefit for objective scaling
    max_possible_benefit = sum(community_need_scores[s] * volume_potential[s] for s in services)
    norm_benefit = max_possible_benefit > 0 ? community_benefit / max_possible_benefit : 0.0

    # Scale margin for comparable magnitude (rough normalisation)
    max_possible_margin = sum(
        (revenue_per_unit[s] - cost_per_unit[s]) * volume_potential[s] - fixed_costs[s]
        for s in services
    )
    norm_margin = max_possible_margin > 0 ? total_margin / max_possible_margin : 0.0

    # --- Objective ---
    w = community_need_weight
    @objective(model, Max, (1.0 - w) * norm_margin + w * norm_benefit)

    # --- Constraints ---

    # Capacity constraint
    @constraint(model, sum(capacity_requirement[s] * select[s] for s in services) <= total_capacity)

    # Required services
    for s in required_services
        @constraint(model, select[s] == 1)
    end

    # Maximum number of services
    @constraint(model, sum(select[s] for s in services) <= max_services)

    # Capacity allocation consistency
    for s in services
        @constraint(model, capacity[s] <= capacity_requirement[s] * select[s])
        @constraint(model, capacity[s] >= 0.5 * capacity_requirement[s] * select[s])  # min viable scale
    end

    # --- Solve ---
    optimize!(model)

    status = Symbol(termination_status(model))
    obj_val = has_values(model) ? objective_value(model) : -Inf

    selected = Dict(s => (has_values(model) ? value(select[s]) > 0.5 : false) for s in services)
    alloc_cap = Dict(s => (has_values(model) ? value(capacity[s]) : 0.0) for s in services)

    exp_rev = Dict{Symbol, Float64}()
    exp_cost = Dict{Symbol, Float64}()
    margins = Dict{Symbol, Float64}()

    for s in services
        if selected[s]
            vol = volume_potential[s]
            exp_rev[s] = revenue_per_unit[s] * vol
            exp_cost[s] = cost_per_unit[s] * vol + fixed_costs[s]
            margins[s] = exp_rev[s] - exp_cost[s]
        else
            exp_rev[s] = 0.0
            exp_cost[s] = 0.0
            margins[s] = 0.0
        end
    end

    return ServicePortfolioResult(
        status, obj_val,
        selected, alloc_cap,
        exp_rev, exp_cost, margins,
    )
end
