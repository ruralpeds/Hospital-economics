# episode/Episode.jl — Core episode definition and costing

"""
    Episode

Represents a single episode of care (hospital admission, procedure, or episode of treatment).

# Fields
- `episode_id::String` — Unique episode identifier
- `patient_id::String` — Patient identifier
- `admission_date::Date` — Admission/start date
- `discharge_date::Date` — Discharge/end date
- `los::Int` — Length of stay (days)
- `primary_diagnosis::String` — ICD-10 code
- `secondary_diagnoses::Vector{String}` — Additional diagnoses
- `drg_code::String` — DRG classification
- `procedures::Vector{String}` — Procedure codes (CPT/ICD-10-PCS)
- `complications::Vector{String}` — Complication codes
- `payer::Payer` — Insurance payer type
- `setting::String` — Hospital, ASC, office, home health
- `metadata::Dict` — Additional attributes
"""
struct Episode
    episode_id::String
    patient_id::String
    admission_date::Date
    discharge_date::Date
    los::Int
    primary_diagnosis::String
    secondary_diagnoses::Vector{String}
    drg_code::String
    procedures::Vector{String}
    complications::Vector{String}
    payer::Payer
    setting::String
    metadata::Dict{String, Any}
    
    function Episode(;
        episode_id::String,
        patient_id::String,
        admission_date::Date,
        discharge_date::Date,
        primary_diagnosis::String,
        drg_code::String = "",
        secondary_diagnoses::Vector{String} = String[],
        procedures::Vector{String} = String[],
        complications::Vector{String} = String[],
        payer::Payer = Medicare,
        setting::String = "Hospital",
        metadata::Dict{String, Any} = Dict()
    )
        los = Dates.value(discharge_date - admission_date)
        validate_episode_constructor(episode_id, patient_id, los, admission_date, discharge_date)
        
        new(
            episode_id, patient_id, admission_date, discharge_date, los,
            primary_diagnosis, secondary_diagnoses, drg_code, procedures,
            complications, payer, setting, metadata
        )
    end
end

function validate_episode_constructor(
    episode_id::String, patient_id::String, los::Int, 
    admission::Date, discharge::Date
)
    @assert !isempty(episode_id) "Episode ID cannot be empty"
    @assert !isempty(patient_id) "Patient ID cannot be empty"
    @assert los >= 0 "Length of stay cannot be negative"
    @assert discharge >= admission "Discharge date must be >= admission date"
end

"""
    EpisodeOutcomes

Clinical and economic outcomes from an episode of care.

# Fields
- `episode_id::String`
- `survived::Bool` — Patient survived episode
- `status::OutcomeStatus` — Final status (Alive, Dead, etc.)
- `qaly_gained::Float64` — Quality-adjusted life years gained
- `complications_occurred::Vector{String}` — Complications that developed
- `readmission_30day::Bool` — Readmitted within 30 days
- `readmission_90day::Bool` — Readmitted within 90 days
- `length_of_stay::Int` — Actual LOS
- `total_cost::Float64` — Episode total cost
- `quality_score::Float64` — Quality measure (0-1)
"""
struct EpisodeOutcomes
    episode_id::String
    survived::Bool
    status::OutcomeStatus
    qaly_gained::Float64
    complications_occurred::Vector{String}
    readmission_30day::Bool
    readmission_90day::Bool
    length_of_stay::Int
    total_cost::Float64
    quality_score::Float64
    metadata::Dict{String, Any}
end

function EpisodeOutcomes(;
    episode_id::String,
    survived::Bool = true,
    status::OutcomeStatus = Alive,
    qaly_gained::Float64 = 0.8,
    complications_occurred::Vector{String} = String[],
    readmission_30day::Bool = false,
    readmission_90day::Bool = false,
    length_of_stay::Int = 5,
    total_cost::Float64 = 0.0,
    quality_score::Float64 = 0.9,
    metadata::Dict{String, Any} = Dict()
)
    @assert 0.0 <= qaly_gained <= 5.0 "QALY gained must be between 0 and 5"
    @assert total_cost >= 0.0 "Cost must be non-negative"
    @assert 0.0 <= quality_score <= 1.0 "Quality score must be between 0 and 1"
    
    EpisodeOutcomes(
        episode_id, survived, status, qaly_gained, complications_occurred,
        readmission_30day, readmission_90day, length_of_stay, total_cost,
        quality_score, metadata
    )
end

"""
    EpisodeSummary

Summary statistics for a cohort of episodes.
"""
struct EpisodeSummary
    n_episodes::Int
    mean_cost::Float64
    std_cost::Float64
    median_cost::Float64
    mean_qaly::Float64
    mortality_rate::Float64
    readmission_30_rate::Float64
    mean_los::Float64
    total_cost::Float64
    total_qaly::Float64
end

function EpisodeSummary(episodes::Vector{EpisodeOutcomes})
    costs = [ep.total_cost for ep in episodes]
    qalys = [ep.qaly_gained for ep in episodes]
    losts = [ep.length_of_stay for ep in episodes]
    
    mortality = sum(!ep.survived for ep in episodes) / length(episodes)
    readmission_30 = sum(ep.readmission_30day for ep in episodes) / length(episodes)
    
    EpisodeSummary(
        length(episodes),
        mean(costs),
        std(costs),
        median(costs),
        mean(qalys),
        mortality,
        readmission_30,
        mean(losts),
        sum(costs),
        sum(qalys)
    )
end

# ═══════════════════════════════════════════════════════════════
# COST MODELS
# ═══════════════════════════════════════════════════════════════

"""
    DRGCostModel

DRG-based costing model using base rates and adjustments.

# Fields
- `drg_base_rates::Dict{String, Float64}` — Base cost per DRG
- `complication_multiplier::Float64` — Additional cost per complication
- `procedure_costs::Dict{String, Float64}` — Procedure add-ons
- `severity_adjustor::Float64` — Adjustment for severity
"""
struct DRGCostModel <: CostModel
    drg_base_rates::Dict{String, Float64}
    complication_multiplier::Float64
    procedure_costs::Dict{String, Float64}
    severity_adjustor::Float64
    
    function DRGCostModel(;
        drg_base_rates::Dict{String, Float64} = DRG_BASE_RATES,
        complication_multiplier::Float64 = 0.25,
        procedure_costs::Dict{String, Float64} = Dict(),
        severity_adjustor::Float64 = 1.0
    )
        new(drg_base_rates, complication_multiplier, procedure_costs, severity_adjustor)
    end
end

"""
    DailyRateCostModel

Per-diem costing model based on daily rates and LOS.
"""
struct DailyRateCostModel <: CostModel
    base_daily_rate::Float64
    daily_rates_by_service::Dict{String, Float64}
    fixed_admission_cost::Float64
end

"""
    RVUCostModel

Relative Value Unit (RVU) based costing.
"""
struct RVUCostModel <: CostModel
    rvu_conversion_factor::Float64
    procedure_rvus::Dict{String, Float64}
    base_cost_offset::Float64
end

"""
    ActivityBasedCostModel

Activity-based costing tracking specific cost drivers.
"""
struct ActivityBasedCostModel <: CostModel
    labor_cost_per_hour::Float64
    material_costs::Dict{String, Float64}
    fixed_overhead_per_day::Float64
end

# ═══════════════════════════════════════════════════════════════
# COST CALCULATION
# ═══════════════════════════════════════════════════════════════

"""
    calculate_episode_cost(episode::Episode, model::DRGCostModel)::Float64

Calculate total episode cost using DRG model.
"""
function calculate_episode_cost(episode::Episode, model::DRGCostModel)::Float64
    # Base DRG cost
    base_cost = get(model.drg_base_rates, episode.drg_code, 8000.0)
    
    # Complication adjustment
    complication_cost = length(episode.complications) * base_cost * model.complication_multiplier
    
    # Procedure costs
    procedure_cost = sum(
        get(model.procedure_costs, proc, 0.0) for proc in episode.procedures
    )
    
    # Severity adjustment
    total_cost = (base_cost + complication_cost + procedure_cost) * model.severity_adjustor
    
    # Payer adjustment
    payer_mult = PAYER_MULTIPLIERS[episode.payer]
    
    return total_cost * payer_mult
end

"""
    calculate_episode_cost(episode::Episode, model::DailyRateCostModel)::Float64

Calculate total episode cost using daily rate model.
"""
function calculate_episode_cost(episode::Episode, model::DailyRateCostModel)::Float64
    daily_cost = get(model.daily_rates_by_service, episode.setting, model.base_daily_rate)
    total_cost = model.fixed_admission_cost + (daily_cost * episode.los)
    
    payer_mult = PAYER_MULTIPLIERS[episode.payer]
    return total_cost * payer_mult
end

"""
    episode_cost_breakdown(episode::Episode, model::CostModel)::Dict{String, Float64}

Return cost breakdown by component.
"""
function episode_cost_breakdown(episode::Episode, model::DRGCostModel)::Dict{String, Float64}
    base_cost = get(model.drg_base_rates, episode.drg_code, 8000.0)
    complication_cost = length(episode.complications) * base_cost * model.complication_multiplier
    procedure_cost = sum(
        get(model.procedure_costs, proc, 0.0) for proc in episode.procedures
    )
    
    return Dict(
        "base_drg" => base_cost,
        "complications" => complication_cost,
        "procedures" => procedure_cost,
        "subtotal" => base_cost + complication_cost + procedure_cost,
        "severity_adjusted" => (base_cost + complication_cost + procedure_cost) * model.severity_adjustor,
        "final_payer_adjusted" => calculate_episode_cost(episode, model)
    )
end
