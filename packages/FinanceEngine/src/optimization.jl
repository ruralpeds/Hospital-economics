"""
    optimization.jl — Discrete dynamic programming for resource allocation

Solves multi-period optimization problems under uncertainty using Bellman equations.
Uses QuantEcon.DiscreteDP for optimal capacity expansion, staffing, and capital budgeting.
"""

using QuantEcon: DiscreteDP, solve

"""
    rouwenhorst_grid(n::Int, ρ::Real, σ::Real) -> (grid::Vector, Π::Matrix)

Discretize an AR(1) process using the Rouwenhorst method.

y_t = ρ*y_{t-1} + ε_t where ε_t ~ N(0, σ²)

# Arguments
- `n`: Number of grid points
- `ρ`: Autocorrelation coefficient (0 < ρ < 1)
- `σ`: Standard deviation of innovations

# Returns
- `grid`: n equally-spaced log values (representing the AR(1) process)
- `Π`: n×n transition probability matrix

# Example
```julia
# Model patient demand as AR(1): demand = 0.8*demand_lag + noise
grid, Π = rouwenhorst_grid(15, ρ=0.8, σ=0.05)
# grid[1] ≈ low demand, grid[15] ≈ high demand
# Π[i,j] = P(demand goes from state i to state j)
```
"""
function rouwenhorst_grid(n::Int, ρ::Real, σ::Real)
    n >= 2 || throw(ArgumentError("n must be >= 2"))
    0 <= ρ < 1 || throw(ArgumentError("ρ must be in [0, 1)"))
    σ > 0 || throw(ArgumentError("σ must be positive"))

    # Standard deviations for grid
    σ_y = σ / sqrt(1 - ρ^2)

    # Grid bounds: approximately ±3 std devs
    grid_min = -3 * σ_y
    grid_max = 3 * σ_y
    grid = range(grid_min, grid_max, length=n)

    # Transition probabilities
    p = (1 + ρ) / 2
    q = p  # For Rouwenhorst method

    # Build transition matrix recursively
    if n == 2
        Π = [p 1-p; 1-q q]
    else
        # Recursively construct from smaller grid
        Π_prev = rouwenhorst_grid(n-1, ρ, σ)[2]
        Π = zeros(n, n)

        # Top-left block: p * Π_prev
        Π[1:n-1, 1:n-1] .+= p .* Π_prev

        # Top-right block: (1-p) * Π_prev
        Π[1:n-1, 2:n] .+= (1-p) .* Π_prev

        # Bottom-left block: (1-q) * Π_prev
        Π[2:n, 1:n-1] .+= (1-q) .* Π_prev

        # Bottom-right block: q * Π_prev
        Π[2:n, 2:n] .+= q .* Π_prev
    end

    # Normalize rows to sum to 1 (handle numerical errors)
    Π = Π ./ sum(Π, dims=2)

    return collect(grid), Π
end

"""
    optimal_bed_expansion(;
        initial_beds::Int,
        min_beds::Int,
        max_beds::Int,
        demand_states::Int,
        demand_autocorr::Real,
        demand_volatility::Real,
        occupancy_revenue::Real,
        empty_bed_cost::Real,
        expansion_cost_per_bed::Real,
        contraction_cost_per_bed::Real,
        discount_rate::Real,
        max_annual_expansion::Int
    ) -> result

Solve for optimal ICU bed expansion/contraction policy using discrete dynamic programming.

# Problem Setup
Hospital must decide each year how many beds to add or remove, trading off:
- Revenue from higher occupancy (more beds → fill more demand)
- Cost of empty beds (too many beds → high fixed costs)
- Expansion/contraction costs (expensive to add/remove beds)

# Arguments (with healthcare defaults)
- `initial_beds`: Starting ICU bed count (default 20)
- `min_beds`: Cannot go below this (default 5)
- `max_beds`: Cannot exceed this (default 50)
- `demand_states`: Number of demand scenarios to discretize (default 15)
- `demand_autocorr`: AR(1) persistence of demand shocks (default 0.85)
- `demand_volatility`: Std dev of demand growth shocks (default 0.03)
- `occupancy_revenue`: \$/bed/day when occupied (default 2500)
- `empty_bed_cost`: \$/bed/year for capacity overhead (default 50000)
- `expansion_cost_per_bed`: Cost to add one bed (default 200000)
- `contraction_cost_per_bed`: Cost to remove one bed (default 50000)
- `discount_rate`: Annual discount rate (default 0.05)
- `max_annual_expansion`: Maximum beds that can be added/removed per year (default 5)

# Returns
Named tuple with:
- `policy`: Matrix where policy[bed_state, demand_state] = optimal action (beds to add)
- `value`: Value function V[bed_state, demand_state]
- `demand_grid`: Discretized demand states
- `demand_trans`: Demand transition probability matrix
- `bed_states`: Possible bed count states
- `ddp`: Solved DiscreteDP object (for inspection)

# Example
```julia
result = optimal_bed_expansion(
    initial_beds=20,
    demand_autocorr=0.8,
    expansion_cost_per_bed=150000
)

# Current state: 20 beds, medium demand
current_demand_idx = 8  # middle of 15-state grid
action = result.policy[20, current_demand_idx]  # beds to add this year
# If action > 0: expand; if action < 0: contract; if action = 0: hold steady
```
"""
function optimal_bed_expansion(;
    initial_beds::Int=20,
    min_beds::Int=5,
    max_beds::Int=50,
    demand_states::Int=15,
    demand_autocorr::Real=0.85,
    demand_volatility::Real=0.03,
    occupancy_revenue::Real=2500,
    empty_bed_cost::Real=50000,
    expansion_cost_per_bed::Real=200000,
    contraction_cost_per_bed::Real=50000,
    discount_rate::Real=0.05,
    max_annual_expansion::Int=5
)

    # Validate inputs
    min_beds > 0 || throw(ArgumentError("min_beds must be positive"))
    max_beds >= min_beds || throw(ArgumentError("max_beds must be >= min_beds"))
    initial_beds in min_beds:max_beds || throw(ArgumentError("initial_beds must be in [min_beds, max_beds]"))
    discount_rate > 0 || throw(ArgumentError("discount_rate must be positive"))

    # Discretize demand process: AR(1) with Rouwenhorst
    demand_grid, demand_trans = rouwenhorst_grid(demand_states, demand_autocorr, demand_volatility)

    # Normalize demand to [0, 1] (as fraction of max capacity)
    demand_grid = exp.(demand_grid)  # Convert from log-space
    demand_grid = demand_grid ./ maximum(demand_grid)

    bed_states = collect(min_beds:max_beds)
    n_beds = length(bed_states)

    # State: (bed_count_idx, demand_idx)
    # Action: change in beds (-max_annual_expansion to +max_annual_expansion)

    n_states = n_beds * demand_states
    action_set = -max_annual_expansion:max_annual_expansion
    n_actions = length(action_set)

    # Payoff matrix: R[state, action]
    R = fill(-Inf, n_states, n_actions)

    for (bed_idx, n_beds_state) in enumerate(bed_states)
        for (demand_idx, demand) in enumerate(demand_grid)
            state_idx = (bed_idx - 1) * demand_states + demand_idx

            for (action_idx, action) in enumerate(action_set)
                new_beds = n_beds_state + action

                # Check feasibility
                if new_beds < min_beds || new_beds > max_beds
                    continue
                end

                # Revenue: occupancy × beds × annual days
                occupancy = min(demand, 1.0)  # Can't exceed capacity
                revenue = occupancy * new_beds * 365 * occupancy_revenue

                # Cost of empty beds
                empty_beds = max(0, new_beds - demand * new_beds)
                empty_cost = empty_beds * empty_bed_cost

                # Expansion/contraction cost
                if action > 0
                    expansion_cost = action * expansion_cost_per_bed
                elseif action < 0
                    expansion_cost = abs(action) * contraction_cost_per_bed
                else
                    expansion_cost = 0
                end

                # Net payoff (negative of cost, since DiscreteDP maximizes)
                R[state_idx, action_idx] = revenue - empty_cost - expansion_cost
            end
        end
    end

    # Transition matrix: Q[state, state']
    # If we're in (bed_idx, demand_idx) and take action, next bed level is deterministic
    # but demand transitions stochastically
    Q = zeros(n_states, n_states)

    for (bed_idx, n_beds_state) in enumerate(bed_states)
        for (demand_idx, demand) in enumerate(demand_grid)
            state_idx = (bed_idx - 1) * demand_states + demand_idx

            for (action_idx, action) in enumerate(action_set)
                new_beds = n_beds_state + action

                # Check feasibility
                if new_beds < min_beds || new_beds > max_beds
                    continue
                end

                # Find new bed index
                new_bed_idx = findfirst(==(new_beds), bed_states)

                # Demand transitions: stochastic
                for next_demand_idx in 1:demand_states
                    next_state_idx = (new_bed_idx - 1) * demand_states + next_demand_idx
                    Q[state_idx, next_state_idx] += demand_trans[demand_idx, next_demand_idx]
                end
            end
        end
    end

    # Solve the DDP problem
    ddp = DiscreteDP(R, Q, discount_rate)
    v, policy_idx = solve(ddp, max_iterations=500, tol=1e-6)

    # Convert policy indices to actual actions
    policy = similar(policy_idx)
    for (bed_idx, n_beds_state) in enumerate(bed_states)
        for demand_idx in 1:demand_states
            state_idx = (bed_idx - 1) * demand_states + demand_idx
            action_idx = policy_idx[state_idx]
            policy[bed_idx, demand_idx] = action_set[action_idx]
        end
    end

    # Reshape value function to (n_beds, demand_states)
    v_reshaped = reshape(v, (n_beds, demand_states))

    return (
        policy = policy,
        value = v_reshaped,
        demand_grid = demand_grid,
        demand_trans = demand_trans,
        bed_states = bed_states,
        ddp = ddp
    )
end

"""
    optimal_staffing(;
        initial_fte::Int,
        min_fte::Int,
        max_fte::Int,
        demand_states::Int,
        demand_autocorr::Real,
        demand_volatility::Real,
        annual_salary::Real,
        productivity_per_fte::Real,
        hiring_cost_per_fte::Real,
        severance_cost_per_fte::Real,
        max_annual_hiring::Int,
        discount_rate::Real
    ) -> result

Solve for optimal staffing levels under uncertain patient demand using DiscreteDP.

# Problem Setup
Hospital must decide each year how many FTEs to hire/lay off, balancing:
- Salary costs for each FTE
- Revenue from higher staffing (better service → more patients served)
- Hiring and severance costs
- Constraints on how fast can scale

# Arguments (with healthcare defaults)
- `initial_fte`: Starting staff FTEs (default 50)
- `min_fte`: Minimum required staffing (default 20)
- `max_fte`: Maximum budgeted staffing (default 100)
- `demand_states`: Scenarios for patient volume (default 15)
- `demand_autocorr`: AR(1) persistence (default 0.80)
- `demand_volatility`: Growth volatility (default 0.05)
- `annual_salary`: Fully-loaded cost per FTE (default 80000)
- `productivity_per_fte`: Annual patients served per FTE (default 500)
- `hiring_cost_per_fte`: Onboarding, training cost (default 10000)
- `severance_cost_per_fte`: Separation cost (default 15000)
- `max_annual_hiring`: Maximum FTE change per year (default 5)
- `discount_rate`: Annual discount rate (default 0.05)

# Returns
Named tuple with:
- `policy`: Optimal hiring/layoff decisions for each (fte_state, demand_state)
- `value`: Value function (expected discounted profit)
- `demand_grid`: Discretized patient demand states
- `fte_states`: Possible staffing levels
- `ddp`: Solved DiscreteDP object

# Example
```julia
result = optimal_staffing(
    initial_fte=60,
    demand_autocorr=0.75,
    hiring_cost_per_fte=8000
)

# Policy: If we have 50 FTEs and demand is high (state 12)
optimal_action = result.policy[50, 12]
# positive = hire more, negative = layoff, zero = hold steady
```
"""
function optimal_staffing(;
    initial_fte::Int=50,
    min_fte::Int=20,
    max_fte::Int=100,
    demand_states::Int=15,
    demand_autocorr::Real=0.80,
    demand_volatility::Real=0.05,
    annual_salary::Real=80000,
    productivity_per_fte::Real=500,
    hiring_cost_per_fte::Real=10000,
    severance_cost_per_fte::Real=15000,
    max_annual_hiring::Int=5,
    discount_rate::Real=0.05
)

    # Validate inputs
    min_fte > 0 || throw(ArgumentError("min_fte must be positive"))
    max_fte >= min_fte || throw(ArgumentError("max_fte must be >= min_fte"))
    initial_fte in min_fte:max_fte || throw(ArgumentError("initial_fte must be in range"))
    productivity_per_fte > 0 || throw(ArgumentError("productivity_per_fte must be positive"))

    # Discretize demand
    demand_grid, demand_trans = rouwenhorst_grid(demand_states, demand_autocorr, demand_volatility)
    demand_grid = exp.(demand_grid)  # Convert from log-space
    demand_grid = demand_grid ./ maximum(demand_grid)  # Normalize to [0, 1]

    fte_states = collect(min_fte:max_fte)
    n_fte = length(fte_states)

    # Actions: change in FTEs
    action_set = -max_annual_hiring:max_annual_hiring
    n_actions = length(action_set)

    # Payoff matrix
    R = fill(-Inf, n_fte * demand_states, n_actions)

    for (fte_idx, fte) in enumerate(fte_states)
        for (demand_idx, demand) in enumerate(demand_grid)
            state_idx = (fte_idx - 1) * demand_states + demand_idx

            for (action_idx, action) in enumerate(action_set)
                new_fte = fte + action

                # Feasibility
                if new_fte < min_fte || new_fte > max_fte
                    continue
                end

                # Revenue: capacity utilized is min(demand, productivity*fte)
                available_capacity = new_fte * productivity_per_fte
                patients_served = min(demand * available_capacity, available_capacity)
                revenue = patients_served * 200  # Assume $200 per patient (revenue split)

                # Salary costs
                salary_cost = new_fte * annual_salary

                # Hiring/severance costs
                if action > 0
                    adjustment_cost = action * hiring_cost_per_fte
                elseif action < 0
                    adjustment_cost = abs(action) * severance_cost_per_fte
                else
                    adjustment_cost = 0
                end

                # Net payoff
                R[state_idx, action_idx] = revenue - salary_cost - adjustment_cost
            end
        end
    end

    # Transition matrix
    Q = zeros(n_fte * demand_states, n_fte * demand_states)

    for (fte_idx, fte) in enumerate(fte_states)
        for (demand_idx, demand) in enumerate(demand_grid)
            state_idx = (fte_idx - 1) * demand_states + demand_idx

            for (action_idx, action) in enumerate(action_set)
                new_fte = fte + action

                if new_fte < min_fte || new_fte > max_fte
                    continue
                end

                new_fte_idx = findfirst(==(new_fte), fte_states)

                # Demand transitions
                for next_demand_idx in 1:demand_states
                    next_state_idx = (new_fte_idx - 1) * demand_states + next_demand_idx
                    Q[state_idx, next_state_idx] += demand_trans[demand_idx, next_demand_idx]
                end
            end
        end
    end

    # Solve DDP
    ddp = DiscreteDP(R, Q, discount_rate)
    v, policy_idx = solve(ddp, max_iterations=500, tol=1e-6)

    # Convert policy indices to actions
    policy = similar(policy_idx)
    for (fte_idx, fte) in enumerate(fte_states)
        for demand_idx in 1:demand_states
            state_idx = (fte_idx - 1) * demand_states + demand_idx
            action_idx = policy_idx[state_idx]
            policy[fte_idx, demand_idx] = action_set[action_idx]
        end
    end

    # Reshape value function
    v_reshaped = reshape(v, (n_fte, demand_states))

    return (
        policy = policy,
        value = v_reshaped,
        demand_grid = demand_grid,
        demand_trans = demand_trans,
        fte_states = fte_states,
        ddp = ddp
    )
end
