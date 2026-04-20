# patient_flow/FlowSimulation.jl
# Patient flow simulation with cost tracking

using Dates
using Statistics
using Random
using Distributions
using StatsBase

"""
    ServiceLineCapacity

Tracks bed availability and resource constraints for a service line.
"""
struct ServiceLineCapacity
    service_line::String
    total_beds::Int
    occupied_beds::Int
    available_beds::Int
    or_minutes_available::Float64
    or_minutes_used::Float64
end

"""
    HospitalSimulation

Main simulation state for hospital patient flow with cost accumulation.

# Fields
- `hospital_name::String` — Hospital identifier
- `patients::Vector{PatientAgent}` — All patients in simulation
- `time_now::Float64` — Current simulation time (hours)
- `time_end::Float64` — Simulation end time (hours)
- `cost_model::Union{DRGCostModel, RVUCostModel, ActivityBasedCostModel}` — Cost calculation model
- `service_lines::Dict{String, ServiceLineCapacity}` — Capacity tracking per service
- `daily_costs::Dict{Date, Float64}` — Total costs by day
- `daily_census::Dict{Date, Int}` — Patient count by day
- `daily_admissions::Dict{Date, Int}` — Admissions by day
- `daily_discharges::Dict{Date, Int}` — Discharges by day
- `cost_results::Dict{String, Any}` — Summary results
"""
mutable struct HospitalSimulation
    hospital_name::String
    patients::Vector{PatientAgent}
    time_now::Float64
    time_end::Float64
    cost_model::Union{DRGCostModel, RVUCostModel, ActivityBasedCostModel}
    service_lines::Dict{String, ServiceLineCapacity}
    daily_costs::Dict{Date, Float64}
    daily_census::Dict{Date, Int}
    daily_admissions::Dict{Date, Int}
    daily_discharges::Dict{Date, Int}
    cost_results::Dict{String, Any}

    function HospitalSimulation(;
        hospital_name::String = "Rural Hospital",
        num_days::Int = 30,
        cost_model::Union{DRGCostModel, RVUCostModel, ActivityBasedCostModel} = create_standard_drg_model(),
        service_lines::Dict{String, ServiceLineCapacity} = Dict{String, ServiceLineCapacity}()
    )
        time_end = num_days * 24.0

        default_services = Dict(
            "ED" => ServiceLineCapacity("ED", 12, 0, 12, 480.0, 0.0),
            "General Ward" => ServiceLineCapacity("General Ward", 30, 0, 30, 0.0, 0.0),
            "ICU" => ServiceLineCapacity("ICU", 8, 0, 8, 0.0, 0.0),
            "OR" => ServiceLineCapacity("OR", 4, 0, 4, 8 * 60, 0.0),
            "Cardiology" => ServiceLineCapacity("Cardiology", 12, 0, 12, 240.0, 0.0),
            "Orthopedics" => ServiceLineCapacity("Orthopedics", 10, 0, 10, 300.0, 0.0)
        )

        services = isempty(service_lines) ? default_services : service_lines

        new(
            hospital_name,
            PatientAgent[],
            0.0,
            time_end,
            cost_model,
            services,
            Dict{Date, Float64}(),
            Dict{Date, Int}(),
            Dict{Date, Int}(),
            Dict{Date, Int}(),
            Dict{String, Any}()
        )
    end
end

"""
    generate_admission(sim::HospitalSimulation, admission_date::Date, arrival_time::Float64)::PatientAgent

Generate a new patient admission with realistic diagnosis and service routing.
"""
function generate_admission(sim::HospitalSimulation, admission_date::Date, arrival_time::Float64)::PatientAgent
    patient_id = "PT_$(length(sim.patients) + 1)"

    # Realistic DRG distribution for rural hospital
    drg_codes = collect(keys(DRG_BASE_RATES))
    drg_code = rand(drg_codes)

    # Map DRG to likely service line
    service_map = Dict(
        "246" => "Cardiology",
        "247" => "Cardiology",
        "248" => "Cardiology",
        "164" => "Orthopedics",
        "165" => "Orthopedics",
        "166" => "Orthopedics",
        "469" => "General Ward",
        "470" => "General Ward",
        "471" => "General Ward",
        "373" => "General Ward",
        "374" => "General Ward",
        "375" => "General Ward"
    )
    service_line = get(service_map, drg_code, "General Ward")

    # Secondary diagnoses (comorbidities)
    has_comorbidity = rand() < 0.4
    secondary_diagnoses = has_comorbidity ? ["CC_001", "CC_002"] : String[]

    # Payer mix (realistic rural hospital distribution)
    payer_weights = [0.45, 0.25, 0.20, 0.10]
    payer_types = ["Medicare", "Medicaid", "Commercial", "Uninsured"]
    payer = sample(payer_types, Weights(payer_weights))

    # LOS target based on DRG
    los_target = rand(2:5)

    patient = PatientAgent(
        id=patient_id,
        arrival_time=arrival_time,
        admission_date=admission_date,
        primary_diagnosis="I21",
        secondary_diagnoses=secondary_diagnoses,
        drg_code=drg_code,
        assigned_service_line=service_line,
        location="waiting",
        los_target=los_target,
        payer=payer
    )

    initialize_patient_cost_tracking(patient, los_target)
    return patient
end

"""
    route_patient!(patient::PatientAgent, sim::HospitalSimulation)

Route patient from ED to appropriate service line based on triage.
"""
function route_patient!(patient::PatientAgent, sim::HospitalSimulation)
    service = patient.assigned_service_line

    # Update patient location
    if service == "Cardiology" || service == "Orthopedics"
        patient.location = "ward"
    else
        patient.location = "general ward"
    end

    # Check for ICU admission (10% of cases with comorbidities)
    if patient.comorbidity_count >= 2 && rand() < 0.10
        patient.location = "ICU"
    end

    # Procedure probability (increases with orthopedics)
    if service == "Orthopedics" && rand() < 0.60
        add_procedure_cost!(patient, "99213", 2500.0)
        patient.location = "OR"
    end
end

"""
    accumulate_daily_costs!(
        sim::HospitalSimulation,
        patient::PatientAgent,
        day_index::Int,
        hospital_date::Date
    )

Accumulate daily costs for a patient based on location and LOS.
"""
function accumulate_daily_costs!(
    sim::HospitalSimulation,
    patient::PatientAgent,
    day_index::Int,
    hospital_date::Date
)
    if patient.location == "discharged"
        return
    end

    # Daily costs vary by location
    labor_cost = 0.0
    supplies_cost = 0.0
    overhead_cost = 0.0
    bed_cost = 0.0

    # Base daily bed cost
    if patient.location == "ICU"
        bed_cost = 3000.0
        labor_cost = 2000.0
        supplies_cost = 800.0
    elseif patient.location == "OR"
        bed_cost = 0.0
        labor_cost = 3500.0
        supplies_cost = 2000.0
    elseif patient.location in ["ward", "general ward"]
        bed_cost = 1500.0
        labor_cost = 800.0
        supplies_cost = 300.0
    else  # waiting
        bed_cost = 0.0
        labor_cost = 200.0
        supplies_cost = 50.0
    end

    # Overhead allocation (20% of direct costs)
    overhead_cost = (labor_cost + supplies_cost + bed_cost) * 0.20

    accumulate_daily_cost!(patient, day_index, labor_cost, supplies_cost, overhead_cost)

    # Update bed cost in daily_costs
    patient.daily_costs["bed"] = get(patient.daily_costs, "bed", 0.0) + bed_cost

    # Track total daily cost for hospital
    daily_total = labor_cost + supplies_cost + overhead_cost + bed_cost
    if !haskey(sim.daily_costs, hospital_date)
        sim.daily_costs[hospital_date] = 0.0
    end
    sim.daily_costs[hospital_date] += daily_total
end

"""
    discharge_patient_with_costs!(
        sim::HospitalSimulation,
        patient::PatientAgent,
        discharge_date::Date
    )

Complete patient episode with final cost calculation.
"""
function discharge_patient_with_costs!(
    sim::HospitalSimulation,
    patient::PatientAgent,
    discharge_date::Date
)
    discharge_patient!(patient, discharge_date)

    # Update daily discharge count
    if !haskey(sim.daily_discharges, discharge_date)
        sim.daily_discharges[discharge_date] = 0
    end
    sim.daily_discharges[discharge_date] += 1
end

"""
    simulate_patient_day!(
        sim::HospitalSimulation,
        patient::PatientAgent,
        simulation_day::Int,
        hospital_date::Date
    )

Simulate one day in hospital for a patient (cost accumulation, discharge check).
"""
function simulate_patient_day!(
    sim::HospitalSimulation,
    patient::PatientAgent,
    simulation_day::Int,
    hospital_date::Date
)
    if patient.location == "discharged"
        return
    end

    # Accumulate costs for the day
    accumulate_daily_costs!(sim, patient, simulation_day, hospital_date)

    # Check for discharge (after meeting LOS target)
    los_actual = simulation_day - 1
    discharge_prob = 0.0

    if los_actual >= patient.los_target
        # Discharge probability increases with LOS
        discharge_prob = 0.4 + 0.1 * (los_actual - patient.los_target)
    end

    if rand() < discharge_prob || los_actual > patient.los_target + 5
        discharge_patient_with_costs!(sim, patient, hospital_date)
    end
end

"""
    simulate_hospital_flow!(
        sim::HospitalSimulation,
        admission_rate_per_day::Float64
    )

Run multi-day hospital simulation with patient admissions, routing, and discharges.
"""
function simulate_hospital_flow!(
    sim::HospitalSimulation,
    admission_rate_per_day::Float64 = 3.5
)
    num_days = Int(ceil(sim.time_end / 24.0))
    start_date = Date(2026, 4, 1)

    for day = 1:num_days
        hospital_date = start_date + Day(day - 1)

        # Generate admissions for this day (Poisson process)
        num_admissions = rand(Poisson(admission_rate_per_day))

        for admission_idx = 1:num_admissions
            arrival_hour = rand() * 24.0  # Uniformly distributed throughout day
            arrival_time = (day - 1) * 24.0 + arrival_hour

            patient = generate_admission(sim, hospital_date, arrival_time)
            push!(sim.patients, patient)

            # Route to service line
            route_patient!(patient, sim)

            # Update admission count
            if !haskey(sim.daily_admissions, hospital_date)
                sim.daily_admissions[hospital_date] = 0
            end
            sim.daily_admissions[hospital_date] += 1
        end

        # Simulate one day for all in-hospital patients
        for patient in sim.patients
            simulate_patient_day!(sim, patient, day, hospital_date)
        end

        # Update census
        census = count(p -> p.location != "discharged", sim.patients)
        sim.daily_census[hospital_date] = census
    end

    finalize_simulation!(sim)
end

"""
    finalize_simulation!(sim::HospitalSimulation)

Calculate summary statistics after simulation ends.
"""
function finalize_simulation!(sim::HospitalSimulation)
    discharged_patients = [p for p in sim.patients if p.location == "discharged"]

    total_cost = sum(p.cumulative_cost for p in discharged_patients)
    total_patients = length(discharged_patients)

    if total_patients > 0
        avg_cost = total_cost / total_patients
        std_cost = std([p.cumulative_cost for p in discharged_patients])
    else
        avg_cost = 0.0
        std_cost = 0.0
    end

    # Aggregate by service line
    service_costs = Dict{String, Float64}()
    service_volumes = Dict{String, Int}()

    for patient in discharged_patients
        service = patient.assigned_service_line
        if !haskey(service_costs, service)
            service_costs[service] = 0.0
            service_volumes[service] = 0
        end
        service_costs[service] += patient.cumulative_cost
        service_volumes[service] += 1
    end

    # Calculate service line margins (assuming 1.3× cost multiplier for revenue)
    service_margins = Dict{String, Float64}()
    for (service, cost) in service_costs
        volume = service_volumes[service]
        revenue = cost * 1.3
        margin = revenue - cost
        service_margins[service] = margin / volume  # per-case margin
    end

    total_daily_cost = sum(values(sim.daily_costs))

    sim.cost_results = Dict(
        "total_cost" => total_cost,
        "total_patients" => total_patients,
        "mean_cost_per_patient" => avg_cost,
        "std_cost_per_patient" => std_cost,
        "total_daily_cost" => total_daily_cost,
        "service_line_costs" => service_costs,
        "service_line_volumes" => service_volumes,
        "service_line_margins" => service_margins,
        "total_admissions" => sum(values(sim.daily_admissions)),
        "total_discharges" => sum(values(sim.daily_discharges)),
        "average_los" => mean([
            Dates.value(p.discharge_date - p.admission_date) for p in discharged_patients if !isnothing(p.discharge_date)
        ])
    )
end

"""
    get_simulation_summary(sim::HospitalSimulation)::Dict{String, Any}

Return summary statistics from completed simulation.
"""
function get_simulation_summary(sim::HospitalSimulation)::Dict{String, Any}
    return copy(sim.cost_results)
end

"""
    simulate_patient_cohort(n_patients::Int; cost_model::Union{DRGCostModel, RVUCostModel, ActivityBasedCostModel} = create_standard_drg_model())

Quick simulation of n patients through hospital for testing.
"""
function simulate_patient_cohort(
    n_patients::Int;
    cost_model::Union{DRGCostModel, RVUCostModel, ActivityBasedCostModel} = create_standard_drg_model()
)
    sim = HospitalSimulation(
        hospital_name="Test Hospital",
        num_days=30,
        cost_model=cost_model
    )

    # Estimate admission rate needed to get n_patients
    target_admission_rate = n_patients / 30.0

    simulate_hospital_flow!(sim, target_admission_rate)

    return sim
end
