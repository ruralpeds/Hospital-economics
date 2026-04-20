# patient_flow/PatientAgent.jl
# Patient agent definition with economic tracking

using Dates

"""
    PatientAgent

Mutable patient agent for discrete event simulation with cost accumulation.

# Fields
- `id::String` — Unique patient identifier
- `arrival_time::Float64` — Arrival time in simulation (hours from start)
- `admission_date::Date` — Actual calendar admission date
- `primary_diagnosis::String` — ICD-10 code for primary diagnosis
- `secondary_diagnoses::Vector{String}` — Additional diagnoses
- `drg_code::String` — Assigned DRG code
- `assigned_service_line::String` — Service line assignment (Cardiology, Orthopedics, etc.)
- `location::String` — Current location (waiting, ward, OR, ICU, discharged)
- `los_target::Int` — Planned length of stay (days)
- `cumulative_cost::Float64` — Total cost accumulated so far
- `cost_by_day::Vector{Float64}` — Daily cost breakdown
- `daily_costs::Dict{String, Float64}` — Cost by component (labor, supplies, overhead)
- `resource_utilization::Dict{String, Float64}` — Resources used (bed-days, OR-minutes, etc.)
- `procedures::Vector{String}` — Procedures performed
- `payer::String` — Payer type (Medicare, Medicaid, Commercial, Uninsured)
- `comorbidity_count::Int` — Number of secondary diagnoses
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
        discharge_date::Union{Date, Nothing} = nothing,
        metadata::Dict{String, Any} = Dict{String, Any}()
    )
        new(
            id, arrival_time, admission_date, primary_diagnosis, secondary_diagnoses,
            drg_code, assigned_service_line, location, los_target,
            cumulative_cost, cost_by_day, daily_costs, resource_utilization,
            procedures, payer, length(secondary_diagnoses), discharge_date, metadata
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
            "cost_components" => copy(patient.daily_costs)
        )
    )
end
