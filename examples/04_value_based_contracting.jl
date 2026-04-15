"""
    example_04_value_based_contracting.jl

Value-Based Care Contract Analysis:
Evaluating financial sustainability of shared savings arrangements

This example demonstrates:
1. Traditional fee-for-service vs. value-based contracting
2. Quality bonus structures
3. Shared savings calculations
4. Risk-sharing analysis
5. Multi-year financial projections

Scenario:
- Healthcare provider/system transitioning to value-based care
- Baseline: FFS model ($100/patient/month)
- VBC: Shared savings model (70/30 split on savings)
- 100,000 attributed lives
- 3-year projection
"""

using HospitalFinanceToolbox
using Distributions
using Random
using Statistics

Random.seed!(789)

# ═══════════════════════════════════════════════════════════════
# PART 1: FEE-FOR-SERVICE MODEL
# ═══════════════════════════════════════════════════════════════

"""Fee-for-service payment model"""
struct FeeForServiceModel
    capitation_rate::Float64              # $ per attributed life per month
    volume_increase_rate::Float64         # Annual growth in utilization
    efficiency_improvement::Float64       # Annual cost reduction
    quality_metric_baseline::Dict{String, Float64}
end

"""Default FFS model"""
function default_ffs_model()::FeeForServiceModel
    FeeForServiceModel(
        capitation_rate = 100.0,
        volume_increase_rate = 0.03,      # 3% annual growth
        efficiency_improvement = 0.01,    # 1% annual efficiency
        quality_metric_baseline = Dict(
            "readmission_rate" => 0.18,
            "ed_utilization" => 0.42,
            "preventive_care" => 0.68,
            "patient_satisfaction" => 0.72
        )
    )
end

# ═══════════════════════════════════════════════════════════════
# PART 2: VALUE-BASED CARE MODEL
# ═══════════════════════════════════════════════════════════════

"""Value-based care payment model"""
struct ValueBasedCareModel
    base_capitation::Float64              # Base payment (typically 80% of FFS)
    quality_bonus_pool::Float64           # % of payment tied to quality
    savings_share_provider::Float64       # % of savings shared with provider
    savings_share_payer::Float64          # % of savings retained by payer
    quality_metrics::Dict{String, Dict}   # Quality target and bonus structure
end

"""Default VBC model"""
function default_vbc_model()::ValueBasedCareModel
    ValueBasedCareModel(
        base_capitation = 80.0,           # 80% of FFS rate
        quality_bonus_pool = 0.10,        # 10% of base payment
        savings_share_provider = 0.70,    # 70/30 shared savings
        savings_share_payer = 0.30,
        quality_metrics = Dict(
            "readmission_rate" => Dict(
                "target" => 0.12,
                "bonus_per_point" => 0.02
            ),
            "ed_utilization" => Dict(
                "target" => 0.30,
                "bonus_per_point" => 0.01
            ),
            "preventive_care" => Dict(
                "target" => 0.80,
                "bonus_per_point" => 0.015
            ),
            "patient_satisfaction" => Dict(
                "target" => 0.85,
                "bonus_per_point" => 0.01
            )
        )
    )
end

# ═══════════════════════════════════════════════════════════════
# PART 3: FINANCIAL MODELING
# ═══════════════════════════════════════════════════════════════

"""Project FFS revenue and costs"""
function project_ffs_financials(
    model::FeeForServiceModel,
    attributed_lives::Int,
    years::Int = 3
)::Dict{String, Vector{Float64}}
    
    revenue_trajectory = Float64[]
    cost_trajectory = Float64[]
    efficiency_trajectory = Float64[]
    
    for year in 1:years
        # Adjusted capitation rate with growth/efficiency factors
        volume_factor = (1.0 + model.volume_increase_rate) ^ (year - 1)
        efficiency_factor = (1.0 - model.efficiency_improvement) ^ (year - 1)
        
        annual_capitation = model.capitation_rate * volume_factor
        annual_cost = annual_capitation * efficiency_factor
        
        annual_revenue = annual_capitation * attributed_lives * 12  # Monthly to annual
        annual_total_cost = annual_cost * attributed_lives * 12
        
        push!(revenue_trajectory, annual_revenue)
        push!(cost_trajectory, annual_total_cost)
        push!(efficiency_trajectory, annual_revenue - annual_total_cost)
    end
    
    return Dict(
        "revenue" => revenue_trajectory,
        "cost" => cost_trajectory,
        "profit" => efficiency_trajectory
    )
end

"""Project VBC revenue and costs"""
function project_vbc_financials(
    model::ValueBasedCareModel,
    baseline_ffs::FeeForServiceModel,
    attributed_lives::Int,
    years::Int = 3
)::Dict{String, Vector{Float64}}
    
    revenue_trajectory = Float64[]
    cost_trajectory = Float64[]
    savings_trajectory = Float64[]
    shared_savings_trajectory = Float64[]
    
    # Baseline (what payer would spend on FFS)
    ffs_financials = project_ffs_financials(baseline_ffs, attributed_lives, years)
    ffs_costs = ffs_financials["cost"]
    
    for year in 1:years
        # Base capitation payment
        base_revenue = model.base_capitation * attributed_lives * 12
        
        # Quality bonus (assume provider improves 50% toward target each year)
        quality_bonus_pct = 0.0
        for (metric, targets) in model.quality_metrics
            improvement_rate = 0.5 / year  # Gradual improvement
            baseline_perf = baseline_ffs.quality_metric_baseline[metric]
            target = targets["target"]
            
            # Simple linear improvement toward target
            achieved = baseline_perf + (target - baseline_perf) * improvement_rate
            bonus_earned = max(0.0, (achieved - baseline_perf) * targets["bonus_per_point"])
            quality_bonus_pct += bonus_earned
        end
        
        quality_bonus = base_revenue * quality_bonus_pct
        
        # Shared savings
        ffs_baseline_cost = ffs_costs[year]
        
        # Assume VBC reduces costs through efficiency improvements
        vbc_cost_factor = (1.0 - 0.02 * year)  # 2% annual improvement vs baseline
        vbc_actual_cost = ffs_baseline_cost * vbc_cost_factor
        
        total_savings = ffs_baseline_cost - vbc_actual_cost
        provider_shared_savings = total_savings * model.savings_share_provider
        
        total_revenue = base_revenue + quality_bonus + provider_shared_savings
        
        push!(revenue_trajectory, total_revenue)
        push!(cost_trajectory, vbc_actual_cost)
        push!(savings_trajectory, total_savings)
        push!(shared_savings_trajectory, provider_shared_savings)
    end
    
    return Dict(
        "revenue" => revenue_trajectory,
        "cost" => cost_trajectory,
        "savings" => savings_trajectory,
        "shared_savings" => shared_savings_trajectory,
        "profit" => revenue_trajectory .- cost_trajectory
    )
end

# ═══════════════════════════════════════════════════════════════
# PART 4: COMPARATIVE ANALYSIS
# ═══════════════════════════════════════════════════════════════

"""Compare FFS and VBC contracts"""
function analyze_vbc_contract(
    attributed_lives::Int = 100_000,
    years::Int = 3
)
    
    println("=" ^ 90)
    println("VALUE-BASED CARE CONTRACT ANALYSIS")
    println("=" ^ 90)
    println()
    println("Attributed Lives:     $attributed_lives")
    println("Analysis Period:      $years years")
    println()
    
    # Setup models
    ffs_model = default_ffs_model()
    vbc_model = default_vbc_model()
    
    # ───────────────────────────────────────────────────────────────
    # Project financials
    # ───────────────────────────────────────────────────────────────
    
    ffs_financials = project_ffs_financials(ffs_model, attributed_lives, years)
    vbc_financials = project_vbc_financials(vbc_model, ffs_model, attributed_lives, years)
    
    # ───────────────────────────────────────────────────────────────
    # Print detailed results
    # ───────────────────────────────────────────────────────────────
    
    println("FEE-FOR-SERVICE MODEL")
    println("-" ^ 90)
    println()
    println("Assumptions:")
    println("  Base Capitation Rate: ", format_currency(ffs_model.capitation_rate), "/patient/month")
    println("  Annual Volume Growth: ", format_percentage(ffs_model.volume_increase_rate))
    println("  Annual Efficiency:    ", format_percentage(ffs_model.efficiency_improvement))
    println()
    
    total_ffs_revenue = 0.0
    total_ffs_cost = 0.0
    total_ffs_profit = 0.0
    
    for year in 1:years
        revenue = ffs_financials["revenue"][year]
        cost = ffs_financials["cost"][year]
        profit = ffs_financials["profit"][year]
        
        total_ffs_revenue += revenue
        total_ffs_cost += cost
        total_ffs_profit += profit
        
        println("Year $year:")
        println("  Revenue:  ", format_currency(revenue))
        println("  Cost:     ", format_currency(cost))
        println("  Profit:   ", format_currency(profit))
        println("  Margin:   ", @sprintf("%.1f%%", (profit / revenue) * 100))
        println()
    end
    
    println()
    println("VALUE-BASED CARE MODEL")
    println("-" ^ 90)
    println()
    println("Assumptions:")
    println("  Base Capitation:      ", format_currency(vbc_model.base_capitation), "/patient/month (80% of FFS)")
    println("  Quality Bonus Pool:   ", format_percentage(vbc_model.quality_bonus_pool))
    println("  Savings Share (Provider): ", format_percentage(vbc_model.savings_share_provider))
    println()
    
    total_vbc_revenue = 0.0
    total_vbc_cost = 0.0
    total_vbc_profit = 0.0
    total_vbc_savings = 0.0
    total_provider_savings = 0.0
    
    for year in 1:years
        revenue = vbc_financials["revenue"][year]
        cost = vbc_financials["cost"][year]
        profit = vbc_financials["profit"][year]
        savings = vbc_financials["savings"][year]
        provider_savings = vbc_financials["shared_savings"][year]
        
        total_vbc_revenue += revenue
        total_vbc_cost += cost
        total_vbc_profit += profit
        total_vbc_savings += savings
        total_provider_savings += provider_savings
        
        println("Year $year:")
        println("  Revenue:          ", format_currency(revenue))
        println("  Cost:             ", format_currency(cost))
        println("  Profit:           ", format_currency(profit))
        println("  Margin:           ", @sprintf("%.1f%%", (profit / revenue) * 100))
        println("  Total Savings:    ", format_currency(savings))
        println("  Provider Share:   ", format_currency(provider_savings))
        println()
    end
    
    # ───────────────────────────────────────────────────────────────
    # Comparison Summary
    # ───────────────────────────────────────────────────────────────
    
    println()
    println("COMPARATIVE SUMMARY")
    println("=" ^ 90)
    println()
    println("3-Year Totals:")
    println("  Metric                    FFS              VBC              Difference")
    println("-" ^ 90)
    
    revenue_diff = total_vbc_revenue - total_ffs_revenue
    cost_diff = total_vbc_cost - total_ffs_cost
    profit_diff = total_vbc_profit - total_ffs_profit
    
    println("  Total Revenue:            ", rpad(format_currency(total_ffs_revenue), 20),
            rpad(format_currency(total_vbc_revenue), 20),
            format_currency(revenue_diff))
    println("  Total Cost:               ", rpad(format_currency(total_ffs_cost), 20),
            rpad(format_currency(total_vbc_cost), 20),
            format_currency(cost_diff))
    println("  Total Profit:             ", rpad(format_currency(total_ffs_profit), 20),
            rpad(format_currency(total_vbc_profit), 20),
            format_currency(profit_diff))
    
    println()
    println("Health System Perspective:")
    println("  FFS Profit Margin:        ", @sprintf("%.2f%%", (total_ffs_profit / total_ffs_revenue) * 100))
    println("  VBC Profit Margin:        ", @sprintf("%.2f%%", (total_vbc_profit / total_vbc_revenue) * 100))
    println()
    
    # ───────────────────────────────────────────────────────────────
    # Break-even Analysis
    # ───────────────────────────────────────────────────────────────
    
    println()
    println("BREAK-EVEN ANALYSIS")
    println("-" ^ 90)
    println()
    
    # At what savings rate does VBC break even with FFS?
    year_1_ffs_profit = ffs_financials["profit"][1]
    year_1_vbc_profit = vbc_financials["profit"][1]
    
    println("Year 1 Profitability:")
    println("  FFS Profit:               ", format_currency(year_1_ffs_profit))
    println("  VBC Profit:               ", format_currency(year_1_vbc_profit))
    println("  Difference:               ", format_currency(year_1_vbc_profit - year_1_ffs_profit))
    println()
    
    if year_1_vbc_profit < year_1_ffs_profit
        println("  ⚠️  VBC underperforms FFS in Year 1")
        println("      Provider needs additional efficiency improvements to break even")
    else
        println("  ✅ VBC outperforms FFS in Year 1")
    end
    
    println()
    
    # ───────────────────────────────────────────────────────────────
    # Risk Assessment
    # ───────────────────────────────────────────────────────────────
    
    println()
    println("RISK ASSESSMENT")
    println("-" ^ 90)
    println()
    println("VBC Contract Risks:")
    println("  • Cost savings may not materialize (downside risk)")
    println("  • Increased care coordination costs")
    println("  • Population health deterioration")
    println("  • Payer rate reductions")
    println()
    println("Risk Mitigation:")
    println("  • Performance guarantees in contract")
    println("  • Shared loss provisions (capped)")
    println("  • Quality improvement infrastructure investment")
    println("  • Data analytics and monitoring capability")
    println()
    
    # Cost savings variability
    println("Sensitivity: Impact of Cost Savings Achievement")
    println()
    
    for savings_pct in [0.5, 0.75, 1.0, 1.25]
        # Adjust VBC financials based on savings achievement
        adjusted_savings = total_vbc_savings * savings_pct
        adjusted_provider_share = adjusted_savings * vbc_model.savings_share_provider
        adjusted_vbc_profit = total_vbc_profit - (total_vbc_savings - adjusted_savings) * vbc_model.savings_share_provider
        
        profit_vs_ffs = adjusted_vbc_profit - total_ffs_profit
        
        label = @sprintf("%.0f%% of expected savings", savings_pct * 100)
        println("  $label:")
        println("    VBC 3-Year Profit: ", format_currency(adjusted_vbc_profit))
        println("    vs. FFS:            ", profit_vs_ffs > 0 ? "✅" : "❌", " ",
                format_currency(profit_vs_ffs))
        println()
    end
    
    return (ffs = ffs_financials, vbc = vbc_financials)
end

# ═══════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════

if abspath(PROGRAM_FILE) == @__FILE__
    results = analyze_vbc_contract(100_000, 3)
    
    println("\n✅ VBC contract analysis complete.")
end
