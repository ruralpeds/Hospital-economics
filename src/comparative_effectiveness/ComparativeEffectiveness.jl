# ============================================================================
# COMPARATIVE EFFECTIVENESS FRAMEWORK (Module 6)
# ============================================================================
# Integrated analysis comparing multiple contract strategies

"""
    ComparisonScenario

Comprehensive comparison of multiple contract strategies across multiple dimensions.

# Fields
- scenario_name::String: Name of comparison scenario
- contracts::Vector{ThreeYearContractAnalysis}: Contracts being compared
- ce_results::Vector{CostEffectivenessResult}: CE analysis for each contract
- optimal_strategy::String: Strategy with best NMB at conventional WTP
- ranking::Vector{String}: Strategies ranked by ICER
- recommendations::Dict{String, String}: Strategic recommendations
"""
struct ComparisonScenario
    scenario_name::String
    contracts::Vector{ThreeYearContractAnalysis}
    ce_results::Vector{CostEffectivenessResult}
    optimal_strategy::String
    ranking::Vector{String}
    recommendations::Dict{String, String}
end

"""
    StrategyProfile

Complete profile of a single contract strategy with multiple metrics.

# Fields
- strategy_name::String: Strategy name
- cost_per_case::Float64: Average cost per case
- cost_per_qaly::Float64: Cost-effectiveness ratio
- nmb_at_100k::Float64: Net monetary benefit at \$100K/QALY
- quality_score::Float64: Quality metrics achievement
- financial_margin::Float64: Hospital margin
- payer_savings::Float64: Payer savings vs baseline
- dominance_status::String: "Dominant", "Dominated", "Incremental"
"""
struct StrategyProfile
    strategy_name::String
    cost_per_case::Float64
    cost_per_qaly::Float64
    nmb_at_100k::Float64
    quality_score::Float64
    financial_margin::Float64
    payer_savings::Float64
    dominance_status::String
end

# ============================================================================
# COMPREHENSIVE COMPARISON
# ============================================================================

"""
    compare_strategies(
        strategies::Vector{ThreeYearContractAnalysis},
        baseline_strategy::Union{String, Int},
        qalys::Vector{Float64};
        wtp_threshold::Float64 = 100_000.0
    )::ComparisonScenario

Comprehensive comparison of multiple contract strategies.

# Arguments
- strategies::Vector{ThreeYearContractAnalysis}: All strategies to compare
- baseline_strategy::Union{String, Int}: Name or index of baseline/comparator
- qalys::Vector{Float64}: QALYs for each strategy
- wtp_threshold::Float64: Cost-effectiveness threshold

# Returns
ComparisonScenario with full comparative analysis
"""
function compare_strategies(
    strategies::Vector{ThreeYearContractAnalysis},
    baseline_strategy::Union{String, Int},
    qalys::Vector{Float64};
    wtp_threshold::Float64 = 100_000.0
)::ComparisonScenario

    # Find baseline
    baseline_idx = isa(baseline_strategy, Int) ? baseline_strategy : findfirst(
        s -> s.contract_name == baseline_strategy, strategies
    )

    if isnothing(baseline_idx)
        error("Baseline strategy not found")
    end

    baseline = strategies[baseline_idx]
    baseline_qaly = qalys[baseline_idx]

    # Analyze each strategy vs baseline
    ce_results = CostEffectivenessResult[]

    for i in 1:length(strategies)
        if i != baseline_idx
            result = analyze_cost_effectiveness(
                strategies[i],
                baseline,
                qalys[i],
                baseline_qaly;
                wtp_threshold = wtp_threshold
            )
            push!(ce_results, result)
        end
    end

    # Rank strategies by ICER
    ranking = rank_strategies_by_icer(ce_results)

    # Identify optimal strategy
    optimal = find_optimal_strategy(ce_results, wtp_threshold)

    # Generate recommendations
    recommendations = generate_strategic_recommendations(ce_results, strategies, baseline_idx)

    return ComparisonScenario(
        "Strategy Comparison",
        strategies,
        ce_results,
        optimal,
        ranking,
        recommendations
    )
end

"""
    rank_strategies_by_icer(ce_results::Vector{CostEffectivenessResult})::Vector{String}

Rank strategies from most to least cost-effective (lowest to highest ICER).
"""
function rank_strategies_by_icer(ce_results::Vector{CostEffectivenessResult})::Vector{String}
    # Sort by ICER (handle dominant strategies with negative ICER)
    sorted = sort(ce_results, by=x -> isinf(x.icer_per_qaly) ? Inf : x.icer_per_qaly)
    return [result.strategy_name for result in sorted]
end

"""
    find_optimal_strategy(
        ce_results::Vector{CostEffectivenessResult},
        wtp_threshold::Float64
    )::String

Identify optimal strategy based on NMB at threshold WTP.
"""
function find_optimal_strategy(
    ce_results::Vector{CostEffectivenessResult},
    wtp_threshold::Float64
)::String
    best_strategy = ""
    best_nmb = -Inf

    for result in ce_results
        if result.net_monetary_benefit > best_nmb
            best_nmb = result.net_monetary_benefit
            best_strategy = result.strategy_name
        end
    end

    return best_strategy
end

"""
    generate_strategic_recommendations(
        ce_results::Vector{CostEffectivenessResult},
        strategies::Vector{ThreeYearContractAnalysis},
        baseline_idx::Int
    )::Dict{String, String}

Generate strategic recommendations for each strategy.
"""
function generate_strategic_recommendations(
    ce_results::Vector{CostEffectivenessResult},
    strategies::Vector{ThreeYearContractAnalysis},
    baseline_idx::Int
)::Dict{String, String}

    recommendations = Dict{String, String}()

    for result in ce_results
        recommendation = ""

        if result.dominance_status == "Dominant"
            recommendation = "STRONGLY PREFERRED: Lower costs, better outcomes"
        elseif result.dominance_status == "Dominated"
            recommendation = "NOT RECOMMENDED: Higher costs, worse outcomes"
        elseif result.cost_effectiveness
            if result.icer_per_qaly < 50_000
                recommendation = "PREFERRED: Very cost-effective"
            else
                recommendation = "ACCEPTABLE: Cost-effective at \$100K/QALY"
            end
        else
            recommendation = "NOT RECOMMENDED: Exceeds cost-effectiveness threshold"
        end

        recommendations[result.strategy_name] = recommendation
    end

    return recommendations
end

# ============================================================================
# MULTI-DIMENSIONAL PROFILE ANALYSIS
# ============================================================================

"""
    build_strategy_profiles(
        strategies::Vector{ThreeYearContractAnalysis},
        qalys::Vector{Float64};
        baseline_idx::Int = 1
    )::Vector{StrategyProfile}

Build comprehensive profiles for each strategy.

# Arguments
- strategies::Vector{ThreeYearContractAnalysis}: Strategies to profile
- qalys::Vector{Float64}: QALYs for each strategy
- baseline_idx::Int: Index of baseline for comparison

# Returns
Vector of StrategyProfile objects
"""
function build_strategy_profiles(
    strategies::Vector{ThreeYearContractAnalysis},
    qalys::Vector{Float64};
    baseline_idx::Int = 1
)::Vector{StrategyProfile}

    profiles = StrategyProfile[]

    baseline = strategies[baseline_idx]
    baseline_qaly = qalys[baseline_idx]

    for i in 1:length(strategies)
        strategy = strategies[i]

        # Calculate 3-year totals
        total_cost = (
            strategy.year1.hospital_costs +
            strategy.year2.hospital_costs +
            strategy.year3.hospital_costs
        )
        total_cases = strategy.year1.cases + strategy.year2.cases + strategy.year3.cases
        total_margin = strategy.total_hospital_margin
        payer_savings = strategy.total_payer_savings

        # Cost per case
        cost_per_case = if total_cases > 0
            total_cost / total_cases
        else
            0.0
        end

        # Calculate ICER vs baseline
        icer = if i != baseline_idx
            baseline_cost = (
                baseline.year1.hospital_costs +
                baseline.year2.hospital_costs +
                baseline.year3.hospital_costs
            )
            delta_cost = total_cost - baseline_cost
            delta_qaly = qalys[i] - baseline_qaly

            if abs(delta_qaly) > 1e-10
                delta_cost / delta_qaly
            else
                Inf
            end
        else
            0.0
        end

        # Dominance classification
        dominance = if i != baseline_idx
            classify_dominance(total_cost, (baseline.year1.hospital_costs + baseline.year2.hospital_costs + baseline.year3.hospital_costs), qalys[i], baseline_qaly)
        else
            "Baseline"
        end

        # NMB at $100K/QALY threshold
        nmb = if i != baseline_idx
            baseline_total_cost = (baseline.year1.hospital_costs + baseline.year2.hospital_costs + baseline.year3.hospital_costs)
            delta_cost = total_cost - baseline_total_cost
            delta_qaly = qalys[i] - baseline_qaly
            (delta_qaly * 100_000.0) - delta_cost
        else
            0.0
        end

        # Quality score (aggregate from contract analyses)
        quality = 0.75  # Default; would be aggregated from real quality metrics

        profile = StrategyProfile(
            strategy.contract_name,
            cost_per_case,
            icer,
            nmb,
            quality,
            total_margin,
            payer_savings,
            dominance
        )

        push!(profiles, profile)
    end

    return profiles
end

# ============================================================================
# COMPARATIVE EFFECTIVENESS REPORTING
# ============================================================================

"""
    format_comparison_summary(scenario::ComparisonScenario)::String

Format comparison as human-readable summary table.
"""
function format_comparison_summary(scenario::ComparisonScenario)::String
    io = IOBuffer()

    println(io, "╔════════════════════════════════════════════════════════════════════╗")
    println(io, "║            COMPARATIVE EFFECTIVENESS SUMMARY                       ║")
    println(io, "╚════════════════════════════════════════════════════════════════════╝")
    println(io, "")

    println(io, "Scenario: $(scenario.scenario_name)")
    println(io, "Optimal Strategy: $(scenario.optimal_strategy)")
    println(io, "")

    println(io, "──── COST-EFFECTIVENESS RANKING (by ICER) ──────────────────────────")
    for (i, strategy) in enumerate(scenario.ranking)
        println(io, "$i. $strategy")
    end
    println(io, "")

    println(io, "──── STRATEGIC RECOMMENDATIONS ──────────────────────────────────────")
    for (strategy, recommendation) in scenario.recommendations
        println(io, "• $strategy: $recommendation")
    end
    println(io, "")

    return String(take!(io))
end

"""
    format_strategy_profiles(profiles::Vector{StrategyProfile})::String

Format strategy profiles as comparison table.
"""
function format_strategy_profiles(profiles::Vector{StrategyProfile})::String
    io = IOBuffer()

    println(io, "╔════════════════════════════════════════════════════════════════════╗")
    println(io, "║                    STRATEGY PROFILES                               ║")
    println(io, "╚════════════════════════════════════════════════════════════════════╝")
    println(io, "")

    # Header
    println(io, "Strategy | Cost/Case | Cost/QALY | NMB@100K | Quality | Margin | Dominance")
    println(io, "─"^100)

    # Rows
    for profile in profiles
        cost_str = format_currency(profile.cost_per_case)
        icer_str = isfinite(profile.cost_per_qaly) ? format_currency(profile.cost_per_qaly) : "Dominant"
        nmb_str = format_currency(profile.nmb_at_100k)
        margin_str = format_currency(profile.financial_margin)

        println(io, "$(rpad(profile.strategy_name, 8)) | $(rpad(cost_str, 9)) | $(rpad(icer_str, 9)) | $(rpad(nmb_str, 8)) | $(round(profile.quality_score, digits=2)) | $(margin_str) | $(profile.dominance_status)")
    end
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
