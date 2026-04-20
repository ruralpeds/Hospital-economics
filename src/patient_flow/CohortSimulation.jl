# ============================================================================
# COHORT SIMULATION
# ============================================================================
# Simulate entire patient cohort through hospital system with outcome tracking

using Dates
using Statistics
using StatsBase

# ============================================================================
# RESULT TYPES
# ============================================================================

"""
    CohortSimulationResult

Summary results from simulating a patient cohort through the hospital system.

# Fields
- cohort_name::String: Name of the cohort
- n_simulations::Int: Number of independent simulation runs
- n_patients::Int: Number of patients in cohort

# Aggregate Clinical Outcomes
- mean_cost::Float64: Mean episode cost (USD)
- mean_los::Float64: Mean length of stay (days)
- mortality_rate::Float64: In-hospital mortality rate (0-1)
- readmission_30day_rate::Float64: 30-day readmission rate (0-1)
- mean_quality_score::Float64: Mean patient quality/satisfaction (0-1)

# Cost & LOS Distributions
- cost_percentiles::Dict{Float64, Float64}: Percentiles (0.10, 0.25, 0.50, 0.75, 0.90)
- los_percentiles::Dict{Float64, Float64}: Percentiles (0.10, 0.25, 0.50, 0.75, 0.90)
- complication_rate::Float64: % of patients with complications
- mean_complication_count::Float64: Average complications per patient

# Service Line Breakdown
- service_line_metrics::Dict{String, ServiceLineMetrics}: Metrics by service line

# Aggregation
- total_cost::Float64: Sum of all episode costs
- total_patient_days::Float64: Sum of all LOS
"""
struct CohortSimulationResult
    cohort_name::String
    n_simulations::Int
    n_patients::Int

    # Aggregate outcomes
    mean_cost::Float64
    mean_los::Float64
    mortality_rate::Float64
    readmission_30day_rate::Float64
    mean_quality_score::Float64

    # Distributions
    cost_percentiles::Dict{Float64, Float64}
    los_percentiles::Dict{Float64, Float64}
    complication_rate::Float64
    mean_complication_count::Float64

    # Service line breakdown
    service_line_metrics::Dict{String, Dict{String, Float64}}

    # Aggregation
    total_cost::Float64
    total_patient_days::Float64
end

# ============================================================================
# COHORT SIMULATION ENGINE
# ============================================================================

"""
    simulate_cohort(
        cohort::PatientCohort,
        encounters::Vector{PatientEncounter};
        num_simulation_runs::Int = 1
    )::CohortSimulationResult

Simulate entire patient cohort through hospital system with clinical pathways.

Each patient is routed through a clinical pathway based on DRG code, outcomes
are simulated based on pathway distributions and patient risk factors, and
aggregate metrics are computed across all simulations.

# Arguments
- cohort::PatientCohort: Cohort definition with inclusion/exclusion criteria
- encounters::Vector{PatientEncounter}: De-identified encounter data (from Module 1)
- num_simulation_runs::Int: Number of independent simulations to run (default: 1)

# Returns
CohortSimulationResult with aggregate outcomes, distributions, and service line breakdown

# Simulation Process
1. For each simulation run:
   a. For each patient in cohort:
      - Create PatientAgent from encounter data
      - Route to clinical pathway based on DRG
      - Simulate outcomes (mortality, readmission, complications)
      - Calculate quality score
   b. Aggregate all patient outcomes
2. Aggregate results across all simulation runs
3. Calculate percentiles, means, distributions
4. Return comprehensive result summary

# Example
```julia
using HospitalFinanceToolbox

# Load encounters and build cohort (Modules 1-2)
encounters = ingest_csv("encounters.csv", config)
criteria = [PayerCriterion(["Medicare"], include=true)]
cohort = build_cohort(encounters, "Medicare Cohort"; inclusion_criteria=criteria)

# Simulate cohort through hospital (Module 4)
result = simulate_cohort(cohort, encounters; num_simulation_runs=100)

println("Mean cost: USD \$(round(result.mean_cost))")
println("Mortality rate: \$(round(result.mortality_rate * 100, digits=1))%")
println("30-day readmission: \$(round(result.readmission_30day_rate * 100, digits=1))%")
println("Cost 90th percentile: USD \$(round(result.cost_percentiles[0.90]))")
```
"""
function simulate_cohort(
    cohort::PatientCohort,
    encounters::Vector{PatientEncounter};
    num_simulation_runs::Int = 1
)::CohortSimulationResult

    # Accumulate results across all simulation runs
    all_costs = Float64[]
    all_los = Int[]
    all_mortalities = Bool[]
    all_readmissions = Bool[]
    all_quality_scores = Float64[]
    all_complication_counts = Int[]
    service_line_totals = Dict{String, Dict{String, Union{Float64, Int}}}()

    # ────────────────────────────────────────────────────────────────────
    # Run simulations
    # ────────────────────────────────────────────────────────────────────

    for sim_run in 1:num_simulation_runs
        # Track outcomes for this simulation
        sim_costs = Float64[]
        sim_los = Int[]
        sim_mortalities = Bool[]
        sim_readmissions = Bool[]
        sim_quality_scores = Float64[]
        sim_complication_counts = Int[]
        sim_service_lines = Dict{String, Dict{String, Union{Float64, Int}}}()

        # ────────────────────────────────────────────────────────────────────
        # Simulate each patient in cohort
        # ────────────────────────────────────────────────────────────────────

        for encounter in encounters
            # Skip if not in cohort (not in encounter_ids)
            if !(encounter.encounter_id in cohort.encounter_ids)
                continue
            end

            # Create patient agent from encounter
            patient = PatientAgent(
                id = encounter.patient_id,
                admission_date = encounter.admission_date,
                primary_diagnosis = encounter.primary_diagnosis,
                secondary_diagnoses = encounter.secondary_diagnoses,
                drg_code = "",  # Will be populated from DRG mapping if available
                assigned_service_line = "General",
                cumulative_cost = encounter.total_charges,
                procedures = encounter.procedures,
                payer = encounter.payer,
                comorbidity_count = length(encounter.secondary_diagnoses),
                metadata = Dict(
                    "age" => encounter.age_at_admission,
                    "actual_los" => encounter.length_of_stay
                )
            )

            # Set discharge date
            patient.discharge_date = encounter.discharge_date

            # Route to clinical pathway if pathway exists for this DRG
            try
                pathway = route_to_pathway(encounter.primary_diagnosis)
                # Simulate outcomes based on pathway
                simulate_patient_outcomes!(patient, pathway)
            catch
                # Pathway not found, use defaults
                pathway = ClinicalPathway(
                    "", "", "", 0, String[], "",
                    0.0, 0.0, 0.0, 0.75,
                    0.0, 0.0,
                    0, 0, 0, 0, "", "", Dict()
                )
                simulate_patient_outcomes!(patient, pathway)
            end

            # Track outcomes
            push!(sim_costs, patient.cumulative_cost)
            actual_los = Dates.value(encounter.discharge_date - encounter.admission_date)
            push!(sim_los, actual_los)
            push!(sim_mortalities, patient.mortality)
            push!(sim_readmissions, patient.readmission_status)
            push!(sim_quality_scores, patient.quality_score)
            push!(sim_complication_counts, length(patient.complication_codes))

            # Track by service line
            service_line = patient.assigned_service_line
            if !haskey(sim_service_lines, service_line)
                sim_service_lines[service_line] = Dict(
                    "count" => 0,
                    "total_cost" => 0.0,
                    "total_los" => 0,
                    "mortality_count" => 0,
                    "readmission_count" => 0,
                    "mean_quality" => 0.0
                )
            end

            sim_service_lines[service_line]["count"] += 1
            sim_service_lines[service_line]["total_cost"] += patient.cumulative_cost
            sim_service_lines[service_line]["total_los"] += actual_los
            sim_service_lines[service_line]["mortality_count"] += patient.mortality ? 1 : 0
            sim_service_lines[service_line]["readmission_count"] += patient.readmission_status ? 1 : 0
            sim_service_lines[service_line]["mean_quality"] += patient.quality_score
        end

        # Accumulate this simulation's results
        append!(all_costs, sim_costs)
        append!(all_los, sim_los)
        append!(all_mortalities, sim_mortalities)
        append!(all_readmissions, sim_readmissions)
        append!(all_quality_scores, sim_quality_scores)
        append!(all_complication_counts, sim_complication_counts)

        # Aggregate service line metrics
        for (service_line, metrics) in sim_service_lines
            if !haskey(service_line_totals, service_line)
                service_line_totals[service_line] = Dict(
                    "count" => 0,
                    "total_cost" => 0.0,
                    "total_los" => 0,
                    "mortality_count" => 0,
                    "readmission_count" => 0,
                    "mean_quality" => 0.0
                )
            end

            service_line_totals[service_line]["count"] += metrics["count"]
            service_line_totals[service_line]["total_cost"] += metrics["total_cost"]
            service_line_totals[service_line]["total_los"] += metrics["total_los"]
            service_line_totals[service_line]["mortality_count"] += metrics["mortality_count"]
            service_line_totals[service_line]["readmission_count"] += metrics["readmission_count"]
            service_line_totals[service_line]["mean_quality"] += metrics["mean_quality"]
        end
    end

    # ────────────────────────────────────────────────────────────────────
    # Aggregate results across simulations
    # ────────────────────────────────────────────────────────────────────

    mean_cost = isempty(all_costs) ? 0.0 : mean(all_costs)
    mean_los = isempty(all_los) ? 0.0 : mean(all_los)
    mortality_rate = isempty(all_mortalities) ? 0.0 : sum(all_mortalities) / length(all_mortalities)
    readmission_rate = isempty(all_readmissions) ? 0.0 : sum(all_readmissions) / length(all_readmissions)
    mean_quality = isempty(all_quality_scores) ? 0.0 : mean(all_quality_scores)
    complication_rate = isempty(all_complication_counts) ? 0.0 : sum(all_complication_counts .> 0) / length(all_complication_counts)
    mean_complication_count = isempty(all_complication_counts) ? 0.0 : mean(all_complication_counts)

    # Calculate percentiles
    cost_percentiles = Dict{Float64, Float64}()
    los_percentiles = Dict{Float64, Float64}()

    if !isempty(all_costs)
        cost_percentiles = Dict(
            0.10 => quantile(all_costs, 0.10),
            0.25 => quantile(all_costs, 0.25),
            0.50 => quantile(all_costs, 0.50),
            0.75 => quantile(all_costs, 0.75),
            0.90 => quantile(all_costs, 0.90)
        )
    end

    if !isempty(all_los)
        los_percentiles = Dict(
            0.10 => quantile(all_los, 0.10),
            0.25 => quantile(all_los, 0.25),
            0.50 => quantile(all_los, 0.50),
            0.75 => quantile(all_los, 0.75),
            0.90 => quantile(all_los, 0.90)
        )
    end

    # ────────────────────────────────────────────────────────────────────
    # Calculate service line metrics
    # ────────────────────────────────────────────────────────────────────

    service_line_metrics = Dict{String, Dict{String, Float64}}()
    for (service_line, totals) in service_line_totals
        count = totals["count"]
        if count > 0
            service_line_metrics[service_line] = Dict(
                "count" => Float64(count),
                "mean_cost" => totals["total_cost"] / count,
                "mean_los" => totals["total_los"] / count,
                "mortality_rate" => totals["mortality_count"] / count,
                "readmission_rate" => totals["readmission_count"] / count,
                "mean_quality_score" => totals["mean_quality"] / count
            )
        end
    end

    # ────────────────────────────────────────────────────────────────────
    # Create and return result
    # ────────────────────────────────────────────────────────────────────

    return CohortSimulationResult(
        cohort.name,
        num_simulation_runs,
        cohort.size,
        mean_cost,
        mean_los,
        mortality_rate,
        readmission_rate,
        mean_quality,
        cost_percentiles,
        los_percentiles,
        complication_rate,
        mean_complication_count,
        service_line_metrics,
        sum(all_costs),
        sum(all_los)
    )
end

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

"""
    format_cohort_simulation_result(result::CohortSimulationResult)::String

Format cohort simulation result as human-readable string.
"""
function format_cohort_simulation_result(result::CohortSimulationResult)::String
    io = IOBuffer()

    println(io, "╔════════════════════════════════════════════════════════════════════╗")
    println(io, "║          COHORT SIMULATION RESULTS                                ║")
    println(io, "╚════════════════════════════════════════════════════════════════════╝")
    println(io, "")

    # Header
    println(io, "Cohort: $(result.cohort_name)")
    println(io, "Patients: $(result.n_patients)")
    println(io, "Simulations: $(result.n_simulations)")
    println(io, "")

    # Financial
    println(io, "──── FINANCIAL ────────────────────────────────────────────────────")
    println(io, "Mean Cost:        USD \$(format(result.mean_cost, 0))")
    println(io, "Total Cost:       USD \$(format(result.total_cost, 0))")
    println(io, "Cost P10:         USD \$(format(result.cost_percentiles[0.10], 0))")
    println(io, "Cost Median:      USD \$(format(result.cost_percentiles[0.50], 0))")
    println(io, "Cost P90:         USD \$(format(result.cost_percentiles[0.90], 0))")
    println(io, "")

    # Clinical
    println(io, "──── CLINICAL OUTCOMES ────────────────────────────────────────────")
    println(io, "Mean LOS:         $(round(result.mean_los, digits=1)) days")
    println(io, "LOS Median:       $(round(result.los_percentiles[0.50], digits=1)) days")
    println(io, "LOS P90:          $(round(result.los_percentiles[0.90], digits=1)) days")
    println(io, "")

    # Outcomes
    println(io, "──── OUTCOMES ─────────────────────────────────────────────────────")
    println(io, "Mortality:        $(round(result.mortality_rate * 100, digits=1))%")
    println(io, "Readmission 30d:  $(round(result.readmission_30day_rate * 100, digits=1))%")
    println(io, "Complication:     $(round(result.complication_rate * 100, digits=1))%")
    println(io, "Mean Quality:     $(round(result.mean_quality, digits=3))/1.0")
    println(io, "")

    # Service lines
    if !isempty(result.service_line_metrics)
        println(io, "──── BY SERVICE LINE ──────────────────────────────────────────────")
        for (service_line, metrics) in result.service_line_metrics
            println(io, "  $service_line:")
            println(io, "    Count: $(Int(metrics["count"]))")
            println(io, "    Mean Cost: USD $(format(metrics["mean_cost"], 0))")
            println(io, "    Mean LOS: $(round(metrics["mean_los"], digits=1)) days")
            println(io, "    Mortality: $(round(metrics["mortality_rate"] * 100, digits=1))%")
            println(io, "    Quality: $(round(metrics["mean_quality_score"], digits=3))/1.0")
        end
    end

    return String(take!(io))
end

# Helper for number formatting
function format(value::Real, decimals::Int)::String
    if value >= 1_000_000
        return "\$" * "$(round(value/1_000_000, digits=1))M"
    elseif value >= 1_000
        return "\$" * "$(round(value/1_000, digits=0))K"
    else
        return "\$" * "$(round(value, digits=decimals))"
    end
end
