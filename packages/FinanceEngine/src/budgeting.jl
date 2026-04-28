# ── Healthcare Budgeting and Variance Analysis ────────────────────────────────
#
# Operating budgets, flexible budgets, variance analysis, capital project
# ranking, zero-based budgeting, and rolling forecasts.
#
# Ported from healthcare-finance-julia/src/budgeting/budgeting_engine.jl

"""
    operating_budget(fixed_costs, variable_cost_per_unit, expected_volume,
                     price_per_unit; other_revenue=0.0) -> NamedTuple

Compute a departmental operating budget.
Returns `(revenue, variable_costs, fixed_costs, total_costs,
contribution_margin, operating_income)`.
"""
function operating_budget(fixed_costs::Real,
                           variable_cost_per_unit::Real,
                           expected_volume::Real,
                           price_per_unit::Real;
                           other_revenue::Real=0.0)
    fixed_costs >= 0 || throw(DomainValidationError("fixed_costs",
        string(fixed_costs), "≥ 0", "Fixed costs must be non-negative"))
    expected_volume >= 0 || throw(DomainValidationError("expected_volume",
        string(expected_volume), "≥ 0", "Expected volume must be non-negative"))
    revenue          = price_per_unit * expected_volume + other_revenue
    variable_costs   = variable_cost_per_unit * expected_volume
    total_costs      = fixed_costs + variable_costs
    contribution_margin = revenue - variable_costs
    operating_income = revenue - total_costs
    return (revenue=revenue, variable_costs=variable_costs,
            fixed_costs=fixed_costs, total_costs=total_costs,
            contribution_margin=contribution_margin,
            operating_income=operating_income)
end

"""
    flex_budget(fixed_costs, variable_cost_per_unit, actual_volume, price_per_unit;
                other_revenue=0.0) -> NamedTuple

Flexible budget restated at actual volume. Enables meaningful budget-vs-actual
variance analysis by holding the cost model constant while adjusting volume.
"""
function flex_budget(fixed_costs::Real,
                     variable_cost_per_unit::Real,
                     actual_volume::Real,
                     price_per_unit::Real;
                     other_revenue::Real=0.0)
    return operating_budget(fixed_costs, variable_cost_per_unit, actual_volume,
                            price_per_unit; other_revenue=other_revenue)
end

"""
    volume_variance(budgeted_cm_per_unit, actual_volume, budgeted_volume) -> Float64

Volume variance = budgeted contribution margin × (actual volume − budgeted volume).
Positive = favorable (higher-than-expected volume).
"""
function volume_variance(budgeted_cm_per_unit::Real,
                          actual_volume::Real,
                          budgeted_volume::Real)::Float64
    return Float64(budgeted_cm_per_unit * (actual_volume - budgeted_volume))
end

"""
    price_variance(actual_price, budgeted_price, actual_volume) -> Float64

Price variance = (actual price − budgeted price) × actual volume.
Positive = favorable (higher realization than budgeted).
"""
function price_variance(actual_price::Real,
                         budgeted_price::Real,
                         actual_volume::Real)::Float64
    return Float64((actual_price - budgeted_price) * actual_volume)
end

"""
    efficiency_variance(budgeted_cost_per_unit, actual_units_used,
                        standard_units_per_output, actual_output) -> Float64

Efficiency variance = budgeted cost × (actual inputs − standard inputs).
Positive = unfavorable (resource overuse). Common use: nursing hours, supply units.
"""
function efficiency_variance(budgeted_cost_per_unit::Real,
                              actual_units_used::Real,
                              standard_units_per_output::Real,
                              actual_output::Real)::Float64
    standard_inputs = standard_units_per_output * actual_output
    return Float64(budgeted_cost_per_unit * (actual_units_used - standard_inputs))
end

"""
    mix_variance(actual_volumes, budgeted_volumes, budgeted_margins) -> NamedTuple

Payer or service-line mix variance. Measures profit impact of shifting case
composition away from budget. Returns `(total_mix_variance, per_category)`.

All three vectors must have the same length.
"""
function mix_variance(actual_volumes::AbstractVector{<:Real},
                       budgeted_volumes::AbstractVector{<:Real},
                       budgeted_margins::AbstractVector{<:Real})
    n = length(actual_volumes)
    (n == length(budgeted_volumes) == length(budgeted_margins)) ||
        throw(DataValidationError(
            "actual_volumes, budgeted_volumes, and budgeted_margins must have equal length"))
    total_actual   = sum(actual_volumes)
    total_budgeted = sum(budgeted_volumes)
    total_budgeted > 0 || throw(DomainValidationError("sum(budgeted_volumes)",
        string(total_budgeted), "> 0", "Sum of budgeted volumes must be positive"))
    wtd_avg_margin = sum(budgeted_volumes .* budgeted_margins) / total_budgeted
    per_category = [total_actual *
                    (budgeted_volumes[i] / total_budgeted -
                     actual_volumes[i] / total_actual) *
                    wtd_avg_margin
                    for i in 1:n]
    return (total_mix_variance=sum(per_category), per_category=per_category)
end

"""
    rate_volume_variance(actual_revenue, budgeted_revenue, actual_volume,
                         budgeted_volume, budgeted_price) -> NamedTuple

Decompose total revenue variance into rate and volume components.
Returns `(total_variance, rate_variance, volume_variance)`.
"""
function rate_volume_variance(actual_revenue::Real,
                               budgeted_revenue::Real,
                               actual_volume::Real,
                               budgeted_volume::Real,
                               budgeted_price::Real)
    total_var = actual_revenue - budgeted_revenue
    vol_var   = volume_variance(budgeted_price, actual_volume, budgeted_volume)
    rate_var  = total_var - vol_var
    return (total_variance=total_var, rate_variance=rate_var,
            volume_variance=vol_var)
end

"""
    budget_to_actual_variance(budget, actual) -> NamedTuple

Compare a budget to actual spending.
Positive dollar variance = under budget (favorable for cost lines).
Returns `(dollar_variance, pct_variance)`.
"""
function budget_to_actual_variance(budget::Real, actual::Real)
    budget != 0 || throw(DomainValidationError("budget", string(budget),
        "≠ 0", "Budget cannot be zero"))
    dollar_var = budget - actual
    pct_var    = dollar_var / abs(budget)
    return (dollar_variance=dollar_var, pct_variance=pct_var)
end

"""
    capital_budget_rank(projects; npv_weight=0.7, strategic_weight=0.3)
        -> Vector{NamedTuple}

Rank capital projects by composite score: weighted NPV score + strategic score.

Each element of `projects` must have fields:
- `name` — project identifier
- `npv` — net present value (dollars)
- `strategic_score` — 0–10 strategic alignment score

Returns sorted vector (highest composite score first) with added `composite_score`.
"""
function capital_budget_rank(projects::AbstractVector;
                              npv_weight::Real=0.7,
                              strategic_weight::Real=0.3)
    isempty(projects) && throw(DataValidationError("projects cannot be empty"))
    abs(npv_weight + strategic_weight - 1.0) > 1e-6 &&
        throw(DomainValidationError("npv_weight + strategic_weight",
            string(npv_weight + strategic_weight), "= 1.0", "Weights must sum to 1"))
    npvs       = [p.npv for p in projects]
    min_npv    = minimum(npvs)
    max_npv    = maximum(npvs)
    range_npv  = max_npv - min_npv
    scored = map(projects) do p
        npv_norm  = range_npv > 0 ? (p.npv - min_npv) / range_npv * 10 : 5.0
        composite = npv_weight * npv_norm + strategic_weight * p.strategic_score
        (name=p.name, npv=p.npv, strategic_score=p.strategic_score,
         composite_score=composite)
    end
    return sort(scored; by=p -> p.composite_score, rev=true)
end

"""
    zero_based_budget_score(necessity_score, cost_effectiveness, strategic_alignment;
                            weights=(0.4, 0.3, 0.3)) -> Float64

Score a budget line item 0–10 across three dimensions for zero-based budgeting.
Each score must be in [0, 10]; weights must sum to 1.
"""
function zero_based_budget_score(necessity_score::Real,
                                  cost_effectiveness::Real,
                                  strategic_alignment::Real;
                                  weights::NTuple{3,Float64}=(0.4, 0.3, 0.3))::Float64
    for (label, val) in (("necessity_score",    necessity_score),
                          ("cost_effectiveness", cost_effectiveness),
                          ("strategic_alignment",strategic_alignment))
        0 <= val <= 10 || throw(DomainValidationError(label, string(val),
            "0 ≤ score ≤ 10", "Score must be in [0, 10]"))
    end
    abs(sum(weights) - 1.0) > 1e-6 && throw(DomainValidationError("weights",
        string(sum(weights)), "= 1.0", "Weights must sum to 1"))
    return weights[1] * necessity_score +
           weights[2] * cost_effectiveness +
           weights[3] * strategic_alignment
end

"""
    rolling_forecast_update(actuals_ytd, periods_elapsed, periods_total,
                            original_annual_budget) -> NamedTuple

Project the annual outcome from year-to-date actuals using run-rate extrapolation.
Returns `(projected_annual, variance_to_budget, pct_variance)`.
"""
function rolling_forecast_update(actuals_ytd::Real,
                                  periods_elapsed::Integer,
                                  periods_total::Integer,
                                  original_annual_budget::Real)
    periods_elapsed > 0 || throw(DomainValidationError("periods_elapsed",
        string(periods_elapsed), "> 0", "Periods elapsed must be positive"))
    periods_total > periods_elapsed || throw(DomainValidationError("periods_total",
        string(periods_total), "> periods_elapsed",
        "Total periods must exceed periods elapsed"))
    original_annual_budget != 0 || throw(DomainValidationError(
        "original_annual_budget", string(original_annual_budget),
        "≠ 0", "Budget cannot be zero"))
    run_rate         = actuals_ytd / periods_elapsed
    projected_annual = run_rate * periods_total
    variance         = original_annual_budget - projected_annual
    return (projected_annual=projected_annual,
            variance_to_budget=variance,
            pct_variance=variance / abs(original_annual_budget))
end
