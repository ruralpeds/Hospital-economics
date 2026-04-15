"""
    example_03_preventive_care_value.jl

Preventive Care Value Proposition:
Cost-effectiveness of preventive interventions vs. treatment of disease

This example demonstrates:
1. Natural history modeling of disease progression
2. Preventive intervention impact
3. Cost-effectiveness of prevention vs. treatment
4. Lifetime cost-benefit analysis
5. Multi-strategy comparison

Scenario:
- 10,000 patient cohort with hypertension
- Strategies: Usual care, medication therapy, intensive lifestyle intervention
- Outcome: Prevention of stroke, MI, death
- Time horizon: 10 years
"""

using HospitalFinanceToolbox
using Distributions
using Random
using Statistics

Random.seed!(456)

# ═══════════════════════════════════════════════════════════════
# PART 1: DISEASE NATURAL HISTORY PARAMETERS
# ═══════════════════════════════════════════════════════════════

"""Hypertension natural history and progression"""
const HYPERTENSION_NATURAL_HISTORY = Dict(
    # Annual event rates by strategy
    :usual_care => Dict(
        :stroke => 0.015,
        :mi => 0.012,
        :death_cvd => 0.008,
        :death_other => 0.003
    ),
    :medication => Dict(
        :stroke => 0.008,      # 47% RRR vs usual care
        :mi => 0.006,          # 50% RRR
        :death_cvd => 0.004,   # 50% RRR
        :death_other => 0.003
    ),
    :intensive_lifestyle => Dict(
        :stroke => 0.010,      # 33% RRR
        :mi => 0.009,          # 25% RRR
        :death_cvd => 0.005,   # 38% RRR
        :death_other => 0.003
    ),
    :combined => Dict(
        :stroke => 0.005,      # 67% RRR
        :mi => 0.004,          # 67% RRR
        :death_cvd => 0.002,   # 75% RRR
        :death_other => 0.003
    )
)

"""Cost parameters for strategies"""
const COST_PARAMETERS = Dict(
    :usual_care => Dict(
        :annual_monitoring => 150.0,
        :acute_event_cost => Dict(
            :stroke => 85_000.0,
            :mi => 75_000.0,
            :death_cvd => 5_000.0  # Terminal care
        )
    ),
    :medication => Dict(
        :annual_monitoring => 200.0,
        :annual_medication => 800.0,  # Antihypertensives, statin, etc.
        :acute_event_cost => Dict(
            :stroke => 85_000.0,
            :mi => 75_000.0,
            :death_cvd => 5_000.0
        )
    ),
    :intensive_lifestyle => Dict(
        :annual_monitoring => 250.0,
        :annual_intervention => 1_200.0,  # Clinic visits, dietitian, exercise
        :acute_event_cost => Dict(
            :stroke => 85_000.0,
            :mi => 75_000.0,
            :death_cvd => 5_000.0
        )
    ),
    :combined => Dict(
        :annual_monitoring => 250.0,
        :annual_medication => 800.0,
        :annual_intervention => 1_200.0,
        :acute_event_cost => Dict(
            :stroke => 85_000.0,
            :mi => 75_000.0,
            :death_cvd => 5_000.0
        )
    )
)

"""Utility weights for health states"""
const HEALTH_STATE_UTILITIES = Dict(
    :healthy => 1.0,
    :controlled_hypertension => 0.95,
    :post_stroke => 0.65,
    :post_mi => 0.70,
    :death => 0.0
)

# ═══════════════════════════════════════════════════════════════
# PART 2: SIMULATION ENGINE
# ═══════════════════════════════════════════════════════════════

"""Simulate one patient over time horizon"""
function simulate_patient_trajectory(
    strategy::Symbol,
    years::Int = 10,
    discount_rate::Float64 = 0.03
)::Tuple{Float64, Float64, Vector{Float64}, Vector{Float64}}
    
    event_rates = HYPERTENSION_NATURAL_HISTORY[strategy]
    costs = COST_PARAMETERS[strategy]
    
    total_cost = 0.0
    total_qaly = 0.0
    alive = true
    health_state = :healthy
    cost_trajectory = Float64[]
    qaly_trajectory = Float64[]
    
    for year in 1:years
        discount_factor = 1.0 / (1.0 + discount_rate)^(year-1)
        
        # Annual costs
        annual_cost = costs[:annual_monitoring]
        
        if strategy == :medication || strategy == :combined
            annual_cost += costs[:annual_medication]
        end
        
        if strategy == :intensive_lifestyle || strategy == :combined
            annual_cost += costs[:annual_intervention]
        end
        
        # Apply discount
        discounted_cost = annual_cost * discount_factor
        total_cost += discounted_cost
        push!(cost_trajectory, total_cost)
        
        # Event simulation
        if alive
            # Stroke event
            if rand() < event_rates[:stroke]
                health_state = :post_stroke
                total_cost += costs[:acute_event_cost][:stroke] * discount_factor
            end
            
            # MI event
            if rand() < event_rates[:mi]
                health_state = :post_mi
                total_cost += costs[:acute_event_cost][:mi] * discount_factor
            end
            
            # Death
            if rand() < event_rates[:death_cvd] + event_rates[:death_other]
                alive = false
                total_cost += costs[:acute_event_cost][:death_cvd] * discount_factor
            end
        end
        
        # QALY accumulation
        utility = HEALTH_STATE_UTILITIES[health_state]
        qaly_year = utility * discount_factor
        total_qaly += qaly_year
        push!(qaly_trajectory, total_qaly)
    end
    
    return (total_cost, total_qaly, cost_trajectory, qaly_trajectory)
end

"""Simulate cohort and aggregate results"""
function simulate_cohort(
    strategy::Symbol,
    cohort_size::Int = 10_000,
    years::Int = 10
)::Dict{String, Float64}
    
    costs = Float64[]
    qalys = Float64[]
    
    for i in 1:cohort_size
        cost, qaly, _, _ = simulate_patient_trajectory(strategy, years)
        push!(costs, cost)
        push!(qalys, qaly)
    end
    
    return Dict(
        "strategy" => String(strategy),
        "cohort_size" => cohort_size,
        "mean_cost" => mean(costs),
        "std_cost" => std(costs),
        "median_cost" => median(costs),
        "mean_qaly" => mean(qalys),
        "std_qaly" => std(qalys),
        "median_qaly" => median(qalys),
        "total_cost" => sum(costs),
        "total_qaly" => sum(qalys)
    )
end

# ═══════════════════════════════════════════════════════════════
# PART 3: COST-EFFECTIVENESS ANALYSIS
# ═══════════════════════════════════════════════════════════════

"""Compare strategies using incremental analysis"""
function analyze_strategies(cohort_size::Int = 10_000, years::Int = 10)
    
    println("=" ^ 85)
    println("PREVENTIVE CARE VALUE PROPOSITION: Hypertension Management Strategies")
    println("=" ^ 85)
    println()
    println("Population: $cohort_size patients with hypertension")
    println("Time Horizon: $years years")
    println()
    
    # Run all strategies
    strategies = [:usual_care, :medication, :intensive_lifestyle, :combined]
    results = Dict{Symbol, Dict}()
    
    for strategy in strategies
        results[strategy] = simulate_cohort(strategy, cohort_size, years)
    end
    
    # ───────────────────────────────────────────────────────────────
    # Print individual strategy results
    # ───────────────────────────────────────────────────────────────
    
    println("STRATEGY PROFILES")
    println("-" ^ 85)
    println()
    
    for strategy in strategies
        result = results[strategy]
        strategy_name = replace(String(strategy), "_" => " ") |> titlecase
        
        println("$strategy_name")
        println("  Mean Cost per Patient:         ", format_currency(result["mean_cost"]))
        println("  Std Dev Cost:                  ", format_currency(result["std_cost"]))
        println("  Total Cohort Cost:             ", format_currency(result["total_cost"]))
        println("  ")
        println("  Mean QALYs per Patient:        ", @sprintf("%.3f", result["mean_qaly"]))
        println("  Std Dev QALYs:                 ", @sprintf("%.3f", result["std_qaly"]))
        println("  Total Cohort QALYs:            ", @sprintf("%.0f", result["total_qaly"]))
        println()
    end
    
    # ───────────────────────────────────────────────────────────────
    # Incremental Cost-Effectiveness Analysis
    # ───────────────────────────────────────────────────────────────
    
    println()
    println("INCREMENTAL COST-EFFECTIVENESS ANALYSIS")
    println("-" ^ 85)
    println()
    println("Comparisons: vs. Usual Care")
    println()
    
    baseline_result = results[:usual_care]
    
    for strategy in [:medication, :intensive_lifestyle, :combined]
        comparison_result = results[strategy]
        
        icer_result = calculate_icer(
            intervention_cost = comparison_result["mean_cost"],
            intervention_effect = comparison_result["mean_qaly"],
            control_cost = baseline_result["mean_cost"],
            control_effect = baseline_result["mean_qaly"],
            ce_threshold = 100_000.0
        )
        
        strategy_name = replace(String(strategy), "_" => " ") |> titlecase
        
        println("$strategy_name vs. Usual Care:")
        println("  Incremental Cost:              ", format_currency(icer_result.cost_difference))
        println("  Incremental Effect (QALYs):    ", @sprintf("+%.3f", icer_result.effect_difference))
        
        if icer_result.cost_difference < 0 && icer_result.effect_difference > 0
            println("  Status:                        ✅ DOMINANT (cost-saving & more effective)")
        elseif icer_result.cost_difference < 0
            println("  Status:                        ✅ COST-SAVING")
        elseif icer_result.cost_effective
            println("  ICER:                          ", format_currency(icer_result.icer), " per QALY")
            println("  Status:                        ✅ COST-EFFECTIVE")
        else
            println("  ICER:                          ", format_currency(icer_result.icer), " per QALY")
            println("  Status:                        ❌ NOT COST-EFFECTIVE")
        end
        
        println()
    end
    
    # ───────────────────────────────────────────────────────────────
    # Health Impact Summary
    # ───────────────────────────────────────────────────────────────
    
    println()
    println("HEALTH IMPACT SUMMARY")
    println("-" ^ 85)
    println()
    
    baseline_qaly = results[:usual_care]["total_qaly"]
    
    for strategy in [:medication, :intensive_lifestyle, :combined]
        comparison_result = results[strategy]
        qaly_gain = comparison_result["total_qaly"] - baseline_qaly
        
        strategy_name = replace(String(strategy), "_" => " ") |> titlecase
        
        println("$strategy_name:")
        println("  Additional QALYs vs. Usual Care: ", @sprintf("+%.0f (%.2f per patient)", 
                qaly_gain, qaly_gain / cohort_size))
        println()
    end
    
    # ───────────────────────────────────────────────────────────────
    # Efficiency Frontier
    # ───────────────────────────────────────────────────────────────
    
    println()
    println("EFFICIENCY FRONTIER")
    println("-" ^ 85)
    println()
    
    sorted_strategies = sort(strategies, by = s -> results[s]["mean_qaly"])
    
    println("Strategies ranked by effectiveness (QALYs per patient):")
    println()
    
    for (idx, strategy) in enumerate(sorted_strategies)
        result = results[strategy]
        strategy_name = replace(String(strategy), "_" => " ") |> titlecase
        
        println("$idx. $strategy_name")
        println("   Cost:  ", format_currency(result["mean_cost"]))
        println("   Effect: ", @sprintf("%.3f QALYs", result["mean_qaly"]))
        println("   Cost/Effect: ", format_currency(result["mean_cost"] / result["mean_qaly"]))
        println()
    end
    
    return results
end

# ═══════════════════════════════════════════════════════════════
# SENSITIVITY ANALYSIS
# ═══════════════════════════════════════════════════════════════

"""Test sensitivity to key parameters"""
function sensitivity_analysis()
    
    println()
    println("SENSITIVITY ANALYSIS")
    println("=" ^ 85)
    println()
    println("Medication Strategy - Varying Annual Medication Cost")
    println("-" ^ 85)
    println()
    
    baseline_cost = COST_PARAMETERS[:medication][:annual_medication]
    
    for cost_multiplier in [0.75, 0.9, 1.0, 1.1, 1.25]
        # Temporarily modify cost
        COST_PARAMETERS[:medication][:annual_medication] = baseline_cost * cost_multiplier
        
        med_result = simulate_cohort(:medication, 1_000, 10)
        baseline_result = simulate_cohort(:usual_care, 1_000, 10)
        
        icer = (med_result["mean_cost"] - baseline_result["mean_cost"]) / 
               (med_result["mean_qaly"] - baseline_result["mean_qaly"])
        
        cost_label = @sprintf("Medication cost %+.0f%%", (cost_multiplier - 1) * 100)
        println("$cost_label: ICER = ", format_currency(icer), " per QALY")
    end
    
    # Restore baseline
    COST_PARAMETERS[:medication][:annual_medication] = baseline_cost
    
    println()
end

# ═══════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════

if abspath(PROGRAM_FILE) == @__FILE__
    results = analyze_strategies(10_000, 10)
    sensitivity_analysis()
    
    println("\n✅ Preventive care analysis complete.")
end
