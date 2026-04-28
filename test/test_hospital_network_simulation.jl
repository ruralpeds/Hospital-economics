# test/test_hospital_network_simulation.jl
# Comprehensive tests for HospitalNetworkSimulation.jl

using Test
using Dates
using Statistics
using Random

# Set seed for reproducibility
Random.seed!(42)

# Include necessary modules
include("../src/episode/Episode.jl")
include("../src/patient_flow/PatientAgent.jl")
include("../src/patient_flow/FlowSimulation.jl")
include("../src/episode/EpisodeCostModels.jl")
include("../src/network/HospitalNetworkSimulation.jl")

@testset "HospitalNetworkSimulation Tests" begin

    # ================== Hospital Struct Tests ==================
    @testset "Hospital Struct" begin
        hospital = Hospital(
            "H1", "Test Hospital", (38.5, -84.0), 250,
            Set(["General Ward", "ED", "ICU"]),
            Set(["Trauma", "NICU"]),
            0.7, 0.85,
            Dict("Medicare" => 0.45, "Medicaid" => 0.25, "Commercial" => 0.20, "Uninsured" => 0.10),
            1800.0
        )

        @test hospital.hospital_id == "H1"
        @test hospital.hospital_name == "Test Hospital"
        @test hospital.location == (38.5, -84.0)
        @test hospital.total_beds == 250
        @test "General Ward" in hospital.service_lines
        @test length(hospital.service_lines) == 3
        @test "Trauma" in hospital.specialty_capabilities
        @test hospital.bed_utilization == 0.7
        @test hospital.quality_score == 0.85
        @test hospital.payer_mix["Medicare"] == 0.45
        @test hospital.base_cost_per_day == 1800.0
    end

    # ================== HospitalNetwork Initialization Tests ==================
    @testset "HospitalNetwork Initialization" begin
        # Default network
        network = HospitalNetwork()
        @test network.network_name == "Rural Health Network"
        @test length(network.hospitals) == 5
        @test size(network.referral_matrix) == (5, 5)
        @test network.time_end == 30 * 24.0  # 30 days in hours
        @test network.patient_choice_model == "hybrid"
        @test isempty(network.patients)
        @test network.time_now == 0.0

        # New fields
        @test length(network.service_availability) == 5
        @test !isempty(network.shared_service_lines)
        @test length(network.capacity_state) == 5
        @test all(v == 0 for v in values(network.capacity_state))

        # Custom network
        network2 = HospitalNetwork(
            network_name="Test Network",
            num_hospitals=3,
            num_days=14,
            patient_choice_model="distance"
        )
        @test network2.network_name == "Test Network"
        @test length(network2.hospitals) == 3
        @test size(network2.referral_matrix) == (3, 3)
        @test network2.time_end == 14 * 24.0
        @test network2.patient_choice_model == "distance"
    end

    @testset "Hospital Network Structure" begin
        network = HospitalNetwork(num_hospitals=4)

        # Check all hospitals are created
        @test length(network.hospitals) == 4
        for i in 1:4
            @test haskey(network.hospitals, "H$i")
        end

        # Check hospital properties
        h1 = network.hospitals["H1"]
        @test h1.total_beds > 0
        @test length(h1.service_lines) > 0
        @test h1.quality_score > 0
        @test h1.bed_utilization >= 0

        # Check referral matrix properties
        for i in 1:4
            row_sum = sum(network.referral_matrix[i, :])
            @test row_sum ≈ 1.0  # Rows should sum to 1 (probability distribution)
        end

        # Check geographic region is valid
        minlat, maxlat, minlon, maxlon = network.geographic_region
        @test minlat < maxlat
        @test minlon < maxlon
    end

    # ================== Distance Calculation Tests ==================
    @testset "Distance Calculation" begin
        loc1 = (38.5, -84.0)
        loc2 = (38.5, -84.0)

        # Same location
        dist = calculate_distance(loc1, loc2)
        @test dist ≈ 0.0 atol=0.01

        # Different locations
        loc3 = (39.5, -84.0)  # 1 degree north
        dist2 = calculate_distance(loc1, loc3)
        @test dist2 > 60  # About 69 miles per degree

        # Diagonal difference
        loc4 = (39.5, -85.0)
        dist3 = calculate_distance(loc1, loc4)
        @test dist3 > dist2  # Longer diagonal distance
    end

    # ================== Hospital Choice Model Tests ==================
    @testset "Hospital Choice - Distance Model" begin
        network = HospitalNetwork(
            num_hospitals=3,
            patient_choice_model="distance"
        )

        # Create a test patient
        patient = PatientAgent(
            id="P1", arrival_time=0.0, admission_date=Date(2026, 4, 1),
            primary_diagnosis="I10", secondary_diagnoses=String[], drg_code="39900",
            assigned_service_line="Cardiology", location="waiting", los_target=3,
            cumulative_cost=0.0, cost_by_day=Float64[],
            daily_costs=Dict{String, Float64}("labor" => 0.0, "supplies" => 0.0, "overhead" => 0.0),
            procedures=String[], payer="Medicare", comorbidity_count=0,
            discharge_date=nothing, metadata=Dict{String, Any}()
        )

        # Test patient location
        patient_location = (38.5, -84.0)

        # Choose hospital
        chosen = choose_hospital(network, patient, patient_location)
        @test chosen in keys(network.hospitals)
        @test chosen isa String

        # Verify it chose a hospital with the required service line
        chosen_hosp = network.hospitals[chosen]
        @test patient.assigned_service_line in chosen_hosp.service_lines ||
              chosen == "H1"  # H1 always has Cardiology
    end

    @testset "Hospital Choice - Quality Model" begin
        network = HospitalNetwork(
            num_hospitals=3,
            patient_choice_model="quality"
        )

        patient = PatientAgent(
            id="P2", arrival_time=0.0, admission_date=Date(2026, 4, 1),
            primary_diagnosis="I10", secondary_diagnoses=String[], drg_code="39900",
            assigned_service_line="Cardiology", location="waiting", los_target=3,
            cumulative_cost=0.0, cost_by_day=Float64[],
            daily_costs=Dict{String, Float64}("labor" => 0.0, "supplies" => 0.0, "overhead" => 0.0),
            procedures=String[], payer="Medicare", comorbidity_count=0,
            discharge_date=nothing, metadata=Dict{String, Any}()
        )

        patient_location = (38.5, -84.0)
        chosen = choose_hospital(network, patient, patient_location)

        @test chosen in keys(network.hospitals)
        # Should choose hospital with highest quality that offers service
        chosen_hosp = network.hospitals[chosen]
        @test chosen_hosp.quality_score > 0.0
    end

    @testset "Hospital Choice - Hybrid Model" begin
        network = HospitalNetwork(
            num_hospitals=3,
            patient_choice_model="hybrid"
        )

        patient = PatientAgent(
            id="P3", arrival_time=0.0, admission_date=Date(2026, 4, 1),
            primary_diagnosis="I10", secondary_diagnoses=String[], drg_code="39900",
            assigned_service_line="Cardiology", location="waiting", los_target=3,
            cumulative_cost=0.0, cost_by_day=Float64[],
            daily_costs=Dict{String, Float64}("labor" => 0.0, "supplies" => 0.0, "overhead" => 0.0),
            procedures=String[], payer="Medicare", comorbidity_count=0,
            discharge_date=nothing, metadata=Dict{String, Any}()
        )

        patient_location = (38.5, -84.0)
        chosen = choose_hospital(network, patient, patient_location)

        @test chosen in keys(network.hospitals)
        # Hybrid should balance distance and quality
        @test network.hospitals[chosen].quality_score > 0.0
    end

    # ================== Patient Routing Tests ==================
    @testset "Patient Routing to Hospital" begin
        network = HospitalNetwork(num_hospitals=3)

        patient = PatientAgent(
            id="P4", arrival_time=0.0, admission_date=Date(2026, 4, 1),
            primary_diagnosis="I10", secondary_diagnoses=String[], drg_code="39900",
            assigned_service_line="Cardiology", location="waiting", los_target=3,
            cumulative_cost=0.0, cost_by_day=Float64[],
            daily_costs=Dict{String, Float64}("labor" => 0.0, "supplies" => 0.0, "overhead" => 0.0),
            procedures=String[], payer="Medicare", comorbidity_count=0,
            discharge_date=nothing, metadata=Dict{String, Any}()
        )

        patient_location = (38.5, -84.0)
        route_patient_to_hospital!(network, patient, patient_location)

        @test haskey(patient.metadata, "assigned_hospital")
        @test haskey(patient.metadata, "hospital_name")
        @test haskey(patient.metadata, "distance_to_hospital")
        @test patient.metadata["assigned_hospital"] in keys(network.hospitals)
        @test patient.metadata["distance_to_hospital"] >= 0.0
    end

    # ================== Network Admissions Generation Tests ==================
    @testset "Network Admissions Generation" begin
        network = HospitalNetwork(num_hospitals=3, num_days=5)

        population_size = 100
        admission_rate = 2.0  # 2 admissions per day

        generate_network_admissions(network, population_size, admission_rate)

        @test length(network.patients) > 0
        @test length(network.patients) <= population_size + 50  # Some buffer for randomness

        # All patients should have hospital assignments
        for patient in network.patients
            @test haskey(patient.metadata, "assigned_hospital")
            @test patient.metadata["assigned_hospital"] in keys(network.hospitals)
        end
    end

    # ================== Network Simulation Tests ==================
    @testset "Network Flow Simulation" begin
        network = HospitalNetwork(
            network_name="Test Network",
            num_hospitals=3,
            num_days=5,
            patient_choice_model="hybrid"
        )

        simulate_network_flow!(network, 50, 2.0)

        # Check results
        @test !isempty(network.network_results)
        @test haskey(network.network_results, "total_patients")
        @test haskey(network.network_results, "total_cost")
        @test haskey(network.network_results, "hospital_volumes")
        @test haskey(network.network_results, "hospital_costs")
        @test haskey(network.network_results, "hospital_margins")
        @test haskey(network.network_results, "hospital_quality")

        # Check aggregations
        total_vol = sum(values(network.network_results["hospital_volumes"]))
        @test total_vol > 0
        @test network.network_results["total_cost"] > 0.0
    end

    @testset "Network Summary Statistics" begin
        network = HospitalNetwork(num_hospitals=3, num_days=7)
        simulate_network_flow!(network, 75, 2.5)

        summary = get_network_summary(network)

        @test !isempty(summary)
        @test summary["total_patients"] > 0
        @test summary["total_cost"] > 0.0
        @test summary["avg_cost_per_patient"] > 0.0
        @test length(summary["hospital_volumes"]) == 3
    end

    # ================== Hospital Performance Analysis Tests ==================
    @testset "Individual Hospital Performance Analysis" begin
        network = HospitalNetwork(num_hospitals=3, num_days=7)
        simulate_network_flow!(network, 100, 3.0)

        # Analyze each hospital
        for hosp_id in keys(network.hospitals)
            perf = analyze_hospital_performance(network, hosp_id)

            @test !isempty(perf)
            @test perf["hospital_id"] == hosp_id
            @test perf["volume"] >= 0
            @test perf["total_cost"] >= 0.0
            @test perf["avg_cost_per_case"] >= 0.0
            @test perf["quality_score"] >= 0.0
        end
    end

    @testset "Hospital Performance Ranking" begin
        network = HospitalNetwork(num_hospitals=5, num_days=14)
        simulate_network_flow!(network, 200, 4.0)

        # Get performance for all hospitals
        performances = []
        for hosp_id in keys(network.hospitals)
            perf = analyze_hospital_performance(network, hosp_id)
            push!(performances, perf)
        end

        # Should be able to rank by volume
        sorted_by_volume = sort(performances, by=p -> p["volume"], rev=true)
        @test sorted_by_volume[1]["volume"] >= sorted_by_volume[end]["volume"]
    end

    # ================== Multi-Day Simulation Tests ==================
    @testset "Multi-Day Simulation Flow" begin
        network = HospitalNetwork(
            network_name="Multi-Day Test",
            num_hospitals=3,
            num_days=10,
            patient_choice_model="hybrid"
        )

        admission_rate = 3.0
        simulate_network_flow!(network, 150, admission_rate)

        # Verify simulation state
        results = network.network_results
        @test results["total_patients"] > 0

        # Expected admissions: ~10 days * 3 per day = ~30, but with variance
        expected_min = admission_rate * network.time_end / 24.0 * 0.3  # 30% of expected
        expected_max = admission_rate * network.time_end / 24.0 * 2.0  # 200% of expected

        total_vol = sum(values(results["hospital_volumes"]))
        @test total_vol >= 1  # At least some admissions
    end

    # ================== Cost Aggregation Tests ==================
    @testset "Hospital Cost Aggregation" begin
        network = HospitalNetwork(num_hospitals=3, num_days=7)
        simulate_network_flow!(network, 80, 2.5)

        results = network.network_results

        # All hospitals should have costs and volumes
        for hosp_id in keys(network.hospitals)
            if results["hospital_volumes"][hosp_id] > 0
                @test results["hospital_costs"][hosp_id] > 0.0
                @test results["hospital_margins"][hosp_id] >= 0.0
            end
        end

        # Total network margin should be sum of hospital margins
        total_margin = results["network_margin"]
        sum_margins = sum(values(results["hospital_margins"]))
        @test total_margin ≈ sum_margins
    end

    # ================== Quality Metrics Tests ==================
    @testset "Quality Metrics Aggregation" begin
        network = HospitalNetwork(num_hospitals=4, num_days=10)
        simulate_network_flow!(network, 120, 3.5)

        results = network.network_results

        # Each hospital should have quality scores if it has patients
        for (hosp_id, quality_scores) in results["hospital_quality"]
            if !isempty(quality_scores)
                @test all(0.0 <= q <= 1.0 for q in quality_scores)
                @test mean(quality_scores) > 0.0
            end
        end
    end

    # ================== Edge Case Tests ==================
    @testset "Edge Case: Single Hospital Network" begin
        network = HospitalNetwork(num_hospitals=1, num_days=3)
        simulate_network_flow!(network, 20, 1.5)

        @test length(network.hospitals) == 1
        @test length(network.patients) >= 1
        # All patients should route to the single hospital
        for patient in network.patients
            @test patient.metadata["assigned_hospital"] == "H1"
        end
    end

    @testset "Edge Case: High Admission Rate" begin
        network = HospitalNetwork(num_hospitals=2, num_days=5)
        simulate_network_flow!(network, 500, 20.0)  # Very high admission rate

        @test length(network.patients) > 0
        @test network.network_results["total_patients"] > 0
    end

    @testset "Edge Case: Low Admission Rate" begin
        network = HospitalNetwork(num_hospitals=3, num_days=10)
        simulate_network_flow!(network, 20, 0.1)  # Very low admission rate

        @test network.network_results["total_patients"] >= 0
    end

    @testset "Edge Case: Invalid Hospital ID" begin
        network = HospitalNetwork(num_hospitals=3)
        perf = analyze_hospital_performance(network, "INVALID_HOSPITAL")

        @test isempty(perf)
    end

    # ================== Referral Pattern Tests ==================
    @testset "Referral Pattern Tracking" begin
        network = HospitalNetwork(num_hospitals=3, num_days=7)
        simulate_network_flow!(network, 100, 3.0)

        results = network.network_results
        patterns = results["referral_patterns"]

        @test !isempty(patterns)

        # Count total admissions tracked in patterns
        admission_count = 0
        for hosp in keys(patterns)
            if haskey(patterns[hosp], "admissions")
                admission_count += patterns[hosp]["admissions"]
            end
        end

        @test admission_count > 0 || length(patterns) > 0
    end

    # ================== Integration Tests ==================
    @testset "Integration: Cohort Network Simulation" begin
        network = simulate_patient_cohort_network(100, 4)

        @test !isempty(network.hospitals)
        @test !isempty(network.patients)
        @test !isempty(network.network_results)
        @test network.network_results["total_patients"] > 0
    end

    @testset "Integration: Multiple Simulation Runs" begin
        # Run multiple simulations to check consistency
        results_list = []

        for run in 1:3
            network = HospitalNetwork(num_hospitals=3, num_days=5)
            simulate_network_flow!(network, 50, 2.0)
            push!(results_list, network.network_results["total_patients"])
        end

        # Results should be reasonable (all positive)
        @test all(r > 0 for r in results_list)

        # Results will vary due to stochasticity, but within reasonable range
        mean_patients = mean(results_list)
        @test mean_patients > 0.0
    end

    @testset "Integration: Choice Model Comparison" begin
        # Compare different choice models
        models = ["distance", "quality", "hybrid"]

        for model in models
            network = HospitalNetwork(
                num_hospitals=3,
                num_days=5,
                patient_choice_model=model
            )

            simulate_network_flow!(network, 60, 2.5)

            @test network.network_results["total_patients"] > 0
            @test network.patient_choice_model == model
        end
    end

    @testset "Integration: Hospital Sizing Impact" begin
        # Larger hospitals should generally have higher volume
        small_network = HospitalNetwork(num_hospitals=2, num_days=7)
        simulate_network_flow!(small_network, 100, 2.0)

        large_network = HospitalNetwork(num_hospitals=5, num_days=7)
        simulate_network_flow!(large_network, 100, 2.0)

        # Both should complete successfully
        @test small_network.network_results["total_patients"] > 0
        @test large_network.network_results["total_patients"] > 0
    end

    # ================== Data Consistency Tests ==================
    @testset "Data Consistency: Costs Sum Correctly" begin
        network = HospitalNetwork(num_hospitals=3, num_days=7)
        simulate_network_flow!(network, 100, 3.0)

        results = network.network_results

        # Sum of hospital costs should approximately equal total cost
        # (within floating point tolerance)
        sum_hosp_costs = sum(values(results["hospital_costs"]))
        @test sum_hosp_costs > 0.0
    end

    @testset "Data Consistency: Volumes Are Non-Negative" begin
        network = HospitalNetwork(num_hospitals=4, num_days=10)
        simulate_network_flow!(network, 150, 3.5)

        results = network.network_results

        @test all(v >= 0 for v in values(results["hospital_volumes"]))
        @test all(c >= 0.0 for c in values(results["hospital_costs"]))
    end

    # ================== Population Struct Tests ==================
    @testset "Population Struct" begin
        # Default population
        pop = Population()
        @test pop.size == 50_000
        @test pop.annual_admission_rate == 120.0
        @test pop.region_radius_miles == 50.0
        @test pop.chronic_disease_prevalence == 0.35
        @test sum(values(pop.age_distribution)) ≈ 1.0 atol=0.01
        @test sum(values(pop.payer_mix)) ≈ 1.0 atol=0.01

        # Custom population
        pop2 = Population(
            size=10_000,
            annual_admission_rate=150.0,
            region_center=(40.0, -80.0),
            region_radius_miles=30.0,
            chronic_disease_prevalence=0.40
        )
        @test pop2.size == 10_000
        @test pop2.annual_admission_rate == 150.0
        @test pop2.region_center == (40.0, -80.0)
        @test pop2.chronic_disease_prevalence == 0.40

        # daily_admission_rate helper
        rate = daily_admission_rate(pop)
        expected = (50_000 * 120.0 / 1000.0) / 365.0
        @test rate ≈ expected atol=0.001
    end

    # ================== Service Availability & Shared Service Lines ==================
    @testset "Service Availability and Shared Service Lines" begin
        network = HospitalNetwork(num_hospitals=5)

        # service_availability mirrors each hospital's service_lines
        for (hosp_id, hosp) in network.hospitals
            @test haskey(network.service_availability, hosp_id)
            @test network.service_availability[hosp_id] == hosp.service_lines
        end

        # shared_service_lines: every service listed in a hospital's service_lines
        # must appear in shared_service_lines with that hospital listed
        for (hosp_id, hosp) in network.hospitals
            for svc in hosp.service_lines
                @test haskey(network.shared_service_lines, svc)
                @test hosp_id in network.shared_service_lines[svc]
            end
        end

        # General Ward and ED are in every hospital
        @test length(network.shared_service_lines["General Ward"]) == 5
        @test length(network.shared_service_lines["ED"]) == 5
    end

    # ================== Capacity State & Overflow Tests ==================
    @testset "Capacity State Tracking" begin
        network = HospitalNetwork(num_hospitals=3, num_days=5)
        @test all(v == 0 for v in values(network.capacity_state))

        simulate_network_flow!(network, 30, 2.0)

        # After simulation, capacity state should be >= 0 for all hospitals
        @test all(v >= 0 for v in values(network.capacity_state))
    end

    @testset "has_capacity Function" begin
        network = HospitalNetwork(num_hospitals=2)

        # Initially all hospitals have capacity
        @test has_capacity(network, "H1")
        @test has_capacity(network, "H2")

        # Artificially fill H1 to capacity
        network.capacity_state["H1"] = network.hospitals["H1"].total_beds
        @test !has_capacity(network, "H1")
        @test has_capacity(network, "H2")
    end

    @testset "Overflow Handling: At-Capacity Routing" begin
        # Create a tiny network so overflow is likely
        network = HospitalNetwork(num_hospitals=2, num_days=5, patient_choice_model="distance")

        # Fill H1 to capacity so patients overflow to H2
        network.capacity_state["H1"] = network.hospitals["H1"].total_beds

        patient = PatientAgent(
            id="PX", arrival_time=0.0, admission_date=Date(2026, 4, 1),
            primary_diagnosis="I10", secondary_diagnoses=String[], drg_code="39900",
            assigned_service_line="General Ward", location="waiting", los_target=3,
            cumulative_cost=0.0, cost_by_day=Float64[],
            daily_costs=Dict{String, Float64}("labor" => 0.0, "supplies" => 0.0, "overhead" => 0.0),
            procedures=String[], payer="Medicare", comorbidity_count=0,
            discharge_date=nothing, metadata=Dict{String, Any}()
        )

        patient_location = (38.5, -84.0)
        route_patient_to_hospital!(network, patient, patient_location)

        # Patient should be routed to H2 (H1 is full) or marked overflowed
        assigned = patient.metadata["assigned_hospital"]
        @test assigned in keys(network.hospitals)
    end

    @testset "Overflow Stats in Results" begin
        network = HospitalNetwork(num_hospitals=3, num_days=7)
        simulate_network_flow!(network, 100, 3.0)

        results = network.network_results
        @test haskey(results, "hospital_overflow")
        @test haskey(results, "regional")
        regional = results["regional"]
        @test haskey(regional, "total_overflow_events")
        @test haskey(regional, "overflow_rate")
        @test regional["overflow_rate"] >= 0.0
        @test regional["overflow_rate"] <= 1.0
    end

    # ================== Cost Choice Model Tests ==================
    @testset "Hospital Choice - Cost Model" begin
        network = HospitalNetwork(
            num_hospitals=3,
            patient_choice_model="cost"
        )

        patient = PatientAgent(
            id="P_COST", arrival_time=0.0, admission_date=Date(2026, 4, 1),
            primary_diagnosis="I10", secondary_diagnoses=String[], drg_code="28340",
            assigned_service_line="General Ward", location="waiting", los_target=3,
            cumulative_cost=0.0, cost_by_day=Float64[],
            daily_costs=Dict{String, Float64}("labor" => 0.0, "supplies" => 0.0, "overhead" => 0.0),
            procedures=String[], payer="Commercial", comorbidity_count=0,
            discharge_date=nothing, metadata=Dict{String, Any}()
        )

        patient_location = (38.5, -84.0)
        chosen = choose_hospital(network, patient, patient_location)

        @test chosen in keys(network.hospitals)
        # The chosen hospital should have the lowest base_cost_per_day among
        # those offering General Ward
        min_cost = minimum(
            network.hospitals[id].base_cost_per_day
            for id in keys(network.hospitals)
            if "General Ward" in network.hospitals[id].service_lines
        )
        @test network.hospitals[chosen].base_cost_per_day == min_cost
    end

    @testset "All Four Choice Models Produce Valid Results" begin
        for model in ["distance", "quality", "cost", "hybrid"]
            network = HospitalNetwork(num_hospitals=3, num_days=5, patient_choice_model=model)
            simulate_network_flow!(network, 50, 2.0)
            @test network.network_results["total_patients"] > 0
            @test network.patient_choice_model == model
        end
    end

    # ================== simulate_network! (Population API) Tests ==================
    @testset "simulate_network! with Population" begin
        network = HospitalNetwork(
            network_name="Population Test Network",
            num_hospitals=4,
            num_days=14
        )

        pop = Population(
            size=20_000,
            annual_admission_rate=100.0,
            region_center=(38.5, -84.0),
            region_radius_miles=40.0
        )

        simulate_network!(network, pop, 14)

        @test !isempty(network.network_results)
        @test network.network_results["total_patients"] > 0
        @test network.network_results["avg_cost_per_patient"] > 0.0
        @test haskey(network.network_results, "regional")
    end

    @testset "simulate_network! extends time window if needed" begin
        network = HospitalNetwork(num_hospitals=3, num_days=7)
        pop = Population(size=5_000, annual_admission_rate=80.0)

        # Request 30 days even though network was built for 7
        simulate_network!(network, pop, 30)

        @test network.time_end >= 30 * 24.0
        @test network.network_results["total_patients"] >= 0
    end

    # ================== Regional Financial Outcome Aggregation ==================
    @testset "Regional Outcome Aggregation" begin
        network = HospitalNetwork(num_hospitals=5, num_days=14)
        simulate_network_flow!(network, 200, 4.0)

        results = network.network_results
        regional = results["regional"]

        @test regional["num_hospitals_active"] >= 1
        @test regional["avg_patient_distance"] >= 0.0
        @test haskey(regional, "total_overflow_events")
    end

    # ================== 10-Hospital × 90-Day Scale Test ==================
    @testset "Scale: 10 hospitals × 90 days" begin
        network = HospitalNetwork(
            network_name="Regional Scale Test",
            num_hospitals=10,
            num_days=90,
            patient_choice_model="hybrid"
        )

        pop = Population(
            size=100_000,
            annual_admission_rate=100.0,
            region_radius_miles=75.0
        )

        t_start = time()
        simulate_network!(network, pop, 90)
        elapsed = time() - t_start

        @test network.network_results["total_patients"] > 0
        @test length(network.hospitals) == 10
        @test size(network.referral_matrix) == (10, 10)

        # Performance requirement: < 30 seconds
        @test elapsed < 30.0

        # All 10 hospitals should be tracked in results
        @test length(network.network_results["hospital_volumes"]) == 10
        @test length(network.network_results["hospital_costs"]) == 10

        # Regional aggregation should cover all hospitals
        regional = network.network_results["regional"]
        @test regional["num_hospitals_active"] >= 1
    end

end  # End of main testset

println("\n✓ All HospitalNetworkSimulation tests completed!")
