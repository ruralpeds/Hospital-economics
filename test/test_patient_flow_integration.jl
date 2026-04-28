"""
    test_patient_flow_integration.jl

Unit and integration tests for Phase 1.2 Patient Flow Integration with Cost Accumulation
"""

using Test
using Dates
using Random

# Include required modules
include("../src/episode/Episode.jl")
include("../src/episode/EpisodeCostModels.jl")
include("../src/patient_flow/PatientAgent.jl")
include("../src/patient_flow/FlowSimulation.jl")

# Set random seed for reproducibility
Random.seed!(42)

@testset "Phase 1.2: Patient Flow Integration" begin

    # ========================================================================
    # PatientAgent Tests
    # ========================================================================

    @testset "PatientAgent construction" begin
        patient = PatientAgent(
            id="PT001",
            admission_date=Date(2026, 4, 1),
            primary_diagnosis="I21",
            drg_code="247",
            assigned_service_line="Cardiology",
            los_target=3,
            payer="Medicare"
        )

        @test patient.id == "PT001"
        @test patient.location == "waiting"
        @test patient.cumulative_cost == 0.0
        @test patient.payer == "Medicare"
        @test patient.los_target == 3
    end

    @testset "Initialize patient cost tracking" begin
        patient = PatientAgent(
            id="PT002",
            admission_date=Date(2026, 4, 1),
            primary_diagnosis="I21",
            los_target=5
        )

        initialize_patient_cost_tracking(patient, 5)

        @test length(patient.cost_by_day) == 5
        @test patient.daily_costs["labor"] == 0.0
        @test haskey(patient.resource_utilization, "bed_days")
    end

    @testset "Accumulate daily costs" begin
        patient = PatientAgent(
            id="PT003",
            admission_date=Date(2026, 4, 1),
            primary_diagnosis="I21"
        )

        initialize_patient_cost_tracking(patient, 3)

        accumulate_daily_cost!(patient, 1, 800.0, 300.0, 220.0)
        @test patient.cumulative_cost == 1320.0
        @test patient.cost_by_day[1] == 1320.0
        @test patient.daily_costs["labor"] == 800.0

        accumulate_daily_cost!(patient, 2, 800.0, 300.0, 220.0)
        @test patient.cumulative_cost == 2640.0
    end

    @testset "Add procedure costs" begin
        patient = PatientAgent(
            id="PT004",
            admission_date=Date(2026, 4, 1),
            primary_diagnosis="I21"
        )

        initialize_patient_cost_tracking(patient, 3)

        add_procedure_cost!(patient, "99213", 2500.0)
        @test length(patient.procedures) == 1
        @test patient.procedures[1] == "99213"
        @test patient.cumulative_cost == 2500.0
        @test haskey(patient.daily_costs, "procedures")
    end

    @testset "Route patient to service" begin
        patient = PatientAgent(
            id="PT005",
            admission_date=Date(2026, 4, 1),
            primary_diagnosis="I21",
            assigned_service_line="ED"
        )

        route_patient_to_service!(patient, "Cardiology", "ward")
        @test patient.assigned_service_line == "Cardiology"
        @test patient.location == "ward"
    end

    @testset "Discharge patient" begin
        patient = PatientAgent(
            id="PT006",
            admission_date=Date(2026, 4, 1),
            primary_diagnosis="I21",
            location="ward"
        )

        discharge_date = Date(2026, 4, 4)
        discharge_patient!(patient, discharge_date)

        @test patient.location == "discharged"
        @test patient.discharge_date == discharge_date
    end

    @testset "Get patient summary" begin
        patient = PatientAgent(
            id="PT007",
            admission_date=Date(2026, 4, 1),
            primary_diagnosis="I21",
            drg_code="247",
            assigned_service_line="Cardiology",
            payer="Medicare"
        )

        initialize_patient_cost_tracking(patient, 3)
        accumulate_daily_cost!(patient, 1, 800.0, 300.0, 220.0)
        add_procedure_cost!(patient, "99213", 2500.0)
        discharge_patient!(patient, Date(2026, 4, 4))

        summary = get_patient_summary(patient)

        @test summary["patient_id"] == "PT007"
        @test summary["service_line"] == "Cardiology"
        @test summary["los"] == 3
        @test summary["total_cost"] == 1320.0 + 2500.0
        @test summary["payer"] == "Medicare"
    end

    @testset "Patient to episode conversion" begin
        patient = PatientAgent(
            id="PT008",
            admission_date=Date(2026, 4, 1),
            primary_diagnosis="I21",
            secondary_diagnoses=["CC_001"],
            drg_code="247",
            assigned_service_line="Cardiology",
            payer="Medicare"
        )

        initialize_patient_cost_tracking(patient, 3)
        accumulate_daily_cost!(patient, 1, 800.0, 300.0, 220.0)
        discharge_patient!(patient, Date(2026, 4, 4))

        episode = patient_to_episode(patient)

        @test episode.episode_id == "EP_PT008"
        @test episode.patient_id == "PT008"
        @test episode.drg_code == "247"
        @test episode.payer == Medicare
        @test length(episode.secondary_diagnoses) == 1
    end

    # ========================================================================
    # HospitalSimulation Tests
    # ========================================================================

    @testset "HospitalSimulation initialization" begin
        cost_model = create_standard_drg_model()
        sim = HospitalSimulation(
            hospital_name="Test Hospital",
            num_days=30,
            cost_model=cost_model
        )

        @test sim.hospital_name == "Test Hospital"
        @test sim.time_end == 30 * 24  # 30 days in hours
        @test isempty(sim.patients)
        @test haskey(sim.service_lines, "Emergency")
        @test haskey(sim.service_lines, "ICU")
        @test haskey(sim.service_lines, "Cardiology")
    end

    @testset "Generate admission" begin
        sim = HospitalSimulation(num_days=30)
        patient = generate_admission(sim, Date(2026, 4, 1), 0.0)

        @test !isempty(patient.id)
        @test patient.admission_date == Date(2026, 4, 1)
        @test !isempty(patient.drg_code)
        @test patient.payer in ["Medicare", "Medicaid", "Commercial", "Uninsured"]
        @test patient.los_target >= 1 && patient.los_target <= 8
    end

    @testset "Route patient" begin
        sim = HospitalSimulation(num_days=30)
        patient = PatientAgent(
            id="PT009",
            admission_date=Date(2026, 4, 1),
            primary_diagnosis="I21",
            drg_code="247",
            assigned_service_line="Cardiology"
        )

        initialize_patient_cost_tracking(patient, 3)
        route_patient!(patient, sim)

        @test patient.location in ["ward", "general ward", "OR", "ICU"]
        @test !isempty(patient.procedures) || patient.location != "OR"
    end

    @testset "Accumulate daily costs" begin
        sim = HospitalSimulation(num_days=30)
        patient = PatientAgent(
            id="PT010",
            admission_date=Date(2026, 4, 1),
            primary_diagnosis="I21",
            location="ward"
        )

        initialize_patient_cost_tracking(patient, 3)
        date = Date(2026, 4, 1)

        accumulate_daily_costs!(sim, patient, 1, date)

        @test patient.cumulative_cost > 0
        @test haskey(sim.daily_costs, date)
        @test sim.daily_costs[date] > 0
    end

    @testset "Discharge patient with costs" begin
        sim = HospitalSimulation(num_days=30)
        patient = PatientAgent(
            id="PT011",
            admission_date=Date(2026, 4, 1),
            primary_diagnosis="I21"
        )

        discharge_date = Date(2026, 4, 4)
        discharge_patient_with_costs!(sim, patient, discharge_date)

        @test patient.location == "discharged"
        @test haskey(sim.daily_discharges, discharge_date)
        @test sim.daily_discharges[discharge_date] == 1
    end

    @testset "Simulate patient day" begin
        sim = HospitalSimulation(num_days=30)
        patient = PatientAgent(
            id="PT012",
            admission_date=Date(2026, 4, 1),
            primary_diagnosis="I21",
            location="ward",
            los_target=3
        )

        initialize_patient_cost_tracking(patient, 3)
        date = Date(2026, 4, 1)

        initial_cost = patient.cumulative_cost
        simulate_patient_day!(sim, patient, 1, date)

        @test patient.cumulative_cost >= initial_cost
    end

    # ========================================================================
    # Multi-Day Simulation Tests
    # ========================================================================

    @testset "Simulate hospital flow - 30 days" begin
        sim = HospitalSimulation(
            hospital_name="Test Hospital",
            num_days=30,
            cost_model=create_standard_drg_model()
        )

        simulate_hospital_flow!(sim, 3.5)

        # Basic validation
        @test !isempty(sim.patients)
        @test !isempty(sim.daily_admissions)
        @test !isempty(sim.daily_discharges)
        @test !isempty(sim.daily_costs)

        # Should have discharged patients
        discharged = count(p -> p.location == "discharged", sim.patients)
        @test discharged > 0

        # Total cost should be positive
        @test sim.cost_results["total_cost"] > 0
    end

    @testset "Cost accumulation consistency" begin
        sim = HospitalSimulation(num_days=30)
        simulate_hospital_flow!(sim, 3.5)

        # Sum of discharged patient costs should match reported total
        individual_sum = sum(p.cumulative_cost for p in sim.patients if p.location == "discharged")
        reported_total = sim.cost_results["total_cost"]

        @test abs(individual_sum - reported_total) < 1.0  # Allow floating point rounding
    end

    @testset "Service line volume tracking" begin
        sim = HospitalSimulation(num_days=30)
        simulate_hospital_flow!(sim, 3.5)

        service_volumes = sim.cost_results["service_line_volumes"]
        total_volume = sum(values(service_volumes))

        @test total_volume == sim.cost_results["total_patients"]
        @test total_volume > 0

        # At least some service lines should have volume (not necessarily all at low admission rate)
        @test length(service_volumes) > 0
        @test all(v > 0 for v in values(service_volumes))
    end

    @testset "Service line cost margins" begin
        sim = HospitalSimulation(num_days=30)
        simulate_hospital_flow!(sim, 3.5)

        margins = sim.cost_results["service_line_margins"]

        # High-revenue service lines should have positive margins
        # Emergency (revenue_multiplier = 0.95) may have a negative margin
        profitable = [sl for (sl, m) in margins if sl != "Emergency"]
        @test all(sim.cost_results["service_line_margins"][sl] > 0 for sl in profitable)
    end

    @testset "Daily census tracking" begin
        sim = HospitalSimulation(num_days=30)
        simulate_hospital_flow!(sim, 3.5)

        # Should have census for each day
        @test length(sim.daily_census) == 30
        @test all(v >= 0 for v in values(sim.daily_census))  # Some days may have 0 census
        @test count(v > 0 for v in values(sim.daily_census)) > 3  # At least a few days should have patients

        # Census should be reasonable
        @test maximum(values(sim.daily_census)) <= 300  # < 300 patients at any time
    end

    @testset "Average LOS computation" begin
        sim = HospitalSimulation(num_days=30)
        simulate_hospital_flow!(sim, 3.5)

        avg_los = sim.cost_results["average_los"]
        @test avg_los > 0
        @test avg_los <= 30  # Can't be longer than simulation
    end

    @testset "Simulate patient cohort" begin
        sim = simulate_patient_cohort(50; cost_model=create_standard_drg_model())

        @test sim.cost_results["total_patients"] > 0
        @test sim.cost_results["total_cost"] > 0
        @test sim.cost_results["mean_cost_per_patient"] > 0

        # Mean cost should be reasonable (allow per-diem costs to be lower than DRG costs)
        mean_cost = sim.cost_results["mean_cost_per_patient"]
        @test 1000 < mean_cost < 100000
    end

    # ========================================================================
    # Integration: Patient → Episode → Cost Model
    # ========================================================================

    @testset "Integration: patient to episode to cost" begin
        # Create patient
        patient = PatientAgent(
            id="PT013",
            admission_date=Date(2026, 4, 1),
            primary_diagnosis="I21",
            secondary_diagnoses=["CC_001"],
            drg_code="247",
            assigned_service_line="Cardiology",
            payer="Medicare"
        )

        initialize_patient_cost_tracking(patient, 4)
        accumulate_daily_cost!(patient, 1, 800.0, 300.0, 220.0)
        accumulate_daily_cost!(patient, 2, 800.0, 300.0, 220.0)
        accumulate_daily_cost!(patient, 3, 800.0, 300.0, 220.0)
        accumulate_daily_cost!(patient, 4, 800.0, 300.0, 220.0)
        discharge_patient!(patient, Date(2026, 4, 5))

        # Convert to episode
        episode = patient_to_episode(patient)

        # Calculate cost using cost model
        cost_model = create_standard_drg_model()
        episode_cost = calculate_episode_cost(episode, cost_model)

        @test episode_cost > 0
        @test episode_cost >= 5000  # Reasonable minimum

        # Simulated cost from patient should be in same ballpark
        simulated_cost = patient.cumulative_cost
        ratio = episode_cost / simulated_cost

        @test 0.2 < ratio < 10.0  # Allow wider variance due to different costing methods
    end

    @testset "Multi-patient simulation with cost model validation" begin
        sim = simulate_patient_cohort(30; cost_model=create_standard_rvu_model())

        # Validate that all patients have reasonable costs
        for patient in sim.patients
            if patient.location == "discharged"
                @test patient.cumulative_cost > 0
                @test patient.cumulative_cost < 200000  # Sanity check
            end
        end

        # Validate aggregated stats
        @test sim.cost_results["total_patients"] > 0
        @test sim.cost_results["mean_cost_per_patient"] > 5000
        @test sim.cost_results["std_cost_per_patient"] > 0
    end

    # ========================================================================
    # Edge Cases and Validation
    # ========================================================================

    @testset "Patient with no procedures" begin
        patient = PatientAgent(
            id="PT014",
            admission_date=Date(2026, 4, 1),
            primary_diagnosis="I21",
            drg_code="247"
        )

        initialize_patient_cost_tracking(patient, 3)
        accumulate_daily_cost!(patient, 1, 800.0, 300.0, 220.0)

        summary = get_patient_summary(patient)
        @test length(summary["procedures"]) == 0
    end

    @testset "Patient with multiple procedures" begin
        patient = PatientAgent(
            id="PT015",
            admission_date=Date(2026, 4, 1),
            primary_diagnosis="I21",
            drg_code="247"
        )

        initialize_patient_cost_tracking(patient, 3)
        add_procedure_cost!(patient, "99213", 1500.0)
        add_procedure_cost!(patient, "99214", 2000.0)
        add_procedure_cost!(patient, "99215", 2500.0)

        @test length(patient.procedures) == 3
        @test patient.cumulative_cost == 6000.0
    end

    @testset "Patient with zero LOS" begin
        patient = PatientAgent(
            id="PT016",
            admission_date=Date(2026, 4, 1),
            primary_diagnosis="I21",
            los_target=0
        )

        discharge_patient!(patient, Date(2026, 4, 1))
        summary = get_patient_summary(patient)

        @test summary["los"] == 0
    end

    @testset "Long LOS patient" begin
        patient = PatientAgent(
            id="PT017",
            admission_date=Date(2026, 4, 1),
            primary_diagnosis="I21",
            los_target=15
        )

        initialize_patient_cost_tracking(patient, 15)

        for day = 1:15
            accumulate_daily_cost!(patient, day, 1000.0, 400.0, 280.0)
        end

        discharge_patient!(patient, Date(2026, 4, 16))
        summary = get_patient_summary(patient)

        @test summary["los"] == 15
        @test summary["total_cost"] == 15 * 1680.0
    end

    @testset "Different payer types in simulation" begin
        sim = HospitalSimulation(num_days=30)
        simulate_hospital_flow!(sim, 3.5)

        payers_seen = Set(p.payer for p in sim.patients)
        @test length(payers_seen) > 1  # Should see multiple payer types
    end

end

println("\n✅ Phase 1.2: All Patient Flow Integration tests passed!")
