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

# ─────────────────────────────────────────────────────────────────────────────
# T-027: ICER Sensitivity Analysis Framework
# ─────────────────────────────────────────────────────────────────────────────

"""
    ICERParameter

A named parameter with a range for sensitivity analysis.

# Fields
- `name::Symbol`: Parameter identifier (must match a keyword accepted by `calculate_icer`).
- `base_value::Float64`: Central-case value.
- `low_value::Float64`: Pessimistic / low bound.
- `high_value::Float64`: Optimistic / high bound.
- `label::String`: Display label for tornado charts.
"""
@kwdef struct ICERParameter
    name::Symbol
    base_value::Float64
    low_value::Float64
    high_value::Float64
    label::String = string(name)
end

"""
    ICERSensitivityResult

Output of one-way ICER sensitivity analysis for a single parameter.

# Fields
- `param::ICERParameter`
- `icer_base::Float64`: ICER at base value.
- `icer_low::Float64`: ICER at `param.low_value`.
- `icer_high::Float64`: ICER at `param.high_value`.
- `delta_low::Float64`: `icer_low - icer_base` (signed).
- `delta_high::Float64`: `icer_high - icer_base` (signed).
- `absolute_swing::Float64`: `abs(icer_high - icer_low)` — used for tornado ranking.
"""
struct ICERSensitivityResult
    param::ICERParameter
    icer_base::Float64
    icer_low::Float64
    icer_high::Float64
    delta_low::Float64
    delta_high::Float64
    absolute_swing::Float64
end

"""
    ICERTornadoData

Complete tornado-plot dataset for a set of ICER sensitivity results.

# Fields
- `base_icer::Float64`: Central-case ICER.
- `wtp_threshold::Float64`: WTP threshold line (default \$100,000/QALY).
- `rows::Vector{ICERSensitivityResult}`: Results sorted by `absolute_swing` descending.
"""
struct ICERTornadoData
    base_icer::Float64
    wtp_threshold::Float64
    rows::Vector{ICERSensitivityResult}
end

"""
    icer_one_way_sensitivity(
        cost_intervention, cost_comparator,
        effect_intervention, effect_comparator,
        parameters;
        wtp_threshold
    ) -> ICERTornadoData

Run one-way sensitivity analysis on a set of ICER parameters. For each
parameter, the ICER is recomputed holding all other parameters at their base
values while sweeping the focal parameter from `low_value` to `high_value`.

# Arguments
- `cost_intervention`, `cost_comparator`: Base-case costs.
- `effect_intervention`, `effect_comparator`: Base-case effects (e.g. QALYs).
- `parameters::Vector{ICERParameter}`: Parameters to vary.
- `wtp_threshold::Float64 = 100_000.0`: Cost-effectiveness threshold line.

# Returns
`ICERTornadoData` with rows sorted by `absolute_swing` (largest first) —
ready for direct tornado plotting.

# Example
```julia
params = [
    ICERParameter(name=:cost_intervention, base_value=50_000, low_value=40_000, high_value=65_000, label="Intervention cost"),
    ICERParameter(name=:effect_intervention, base_value=0.85, low_value=0.70, high_value=0.95, label="Treatment efficacy (QALY)"),
]
tornado = icer_one_way_sensitivity(50_000, 20_000, 0.85, 0.60, params)
tornado.base_icer        # central ICER
tornado.rows[1].absolute_swing  # largest driver
```
"""
function icer_one_way_sensitivity(
    cost_intervention::Float64,
    cost_comparator::Float64,
    effect_intervention::Float64,
    effect_comparator::Float64,
    parameters::Vector{ICERParameter};
    wtp_threshold::Float64 = 100_000.0,
)::ICERTornadoData

    base_icer = calculate_icer(;
        cost_intervention, cost_comparator,
        effect_intervention, effect_comparator,
    ).icer

    results = ICERSensitivityResult[]

    for param in parameters
        # Build named-tuple overrides for low and high
        function _icer_at(val::Float64)::Float64
            c_int = param.name == :cost_intervention  ? val : cost_intervention
            c_cmp = param.name == :cost_comparator    ? val : cost_comparator
            e_int = param.name == :effect_intervention ? val : effect_intervention
            e_cmp = param.name == :effect_comparator  ? val : effect_comparator
            calculate_icer(;
                cost_intervention=c_int, cost_comparator=c_cmp,
                effect_intervention=e_int, effect_comparator=e_cmp,
            ).icer
        end

        icer_low  = _icer_at(param.low_value)
        icer_high = _icer_at(param.high_value)

        push!(results, ICERSensitivityResult(
            param,
            base_icer,
            icer_low,
            icer_high,
            icer_low  - base_icer,
            icer_high - base_icer,
            abs(icer_high - icer_low),
        ))
    end

    # Sort by absolute swing descending (tornado order)
    sort!(results; by = r -> r.absolute_swing, rev = true)

    ICERTornadoData(base_icer, wtp_threshold, results)
end

"""
    icer_probabilistic_sensitivity(
        cost_fn, effect_fn, n_samples;
        wtp_threshold, rng_seed
    ) -> NamedTuple

Probabilistic sensitivity analysis (PSA) for ICER. Calls user-supplied
functions to sample costs and effects, then computes the CEAC (cost-
effectiveness acceptability curve) across WTP thresholds.

# Arguments
- `cost_fn()`: Zero-argument function returning `(cost_intervention, cost_comparator)`.
- `effect_fn()`: Zero-argument function returning `(effect_intervention, effect_comparator)`.
- `n_samples::Int = 1_000`: PSA iterations.
- `wtp_threshold::Float64 = 100_000.0`: Primary WTP threshold.
- `rng_seed::Int = 42`

# Returns
NamedTuple with:
- `icers::Vector{Float64}`: Simulated ICERs.
- `pct_cost_effective::Float64`: Fraction of ICERs ≤ `wtp_threshold`.
- `median_icer`, `p025_icer`, `p975_icer`
- `ceac_wtp::Vector{Float64}`, `ceac_prob::Vector{Float64}`: CEAC curve data.
"""
function icer_probabilistic_sensitivity(
    cost_fn,
    effect_fn;
    n_samples::Int = 1_000,
    wtp_threshold::Float64 = 100_000.0,
    rng_seed::Int = 42,
)
    Random.seed!(rng_seed)

    icers = Float64[]
    for _ in 1:n_samples
        ci, cc = cost_fn()
        ei, ec = effect_fn()
        r = calculate_icer(; cost_intervention=ci, cost_comparator=cc,
                             effect_intervention=ei, effect_comparator=ec)
        push!(icers, r.icer)
    end

    # CEAC across WTP range 0..500k
    wtp_grid = 0.0:5_000.0:500_000.0
    ceac_prob = [mean(i <= wtp for i in icers) for wtp in wtp_grid]

    (
        icers           = icers,
        pct_cost_effective = mean(i <= wtp_threshold for i in icers),
        median_icer     = median(icers),
        p025_icer       = quantile(icers, 0.025),
        p975_icer       = quantile(icers, 0.975),
        ceac_wtp        = collect(wtp_grid),
        ceac_prob       = ceac_prob,
    )
end
