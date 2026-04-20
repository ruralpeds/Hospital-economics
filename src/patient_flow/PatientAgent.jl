# patient_flow/PatientAgent.jl
# Patient agent definition with economic tracking and clinical outcomes

using Dates
using Distributions
using Random

include("ClinicalPathway.jl")

"""
    PatientAgent

Mutable patient agent for discrete event simulation with cost accumulation and outcome tracking.

# Financial Fields
- `id::String` — Unique patient identifier
- `arrival_time::Float64` — Arrival time in simulation (hours from start)
- `admission_date::Date` — Actual calendar admission date
- `cumulative_cost::Float64` — Total cost accumulated so far
- `cost_by_day::Vector{Float64}` — Daily cost breakdown
- `daily_costs::Dict{String, Float64}` — Cost by component (labor, supplies, overhead)
- `resource_utilization::Dict{String, Float64}` — Resources used (bed-days, OR-minutes, etc.)

# Clinical Fields
- `primary_diagnosis::String` — ICD-10 code for primary diagnosis
- `secondary_diagnoses::Vector{String}` — Additional diagnoses
- `drg_code::String` — Assigned DRG code
- `procedures::Vector{String}` — Procedures performed
- `comorbidity_count::Int` — Number of secondary diagnoses

# Location & Service
- `assigned_service_line::String` — Service line assignment (Cardiology, Orthopedics, etc.)
- `location::String` — Current location (waiting, ward, OR, ICU, discharged)
- `los_target::Int` — Planned length of stay (days)

# Outcomes (Module 4)
- `quality_score::Float64` — Simulated patient satisfaction/quality (0-1)
- `readmission_status::Bool` — True if patient gets readmitted within 30 days
- `mortality::Bool` — True if patient dies during/after episode
- `complication_codes::Vector{String}` — ICD-10 complication codes

# Administrative
- `payer::String` — Payer type (Medicare, Medicaid, Commercial, Uninsured)
- `discharge_date::Union{Date, Nothing}` — Discharge date (set at discharge)
- `metadata::Dict{String, Any}` — Additional tracking data
"""
mutable struct PatientAgent
    id::String
    arrival_time::Float64
    admission_date::Date
    primary_diagnosis::String
    secondary_diagnoses::Vector{String}
    drg_code::String
    assigned_service_line::String
    location::String  # "waiting" | "ward" | "OR" | "ICU" | "discharged"
    los_target::Int

    # Cost tracking
    cumulative_cost::Float64
    cost_by_day::Vector{Float64}
    daily_costs::Dict{String, Float64}
    resource_utilization::Dict{String, Float64}

    # Clinical tracking
    procedures::Vector{String}
    payer::String
    comorbidity_count::Int

    # Outcomes (Module 4)
    quality_score::Float64
    readmission_status::Bool
    mortality::Bool
    complication_codes::Vector{String}

    # Timestamps
    discharge_date::Union{Date, Nothing}
    metadata::Dict{String, Any}

    function PatientAgent(;
        id::String,
        arrival_time::Float64 = 0.0,
        admission_date::Date = today(),
        primary_diagnosis::String = "",
        secondary_diagnoses::Vector{String} = String[],
        drg_code::String = "",
        assigned_service_line::String = "General",
        location::String = "waiting",
        los_target::Int = 3,
        cumulative_cost::Float64 = 0.0,
        cost_by_day::Vector{Float64} = Float64[],
        daily_costs::Dict{String, Float64} = Dict{String, Float64}("labor" => 0.0, "supplies" => 0.0, "overhead" => 0.0),
        resource_utilization::Dict{String, Float64} = Dict{String, Float64}(),
        procedures::Vector{String} = String[],
        payer::String = "Medicare",
        comorbidity_count::Int = 0,
        quality_score::Float64 = 0.5,
        readmission_status::Bool = false,
        mortality::Bool = false,
        complication_codes::Vector{String} = String[],
        discharge_date::Union{Date, Nothing} = nothing,
        metadata::Dict{String, Any} = Dict{String, Any}()
    )
        new(
            id, arrival_time, admission_date, primary_diagnosis, secondary_diagnoses,
            drg_code, assigned_service_line, location, los_target,
            cumulative_cost, cost_by_day, daily_costs, resource_utilization,
            procedures, payer, length(secondary_diagnoses),
            quality_score, readmission_status, mortality, complication_codes,
            discharge_date, metadata
        )
    end
end

"""
    initialize_patient_cost_tracking(patient::PatientAgent, los::Int)

Initialize daily cost tracking arrays for a patient's stay.
"""
function initialize_patient_cost_tracking(patient::PatientAgent, los::Int)
    patient.cost_by_day = zeros(Float64, los)
    patient.daily_costs = Dict("labor" => 0.0, "supplies" => 0.0, "overhead" => 0.0, "bed" => 0.0)
    patient.resource_utilization = Dict(
        "bed_days" => 0.0,
        "labor_hours" => 0.0,
        "or_minutes" => 0.0,
        "supplies_cost" => 0.0
    )
end

"""
    accumulate_daily_cost!(patient::PatientAgent, day::Int, labor::Float64, supplies::Float64, overhead::Float64)

Add daily costs to patient's accumulated cost. Called once per simulation day.
"""
function accumulate_daily_cost!(
    patient::PatientAgent,
    day::Int,
    labor::Float64,
    supplies::Float64,
    overhead::Float64
)
    daily_total = labor + supplies + overhead

    if day <= length(patient.cost_by_day)
        patient.cost_by_day[day] = daily_total
    end

    patient.cumulative_cost += daily_total
    patient.daily_costs["labor"] += labor
    patient.daily_costs["supplies"] += supplies
    patient.daily_costs["overhead"] += overhead
end

"""
    add_procedure_cost!(patient::PatientAgent, procedure_code::String, cost::Float64)

Record a procedure and its associated cost.
"""
function add_procedure_cost!(patient::PatientAgent, procedure_code::String, cost::Float64)
    push!(patient.procedures, procedure_code)
    patient.cumulative_cost += cost
    if !haskey(patient.daily_costs, "procedures")
        patient.daily_costs["procedures"] = 0.0
    end
    patient.daily_costs["procedures"] += cost
end

"""
    route_patient_to_service!(patient::PatientAgent, service_line::String, location::String)

Update patient's service line and location (used during simulation routing).
"""
function route_patient_to_service!(patient::PatientAgent, service_line::String, location::String)
    patient.assigned_service_line = service_line
    patient.location = location
end

"""
    discharge_patient!(patient::PatientAgent, discharge_date::Date)

Mark patient as discharged and finalize their stay.
"""
function discharge_patient!(patient::PatientAgent, discharge_date::Date)
    patient.location = "discharged"
    patient.discharge_date = discharge_date
end

"""
    get_patient_summary(patient::PatientAgent)::Dict{String, Any}

Return a summary dictionary of patient's episode and costs.
"""
function get_patient_summary(patient::PatientAgent)::Dict{String, Any}
    los = isnothing(patient.discharge_date) ? 0 : Dates.value(patient.discharge_date - patient.admission_date)

    return Dict(
        "patient_id" => patient.id,
        "admission_date" => patient.admission_date,
        "discharge_date" => patient.discharge_date,
        "los" => los,
        "service_line" => patient.assigned_service_line,
        "drg_code" => patient.drg_code,
        "payer" => patient.payer,
        "total_cost" => patient.cumulative_cost,
        "cost_by_component" => copy(patient.daily_costs),
        "procedures" => copy(patient.procedures),
        "comorbidities" => patient.comorbidity_count
    )
end

"""
    patient_to_episode(patient::PatientAgent)::Episode

Convert a discharged patient to an Episode record for cost analysis.
Requires Episode.jl to be included.
"""
function patient_to_episode(patient::PatientAgent)
    if isnothing(patient.discharge_date)
        error("Cannot create episode for non-discharged patient")
    end

    los = Dates.value(patient.discharge_date - patient.admission_date)

    # Map payer string to enum (requires Episode.jl)
    payer_map = Dict(
        "Medicare" => Medicare,
        "Medicaid" => Medicaid,
        "Commercial" => Commercial,
        "Uninsured" => Uninsured
    )
    payer_enum = get(payer_map, patient.payer, Medicare)

    Episode(
        episode_id="EP_" * patient.id,
        patient_id=patient.id,
        admission_date=patient.admission_date,
        discharge_date=patient.discharge_date,
        primary_diagnosis=patient.primary_diagnosis,
        drg_code=patient.drg_code,
        secondary_diagnoses=patient.secondary_diagnoses,
        procedures=patient.procedures,
        payer=payer_enum,
        setting=patient.assigned_service_line,
        metadata=Dict(
            "service_line" => patient.assigned_service_line,
            "simulated_cost" => patient.cumulative_cost,
            "cost_components" => copy(patient.daily_costs),
            "outcomes" => Dict(
                "quality_score" => patient.quality_score,
                "readmission" => patient.readmission_status,
                "mortality" => patient.mortality,
                "complications" => copy(patient.complication_codes)
            )
        )
    )
end

# ============================================================================
# OUTCOME SIMULATION (Module 4)
# ============================================================================

"""
    simulate_patient_outcomes!(patient::PatientAgent, pathway::ClinicalPathway)

Simulate clinical outcomes for a patient based on their clinical pathway.
Assigns outcomes (mortality, readmission, complications, quality) based on
pathway distributions and patient risk factors (age, comorbidities).

# Arguments
- patient::PatientAgent: Patient to assign outcomes to
- pathway::ClinicalPathway: Evidence-based pathway with outcome distributions

# Modifies (in-place)
- patient.mortality: Sampled from pathway + risk adjustment
- patient.readmission_status: Sampled from pathway + risk adjustment
- patient.complication_codes: Sampled based on complication rate
- patient.quality_score: Calculated from outcomes and costs

# Risk Adjustment
Outcomes adjusted based on:
- Age (>75 increases mortality/readmission risk)
- Comorbidity count (increases complication risk)
- Cost variance (lower relative cost improves quality)

# Example
```julia
using HospitalFinanceToolbox
pathway = route_to_pathway("246")  # Acute MI
patient = PatientAgent(id="PT001", drg_code="246", comorbidity_count=2)
simulate_patient_outcomes!(patient, pathway)
println("Mortality: \$(patient.mortality)")
println("Quality Score: \$(patient.quality_score)")
```
"""
function simulate_patient_outcomes!(patient::PatientAgent, pathway::ClinicalPathway)
    # ────────────────────────────────────────────────────────────────────
    # Risk Adjustment Factors (from patient characteristics)
    # ────────────────────────────────────────────────────────────────────
    # Parse age from metadata or use default
    age = get(patient.metadata, "age", 65)
    age_factor = 1.0 + max(0, (age - 65) / 35 * 0.5)  # 0-50% increase for age >65

    # Comorbidity factor (5% increase per comorbidity)
    comorbidity_factor = 1.0 + (patient.comorbidity_count * 0.05)

    # Cost variance factor (patients with higher-than-expected costs have worse outcomes)
    los_target = pathway.expected_los
    actual_los = isnothing(patient.discharge_date) ? los_target : Dates.value(patient.discharge_date - patient.admission_date)
    los_variance = abs(actual_los - los_target) / los_target
    los_factor = 1.0 + (los_variance * 0.3)  # 0-30% increase for LOS variance

    # ────────────────────────────────────────────────────────────────────
    # Simulate Mortality
    # ────────────────────────────────────────────────────────────────────
    adjusted_mortality_rate = min(1.0, pathway.expected_mortality_rate * age_factor * comorbidity_factor * los_factor)
    patient.mortality = rand() < adjusted_mortality_rate

    # ────────────────────────────────────────────────────────────────────
    # Simulate 30-day Readmission
    # ────────────────────────────────────────────────────────────────────
    if !patient.mortality
        adjusted_readmission_rate = min(1.0, pathway.expected_readmission_30day * age_factor * comorbidity_factor)
        patient.readmission_status = rand() < adjusted_readmission_rate
    else
        patient.readmission_status = false  # No readmission if deceased
    end

    # ────────────────────────────────────────────────────────────────────
    # Simulate Complications
    # ────────────────────────────────────────────────────────────────────
    adjusted_complication_rate = min(1.0, pathway.expected_complication_rate * age_factor * comorbidity_factor * los_factor)
    if rand() < adjusted_complication_rate
        # Assign 1-3 random complication codes (in practice would use ICD-10 specifics)
        num_complications = rand(1:3)
        complication_map = Dict(
            "I97.8" => "Cardiac complication",
            "N17.9" => "Acute kidney injury",
            "J96.9" => "Respiratory failure",
            "R65.20" => "Sepsis complication",
            "A41.9" => "Septicemia",
            "I63.9" => "Stroke complication",
            "K91.6" => "Intra-abdominal complication"
        )
        complication_codes = collect(keys(complication_map))
        patient.complication_codes = sample(complication_codes, min(num_complications, length(complication_codes)), replace=false)
    else
        patient.complication_codes = String[]
    end

    # ────────────────────────────────────────────────────────────────────
    # Calculate Quality Score
    # ────────────────────────────────────────────────────────────────────
    patient.quality_score = calculate_quality_score(patient, pathway)

    nothing
end

"""
    calculate_quality_score(patient::PatientAgent, pathway::ClinicalPathway = ClinicalPathway())::Float64

Calculate patient quality/satisfaction score (0-1) based on clinical outcomes and cost.

Scoring logic:
- Start with pathway's expected quality score
- Adjust down for: mortality, readmission, complications
- Adjust down for: LOS variance from expected
- Adjust down for: high cost relative to cohort

# Arguments
- patient::PatientAgent: Patient with simulated outcomes
- pathway::ClinicalPathway: Reference pathway (optional, default quality = 0.75)

# Returns
Float64 between 0.0 (worst) and 1.0 (best)

# Adjustments
- Mortality: -0.35 (major penalty)
- Readmission: -0.10 (moderate penalty)
- Per complication: -0.05 (cumulative)
- LOS variance >50%: -0.08
- High cost (>90th percentile): -0.05
"""
function calculate_quality_score(patient::PatientAgent, pathway::ClinicalPathway = ClinicalPathway())::Float64
    score = 0.75  # Base quality score if no pathway provided

    if pathway.pathway_id != ""
        score = pathway.expected_quality_score
    end

    # Penalty for poor outcomes
    if patient.mortality
        score -= 0.35
    end

    if patient.readmission_status
        score -= 0.10
    end

    # Complication penalty (5% per complication)
    score -= length(patient.complication_codes) * 0.05

    # LOS variance penalty
    if pathway.pathway_id != ""
        los_target = pathway.expected_los
        actual_los = isnothing(patient.discharge_date) ? los_target : Dates.value(patient.discharge_date - patient.admission_date)
        los_variance = abs(actual_los - los_target) / los_target

        if los_variance > 0.5
            score -= 0.08
        end
    end

    # Cost variance penalty (if cost > expected + std dev)
    if pathway.pathway_id != ""
        expected_cost = pathway.expected_cost
        cost_threshold = expected_cost + pathway.cost_std
        if patient.cumulative_cost > cost_threshold
            score -= 0.05
        end
    end

    # Bound to 0.0-1.0
    return max(0.0, min(1.0, score))
end
