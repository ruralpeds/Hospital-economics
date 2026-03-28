# System Dynamics Engine
# Continuous-time ODE model of rural hospital feedback loops using DifferentialEquations.jl.

using DifferentialEquations

# ---------------------------------------------------------------------------
# Parameters
# ---------------------------------------------------------------------------

# SystemDynamicsParams is defined in src/types/scenarios.jl — do not redefine here.
# Fields used from scenarios.jl version:
#   time_horizon_years, dt, population_growth_rate, aging_rate,
#   inflation_rate, medical_inflation_rate, technology_cost_growth,
#   reimbursement_growth_rate, volume_elasticity_to_distance,
#   volume_elasticity_to_quality, physician_retirement_rate,
#   nurse_attrition_rate, cash_reserve_target_days,
#   debt_capacity_ratio, capital_reinvestment_rate

# ---------------------------------------------------------------------------
# State variable indices
# ---------------------------------------------------------------------------
# u[1] = volume        (patient visits/year)
# u[2] = revenue       (annual revenue, USD)
# u[3] = staff         (FTE count)
# u[4] = quality       (0-1 index)
# u[5] = population    (service area population)
# u[6] = cash          (cash reserves, USD)
# u[7] = satisfaction  (patient satisfaction, 0-1)
# u[8] = health        (community health index, 0-1)

const STATE_VOLUME       = 1
const STATE_REVENUE      = 2
const STATE_STAFF        = 3
const STATE_QUALITY      = 4
const STATE_POPULATION   = 5
const STATE_CASH         = 6
const STATE_SATISFACTION = 7
const STATE_HEALTH       = 8

"""
    hospital_dynamics!(du, u, p::SystemDynamicsParams, t)

ODE system describing the continuous-time dynamics of a rural hospital.

## State Variables (8)
1. **Volume**: Patient visits, driven by population, quality, and satisfaction.
2. **Revenue**: Financial inflows, linked to volume and reimbursement.
3. **Staff**: FTE workforce, with recruitment and departure dynamics.
4. **Quality**: Care quality index, dependent on staffing and investment.
5. **Population**: Service area population with migration dynamics.
6. **Cash**: Cash reserves, accumulating operating income minus fixed costs.
7. **Satisfaction**: Patient satisfaction, driven by quality and wait times.
8. **Health**: Community health index, improved by access and quality of care.

## Feedback Loops
- **Volume-Revenue-Quality (reinforcing)**: Higher volume generates revenue, enabling
  quality investment, which attracts more volume.
- **Staffing Sustainability (balancing)**: Staff shortages degrade quality and increase
  burnout, driving departures, which worsen shortages.
- **Community Health (reinforcing)**: Better hospital quality improves community health,
  which reduces acute demand but sustains population and long-term volume.
"""
"""
Default constants for feedback-loop parameters not present in the
types/scenarios.jl version of SystemDynamicsParams.
"""
const _SD_VOLUME_REVENUE_ELASTICITY  = 0.8
const _SD_REVENUE_QUALITY_INVESTMENT = 0.15
const _SD_STAFF_QUALITY_IMPACT       = 0.5
const _SD_COMMUNITY_HEALTH_DECAY     = 0.02
const _SD_POPULATION_OUTMIGRATION    = 0.01
const _SD_SATISFACTION_FEEDBACK      = 0.2
const _SD_BASE_REIMBURSEMENT_RATE    = 5000.0
const _SD_BASE_COST_PER_STAFF       = 85_000.0
const _SD_TRAVEL_NURSE_PREMIUM      = 1.8
const _SD_CRITICAL_STAFF_THRESHOLD  = 0.6
const _SD_CASH_BURN_RATE            = 500_000.0
const _SD_MAX_CAPACITY              = 10_000.0

function hospital_dynamics!(du, u, p::SystemDynamicsParams, t)
    volume, revenue, staff, quality, population, cash, satisfaction, health = u

    # Clamp state variables to physical bounds
    volume      = max(volume, 0.0)
    revenue     = max(revenue, 0.0)
    staff       = max(staff, 1.0)  # minimum 1 to avoid division by zero
    quality     = clamp(quality, 0.0, 1.0)
    population  = max(population, 100.0)
    cash        = cash  # can go negative (debt)
    satisfaction = clamp(satisfaction, 0.0, 1.0)
    health      = clamp(health, 0.0, 1.0)

    # Map types/scenarios.jl fields to local names; use defaults for fields
    # that only existed in the old engine-local struct.
    volume_elasticity_to_quality = p.volume_elasticity_to_quality
    nurse_attrition_rate         = p.nurse_attrition_rate
    pop_growth                   = p.population_growth_rate

    # --- Derived quantities ---
    staffing_ratio = staff / (volume / 250.0 + 1.0)  # staff per ~250 visits
    staffing_adequacy = clamp(staffing_ratio / 5.0, 0.0, 1.5)  # normalised around target of 5
    is_understaffed = staffing_adequacy < _SD_CRITICAL_STAFF_THRESHOLD

    capacity_utilisation = clamp(volume / _SD_MAX_CAPACITY, 0.0, 1.0)
    revenue_per_visit = _SD_BASE_REIMBURSEMENT_RATE
    total_staff_cost = staff * _SD_BASE_COST_PER_STAFF * (is_understaffed ? _SD_TRAVEL_NURSE_PREMIUM : 1.0)

    # --- Feedback Loop 1: Volume-Revenue-Quality (reinforcing) ---
    quality_attraction = volume_elasticity_to_quality * (quality - 0.5)  # above/below average
    satisfaction_pull = _SD_SATISFACTION_FEEDBACK * (satisfaction - 0.5)
    population_factor = population / 10_000.0  # normalised to reference population

    du[STATE_VOLUME] = volume * (
        population_factor * 0.01 +         # population-driven demand
        quality_attraction +                # quality attracts/repels
        satisfaction_pull -                 # satisfaction attracts/repels
        0.02 * capacity_utilisation         # capacity constraint dampening
    )

    du[STATE_REVENUE] = _SD_VOLUME_REVENUE_ELASTICITY * (
        volume * revenue_per_visit - revenue  # revenue tracks toward volume * rate
    )

    # --- Feedback Loop 2: Staffing Sustainability (balancing) ---
    target_staff = volume / 200.0 + 10.0  # simplified staffing model
    recruitment_rate = 0.1 * max(target_staff - staff, 0.0) * quality  # quality aids recruitment
    burnout_level = clamp(1.0 - staffing_adequacy, 0.0, 1.0) * (is_understaffed ? 1.5 : 1.0)
    departure_rate = nurse_attrition_rate * staff * burnout_level

    du[STATE_STAFF] = recruitment_rate - departure_rate

    # Quality depends on staffing adequacy and revenue reinvestment
    investment_factor = _SD_REVENUE_QUALITY_INVESTMENT * revenue / max(total_staff_cost, 1.0)
    quality_from_staff = _SD_STAFF_QUALITY_IMPACT * (staffing_adequacy - 0.5)
    quality_decay = -0.05 * (1.0 - quality)  # natural regression toward mean

    du[STATE_QUALITY] = quality_from_staff + 0.1 * clamp(investment_factor - 1.0, -0.5, 0.5) + quality_decay

    # --- Feedback Loop 3: Community Health ---
    du[STATE_POPULATION] = population * (
        pop_growth +
        0.005 * (health - 0.5) -            # healthier community retains population
        _SD_POPULATION_OUTMIGRATION * (1.0 - satisfaction)  # dissatisfaction drives outmigration
    )

    # Cash dynamics
    operating_income = revenue - total_staff_cost - _SD_CASH_BURN_RATE
    du[STATE_CASH] = operating_income

    # Satisfaction driven by quality, wait times (capacity), and community health
    target_satisfaction = 0.4 * quality + 0.3 * (1.0 - capacity_utilisation) + 0.3 * health
    du[STATE_SATISFACTION] = 0.5 * (target_satisfaction - satisfaction)

    # Community health improved by hospital quality and access
    hospital_health_impact = 0.01 * quality * (volume / max(population, 1.0))
    du[STATE_HEALTH] = hospital_health_impact - _SD_COMMUNITY_HEALTH_DECAY * (1.0 - health)

    return nothing
end

# ---------------------------------------------------------------------------
# Solver interface
# ---------------------------------------------------------------------------

# SystemDynamicsResult is defined in types/results.jl — uses @kwdef struct with
# scenario_name, time_points, stock/flow vectors, is_sustainable, tipping_point_year, etc.

"""
    run_system_dynamics(u0::Vector{Float64}, params::SystemDynamicsParams) -> SystemDynamicsResult

Solve the hospital dynamics ODE system using the Tsit5 (Tsitouras 5th-order) solver.

# Arguments
- `u0`: Initial state vector of length 8:
  `[volume, revenue, staff, quality, population, cash, satisfaction, health]`.
- `params`: System dynamics parameters.

# Returns
A `SystemDynamicsResult` containing the full solution, closure detection, and equilibrium analysis.
"""
function run_system_dynamics(u0::Vector{Float64}, params::SystemDynamicsParams)
    @assert length(u0) == 8 "Initial state must have 8 elements: [volume, revenue, staff, quality, population, cash, satisfaction, health]"

    tspan = (0.0, Float64(params.time_horizon_years))
    prob = ODEProblem(hospital_dynamics!, u0, tspan, params)
    sol = solve(prob, Tsit5(); saveat = params.dt, abstol = 1e-8, reltol = 1e-6)

    closure_triggered, closure_time = detect_closure_triggers(sol, params)
    eq = find_equilibrium(sol)

    # Extract time series from ODE solution
    t_pts = sol.t
    volume_ts   = [sol[i][1] for i in eachindex(sol)]
    cash_ts     = [sol[i][6] for i in eachindex(sol)]
    staff_ts    = [sol[i][3] for i in eachindex(sol)]
    quality_ts  = [sol[i][4] for i in eachindex(sol)]
    pop_ts      = [sol[i][5] for i in eachindex(sol)]

    return SystemDynamicsResult(
        time_points = t_pts,
        inpatient_volume = volume_ts,
        cash_reserves = cash_ts,
        nurse_supply = staff_ts,
        population = pop_ts,
        is_sustainable = !closure_triggered,
        tipping_point_year = closure_time,
    )
end

"""
    run_system_dynamics(params::SystemDynamicsParams) -> SystemDynamicsResult

Run with default initial conditions for a typical 25-bed Critical Access Hospital.
"""
function run_system_dynamics(params::SystemDynamicsParams)
    u0 = [
        3000.0,       # volume: 3000 visits/year
        15_000_000.0, # revenue: 15M USD
        80.0,         # staff: 80 FTEs
        0.7,          # quality: above average
        8000.0,       # population: 8000
        5_000_000.0,  # cash: 5M reserves
        0.65,         # satisfaction: moderate
        0.6,          # health: moderate
    ]
    return run_system_dynamics(u0, params)
end

# ---------------------------------------------------------------------------
# Analysis helpers
# ---------------------------------------------------------------------------

"""
    detect_closure_triggers(sol, params) -> (triggered::Bool, time::Union{Float64, Nothing})

Scan the ODE solution for conditions that would trigger hospital closure:
1. Cash reserves fall below zero for an extended period.
2. Staffing drops below critical threshold.
3. Patient volume drops below viability floor (500 visits/year).

Returns a tuple of (whether triggered, time of first trigger).
"""
function detect_closure_triggers(sol, params::SystemDynamicsParams)
    consecutive_negative_cash = 0
    trigger_threshold = 4  # consecutive save points (~1 year at quarterly saves)

    for (i, t) in enumerate(sol.t)
        u = sol.u[i]
        volume = u[STATE_VOLUME]
        staff = u[STATE_STAFF]
        cash = u[STATE_CASH]

        # Cash exhaustion
        if cash < 0.0
            consecutive_negative_cash += 1
        else
            consecutive_negative_cash = 0
        end

        if consecutive_negative_cash >= trigger_threshold
            return (true, t)
        end

        # Critical staffing failure
        if staff < 5.0 && t > 1.0  # allow initial transient
            return (true, t)
        end

        # Volume collapse
        if volume < 500.0 && t > 1.0
            return (true, t)
        end
    end

    return (false, nothing)
end

"""
    find_equilibrium(sol; tail_fraction=0.1, tolerance=0.01) -> Union{Vector{Float64}, Nothing}

Attempt to detect if the system has reached equilibrium by examining the
final portion of the trajectory. Returns the equilibrium state vector if
the relative change in all state variables is below `tolerance`, otherwise `nothing`.
"""
function find_equilibrium(sol; tail_fraction::Float64 = 0.1, tolerance::Float64 = 0.01)
    n = length(sol.t)
    n < 10 && return nothing

    tail_start = max(1, round(Int, n * (1.0 - tail_fraction)))
    tail_states = sol.u[tail_start:end]

    # Check if state variables have stabilised
    first_state = tail_states[1]
    last_state = tail_states[end]

    for j in 1:length(first_state)
        ref = abs(first_state[j])
        ref < 1e-10 && continue  # skip near-zero states
        relative_change = abs(last_state[j] - first_state[j]) / ref
        if relative_change > tolerance
            return nothing
        end
    end

    return collect(last_state)
end
