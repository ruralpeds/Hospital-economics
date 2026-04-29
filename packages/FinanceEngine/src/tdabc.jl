"""
    tdabc.jl — Time-Driven Activity-Based Costing (MBA Gap C-05)

Implements the Kaplan-Anderson (2004) TDABC method — the modern successor to
traditional ABC that replaces activity driver rates with two simple parameters:

  cost_per_time_unit = total_resource_cost / practical_capacity_minutes

  service_cost = Σ_activities (time_equation_minutes × cost_per_time_unit)

TDABC is preferred over traditional ABC for hospitals because:
1. No surveys needed — time equations can be estimated from observation or EHR.
2. Handles variation automatically (conditional time equations).
3. Reveals unused capacity explicitly.
4. Works with CMS episode-based payment models (BPCI, TEAM, MSSP).

This module provides:
- Resource pool definition (department/cost centre)
- Time equation building (activity × patient type)
- Service cost calculation per patient type or encounter
- Capacity utilisation and unused capacity quantification
- Comparison to standard Medicare cost-to-charge based costing

References:
- Kaplan RS, Anderson SR (2004). Time-Driven Activity-Based Costing.
  Harvard Business Review, November 2004.
- Kaplan RS, Porter ME (2011). How to solve the cost crisis in health care.
  Harvard Business Review, September 2011.
- Demeere N et al (2009). Time-driven activity-based costing in an outpatient clinic.
  Health Policy 92(2-3): 296-304.
"""

using Statistics
using Printf

# ─────────────────────────────────────────────────────────────────────────────
# Resource pool
# ─────────────────────────────────────────────────────────────────────────────

"""
    ResourcePool

A TDABC resource pool — a group of people/equipment with similar cost rates.
Typically corresponds to a hospital cost centre (nursing unit, OR, lab, etc.).

# Fields
- `id::Any`
- `name::String`: e.g. "Med-Surg Nursing", "Operating Room", "ED".
- `total_annual_cost::Float64`: Total cost for this resource pool (USD/yr).
- `total_capacity_minutes::Float64`: Practical capacity (scheduled minutes/yr;
  typically 80% of theoretical maximum to account for breaks, downtime).
- `cost_per_minute::Float64`: Computed from total_cost / capacity_minutes.
- `unused_capacity_minutes::Float64`: Capacity not consumed by activities.
"""
@kwdef mutable struct ResourcePool
    id::Any
    name::String
    total_annual_cost::Float64
    total_capacity_minutes::Float64
    cost_per_minute::Float64 = total_annual_cost / total_capacity_minutes
    used_minutes::Float64    = 0.0

    function ResourcePool(id, name, cost, cap, cpm, used)
        cap > 0 || throw(ArgumentError("total_capacity_minutes must be > 0"))
        new(id, name, cost, cap, cost / cap, used)
    end
end

unused_capacity_minutes(p::ResourcePool) = p.total_capacity_minutes - p.used_minutes
unused_capacity_cost(p::ResourcePool) = unused_capacity_minutes(p) * p.cost_per_minute
capacity_utilisation(p::ResourcePool) = p.total_capacity_minutes > 0 ?
    p.used_minutes / p.total_capacity_minutes : 0.0

# ─────────────────────────────────────────────────────────────────────────────
# Time equations
# ─────────────────────────────────────────────────────────────────────────────

"""
    TimeEquation

A TDABC time equation for a specific activity-patient-type combination.

A time equation specifies how long an activity takes:
  minutes = base_minutes + Σ_k (coefficient_k × driver_k_value)

Example: "Nursing assessment for inpatient" might be:
  minutes = 15 + 8 × is_complex_case + 5 × has_wound_care

# Fields
- `activity_name::String`
- `resource_pool_id::Any`: Links to the `ResourcePool`.
- `base_minutes::Float64`: Fixed time for any instance of this activity.
- `time_drivers::Vector{NamedTuple}`: Each `(name, coefficient_minutes)`.
  The driver value is provided when evaluating the equation.
"""
@kwdef struct TimeEquation
    activity_name::String
    resource_pool_id::Any
    base_minutes::Float64
    time_drivers::Vector{NamedTuple} = NamedTuple[]
end

"""
    evaluate_time_equation(eq::TimeEquation, driver_values::Dict) -> Float64

Evaluate a time equation given specific driver values.

# Example
```julia
eq = TimeEquation(
    activity_name = "Nursing Assessment",
    resource_pool_id = :med_surg,
    base_minutes = 15.0,
    time_drivers = [(name="complex_case", coeff=8.0), (name="wound_care", coeff=5.0)],
)
evaluate_time_equation(eq, Dict("complex_case"=>1.0, "wound_care"=>0.0))  # → 23 minutes
```
"""
function evaluate_time_equation(
    eq::TimeEquation,
    driver_values::Dict{String,Float64} = Dict{String,Float64}(),
)::Float64
    t = eq.base_minutes
    for driver in eq.time_drivers
        name  = string(driver.name)
        coeff = Float64(driver.coeff)
        val   = get(driver_values, name, 0.0)
        t    += coeff * val
    end
    max(0.0, t)
end

# ─────────────────────────────────────────────────────────────────────────────
# Patient encounter / service type
# ─────────────────────────────────────────────────────────────────────────────

"""
    TDABCEncounter

One patient encounter or service type to cost.

# Fields
- `id::Any`
- `encounter_type::String`: e.g. "Inpatient DRG-291", "ED ESI-3", "RHC Visit".
- `volume::Int`: Annual encounters of this type.
- `activities::Vector{NamedTuple}`: Each `(equation_id, driver_values)` specifying
  which time equations apply and with what driver values.
"""
@kwdef struct TDABCEncounter
    id::Any
    encounter_type::String
    volume::Int
    activities::Vector{NamedTuple}
end

"""
    TDABCCostResult

TDABC cost estimate for one encounter type.

# Fields
- `encounter_type::String`
- `volume::Int`
- `cost_per_encounter::Float64`: Total cost from all activities.
- `activity_costs::Vector{NamedTuple}`: Per-activity breakdown.
- `total_annual_cost::Float64`: `cost_per_encounter × volume`.
- `minutes_per_encounter::Float64`: Total time consumed.
- `benchmark_ctc_cost::Float64`: Benchmark cost via cost-to-charge ratio (for comparison).
- `tdabc_vs_ctc_ratio::Float64`: TDABC / CTC (>1 = TDABC more expensive than CTC suggests).
"""
struct TDABCCostResult
    encounter_type::String
    volume::Int
    cost_per_encounter::Float64
    activity_costs::Vector{NamedTuple}
    total_annual_cost::Float64
    minutes_per_encounter::Float64
    benchmark_ctc_cost::Float64
    tdabc_vs_ctc_ratio::Float64
end

# ─────────────────────────────────────────────────────────────────────────────
# Main TDABC model
# ─────────────────────────────────────────────────────────────────────────────

"""
    TDABCModel

A complete TDABC model for a hospital or department.

# Fields
- `resource_pools::Dict{Any,ResourcePool}`: Keyed by pool id.
- `time_equations::Dict{Any,TimeEquation}`: Keyed by equation id.
"""
struct TDABCModel
    resource_pools::Dict{Any,ResourcePool}
    time_equations::Dict{Any,TimeEquation}
end

TDABCModel() = TDABCModel(Dict(), Dict())

"""
    add_resource_pool!(model::TDABCModel, pool::ResourcePool)

Add a resource pool to the model.
"""
function add_resource_pool!(model::TDABCModel, pool::ResourcePool)
    model.resource_pools[pool.id] = pool
    model
end

"""
    add_time_equation!(model::TDABCModel, eq::TimeEquation)

Add a time equation to the model.
"""
function add_time_equation!(model::TDABCModel, eq::TimeEquation)
    model.time_equations[eq.activity_name] = eq
    model
end

"""
    cost_encounter(
        model::TDABCModel,
        encounter::TDABCEncounter;
        benchmark_ctc_cost
    ) -> TDABCCostResult

Compute the TDABC cost for one encounter type.

For each activity in the encounter, evaluates the time equation, multiplies
by the resource pool's cost_per_minute, and sums across all activities.
"""
function cost_encounter(
    model::TDABCModel,
    encounter::TDABCEncounter;
    benchmark_ctc_cost::Float64 = 0.0,
)::TDABCCostResult
    activity_costs = NamedTuple[]
    total_cost     = 0.0
    total_minutes  = 0.0

    for act in encounter.activities
        eq_id     = string(act.equation_id)
        drivers   = get(act, :driver_values, Dict{String,Float64}())
        drivers_d = Dict{String,Float64}(string(k) => Float64(v) for (k,v) in pairs(drivers))

        haskey(model.time_equations, eq_id) ||
            throw(ArgumentError("Time equation '$eq_id' not found in model"))
        eq   = model.time_equations[eq_id]
        mins = evaluate_time_equation(eq, drivers_d)

        haskey(model.resource_pools, eq.resource_pool_id) ||
            throw(ArgumentError("Resource pool '$(eq.resource_pool_id)' not found"))
        pool = model.resource_pools[eq.resource_pool_id]

        act_cost = mins * pool.cost_per_minute
        push!(activity_costs, (
            activity     = eq_id,
            resource_pool = pool.name,
            minutes      = mins,
            cost_per_min = pool.cost_per_minute,
            cost         = act_cost,
        ))
        total_cost    += act_cost
        total_minutes += mins
    end

    ctc_ratio = benchmark_ctc_cost > 0 ? total_cost / benchmark_ctc_cost : NaN

    TDABCCostResult(
        encounter.encounter_type,
        encounter.volume,
        total_cost,
        activity_costs,
        total_cost * encounter.volume,
        total_minutes,
        benchmark_ctc_cost,
        ctc_ratio,
    )
end

"""
    run_tdabc(
        model::TDABCModel,
        encounters::Vector{TDABCEncounter};
        benchmark_ctc_costs
    ) -> NamedTuple

Run the full TDABC model across all encounter types.

# Returns
- `results::Vector{TDABCCostResult}`: One per encounter type, sorted by total_annual_cost desc.
- `total_costed_cost::Float64`: Total TDABC cost across all encounters.
- `capacity_utilisation::Dict`: Pool id → utilisation rate.
- `unused_capacity_cost::Float64`: Total cost of unused capacity.
- `top_cost_driver::String`: Encounter type driving most total cost.
"""
function run_tdabc(
    model::TDABCModel,
    encounters::Vector{TDABCEncounter};
    benchmark_ctc_costs::Dict{Any,Float64} = Dict{Any,Float64}(),
)
    results = map(encounters) do enc
        ctc = get(benchmark_ctc_costs, enc.id, 0.0)
        cost_encounter(model, enc; benchmark_ctc_cost=ctc)
    end

    sort!(results; by=r->-r.total_annual_cost)

    # Update pool used_minutes
    for r in results
        for act in r.activity_costs
            pool_name = act.resource_pool
            pool = findfirst(p -> p.name == pool_name, collect(values(model.resource_pools)))
            if !isnothing(pool)
                p = collect(values(model.resource_pools))[pool]
                p.used_minutes += act.minutes * r.volume
            end
        end
    end

    total_cost = sum(r.total_annual_cost for r in results)
    total_pool_cost = sum(p.total_annual_cost for p in values(model.resource_pools))
    unused_cap = sum(unused_capacity_cost(p) for p in values(model.resource_pools))

    cap_util = Dict(
        p.id => capacity_utilisation(p) for p in values(model.resource_pools)
    )

    top_driver = isempty(results) ? "" : results[1].encounter_type

    (
        results              = results,
        total_costed_cost    = total_cost,
        total_resource_cost  = total_pool_cost,
        unused_capacity_cost = unused_cap,
        capacity_utilisation = cap_util,
        top_cost_driver      = top_driver,
        costing_coverage_pct = total_pool_cost > 0 ? total_cost / total_pool_cost * 100 : NaN,
    )
end
