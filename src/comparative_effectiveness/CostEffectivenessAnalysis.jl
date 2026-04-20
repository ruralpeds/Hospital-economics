# ============================================================================
# COST-EFFECTIVENESS ANALYSIS (Module 6)
# ============================================================================
# Framework for comparing healthcare interventions using ICER, NMB, and CEP

using Statistics

# ============================================================================
# COST-EFFECTIVENESS TYPES
# ============================================================================

"""
    CostEffectivenessResult

Result of comparing two strategies on cost and effectiveness dimensions.

# Fields
- strategy_name::String: Name of the intervention being analyzed
- comparator_name::String: Name of the baseline/comparator
- incremental_cost::Float64: Cost difference (strategy - comparator)
- incremental_effectiveness::Float64: Effectiveness difference (strategy - comparator)
- icer::Float64: Incremental Cost-Effectiveness Ratio (cost per unit effectiveness)
- quality_adjusted_life_years::Float64: QALYs gained
- icer_per_qaly::Float64: Cost per QALY gained
- net_monetary_benefit::Float64: NMB at willingness-to-pay threshold
- dominance_status::String: "Dominant", "Dominated", "Incremental", "Dominated Ext."
- cost_effectiveness::Bool: Meets threshold (default: ICER < \$100K/QALY)
"""
struct CostEffectivenessResult
    strategy_name::String
    comparator_name::String

    incremental_cost::Float64
    incremental_effectiveness::Float64
    icer::Float64

    quality_adjusted_life_years::Float64
    icer_per_qaly::Float64
    net_monetary_benefit::Float64

    dominance_status::String
    cost_effectiveness::Bool
end

"""
    CostEffectivenessPlane

Data for plotting cost-effectiveness plane (Delta C vs Delta E)

# Fields
- incremental_costs::Vector{Float64}: Distribution of incremental costs
- incremental_effects::Vector{Float64}: Distribution of incremental effects
- wtp_threshold::Float64: Willingness-to-pay per unit effectiveness
- ceac_values::Vector{Float64}: CEAC probability at each WTP
- wtp_range::Vector{Float64}: WTP values tested (0 to max)
"""
struct CostEffectivenessPlane
    incremental_costs::Vector{Float64}
    incremental_effects::Vector{Float64}
    wtp_threshold::Float64
    ceac_values::Vector{Float64}
    wtp_range::Vector{Float64}
end

"""
    ThresholdAnalysis

Break-even analysis results identifying WTP threshold where strategies are equivalent

# Fields
- break_even_wtp::Float64: WTP where NMB = 0
- strategy_preferred_below::String: Strategy preferred if WTP < break_even
- strategy_preferred_above::String: Strategy preferred if WTP > break_even
- cost_saving::Float64: Cost savings if cost-decreasing, lower-effective
- effectiveness_gained::Float64: Effectiveness gain if cost-increasing, higher-effective
"""
struct ThresholdAnalysis
    break_even_wtp::Float64
    strategy_preferred_below::String
    strategy_preferred_above::String
    cost_saving::Float64
    effectiveness_gained::Float64
end

# ============================================================================
# CORE FUNCTIONS
# ============================================================================

"""
    calculate_icer(
        cost_intervention::Float64,
        cost_comparator::Float64,
        effect_intervention::Float64,
        effect_comparator::Float64
    )::Float64

Calculate Incremental Cost-Effectiveness Ratio.

ICER = (Cost_intervention - Cost_comparator) / (Effect_intervention - Effect_comparator)

# Arguments
- cost_intervention::Float64: Total cost of intervention
- cost_comparator::Float64: Total cost of comparator/baseline
- effect_intervention::Float64: Effectiveness of intervention (QALYs, life-years, etc.)
- effect_comparator::Float64: Effectiveness of comparator

# Returns
ICER in units of cost per unit effectiveness (e.g., \$/QALY)
Returns Inf if no effectiveness difference (denominator = 0)
"""
function calculate_icer(
    cost_intervention::Float64,
    cost_comparator::Float64,
    effect_intervention::Float64,
    effect_comparator::Float64
)::Float64
    delta_cost = cost_intervention - cost_comparator
    delta_effect = effect_intervention - effect_comparator

    if abs(delta_effect) < 1e-10
        return Inf
    end

    return delta_cost / delta_effect
end

"""
    calculate_net_monetary_benefit(
        cost_intervention::Float64,
        cost_comparator::Float64,
        effect_intervention::Float64,
        effect_comparator::Float64,
        wtp_threshold::Float64
    )::Float64

Calculate Net Monetary Benefit (NMB).

NMB = (Effect_intervention × WTP) - Cost_intervention -
      ((Effect_comparator × WTP) - Cost_comparator)
    = ΔEffect × WTP - ΔCost

# Arguments
- cost_intervention::Float64: Total cost of intervention
- cost_comparator::Float64: Total cost of comparator
- effect_intervention::Float64: Effectiveness of intervention
- effect_comparator::Float64: Effectiveness of comparator
- wtp_threshold::Float64: Willingness-to-pay per unit effectiveness

# Returns
NMB in monetary units. Positive = intervention is cost-effective at threshold
"""
function calculate_net_monetary_benefit(
    cost_intervention::Float64,
    cost_comparator::Float64,
    effect_intervention::Float64,
    effect_comparator::Float64,
    wtp_threshold::Float64
)::Float64
    delta_cost = cost_intervention - cost_comparator
    delta_effect = effect_intervention - effect_comparator

    nmb = (delta_effect * wtp_threshold) - delta_cost
    return nmb
end

"""
    classify_dominance(
        cost_intervention::Float64,
        cost_comparator::Float64,
        effect_intervention::Float64,
        effect_comparator::Float64
    )::String

Classify strategy as dominant, dominated, or incremental based on costs and effects.

# Dominance Definitions
- **Dominant**: Lower cost AND higher effectiveness
- **Dominated**: Higher cost AND lower effectiveness
- **Dominated (Extended)**: Higher cost AND equal/lower effectiveness
- **Incremental**: Higher cost with higher effectiveness OR lower cost with lower effectiveness

# Returns
Dominance classification string
"""
function classify_dominance(
    cost_intervention::Float64,
    cost_comparator::Float64,
    effect_intervention::Float64,
    effect_comparator::Float64
)::String
    delta_cost = cost_intervention - cost_comparator
    delta_effect = effect_intervention - effect_comparator

    cost_lower = delta_cost < -1e-6
    cost_higher = delta_cost > 1e-6
    effect_higher = delta_effect > 1e-6
    effect_lower = delta_effect < -1e-6

    if cost_lower && effect_higher
        return "Dominant"
    elseif cost_higher && effect_lower
        return "Dominated"
    elseif cost_higher && abs(delta_effect) < 1e-6
        return "Dominated (Extended)"
    else
        return "Incremental"
    end
end

"""
    analyze_cost_effectiveness(
        strategy_result::ThreeYearContractAnalysis,
        comparator_result::ThreeYearContractAnalysis,
        qalys_strategy::Float64,
        qalys_comparator::Float64;
        wtp_threshold::Float64 = 100_000.0
    )::CostEffectivenessResult

Comprehensive cost-effectiveness analysis comparing two contract strategies.

# Arguments
- strategy_result::ThreeYearContractAnalysis: Financial analysis of intervention
- comparator_result::ThreeYearContractAnalysis: Financial analysis of baseline
- qalys_strategy::Float64: Quality-adjusted life years for strategy
- qalys_comparator::Float64: Quality-adjusted life years for comparator
- wtp_threshold::Float64: Willingness-to-pay per QALY (default: \$100,000)

# Returns
CostEffectivenessResult with full analysis
"""
function analyze_cost_effectiveness(
    strategy_result::ThreeYearContractAnalysis,
    comparator_result::ThreeYearContractAnalysis,
    qalys_strategy::Float64,
    qalys_comparator::Float64;
    wtp_threshold::Float64 = 100_000.0
)::CostEffectivenessResult

    # Calculate 3-year costs (hospital perspective)
    cost_strategy = (
        strategy_result.year1.hospital_costs +
        strategy_result.year2.hospital_costs +
        strategy_result.year3.hospital_costs
    )

    cost_comparator = (
        comparator_result.year1.hospital_costs +
        comparator_result.year2.hospital_costs +
        comparator_result.year3.hospital_costs
    )

    # Calculate ICER
    icer = calculate_icer(cost_strategy, cost_comparator, qalys_strategy, qalys_comparator)

    # Calculate NMB
    nmb = calculate_net_monetary_benefit(
        cost_strategy, cost_comparator,
        qalys_strategy, qalys_comparator,
        wtp_threshold
    )

    # Determine dominance
    dominance = classify_dominance(cost_strategy, cost_comparator, qalys_strategy, qalys_comparator)

    # Cost-effectiveness determination
    is_cost_effective = (icer < wtp_threshold) || (dominance == "Dominant")

    return CostEffectivenessResult(
        strategy_result.contract_name,
        comparator_result.contract_name,
        cost_strategy - cost_comparator,
        qalys_strategy - qalys_comparator,
        icer,
        qalys_strategy - qalys_comparator,
        icer,
        nmb,
        dominance,
        is_cost_effective
    )
end

# ============================================================================
# FORMATTING & REPORTING
# ============================================================================

"""
    format_cost_effectiveness_result(result::CostEffectivenessResult)::String

Format CE result as human-readable report.
"""
function format_cost_effectiveness_result(result::CostEffectivenessResult)::String
    io = IOBuffer()

    println(io, "╔════════════════════════════════════════════════════════════════════╗")
    println(io, "║            COST-EFFECTIVENESS ANALYSIS RESULT                      ║")
    println(io, "╚════════════════════════════════════════════════════════════════════╝")
    println(io, "")

    println(io, "Strategy:                $(result.strategy_name)")
    println(io, "Comparator:              $(result.comparator_name)")
    println(io, "")

    println(io, "──── INCREMENTAL ANALYSIS ──────────────────────────────────────────")
    println(io, "Incremental Cost:        \$$(format_currency(result.incremental_cost))")
    println(io, "Incremental QALYs:       $(round(result.quality_adjusted_life_years, digits=2))")
    println(io, "ICER (per QALY):         \$$(format_currency(result.icer_per_qaly))")
    println(io, "")

    println(io, "──── DECISION ANALYSIS ─────────────────────────────────────────────")
    println(io, "Dominance Status:        $(result.dominance_status)")
    println(io, "Net Monetary Benefit:    \$$(format_currency(result.net_monetary_benefit))")
    println(io, "Cost-Effective:          $(result.cost_effectiveness ? "YES (< \$100K/QALY)" : "NO")")
    println(io, "")

    return String(take!(io))
end

function format_currency(value::Float64)::String
    if abs(value) >= 1_000_000
        return "$(round(value/1_000_000, digits=1))M"
    elseif abs(value) >= 1_000
        return "$(round(value/1_000, digits=0))K"
    else
        return "$(round(value, digits=0))"
    end
end
