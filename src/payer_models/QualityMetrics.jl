# ============================================================================
# QUALITY METRICS AGGREGATION (Module 5)
# ============================================================================
# Calculate and track quality metrics from patient outcomes

using Statistics

# ============================================================================
# QUALITY METRICS STRUCTURE
# ============================================================================

"""
    QualityMetrics

Aggregated quality metrics from patient outcomes.
Used for quality-based payment calculations and contract comparisons.

# HCAHPS / Patient Satisfaction (0-1 scale)
- patient_satisfaction_score::Float64: Overall satisfaction (HCAHPS-derived)
- care_coordination::Float64: Quality of care coordination
- communication::Float64: Communication quality

# Clinical Outcomes (rates, 0-1 scale)
- mortality_rate::Float64: In-hospital mortality rate (lower is better)
- readmission_30day_rate::Float64: 30-day readmission rate (lower is better)
- hospital_acquired_infection_rate::Float64: HAI rate (lower is better)
- complication_rate::Float64: Major complications rate (lower is better)

# Efficiency & Cost (rates/ratios, 0-1 scale or USD)
- cost_per_case::Float64: Mean episode cost in USD
- los_variance::Float64: Length of stay variance from expected (lower is better)

# Process Measures (%, 0-1 scale)
- evidence_based_care_percentage::Float64: % of cases following clinical protocols

# Metadata
- n_patients::Int: Number of patients in aggregation
- evaluation_period::String: Date range or period of evaluation
"""
struct QualityMetrics
    # HCAHPS / Patient Satisfaction
    patient_satisfaction_score::Float64
    care_coordination::Float64
    communication::Float64

    # Clinical Outcomes
    mortality_rate::Float64
    readmission_30day_rate::Float64
    hospital_acquired_infection_rate::Float64
    complication_rate::Float64

    # Efficiency & Cost
    cost_per_case::Float64
    los_variance::Float64

    # Process Measures
    evidence_based_care_percentage::Float64

    # Metadata
    n_patients::Int
    evaluation_period::String
end

function QualityMetrics(;
    patient_satisfaction_score::Float64 = 0.75,
    care_coordination::Float64 = 0.75,
    communication::Float64 = 0.75,
    mortality_rate::Float64 = 0.02,
    readmission_30day_rate::Float64 = 0.12,
    hospital_acquired_infection_rate::Float64 = 0.01,
    complication_rate::Float64 = 0.08,
    cost_per_case::Float64 = 15000.0,
    los_variance::Float64 = 0.0,
    evidence_based_care_percentage::Float64 = 0.85,
    n_patients::Int = 0,
    evaluation_period::String = ""
)
    QualityMetrics(
        patient_satisfaction_score,
        care_coordination,
        communication,
        mortality_rate,
        readmission_30day_rate,
        hospital_acquired_infection_rate,
        complication_rate,
        cost_per_case,
        los_variance,
        evidence_based_care_percentage,
        n_patients,
        evaluation_period
    )
end

# ============================================================================
# QUALITY METRICS CALCULATION
# ============================================================================

"""
    calculate_quality_metrics(cohort_simulation::CohortSimulationResult)::QualityMetrics

Calculate quality metrics from cohort simulation results.

# Arguments
- cohort_simulation::CohortSimulationResult: Results from Module 4 cohort simulation

# Returns
QualityMetrics aggregated from simulation outcomes

# Mapping from CohortSimulationResult to QualityMetrics
- mortality_rate: cohort_simulation.mortality_rate
- readmission_30day_rate: cohort_simulation.readmission_30day_rate
- complication_rate: cohort_simulation.complication_rate
- cost_per_case: cohort_simulation.mean_cost
- mean_quality_score → satisfaction: cohort_simulation.mean_quality_score (proxy for HCAHPS)

# Default Assumptions (when data not available)
- HAI rate: 1% (typical for rural hospitals)
- Care coordination: Same as satisfaction
- Communication: Same as satisfaction
- Evidence-based care: 85% (typical compliance rate)
"""
function calculate_quality_metrics(cohort_simulation::CohortSimulationResult)::QualityMetrics
    # Use quality score as proxy for patient satisfaction
    patient_satisfaction = cohort_simulation.mean_quality_score

    return QualityMetrics(
        patient_satisfaction_score = patient_satisfaction,
        care_coordination = patient_satisfaction,  # Proxy: same as satisfaction
        communication = patient_satisfaction,      # Proxy: same as satisfaction
        mortality_rate = cohort_simulation.mortality_rate,
        readmission_30day_rate = cohort_simulation.readmission_30day_rate,
        hospital_acquired_infection_rate = 0.01,  # Default: 1% HAI rate
        complication_rate = cohort_simulation.complication_rate,
        cost_per_case = cohort_simulation.mean_cost,
        los_variance = abs(cohort_simulation.mean_los - 4.0) / 4.0,  # Assume 4-day expected LOS
        evidence_based_care_percentage = 0.85,  # Default: 85% evidence-based care
        n_patients = cohort_simulation.n_patients,
        evaluation_period = "Simulated"
    )
end

# ============================================================================
# QUALITY ADJUSTMENT CALCULATIONS
# ============================================================================

"""
    calculate_quality_adjustment(
        actual_metrics::QualityMetrics,
        target_metrics::QualityMetrics,
        adjustors::Dict{String, Float64}
    )::Float64

Calculate % payment adjustment based on quality performance.

Compares actual metrics to targets and applies adjustors (penalties/bonuses).

# Arguments
- actual_metrics::QualityMetrics: Actual performance
- target_metrics::QualityMetrics: Performance targets
- adjustors::Dict{String, Float64}: % adjustment per metric unit
  - Negative = penalty for exceeding target (e.g., higher mortality)
  - Positive = bonus for exceeding target (e.g., higher satisfaction)

# Example Adjustors
```julia
adjustors = Dict(
    "mortality" => -0.02,            # -2% per 1% over target
    "readmission" => -0.01,          # -1% per 1% over target
    "satisfaction" => 0.03,          # +3% per 1% above target
    "complication" => -0.02          # -2% per 1% over target
)
```

# Returns
Float64: Net adjustment factor (e.g., 0.05 = +5%, -0.10 = -10%)
Bounded to [-0.30, 0.15] (max -30% penalty, +15% bonus)
"""
function calculate_quality_adjustment(
    actual_metrics::QualityMetrics,
    target_metrics::QualityMetrics,
    adjustors::Dict{String, Float64}
)::Float64

    adjustment = 0.0

    # Mortality: lower is better (negative variance = bonus)
    if haskey(adjustors, "mortality")
        mortality_variance = actual_metrics.mortality_rate - target_metrics.mortality_rate
        adjustment += mortality_variance * adjustors["mortality"]
    end

    # Readmission: lower is better (negative variance = bonus)
    if haskey(adjustors, "readmission")
        readmission_variance = actual_metrics.readmission_30day_rate - target_metrics.readmission_30day_rate
        adjustment += readmission_variance * adjustors["readmission"]
    end

    # Patient Satisfaction: higher is better (positive variance = bonus)
    if haskey(adjustors, "satisfaction")
        satisfaction_variance = actual_metrics.patient_satisfaction_score - target_metrics.patient_satisfaction_score
        adjustment += satisfaction_variance * adjustors["satisfaction"]
    end

    # Complication: lower is better (negative variance = bonus)
    if haskey(adjustors, "complication")
        complication_variance = actual_metrics.complication_rate - target_metrics.complication_rate
        adjustment += complication_variance * adjustors["complication"]
    end

    # HAI Rate: lower is better (negative variance = bonus)
    if haskey(adjustors, "hai")
        hai_variance = actual_metrics.hospital_acquired_infection_rate - target_metrics.hospital_acquired_infection_rate
        adjustment += hai_variance * adjustors["hai"]
    end

    # Evidence-Based Care: higher is better (positive variance = bonus)
    if haskey(adjustors, "evidence_based")
        evidence_variance = actual_metrics.evidence_based_care_percentage - target_metrics.evidence_based_care_percentage
        adjustment += evidence_variance * adjustors["evidence_based"]
    end

    # Bound adjustment to reasonable ranges
    max_penalty = -0.30      # Max -30% penalty
    max_bonus = 0.15         # Max +15% bonus

    return max(max_penalty, min(max_bonus, adjustment))
end

"""
    get_quality_rating(metrics::QualityMetrics)::String

Get qualitative rating (Excellent/Good/Fair/Poor) based on quality metrics.

# Scoring Logic
- Excellent: All metrics in top 25% nationally (mortality <1.5%, readmission <10%, satisfaction >90%)
- Good: Most metrics above median (mortality <3%, readmission <15%, satisfaction >75%)
- Fair: Mixed performance (mortality <5%, readmission <20%, satisfaction >65%)
- Poor: Below average performance on multiple metrics
"""
function get_quality_rating(metrics::QualityMetrics)::String
    score = 0

    # Mortality scoring (target: <2%)
    if metrics.mortality_rate < 0.015
        score += 4
    elseif metrics.mortality_rate < 0.030
        score += 3
    elseif metrics.mortality_rate < 0.050
        score += 2
    else
        score += 1
    end

    # Readmission scoring (target: <12%)
    if metrics.readmission_30day_rate < 0.10
        score += 4
    elseif metrics.readmission_30day_rate < 0.15
        score += 3
    elseif metrics.readmission_30day_rate < 0.20
        score += 2
    else
        score += 1
    end

    # Patient satisfaction scoring (target: >80%)
    if metrics.patient_satisfaction_score > 0.85
        score += 4
    elseif metrics.patient_satisfaction_score > 0.75
        score += 3
    elseif metrics.patient_satisfaction_score > 0.65
        score += 2
    else
        score += 1
    end

    # Complication scoring (target: <5%)
    if metrics.complication_rate < 0.05
        score += 4
    elseif metrics.complication_rate < 0.08
        score += 3
    elseif metrics.complication_rate < 0.12
        score += 2
    else
        score += 1
    end

    # Overall rating based on total score (max 16)
    if score >= 15
        return "Excellent"
    elseif score >= 12
        return "Good"
    elseif score >= 8
        return "Fair"
    else
        return "Poor"
    end
end

# ============================================================================
# COMPARATIVE ANALYSIS
# ============================================================================

"""
    compare_metrics(
        metrics1::QualityMetrics,
        metrics2::QualityMetrics
    )::Dict{String, Float64}

Compare two quality metric sets.
Returns % difference for each metric (positive = metrics1 better).

# Returns
Dict{String, Float64} with metrics as keys, % difference as values
"""
function compare_metrics(
    metrics1::QualityMetrics,
    metrics2::QualityMetrics
)::Dict{String, Float64}

    differences = Dict{String, Float64}()

    # Lower is better metrics (mortality, readmission, complications, HAI)
    differences["mortality"] = (metrics2.mortality_rate - metrics1.mortality_rate) / metrics2.mortality_rate * 100
    differences["readmission"] = (metrics2.readmission_30day_rate - metrics1.readmission_30day_rate) / metrics2.readmission_30day_rate * 100
    differences["complication"] = (metrics2.complication_rate - metrics1.complication_rate) / metrics2.complication_rate * 100
    differences["hai"] = (metrics2.hospital_acquired_infection_rate - metrics1.hospital_acquired_infection_rate) / metrics2.hospital_acquired_infection_rate * 100

    # Higher is better metrics (satisfaction, evidence-based care)
    differences["satisfaction"] = (metrics1.patient_satisfaction_score - metrics2.patient_satisfaction_score) / metrics2.patient_satisfaction_score * 100
    differences["evidence_based"] = (metrics1.evidence_based_care_percentage - metrics2.evidence_based_care_percentage) / metrics2.evidence_based_care_percentage * 100

    # Cost (lower is better)
    if metrics2.cost_per_case > 0
        differences["cost"] = (metrics2.cost_per_case - metrics1.cost_per_case) / metrics2.cost_per_case * 100
    else
        differences["cost"] = 0.0
    end

    return differences
end

# ============================================================================
# FORMATTING
# ============================================================================

"""
    format_quality_metrics(metrics::QualityMetrics)::String

Format quality metrics as human-readable report.
"""
function format_quality_metrics(metrics::QualityMetrics)::String
    io = IOBuffer()

    println(io, "╔════════════════════════════════════════════════════════════════════╗")
    println(io, "║                      QUALITY METRICS                              ║")
    println(io, "╚════════════════════════════════════════════════════════════════════╝")
    println(io, "")

    # Header
    println(io, "Rating: $(get_quality_rating(metrics))")
    println(io, "Patients: $(metrics.n_patients)")
    println(io, "Period: $(metrics.evaluation_period)")
    println(io, "")

    # Clinical Outcomes
    println(io, "──── CLINICAL OUTCOMES ────────────────────────────────────────────")
    println(io, "Mortality Rate:              $(round(metrics.mortality_rate * 100, digits=2))%")
    println(io, "30-Day Readmission:          $(round(metrics.readmission_30day_rate * 100, digits=2))%")
    println(io, "Complication Rate:           $(round(metrics.complication_rate * 100, digits=2))%")
    println(io, "Hospital-Acquired Infection: $(round(metrics.hospital_acquired_infection_rate * 100, digits=2))%")
    println(io, "")

    # Patient Satisfaction
    println(io, "──── PATIENT SATISFACTION ─────────────────────────────────────────")
    println(io, "Overall Satisfaction:        $(round(metrics.patient_satisfaction_score * 100, digits=1))%")
    println(io, "Care Coordination:           $(round(metrics.care_coordination * 100, digits=1))%")
    println(io, "Communication Quality:       $(round(metrics.communication * 100, digits=1))%")
    println(io, "")

    # Efficiency
    println(io, "──── EFFICIENCY ───────────────────────────────────────────────────")
    println(io, "Cost Per Case:               USD $(round(metrics.cost_per_case, digits=0))")
    println(io, "LOS Variance:                $(round(metrics.los_variance * 100, digits=1))%")
    println(io, "Evidence-Based Care:         $(round(metrics.evidence_based_care_percentage * 100, digits=1))%")
    println(io, "")

    return String(take!(io))
end
