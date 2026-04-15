# utils/constants.jl — Constants for healthcare economics

const DEFAULT_ICER_THRESHOLD = 100_000.0  # $100K per QALY (US standard)
const DEFAULT_WILLINGNESS_TO_PAY = [50_000, 100_000, 150_000, 200_000]

const ICD10_MAPPING = Dict(
    "I10" => "Essential Hypertension",
    "I11" => "Hypertensive Heart Disease",
    "E11" => "Type 2 Diabetes Mellitus",
    "J18" => "Pneumonia",
    "R00" => "Abnormalities of Heartbeat",
)

# Typical QALY utility weights (simplified)
const QALY_UTILITY_STANDARD = Dict(
    "perfect_health" => 1.0,
    "mild_disease" => 0.90,
    "moderate_disease" => 0.70,
    "severe_disease" => 0.40,
    "very_severe" => 0.10,
    "death" => 0.0
)

# DRG base rates (simplified—real implementation uses CMS files)
const DRG_BASE_RATES = Dict(
    "065" => 8_500.0,      # Intracranial procedures
    "175" => 5_200.0,      # Pulmonary edema
    "291" => 6_800.0,      # Heart failure
    "470" => 2_100.0,      # Major joint procedures
)

const PAYER_MULTIPLIERS = Dict(
    :Medicare => 1.0,      # Baseline
    :Medicaid => 0.75,     # Lower reimbursement
    :Commercial => 1.25,   # Higher reimbursement
    :Uninsured => 0.0,     # No reimbursement
)

# utils/types.jl — Core type definitions

abstract type CostModel end
abstract type OutcomeModel end
abstract type QALYUtility end
abstract type SimulationResult end

# Payer type
@enum Payer Medicare Medicaid Commercial Uninsured Tricare VeteransAffairs

# Episode outcome status
@enum OutcomeStatus Alive Dead Transferred LongTermCare

# Readmission status
@enum ReadmissionStatus None Readmitted_30 Readmitted_90 Transferred_30

# utils/validation.jl — Validation functions

function validate_episode(ep::Episode)::Bool
    @assert !isempty(ep.episode_id) "Episode ID cannot be empty"
    @assert !isempty(ep.patient_id) "Patient ID cannot be empty"
    @assert ep.los > 0 "Length of stay must be positive"
    @assert ep.discharge_date >= ep.admission_date "Discharge must be after admission"
    return true
end

function validate_cost_model(cost::CostModel)::Bool
    # Specific validation per model type
    true
end

function validate_outcomes(outcomes::EpisodeOutcomes)::Bool
    @assert 0 <= outcomes.qaly_gained <= 5.0 "QALYs must be between 0 and 5"
    @assert outcomes.total_cost >= 0 "Cost must be non-negative"
    return true
end

"""
    format_currency(value::Float64)::String
Format a number as currency string.
"""
function format_currency(value::Float64)::String
    if value >= 1_000_000
        return @sprintf("\$%.1fM", value / 1_000_000)
    elseif value >= 1_000
        return @sprintf("\$%.1fK", value / 1_000)
    else
        return @sprintf("\$%.2f", value)
    end
end

"""
    format_percentage(value::Float64)::String
Format a number as percentage string.
"""
function format_percentage(value::Float64)::String
    @sprintf("%.1f%%", value * 100)
end

"""
    format_ratio(numerator::Float64, denominator::Float64)::String
Format a ratio as a string.
"""
function format_ratio(numerator::Float64, denominator::Float64)::String
    if denominator == 0
        return "N/A"
    end
    ratio = numerator / denominator
    @sprintf("%.2f", ratio)
end
