# health_economics/ICER.jl — Cost-Effectiveness Analysis

"""
    CostEffectivenessResult

Results from cost-effectiveness analysis.

# Fields
- `icer::Float64` — Incremental Cost-Effectiveness Ratio (cost per effect unit)
- `cost_difference::Float64` — Δ Cost (intervention - control)
- `effect_difference::Float64` — Δ Effect (intervention - control)
- `incremental_nmb::Float64` — Net Monetary Benefit
- `cost_effective::Bool` — Whether ICER < threshold
- `dominated::Bool` — Whether intervention is dominated (worse on all dimensions)
- `extended_dominance::Bool` — Whether ruled out by cost-effectiveness frontier
"""
struct CostEffectivenessResult
    icer::Float64
    cost_difference::Float64
    effect_difference::Float64
    incremental_nmb::Float64
    cost_effective::Bool
    dominated::Bool
    extended_dominance::Bool
    ce_threshold::Float64
    metadata::Dict{String, Any}
end

"""
    calculate_icer(;
        intervention_cost::Float64,
        intervention_effect::Float64,
        control_cost::Float64,
        control_effect::Float64,
        ce_threshold::Float64 = DEFAULT_ICER_THRESHOLD
    )::CostEffectivenessResult

Calculate Incremental Cost-Effectiveness Ratio (ICER).

ICER = (Cost_intervention - Cost_control) / (Effect_intervention - Effect_control)

# Arguments
- `intervention_cost::Float64` — Total cost of intervention
- `intervention_effect::Float64` — Clinical effect (QALY, life years, etc.)
- `control_cost::Float64` — Total cost of control/standard care
- `control_effect::Float64` — Clinical effect of control
- `ce_threshold::Float64` — Willingness-to-pay threshold (default USD100K/QALY)

# Example
```julia
icer = calculate_icer(
    intervention_cost = 50_000.0,
    intervention_effect = 1.5,      # 1.5 QALYs gained
    control_cost = 30_000.0,
    control_effect = 1.0             # 1.0 QALYs
)

# ICER = (50k - 30k) / (1.5 - 1.0) = 20k / 0.5 = USD40,000 per QALY
# Cost-effective if threshold is USD100K per QALY
```
"""
function calculate_icer(;
    intervention_cost::Float64,
    intervention_effect::Float64,
    control_cost::Float64,
    control_effect::Float64,
    ce_threshold::Float64 = DEFAULT_ICER_THRESHOLD,
    metadata::Dict{String, Any} = Dict()
)::CostEffectivenessResult
    
    cost_diff = intervention_cost - control_cost
    effect_diff = intervention_effect - control_effect
    
    # Check for dominance
    if effect_diff < 0 && cost_diff > 0
        # Dominated: worse effect AND higher cost
        return CostEffectivenessResult(
            Inf, cost_diff, effect_diff, -Inf, false, true, false, ce_threshold, metadata
        )
    elseif effect_diff < 0 && cost_diff < 0
        # Extended dominance: need to check slope vs others
        return CostEffectivenessResult(
            -Inf, cost_diff, effect_diff, Inf, false, false, true, ce_threshold, metadata
        )
    elseif effect_diff ≈ 0
        # No effect difference
        if cost_diff < 0
            return CostEffectivenessResult(
                -Inf, cost_diff, 0.0, -cost_diff, true, false, false, ce_threshold, metadata
            )
        else
            return CostEffectivenessResult(
                Inf, cost_diff, 0.0, -cost_diff, false, true, false, ce_threshold, metadata
            )
        end
    end
    
    # Normal calculation
    icer = cost_diff / effect_diff
    
    # Cost-effectiveness judgment
    cost_effective = (icer >= 0 && icer <= ce_threshold) || (icer < 0)  # < 0 = cost-saving
    
    # NMB calculation
    incremental_nmb = (effect_diff * ce_threshold) - cost_diff
    
    CostEffectivenessResult(
        icer, cost_diff, effect_diff, incremental_nmb,
        cost_effective, false, false, ce_threshold, metadata
    )
end

"""
    calculate_nce(cost::Float64, effect::Float64)::Float64

Calculate Net Cost-Effectiveness (average rather than incremental).

Useful for first assessment of a single intervention.
"""
function calculate_nce(cost::Float64, effect::Float64)::Float64
    if effect ≈ 0
        return Inf
    end
    return cost / effect
end

"""
    calculate_incremental_cost(intervention::Vector{Float64}, 
                             control::Vector{Float64})::Tuple{Float64, Float64}

Calculate mean incremental cost with 95% CI.

Returns: (mean_cost_diff, std_error)
"""
function calculate_incremental_cost(intervention::Vector{Float64}, 
                                   control::Vector{Float64})::Tuple{Float64, Float64}
    @assert length(intervention) == length(control)
    
    cost_diffs = intervention .- control
    mean_diff = mean(cost_diffs)
    se_diff = std(cost_diffs) / sqrt(length(cost_diffs))
    
    return (mean_diff, se_diff)
end

"""
    calculate_incremental_effect(intervention::Vector{Float64}, 
                                control::Vector{Float64})::Tuple{Float64, Float64}

Calculate mean incremental effect (e.g., QALY gain) with 95% CI.

Returns: (mean_effect_diff, std_error)
"""
function calculate_incremental_effect(intervention::Vector{Float64}, 
                                     control::Vector{Float64})::Tuple{Float64, Float64}
    @assert length(intervention) == length(control)
    
    effect_diffs = intervention .- control
    mean_diff = mean(effect_diffs)
    se_diff = std(effect_diffs) / sqrt(length(effect_diffs))
    
    return (mean_diff, se_diff)
end

# ═══════════════════════════════════════════════════════════════
# PROBABILISTIC SENSITIVITY ANALYSIS (PSA)
# ═══════════════════════════════════════════════════════════════

"""
    cost_effectiveness_analysis(;
        intervention_costs::Vector{Float64},
        intervention_effects::Vector{Float64},
        control_costs::Vector{Float64},
        control_effects::Vector{Float64},
        ce_threshold::Float64 = DEFAULT_ICER_THRESHOLD
    )::Vector{CostEffectivenessResult}

Run cost-effectiveness analysis on Monte Carlo samples (PSA).
"""
function cost_effectiveness_analysis(;
    intervention_costs::Vector{Float64},
    intervention_effects::Vector{Float64},
    control_costs::Vector{Float64},
    control_effects::Vector{Float64},
    ce_threshold::Float64 = DEFAULT_ICER_THRESHOLD
)::Vector{CostEffectivenessResult}
    
    @assert length(intervention_costs) == length(intervention_effects)
    @assert length(control_costs) == length(control_effects)
    @assert length(intervention_costs) == length(control_costs)
    
    results = CostEffectivenessResult[]
    
    for i in 1:length(intervention_costs)
        result = calculate_icer(
            intervention_cost = intervention_costs[i],
            intervention_effect = intervention_effects[i],
            control_cost = control_costs[i],
            control_effect = control_effects[i],
            ce_threshold = ce_threshold
        )
        push!(results, result)
    end
    
    return results
end

"""
    build_ceac(ce_results::Vector{CostEffectivenessResult},
              wtp_range::Vector{Float64})::Dict{Float64, Float64}

Build Cost-Effectiveness Acceptability Curve (CEAC).

CEAC shows probability intervention is cost-effective at each WTP threshold.
"""
function build_ceac(ce_results::Vector{CostEffectivenessResult},
                   wtp_range::Vector{Float64} = DEFAULT_WILLINGNESS_TO_PAY)::Dict{Float64, Float64}
    
    ceac = Dict{Float64, Float64}()
    
    for wtp in wtp_range
        # Recalculate with new threshold
        reeval = [
            calculate_icer(
                intervention_cost = r.cost_difference + control_cost,
                intervention_effect = r.effect_difference + control_effect,
                control_cost = control_cost,
                control_effect = control_effect,
                ce_threshold = wtp
            ) for (r, control_cost, control_effect) in 
            zip(ce_results, 30_000, 1.0)  # simplified placeholder
        ]
        
        # Probability of cost-effectiveness
        prob_ce = sum(r.cost_effective for r in reeval) / length(reeval)
        ceac[wtp] = prob_ce
    end
    
    return ceac
end

# ═══════════════════════════════════════════════════════════════
# DECISION RULES
# ═══════════════════════════════════════════════════════════════

"""
    recommend_intervention(result::CostEffectivenessResult)::String

Provide recommendation based on cost-effectiveness result.
"""
function recommend_intervention(result::CostEffectivenessResult)::String
    if result.dominated
        return "REJECT: Intervention is dominated (worse effect, higher cost)"
    elseif result.extended_dominance
        return "CONSIDER: Intervention is on extended dominance frontier"
    elseif result.cost_effective
        if result.cost_difference < 0
            return "RECOMMEND: Intervention is cost-saving"
        else
            return "RECOMMEND: Intervention is cost-effective (ICER = USD" * 
                   string(round(Int, result.icer)) * " per unit effect)"
        end
    else
        return "REJECT: Intervention exceeds cost-effectiveness threshold (ICER = USD" *
               string(round(Int, result.icer)) * " per unit effect)"
    end
end
