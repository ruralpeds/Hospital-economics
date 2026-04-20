# ============================================================================
# PATIENT COHORT BUILDER
# ============================================================================
# Flexible cohort construction with inclusion/exclusion criteria

using Dates
using Statistics
using UUIDs

include(joinpath(@__DIR__, "cohort_types.jl"))

# ============================================================================
# CRITERION EVALUATION
# ============================================================================

"""
    apply_age_criterion(enc::PatientEncounter, criterion::AgeCriterion)::Bool

Evaluate age inclusion/exclusion criterion for a patient encounter.
"""
function apply_age_criterion(enc::PatientEncounter, criterion::AgeCriterion)::Bool
    matches = enc.age_at_admission >= criterion.min_age &&
              enc.age_at_admission <= criterion.max_age
    criterion.include ? matches : !matches
end

"""
    apply_diagnosis_criterion(enc::PatientEncounter, criterion::DiagnosisCriterion)::Bool

Evaluate diagnosis inclusion/exclusion criterion.
"""
function apply_diagnosis_criterion(enc::PatientEncounter, criterion::DiagnosisCriterion)::Bool
    if criterion.match_type == "primary"
        matches = any(startswith(enc.primary_diagnosis, code) for code in criterion.icd10_codes)
    else  # "any"
        all_diagnoses = [enc.primary_diagnosis; enc.secondary_diagnoses]
        matches = any(d != "" && any(startswith(d, code) for code in criterion.icd10_codes) for d in all_diagnoses)
    end
    criterion.include ? matches : !matches
end

"""
    apply_procedure_criterion(enc::PatientEncounter, criterion::ProcedureCriterion)::Bool

Evaluate procedure inclusion/exclusion criterion.
"""
function apply_procedure_criterion(enc::PatientEncounter, criterion::ProcedureCriterion)::Bool
    if criterion.require_all
        matches = all(any(startswith(p, code) for p in enc.procedures) for code in criterion.cpt_codes)
    else
        matches = any(p != "" && any(startswith(p, code) for code in criterion.cpt_codes) for p in enc.procedures)
    end
    criterion.include ? matches : !matches
end

"""
    apply_cost_criterion(enc::PatientEncounter, criterion::CostCriterion)::Bool

Evaluate cost range inclusion/exclusion criterion.
"""
function apply_cost_criterion(enc::PatientEncounter, criterion::CostCriterion)::Bool
    matches = enc.total_charges >= criterion.min_cost &&
              enc.total_charges <= criterion.max_cost
    criterion.include ? matches : !matches
end

"""
    apply_los_criterion(enc::PatientEncounter, criterion::LengthOfStayCriterion)::Bool

Evaluate length of stay inclusion/exclusion criterion.
"""
function apply_los_criterion(enc::PatientEncounter, criterion::LengthOfStayCriterion)::Bool
    matches = enc.length_of_stay >= criterion.min_los &&
              enc.length_of_stay <= criterion.max_los
    criterion.include ? matches : !matches
end

"""
    apply_payer_criterion(enc::PatientEncounter, criterion::PayerCriterion)::Bool

Evaluate payer type inclusion/exclusion criterion.
"""
function apply_payer_criterion(enc::PatientEncounter, criterion::PayerCriterion)::Bool
    matches = any(payer == enc.payer for payer in criterion.payers)
    criterion.include ? matches : !matches
end

"""
    apply_date_criterion(enc::PatientEncounter, criterion::DateRangeCriterion)::Bool

Evaluate admission date range inclusion/exclusion criterion.
"""
function apply_date_criterion(enc::PatientEncounter, criterion::DateRangeCriterion)::Bool
    matches = enc.admission_date >= criterion.start_date &&
              enc.admission_date <= criterion.end_date
    criterion.include ? matches : !matches
end

"""
    evaluate_criteria(enc::PatientEncounter, criteria::Vector{CriterionType})::Bool

Evaluate all criteria for an encounter. All criteria must pass (AND logic).

Returns true only if encounter passes ALL inclusion criteria and NONE of exclusion.
"""
function evaluate_criteria(enc::PatientEncounter, criteria::Vector{CriterionType})::Bool
    for criterion in criteria
        if criterion isa AgeCriterion
            !apply_age_criterion(enc, criterion) && return false
        elseif criterion isa DiagnosisCriterion
            !apply_diagnosis_criterion(enc, criterion) && return false
        elseif criterion isa ProcedureCriterion
            !apply_procedure_criterion(enc, criterion) && return false
        elseif criterion isa CostCriterion
            !apply_cost_criterion(enc, criterion) && return false
        elseif criterion isa LengthOfStayCriterion
            !apply_los_criterion(enc, criterion) && return false
        elseif criterion isa PayerCriterion
            !apply_payer_criterion(enc, criterion) && return false
        elseif criterion isa DateRangeCriterion
            !apply_date_criterion(enc, criterion) && return false
        end
    end
    true
end

# ============================================================================
# COHORT STATISTICS CALCULATION
# ============================================================================

"""
    calculate_cohort_statistics(encounters::Vector{PatientEncounter})::CohortStatistics

Compute descriptive statistics for a cohort.
"""
function calculate_cohort_statistics(encounters::Vector{PatientEncounter})::CohortStatistics
    if isempty(encounters)
        return CohortStatistics()
    end

    stats = CohortStatistics()
    stats.size = length(encounters)

    # Age statistics
    ages = [enc.age_at_admission for enc in encounters if enc.age_at_admission > 0]
    if !isempty(ages)
        stats.age_mean = mean(ages)
        stats.age_median = median(ages)
        stats.age_std = std(ages)
    end

    # Sex distribution
    stats.sex_distribution = Dict{String, Int}()
    for sex in ["M", "F", "O"]
        count = sum(enc.sex == sex for enc in encounters)
        count > 0 && (stats.sex_distribution[sex] = count)
    end

    # Race distribution
    stats.race_distribution = Dict{String, Int}()
    for race in ["W", "B", "H", "A", "N", "2+", "O"]
        count = sum(enc.race_code == race for enc in encounters)
        count > 0 && (stats.race_distribution[race] = count)
    end

    # Payer distribution
    payer_totals = Dict{String, Int}()
    for enc in encounters
        payer_totals[enc.payer] = get(payer_totals, enc.payer, 0) + 1
    end
    for (payer, count) in payer_totals
        stats.payer_distribution[payer] = round(count / stats.size * 100, digits=1)
    end

    # Cost statistics
    costs = [enc.total_charges for enc in encounters if enc.total_charges > 0]
    if !isempty(costs)
        stats.cost_mean = mean(costs)
        stats.cost_median = median(costs)
        stats.cost_std = std(costs)
    end

    # Length of stay statistics
    los_values = [enc.length_of_stay for enc in encounters if enc.length_of_stay > 0]
    if !isempty(los_values)
        stats.los_mean = mean(los_values)
        stats.los_median = Int(median(los_values))
        stats.los_std = std(los_values)
    end

    # Top 10 diagnoses
    diagnosis_counts = Dict{String, Int}()
    for enc in encounters
        enc.primary_diagnosis != "" &&
            (diagnosis_counts[enc.primary_diagnosis] = get(diagnosis_counts, enc.primary_diagnosis, 0) + 1)
    end
    top_diagnoses = sort(collect(diagnosis_counts), by=x->x[2], rev=true)[1:min(10, length(diagnosis_counts))]
    stats.primary_diagnosis_top10 = top_diagnoses

    stats
end

# ============================================================================
# MAIN COHORT BUILDER
# ============================================================================

"""
    build_cohort(
        encounters::Vector{PatientEncounter},
        name::String;
        inclusion_criteria::Vector{CriterionType} = CriterionType[],
        exclusion_criteria::Vector{CriterionType} = CriterionType[],
        metadata::Dict{String, Any} = Dict()
    )::PatientCohort

Build a patient cohort from encounters using flexible inclusion/exclusion criteria.

# Arguments
- encounters: Vector of PatientEncounter (de-identified)
- name: Human-readable cohort name
- inclusion_criteria: Criteria that must ALL be satisfied
- exclusion_criteria: Criteria that must ALL NOT be satisfied
- metadata: Additional context (analyst, study name, notes)

# Returns
- PatientCohort: Fully specified cohort with statistics

# Example
```julia
# Build cohort of Medicare beneficiaries with diabetes, age 65+
criteria = [
    PayerCriterion(["Medicare"], include=true),
    DiagnosisCriterion(["E11", "E13"], "primary", include=true),
    AgeCriterion(65, 120, include=true),
]

cohort = build_cohort(
    encounters,
    "Medicare Diabetes Cohort";
    inclusion_criteria = criteria
)

println("Cohort size: \$(cohort.size)")
println("Mean age: \$(round(cohort.statistics.age_mean))")
```
"""
function build_cohort(
    encounters::Vector{PatientEncounter},
    name::String;
    inclusion_criteria::Vector{CriterionType} = CriterionType[],
    exclusion_criteria::Vector{CriterionType} = CriterionType[],
    metadata::Dict{String, Any} = Dict(),
)::PatientCohort

    # Apply inclusion and exclusion criteria
    included_encounters = PatientEncounter[]
    included_patient_ids = Set{String}()
    included_encounter_ids = Set{String}()

    for enc in encounters
        # Must pass ALL inclusion criteria
        passes_inclusion = isempty(inclusion_criteria) ||
                          evaluate_criteria(enc, inclusion_criteria)

        # Must pass ALL exclusion criteria (inverse)
        passes_exclusion = isempty(exclusion_criteria) ||
                          evaluate_criteria(enc, exclusion_criteria)

        if passes_inclusion && passes_exclusion
            push!(included_encounters, enc)
            push!(included_patient_ids, enc.patient_id)
            push!(included_encounter_ids, enc.encounter_id)
        end
    end

    # Calculate statistics
    stats = calculate_cohort_statistics(included_encounters)

    # Create cohort object
    cohort = PatientCohort(
        name;
        inclusion_criteria = inclusion_criteria,
        exclusion_criteria = exclusion_criteria,
        metadata = metadata,
    )

    # Update with results
    cohort_with_results = PatientCohort(
        cohort.cohort_id,
        cohort.name,
        cohort.description,
        collect(included_patient_ids),
        collect(included_encounter_ids),
        length(included_encounters),
        inclusion_criteria,
        exclusion_criteria,
        stats,
        cohort.creation_date,
        now(),
        metadata,
    )

    cohort_with_results
end

