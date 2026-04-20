# optimization/OutcomeOptimization.jl
# Outcome optimization under constraints using JuMP
# Optimize healthcare economics decisions across networks and service lines

using JuMP
using HiGHS
using LinearAlgebra
using Statistics

"""
    CostMinimizationProblem

Formulates and solves cost minimization problem under quality constraints.

# Fields
- `model::Model` — JuMP model
- `service_lines::Vector{String}` — Service line identifiers
- `volumes::Dict{String, Int}` — Patient volumes per service line
- `costs::Dict{String, Float64}` — Average cost per patient per service
- `quality_scores::Dict{String, Float64}` — Current quality scores
- `quality_threshold::Float64` — Minimum acceptable quality (0-1)
- `solution::Dict{String, Any}` — Optimization solution
"""
mutable struct CostMinimizationProblem
    model::Model
    service_lines::Vector{String}
    volumes::Dict{String, Int}
    costs::Dict{String, Float64}
    quality_scores::Dict{String, Float64}
    quality_threshold::Float64
    solution::Dict{String, Any}
end

"""
    QualityMaximizationProblem

Formulates and solves quality maximization problem under budget constraints.

# Fields
- `model::Model` — JuMP model
- `service_lines::Vector{String}` — Service line identifiers
- `volumes::Dict{String, Int}` — Patient volumes per service line
- `quality_improvement_cost::Dict{String, Float64}` — Cost to improve quality by 1%
- `current_quality::Dict{String, Float64}` — Current quality scores
- `budget::Float64` — Total available budget
- `solution::Dict{String, Any}` — Optimization solution
"""
mutable struct QualityMaximizationProblem
    model::Model
    service_lines::Vector{String}
    volumes::Dict{String, Int}
    quality_improvement_cost::Dict{String, Float64}
    current_quality::Dict{String, Float64}
    budget::Float64
    solution::Dict{String, Any}
end

"""
    ServiceLinePortfolioOptimization

Optimizes service line portfolio composition and investment levels.

# Fields
- `model::Model` — JuMP model
- `service_lines::Vector{String}` — Available service lines
- `investment_costs::Dict{String, Float64}` — Setup/infrastructure cost per service
- `revenue_per_volume::Dict{String, Float64}` — Revenue per patient per service
- `quality_potential::Dict{String, Float64}` — Maximum achievable quality
- `volume_constraints::Dict{String, Tuple{Int, Int}}` — Min/max volume per service
- `total_budget::Float64` — Total investment budget
- `solution::Dict{String, Any}` — Optimization solution
"""
mutable struct ServiceLinePortfolioOptimization
    model::Model
    service_lines::Vector{String}
    investment_costs::Dict{String, Float64}
    revenue_per_volume::Dict{String, Float64}
    quality_potential::Dict{String, Float64}
    volume_constraints::Dict{String, Tuple{Int, Int}}
    total_budget::Float64
    solution::Dict{String, Any}
end

"""
    HospitalCapacityAllocation

Optimizes bed and resource allocation across hospital departments.

# Fields
- `model::Model` — JuMP model
- `hospitals::Vector{String}` — Hospital identifiers
- `departments::Vector{String}` — Department/service line identifiers
- `total_beds::Dict{String, Int}` — Total beds per hospital
- `demand::Dict{Tuple{String, String}, Int}` — Demand (hospital, dept) -> volume
- `cost_per_bed::Dict{String, Float64}` — Daily cost per bed by department
- `revenue_per_case::Dict{String, Float64}` — Revenue per case by department
- `quality_per_bed::Dict{String, Float64}` — Quality impact per allocated bed
- `solution::Dict{String, Any}` — Optimization solution
"""
mutable struct HospitalCapacityAllocation
    model::Model
    hospitals::Vector{String}
    departments::Vector{String}
    total_beds::Dict{String, Int}
    demand::Dict{Tuple{String, String}, Int}
    cost_per_bed::Dict{String, Float64}
    revenue_per_case::Dict{String, Float64}
    quality_per_bed::Dict{String, Float64}
    solution::Dict{String, Any}
end

"""
    create_cost_minimization_model(
        service_lines::Vector{String},
        volumes::Dict{String, Int},
        costs::Dict{String, Float64},
        quality_scores::Dict{String, Float64},
        quality_threshold::Float64 = 0.70
    )::CostMinimizationProblem

Create and formulate cost minimization problem under quality constraints.
"""
function create_cost_minimization_model(
    service_lines::Vector{String},
    volumes::Dict{String, Int},
    costs::Dict{String, Float64},
    quality_scores::Dict{String, Float64},
    quality_threshold::Float64 = 0.70
)::CostMinimizationProblem
    model = Model(HiGHS.Optimizer)
    set_silent(model)

    # Decision variables: cost multiplier per service line (0.5 = 50% cost reduction)
    @variable(model, 0.5 <= cost_multiplier[sl in service_lines] <= 1.0)

    # Quality variables: quality improvement factors (1.0 = maintain, 1.2 = 20% improvement)
    @variable(model, 1.0 <= quality_factor[sl in service_lines] <= 1.5)

    # Cost-quality relationship: improving quality requires maintaining/increasing costs
    for sl in service_lines
        @constraint(model, cost_multiplier[sl] >= 0.8 * quality_factor[sl] - 0.3)
    end

    # Quality constraints: must maintain minimum quality
    for sl in service_lines
        @constraint(model, quality_factor[sl] * quality_scores[sl] >= quality_threshold)
    end

    # Objective: minimize total cost
    total_cost = sum(
        volumes[sl] * costs[sl] * cost_multiplier[sl]
        for sl in service_lines
    )
    @objective(model, Min, total_cost)

    return CostMinimizationProblem(
        model, service_lines, volumes, costs, quality_scores, quality_threshold,
        Dict{String, Any}()
    )
end

"""
    solve_cost_minimization(problem::CostMinimizationProblem)::Dict{String, Any}

Solve cost minimization problem and extract solution.
"""
function solve_cost_minimization(problem::CostMinimizationProblem)::Dict{String, Any}
    optimize!(problem.model)

    solution = Dict{String, Any}(
        "status" => termination_status(problem.model),
        "objective_value" => objective_value(problem.model),
        "cost_multipliers" => Dict(),
        "quality_factors" => Dict(),
        "total_cost_reduction" => 0.0,
        "quality_maintained" => true
    )

    if termination_status(problem.model) == OPTIMAL
        for sl in problem.service_lines
            solution["cost_multipliers"][sl] = value(problem.model[:cost_multiplier][sl])
            solution["quality_factors"][sl] = value(problem.model[:quality_factor][sl])
        end

        original_cost = sum(
            problem.volumes[sl] * problem.costs[sl]
            for sl in problem.service_lines
        )
        optimized_cost = solution["objective_value"]
        solution["total_cost_reduction"] = original_cost - optimized_cost
    end

    problem.solution = solution
    return solution
end

"""
    create_quality_maximization_model(
        service_lines::Vector{String},
        volumes::Dict{String, Int},
        quality_improvement_cost::Dict{String, Float64},
        current_quality::Dict{String, Float64},
        budget::Float64
    )::QualityMaximizationProblem

Create and formulate quality maximization problem under budget constraints.
"""
function create_quality_maximization_model(
    service_lines::Vector{String},
    volumes::Dict{String, Int},
    quality_improvement_cost::Dict{String, Float64},
    current_quality::Dict{String, Float64},
    budget::Float64
)::QualityMaximizationProblem
    model = Model(HiGHS.Optimizer)
    set_silent(model)

    # Decision variables: quality improvement factor per service line
    @variable(model, 0.0 <= quality_improvement[sl in service_lines] <= 0.3)

    # Budget constraint: total improvement spending cannot exceed budget
    @constraint(
        model,
        sum(volumes[sl] * quality_improvement_cost[sl] * quality_improvement[sl]
            for sl in service_lines) <= budget
    )

    # Quality bounds: cannot exceed 1.0 (perfect quality)
    for sl in service_lines
        @constraint(model, current_quality[sl] + quality_improvement[sl] <= 1.0)
    end

    # Objective: maximize weighted quality across all service lines
    total_quality = sum(
        volumes[sl] * (current_quality[sl] + quality_improvement[sl])
        for sl in service_lines
    )
    @objective(model, Max, total_quality)

    return QualityMaximizationProblem(
        model, service_lines, volumes, quality_improvement_cost, current_quality, budget,
        Dict{String, Any}()
    )
end

"""
    solve_quality_maximization(problem::QualityMaximizationProblem)::Dict{String, Any}

Solve quality maximization problem and extract solution.
"""
function solve_quality_maximization(problem::QualityMaximizationProblem)::Dict{String, Any}
    optimize!(problem.model)

    solution = Dict{String, Any}(
        "status" => termination_status(problem.model),
        "objective_value" => objective_value(problem.model),
        "quality_improvements" => Dict(),
        "new_quality_scores" => Dict(),
        "investment_amounts" => Dict(),
        "budget_used" => 0.0
    )

    if termination_status(problem.model) == OPTIMAL
        budget_used = 0.0
        for sl in problem.service_lines
            improvement = value(problem.model[:quality_improvement][sl])
            solution["quality_improvements"][sl] = improvement
            solution["new_quality_scores"][sl] = problem.current_quality[sl] + improvement
            investment = problem.volumes[sl] * problem.quality_improvement_cost[sl] * improvement
            solution["investment_amounts"][sl] = investment
            budget_used += investment
        end
        solution["budget_used"] = budget_used
    end

    problem.solution = solution
    return solution
end

"""
    create_service_line_portfolio_model(
        service_lines::Vector{String},
        investment_costs::Dict{String, Float64},
        revenue_per_volume::Dict{String, Float64},
        quality_potential::Dict{String, Float64},
        volume_constraints::Dict{String, Tuple{Int, Int}},
        total_budget::Float64
    )::ServiceLinePortfolioOptimization

Create portfolio optimization model for service line composition.
"""
function create_service_line_portfolio_model(
    service_lines::Vector{String},
    investment_costs::Dict{String, Float64},
    revenue_per_volume::Dict{String, Float64},
    quality_potential::Dict{String, Float64},
    volume_constraints::Dict{String, Tuple{Int, Int}},
    total_budget::Float64
)::ServiceLinePortfolioOptimization
    model = Model(HiGHS.Optimizer)
    set_silent(model)

    # Binary variables: whether to offer each service line (1) or not (0)
    @variable(model, offer[sl in service_lines], Bin)

    # Continuous variables: volume per service line
    @variable(model, volume[sl in service_lines] >= 0)

    # Investment constraint: total investment in offered services
    @constraint(
        model,
        sum(investment_costs[sl] * offer[sl] for sl in service_lines) <= total_budget
    )

    # Volume constraints: only volumes for offered services
    for sl in service_lines
        min_vol, max_vol = volume_constraints[sl]
        @constraint(model, volume[sl] >= min_vol * offer[sl])
        @constraint(model, volume[sl] <= max_vol * offer[sl])
    end

    # Objective: maximize total profit (revenue - investment)
    total_profit = sum(
        revenue_per_volume[sl] * volume[sl] - investment_costs[sl] * offer[sl]
        for sl in service_lines
    )
    @objective(model, Max, total_profit)

    return ServiceLinePortfolioOptimization(
        model, service_lines, investment_costs, revenue_per_volume, quality_potential,
        volume_constraints, total_budget, Dict{String, Any}()
    )
end

"""
    solve_service_line_portfolio(problem::ServiceLinePortfolioOptimization)::Dict{String, Any}

Solve service line portfolio optimization and extract solution.
"""
function solve_service_line_portfolio(problem::ServiceLinePortfolioOptimization)::Dict{String, Any}
    optimize!(problem.model)

    solution = Dict{String, Any}(
        "status" => termination_status(problem.model),
        "objective_value" => objective_value(problem.model),
        "selected_services" => String[],
        "volumes" => Dict(),
        "investments" => Dict(),
        "revenues" => Dict(),
        "total_investment" => 0.0,
        "total_revenue" => 0.0,
        "expected_quality" => 0.0
    )

    if termination_status(problem.model) == OPTIMAL
        total_investment = 0.0
        total_revenue = 0.0
        total_quality = 0.0

        for sl in problem.service_lines
            if value(problem.model[:offer][sl]) > 0.5
                push!(solution["selected_services"], sl)
                vol = value(problem.model[:volume][sl])
                solution["volumes"][sl] = vol
                inv = problem.investment_costs[sl]
                rev = problem.revenue_per_volume[sl] * vol
                solution["investments"][sl] = inv
                solution["revenues"][sl] = rev
                total_investment += inv
                total_revenue += rev
                total_quality += problem.quality_potential[sl] * (vol / (vol + 1))
            end
        end

        solution["total_investment"] = total_investment
        solution["total_revenue"] = total_revenue
        solution["expected_quality"] = total_quality / max(1, length(solution["selected_services"]))
    end

    problem.solution = solution
    return solution
end

"""
    create_capacity_allocation_model(
        hospitals::Vector{String},
        departments::Vector{String},
        total_beds::Dict{String, Int},
        demand::Dict{Tuple{String, String}, Int},
        cost_per_bed::Dict{String, Float64},
        revenue_per_case::Dict{String, Float64},
        quality_per_bed::Dict{String, Float64}
    )::HospitalCapacityAllocation

Create hospital capacity allocation optimization model.
"""
function create_capacity_allocation_model(
    hospitals::Vector{String},
    departments::Vector{String},
    total_beds::Dict{String, Int},
    demand::Dict{Tuple{String, String}, Int},
    cost_per_bed::Dict{String, Float64},
    revenue_per_case::Dict{String, Float64},
    quality_per_bed::Dict{String, Float64}
)::HospitalCapacityAllocation
    model = Model(HiGHS.Optimizer)
    set_silent(model)

    # Decision variables: beds allocated per hospital-department pair
    @variable(model, beds_allocated[h in hospitals, d in departments] >= 0, Int)

    # Hospital bed constraints: total allocated beds cannot exceed available
    for h in hospitals
        @constraint(model, sum(beds_allocated[h, d] for d in departments) <= total_beds[h])
    end

    # Demand satisfaction: allocate enough beds to meet demand (with buffer)
    for h in hospitals, d in departments
        demand_key = (h, d)
        if haskey(demand, demand_key)
            @constraint(model, beds_allocated[h, d] >= 0.8 * demand[demand_key])
        else
            @constraint(model, beds_allocated[h, d] >= 0)
        end
    end

    # Objective: maximize profit (revenue - cost) + quality
    profit = 0.0
    for h in hospitals, d in departments
        dept_key = "cost_" * d
        rev_key = "revenue_" * d
        qual_key = "quality_" * d

        cost = get(cost_per_bed, dept_key, 1000.0)
        revenue = get(revenue_per_case, rev_key, 1500.0)
        quality = get(quality_per_bed, qual_key, 0.1)

        profit += (revenue - cost) * beds_allocated[h, d] + quality * beds_allocated[h, d]
    end

    @objective(model, Max, profit)

    return HospitalCapacityAllocation(
        model, hospitals, departments, total_beds, demand, cost_per_bed, revenue_per_case,
        quality_per_bed, Dict{String, Any}()
    )
end

"""
    solve_capacity_allocation(problem::HospitalCapacityAllocation)::Dict{String, Any}

Solve hospital capacity allocation and extract solution.
"""
function solve_capacity_allocation(problem::HospitalCapacityAllocation)::Dict{String, Any}
    optimize!(problem.model)

    solution = Dict{String, Any}(
        "status" => termination_status(problem.model),
        "objective_value" => objective_value(problem.model),
        "allocations" => Dict(),
        "utilization_rates" => Dict(),
        "unsatisfied_demand" => Dict()
    )

    if termination_status(problem.model) == OPTIMAL
        for h in problem.hospitals
            solution["allocations"][h] = Dict()
            solution["utilization_rates"][h] = 0.0
            total_allocated = 0

            for d in problem.departments
                beds = value(problem.model[:beds_allocated][h, d])
                solution["allocations"][h][d] = beds
                total_allocated += beds
            end

            utilization = total_allocated / max(1, problem.total_beds[h])
            solution["utilization_rates"][h] = utilization
        end

        # Check unmet demand
        for h in problem.hospitals, d in problem.departments
            demand_key = (h, d)
            if haskey(problem.demand, demand_key)
                allocated = value(problem.model[:beds_allocated][h, d])
                demanded = problem.demand[demand_key]
                unmet = max(0, demanded - allocated)
                if unmet > 0
                    if !haskey(solution["unsatisfied_demand"], h)
                        solution["unsatisfied_demand"][h] = Dict()
                    end
                    solution["unsatisfied_demand"][h][d] = unmet
                end
            end
        end
    end

    problem.solution = solution
    return solution
end

"""
    get_optimization_summary(problem::Union{
        CostMinimizationProblem,
        QualityMaximizationProblem,
        ServiceLinePortfolioOptimization,
        HospitalCapacityAllocation
    })::Dict{String, Any}

Generate summary of optimization results.
"""
function get_optimization_summary(problem)::Dict{String, Any}
    solution = problem.solution

    if isempty(solution)
        return Dict(
            "status" => "Not solved",
            "message" => "Problem has not been solved yet"
        )
    end

    status_str = string(solution["status"])
    return Dict(
        "optimization_status" => status_str,
        "is_optimal" => solution["status"] == OPTIMAL,
        "objective_value" => get(solution, "objective_value", nothing),
        "summary" => solution
    )
end
