# System Dynamics Engine
# Continuous-time ODE model of rural hospital feedback loops using DifferentialEquations.jl.

using DifferentialEquations

# ---------------------------------------------------------------------------
# Parameters
# ---------------------------------------------------------------------------

"""
    SystemDynamicsParams <: AbstractSimulationParams

Parameters for the system dynamics model of rural hospital viability.

# Feedback Loop Parameters
- `volume_revenue_elasticity::Float64`: Revenue response to volume changes.
- `revenue_quality_investment::Float64`: Fraction of revenue reinvested in quality.
- `quality_volume_attraction::Float64`: Quality's effect on attracting volume.
- `staff_quality_impact::Float64`: Staffing level impact on care quality.
- `burnout_departure_rate::Float64`: Rate at which burnout drives staff departures.
- `community_health_decay::Float64`: Natural decay rate of community health status.
- `population_outmigration_rate::Float64`: Baseline population outmigration rate.
- `satisfaction_volume_feedback::Float64`: Patient satisfaction impact on volume.

# External & Structural
- `base_reimbursement_rate::Float64`: Revenue per unit volume.
- `base_cost_per_staff::Float64`: Annual cost per FTE staff member.
- `travel_nurse_premium::Float64`: Cost multiplier for travel/agency staff.
- `critical_staff_threshold::Float64`: Minimum staffing ratio before quality degrades sharply.
- `cash_burn_rate::Float64`: Fixed overhead cash burn per time unit.
- `population_growth_rate::Float64`: Exogenous population growth rate.
- `max_capacity::Float64`: Maximum patient volume capacity.

# Simulation
- `tspan::Tuple{Float64, Float64}`: Time span for ODE integration (years).
- `dt_save::Float64`: Time step for saving solution output.
"""
struct SystemDynamicsParams <: AbstractSimulationParams
    # Feedback loop strengths
    volume_revenue_elasticity::Float64
    revenue_quality_investment::Float64
    quality_volume_attraction::Float64
    staff_quality_impact::Float64
    burnout_departure_rate::Float64
    community_health_decay::Float64
    population_outmigration_rate::Float64
    satisfaction_volume_feedback::Float64
    # External parameters
    base_reimbursement_rate::Float64
    base_cost_per_staff::Float64
    travel_nurse_premium::Float64
    critical_staff_threshold::Float64
    cash_burn_rate::Float64
    population_growth_rate::Float64
    max_capacity::Float64
    # Simulation control
    tspan::Tuple{Float64, Float64}
    dt_save::Float64
end

"""
    SystemDynamicsParams(; kwargs...)

Construct `SystemDynamicsParams` with keyword arguments and defaults
calibrated to a typical 25-bed Critical Access Hospital.
"""
function SystemDynamicsParams(;
    volume_revenue_elasticity::Float64 = 0.8,
    revenue_quality_investment::Float64 = 0.15,
    quality_volume_attraction::Float64 = 0.3,
    staff_quality_impact::Float64 = 0.5,
    burnout_departure_rate::Float64 = 0.1,
    community_health_decay::Float64 = 0.02,
    population_outmigration_rate::Float64 = 0.01,
    satisfaction_volume_feedback::Float64 = 0.2,
    base_reimbursement_rate::Float64 = 5000.0,
    base_cost_per_staff::Float64 = 85_000.0,
    travel_nurse_premium::Float64 = 1.8,
    critical_staff_threshold::Float64 = 0.6,
    cash_burn_rate::Float64 = 500_000.0,
    population_growth_rate::Float64 = -0.005,
    max_capacity::Float64 = 10_000.0,
    tspan::Tuple{Float64, Float64} = (0.0, 20.0),
    dt_save::Float64 = 0.25,
)
    SystemDynamicsParams(
        volume_revenue_elasticity, revenue_quality_investment,
        quality_volume_attraction, staff_quality_impact,
        burnout_departure_rate, community_health_decay,
        population_outmigration_rate, satisfaction_volume_feedback,
        base_reimbursement_rate, base_cost_per_staff,
        travel_nurse_premium, critical_staff_threshold,
        cash_burn_rate, population_growth_rate, max_capacity,
        tspan, dt_save,
    )
end

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

    # --- Derived quantities ---
    staffing_ratio = staff / (volume / 250.0 + 1.0)  # staff per ~250 visits
    staffing_adequacy = clamp(staffing_ratio / 5.0, 0.0, 1.5)  # normalised around target of 5
    is_understaffed = staffing_adequacy < p.critical_staff_threshold

    capacity_utilisation = clamp(volume / p.max_capacity, 0.0, 1.0)
    revenue_per_visit = p.base_reimbursement_rate
    total_staff_cost = staff * p.base_cost_per_staff * (is_understaffed ? p.travel_nurse_premium : 1.0)

    # --- Feedback Loop 1: Volume-Revenue-Quality (reinforcing) ---
    quality_attraction = p.quality_volume_attraction * (quality - 0.5)  # above/below average
    satisfaction_pull = p.satisfaction_volume_feedback * (satisfaction - 0.5)
    population_factor = population / 10_000.0  # normalised to reference population

    du[STATE_VOLUME] = volume * (
        population_factor * 0.01 +         # population-driven demand
        quality_attraction +                # quality attracts/repels
        satisfaction_pull -                 # satisfaction attracts/repels
        0.02 * capacity_utilisation         # capacity constraint dampening
    )

    du[STATE_REVENUE] = p.volume_revenue_elasticity * (
        volume * revenue_per_visit - revenue  # revenue tracks toward volume * rate
    )

    # --- Feedback Loop 2: Staffing Sustainability (balancing) ---
    target_staff = volume / 200.0 + 10.0  # simplified staffing model
    recruitment_rate = 0.1 * max(target_staff - staff, 0.0) * quality  # quality aids recruitment
    burnout_level = clamp(1.0 - staffing_adequacy, 0.0, 1.0) * (is_understaffed ? 1.5 : 1.0)
    departure_rate = p.burnout_departure_rate * staff * burnout_level

    du[STATE_STAFF] = recruitment_rate - departure_rate

    # Quality depends on staffing adequacy and revenue reinvestment
    investment_factor = p.revenue_quality_investment * revenue / max(total_staff_cost, 1.0)
    quality_from_staff = p.staff_quality_impact * (staffing_adequacy - 0.5)
    quality_decay = -0.05 * (1.0 - quality)  # natural regression toward mean

    du[STATE_QUALITY] = quality_from_staff + 0.1 * clamp(investment_factor - 1.0, -0.5, 0.5) + quality_decay

    # --- Feedback Loop 3: Community Health ---
    du[STATE_POPULATION] = population * (
        p.population_growth_rate +
        0.005 * (health - 0.5) -            # healthier community retains population
        p.population_outmigration_rate * (1.0 - satisfaction)  # dissatisfaction drives outmigration
    )

    # Cash dynamics
    operating_income = revenue - total_staff_cost - p.cash_burn_rate
    du[STATE_CASH] = operating_income

    # Satisfaction driven by quality, wait times (capacity), and community health
    target_satisfaction = 0.4 * quality + 0.3 * (1.0 - capacity_utilisation) + 0.3 * health
    du[STATE_SATISFACTION] = 0.5 * (target_satisfaction - satisfaction)

    # Community health improved by hospital quality and access
    hospital_health_impact = 0.01 * quality * (volume / max(population, 1.0))
    du[STATE_HEALTH] = hospital_health_impact - p.community_health_decay * (1.0 - health)

    return nothing
end

# ---------------------------------------------------------------------------
# Solver interface
# ---------------------------------------------------------------------------

"""
    SystemDynamicsResult <: AbstractSimulationResult

Results from the system dynamics simulation.

# Fields
- `params::SystemDynamicsParams`: Parameters used.
- `solution::ODESolution`: Full ODE solution from DifferentialEquations.jl.
- `closure_triggered::Bool`: Whether closure triggers were detected.
- `closure_time::Union{Float64, Nothing}`: Time at which closure was triggered, if applicable.
- `equilibrium::Union{Vector{Float64}, Nothing}`: Detected equilibrium state, if found.
"""
struct SystemDynamicsResult <: AbstractSimulationResult
    params::SystemDynamicsParams
    solution::Any  # ODESolution
    closure_triggered::Bool
    closure_time::Union{Float64, Nothing}
    equilibrium::Union{Vector{Float64}, Nothing}
end

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
function run_system_dynamics(u0::Vector{Float64}, params::SystemDynamicsParams)::SystemDynamicsResult
    @assert length(u0) == 8 "Initial state must have 8 elements: [volume, revenue, staff, quality, population, cash, satisfaction, health]"

    prob = ODEProblem(hospital_dynamics!, u0, params.tspan, params)
    sol = solve(prob, Tsit5(); saveat = params.dt_save, abstol = 1e-8, reltol = 1e-6)

    closure_triggered, closure_time = detect_closure_triggers(sol, params)
    eq = find_equilibrium(sol)

    return SystemDynamicsResult(params, sol, closure_triggered, closure_time, eq)
end

"""
    run_system_dynamics(params::SystemDynamicsParams) -> SystemDynamicsResult

Run with default initial conditions for a typical 25-bed Critical Access Hospital.
"""
function run_system_dynamics(params::SystemDynamicsParams)::SystemDynamicsResult
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
