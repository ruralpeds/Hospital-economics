"""
OptimizationController — API handlers for JuMP.jl optimization endpoints.

Routes:
  POST /api/optimize/staffing
  POST /api/optimize/portfolio
"""
module OptimizationController

using JSON3, Dates, UUIDs
using ...RuralHospitalSim

"""Parse a numeric value from payload with bounds checking."""
function _validated_float(payload::Dict, key::String, default::Float64;
                          min_val::Float64=-Inf, max_val::Float64=Inf)
    val = Float64(get(payload, key, default))
    (isnan(val) || isinf(val)) && error("Parameter '$key' must be a finite number")
    val < min_val && error("Parameter '$key' must be >= $min_val")
    val > max_val && error("Parameter '$key' must be <= $max_val")
    return val
end

function _validated_int(payload::Dict, key::String, default::Int;
                        min_val::Int=typemin(Int), max_val::Int=typemax(Int))
    val = Int(get(payload, key, default))
    val < min_val && error("Parameter '$key' must be >= $min_val")
    val > max_val && error("Parameter '$key' must be <= $max_val")
    return val
end

# ═══════════════════════════════════════════════════════════════════════════
# Staffing Optimization
# ═══════════════════════════════════════════════════════════════════════════

"""
    handle_staffing_optimization(payload::Dict) -> Dict

Run staffing optimization from JSON payload.

Expected payload:
  - departments: list of department names
  - shifts: list of shift names (e.g., ["day", "evening", "night"])
  - demand: dict of {dept_shift: required_fte}
  - permanent_salary: dict of {dept: annual_salary}
  - budget: total staffing budget
  - travel_salary_premium, overtime_rate, max_overtime_fraction (optional)
"""
function handle_staffing_optimization(payload::Dict)
    depts = Symbol.(get(payload, "departments", ["ed", "nursing", "lab", "radiology"]))
    shifts = Symbol.(get(payload, "shifts", ["day", "evening", "night"]))

    # Parse demand matrix
    raw_demand = get(payload, "demand", Dict())
    demand = Dict{Tuple{Symbol, Symbol}, Float64}()
    for (key, val) in raw_demand
        parts = split(string(key), "_")
        if length(parts) >= 2
            dept = Symbol(parts[1])
            shift = Symbol(parts[2])
            demand[(dept, shift)] = Float64(val)
        end
    end

    # Fill missing demand with defaults
    for d in depts, s in shifts
        if !haskey(demand, (d, s))
            default = s == :night ? 2.0 : 4.0
            demand[(d, s)] = default
        end
    end

    # Parse salaries
    raw_salaries = get(payload, "permanent_salary", Dict())
    permanent_salary = Dict{Symbol, Float64}()
    for (k, v) in raw_salaries
        permanent_salary[Symbol(k)] = Float64(v)
    end
    for d in depts
        if !haskey(permanent_salary, d)
            permanent_salary[d] = 65000.0
        end
    end

    # Parse regulatory minimums
    raw_mins = get(payload, "regulatory_minimums", Dict())
    regulatory_minimums = Dict{Symbol, Float64}()
    for (k, v) in raw_mins
        regulatory_minimums[Symbol(k)] = Float64(v)
    end

    result = optimize_staffing(;
        departments          = depts,
        shifts               = shifts,
        demand               = demand,
        regulatory_minimums  = regulatory_minimums,
        permanent_salary     = permanent_salary,
        travel_salary_premium = _validated_float(payload, "travel_salary_premium", 1.8; min_val=1.0, max_val=5.0),
        overtime_rate        = _validated_float(payload, "overtime_rate", 1.5; min_val=1.0, max_val=3.0),
        max_overtime_fraction = _validated_float(payload, "max_overtime_fraction", 0.2; min_val=0.0, max_val=1.0),
        budget               = _validated_float(payload, "budget", 10_000_000.0; min_val=0.0),
    )

    Dict(
        "status"              => "success",
        "type"                => "staffing_optimization",
        "run_id"              => string(uuid4()),
        "timestamp"           => string(now()),
        "optimal_cost"        => round(result.total_cost, digits=2),
        "permanent_ftes"      => result.permanent_ftes,
        "travel_ftes"         => result.travel_ftes,
        "overtime_hours"      => result.overtime_hours,
        "solver_status"       => string(result.solver_status),
        "cost_savings_vs_all_travel" => round(result.savings_vs_all_travel, digits=2),
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# Service Line Portfolio Optimization
# ═══════════════════════════════════════════════════════════════════════════

"""
    handle_portfolio_optimization(payload::Dict) -> Dict

Run service line portfolio optimization from JSON payload.

Expected payload:
  - services: list of service line names
  - revenue_per_unit, cost_per_unit, volume_potential: dicts keyed by service name
  - total_capacity: aggregate FTE/bed capacity
  - fixed_costs: dict of fixed overhead per service
  - required_services: list of mandatory services
  - capital_budget / max_services (optional)
"""
function handle_portfolio_optimization(payload::Dict)
    services = Symbol.(get(payload, "services",
        ["ed", "primary_care", "lab", "imaging", "surgery", "obstetrics", "rehab", "behavioral_health"]))

    _parse_dict(key, default) = begin
        raw = get(payload, key, Dict())
        d = Dict{Symbol, Float64}()
        for (k, v) in raw
            d[Symbol(k)] = Float64(v)
        end
        for s in services
            if !haskey(d, s)
                d[s] = default
            end
        end
        d
    end

    revenue_per_unit     = _parse_dict("revenue_per_unit", 2000.0)
    cost_per_unit        = _parse_dict("cost_per_unit", 1500.0)
    volume_potential     = _parse_dict("volume_potential", 500.0)
    capacity_requirement = _parse_dict("capacity_requirement", 5.0)
    fixed_costs          = _parse_dict("fixed_costs", 200_000.0)
    community_need       = _parse_dict("community_need_scores", 0.5)

    required = Symbol.(get(payload, "required_services", ["ed"]))

    result = optimize_service_portfolio(;
        services              = services,
        revenue_per_unit      = revenue_per_unit,
        cost_per_unit         = cost_per_unit,
        volume_potential      = volume_potential,
        capacity_requirement  = capacity_requirement,
        total_capacity        = _validated_float(payload, "total_capacity", 50.0; min_val=1.0),
        fixed_costs           = fixed_costs,
        required_services     = required,
        max_services          = _validated_int(payload, "max_services", length(services); min_val=1, max_val=length(services)),
        community_need_weight = _validated_float(payload, "community_need_weight", 0.2; min_val=0.0, max_val=1.0),
        community_need_scores = community_need,
    )

    Dict(
        "status"               => "success",
        "type"                 => "portfolio_optimization",
        "run_id"               => string(uuid4()),
        "timestamp"            => string(now()),
        "active_services"      => string.(result.active_services),
        "exited_services"      => string.(result.exited_services),
        "total_contribution"   => round(result.total_contribution, digits=2),
        "total_fixed_costs"    => round(result.total_fixed_costs, digits=2),
        "net_margin_impact"    => round(result.net_margin_impact, digits=2),
        "solver_status"        => string(result.solver_status),
    )
end

end # module OptimizationController
