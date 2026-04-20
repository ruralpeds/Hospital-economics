"""
    test_service_line_cohorts.jl

Unit tests for Phase 1.3 Service Line Patient Cohort Analysis
"""

using Test
using Dates
using Statistics

# Include required modules
include("../src/episode/Episode.jl")
include("../src/episode/EpisodeCostModels.jl")
include("../src/patient_flow/PatientAgent.jl")
include("../src/patient_flow/FlowSimulation.jl")
include("../src/episode/ServiceLinePatientCohorts.jl")

# Helper: Create test patient cohort
function make_test_patient(;
    id::String = "PT_test",
    service_line::String = "Cardiology",
    comorbidity_count::Int = 0,
    los_target::Int = 3
)
    PatientAgent(
        id=id,
        admission_date=Date(2026, 4, 1),
        primary_diagnosis="I21",
        secondary_diagnoses=fill("CC_001", comorbidity_count),
        drg_code="247",
        assigned_service_line=service_line,
        los_target=los_target,
        location="ward",
        payer="Medicare"
    )
end

@testset "Phase 1.3: Service Line Patient Cohort Analysis" begin

    # ========================================================================
    # PatientCohort Construction Tests
    # ========================================================================

    @testset "PatientCohort creation" begin
        cohort = PatientCohort(
            "Cardiology", "Age 65-75",
            (65, 75), 3, 2,
            50, 3.5, 25000.0, 18000.0, 7000.0, 28.0,
            0.08, 0.02, 0.15, 0.75, 9333.33
        )

        @test cohort.service_line_id == "Cardiology"
        @test cohort.patient_count == 50
        @test cohort.contribution_margin == 7000.0
        @test cohort.margin_pct ≈ 28.0
    end

    @testset "PatientCohort with empty cohort" begin
        cohort = PatientCohort(
            "Cardiology", "Empty Cohort",
            (0, 100), 1, 0,
            0, 0.0, 0.0, 0.0, 0.0, 0.0,
            0.0, 0.0, 0.0, 0.0, 0.0
        )

        @test cohort.patient_count == 0
        @test cohort.contribution_margin == 0.0
    end

    # ========================================================================
    # Age Segmentation Tests
    # ========================================================================

    @testset "Segment patients by age" begin
        patients = PatientAgent[]

        # Create patients with different admission years (proxy for age)
        for year in 2000:5:2020
            patient = PatientAgent(
                id="PT_$(year)",
                admission_date=Date(year, 1, 1),
                primary_diagnosis="I21"
            )
            push!(patients, patient)
        end

        segments = segment_patients_by_age(patients)

        # All segments should exist
        @test haskey(segments, "0-24")
        @test haskey(segments, "25-40")
        @test haskey(segments, "41-55")
        @test haskey(segments, "56-65")
        @test haskey(segments, "66-75")
        @test haskey(segments, "75+")

        # Total should equal input
        total = sum(length(v) for v in values(segments))
        @test total == length(patients)
    end

    @testset "Age segments contain correct patients" begin
        patients = PatientAgent[]

        # Create young patient (born 2010 → age ~16)
        young = PatientAgent(
            id="PT_young",
            admission_date=Date(2010, 1, 1),
            primary_diagnosis="I21"
        )
        push!(patients, young)

        # Create old patient (born 1980 → age ~46)
        old = PatientAgent(
            id="PT_old",
            admission_date=Date(1980, 1, 1),
            primary_diagnosis="I21"
        )
        push!(patients, old)

        segments = segment_patients_by_age(patients)

        @test length(segments["0-24"]) > 0  # Young patient in correct bracket
        @test length(segments["41-55"]) > 0  # Old patient in correct bracket
    end

    # ========================================================================
    # Severity Segmentation Tests
    # ========================================================================

    @testset "Segment patients by severity" begin
        patients = PatientAgent[]

        # Create patients with varying comorbidity counts
        for comorbidity_count in 0:4
            patient = PatientAgent(
                id="PT_comorbid_$(comorbidity_count)",
                admission_date=Date(2026, 4, 1),
                primary_diagnosis="I21",
                secondary_diagnoses=fill("CC_001", comorbidity_count)
            )
            push!(patients, patient)
        end

        segments = segment_patients_by_severity(patients)

        # All quintiles should exist
        @test haskey(segments, "Q1 (Lowest)")
        @test haskey(segments, "Q2")
        @test haskey(segments, "Q3 (Medium)")
        @test haskey(segments, "Q4")
        @test haskey(segments, "Q5 (Highest)")

        # Total should equal input
        total = sum(length(v) for v in values(segments))
        @test total == length(patients)

        # Q1 should have lowest comorbidity, Q5 should have highest
        q1_comorbidities = mean(p.comorbidity_count for p in segments["Q1 (Lowest)"])
        q5_comorbidities = mean(p.comorbidity_count for p in segments["Q5 (Highest)"])
        @test q1_comorbidities < q5_comorbidities
    end

    # ========================================================================
    # Cohort Profitability Calculation Tests
    # ========================================================================

    @testset "Calculate cohort profitability - single patient" begin
        patient = make_test_patient(id="PT001")
        initialize_patient_cost_tracking(patient, 3)
        accumulate_daily_cost!(patient, 1, 800.0, 300.0, 220.0)
        accumulate_daily_cost!(patient, 2, 800.0, 300.0, 220.0)
        accumulate_daily_cost!(patient, 3, 800.0, 300.0, 220.0)
        discharge_patient!(patient, Date(2026, 4, 4))

        cohort = calculate_cohort_profitability(
            [patient], "Cardiology", "Test Cohort", (60, 75), 3
        )

        @test cohort.patient_count == 1
        @test cohort.avg_cost_per_patient ≈ 3960.0  # 3 days × 1320 (800+300+220)
        @test cohort.avg_revenue_per_patient ≈ 3960.0 * 1.3
        @test cohort.contribution_margin > 0
        @test cohort.margin_pct > 0
    end

    @testset "Calculate cohort profitability - empty cohort" begin
        cohort = calculate_cohort_profitability(
            PatientAgent[], "Cardiology", "Empty", (60, 75), 3
        )

        @test cohort.patient_count == 0
        @test cohort.avg_cost_per_patient == 0.0
        @test cohort.contribution_margin == 0.0
    end

    @testset "Calculate cohort profitability - multiple patients" begin
        patients = PatientAgent[]

        for i in 1:5
            patient = make_test_patient(id="PT_$i")
            initialize_patient_cost_tracking(patient, 3)
            accumulate_daily_cost!(patient, 1, 800.0, 300.0, 220.0)
            accumulate_daily_cost!(patient, 2, 800.0, 300.0, 220.0)
            accumulate_daily_cost!(patient, 3, 800.0, 300.0, 220.0)
            discharge_patient!(patient, Date(2026, 4, 4))
            push!(patients, patient)
        end

        cohort = calculate_cohort_profitability(
            patients, "Cardiology", "Multi-Patient", (60, 75), 3
        )

        @test cohort.patient_count == 5
        @test cohort.avg_cost_per_patient ≈ 3960.0  # 3 days × 1320
        @test cohort.avg_revenue_per_patient ≈ 3960.0 * 1.3
    end

    @testset "Quality metrics in cohort profitability" begin
        # High comorbidity patient
        high_comorbid = make_test_patient(id="PT_high_comorbid", comorbidity_count=3)
        initialize_patient_cost_tracking(high_comorbid, 3)
        accumulate_daily_cost!(high_comorbid, 1, 800.0, 300.0, 220.0)
        discharge_patient!(high_comorbid, Date(2026, 4, 2))

        # Low comorbidity patient
        low_comorbid = make_test_patient(id="PT_low_comorbid", comorbidity_count=0)
        initialize_patient_cost_tracking(low_comorbid, 1)
        accumulate_daily_cost!(low_comorbid, 1, 800.0, 300.0, 220.0)
        discharge_patient!(low_comorbid, Date(2026, 4, 2))

        cohort_high = calculate_cohort_profitability(
            [high_comorbid], "Cardiology", "High Comorbid", (60, 75), 5
        )
        cohort_low = calculate_cohort_profitability(
            [low_comorbid], "Cardiology", "Low Comorbid", (60, 75), 1
        )

        # High comorbidity should have higher readmission and mortality rates
        @test cohort_high.readmission_rate > cohort_low.readmission_rate
        @test cohort_high.mortality_rate > cohort_low.mortality_rate
    end

    # ========================================================================
    # Service Line Analysis Tests
    # ========================================================================

    @testset "Analyze service line by cohort" begin
        patients = PatientAgent[]

        # Create diverse patient mix
        for service in ["Cardiology", "Orthopedics", "General Ward"]
            for i in 1:10
                patient = make_test_patient(
                    id="PT_$(service)_$i",
                    service_line=service,
                    comorbidity_count=rand(0:3)
                )
                initialize_patient_cost_tracking(patient, 3)
                accumulate_daily_cost!(patient, 1, 800.0, 300.0, 220.0)
                accumulate_daily_cost!(patient, 2, 800.0, 300.0, 220.0)
                accumulate_daily_cost!(patient, 3, 800.0, 300.0, 220.0)
                discharge_patient!(patient, Date(2026, 4, 4))
                push!(patients, patient)
            end
        end

        analysis = analyze_service_line_by_cohort("Cardiology", patients)

        @test analysis.service_line_name == "Cardiology"
        @test analysis.total_patients == 10
        @test analysis.total_cost > 0
        @test analysis.total_revenue > analysis.total_cost
        @test analysis.total_margin > 0
        @test !isempty(analysis.cohorts)
    end

    @testset "Service line analysis - empty service line" begin
        patients = PatientAgent[]

        analysis = analyze_service_line_by_cohort("NonExistent", patients)

        @test analysis.total_patients == 0
        @test isempty(analysis.cohorts)
    end

    @testset "Service line analysis rankings" begin
        patients = PatientAgent[]

        for i in 1:20
            patient = make_test_patient(
                id="PT_$i",
                service_line="Cardiology",
                comorbidity_count=rand(0:2)
            )
            initialize_patient_cost_tracking(patient, 3)
            for day in 1:3
                accumulate_daily_cost!(patient, day, 800.0, 300.0, 220.0)
            end
            discharge_patient!(patient, Date(2026, 4, 4))
            push!(patients, patient)
        end

        analysis = analyze_service_line_by_cohort("Cardiology", patients)

        @test !isempty(analysis.profitability_ranking)
        @test !isempty(analysis.quality_ranking)
        @test !isempty(analysis.value_ranking)
        @test length(analysis.profitability_ranking) == length(analysis.cohorts)
    end

    # ========================================================================
    # Cohort Identification Tests
    # ========================================================================

    @testset "Identify high-value cohorts" begin
        patients = PatientAgent[]

        for i in 1:30
            patient = make_test_patient(id="PT_$i", service_line="Cardiology")
            initialize_patient_cost_tracking(patient, 3)
            accumulate_daily_cost!(patient, 1, 800.0, 300.0, 220.0)
            discharge_patient!(patient, Date(2026, 4, 2))
            push!(patients, patient)
        end

        analysis = analyze_service_line_by_cohort("Cardiology", patients)
        high_value = get_high_value_cohorts(analysis)

        @test !isempty(high_value)
        @test length(high_value) <= length(analysis.cohorts)
        @test all(c.margin_per_qaly > 0 for c in high_value)
    end

    @testset "Identify low-margin cohorts" begin
        patients = PatientAgent[]

        # Mix of different patient types
        for i in 1:30
            patient = make_test_patient(
                id="PT_$i",
                service_line="Cardiology",
                comorbidity_count=rand(0:3)
            )
            initialize_patient_cost_tracking(patient, 3)
            for day in 1:3
                accumulate_daily_cost!(patient, day, 800.0, 300.0, 220.0)
            end
            discharge_patient!(patient, Date(2026, 4, 4))
            push!(patients, patient)
        end

        analysis = analyze_service_line_by_cohort("Cardiology", patients)
        low_margin = get_low_margin_cohorts(analysis)

        # Should identify some low/negative margin cohorts or be empty if all profitable
        @test isa(low_margin, Vector{PatientCohort})
    end

    @testset "Identify quality leaders" begin
        patients = PatientAgent[]

        for i in 1:30
            patient = make_test_patient(id="PT_$i", service_line="Cardiology")
            initialize_patient_cost_tracking(patient, 3)
            accumulate_daily_cost!(patient, 1, 800.0, 300.0, 220.0)
            discharge_patient!(patient, Date(2026, 4, 2))
            push!(patients, patient)
        end

        analysis = analyze_service_line_by_cohort("Cardiology", patients)
        quality_leaders = get_quality_leaders(analysis)

        @test !isempty(quality_leaders)
        @test length(quality_leaders) <= length(analysis.cohorts)
        @test all(c.readmission_rate >= 0 for c in quality_leaders)
    end

    # ========================================================================
    # Comparison and Summary Tests
    # ========================================================================

    @testset "Compare cohort to service line average" begin
        patients = PatientAgent[]

        for i in 1:20
            patient = make_test_patient(id="PT_$i", service_line="Cardiology")
            initialize_patient_cost_tracking(patient, 3)
            accumulate_daily_cost!(patient, 1, 800.0, 300.0, 220.0)
            discharge_patient!(patient, Date(2026, 4, 2))
            push!(patients, patient)
        end

        analysis = analyze_service_line_by_cohort("Cardiology", patients)

        if !isempty(analysis.cohorts)
            comparison = compare_cohort_to_service_line_avg(analysis.cohorts[1], analysis)

            @test haskey(comparison, "cost_variance")
            @test haskey(comparison, "revenue_variance")
            @test haskey(comparison, "margin_variance")
            @test haskey(comparison, "volume_pct")
            @test comparison["volume_pct"] > 0
        end
    end

    @testset "Service line cohort summary" begin
        patients = PatientAgent[]

        for i in 1:20
            patient = make_test_patient(id="PT_$i", service_line="Cardiology")
            initialize_patient_cost_tracking(patient, 3)
            accumulate_daily_cost!(patient, 1, 800.0, 300.0, 220.0)
            discharge_patient!(patient, Date(2026, 4, 2))
            push!(patients, patient)
        end

        analysis = analyze_service_line_by_cohort("Cardiology", patients)
        summary = service_line_cohort_summary(analysis)

        @test haskey(summary, "service_line")
        @test haskey(summary, "total_patients")
        @test haskey(summary, "total_margin")
        @test haskey(summary, "margin_percentage")
        @test haskey(summary, "high_value_cohorts")
        @test haskey(summary, "unprofitable_cohorts")
        @test haskey(summary, "quality_leaders")
    end

    @testset "Summary contains valid rankings" begin
        patients = PatientAgent[]

        for i in 1:30
            patient = make_test_patient(id="PT_$i", service_line="Cardiology")
            initialize_patient_cost_tracking(patient, 3)
            accumulate_daily_cost!(patient, 1, 800.0, 300.0, 220.0)
            discharge_patient!(patient, Date(2026, 4, 2))
            push!(patients, patient)
        end

        analysis = analyze_service_line_by_cohort("Cardiology", patients)
        summary = service_line_cohort_summary(analysis)

        @test length(summary["profitability_ranking"]) == length(analysis.cohorts)
        @test length(summary["quality_ranking"]) == length(analysis.cohorts)
        @test length(summary["value_ranking"]) == length(analysis.cohorts)
    end

    # ========================================================================
    # Integration Tests
    # ========================================================================

    @testset "End-to-end: Simulate, segment, and analyze" begin
        # Run a small hospital simulation
        sim = simulate_patient_cohort(50; cost_model=create_standard_drg_model())

        # Analyze all service lines
        for service_line in ["General Ward", "Cardiology", "Orthopedics"]
            analysis = analyze_service_line_by_cohort(service_line, sim.patients)

            if analysis.total_patients > 0
                @test analysis.total_cost > 0
                @test analysis.total_revenue > 0
                @test analysis.total_margin >= 0

                summary = service_line_cohort_summary(analysis)
                @test summary["total_patients"] > 0
            end
        end
    end

    @testset "Multiple service line comparison" begin
        patients = PatientAgent[]

        for service in ["Cardiology", "Orthopedics"]
            for i in 1:15
                patient = make_test_patient(
                    id="PT_$(service)_$i",
                    service_line=service,
                    comorbidity_count=rand(0:2)
                )
                initialize_patient_cost_tracking(patient, 3)
                for day in 1:3
                    accumulate_daily_cost!(patient, day, 800.0, 300.0, 220.0)
                end
                discharge_patient!(patient, Date(2026, 4, 4))
                push!(patients, patient)
            end
        end

        analysis_cardio = analyze_service_line_by_cohort("Cardiology", patients)
        analysis_ortho = analyze_service_line_by_cohort("Orthopedics", patients)

        @test analysis_cardio.total_patients == 15
        @test analysis_ortho.total_patients == 15
        @test analysis_cardio.total_cost > 0
        @test analysis_ortho.total_cost > 0
    end

end

println("\n✅ Phase 1.3: All Service Line Cohort Analysis tests passed!")
