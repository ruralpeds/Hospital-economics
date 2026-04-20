# network/HospitalNetworkSimulation.jl
# Multi-hospital network simulation with patient routing and referral patterns

using Dates
using Statistics
using Random
using Distributions
using StatsBase
using LinearAlgebra

"""
    Hospital

Represents a single hospital in a network with capacity and capabilities.

# Fields
- `hospital_id::String` — Unique identifier
- `hospital_name::String` — Display name
- `location::Tuple{Float64, Float64}` — Geographic coordinates (lat, lon)
- `total_beds::Int` — Total bed capacity
- `service_lines::Set{String}` — Available services (Cardiology, Orthopedics, etc.)
- `specialty_capabilities::Set{String}` — Specialized services (Trauma, NICU, etc.)
- `bed_utilization::Float64` — Current % bed occupancy (0-1)
- `quality_score::Float64` — Quality metric (0-1, 1=best)
- `payer_mix::Dict{String, Float64}` — Distribution of patient payers
"""
struct Hospital
    hospital_id::String
    hospital_name::String
    location::Tuple{Float64, Float64}
    total_beds::Int
    service_lines::Set{String}
    specialty_capabilities::Set{String}
    bed_utilization::Float64
    quality_score::Float64
    payer_mix::Dict{String, Float64}
end

"""
    HospitalNetwork

Multi-hospital network with patient routing and referral patterns.

# Fields
- `hospitals::Dict{String, Hospital}` — All hospitals in network
- `network_name::String` — Network identifier
- `referral_matrix::Matrix{Float64}` — Hospital-to-hospital referral probabilities
- `patient_choice_model::String` — How patients choose hospitals (distance, quality, cost, hybrid)
- `geographic_region::Tuple{Float64, Float64, Float64, Float64}` — Bounding box (minlat, maxlat, minlon, maxlon)
- `patients::Vector{PatientAgent}` — All patients in network
- `time_now::Float64` — Current simulation time (hours)
- `time_end::Float64` — Simulation end time
- `network_results::Dict{String, Any}` — Aggregated results
"""
mutable struct HospitalNetwork
    hospitals::Dict{String, Hospital}
    network_name::String
    referral_matrix::Matrix{Float64}
    patient_choice_model::String
    geographic_region::Tuple{Float64, Float64, Float64, Float64}
    patients::Vector{PatientAgent}
    time_now::Float64
    time_end::Float64
    network_results::Dict{String, Any}

    function HospitalNetwork(;
        network_name::String = "Rural Health Network",
        num_hospitals::Int = 5,
        num_days::Int = 30,
        patient_choice_model::String = "hybrid"
    )
        hospitals = Dict{String, Hospital}()
        time_end = num_days * 24.0

        # Create hospital network
        for i in 1:num_hospitals
            hosp_id = "H$(i)"
            hosp_name = ["Regional Medical Center", "Community Hospital", "Critical Access Hospital",
                        "Specialty Center", "Rural Hospital"][min(i, 5)]

            # Geographic distribution (within a ~100 mile radius)
            lat = 38.5 + rand(-2.0:0.1:2.0)
            lon = -84.0 + rand(-2.0:0.1:2.0)

            # Larger hospitals have more beds
            total_beds = i == 1 ? 250 : (i <= 2 ? 150 : (i <= 3 ? 80 : 50))

            # Service lines vary by hospital size
            service_lines = Set(["General Ward", "ED"])
            if i <= 2
                push!(service_lines, "Cardiology", "Orthopedics", "ICU")
            elseif i <= 3
                push!(service_lines, "Cardiology", "Orthopedics")
            end

            # Specialty capabilities
            specialty_capabilities = Set{String}()
            if i == 1
                specialty_capabilities = Set(["Trauma", "NICU", "Transplant"])
            elseif i == 2
                specialty_capabilities = Set(["Cardiac Cath Lab", "Level II Trauma"])
            end

            hospital = Hospital(
                hosp_id, hosp_name, (lat, lon), total_beds,
                service_lines, specialty_capabilities,
                0.0, 0.7 + 0.2 * rand(),  # Quality 0.7-0.9
                Dict("Medicare" => 0.45, "Medicaid" => 0.25, "Commercial" => 0.20, "Uninsured" => 0.10)
            )

            hospitals[hosp_id] = hospital
        end

        # Initialize referral matrix (identity + some cross-referrals)
        n = num_hospitals
        referral_matrix = diagm(ones(n)) * 0.7 + rand(n, n) * 0.05
        for i in 1:n
            referral_matrix[i, :] = referral_matrix[i, :] ./ sum(referral_matrix[i, :])
        end

        geographic_region = (36.5, 40.5, -86.0, -82.0)

        new(
            hospitals, network_name, referral_matrix, patient_choice_model,
            geographic_region, PatientAgent[], 0.0, time_end, Dict{String, Any}()
        )
    end
end

"""
    calculate_distance(loc1::Tuple{Float64, Float64}, loc2::Tuple{Float64, Float64})::Float64

Calculate distance between two geographic locations (rough approximation in miles).
"""
function calculate_distance(loc1::Tuple{Float64, Float64}, loc2::Tuple{Float64, Float64})::Float64
    # Rough approximation: 1 degree ≈ 69 miles
    lat_diff = (loc2[1] - loc1[1]) * 69
    lon_diff = (loc2[2] - loc1[2]) * 69 * cos(deg2rad(loc1[1]))
    return sqrt(lat_diff^2 + lon_diff^2)
end

"""
    choose_hospital(
        network::HospitalNetwork,
        patient::PatientAgent,
        patient_location::Tuple{Float64, Float64}
    )::String

Determine which hospital should treat this patient based on choice model and availability.
"""
function choose_hospital(
    network::HospitalNetwork,
    patient::PatientAgent,
    patient_location::Tuple{Float64, Float64}
)::String
    hospitals = values(network.hospitals)
    hospital_ids = collect(keys(network.hospitals))

    if network.patient_choice_model == "distance"
        # Choose nearest hospital with required services
        best_hosp = nothing
        best_distance = Inf

        for (hosp_id, hosp) in network.hospitals
            if patient.assigned_service_line in hosp.service_lines
                dist = calculate_distance(patient_location, hosp.location)
                if dist < best_distance
                    best_distance = dist
                    best_hosp = hosp_id
                end
            end
        end

        return best_hosp !== nothing ? best_hosp : first(hospital_ids)

    elseif network.patient_choice_model == "quality"
        # Choose best-quality hospital with required services
        best_hosp = nothing
        best_quality = -1.0

        for (hosp_id, hosp) in network.hospitals
            if patient.assigned_service_line in hosp.service_lines
                if hosp.quality_score > best_quality
                    best_quality = hosp.quality_score
                    best_hosp = hosp_id
                end
            end
        end

        return best_hosp !== nothing ? best_hosp : first(hospital_ids)

    elseif network.patient_choice_model == "hybrid"
        # Combination of distance and quality
        scores = Float64[]
        valid_ids = String[]

        for (hosp_id, hosp) in network.hospitals
            if patient.assigned_service_line in hosp.service_lines
                dist = calculate_distance(patient_location, hosp.location)
                # Score: quality - normalized distance
                score = hosp.quality_score - (dist / 50.0) * 0.3
                push!(scores, score)
                push!(valid_ids, hosp_id)
            end
        end

        if !isempty(valid_ids)
            best_idx = argmax(scores)
            return valid_ids[best_idx]
        else
            return first(hospital_ids)
        end
    else
        # Random selection
        return rand(hospital_ids)
    end
end

"""
    route_patient_to_hospital!(
        network::HospitalNetwork,
        patient::PatientAgent,
        patient_location::Tuple{Float64, Float64}
    )

Assign patient to a hospital in the network based on routing logic.
"""
function route_patient_to_hospital!(
    network::HospitalNetwork,
    patient::PatientAgent,
    patient_location::Tuple{Float64, Float64}
)
    hospital_id = choose_hospital(network, patient, patient_location)

    if haskey(network.hospitals, hospital_id)
        hospital = network.hospitals[hospital_id]
        patient.metadata["assigned_hospital"] = hospital_id
        patient.metadata["hospital_name"] = hospital.hospital_name
        patient.metadata["distance_to_hospital"] = calculate_distance(patient_location, hospital.location)
    end
end

"""
    generate_network_admissions(
        network::HospitalNetwork,
        population_size::Int,
        admission_rate_per_day::Float64
    )

Generate patient admissions distributed across network hospitals.
"""
function generate_network_admissions(
    network::HospitalNetwork,
    population_size::Int,
    admission_rate_per_day::Float64
)
    num_days = Int(ceil(network.time_end / 24.0))
    start_date = Date(2026, 4, 1)

    # Counter for patient IDs
    patient_counter = 0

    for day = 1:num_days
        hospital_date = start_date + Day(day - 1)

        # Generate admissions
        num_admissions = rand(Poisson(admission_rate_per_day))

        for admission_idx = 1:num_admissions
            arrival_hour = rand() * 24.0
            arrival_time = (day - 1) * 24.0 + arrival_hour

            # Generate patient directly without needing HospitalSimulation instance
            patient_counter += 1
            patient_id = "PT_$(patient_counter)"

            # Create realistic patient with DRG distribution
            drg_codes = ["39900", "39401", "28340", "40110", "41401", "33022", "35901"]
            drg_code = rand(drg_codes)

            # Map DRG to service line
            service_line_map = Dict(
                "39900" => "Cardiology",
                "39401" => "Orthopedics",
                "28340" => "General Ward",
                "40110" => "Cardiology",
                "41401" => "Orthopedics",
                "33022" => "General Ward",
                "35901" => "General Ward"
            )
            assigned_service_line = service_line_map[drg_code]

            # Create patient
            patient = PatientAgent(
                id=patient_id,
                arrival_time=arrival_time,
                admission_date=hospital_date,
                primary_diagnosis="I10",
                secondary_diagnoses=String[],
                drg_code=drg_code,
                assigned_service_line=assigned_service_line,
                location="waiting",
                los_target=rand(2:6),
                cumulative_cost=0.0,
                cost_by_day=Float64[],
                daily_costs=Dict{String, Float64}("labor" => 0.0, "supplies" => 0.0, "overhead" => 0.0),
                resource_utilization=Dict{String, Float64}(),
                procedures=String[],
                payer=rand(["Medicare", "Medicaid", "Commercial", "Uninsured"]),
                comorbidity_count=rand(0:3),
                discharge_date=nothing,
                metadata=Dict{String, Any}()
            )

            patient = patient  # Assign to patient variable

            # Assign to hospital in network
            patient_location = (network.geographic_region[1] + rand() * (network.geographic_region[2] - network.geographic_region[1]),
                               network.geographic_region[3] + rand() * (network.geographic_region[4] - network.geographic_region[3]))

            route_patient_to_hospital!(network, patient, patient_location)

            push!(network.patients, patient)
        end
    end
end

"""
    simulate_network_flow!(
        network::HospitalNetwork,
        population_size::Int,
        admission_rate_per_day::Float64
    )

Run multi-day, multi-hospital network simulation.
"""
function simulate_network_flow!(
    network::HospitalNetwork,
    population_size::Int,
    admission_rate_per_day::Float64 = 3.5
)
    # Generate and route patient admissions
    generate_network_admissions(network, population_size, admission_rate_per_day)

    # Simulate each day for all patients
    num_days = Int(ceil(network.time_end / 24.0))
    start_date = Date(2026, 4, 1)

    for day = 1:num_days
        hospital_date = start_date + Day(day - 1)

        # Process each patient for the day
        for patient in network.patients
            if patient.location == "discharged"
                continue
            end

            # Accumulate daily costs (simplified for network simulation)
            # Base costs depend on location
            daily_cost = 0.0
            if patient.location == "waiting"
                daily_cost = 200.0  # ED costs
            elseif patient.location == "ward"
                daily_cost = 1500.0  # Ward bed and staff
            elseif patient.location == "OR"
                daily_cost = 3500.0  # OR labor and equipment
            elseif patient.location == "ICU"
                daily_cost = 3000.0  # ICU bed and monitoring
            end

            push!(patient.cost_by_day, daily_cost)
            patient.cumulative_cost += daily_cost

            # Check for discharge (simplified logic)
            los_actual = day - 1
            discharge_prob = 0.0

            if los_actual >= patient.los_target
                discharge_prob = 0.4 + 0.1 * (los_actual - patient.los_target)
            end

            if rand() < discharge_prob || los_actual > patient.los_target + 5
                patient.location = "discharged"
                patient.discharge_date = hospital_date
            elseif patient.location == "waiting"
                # Route from waiting to appropriate unit
                if patient.assigned_service_line in ["Cardiology", "Orthopedics"]
                    patient.location = "ward"
                else
                    patient.location = "ward"
                end
            end
        end
    end

    finalize_network_results!(network)
end

"""
    finalize_network_results!(network::HospitalNetwork)

Calculate aggregated network-level statistics.
"""
function finalize_network_results!(network::HospitalNetwork)
    discharged_patients = [p for p in network.patients if p.location == "discharged"]

    if isempty(discharged_patients)
        network.network_results = Dict{String, Any}()
        return
    end

    # Total costs
    total_cost = sum(p.cumulative_cost for p in discharged_patients)
    avg_cost = total_cost / length(discharged_patients)

    # Hospital-level aggregation
    hospital_costs = Dict{String, Float64}()
    hospital_volumes = Dict{String, Int}()
    hospital_quality = Dict{String, Vector{Float64}}()

    for patient in discharged_patients
        hosp_id = get(patient.metadata, "assigned_hospital", "Unknown")

        if !haskey(hospital_costs, hosp_id)
            hospital_costs[hosp_id] = 0.0
            hospital_volumes[hosp_id] = 0
            hospital_quality[hosp_id] = Float64[]
        end

        hospital_costs[hosp_id] += patient.cumulative_cost
        hospital_volumes[hosp_id] += 1

        # Quality proxy based on comorbidities (lower comorbidities = higher quality)
        quality = 1.0 - (patient.comorbidity_count * 0.1)
        quality = max(0.0, min(1.0, quality))  # Clamp to [0, 1]
        push!(hospital_quality[hosp_id], quality)
    end

    # Calculate per-hospital margins
    hospital_margins = Dict{String, Float64}()
    for (hosp_id, cost) in hospital_costs
        volume = hospital_volumes[hosp_id]
        avg_hosp_cost = cost / volume
        revenue = avg_hosp_cost * 1.3
        margin = revenue - avg_hosp_cost
        hospital_margins[hosp_id] = margin
    end

    # Calculate referral patterns
    referral_patterns = Dict{String, Dict{String, Int}}()
    for patient in network.patients
        origin = get(patient.metadata, "assigned_hospital", "Unknown")
        if !haskey(referral_patterns, origin)
            referral_patterns[origin] = Dict{String, Int}()
        end
        # Count admissions per hospital (simplified: just track origin)
        if !haskey(referral_patterns[origin], "admissions")
            referral_patterns[origin]["admissions"] = 0
        end
        referral_patterns[origin]["admissions"] += 1
    end

    network.network_results = Dict(
        "total_patients" => length(discharged_patients),
        "total_cost" => total_cost,
        "avg_cost_per_patient" => avg_cost,
        "hospital_costs" => hospital_costs,
        "hospital_volumes" => hospital_volumes,
        "hospital_margins" => hospital_margins,
        "hospital_quality" => hospital_quality,
        "referral_patterns" => referral_patterns,
        "network_margin" => sum(values(hospital_margins))
    )
end

"""
    get_network_summary(network::HospitalNetwork)::Dict{String, Any}

Return summary statistics from completed network simulation.
"""
function get_network_summary(network::HospitalNetwork)::Dict{String, Any}
    return copy(network.network_results)
end

"""
    analyze_hospital_performance(
        network::HospitalNetwork,
        hospital_id::String
    )::Dict{String, Any}

Analyze individual hospital performance within network context.
"""
function analyze_hospital_performance(
    network::HospitalNetwork,
    hospital_id::String
)::Dict{String, Any}
    if !haskey(network.hospitals, hospital_id)
        return Dict{String, Any}()
    end

    hospital = network.hospitals[hospital_id]

    if !haskey(network.network_results, "hospital_volumes")
        return Dict{String, Any}()
    end

    volume = get(network.network_results["hospital_volumes"], hospital_id, 0)
    cost = get(network.network_results["hospital_costs"], hospital_id, 0.0)
    margin = get(network.network_results["hospital_margins"], hospital_id, 0.0)
    quality_scores = get(network.network_results["hospital_quality"], hospital_id, Float64[])

    avg_quality = isempty(quality_scores) ? 0.0 : mean(quality_scores)

    return Dict(
        "hospital_id" => hospital_id,
        "hospital_name" => hospital.hospital_name,
        "volume" => volume,
        "total_cost" => cost,
        "avg_cost_per_case" => volume > 0 ? cost / volume : 0.0,
        "contribution_margin" => margin,
        "avg_margin_per_case" => volume > 0 ? margin / volume : 0.0,
        "quality_score" => avg_quality,
        "bed_capacity" => hospital.total_beds,
        "services" => length(hospital.service_lines),
        "specialties" => length(hospital.specialty_capabilities)
    )
end

"""
    simulate_patient_cohort_network(
        n_patients::Int,
        num_hospitals::Int = 5
    )

Quick network simulation with n patients distributed across hospitals.
"""
function simulate_patient_cohort_network(
    n_patients::Int,
    num_hospitals::Int = 5
)
    network = HospitalNetwork(
        network_name="Test Network",
        num_hospitals=num_hospitals,
        num_days=30,
        patient_choice_model="hybrid"
    )

    target_admission_rate = n_patients / 30.0
    simulate_network_flow!(network, n_patients, target_admission_rate)

    return network
end
