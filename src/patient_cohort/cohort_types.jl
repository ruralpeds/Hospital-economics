# ============================================================================
# PATIENT COHORT DATA STRUCTURES
# ============================================================================
# Core types for flexible patient cohort building with inclusion/exclusion logic

using Dates
using Statistics
using DataFrames

# ============================================================================
# CRITERION TYPES (Flexible Inclusion/Exclusion Logic)
# ============================================================================

"""
    CriterionType

Abstract base for cohort inclusion/exclusion criteria.
Supports age, diagnosis, cost, procedure, and time-based filtering.
"""
abstract type CriterionType end

"""
    AgeCriterion

Include/exclude patients by age range.

# Fields
- min_age::Int: Minimum age (inclusive)
- max_age::Int: Maximum age (inclusive)
- include::Bool: true = include, false = exclude
"""
struct AgeCriterion <: CriterionType
    min_age::Int
    max_age::Int
    include::Bool
end

"""
    DiagnosisCriterion

Include/exclude patients by primary or secondary diagnosis.

# Fields
- icd10_codes::Vector{String}: ICD-10 codes to match (e.g., ["E11", "E13"])
- match_type::String: "primary" (primary diagnosis only) or "any" (primary or secondary)
- include::Bool: true = include, false = exclude
"""
struct DiagnosisCriterion <: CriterionType
    icd10_codes::Vector{String}
    match_type::String  # "primary" or "any"
    include::Bool
end

"""
    ProcedureCriterion

Include/exclude patients by procedure codes.

# Fields
- cpt_codes::Vector{String}: CPT codes to match
- require_all::Bool: true = must have ALL codes, false = at least ONE code
- include::Bool: true = include, false = exclude
"""
struct ProcedureCriterion <: CriterionType
    cpt_codes::Vector{String}
    require_all::Bool
    include::Bool
end

"""
    CostCriterion

Include/exclude patients by encounter cost.

# Fields
- min_cost::Float64: Minimum total charges (USD)
- max_cost::Float64: Maximum total charges (USD)
- include::Bool: true = include, false = exclude
"""
struct CostCriterion <: CriterionType
    min_cost::Float64
    max_cost::Float64
    include::Bool
end

"""
    LengthOfStayCriterion

Include/exclude patients by length of stay (days).

# Fields
- min_los::Int: Minimum LOS (days)
- max_los::Int: Maximum LOS (days)
- include::Bool: true = include, false = exclude
"""
struct LengthOfStayCriterion <: CriterionType
    min_los::Int
    max_los::Int
    include::Bool
end

"""
    PayerCriterion

Include/exclude patients by insurance payer.

# Fields
- payers::Vector{String}: Payer names (Medicare, Medicaid, Commercial, Uninsured)
- include::Bool: true = include, false = exclude
"""
struct PayerCriterion <: CriterionType
    payers::Vector{String}
    include::Bool
end

"""
    DateRangeCriterion

Include/exclude patients by admission date.

# Fields
- start_date::Date: Earliest admission date (inclusive)
- end_date::Date: Latest admission date (inclusive)
- include::Bool: true = include, false = exclude
"""
struct DateRangeCriterion <: CriterionType
    start_date::Date
    end_date::Date
    include::Bool
end

# ============================================================================
# COHORT STATISTICS & SUMMARIES
# ============================================================================

"""
    CohortStatistics

Descriptive statistics for a patient cohort.

# Fields
- size::Int: Number of patients
- age_mean::Float64: Mean age
- age_median::Float64: Median age
- age_std::Float64: Standard deviation of age
- sex_distribution::Dict{String, Int}: Count by sex (M/F/O)
- race_distribution::Dict{String, Int}: Count by race code
- payer_distribution::Dict{String, Float64}: % by payer
- primary_diagnosis_top10::Vector{Tuple{String, Int}}: Top 10 diagnoses (code, count)
- cost_mean::Float64: Mean total charges (USD)
- cost_median::Float64: Median total charges
- cost_std::Float64: Std dev of charges
- los_mean::Float64: Mean length of stay (days)
- los_median::Int: Median LOS
- los_std::Float64: Std dev of LOS
"""
mutable struct CohortStatistics
    size::Int
    age_mean::Float64
    age_median::Float64
    age_std::Float64
    sex_distribution::Dict{String, Int}
    race_distribution::Dict{String, Int}
    payer_distribution::Dict{String, Float64}
    primary_diagnosis_top10::Vector{Tuple{String, Int}}
    cost_mean::Float64
    cost_median::Float64
    cost_std::Float64
    los_mean::Float64
    los_median::Int
    los_std::Float64
end

function CohortStatistics()
    CohortStatistics(
        0,
        0.0, 0.0, 0.0,
        Dict(), Dict(), Dict(),
        Tuple{String, Int}[],
        0.0, 0.0, 0.0,
        0.0, 0, 0.0
    )
end

# ============================================================================
# PATIENT COHORT
# ============================================================================

"""
    PatientCohort

A defined group of patients meeting specified inclusion/exclusion criteria.

# Fields
- cohort_id::String: Unique cohort identifier (UUID)
- name::String: Human-readable cohort name
- description::String: Detailed description of cohort definition
- patient_ids::Vector{String}: De-identified patient pseudonyms
- encounter_ids::Vector{String}: Associated encounter IDs
- size::Int: Number of patients
- inclusion_criteria::Vector{CriterionType}: Inclusion filters
- exclusion_criteria::Vector{CriterionType}: Exclusion filters
- statistics::CohortStatistics: Computed cohort statistics
- creation_date::DateTime: When cohort was created
- last_updated::DateTime: Last time cohort was modified
- metadata::Dict: Additional context (study name, analyst, notes)
"""
struct PatientCohort
    cohort_id::String
    name::String
    description::String
    patient_ids::Vector{String}
    encounter_ids::Vector{String}
    size::Int
    inclusion_criteria::Vector{CriterionType}
    exclusion_criteria::Vector{CriterionType}
    statistics::CohortStatistics
    creation_date::DateTime
    last_updated::DateTime
    metadata::Dict{String, Any}
end

function PatientCohort(
    name::String;
    description::String = "",
    inclusion_criteria::Vector{CriterionType} = CriterionType[],
    exclusion_criteria::Vector{CriterionType} = CriterionType[],
    metadata::Dict{String, Any} = Dict(),
)
    PatientCohort(
        string(uuid4()),
        name,
        description,
        String[],
        String[],
        0,
        inclusion_criteria,
        exclusion_criteria,
        CohortStatistics(),
        now(),
        now(),
        metadata,
    )
end

# ============================================================================
# COHORT LINEAGE & AUDIT
# ============================================================================

"""
    CohortDefinition

Fully specified cohort definition with creation metadata.

# Fields
- cohort_id::String: Reference to PatientCohort
- definition_id::String: Unique definition version
- created_by::String: User who created cohort
- created_at::DateTime: Creation timestamp
- inclusion_criteria::Vector{CriterionType}: Full specification
- exclusion_criteria::Vector{CriterionType}: Full specification
- data_lineage::Dict: Traces source data (file, version, extraction date)
- documentation::String: Definition documentation
"""
struct CohortDefinition
    cohort_id::String
    definition_id::String
    created_by::String
    created_at::DateTime
    inclusion_criteria::Vector{CriterionType}
    exclusion_criteria::Vector{CriterionType}
    data_lineage::Dict{String, Any}
    documentation::String
end

function CohortDefinition(
    cohort_id::String,
    created_by::String;
    inclusion_criteria::Vector{CriterionType} = CriterionType[],
    exclusion_criteria::Vector{CriterionType} = CriterionType[],
    data_lineage::Dict{String, Any} = Dict(),
    documentation::String = "",
)
    CohortDefinition(
        cohort_id,
        string(uuid4()),
        created_by,
        now(),
        inclusion_criteria,
        exclusion_criteria,
        data_lineage,
        documentation,
    )
end

