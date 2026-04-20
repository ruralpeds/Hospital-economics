# ============================================================================
# THRESHOLD ANALYSIS (Module 6)
# ============================================================================
# Break-even analysis and willingness-to-pay threshold analysis

# ============================================================================
# THRESHOLD ANALYSIS TYPES
# ============================================================================

"""
    BreakEvenAnalysis

Result of break-even analysis identifying critical parameter values.

# Fields
- decision_parameter::String: The variable being solved for
- break_even_value::Float64: Parameter value where strategies are equivalent
- strategy_preferred_below::String: Preferred strategy if parameter < break_even
- strategy_preferred_above::String: Preferred strategy if parameter > break_even
- current_value::Float64: Current actual parameter value
- sensitivity_range::Tuple{Float64, Float64}: Min/max plausible range
- is_current_acceptable::Bool: Is current value acceptable (not at break-even)?
"""
struct BreakEvenAnalysis
    decision_parameter::String
    break_even_value::Float64
    strategy_preferred_below::String
    strategy_preferred_above::String
    current_value::Float64
    sensitivity_range::Tuple{Float64, Float64}
    is_current_acceptable::Bool
end

"""
    WTPThreshold

Willingness-to-pay threshold analysis identifying acceptable WTP ranges.

# Fields
- strategy_name::String: Name of intervention strategy
- icer::Float64: Incremental Cost-Effectiveness Ratio
- conventional_threshold::Float64: Typical CE threshold (\$100K/QALY)
- acceptable_below::Bool: Strategy acceptable if WTP < ICER
- acceptable_above::Bool: Strategy acceptable if WTP > ICER
- recommendation::String: Strategic recommendation based on thresholds
"""
struct WTPThreshold
    strategy_name::String
    icer::Float64
    conventional_threshold::Float64
    acceptable_below::Bool
    acceptable_above::Bool
    recommendation::String
end

"""
    EffectivenessMilepost

Identify milestones of effectiveness gain (incremental improvements).

# Fields
- effectiveness_level::Float64: Target effectiveness level (e.g., QALYs)
- cost_at_level::Float64: Cost to achieve this level
- cost_per_unit::Float64: Average cost per unit effectiveness
- cumulative_cost::Float64: Total cost from baseline
- cumulative_effectiveness::Float64: Total effectiveness from baseline
"""
struct EffectivenessMilepost
    effectiveness_level::Float64
    cost_at_level::Float64
    cost_per_unit::Float64
    cumulative_cost::Float64
    cumulative_effectiveness::Float64
end

# ============================================================================
# BREAK-EVEN ANALYSIS
# ============================================================================

"""
    calculate_break_even_wtp(
        delta_cost::Float64,
        delta_effect::Float64
    )::Float64

Calculate break-even WTP threshold (where NMB = 0).

At break-even: delta_effect × WTP_breakeven = delta_cost
Therefore: WTP_breakeven = delta_cost / delta_effect

# Arguments
- delta_cost::Float64: Cost difference (intervention - comparator)
- delta_effect::Float64: Effectiveness difference (intervention - comparator)

# Returns
Break-even WTP per unit effectiveness
Returns Inf if delta_effect = 0
"""
function calculate_break_even_wtp(
    delta_cost::Float64,
    delta_effect::Float64
)::Float64
    if abs(delta_effect) < 1e-10
        return Inf
    end
    return delta_cost / delta_effect
end

"""
    analyze_break_even(
        delta_cost::Float64,
        delta_effect::Float64,
        strategy_name::String,
        comparator_name::String
    )::BreakEvenAnalysis

Analyze break-even points for cost-effectiveness decision.

# Arguments
- delta_cost::Float64: Cost difference (intervention - comparator)
- delta_effect::Float64: Effectiveness difference (intervention - comparator)
- strategy_name::String: Name of intervention
- comparator_name::String: Name of baseline

# Returns
BreakEvenAnalysis with interpretation
"""
function analyze_break_even(
    delta_cost::Float64,
    delta_effect::Float64,
    strategy_name::String,
    comparator_name::String
)::BreakEvenAnalysis

    breakeven_wtp = calculate_break_even_wtp(delta_cost, delta_effect)

    # Determine preference by sign of delta_cost and delta_effect
    conventional_threshold = 100_000.0

    if delta_cost < 0 && delta_effect > 0
        # Dominant: lower cost, higher effectiveness
        preferred_below = strategy_name
        preferred_above = strategy_name
        is_acceptable = true
    elseif delta_cost > 0 && delta_effect < 0
        # Dominated: higher cost, lower effectiveness
        preferred_below = comparator_name
        preferred_above = comparator_name
        is_acceptable = false
    elseif delta_cost > 0 && delta_effect > 0
        # Incremental: higher cost, higher effectiveness
        preferred_below = comparator_name
        preferred_above = strategy_name
        is_acceptable = breakeven_wtp <= conventional_threshold
    else
        # Cost-saving but less effective
        preferred_below = strategy_name
        preferred_above = comparator_name
        is_acceptable = breakeven_wtp >= conventional_threshold
    end

    return BreakEvenAnalysis(
        "Willingness-to-pay threshold",
        breakeven_wtp,
        preferred_below,
        preferred_above,
        conventional_threshold,
        (50_000.0, 150_000.0),
        is_acceptable
    )
end

# ============================================================================
# WILLINGNESS-TO-PAY ANALYSIS
# ============================================================================

"""
    evaluate_at_wtp_threshold(
        icer::Float64,
        strategy_name::String;
        threshold::Float64 = 100_000.0
    )::WTPThreshold

Evaluate cost-effectiveness at a specific WTP threshold.

# Arguments
- icer::Float64: Incremental Cost-Effectiveness Ratio
- strategy_name::String: Name of strategy
- threshold::Float64: WTP threshold for acceptability (default \$100K/QALY)

# Returns
WTPThreshold with decision recommendation
"""
function evaluate_at_wtp_threshold(
    icer::Float64,
    strategy_name::String;
    threshold::Float64 = 100_000.0
)::WTPThreshold

    acceptable_below = icer > threshold  # Below threshold, comparator preferred
    acceptable_above = icer < threshold  # Above threshold, strategy preferred

    # Generate recommendation
    if isinf(icer) || isnan(icer)
        recommendation = "Unable to calculate (dominance situation)"
    elseif icer < 0
        recommendation = "Dominant: lower cost AND higher effectiveness"
    elseif icer < threshold * 0.5
        recommendation = "Strongly preferred: low incremental cost"
    elseif icer < threshold
        recommendation = "Preferred: cost-effective at \$$(threshold/1000)K/QALY"
    elseif icer < threshold * 2
        recommendation = "Borderline: expensive but may be acceptable"
    else
        recommendation = "Not recommended: exceeds acceptable cost-effectiveness"
    end

    return WTPThreshold(
        strategy_name,
        icer,
        threshold,
        acceptable_below,
        acceptable_above,
        recommendation
    )
end

"""
    find_optimal_wtp(
        strategy_icers::Dict{String, Float64}
    )::Dict{String, Union{String, Float64}}

Identify optimal strategy at different WTP levels.

# Arguments
- strategy_icers::Dict{String, Float64}: Strategy name → ICER mapping

# Returns
Dict with:
- "dominant" => strategy name (if one dominates)
- "low_wtp_preferred" => strategy name (preferred at low WTP)
- "high_wtp_preferred" => strategy name (preferred at high WTP)
- "inflection_point" => WTP where preference changes
"""
function find_optimal_wtp(
    strategy_icers::Dict{String, Float64}
)::Dict{String, Union{String, Float64}}

    # Find dominant strategy (negative ICER)
    dominant = filter(p -> p[2] < 0, strategy_icers)
    if !isempty(dominant)
        return Dict("dominant" => first(dominant).first)
    end

    # Sort strategies by ICER
    sorted = sort(strategy_icers, by=x -> x[2])

    results = Dict{String, Union{String, Float64}}()

    # Low WTP preference
    if !isempty(sorted)
        results["low_wtp_preferred"] = first(sorted).first
        results["low_wtp_icer"] = first(sorted).second
    end

    # High WTP preference (lowest ICER, most cost-effective)
    if length(sorted) > 1
        results["high_wtp_preferred"] = sorted[1].first
        results["high_wtp_icer"] = sorted[1].second
    end

    return results
end

# ============================================================================
# EFFECTIVENESS MILEPOSTS
# ============================================================================

"""
    analyze_effectiveness_trajectory(
        incremental_costs::Vector{Float64},
        incremental_effects::Vector{Float64}
    )::Vector{EffectivenessMilepost}

Analyze progression of cost-effectiveness at different effectiveness levels.

Used to identify "sweet spots" or milestones of value.

# Arguments
- incremental_costs::Vector{Float64}: Costs at each stage
- incremental_effects::Vector{Float64}: Effectiveness at each stage

# Returns
Vector of EffectivenessMilepost from baseline to maximum
"""
function analyze_effectiveness_trajectory(
    incremental_costs::Vector{Float64},
    incremental_effects::Vector{Float64}
)::Vector{EffectivenessMilepost}

    if length(incremental_costs) != length(incremental_effects)
        error("Cost and effect vectors must have same length")
    end

    mileposts = EffectivenessMilepost[]

    cumulative_cost = 0.0
    cumulative_effect = 0.0

    for i in 1:length(incremental_costs)
        cumulative_cost += incremental_costs[i]
        cumulative_effect += incremental_effects[i]

        cost_per_unit = if abs(cumulative_effect) > 1e-10
            cumulative_cost / cumulative_effect
        else
            Inf
        end

        milepost = EffectivenessMilepost(
            cumulative_effect,
            incremental_costs[i],
            cost_per_unit,
            cumulative_cost,
            cumulative_effect
        )

        push!(mileposts, milepost)
    end

    return mileposts
end

# ============================================================================
# COST-EFFECTIVENESS ACCEPTABILITY CURVE (CEAC)
# ============================================================================

"""
    calculate_ceac(
        delta_costs::Vector{Float64},
        delta_effects::Vector{Float64},
        wtp_range::Vector{Float64}
    )::Vector{Float64}

Calculate Cost-Effectiveness Acceptability Curve.

CEAC probability at each WTP = proportion of samples where NMB > 0
NMB = Effect × WTP - Cost

# Arguments
- delta_costs::Vector{Float64}: Sampled cost differences
- delta_effects::Vector{Float64}: Sampled effect differences
- wtp_range::Vector{Float64}: WTP values to evaluate

# Returns
Vector of probabilities (0-1) that strategy is CE at each WTP
"""
function calculate_ceac(
    delta_costs::Vector{Float64},
    delta_effects::Vector{Float64},
    wtp_range::Vector{Float64}
)::Vector{Float64}

    ceac_values = Float64[]

    for wtp in wtp_range
        # Count how many samples have NMB > 0
        ce_count = sum(
            (delta_effects[i] * wtp - delta_costs[i]) > 0
            for i in 1:length(delta_costs)
        )

        probability = ce_count / length(delta_costs)
        push!(ceac_values, probability)
    end

    return ceac_values
end

"""
    find_ceac_crossover(
        ceac_values::Vector{Float64},
        wtp_range::Vector{Float64}
    )::Union{Float64, Nothing}

Find WTP where CEAC crosses 50% (most likely strategy switches).

# Returns
WTP value at crossover, or Nothing if no clear crossover
"""
function find_ceac_crossover(
    ceac_values::Vector{Float64},
    wtp_range::Vector{Float64}
)::Union{Float64, Nothing}

    for i in 1:(length(ceac_values)-1)
        if (ceac_values[i] - 0.5) * (ceac_values[i+1] - 0.5) < 0
            # Linear interpolation
            return wtp_range[i]
        end
    end

    return nothing
end

# ============================================================================
# THRESHOLD REPORTING
# ============================================================================

"""
    format_threshold_analysis(analysis::BreakEvenAnalysis)::String

Format break-even analysis as human-readable report.
"""
function format_threshold_analysis(analysis::BreakEvenAnalysis)::String
    io = IOBuffer()

    println(io, "╔════════════════════════════════════════════════════════════════════╗")
    println(io, "║                  THRESHOLD ANALYSIS REPORT                         ║")
    println(io, "╚════════════════════════════════════════════════════════════════════╝")
    println(io, "")

    println(io, "Parameter:               $(analysis.decision_parameter)")
    println(io, "Break-even Value:        \$$(format_currency(analysis.break_even_value))/QALY")
    println(io, "Current Value:           \$$(format_currency(analysis.current_value))/QALY")
    println(io, "")

    println(io, "──── DECISION RULE ─────────────────────────────────────────────────")
    println(io, "If WTP < \$$(format_currency(analysis.break_even_value))")
    println(io, "  → Prefer: $(analysis.strategy_preferred_below)")
    println(io, "")
    println(io, "If WTP > \$$(format_currency(analysis.break_even_value))")
    println(io, "  → Prefer: $(analysis.strategy_preferred_above)")
    println(io, "")

    println(io, "Current Acceptability:   $(analysis.is_current_acceptable ? "✓ ACCEPTABLE" : "✗ NOT ACCEPTABLE")")
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
