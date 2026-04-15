"""
    example_01_nicu_cost_effectiveness.jl

NICU Cost-Effectiveness Analysis:
Comparing standard ventilation vs. high-frequency oscillatory ventilation (HFOV)

This example demonstrates:
1. Episode-level costing for NICU patients
2. QALY calculations with outcome tracking
3. Cost-effectiveness analysis (ICER)
4. Probabilistic sensitivity analysis
5. Cost-effectiveness acceptability curve

Scenario:
- 100 preterm infants (28-32 weeks gestation)
- Primary outcome: Bronchopulmonary dysplasia (BPD) prevention
- Cost driver: Ventilation equipment & complications
- Time horizon: First 90 days of life
"""

using HospitalFinanceToolbox
using Distributions
using Random
using Statistics
using Plots
using StatsPlots

# Set random seed for reproducibility
Random.seed!(42)

# ═══════════════════════════════════════════════════════════════
# PART 1: DEFINE PATIENT COHORT
# ═══════════════════════════════════════════════════════════════

"""Generate synthetic NICU patient episodes"""
function generate_nicu_cohort(n::Int, treatment::Symbol)::Vector{Episode}
    episodes = Episode[]
    
    for i in 1:n
        episode = Episode(
            episode_id = "NICU_$(treatment)_$i",
            patient_id = "PT_NICU_$i",
            admission_date = Date(2024, 1, 1) + Day(i),
            discharge_date = Date(2024, 4, 1) + Day(i),  # ~90 days LOS
            primary_diagnosis = "P07.1",  # Extreme prematurity, 28-31 weeks
            drg_code = "795",  # Prematurity with major complications
            secondary_diagnoses = ["P28.0", "P21.0"],  # RDS, asphyxia
            procedures = [
                "36.15",  # Arterial catheter placement
                "31.1",   # Endotracheal intubation
                if treatment == :conventional "33.27" else "33.28" end  # Ventilation type
            ],
            payer = Medicare  # In real world, mix of Medicaid, commercial
        )
        push!(episodes, episode)
    end
    
    return episodes
end

# ═══════════════════════════════════════════════════════════════
# PART 2: DEFINE COST MODELS
# ═══════════════════════════════════════════════════════════════

"""Cost model for conventional mechanical ventilation"""
function conventional_ventilation_cost_model()::DRGCostModel
    DRGCostModel(
        drg_base_rates = Dict(
            "795" => 85_000.0  # NICU base cost (extreme prematurity)
        ),
        complication_multiplier = 0.35,  # 35% increase per complication
        procedure_costs = Dict(
            "36.15" => 2_500.0,   # Arterial catheter
            "31.1" => 1_200.0,    # Intubation
            "33.27" => 18_000.0   # Conventional ventilation equipment/use
        ),
        severity_adjustor = 1.0
    )
end

"""Cost model for HFOV (high-frequency oscillatory ventilation)"""
function hfov_cost_model()::DRGCostModel
    DRGCostModel(
        drg_base_rates = Dict(
            "795" => 85_000.0
        ),
        complication_multiplier = 0.25,  # Lower complication rate with HFOV
        procedure_costs = Dict(
            "36.15" => 2_500.0,
            "31.1" => 1_200.0,
            "33.28" => 28_000.0   # More expensive HFOV equipment/use
        ),
        severity_adjustor = 1.0
    )
end

# ═══════════════════════════════════════════════════════════════
# PART 3: DEFINE OUTCOME MODELS
# ═══════════════════════════════════════════════════════════════

"""Generate clinical outcomes for control (conventional ventilation)"""
function conventional_outcomes(episode::Episode)::EpisodeOutcomes
    # Baseline outcomes
    survival_prob = 0.92  # 92% survival
    bpd_rate = 0.45      # 45% BPD rate
    major_ivh = 0.08     # 8% Grade III/IV IVH
    nec_rate = 0.12      # 12% NEC
    
    survived = rand() < survival_prob
    
    complications = String[]
    if rand() < bpd_rate
        push!(complications, "P27.3")  # BPD
    end
    if rand() < major_ivh
        push!(complications, "P52.3")  # IVH
    end
    if rand() < nec_rate
        push!(complications, "P77.9")  # NEC
    end
    
    # QALY calculation: survival + quality of life weight
    qaly_weight = survived ? (1.0 - 0.15 * length(complications)) : 0.0
    qaly_gained = 90/365 * qaly_weight  # 90-day episode
    
    # Cost calculation
    cost = calculate_episode_cost(episode, conventional_ventilation_cost_model())
    
    # Complications add cost
    complication_cost_map = Dict(
        "P27.3" => 15_000.0,  # BPD additional cost
        "P52.3" => 12_000.0,  # IVH additional
        "P77.9" => 25_000.0   # NEC additional
    )
    for comp in complications
        cost += get(complication_cost_map, comp, 0.0)
    end
    
    # Readmission risk (30-day)
    readmit_30 = (length(complications) > 0) && (rand() < 0.35)
    
    EpisodeOutcomes(
        episode_id = episode.episode_id,
        survived = survived,
        status = survived ? Alive : Dead,
        qaly_gained = qaly_gained,
        complications_occurred = complications,
        readmission_30day = readmit_30,
        readmission_90day = false,
        length_of_stay = episode.los,
        total_cost = cost,
        quality_score = survived ? 0.85 : 0.0
    )
end

"""Generate clinical outcomes for intervention (HFOV)"""
function hfov_outcomes(episode::Episode)::EpisodeOutcomes
    # HFOV improves outcomes
    survival_prob = 0.95  # Improved to 95%
    bpd_rate = 0.32      # Reduced to 32% BPD
    major_ivh = 0.06     # Reduced to 6% IVH
    nec_rate = 0.10      # Slightly reduced
    
    survived = rand() < survival_prob
    
    complications = String[]
    if rand() < bpd_rate
        push!(complications, "P27.3")
    end
    if rand() < major_ivh
        push!(complications, "P52.3")
    end
    if rand() < nec_rate
        push!(complications, "P77.9")
    end
    
    # QALY: better quality with HFOV
    qaly_weight = survived ? (1.0 - 0.10 * length(complications)) : 0.0
    qaly_gained = 90/365 * qaly_weight
    
    # Cost calculation
    cost = calculate_episode_cost(episode, hfov_cost_model())
    
    # Same complication costs
    complication_cost_map = Dict(
        "P27.3" => 15_000.0,
        "P52.3" => 12_000.0,
        "P77.9" => 25_000.0
    )
    for comp in complications
        cost += get(complication_cost_map, comp, 0.0)
    end
    
    # Readmission risk (lower with HFOV)
    readmit_30 = (length(complications) > 0) && (rand() < 0.20)
    
    EpisodeOutcomes(
        episode_id = episode.episode_id,
        survived = survived,
        status = survived ? Alive : Dead,
        qaly_gained = qaly_gained,
        complications_occurred = complications,
        readmission_30day = readmit_30,
        readmission_90day = false,
        length_of_stay = episode.los,
        total_cost = cost,
        quality_score = survived ? 0.90 : 0.0
    )
end

# ═══════════════════════════════════════════════════════════════
# PART 4: RUN ANALYSIS
# ═══════════════════════════════════════════════════════════════

"""Main analysis function"""
function run_nicu_cost_effectiveness_analysis(n_patients::Int = 500)
    
    println("=" ^ 70)
    println("NICU COST-EFFECTIVENESS ANALYSIS: Conventional vs. HFOV")
    println("=" ^ 70)
    println("\nScenario: $n_patients preterm infants (28-32 weeks)")
    println("Comparison: Conventional ventilation vs. High-frequency oscillatory ventilation")
    println()
    
    # Generate cohorts
    control_episodes = generate_nicu_cohort(n_patients, :conventional)
    intervention_episodes = generate_nicu_cohort(n_patients, :hfov)
    
    # Simulate outcomes
    control_outcomes = [conventional_outcomes(ep) for ep in control_episodes]
    intervention_outcomes = [hfov_outcomes(ep) for ep in intervention_episodes]
    
    # ───────────────────────────────────────────────────────────────
    # Summary statistics
    # ───────────────────────────────────────────────────────────────
    
    control_summary = EpisodeSummary(control_outcomes)
    intervention_summary = EpisodeSummary(intervention_outcomes)
    
    println("CONTROL GROUP (Conventional Ventilation)")
    println("-" ^ 70)
    println("  Total Cost:            ", format_currency(control_summary.total_cost))
    println("  Mean Cost per Patient: ", format_currency(control_summary.mean_cost))
    println("  Total QALYs:           ", round(control_summary.total_qaly, digits=2))
    println("  Mean QALY per Patient: ", round(control_summary.mean_qaly, digits=3))
    println("  Mortality Rate:        ", format_percentage(control_summary.mortality_rate))
    println("  30-day Readmission:    ", format_percentage(control_summary.readmission_30_rate))
    println()
    
    println("INTERVENTION GROUP (HFOV)")
    println("-" ^ 70)
    println("  Total Cost:            ", format_currency(intervention_summary.total_cost))
    println("  Mean Cost per Patient: ", format_currency(intervention_summary.mean_cost))
    println("  Total QALYs:           ", round(intervention_summary.total_qaly, digits=2))
    println("  Mean QALY per Patient: ", round(intervention_summary.mean_qaly, digits=3))
    println("  Mortality Rate:        ", format_percentage(intervention_summary.mortality_rate))
    println("  30-day Readmission:    ", format_percentage(intervention_summary.readmission_30_rate))
    println()
    
    # ───────────────────────────────────────────────────────────────
    # Cost-Effectiveness Analysis
    # ───────────────────────────────────────────────────────────────
    
    ce_result = calculate_icer(
        intervention_cost = intervention_summary.mean_cost,
        intervention_effect = intervention_summary.mean_qaly,
        control_cost = control_summary.mean_cost,
        control_effect = control_summary.mean_qaly,
        ce_threshold = 100_000.0  # Standard US threshold: $100K per QALY
    )
    
    println("COST-EFFECTIVENESS ANALYSIS")
    println("-" ^ 70)
    println("  Incremental Cost:      ", format_currency(ce_result.cost_difference))
    println("  Incremental Effect:    ", round(ce_result.effect_difference, digits=4), " QALYs")
    
    if ce_result.dominated
        println("  Status:                DOMINATED (higher cost, lower benefit)")
    elseif ce_result.extended_dominance
        println("  Status:                EXTENDED DOMINANCE")
    elseif ce_result.cost_difference < 0
        println("  Status:                COST-SAVING AND MORE EFFECTIVE")
        println("  Net Savings per Pt:    ", format_currency(abs(ce_result.cost_difference)))
    else
        println("  ICER:                  ", format_currency(ce_result.icer), " per QALY")
        println("  Status:                ", ce_result.cost_effective ? "COST-EFFECTIVE" : "NOT COST-EFFECTIVE")
    end
    println()
    println("  Recommendation:        ", recommend_intervention(ce_result))
    println()
    
    # ───────────────────────────────────────────────────────────────
    # Sensitivity Analysis
    # ───────────────────────────────────────────────────────────────
    
    println("SENSITIVITY ANALYSIS (One-Way)")
    println("-" ^ 70)
    
    # Test HFOV cost variation (±20%)
    for cost_var in [0.8, 0.9, 1.0, 1.1, 1.2]
        adjusted_hfov_cost = intervention_summary.mean_cost * cost_var
        ce_sens = calculate_icer(
            intervention_cost = adjusted_hfov_cost,
            intervention_effect = intervention_summary.mean_qaly,
            control_cost = control_summary.mean_cost,
            control_effect = control_summary.mean_qaly,
            ce_threshold = 100_000.0
        )
        
        cost_label = @sprintf("HFOV Cost %+d%%", round(Int, (cost_var - 1) * 100))
        if ce_sens.dominated
            println("  ", cost_label, ": DOMINATED")
        elseif ce_sens.cost_difference < 0
            println("  ", cost_label, ": COST-SAVING")
        else
            println("  ", cost_label, ": ICER = ", format_currency(ce_sens.icer), " per QALY")
        end
    end
    println()
    
    # ───────────────────────────────────────────────────────────────
    # Return results for plotting
    # ───────────────────────────────────────────────────────────────
    
    return (
        control_outcomes = control_outcomes,
        intervention_outcomes = intervention_outcomes,
        control_summary = control_summary,
        intervention_summary = intervention_summary,
        ce_result = ce_result
    )
end

# ═══════════════════════════════════════════════════════════════
# PART 5: VISUALIZATION
# ═══════════════════════════════════════════════════════════════

function plot_cost_effectiveness_results(results)
    
    fig = figure(figsize=(14, 10))
    
    # Plot 1: Cost comparison
    ax1 = subplot(2, 3, 1)
    groups = ["Control", "HFOV"]
    costs = [results.control_summary.mean_cost, results.intervention_summary.mean_cost]
    colors = [:lightblue, :lightcoral]
    bar(groups, costs, color=colors, label="Mean Cost per Patient")
    ylabel("Cost (\$)")
    title("Average Cost Comparison")
    for (i, v) in enumerate(costs)
        text(i-0.3, v, format_currency(v), fontsize=9)
    end
    
    # Plot 2: QALY comparison
    ax2 = subplot(2, 3, 2)
    qalys = [results.control_summary.mean_qaly, results.intervention_summary.mean_qaly]
    bar(groups, qalys, color=colors, label="Mean QALY per Patient")
    ylabel("QALYs")
    title("Quality-Adjusted Life Years")
    for (i, v) in enumerate(qalys)
        text(i-0.2, v, @sprintf("%.3f", v), fontsize=9)
    end
    
    # Plot 3: Mortality comparison
    ax3 = subplot(2, 3, 3)
    mortality = [results.control_summary.mortality_rate * 100, 
                 results.intervention_summary.mortality_rate * 100]
    bar(groups, mortality, color=colors)
    ylabel("Mortality Rate (%)")
    title("Mortality Comparison")
    
    # Plot 4: Cost-effectiveness scatter
    ax4 = subplot(2, 3, 4)
    scatter([results.control_summary.mean_cost], [results.control_summary.mean_qaly],
           label="Control", s=200, alpha=0.6, color="blue")
    scatter([results.intervention_summary.mean_cost], [results.intervention_summary.mean_qaly],
           label="HFOV", s=200, alpha=0.6, color="red")
    xlabel("Cost (\$)")
    ylabel("QALYs")
    title("Cost-Effectiveness Plane")
    legend()
    
    # Plot 5: Readmission comparison
    ax5 = subplot(2, 3, 5)
    readmit = [results.control_summary.readmission_30_rate * 100,
               results.intervention_summary.readmission_30_rate * 100]
    bar(groups, readmit, color=colors)
    ylabel("30-Day Readmission Rate (%)")
    title("Readmission Comparison")
    
    # Plot 6: Cost distribution
    ax6 = subplot(2, 3, 6)
    control_costs = [ep.total_cost for ep in results.control_outcomes]
    intervention_costs = [ep.total_cost for ep in results.intervention_outcomes]
    boxplot([control_costs, intervention_costs], labels=groups)
    ylabel("Episode Cost (\$)")
    title("Cost Distribution")
    
    tight_layout()
    return fig
end

# ═══════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════

if abspath(PROGRAM_FILE) == @__FILE__
    results = run_nicu_cost_effectiveness_analysis(500)
    
    # Optionally save results to CSV
    # using CSV
    # CSV.write("nicu_ce_results.csv", results.ce_result)
    
    println("\nAnalysis complete. Results available in 'results' variable.")
end
