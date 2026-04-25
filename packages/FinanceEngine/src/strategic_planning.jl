"""
    strategic_planning.jl — Linear-quadratic control for smooth cost trajectories

Solves for optimal cost reduction and revenue enhancement paths under constraints.
Minimizes operational disruption (staffing, service changes) while reaching financial targets.

Uses QuantEcon.LQ for control-theoretic optimization.
"""

using QuantEcon: LQ, compute_sequence

"""
    cost_trajectory(;
        current_cost::Real,
        target_cost::Real,
        horizon::Int,
        cost_change_weight::Real,
        adjustment_cost::Real,
        discount_rate::Real
    ) -> result

Solve for optimal cost reduction path using linear-quadratic control.

The hospital wants to reduce costs from current to target over a horizon,
but cost reduction has constraints and adjustment costs:
- Too-fast cuts → operational disruption, staff turnover, service quality
- Too-slow cuts → financial stress continues longer

LQ control finds the **smooth trajectory** that balances these tradeoffs.

# Arguments
- `current_cost`: Annual operating cost today (\$, e.g., 50M)
- `target_cost`: Desired cost in final year (\$, e.g., 40M)
- `horizon`: Years to execute cost reduction (e.g., 3 years)
- `cost_change_weight`: Penalty for deviating from target (higher = must hit target)
  - Default: 1.0 (unit penalty per \$ of overshoot)
- `adjustment_cost`: Penalty for changing costs quickly (higher = slower cuts)
  - Default: 0.5 (encourages gradual reduction)
- `discount_rate`: Annual discount rate (default: 0.05)

# Returns
Named tuple with:
- `optimal_costs`: Year-by-year cost path (cost[1] = year 1, ..., cost[horizon] = year horizon)
- `required_reductions`: Savings target each year
- `adjustment_costs`: Adjustment burden each year (operational disruption)
- `total_adjustment_cost`: Sum of all adjustment costs
- `feasibility_margin`: How close to hitting target? (0 = exact, <0 = miss)
- `smoothness`: How gradual is transition? (0 = very smooth, 1 = abrupt)

# Example
```julia
result = cost_trajectory(
    current_cost = 50_000_000,     # \$50M annually
    target_cost = 45_000_000,      # \$45M target
    horizon = 3,                   # 3-year plan
    adjustment_cost = 0.8          # Penalize fast cuts
)

# Year 1: cost_reduction ≈ 1.2M (gradual)
# Year 2: cost_reduction ≈ 1.8M (accelerating)
# Year 3: cost_reduction ≈ 2.0M (reaches target)
```
"""
function cost_trajectory(;
    current_cost::Real,
    target_cost::Real,
    horizon::Int,
    cost_change_weight::Real=1.0,
    adjustment_cost::Real=0.5,
    discount_rate::Real=0.05)

    current_cost > 0 || throw(ArgumentError("current_cost must be positive"))
    target_cost > 0 || throw(ArgumentError("target_cost must be positive"))
    horizon > 0 || throw(ArgumentError("horizon must be positive"))
    cost_change_weight >= 0 || throw(ArgumentError("cost_change_weight must be non-negative"))
    adjustment_cost >= 0 || throw(ArgumentError("adjustment_cost must be non-negative"))
    discount_rate > 0 || throw(ArgumentError("discount_rate must be positive"))

    # LQ state-space formulation
    # State x_t = cost in year t
    # Control u_t = cost reduction (negative = reduction)
    # Transition: x_{t+1} = x_t + u_t (cost changes by control action)

    # Cost function: minimize ||x_T - target||² + sum_t(u_t²)*adjustment_cost
    # Q = cost_change_weight (penalty for missing target at end)
    # R = adjustment_cost (penalty for changing costs quickly)
    # A = 1.0 (cost carries forward)
    # B = 1.0 (control affects cost directly)

    Q = cost_change_weight
    R = max(adjustment_cost, 1e-6)  # Avoid singularity
    A = 1.0
    B = 1.0

    # Create and solve LQ problem
    lq = LQ(Q, R, A, B, beta=1.0/(1 + discount_rate))

    # Compute optimal sequence from current cost
    # x0 = current cost, T = horizon
    x_path, u_path, w_path = compute_sequence(lq, current_cost, horizon)

    # Convert to meaningful interpretation
    # u_path[t] = change in cost (negative = reduction, positive = increase)
    optimal_costs = x_path[1:horizon]
    cost_reductions = -u_path[1:horizon]  # Make positive (savings)
    adjustment_costs = adjustment_cost .* u_path[1:horizon].^2

    # Terminal cost (how close to target?)
    terminal_cost = abs(optimal_costs[end] - target_cost)
    feasibility_margin = (target_cost - terminal_cost) / target_cost

    # Smoothness: std dev of reduction rates (0 = constant, 1 = highly variable)
    mean_reduction = mean(cost_reductions)
    if mean_reduction > 0
        smoothness = std(cost_reductions) / mean_reduction
    else
        smoothness = 0.0
    end

    return (
        optimal_costs = optimal_costs,
        required_reductions = cost_reductions,
        adjustment_costs = adjustment_costs,
        total_adjustment_cost = sum(adjustment_costs),
        feasibility_margin = feasibility_margin,
        smoothness = smoothness,
        lq_problem = lq
    )
end

"""
    merger_integration_plan(;
        hospital_a_cost::Real,
        hospital_b_cost::Real,
        synergy_target::Real,
        integration_horizon::Int,
        disruption_penalty::Real,
        integration_complexity::Real,
        discount_rate::Real
    ) -> result

Plan optimal cost reduction post-merger under operational constraints.

After merging two hospitals, redundancy must be eliminated gradually:
- **Too fast:** Staff morale plummets, quality suffers, emergency departures
- **Too slow:** Miss synergy targets, cost savings don't materialize, loses stakeholder support

LQ control finds the optimal **integration velocity** that balances these.

# Arguments
- `hospital_a_cost`: Annual operating cost hospital A (\$, e.g., 30M)
- `hospital_b_cost`: Annual operating cost hospital B (\$, e.g., 20M)
- `synergy_target`: Expected cost savings (\$, e.g., 8M = 13% combined cost)
- `integration_horizon`: Years to realize synergies (typically 2–3)
- `disruption_penalty`: Cost of operational disruption per \$ of cost cut
  - 0.1 = 10% of saved cost is disruption cost
  - 0.5 = 50% of saved cost is disruption cost (very high friction)
- `integration_complexity`: Multiplier for EHR/process complexity
  - 1.0 = moderate complexity
  - 2.0 = high complexity (different EHRs, cultures)
- `discount_rate`: Annual discount (default 0.05)

# Returns
Named tuple with:
- `combined_cost`: Starting annual cost (A + B)
- `target_cost`: Final annual cost after synergies
- `optimal_path`: Year-by-year cost trajectory
- `annual_synergies`: Cost savings each year
- `disruption_costs`: Operational impact each year (staff turnover, IT migration, etc.)
- `net_benefit`: Total synergies minus disruption costs
- `integration_velocity`: How fast is transition? (0 = very slow, 1 = very fast)
- `recommendation`: "Proceed as planned", "Accelerate", "Slow down", etc.

# Example
```julia
result = merger_integration_plan(
    hospital_a_cost = 30_000_000,      # \$30M
    hospital_b_cost = 20_000_000,      # \$20M
    synergy_target = 8_000_000,        # 13% savings target
    integration_horizon = 2,            # 2 years
    disruption_penalty = 0.3           # 30% of savings lost to disruption
)

# Year 1: Cut costs by \$3M (slowly to minimize disruption)
# Year 2: Cut costs by \$5M (reach target)
# Net benefit: \$8M - \$X disruption costs
```
"""
function merger_integration_plan(;
    hospital_a_cost::Real,
    hospital_b_cost::Real,
    synergy_target::Real,
    integration_horizon::Int,
    disruption_penalty::Real=0.3,
    integration_complexity::Real=1.0,
    discount_rate::Real=0.05)

    hospital_a_cost > 0 || throw(ArgumentError("hospital_a_cost must be positive"))
    hospital_b_cost > 0 || throw(ArgumentError("hospital_b_cost must be positive"))
    synergy_target >= 0 || throw(ArgumentError("synergy_target must be non-negative"))
    integration_horizon > 0 || throw(ArgumentError("integration_horizon must be positive"))
    disruption_penalty >= 0 || throw(ArgumentError("disruption_penalty must be non-negative"))
    integration_complexity > 0 || throw(ArgumentError("integration_complexity must be positive"))

    # Combined starting cost
    combined_cost = hospital_a_cost + hospital_b_cost
    target_cost = combined_cost - synergy_target

    # Adjust cost weights for integration complexity
    # Higher complexity = harder to cut quickly without disruption
    adjustment_cost = disruption_penalty * integration_complexity

    # Solve using cost_trajectory framework
    result = cost_trajectory(
        current_cost = combined_cost,
        target_cost = target_cost,
        horizon = integration_horizon,
        cost_change_weight = 2.0,  # Strong incentive to hit synergy target
        adjustment_cost = adjustment_cost,
        discount_rate = discount_rate
    )

    # Interpret for merger context
    annual_synergies = result.required_reductions
    disruption_burden = result.adjustment_costs
    net_benefits = annual_synergies .- disruption_burden

    # Integration velocity (0 = conservative/slow, 1 = aggressive/fast)
    integration_velocity = result.smoothness

    # Recommendation based on net benefits
    total_net = sum(net_benefits)
    if total_net >= synergy_target * 0.8
        recommendation = "Proceed as planned: Integration velocity is optimal"
    elseif integration_velocity > 0.6 && total_net < synergy_target * 0.6
        recommendation = "Slow down: Current pace creates too much disruption; reduce disruption costs"
    elseif total_net > 0
        recommendation = "Accelerate: Safe to move faster; most disruption is temporary"
    else
        recommendation = "CAUTION: Integration may not achieve targets; reassess scope"
    end

    return (
        combined_cost = combined_cost,
        target_cost = target_cost,
        optimal_path = result.optimal_costs,
        annual_synergies = annual_synergies,
        disruption_costs = disruption_burden,
        net_benefit = sum(net_benefits),
        integration_velocity = integration_velocity,
        recommendation = recommendation,
        detailed_result = result
    )
end

"""
    restructuring_plan(;
        current_margin::Real,
        target_margin::Real,
        annual_revenue::Real,
        time_horizon::Int,
        minimum_margin_allowed::Real,
        max_annual_cost_cut::Real,
        discount_rate::Real
    ) -> result

Generate feasible restructuring plan from current margin to target.

Combines cost reduction + revenue initiatives to hit margin target.
Respects operational constraints (can't cut more than max per year).

# Arguments
- `current_margin`: Current operating margin (e.g., 0.05 = 5%)
- `target_margin`: Target operating margin (e.g., 0.10 = 10%)
- `annual_revenue`: Annual revenue (\$, e.g., 100M)
- `time_horizon`: Years to achieve target
- `minimum_margin_allowed`: Floor (can't go below this, e.g., 0.02 = 2% minimum)
- `max_annual_cost_cut`: Maximum annual cost reduction (\$ or % of revenue)
  - 0.05 = max 5% of revenue per year
- `discount_rate`: Discount rate for NPV calculations

# Returns
- `current_cost`: Starting annual cost
- `target_cost`: Final annual cost needed for target margin
- `optimal_path`: Year-by-year costs
- `required_improvements`: Total improvement needed (cost cuts + revenue growth)
- `feasibility_score`: 0–1 (1 = easily achievable, 0 = impossible with constraints)
- `critical_path`: What must happen (cost cuts vs. revenue growth priority)
- `recommendation`: "Ambitious but feasible", "Unrealistic", "Easily achievable", etc.

# Example
```julia
result = restructuring_plan(
    current_margin = 0.05,         # 5% margin
    target_margin = 0.10,          # 10% target
    annual_revenue = 100_000_000,  # \$100M revenue
    time_horizon = 3,
    max_annual_cost_cut = 0.05     # Max 5% per year
)
```
"""
function restructuring_plan(;
    current_margin::Real,
    target_margin::Real,
    annual_revenue::Real,
    time_horizon::Int,
    minimum_margin_allowed::Real=0.02,
    max_annual_cost_cut::Real=0.05,
    discount_rate::Real=0.05)

    0 <= current_margin <= 1 || throw(ArgumentError("current_margin must be in [0,1]"))
    0 <= target_margin <= 1 || throw(ArgumentError("target_margin must be in [0,1]"))
    annual_revenue > 0 || throw(ArgumentError("annual_revenue must be positive"))
    time_horizon > 0 || throw(ArgumentError("time_horizon must be positive"))
    minimum_margin_allowed >= 0 || throw(ArgumentError("minimum_margin_allowed must be non-negative"))
    max_annual_cost_cut > 0 || throw(ArgumentError("max_annual_cost_cut must be positive"))

    # Current and target costs
    current_cost = annual_revenue * (1 - current_margin)
    target_cost = annual_revenue * (1 - target_margin)
    total_improvement_needed = current_cost - target_cost

    # Maximum possible improvement per year
    max_improvement_per_year = annual_revenue * max_annual_cost_cut
    max_total_improvement = max_improvement_per_year * time_horizon

    # Feasibility: can we achieve target given constraints?
    if total_improvement_needed <= max_total_improvement && target_margin >= minimum_margin_allowed
        feasibility_score = min(1.0, max_total_improvement / (total_improvement_needed + 1e-6))
        if feasibility_score > 0.95
            feasibility = "Easily achievable"
        elseif feasibility_score > 0.8
            feasibility = "Ambitious but feasible"
        elseif feasibility_score > 0.6
            feasibility = "Challenging; needs execution discipline"
        else
            feasibility = "Very tight; minimal margin for error"
        end
    else
        feasibility_score = max_total_improvement / total_improvement_needed
        if feasibility_score > 0.5
            feasibility = "Unrealistic with current constraints; revise targets"
        else
            feasibility = "Impossible; requires changing constraints or targets"
        end
    end

    # Solve cost trajectory from current to feasible target
    feasible_target_cost = max(target_cost, current_cost - max_total_improvement)

    result = cost_trajectory(
        current_cost = current_cost,
        target_cost = feasible_target_cost,
        horizon = time_horizon,
        cost_change_weight = 1.0,
        adjustment_cost = 0.4,
        discount_rate = discount_rate
    )

    # Determine critical path (cost cuts vs. revenue growth)
    improvement_shortfall = target_cost - feasible_target_cost
    if improvement_shortfall > 0
        critical_path = "Must increase revenue by \$$(round(improvement_shortfall/1e6, digits=1))M to hit target margin"
    else
        critical_path = "Cost cuts alone sufficient; revenue growth is upside"
    end

    return (
        current_cost = current_cost,
        current_margin = current_margin,
        target_cost = target_cost,
        feasible_target_cost = feasible_target_cost,
        optimal_path = result.optimal_costs,
        required_improvements = result.required_reductions,
        total_improvement_needed = total_improvement_needed,
        feasibility_score = feasibility_score,
        feasibility_text = feasibility,
        critical_path = critical_path,
        recommendation = feasibility,
        detailed_result = result
    )
end

"""
    revenue_enhancement_plan(;
        current_revenue::Real,
        target_revenue::Real,
        current_margin::Real,
        time_horizon::Int,
        growth_initiative_weight::Real,
        market_growth_rate::Real,
        discount_rate::Real
    ) -> result

Plan revenue growth path from current to target under market constraints.

Unlike cost cutting (painful but controllable), revenue growth must align with market.
This function finds the optimal growth trajectory subject to:
- Market capacity constraints
- Payer rate pressures
- Competitive dynamics

# Arguments
- `current_revenue`: Annual revenue (\$, e.g., 100M)
- `target_revenue`: Revenue goal (\$, e.g., 120M)
- `current_margin`: Current operating margin (for context)
- `time_horizon`: Years to achieve target
- `growth_initiative_weight`: Effort/cost of growth initiatives per \$ of revenue
  - 0.1 = 10% of new revenue consumed by growth investments
  - 0.5 = 50% of new revenue consumed (very expensive)
- `market_growth_rate`: Market growth rate that can be captured without much effort (e.g., 0.02 = 2%/year organic)
- `discount_rate`: Discount rate

# Returns
- `optimal_path`: Year-by-year revenue trajectory
- `annual_growth`: Revenue growth each year
- `cumulative_growth`: Total growth achieved
- `growth_investment_required`: Cost of achieving growth
- `net_margin_impact`: How much margin improves from revenue growth
- `feasibility`: "Easily achievable", "Realistic", "Stretch goal", "Unrealistic"
"""
function revenue_enhancement_plan(;
    current_revenue::Real,
    target_revenue::Real,
    current_margin::Real,
    time_horizon::Int,
    growth_initiative_weight::Real=0.15,
    market_growth_rate::Real=0.02,
    discount_rate::Real=0.05)

    current_revenue > 0 || throw(ArgumentError("current_revenue must be positive"))
    target_revenue > current_revenue || throw(ArgumentError("target_revenue must exceed current"))
    time_horizon > 0 || throw(ArgumentError("time_horizon must be positive"))
    growth_initiative_weight >= 0 || throw(ArgumentError("growth_initiative_weight must be non-negative"))
    market_growth_rate >= 0 || throw(ArgumentError("market_growth_rate must be non-negative"))

    # Revenue growth needed
    total_growth_needed = target_revenue - current_revenue
    annual_organic_growth = current_revenue * market_growth_rate

    # Maximum achievable growth (organic + initiative-driven)
    # Assume can drive 3x market rate with effort
    max_achievable_annual = annual_organic_growth * 3

    # LQ trajectory for revenue growth
    # Similar to cost trajectory but for growth
    # State = revenue, Control = growth investment effort
    # Goal = hit target while minimizing disruption cost of growth initiatives

    # Simple heuristic: linear growth path if feasible
    if total_growth_needed / time_horizon <= max_achievable_annual
        # Feasible: gradual growth path
        annual_growth = repeat([total_growth_needed / time_horizon], time_horizon)
        path_feasibility = 1.0
        feasibility_text = "Realistic with reasonable growth initiatives"
    elseif total_growth_needed / time_horizon <= max_achievable_annual * 1.5
        # Stretch but possible
        annual_growth = repeat([total_growth_needed / time_horizon], time_horizon)
        path_feasibility = 0.7
        feasibility_text = "Stretch goal; requires aggressive but executable initiatives"
    else
        # Impossible with market constraints
        annual_growth = repeat([max_achievable_annual], time_horizon)
        path_feasibility = 0.3
        feasibility_text = "Unrealistic with market constraints; revise target or horizon"
    end

    # Revenue trajectory
    revenue_path = [current_revenue + sum(annual_growth[1:t]) for t in 1:time_horizon]

    # Growth investment cost (% of new revenue)
    growth_investments = annual_growth .* growth_initiative_weight

    # Margin impact: higher revenue (if fixed costs), minus growth investment costs
    margin_impact = sum(annual_growth) / (current_revenue * 2)  # Rough estimate

    return (
        optimal_path = revenue_path,
        annual_growth = annual_growth,
        cumulative_growth = sum(annual_growth),
        growth_investment_required = sum(growth_investments),
        net_margin_impact = margin_impact,
        feasibility_score = path_feasibility,
        feasibility_text = feasibility_text,
        organic_growth_potential = annual_organic_growth,
        max_achievable_annual = max_achievable_annual
    )
end
