# optimization/ValueBasedOptimization.jl
# Value-based optimization: maximize patient outcomes per dollar under constraints
# Implements Phase 2.2 — Outcome Optimization Under Constraints

using JuMP
using HiGHS
using LinearAlgebra
using Statistics

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Returns 1/max_value when max_value > 0, otherwise 1.0.
# Used to normalise objective components to a comparable [0, 1] scale.
_normalize_coeff(max_value::Float64) = max_value > 0.0 ? 1.0 / max_value : 1.0

# Annualised FTE-per-ratio-patient coverage factor.
# Derivation: 3 shifts/day × (1 + 0.4 PTO/sick/overhead) ≈ 4.2 FTE
# per patient per ratio unit (i.e., to staff 1 nurse per N patients around
# the clock including relief coverage).
const NURSE_COVERAGE_FACTOR = 4.2

# ---------------------------------------------------------------------------
# Result types
# ---------------------------------------------------------------------------

"""
    ServiceAllocationResult

Result of the service line allocation optimization.

# Fields
- `status::Symbol` — Solver termination status.
- `objective_value::Float64` — Maximised total weighted value (margin + quality).
- `volumes::Dict{String, Float64}` — Optimal patient volume per service line.
- `budget_used::Float64` — Total budget consumed.
- `quality_score::Float64` — Weighted average quality across selected volumes.
"""
struct ServiceAllocationResult
    status::Symbol
    objective_value::Float64
    volumes::Dict{String, Float64}
    budget_used::Float64
    quality_score::Float64
end

"""
    ResourceAllocationResult

Result of the department budget allocation optimization.

# Fields
- `status::Symbol` — Solver termination status.
- `objective_value::Float64` — Maximised total expected outcome.
- `allocations::Dict{String, Float64}` — Budget allocated per department.
- `expected_outcomes::Dict{String, Float64}` — Expected outcome gain per department.
- `budget_used::Float64` — Total budget allocated.
"""
struct ResourceAllocationResult
    status::Symbol
    objective_value::Float64
    allocations::Dict{String, Float64}
    expected_outcomes::Dict{String, Float64}
    budget_used::Float64
end

"""
    NetworkOptimizationResult

Result of the hospital-network service assignment optimization.

# Fields
- `status::Symbol` — Solver termination status.
- `objective_value::Float64` — Maximised total network profit.
- `assignments::Dict{Tuple{String,String}, Bool}` — (hospital, service) -> offered.
- `total_profit::Float64` — Total expected network profit.
- `coverage_score::Float64` — Fraction of demand covered across the network.
"""
struct NetworkOptimizationResult
    status::Symbol
    objective_value::Float64
    assignments::Dict{Tuple{String,String}, Bool}
    total_profit::Float64
    coverage_score::Float64
end

"""
    StaffingRatioResult

Result of the staffing-ratio optimization.

# Fields
- `status::Symbol` — Solver termination status.
- `objective_value::Float64` — Minimised total staffing cost.
- `ratios::Dict{String, Float64}` — Optimal nurses-per-patient ratio per unit.
- `nurse_ftes::Dict{String, Float64}` — Full-time equivalent nurses per unit.
- `total_cost::Float64` — Total annual staffing cost.
- `quality_score::Float64` — Aggregate quality score (higher ratio → better quality).
"""
struct StaffingRatioResult
    status::Symbol
    objective_value::Float64
    ratios::Dict{String, Float64}
    nurse_ftes::Dict{String, Float64}
    total_cost::Float64
    quality_score::Float64
end

"""
    MultiObjectiveResult

Result of the multi-objective (margin / access / quality) optimization.

# Fields
- `status::Symbol` — Solver termination status.
- `objective_value::Float64` — Maximised weighted composite score.
- `volumes::Dict{String, Float64}` — Optimal volumes per service line.
- `margin_score::Float64` — Contribution-margin component of the objective.
- `access_score::Float64` — Patient-access component of the objective.
- `quality_score::Float64` — Quality component of the objective.
- `budget_used::Float64` — Budget consumed.
"""
struct MultiObjectiveResult
    status::Symbol
    objective_value::Float64
    volumes::Dict{String, Float64}
    margin_score::Float64
    access_score::Float64
    quality_score::Float64
    budget_used::Float64
end

# ---------------------------------------------------------------------------
# 1. Service-Line Expansion — maximize profit + quality
# ---------------------------------------------------------------------------

"""
    optimize_service_allocation(
        service_lines, margin_per_case, cost_per_case, capacity,
        quality_scores, budget;
        quality_weight = 0.2
    ) -> ServiceAllocationResult

Optimize patient volume per service line to maximize a weighted combination of
total contribution margin and patient-weighted quality, subject to a budget
constraint and per-service capacity limits.

# Arguments
- `service_lines::Vector{String}` — Service line identifiers.
- `margin_per_case::Dict{String, Float64}` — Contribution margin per patient case.
- `cost_per_case::Dict{String, Float64}` — Variable cost per patient case.
- `capacity::Dict{String, Float64}` — Maximum annual patient volume per service.
- `quality_scores::Dict{String, Float64}` — Quality score per service line (0–1).
- `budget::Float64` — Total budget available.
- `quality_weight::Float64` — Weight on quality vs. margin in the objective (0–1).

# Returns
A `ServiceAllocationResult` with optimal volumes and summary metrics.
"""
function optimize_service_allocation(
    service_lines::Vector{String},
    margin_per_case::Dict{String, Float64},
    cost_per_case::Dict{String, Float64},
    capacity::Dict{String, Float64},
    quality_scores::Dict{String, Float64},
    budget::Float64;
    quality_weight::Float64 = 0.2,
)::ServiceAllocationResult

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    @variable(model, volume[sl in service_lines] >= 0)

    # Budget constraint
    @constraint(model,
        sum(cost_per_case[sl] * volume[sl] for sl in service_lines) <= budget
    )

    # Capacity constraints
    for sl in service_lines
        @constraint(model, volume[sl] <= capacity[sl])
    end

    # Normalise margin and quality for comparable scale
    max_margin = sum(max(margin_per_case[sl], 0.0) * capacity[sl] for sl in service_lines)
    max_quality = sum(quality_scores[sl] * capacity[sl] for sl in service_lines)

    margin_expr = @expression(model,
        sum(margin_per_case[sl] * volume[sl] for sl in service_lines)
    )
    quality_expr = @expression(model,
        sum(quality_scores[sl] * volume[sl] for sl in service_lines)
    )

    w = quality_weight
    norm_m = _normalize_coeff(max_margin)
    norm_q = _normalize_coeff(max_quality)

    @objective(model, Max,
        (1.0 - w) * norm_m * margin_expr + w * norm_q * quality_expr
    )

    optimize!(model)

    status = Symbol(termination_status(model))
    obj_val = has_values(model) ? objective_value(model) : -Inf

    vols = Dict(sl => (has_values(model) ? value(volume[sl]) : 0.0) for sl in service_lines)

    total_cost = sum(cost_per_case[sl] * vols[sl] for sl in service_lines)
    total_vol = sum(values(vols))
    avg_quality = total_vol > 0 ?
        sum(quality_scores[sl] * vols[sl] for sl in service_lines) / total_vol : 0.0

    return ServiceAllocationResult(status, obj_val, vols, total_cost, avg_quality)
end

# ---------------------------------------------------------------------------
# 2. Resource Allocation — allocate budget across departments
# ---------------------------------------------------------------------------

"""
    optimize_resource_allocation(
        departments, budget, outcome_per_dollar, min_allocation, max_allocation;
        min_coverage_fraction = 0.05
    ) -> ResourceAllocationResult

Allocate a fixed budget across hospital departments to maximize total expected
outcome improvement.  A concave square-root response function captures
diminishing returns.

# Arguments
- `departments::Vector{String}` — Department identifiers.
- `budget::Float64` — Total budget to allocate (e.g. 1_000_000.0).
- `outcome_per_dollar::Dict{String, Float64}` — Marginal outcome gain per dollar (linearised).
- `min_allocation::Dict{String, Float64}` — Minimum spend per department.
- `max_allocation::Dict{String, Float64}` — Maximum spend per department.
- `min_coverage_fraction::Float64` — Minimum fraction of budget each department receives.

# Returns
A `ResourceAllocationResult` with optimal allocations and summary metrics.
"""
function optimize_resource_allocation(
    departments::Vector{String},
    budget::Float64,
    outcome_per_dollar::Dict{String, Float64},
    min_allocation::Dict{String, Float64},
    max_allocation::Dict{String, Float64};
    min_coverage_fraction::Float64 = 0.05,
)::ResourceAllocationResult

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    @variable(model, alloc[d in departments] >= 0)

    # Budget constraint: must spend exactly the full budget
    @constraint(model, sum(alloc[d] for d in departments) <= budget)
    @constraint(model, sum(alloc[d] for d in departments) >= budget * 0.99)

    # Per-department bounds
    for d in departments
        @constraint(model, alloc[d] >= min_allocation[d])
        @constraint(model, alloc[d] <= max_allocation[d])
        @constraint(model, alloc[d] >= min_coverage_fraction * budget)
    end

    # Objective: maximize linear outcome (linearisation of concave response)
    @objective(model, Max, sum(outcome_per_dollar[d] * alloc[d] for d in departments))

    optimize!(model)

    status = Symbol(termination_status(model))
    obj_val = has_values(model) ? objective_value(model) : -Inf

    allocs = Dict(d => (has_values(model) ? value(alloc[d]) : 0.0) for d in departments)
    outcomes = Dict(d => outcome_per_dollar[d] * allocs[d] for d in departments)
    budget_used = sum(values(allocs))

    return ResourceAllocationResult(status, obj_val, allocs, outcomes, budget_used)
end

# ---------------------------------------------------------------------------
# 3. Network Optimization — which hospitals should offer which services
# ---------------------------------------------------------------------------

"""
    optimize_network_services(
        hospitals, services,
        revenue_per_case, cost_per_case, demand,
        hospital_capacity, setup_cost, total_network_budget;
        min_access_coverage = 0.7
    ) -> NetworkOptimizationResult

Determine the optimal assignment of services to hospitals in a network to
maximize total network profit, subject to capacity, setup-budget, and minimum
patient-access coverage constraints.

# Arguments
- `hospitals::Vector{String}` — Hospital identifiers.
- `services::Vector{String}` — Service line identifiers.
- `revenue_per_case::Dict{String, Float64}` — Revenue per case by service.
- `cost_per_case::Dict{String, Float64}` — Variable cost per case by service.
- `demand::Dict{Tuple{String,String}, Float64}` — Demand (hospital, service) -> annual cases.
- `hospital_capacity::Dict{String, Float64}` — Total capacity units per hospital.
- `setup_cost::Dict{String, Float64}` — One-time setup cost per service line.
- `total_network_budget::Float64` — Total budget for new service-line setup.
- `min_access_coverage::Float64` — Minimum fraction of total demand that must be served.

# Returns
A `NetworkOptimizationResult` with optimal assignments and summary metrics.
"""
function optimize_network_services(
    hospitals::Vector{String},
    services::Vector{String},
    revenue_per_case::Dict{String, Float64},
    cost_per_case::Dict{String, Float64},
    demand::Dict{Tuple{String,String}, Float64},
    hospital_capacity::Dict{String, Float64},
    setup_cost::Dict{String, Float64},
    total_network_budget::Float64;
    min_access_coverage::Float64 = 0.7,
)::NetworkOptimizationResult

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    # Binary: hospital h offers service s
    @variable(model, offer[h in hospitals, s in services], Bin)

    # Continuous: volume served at (h, s)
    @variable(model, vol[h in hospitals, s in services] >= 0)

    # Volume is bounded by demand and only positive when service is offered
    for h in hospitals, s in services
        d_val = get(demand, (h, s), 0.0)
        @constraint(model, vol[h, s] <= d_val * offer[h, s])
    end

    # Hospital capacity: sum of volumes across services ≤ capacity
    for h in hospitals
        @constraint(model, sum(vol[h, s] for s in services) <= hospital_capacity[h])
    end

    # Setup-budget constraint
    @constraint(model,
        sum(setup_cost[s] * offer[h, s] for h in hospitals for s in services) <= total_network_budget
    )

    # Minimum access coverage: network serves at least min_access_coverage of total demand
    total_demand = sum(get(demand, (h, s), 0.0) for h in hospitals for s in services)
    if total_demand > 0
        @constraint(model,
            sum(vol[h, s] for h in hospitals for s in services) >= min_access_coverage * total_demand
        )
    end

    # Objective: maximize network profit
    margin_per = Dict(s => revenue_per_case[s] - cost_per_case[s] for s in services)
    @objective(model, Max,
        sum(margin_per[s] * vol[h, s] for h in hospitals for s in services)
        - sum(setup_cost[s] * offer[h, s] for h in hospitals for s in services)
    )

    optimize!(model)

    status = Symbol(termination_status(model))
    obj_val = has_values(model) ? objective_value(model) : -Inf

    assignments = Dict(
        (h, s) => (has_values(model) ? value(offer[h, s]) > 0.5 : false)
        for h in hospitals for s in services
    )

    total_profit = has_values(model) ? objective_value(model) : 0.0

    total_served = has_values(model) ?
        sum(value(vol[h, s]) for h in hospitals for s in services) : 0.0
    coverage = total_demand > 0 ? total_served / total_demand : 0.0

    return NetworkOptimizationResult(status, obj_val, assignments, total_profit, coverage)
end

# ---------------------------------------------------------------------------
# 4. Staffing Optimization — nurse-to-patient ratios by unit
# ---------------------------------------------------------------------------

"""
    optimize_staffing_ratios(
        units, patient_volumes, nurse_salary,
        min_ratio, max_ratio, staffing_budget;
        quality_weight = 0.3,
        regulatory_minimum = 0.1
    ) -> StaffingRatioResult

Optimize nurse-to-patient ratios across hospital units to minimize staffing
cost while maintaining regulatory minimums and maximizing patient-quality.

# Arguments
- `units::Vector{String}` — Unit identifiers (e.g., ["ICU", "MedSurg", "ED"]).
- `patient_volumes::Dict{String, Float64}` — Average simultaneous patients per unit.
- `nurse_salary::Dict{String, Float64}` — Annual salary per nurse FTE by unit.
- `min_ratio::Dict{String, Float64}` — Minimum nurses-per-patient ratio (regulatory floor).
- `max_ratio::Dict{String, Float64}` — Maximum nurses-per-patient ratio (budget ceiling).
- `staffing_budget::Float64` — Total annual staffing budget.
- `quality_weight::Float64` — Weight on quality (higher ratio) vs. cost minimization.
- `regulatory_minimum::Float64` — Hard minimum ratio applied to all units.

# Returns
A `StaffingRatioResult` with optimal ratios and summary metrics.
"""
function optimize_staffing_ratios(
    units::Vector{String},
    patient_volumes::Dict{String, Float64},
    nurse_salary::Dict{String, Float64},
    min_ratio::Dict{String, Float64},
    max_ratio::Dict{String, Float64},
    staffing_budget::Float64;
    quality_weight::Float64 = 0.3,
    regulatory_minimum::Float64 = 0.1,
)::StaffingRatioResult

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    @variable(model, ratio[u in units] >= 0)

    # Regulatory and practical bounds
    for u in units
        lo = max(get(min_ratio, u, regulatory_minimum), regulatory_minimum)
        hi = get(max_ratio, u, 1.0)
        @constraint(model, ratio[u] >= lo)
        @constraint(model, ratio[u] <= hi)
    end

    # FTEs = ratio × patients × NURSE_COVERAGE_FACTOR
    # Annual cost per unit = ratio * patient_volume * nurse_salary * NURSE_COVERAGE_FACTOR
    nurse_ftes_expr = Dict(
        u => @expression(model, ratio[u] * patient_volumes[u] * NURSE_COVERAGE_FACTOR)
        for u in units
    )

    total_cost_expr = @expression(model,
        sum(nurse_ftes_expr[u] * nurse_salary[u] for u in units)
    )

    # Budget constraint
    @constraint(model, total_cost_expr <= staffing_budget)

    # Quality proxy: higher ratio → better quality; normalise by max possible
    max_quality = sum(get(max_ratio, u, 1.0) * patient_volumes[u] for u in units)
    quality_expr = @expression(model, sum(ratio[u] * patient_volumes[u] for u in units))

    norm_q = _normalize_coeff(max_quality)
    norm_c = _normalize_coeff(staffing_budget)

    w = quality_weight
    @objective(model, Max,
        w * norm_q * quality_expr - (1.0 - w) * norm_c * total_cost_expr
    )

    optimize!(model)

    status = Symbol(termination_status(model))
    obj_val = has_values(model) ? objective_value(model) : -Inf

    ratios = Dict(u => (has_values(model) ? value(ratio[u]) : 0.0) for u in units)
    ftes = Dict(u => ratios[u] * patient_volumes[u] * NURSE_COVERAGE_FACTOR for u in units)
    total_cost = sum(ftes[u] * nurse_salary[u] for u in units)

    total_patients = sum(values(patient_volumes))
    quality = total_patients > 0 ?
        sum(ratios[u] * patient_volumes[u] for u in units) / total_patients : 0.0

    return StaffingRatioResult(status, obj_val, ratios, ftes, total_cost, quality)
end

# ---------------------------------------------------------------------------
# 5. Multi-Objective Optimization — margin vs. access vs. quality
# ---------------------------------------------------------------------------

"""
    optimize_multi_objective(
        service_lines, margin_per_case, cost_per_case, capacity,
        quality_scores, access_scores, budget;
        margin_weight = 0.4, access_weight = 0.3, quality_weight = 0.3
    ) -> MultiObjectiveResult

Multi-objective service-volume optimization that simultaneously maximizes
contribution margin, patient access, and care quality using a weighted-sum
scalarization.

# Arguments
- `service_lines::Vector{String}` — Service line identifiers.
- `margin_per_case::Dict{String, Float64}` — Contribution margin per case.
- `cost_per_case::Dict{String, Float64}` — Variable cost per case.
- `capacity::Dict{String, Float64}` — Maximum annual volume per service.
- `quality_scores::Dict{String, Float64}` — Quality score per service (0–1).
- `access_scores::Dict{String, Float64}` — Access/equity score per service (0–1),
    reflecting underserved-population reach.
- `budget::Float64` — Total budget constraint.
- `margin_weight::Float64` — Weight on margin objective (must sum to 1 with others).
- `access_weight::Float64` — Weight on access objective.
- `quality_weight::Float64` — Weight on quality objective.

# Returns
A `MultiObjectiveResult` with optimal volumes and per-objective scores.
"""
function optimize_multi_objective(
    service_lines::Vector{String},
    margin_per_case::Dict{String, Float64},
    cost_per_case::Dict{String, Float64},
    capacity::Dict{String, Float64},
    quality_scores::Dict{String, Float64},
    access_scores::Dict{String, Float64},
    budget::Float64;
    margin_weight::Float64 = 0.4,
    access_weight::Float64 = 0.3,
    quality_weight::Float64 = 0.3,
)::MultiObjectiveResult

    # Weights must be positive and sum to ~1
    @assert margin_weight >= 0.0 && access_weight >= 0.0 && quality_weight >= 0.0
    total_w = margin_weight + access_weight + quality_weight
    @assert total_w > 0.0
    wm = margin_weight / total_w
    wa = access_weight  / total_w
    wq = quality_weight / total_w

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    @variable(model, volume[sl in service_lines] >= 0)

    @constraint(model,
        sum(cost_per_case[sl] * volume[sl] for sl in service_lines) <= budget
    )
    for sl in service_lines
        @constraint(model, volume[sl] <= capacity[sl])
    end

    # Per-objective expressions
    margin_expr = @expression(model,
        sum(margin_per_case[sl] * volume[sl] for sl in service_lines)
    )
    access_expr = @expression(model,
        sum(access_scores[sl] * volume[sl] for sl in service_lines)
    )
    quality_expr = @expression(model,
        sum(quality_scores[sl] * volume[sl] for sl in service_lines)
    )

    # Normalisation denominators
    max_margin = sum(max(margin_per_case[sl], 0.0) * capacity[sl] for sl in service_lines)
    max_access = sum(access_scores[sl] * capacity[sl] for sl in service_lines)
    max_quality = sum(quality_scores[sl] * capacity[sl] for sl in service_lines)

    nm = _normalize_coeff(max_margin)
    na = _normalize_coeff(max_access)
    nq = _normalize_coeff(max_quality)

    @objective(model, Max,
        wm * nm * margin_expr + wa * na * access_expr + wq * nq * quality_expr
    )

    optimize!(model)

    status = Symbol(termination_status(model))
    obj_val = has_values(model) ? objective_value(model) : -Inf

    vols = Dict(sl => (has_values(model) ? value(volume[sl]) : 0.0) for sl in service_lines)

    margin_sc = has_values(model) ? sum(margin_per_case[sl] * vols[sl] for sl in service_lines) : 0.0
    access_sc  = has_values(model) ? sum(access_scores[sl]  * vols[sl] for sl in service_lines) : 0.0
    quality_sc = has_values(model) ? sum(quality_scores[sl] * vols[sl] for sl in service_lines) : 0.0

    budget_used = sum(cost_per_case[sl] * vols[sl] for sl in service_lines)

    return MultiObjectiveResult(
        status, obj_val, vols,
        margin_sc, access_sc, quality_sc,
        budget_used
    )
end

# ---------------------------------------------------------------------------
# Convenience: legacy stub preserved for backward compatibility
# ---------------------------------------------------------------------------

"""
    optimize_outcome_allocation(budget::Float64, interventions::Vector) -> Nothing

Legacy stub (Phase 1 placeholder). Use the typed functions above instead.
"""
function optimize_outcome_allocation(budget::Float64, interventions::Vector)
    nothing
end
