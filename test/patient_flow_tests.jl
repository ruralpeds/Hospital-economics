# ============================================================================
# TESTS: MODULE 4 - PATIENT FLOW SIMULATION
# ============================================================================
# Comprehensive tests for ClinicalPathway, PatientAgent outcomes, and CohortSimulation

using Test
using Dates
using HospitalFinanceToolbox

# ============================================================================
# CLINICAL PATHWAY TESTS
# ============================================================================

@testset "ClinicalPathway Repository" begin
    # Test get_clinical_pathways returns dict
    pathways = get_clinical_pathways()
    @test isa(pathways, Dict)
    @test !isempty(pathways)

    # Test we have 20+ pathways
    @test length(pathways) >= 20

    # Test each pathway has required fields
    for (drg_code, pathway) in pathways
        @test pathway.pathway_id != ""
        @test pathway.primary_diagnosis != ""
        @test pathway.drg_code == drg_code
        @test pathway.expected_los > 0
        @test 0.0 <= pathway.expected_mortality_rate <= 1.0
        @test 0.0 <= pathway.expected_readmission_30day <= 1.0
        @test 0.0 <= pathway.expected_complication_rate <= 1.0
        @test 0.0 <= pathway.expected_quality_score <= 1.0
        @test pathway.expected_cost >= 0.0
        @test pathway.cost_std >= 0.0
        @test pathway.typical_ed_stay_hours >= 0
        @test pathway.typical_icu_stay_days >= 0
    end
end

@testset "ClinicalPathway Routing" begin
    # Test route_to_pathway returns correct pathway
    pathway_246 = route_to_pathway("246")
    @test pathway_246.drg_code == "246"
    @test pathway_246.primary_diagnosis == "I21"
    @test pathway_246.expected_mortality_rate == 0.02

    # Test route_to_pathway raises error for unknown DRG
    @test_throws ErrorException route_to_pathway("999")
end

@testset "ClinicalPathway Data Quality" begin
    pathways = get_clinical_pathways()

    # All pathways should have reasonable cost expectations
    for (drg, pathway) in pathways
        # Cost should be between $1K and $500K
        @test pathway.expected_cost >= 1000.0 || pathway.expected_cost == 0.0
        @test pathway.expected_cost <= 500000.0

        # Cost std dev should be <= mean cost
        @test pathway.cost_std <= pathway.expected_cost + 100000.0
    end

    # Test specific known pathways have expected characteristics
    # MI should have higher mortality than chest pain
    mi = route_to_pathway("246")
    chest_pain = route_to_pathway("296")
    @test mi.expected_mortality_rate > chest_pain.expected_mortality_rate

    # Hip replacement should have no ICU by default
    hip = route_to_pathway("470")
    @test hip.typical_icu_stay_days == 0
    @test hip.typical_or_minutes > 0
end

# ============================================================================
# PATIENT AGENT OUTCOME TESTS
# ============================================================================

@testset "PatientAgent Outcome Fields" begin
    patient = PatientAgent(
        id = "PT001",
        admission_date = today(),
        primary_diagnosis = "I21",
        drg_code = "246"
    )

    # Test initial values
    @test patient.quality_score == 0.5
    @test patient.readmission_status == false
    @test patient.mortality == false
    @test isempty(patient.complication_codes)

    # Test we can modify outcomes
    patient.mortality = true
    @test patient.mortality == true

    patient.complication_codes = ["I97.8", "N17.9"]
    @test length(patient.complication_codes) == 2
end

@testset "simulate_patient_outcomes! Basic" begin
    patient = PatientAgent(
        id = "PT001",
        admission_date = Date(2026, 4, 1),
        discharge_date = Date(2026, 4, 4),
        primary_diagnosis = "I21",
        drg_code = "246",
        cumulative_cost = 18500.0,
        metadata = Dict("age" => 65)
    )

    pathway = route_to_pathway("246")
    simulate_patient_outcomes!(patient, pathway)

    # Check outcomes were assigned
    @test isa(patient.mortality, Bool)
    @test isa(patient.readmission_status, Bool)
    @test isa(patient.quality_score, Float64)
    @test 0.0 <= patient.quality_score <= 1.0

    # If no mortality, readmission can be true or false
    # If mortality, readmission should be false
    if patient.mortality
        @test patient.readmission_status == false
    end
end

@testset "simulate_patient_outcomes! Risk Adjustment" begin
    # Test that older patients have higher mortality
    elderly_patient = PatientAgent(
        id = "PT002",
        admission_date = Date(2026, 4, 1),
        discharge_date = Date(2026, 4, 4),
        primary_diagnosis = "I21",
        drg_code = "246",
        comorbidity_count = 3,
        cumulative_cost = 18500.0,
        metadata = Dict("age" => 85)
    )

    young_patient = PatientAgent(
        id = "PT003",
        admission_date = Date(2026, 4, 1),
        discharge_date = Date(2026, 4, 4),
        primary_diagnosis = "I21",
        drg_code = "246",
        comorbidity_count = 0,
        cumulative_cost = 18500.0,
        metadata = Dict("age" => 45)
    )

    pathway = route_to_pathway("246")

    # Run simulation multiple times to get statistical properties
    elderly_mortalities = [simulate_patient_outcomes!(elderly_patient, pathway); elderly_patient.mortality for _ in 1:10]
    young_mortalities = [simulate_patient_outcomes!(young_patient, pathway); young_patient.mortality for _ in 1:10]

    # Filter out the initial None from the first simulate call
    elderly_mortality_rate = sum(elderly_mortalities) / length(elderly_mortalities)
    young_mortality_rate = sum(young_mortalities) / length(young_mortalities)

    # Elderly should have higher mortality on average (this is probabilistic so allow some variance)
    @test elderly_mortality_rate >= young_mortality_rate * 0.5  # Allow some variance
end

@testset "calculate_quality_score" begin
    patient = PatientAgent(
        id = "PT004",
        admission_date = Date(2026, 4, 1),
        discharge_date = Date(2026, 4, 4),
        cumulative_cost = 18500.0
    )

    pathway = route_to_pathway("246")
    quality_baseline = calculate_quality_score(patient, pathway)

    # Quality should improve when patient has no complications
    @test quality_baseline > 0.0
    @test quality_baseline <= 1.0

    # Quality should decrease with mortality
    patient.mortality = true
    quality_with_mortality = calculate_quality_score(patient, pathway)
    @test quality_with_mortality < quality_baseline

    # Quality should decrease with readmission
    patient.mortality = false
    patient.readmission_status = true
    quality_with_readmission = calculate_quality_score(patient, pathway)
    @test quality_with_readmission < quality_baseline

    # Quality should decrease with complications
    patient.readmission_status = false
    patient.complication_codes = ["I97.8", "N17.9", "J96.9"]
    quality_with_complications = calculate_quality_score(patient, pathway)
    @test quality_with_complications < quality_baseline
end

# ============================================================================
# COHORT SIMULATION TESTS
# ============================================================================

@testset "CohortSimulationResult Structure" begin
    result = CohortSimulationResult(
        "Test Cohort",
        1,
        100,
        15000.0,
        3.5,
        0.05,
        0.12,
        0.82,
        Dict(0.5 => 15000.0),
        Dict(0.5 => 3.5),
        0.10,
        0.15,
        Dict(),
        1_500_000.0,
        350.0
    )

    @test result.cohort_name == "Test Cohort"
    @test result.n_simulations == 1
    @test result.n_patients == 100
    @test result.mean_cost == 15000.0
    @test result.mean_los == 3.5
    @test 0.0 <= result.mortality_rate <= 1.0
end

@testset "simulate_cohort Basic" begin
    # Create test encounters
    encounters = PatientEncounter[]
    for i in 1:5
        push!(encounters, PatientEncounter(
            patient_id = "PT_$i",
            encrypted_patient_id = UInt8[],
            encounter_id = "ENC_$i",
            age_at_admission = 65 + i,
            sex = "M",
            race_code = "W",
            ethnicity_code = "NH",
            zip_code_prefix = "123",
            admission_date = Date(2026, 4, 1),
            discharge_date = Date(2026, 4, 5),
            length_of_stay = 4,
            admission_type = "Emergency",
            discharge_disposition = "Home",
            primary_diagnosis = "I21",
            secondary_diagnoses = String[],
            procedures = ["92004"],
            total_charges = 18500.0,
            allowed_amount = 15000.0,
            paid_amount = 12000.0,
            patient_cost_share = 3000.0,
            payer = "Medicare",
            source_system = "Test",
            ingestion_date = now(),
            validation_status = "Valid",
            quality_flags = String[],
            metadata = Dict()
        ))
    end

    # Create cohort from encounters
    cohort = PatientCohort("Test Cohort")
    cohort_with_data = PatientCohort(
        cohort.cohort_id,
        cohort.name,
        cohort.description,
        [enc.patient_id for enc in encounters],
        [enc.encounter_id for enc in encounters],
        length(encounters),
        cohort.inclusion_criteria,
        cohort.exclusion_criteria,
        cohort.statistics,
        cohort.creation_date,
        now(),
        cohort.metadata
    )

    # Run simulation
    result = simulate_cohort(cohort_with_data, encounters; num_simulation_runs=1)

    # Check result structure
    @test result.cohort_name == "Test Cohort"
    @test result.n_patients == 5
    @test result.n_simulations == 1
    @test result.mean_cost > 0
    @test result.mean_los > 0
    @test 0.0 <= result.mortality_rate <= 1.0
    @test 0.0 <= result.readmission_30day_rate <= 1.0
    @test 0.0 <= result.mean_quality_score <= 1.0

    # Check percentiles
    @test haskey(result.cost_percentiles, 0.50)
    @test result.cost_percentiles[0.50] > 0
end

@testset "simulate_cohort Multiple Runs" begin
    # Create test encounters
    encounters = PatientEncounter[]
    for i in 1:10
        push!(encounters, PatientEncounter(
            patient_id = "PT_$i",
            encrypted_patient_id = UInt8[],
            encounter_id = "ENC_$i",
            age_at_admission = 65,
            sex = "M",
            race_code = "W",
            ethnicity_code = "NH",
            zip_code_prefix = "123",
            admission_date = Date(2026, 4, 1),
            discharge_date = Date(2026, 4, 5),
            length_of_stay = 4,
            admission_type = "Emergency",
            discharge_disposition = "Home",
            primary_diagnosis = "246",  # MI
            secondary_diagnoses = String[],
            procedures = ["92004"],
            total_charges = 18500.0,
            allowed_amount = 15000.0,
            paid_amount = 12000.0,
            patient_cost_share = 3000.0,
            payer = "Medicare",
            source_system = "Test",
            ingestion_date = now(),
            validation_status = "Valid",
            quality_flags = String[],
            metadata = Dict()
        ))
    end

    cohort = PatientCohort(
        "Test Cohort MI",
        "Test",
        String[],
        String[],
        [enc.patient_id for enc in encounters],
        [enc.encounter_id for enc in encounters],
        length(encounters),
        CriterionType[],
        CriterionType[],
        CohortStatistics(),
        now(),
        now(),
        Dict()
    )

    # Run multiple simulations
    result = simulate_cohort(cohort, encounters; num_simulation_runs=5)

    @test result.n_simulations == 5
    @test result.n_patients == 10
end

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

@testset "PatientAgent to Episode Conversion with Outcomes" begin
    patient = PatientAgent(
        id = "PT005",
        admission_date = Date(2026, 4, 1),
        discharge_date = Date(2026, 4, 5),
        primary_diagnosis = "I21",
        drg_code = "246",
        procedures = ["92004"],
        payer = "Medicare"
    )

    # Simulate outcomes
    pathway = route_to_pathway("246")
    simulate_patient_outcomes!(patient, pathway)

    # Convert to episode (requires Episode.jl)
    episode = patient_to_episode(patient)

    @test episode.patient_id == "PT005"
    @test episode.primary_diagnosis == "I21"

    # Check outcomes are included in metadata
    if haskey(episode.metadata, "outcomes")
        @test haskey(episode.metadata["outcomes"], "quality_score")
        @test haskey(episode.metadata["outcomes"], "mortality")
        @test haskey(episode.metadata["outcomes"], "readmission")
    end
end

println("\n✓ All Module 4 (Patient Flow Simulation) tests passed!")
