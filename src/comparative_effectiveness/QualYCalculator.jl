# ============================================================================
# QUALITY-ADJUSTED LIFE YEAR (QALY) CALCULATOR (Module 6)
# ============================================================================
# Calculate QALYs based on health outcomes and utility weights

"""
    QALYCalculation

Results of QALY calculation for a patient or cohort.

# Fields
- base_life_years::Float64: Years of life gained (LY)
- utility_weight::Float64: Health utility weight (0-1, 1=perfect health)
- quality_adjusted_life_years::Float64: Base LY × utility weight
- adjustment_factors::Dict{String, Float64}: Health state adjustments applied
"""
struct QALYCalculation
    base_life_years::Float64
    utility_weight::Float64
    quality_adjusted_life_years::Float64
    adjustment_factors::Dict{String, Float64}
end

"""
    HealthState

Represents patient health state for QALY calculation.

# Fields
- mortality_rate::Float64: Annual probability of death (0-1)
- morbidity_index::Float64: Functional limitation index (0-1, 0=perfect, 1=worst)
- complication_count::Int: Number of active complications
- is_post_acute_care::Bool: In recovery/post-acute phase
- years_projected::Int: Years of life projection (default 5, 10, lifetime)
"""
struct HealthState
    mortality_rate::Float64
    morbidity_index::Float64
    complication_count::Int
    is_post_acute_care::Bool
    years_projected::Int
end

# ============================================================================
# UTILITY WEIGHT FUNCTIONS
# ============================================================================

"""
    get_utility_weight(health_state::HealthState)::Float64

Calculate health state utility weight (0-1 scale, where 1 = perfect health).

Uses EQ-5D-5L style utility weights with adjustments for comorbidities.

# Utility Calculation
- Base: 1.0
- Mortality impact: -mortality_rate (death reduces utility)
- Morbidity impact: -(morbidity_index × 0.5)
- Complications: -0.05 per complication
- Post-acute discount: -0.15 (temporary reduction during recovery)

Bounded to [0.0, 1.0]
"""
function get_utility_weight(health_state::HealthState)::Float64
    utility = 1.0

    # Mortality impact
    utility -= health_state.mortality_rate

    # Morbidity impact (functional limitation)
    utility -= health_state.morbidity_index * 0.5

    # Complication impact
    complication_penalty = min(health_state.complication_count * 0.05, 0.3)
    utility -= complication_penalty

    # Post-acute care discount (temporary)
    if health_state.is_post_acute_care
        utility -= 0.15
    end

    # Bound utility to valid range
    return clamp(utility, 0.0, 1.0)
end

"""
    get_utility_by_diagnosis(diagnosis_code::String, severity::String)::Float64

Get EQ-5D-5L utility weight by diagnosis and severity.

# Common Diagnosis Utilities
- **Acute MI**: Moderate (0.65), Severe (0.45)
- **Stroke**: Mild (0.60), Moderate (0.40), Severe (0.20)
- **COPD**: Mild (0.70), Moderate (0.50), Severe (0.30)
- **Joint Replacement**: Pre-op (0.50), 6mo post-op (0.85), 12mo (0.90)
- **Hip Fracture**: Hospitalized (0.40), Recovery (0.65), Chronic (0.75)

# Arguments
- diagnosis_code::String: ICD-10 code (e.g., "I21" for MI)
- severity::String: "Mild", "Moderate", or "Severe"

# Returns
Utility weight 0-1
"""
function get_utility_by_diagnosis(diagnosis_code::String, severity::String)::Float64
    # Map ICD-10 codes to condition categories
    diagnosis_category = get_diagnosis_category(diagnosis_code)

    # Default utility by diagnosis and severity
    utilities = Dict(
        ("Acute MI", "Mild") => 0.75,
        ("Acute MI", "Moderate") => 0.65,
        ("Acute MI", "Severe") => 0.45,

        ("Stroke", "Mild") => 0.60,
        ("Stroke", "Moderate") => 0.40,
        ("Stroke", "Severe") => 0.20,

        ("COPD", "Mild") => 0.70,
        ("COPD", "Moderate") => 0.50,
        ("COPD", "Severe") => 0.30,

        ("Hip/Knee Replacement", "Pre-op") => 0.50,
        ("Hip/Knee Replacement", "Post-op") => 0.85,

        ("Hip Fracture", "Acute") => 0.40,
        ("Hip Fracture", "Recovery") => 0.65,
        ("Hip Fracture", "Chronic") => 0.75,

        ("Sepsis", "Mild") => 0.60,
        ("Sepsis", "Moderate") => 0.40,
        ("Sepsis", "Severe") => 0.15,

        ("Pneumonia", "Mild") => 0.80,
        ("Pneumonia", "Moderate") => 0.65,
        ("Pneumonia", "Severe") => 0.40,

        ("Diabetes", "Mild") => 0.85,
        ("Diabetes", "Moderate") => 0.70,
        ("Diabetes", "Severe") => 0.55,

        ("Default", "Mild") => 0.80,
        ("Default", "Moderate") => 0.65,
        ("Default", "Severe") => 0.40,
    )

    key = (diagnosis_category, severity)
    return get(utilities, key, utilities[("Default", severity)])
end

function get_diagnosis_category(diagnosis_code::String)::String
    # Map ICD-10 codes to diagnosis categories
    categories = Dict(
        "I21" => "Acute MI",
        "I63" => "Stroke",
        "I64" => "Stroke",
        "J44" => "COPD",
        "Z09" => "Hip/Knee Replacement",  # Orthopedic follow-up
        "S72" => "Hip Fracture",
        "R65" => "Sepsis",
        "J18" => "Pneumonia",
        "E11" => "Diabetes",
        "E10" => "Diabetes",
    )

    # Check if code starts with any known prefix
    for (code_prefix, category) in categories
        if startswith(diagnosis_code, code_prefix)
            return category
        end
    end

    return "Default"
end

# ============================================================================
# QALY CALCULATION
# ============================================================================

"""
    calculate_qaly(health_state::HealthState)::QALYCalculation

Calculate Quality-Adjusted Life Years for a patient health state.

# Arguments
- health_state::HealthState: Patient health state with outcomes

# Returns
QALYCalculation with base years, utility weight, and adjusted QALYs
"""
function calculate_qaly(health_state::HealthState)::QALYCalculation
    # Get utility weight for this health state
    utility = get_utility_weight(health_state)

    # Calculate base life years (adjusted for mortality)
    # Using life table survival probability
    base_life_years = calculate_life_years(health_state.years_projected, health_state.mortality_rate)

    # Calculate QALYs
    qalys = base_life_years * utility

    # Track adjustment factors
    adjustments = Dict(
        "mortality" => -health_state.mortality_rate,
        "morbidity" => -health_state.morbidity_index * 0.5,
        "complications" => -min(health_state.complication_count * 0.05, 0.3),
        "post_acute" => health_state.is_post_acute_care ? -0.15 : 0.0,
    )

    return QALYCalculation(base_life_years, utility, qalys, adjustments)
end

"""
    calculate_life_years(years_projected::Int, mortality_rate::Float64)::Float64

Calculate life years accounting for mortality over projection period.

Uses simplified cumulative survival probability:
LY = Σ(1 - mortality_rate)^t for t = 1 to years_projected

# Arguments
- years_projected::Int: Number of years to project (typically 5-10 or lifetime)
- mortality_rate::Float64: Annual mortality rate (0-1)

# Returns
Cumulative life years lived
"""
function calculate_life_years(years_projected::Int, mortality_rate::Float64)::Float64
    if mortality_rate >= 1.0
        return 0.0
    end

    ly = 0.0
    survival = 1.0

    for year in 1:years_projected
        survival *= (1.0 - mortality_rate)
        ly += survival
    end

    return ly
end

"""
    calculate_cohort_qalys(
        cohort_simulation::CohortSimulationResult,
        diagnoses::Vector{String};
        years_projected::Int = 10
    )::Float64

Calculate total QALYs for a patient cohort.

# Arguments
- cohort_simulation::CohortSimulationResult: Simulation results with outcomes
- diagnoses::Vector{String}: Primary diagnosis codes for cohort patients
- years_projected::Int: Years to project (default 10)

# Returns
Total QALYs for the cohort
"""
function calculate_cohort_qalys(
    cohort_simulation::CohortSimulationResult,
    diagnoses::Vector{String};
    years_projected::Int = 10
)::Float64

    total_qalys = 0.0

    # Calculate QALYs per patient
    per_patient_qalys = calculate_qalys_per_patient(
        cohort_simulation.mortality_rate,
        cohort_simulation.readmission_30day_rate,
        diagnoses,
        years_projected
    )

    # Multiply by cohort size
    total_qalys = per_patient_qalys * cohort_simulation.n_patients

    return total_qalys
end

"""
    calculate_qalys_per_patient(
        mortality_rate::Float64,
        readmission_rate::Float64,
        diagnoses::Vector{String},
        years_projected::Int
    )::Float64

Calculate average QALYs per patient based on outcomes and diagnoses.

Combines:
1. Diagnosis-specific utility
2. Mortality impact
3. Readmission impact (morbidity increase)
"""
function calculate_qalys_per_patient(
    mortality_rate::Float64,
    readmission_rate::Float64,
    diagnoses::Vector{String},
    years_projected::Int
)::Float64

    # Average diagnosis utility
    diagnosis_utility = 0.0
    if !isempty(diagnoses)
        diagnosis_utilities = [get_utility_by_diagnosis(d, "Moderate") for d in diagnoses]
        diagnosis_utility = mean(diagnosis_utilities)
    else
        diagnosis_utility = 0.80  # Default good health
    end

    # Mortality impact
    mortality_impact = 1.0 - mortality_rate

    # Readmission impact (increases morbidity)
    readmission_impact = 1.0 - (readmission_rate * 0.3)  # 30% penalty for readmission

    # Combined utility
    combined_utility = diagnosis_utility * mortality_impact * readmission_impact
    combined_utility = clamp(combined_utility, 0.0, 1.0)

    # Calculate life years
    life_years = calculate_life_years(years_projected, mortality_rate)

    # Calculate QALYs
    qalys_per_patient = life_years * combined_utility

    return qalys_per_patient
end

# ============================================================================
# QALY SENSITIVITY ANALYSIS
# ============================================================================

"""
    sensitivity_qaly_to_utility(
        base_qaly::Float64,
        utility_low::Float64,
        utility_high::Float64
    )::Dict{String, Float64}

One-way sensitivity on utility weight assumption.

# Returns
Dict with "low", "base", "high" QALY estimates
"""
function sensitivity_qaly_to_utility(
    base_qaly::Float64,
    utility_low::Float64,
    utility_high::Float64
)::Dict{String, Float64}
    # Assuming base utility in middle
    base_utility = (utility_low + utility_high) / 2

    return Dict(
        "low" => base_qaly * (utility_low / base_utility),
        "base" => base_qaly,
        "high" => base_qaly * (utility_high / base_utility),
    )
end

"""
    sensitivity_qaly_to_mortality(
        base_qaly::Float64,
        mortality_low::Float64,
        mortality_high::Float64,
        years_projected::Int
    )::Dict{String, Float64}

One-way sensitivity on mortality assumption.
"""
function sensitivity_qaly_to_mortality(
    base_qaly::Float64,
    mortality_low::Float64,
    mortality_high::Float64,
    years_projected::Int
)::Dict{String, Float64}

    ly_low = calculate_life_years(years_projected, mortality_high)  # High mortality = low LY
    ly_high = calculate_life_years(years_projected, mortality_low)
    ly_base = calculate_life_years(years_projected, (mortality_low + mortality_high) / 2)

    # Scale QALY by life year ratio
    return Dict(
        "low" => base_qaly * (ly_low / ly_base),
        "base" => base_qaly,
        "high" => base_qaly * (ly_high / ly_base),
    )
end
