"""
    example_02_readmission_prevention_roi.jl

Readmission Prevention ROI Analysis:
Evaluating the cost-effectiveness of a care coordination program

This example demonstrates:
1. Readmission risk modeling
2. Intervention impact simulation
3. Return on investment (ROI) calculation
4. Cost per readmission prevented
5. Multi-payer impact analysis

Scenario:
- 1,000 heart failure patients
- Post-discharge care coordination program
- Goal: Reduce 30-day readmissions by 25%
- Cost: $150 per patient
- Time horizon: 12 months
"""

using HospitalFinanceToolbox
using Distributions
using Random
using Statistics

Random.seed!(123)

# ═══════════════════════════════════════════════════════════════
# PART 1: BASELINE READMISSION RATES BY CONDITION
# ═══════════════════════════════════════════════════════════════

"""Baseline readmission rates from literature"""
const BASELINE_READMISSION_RATES = Dict(
    "I50.9" => (rate=0.24, cost=8_500.0, description="Heart failure"),
    "J18.9" => (rate=0.18, cost=7_200.0, description="Pneumonia"),
    "K65.9" => (rate=0.22, cost=9_800.0, description="Peritonitis"),
    "I63.9" => (rate=0.15, cost=11_200.0, description="Acute stroke"),
    "N18.3" => (rate=0.20, cost=6_500.0, description="Chronic kidney disease"),
)

# ═══════════════════════════════════════════════════════════════
# PART 2: INTERVENTION MODEL
# ═══════════════════════════════════════════════════════════════

"""Readmission prevention intervention"""
struct ReadmissionPreventionProgram
    name::String
    implementation_cost::Float64        # $ per patient
    maintenance_cost_monthly::Float64   # $ per month
    adherence_rate::Float64             # % of patients adhering
    readmission_reduction::Float64      # % reduction in readmissions
    program_duration_months::Int
end

"""Default program: Standard care coordination"""
function standard_care_coordination()::ReadmissionPreventionProgram
    ReadmissionPreventionProgram(
        name = "Standard Care Coordination",
        implementation_cost = 150.0,
        maintenance_cost_monthly = 25.0,
        adherence_rate = 0.75,
        readmission_reduction = 0.25,
        program_duration_months = 12
    )
end

"""Enhanced program: With telehealth monitoring"""
function enhanced_care_coordination()::ReadmissionPreventionProgram
    ReadmissionPreventionProgram(
        name = "Enhanced Care Coordination + Telehealth",
        implementation_cost = 250.0,
        maintenance_cost_monthly = 45.0,
        adherence_rate = 0.85,
        readmission_reduction = 0.35,
        program_duration_months = 12
    )
end

# ═══════════════════════════════════════════════════════════════
# PART 3: PATIENT COHORT SIMULATION
# ═══════════════════════════════════════════════════════════════

"""Generate synthetic patient cohort by diagnosis"""
function generate_patient_cohort(diagnosis::String, n_patients::Int)::Vector{Episode}
    episodes = Episode[]
    
    for i in 1:n_patients
        episode = Episode(
            episode_id = "readmit_$(diagnosis)_$i",
            patient_id = "PT_$i",
            admission_date = Date(2024, 1, 1) + Day(rand(0:365)),
            discharge_date = Date(2024, 1, 8) + Day(rand(0:365)),
            primary_diagnosis = diagnosis,
            drg_code = "999",  # Simplified
            payer = rand([:Medicare, :Medicaid, :Commercial])
        )
        push!(episodes, episode)
    end
    
    return episodes
end

"""Simulate readmissions under control condition"""
function simulate_readmissions_control(
    diagnosis::String,
    cohort_size::Int
)::Tuple{Int, Float64}
    
    baseline = BASELINE_READMISSION_RATES[diagnosis]
    readmission_rate = baseline.rate
    readmission_cost = baseline.cost
    
    n_readmissions = 0
    total_readmit_cost = 0.0
    
    for i in 1:cohort_size
        if rand() < readmission_rate
            n_readmissions += 1
            total_readmit_cost += readmission_cost
        end
    end
    
    return (n_readmissions, total_readmit_cost)
end

"""Simulate readmissions under intervention"""
function simulate_readmissions_intervention(
    diagnosis::String,
    cohort_size::Int,
    program::ReadmissionPreventionProgram
)::Tuple{Int, Float64}
    
    baseline = BASELINE_READMISSION_RATES[diagnosis]
    baseline_rate = baseline.rate
    readmission_cost = baseline.cost
    
    # Adjusted rate with program effect
    # Only adherent patients benefit
    adjusted_rate = baseline_rate * (1 - (program.adherence_rate * program.readmission_reduction))
    
    n_readmissions = 0
    total_readmit_cost = 0.0
    
    for i in 1:cohort_size
        if rand() < adjusted_rate
            n_readmissions += 1
            total_readmit_cost += readmission_cost
        end
    end
    
    return (n_readmissions, total_readmit_cost)
end

# ═══════════════════════════════════════════════════════════════
# PART 4: COST ANALYSIS
# ═══════════════════════════════════════════════════════════════

"""Calculate program costs"""
function calculate_program_costs(
    cohort_size::Int,
    program::ReadmissionPreventionProgram
)::Tuple{Float64, Float64, Float64}
    
    implementation = cohort_size * program.implementation_cost
    maintenance = cohort_size * program.maintenance_cost_monthly * program.program_duration_months
    total = implementation + maintenance
    
    return (implementation, maintenance, total)
end

"""Calculate net benefit"""
function calculate_program_benefit(
    diagnosis::String,
    cohort_size::Int,
    program::ReadmissionPreventionProgram
)::Dict{String, Float64}
    
    # Baseline (control)
    control_readmits, control_cost = simulate_readmissions_control(diagnosis, cohort_size)
    
    # Intervention
    intervention_readmits, intervention_cost = simulate_readmissions_intervention(
        diagnosis, cohort_size, program
    )
    
    # Program costs
    impl_cost, maint_cost, total_program_cost = calculate_program_costs(cohort_size, program)
    
    # Calculate benefits
    readmissions_prevented = control_readmits - intervention_readmits
    readmission_cost_saved = control_cost - intervention_cost
    net_savings = readmission_cost_saved - total_program_cost
    
    # Cost per readmission prevented
    if readmissions_prevented > 0
        cost_per_prevented = total_program_cost / readmissions_prevented
    else
        cost_per_prevented = Inf
    end
    
    return Dict(
        "diagnosis" => diagnosis,
        "cohort_size" => cohort_size,
        "baseline_readmissions" => control_readmits,
        "intervention_readmissions" => intervention_readmits,
        "readmissions_prevented" => readmissions_prevented,
        "baseline_readmit_cost" => control_cost,
        "intervention_readmit_cost" => intervention_cost,
        "readmission_cost_saved" => readmission_cost_saved,
        "program_implementation_cost" => impl_cost,
        "program_maintenance_cost" => maint_cost,
        "total_program_cost" => total_program_cost,
        "net_savings" => net_savings,
        "cost_per_readmission_prevented" => cost_per_prevented,
        "roi_percentage" => (net_savings / total_program_cost) * 100,
        "baseline_readmission_rate" => control_readmits / cohort_size,
        "intervention_readmission_rate" => intervention_readmits / cohort_size
    )
end

# ═══════════════════════════════════════════════════════════════
# PART 5: MAIN ANALYSIS
# ═══════════════════════════════════════════════════════════════

"""Run comprehensive readmission prevention ROI analysis"""
function run_readmission_prevention_analysis(cohort_size::Int = 1_000)
    
    println("=" ^ 80)
    println("READMISSION PREVENTION PROGRAM ROI ANALYSIS")
    println("=" ^ 80)
    println("\nCohort Size: $cohort_size patients")
    println("Time Horizon: 12 months post-discharge")
    println()
    
    # ───────────────────────────────────────────────────────────────
    # Analyze standard program
    # ───────────────────────────────────────────────────────────────
    
    program = standard_care_coordination()
    
    println("PROGRAM: ", program.name)
    println("-" ^ 80)
    println("  Implementation Cost:      ", format_currency(program.implementation_cost), " per patient")
    println("  Monthly Maintenance:      ", format_currency(program.maintenance_cost_monthly), " per patient")
    println("  Adherence Rate:           ", format_percentage(program.adherence_rate))
    println("  Expected Readmission Red: ", format_percentage(program.readmission_reduction))
    println()
    
    # Analyze by diagnosis
    results = Dict{String, Dict}()
    
    for (diagnosis, info) in BASELINE_READMISSION_RATES
        benefit = calculate_program_benefit(diagnosis, cohort_size, program)
        results[diagnosis] = benefit
    end
    
    # Print detailed results
    println("RESULTS BY DIAGNOSIS")
    println("-" ^ 80)
    
    total_prevented = 0
    total_saved = 0.0
    total_program_cost = 0.0
    total_net_benefit = 0.0
    
    for (diagnosis, result) in results
        info = BASELINE_READMISSION_RATES[diagnosis]
        println("\n$(info.description) ($diagnosis)")
        println("  Baseline readmissions:         ", Int(result["baseline_readmissions"]))
        println("  Intervention readmissions:     ", Int(result["intervention_readmissions"]))
        println("  Readmissions prevented:        ", Int(result["readmissions_prevented"]))
        println("  Readmission rate (baseline):   ", format_percentage(result["baseline_readmission_rate"]))
        println("  Readmission rate (after prog): ", format_percentage(result["intervention_readmission_rate"]))
        println("  ")
        println("  Readmission cost saved:        ", format_currency(result["readmission_cost_saved"]))
        println("  Program cost (total):          ", format_currency(result["total_program_cost"]))
        println("  Net savings:                   ", format_currency(result["net_savings"]))
        println("  ")
        if result["readmissions_prevented"] > 0
            println("  Cost per readmission prevented: ", format_currency(result["cost_per_readmission_prevented"]))
        end
        println("  ROI:                           ", @sprintf("%.1f%%", result["roi_percentage"]))
        
        total_prevented += result["readmissions_prevented"]
        total_saved += result["readmission_cost_saved"]
        total_program_cost += result["total_program_cost"]
        total_net_benefit += result["net_savings"]
    end
    
    # ───────────────────────────────────────────────────────────────
    # SUMMARY
    # ───────────────────────────────────────────────────────────────
    
    println()
    println()
    println("SYSTEM-WIDE IMPACT SUMMARY")
    println("=" ^ 80)
    println("  Total Patients:                ", cohort_size * length(results))
    println("  Total Readmissions Prevented:  ", Int(total_prevented))
    println("  Total Cost Saved (readmit):    ", format_currency(total_saved))
    println("  Total Program Cost:            ", format_currency(total_program_cost))
    println("  Net System Benefit:            ", format_currency(total_net_benefit))
    println("  System-wide ROI:               ", @sprintf("%.1f%%", (total_net_benefit / total_program_cost) * 100))
    println()
    
    # ───────────────────────────────────────────────────────────────
    # PROGRAM COMPARISON
    # ───────────────────────────────────────────────────────────────
    
    println()
    println("PROGRAM COMPARISON")
    println("=" ^ 80)
    
    programs = [standard_care_coordination(), enhanced_care_coordination()]
    program_results = Dict()
    
    for prog in programs
        total_prog_cost = 0.0
        total_prev = 0
        
        for (diagnosis, _) in BASELINE_READMISSION_RATES
            benefit = calculate_program_benefit(diagnosis, cohort_size, prog)
            total_prog_cost += benefit["total_program_cost"]
            total_prev += benefit["readmissions_prevented"]
        end
        
        program_results[prog.name] = (
            cost = total_prog_cost,
            prevented = total_prev,
            cost_per_prevented = total_prog_cost / max(total_prev, 1)
        )
    end
    
    println()
    for (prog_name, results_summary) in program_results
        println("$prog_name:")
        println("  Total Program Cost:            ", format_currency(results_summary.cost))
        println("  Readmissions Prevented:        ", Int(results_summary.prevented))
        println("  Cost Per Readmission Prevented: ", format_currency(results_summary.cost_per_prevented))
        println()
    end
    
    # ───────────────────────────────────────────────────────────────
    # BREAK-EVEN ANALYSIS
    # ───────────────────────────────────────────────────────────────
    
    println()
    println("BREAK-EVEN ANALYSIS")
    println("=" ^ 80)
    
    program_std = standard_care_coordination()
    benefit_std = calculate_program_benefit("I50.9", cohort_size, program_std)
    
    # At what reduction rate does program break even?
    readmit_cost = BASELINE_READMISSION_RATES["I50.9"].cost
    total_cost = benefit_std["total_program_cost"]
    baseline_readmits = benefit_std["baseline_readmissions"]
    
    breakeven_prevented = total_cost / readmit_cost
    breakeven_rate = breakeven_prevented / baseline_readmits
    
    println("  (For Heart Failure cohort)")
    println("  ")
    println("  Readmission cost (per case):   ", format_currency(readmit_cost))
    println("  Program cost:                  ", format_currency(total_cost))
    println("  Readmissions needed prevented: ", Int(breakeven_prevented))
    println("  Break-even rate:               ", format_percentage(breakeven_rate))
    println("  Current rate achieved:         ", format_percentage(benefit_std["readmissions_prevented"] / baseline_readmits))
    
    if benefit_std["readmissions_prevented"] >= breakeven_prevented
        println("  ")
        println("  ✅ Program EXCEEDS break-even threshold")
    else
        println("  ")
        println("  ❌ Program BELOW break-even threshold")
    end
    
    println()
    
    return results
end

# ═══════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════

if abspath(PROGRAM_FILE) == @__FILE__
    results = run_readmission_prevention_analysis(1_000)
    
    println("\n✅ Analysis complete.")
    println("Results available in 'results' variable.")
end
