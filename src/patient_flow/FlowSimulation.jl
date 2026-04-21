# patient_flow/FlowSimulation.jl
# Patient flow simulation with cost tracking

using Dates
using Statistics
using Random

# ============================================================================
# Stdlib-only helpers replacing Distributions/StatsBase
# ============================================================================

"""
    poisson_rand(lambda::Float64)::Int

Sample from a Poisson distribution using Knuth's algorithm (stdlib only).
Efficient for lambda ≤ 50; for larger lambda the loop count grows proportionally.
In this simulation admission rates are typically 3–50 admissions/day.
"""
function poisson_rand(lambda::Float64)::Int
    L = exp(-lambda)
    k = 0
    p = 1.0
    while p > L
        k += 1
        p *= rand()
    end
    return k - 1
end

"""
    weighted_sample(items::Vector, weights::Vector{Float64})

Weighted random selection from items vector (stdlib only).
"""
function weighted_sample(items::Vector, weights::Vector{Float64})
    total = sum(weights)
    r = rand() * total
    cumulative = 0.0
    for (item, w) in zip(items, weights)
        cumulative += w
        if r <= cumulative
            return item
        end
    end
    return items[end]
end

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
            "Emergency"       => ServiceLineCapacity("Emergency",       20, 0, 20, 480.0, 0.0),
            "General Ward"    => ServiceLineCapacity("General Ward",    30, 0, 30,   0.0, 0.0),
            "ICU"             => ServiceLineCapacity("ICU",              8, 0,  8,   0.0, 0.0),
            "Cardiology"      => ServiceLineCapacity("Cardiology",      12, 0, 12, 240.0, 0.0),
            "Orthopedics"     => ServiceLineCapacity("Orthopedics",     10, 0, 10, 300.0, 0.0),
            "Obstetrics"      => ServiceLineCapacity("Obstetrics",       8, 0,  8,   0.0, 0.0),
            "Neurology"       => ServiceLineCapacity("Neurology",        8, 0,  8,   0.0, 0.0),
            "General Surgery" => ServiceLineCapacity("General Surgery", 10, 0, 10, 360.0, 0.0)
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

    # Weighted service line assignment (realistic hospital volume distribution)
    service_lines = ["Emergency", "General Ward", "Cardiology", "Orthopedics",
                     "Obstetrics", "ICU", "Neurology", "General Surgery"]
    service_weights = [0.25, 0.20, 0.15, 0.12, 0.10, 0.08, 0.05, 0.05]
    service_line = weighted_sample(service_lines, service_weights)

    # Map service line to representative DRG code
    service_drg_map = Dict(
        "Emergency"       => ["999"],
        "General Ward"    => ["469", "470", "471"],
        "Cardiology"      => ["246", "247", "248"],
        "Orthopedics"     => ["469", "470", "471"],
        "Obstetrics"      => ["373", "374", "375"],
        "ICU"             => ["246", "247"],
        "Neurology"       => ["023", "024"],
        "General Surgery" => ["164", "165", "166"]
    )
    drg_options = get(service_drg_map, service_line, ["247"])
    drg_code = drg_options[rand(1:length(drg_options))]

    # Secondary diagnoses (comorbidities — 40% of patients)
    has_comorbidity = rand() < 0.4
    secondary_diagnoses = has_comorbidity ? ["CC_001", "CC_002"] : String[]

    # Payer mix (realistic rural hospital distribution)
    payer_types   = ["Medicare", "Medicaid", "Commercial", "Uninsured"]
    payer_weights = [0.45, 0.25, 0.20, 0.10]
    payer = weighted_sample(payer_types, payer_weights)

    # LOS target varies by service line
    los_ranges = Dict(
        "Emergency"       => (1, 1),
        "General Ward"    => (2, 5),
        "Cardiology"      => (3, 7),
        "Orthopedics"     => (3, 7),
        "Obstetrics"      => (2, 4),
        "ICU"             => (3, 8),
        "Neurology"       => (3, 6),
        "General Surgery" => (2, 5)
    )
    lo, hi = get(los_ranges, service_line, (2, 5))
    los_target = rand(lo:hi)

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

Route patient from admission to appropriate location based on service line.
"""
function route_patient!(patient::PatientAgent, sim::HospitalSimulation)
    service = patient.assigned_service_line

    # Initial location by service line
    if service == "Emergency"
        patient.location = "general ward"
    elseif service in ["Cardiology", "Orthopedics", "Neurology", "General Surgery"]
        patient.location = "ward"
    elseif service == "ICU"
        patient.location = "ICU"
    else
        patient.location = "general ward"
    end

    # Escalate to ICU for high-comorbidity patients (10%)
    if patient.location != "ICU" && patient.comorbidity_count >= 2 && rand() < 0.10
        patient.location = "ICU"
    end

    # OR admission for surgical services
    if service == "Orthopedics" && rand() < 0.60
        add_procedure_cost!(patient, "99213", 2500.0)
        patient.location = "OR"
    elseif service == "General Surgery" && rand() < 0.75
        add_procedure_cost!(patient, "99213", 3000.0)
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

    # Include bed facility cost in patient's total cost
    patient.cumulative_cost += bed_cost
    if day_index <= length(patient.cost_by_day)
        patient.cost_by_day[day_index] += bed_cost
    end
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

    # Accumulate costs for the day (use simulation_day as the day index for cost arrays)
    accumulate_daily_costs!(sim, patient, simulation_day, hospital_date)

    # Actual patient LOS: days since their personal admission date
    los_actual = Dates.value(hospital_date - patient.admission_date)
    discharge_prob = 0.0

    if los_actual >= patient.los_target
        # Discharge probability increases with days beyond LOS target
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
        num_admissions = poisson_rand(admission_rate_per_day)

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
    service_costs   = Dict{String, Float64}()
    service_volumes = Dict{String, Int}()
    service_cost_sd = Dict{String, Float64}()

    # Aggregate cost components across all discharged patients
    total_labor    = sum(get(p.daily_costs, "labor",    0.0) for p in discharged_patients; init=0.0)
    total_supplies = sum(get(p.daily_costs, "supplies", 0.0) for p in discharged_patients; init=0.0)
    total_overhead = sum(get(p.daily_costs, "overhead", 0.0) for p in discharged_patients; init=0.0)

    service_patient_costs = Dict{String, Vector{Float64}}()

    for patient in discharged_patients
        service = patient.assigned_service_line
        if !haskey(service_costs, service)
            service_costs[service] = 0.0
            service_volumes[service] = 0
            service_patient_costs[service] = Float64[]
        end
        service_costs[service] += patient.cumulative_cost
        service_volumes[service] += 1
        push!(service_patient_costs[service], patient.cumulative_cost)
    end

    for (service, costs) in service_patient_costs
        service_cost_sd[service] = length(costs) > 1 ? std(costs) : 0.0
    end

    # Revenue multipliers per service line (realistic payer mix effects)
    revenue_multipliers = Dict(
        "Emergency"       => 0.95,  # ED typically under-reimbursed
        "General Ward"    => 1.10,
        "Cardiology"      => 1.35,
        "Orthopedics"     => 1.40,
        "Obstetrics"      => 1.05,
        "ICU"             => 1.20,
        "Neurology"       => 1.25,
        "General Surgery" => 1.30
    )

    # Calculate service line margins
    service_margins = Dict{String, Float64}()
    service_revenues = Dict{String, Float64}()
    for (service, cost) in service_costs
        multiplier = get(revenue_multipliers, service, 1.30)
        revenue = cost * multiplier
        service_revenues[service] = revenue
        service_margins[service] = revenue - cost  # total margin for service line
    end

    total_daily_cost = sum(values(sim.daily_costs))

    # Mean cost per patient per service line
    service_mean_cost = Dict{String, Float64}()
    for (service, cost) in service_costs
        volume = service_volumes[service]
        service_mean_cost[service] = volume > 0 ? cost / volume : 0.0
    end

    sim.cost_results = Dict(
        "total_cost"              => total_cost,
        "total_patients"          => total_patients,
        "mean_cost_per_patient"   => avg_cost,
        "std_cost_per_patient"    => std_cost,
        "total_daily_cost"        => total_daily_cost,
        "total_labor_cost"        => total_labor,
        "total_supplies_cost"     => total_supplies,
        "total_overhead_cost"     => total_overhead,
        "service_line_costs"      => service_costs,
        "service_line_volumes"    => service_volumes,
        "service_line_margins"    => service_margins,
        "service_line_revenues"   => service_revenues,
        "service_mean_cost"       => service_mean_cost,
        "service_cost_sd"         => service_cost_sd,
        "total_admissions"        => sum(values(sim.daily_admissions)),
        "total_discharges"        => sum(values(sim.daily_discharges)),
        "average_los"             => isempty(discharged_patients) ? 0.0 : mean([
            Dates.value(p.discharge_date - p.admission_date)
            for p in discharged_patients if !isnothing(p.discharge_date)
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
