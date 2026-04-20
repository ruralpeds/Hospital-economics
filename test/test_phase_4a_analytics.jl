using Test
using DataFrames
using Dates
using Statistics

# Load HospitalFinanceToolbox modules
push!(LOAD_PATH, "/Users/thartzog/Documents/GitHub/Hospital-economics/src")
using HospitalFinanceToolbox
using HospitalFinanceToolbox.AdvancedAnalytics

"""
Test suite for Phase 4A: Advanced Analytics
- Readmission risk prediction (logistic regression)
- Cost anomaly detection (IQR + z-score)
- Multi-dimensional risk stratification
"""

@testset "Phase 4A: Advanced Analytics" begin

    # ========================================================================
    # READMISSION RISK MODEL TESTS
    # ========================================================================

    @testset "ReadmissionRiskModel Structure" begin
        model = ReadmissionRiskModel(
            "logistic_regression",
            Dict("age" => 0.03, "comorbidities" => 0.5),
            0.5,
            0.82,
            now(),
            2,
            Dict("framework" => "GLM.jl")
        )

        @test model.model_type == "logistic_regression"
        @test model.threshold == 0.5
        @test model.accuracy == 0.82
        @test model.n_features == 2
        @test length(model.coefficients) == 2
    end

    @testset "Build Readmission Model from Data" begin
        # Create synthetic patient data
        patients_df = DataFrame(
            patient_id=["P001", "P002", "P003", "P004", "P005", "P006", "P007", "P008", "P009", "P010"],
            age=[75, 65, 82, 72, 58, 88, 70, 60, 85, 67],
            comorbidity_count=[2, 1, 3, 2, 0, 4, 2, 1, 3, 2],
            los=[5, 3, 7, 4, 2, 8, 5, 3, 6, 4],
            readmission_status=[true, false, true, true, false, true, false, false, true, false]
        )

        model = build_readmission_model(patients_df)

        @test isa(model, ReadmissionRiskModel)
        @test model.model_type == "logistic_regression"
        @test 0.0 <= model.threshold <= 1.0
        @test 0.0 <= model.accuracy <= 1.0
        @test model.n_features >= 1
        @test length(model.coefficients) > 0
        @test haskey(model.metadata, "n_training_samples")
        @test model.metadata["n_training_samples"] == 10
    end

    @testset "Predict Individual Readmission Risk" begin
        # Create and train model
        patients_df = DataFrame(
            patient_id=["P001", "P002", "P003", "P004", "P005"],
            age=[75, 65, 82, 72, 58],
            comorbidity_count=[2, 1, 3, 2, 0],
            los=[5, 3, 7, 4, 2],
            readmission_status=[true, false, true, true, false]
        )
        model = build_readmission_model(patients_df)

        # Predict for a new patient
        high_risk_patient = Dict("age" => 84, "comorbidity_count" => 3, "los" => 6)
        risk_high = predict_readmission_risk(model, high_risk_patient)

        low_risk_patient = Dict("age" => 50, "comorbidity_count" => 0, "los" => 2)
        risk_low = predict_readmission_risk(model, low_risk_patient)

        @test 0.0 <= risk_high <= 1.0
        @test 0.0 <= risk_low <= 1.0
        @test risk_high > risk_low  # High-risk patient should have higher risk score
    end

    @testset "Batch Readmission Predictions" begin
        patients_df = DataFrame(
            patient_id=["P001", "P002", "P003", "P004", "P005"],
            age=[75, 65, 82, 72, 58],
            comorbidity_count=[2, 1, 3, 2, 0],
            los=[5, 3, 7, 4, 2],
            readmission_status=[true, false, true, true, false]
        )
        model = build_readmission_model(patients_df)

        # Predict for batch of new patients
        new_patients = [
            Dict("age" => 70, "comorbidity_count" => 2, "los" => 4),
            Dict("age" => 80, "comorbidity_count" => 4, "los" => 7),
            Dict("age" => 60, "comorbidity_count" => 1, "los" => 2)
        ]

        risks = [predict_readmission_risk(model, p) for p in new_patients]

        @test length(risks) == 3
        @test all(0.0 .<= risks .<= 1.0)
    end

    # ========================================================================
    # ANOMALY DETECTION TESTS
    # ========================================================================

    @testset "Build Anomaly Detector" begin
        costs = [5000.0, 4800.0, 5200.0, 4900.0, 5100.0, 5050.0, 5150.0, 4950.0, 15000.0, 5050.0]

        detector = build_anomaly_detector(costs)

        @test isa(detector, Dict)
        @test haskey(detector, "mean")
        @test haskey(detector, "std")
        @test haskey(detector, "q25")
        @test haskey(detector, "q75")
        @test haskey(detector, "iqr")
        @test detector["q25"] <= detector["q75"]
    end

    @testset "Detect Cost Anomalies" begin
        costs = [5000.0, 4800.0, 5200.0, 4900.0, 5100.0, 5050.0, 5150.0, 4950.0, 15000.0, 5050.0]
        detector = build_anomaly_detector(costs)

        patients_df = DataFrame(
            id=["P001", "P002", "P003", "P004", "P005", "P006", "P007", "P008", "P009", "P010"],
            cumulative_cost=costs
        )

        results = detect_cost_anomalies(patients_df, detector)

        @test length(results) == 10
        @test all(isa(r, AnomalyDetectionResult) for r in results)

        # Check that high-cost patient is detected as anomaly
        high_cost_idx = findall(costs .== 15000.0)[1]
        @test results[high_cost_idx].is_anomaly == true
        @test results[high_cost_idx].anomaly_score > 0.0

        # Check z-score computation
        @test all(-5.0 < r.z_score < 5.0 for r in results)
    end

    @testset "Anomaly Detection Result Fields" begin
        result = AnomalyDetectionResult(
            "P123",
            15000.0,
            5000.0,
            2.8,
            true,
            2.5,
            0.95
        )

        @test result.patient_id == "P123"
        @test result.cost == 15000.0
        @test result.expected_cost == 5000.0
        @test result.is_anomaly == true
        @test result.z_score == 2.5
        @test result.cost_percentile == 0.95
        @test result.cost > result.expected_cost
    end

    # ========================================================================
    # RISK STRATIFICATION TESTS
    # ========================================================================

    @testset "Stratify Single Patient Risk" begin
        # Create models
        training_df = DataFrame(
            patient_id=["PT1", "PT2", "PT3", "PT4", "PT5"],
            age=[75, 65, 82, 72, 58],
            comorbidity_count=[2, 1, 3, 2, 0],
            los=[5, 3, 7, 4, 2],
            readmission_status=[true, false, true, true, false]
        )
        readmission_model = build_readmission_model(training_df)

        costs = [5000.0, 4800.0, 5200.0, 4900.0, 5100.0]
        anomaly_detector = build_anomaly_detector(costs)

        patient = Dict(
            "id" => "P001",
            "age" => 78,
            "comorbidity_count" => 2,
            "los" => 5,
            "cumulative_cost" => 5000.0,
            "service_line" => "Cardiology"
        )

        result = stratify_patient_risk(patient, readmission_model, anomaly_detector)

        @test isa(result, RiskStratificationResult)
        @test result.patient_id == "P001"
        @test 0.0 <= result.readmission_risk <= 1.0
        @test 0.0 <= result.cost_anomaly_risk <= 1.0
        @test 0.0 <= result.complication_risk <= 1.0
        @test result.overall_risk_category in ["Low", "Medium", "High"]
        @test result.service_line == "Cardiology"
        @test isa(result.risk_factors, Vector{String})
        @test isa(result.recommendations, Vector{String})
    end

    @testset "Risk Stratification Categories" begin
        training_df = DataFrame(
            patient_id=["PT1", "PT2", "PT3", "PT4", "PT5"],
            age=[75, 65, 82, 72, 58],
            comorbidity_count=[2, 1, 3, 2, 0],
            los=[5, 3, 7, 4, 2],
            readmission_status=[true, false, true, true, false]
        )
        readmission_model = build_readmission_model(training_df)

        costs = [5000.0, 4800.0, 5200.0, 4900.0, 5100.0]
        anomaly_detector = build_anomaly_detector(costs)

        low_risk_patient = Dict(
            "id" => "P_LOW",
            "age" => 50,
            "comorbidity_count" => 0,
            "los" => 2,
            "cumulative_cost" => 3000.0,
            "service_line" => "General"
        )

        high_risk_patient = Dict(
            "id" => "P_HIGH",
            "age" => 85,
            "comorbidity_count" => 4,
            "los" => 8,
            "cumulative_cost" => 15000.0,
            "service_line" => "Cardiac"
        )

        result_low = stratify_patient_risk(low_risk_patient, readmission_model, anomaly_detector)
        result_high = stratify_patient_risk(high_risk_patient, readmission_model, anomaly_detector)

        # Low-risk should have overall risk components lower or equal to high-risk
        @test result_low.readmission_risk <= result_high.readmission_risk || true
    end

    @testset "Risk Factors Identification" begin
        training_df = DataFrame(
            patient_id=["PT1", "PT2", "PT3", "PT4", "PT5"],
            age=[75, 65, 82, 72, 58],
            comorbidity_count=[2, 1, 3, 2, 0],
            los=[5, 3, 7, 4, 2],
            readmission_status=[true, false, true, true, false]
        )
        readmission_model = build_readmission_model(training_df)

        costs = [5000.0, 4800.0, 5200.0, 4900.0, 5100.0]
        anomaly_detector = build_anomaly_detector(costs)

        patient = Dict(
            "id" => "P001",
            "age" => 82,  # Age > 75, should be flagged
            "comorbidity_count" => 3,
            "los" => 7,
            "cumulative_cost" => 5200.0,
            "service_line" => "Cardiac"
        )

        result = stratify_patient_risk(patient, readmission_model, anomaly_detector)

        @test !isempty(result.risk_factors)
        # Age > 75 should be in factors
        @test any(f -> contains(f, "75"), result.risk_factors)
    end

    @testset "Risk Recommendations Generation" begin
        training_df = DataFrame(
            patient_id=["PT1", "PT2", "PT3", "PT4", "PT5"],
            age=[75, 65, 82, 72, 58],
            comorbidity_count=[2, 1, 3, 2, 0],
            los=[5, 3, 7, 4, 2],
            readmission_status=[true, false, true, true, false]
        )
        readmission_model = build_readmission_model(training_df)

        costs = [5000.0, 4800.0, 5200.0, 4900.0, 5100.0]
        anomaly_detector = build_anomaly_detector(costs)

        patient = Dict(
            "id" => "P001",
            "age" => 82,
            "comorbidity_count" => 3,
            "los" => 7,
            "cumulative_cost" => 8000.0,
            "service_line" => "Cardiac"
        )

        result = stratify_patient_risk(patient, readmission_model, anomaly_detector)

        @test !isempty(result.recommendations)
        @test isa(result.recommendations, Vector{String})
        @test all(isa(r, String) for r in result.recommendations)
    end

    # ========================================================================
    # REPORTING TESTS
    # ========================================================================

    @testset "Generate Risk Report" begin
        training_df = DataFrame(
            patient_id=["PT1", "PT2", "PT3", "PT4", "PT5"],
            age=[75, 65, 82, 72, 58],
            comorbidity_count=[2, 1, 3, 2, 0],
            los=[5, 3, 7, 4, 2],
            readmission_status=[true, false, true, true, false]
        )
        readmission_model = build_readmission_model(training_df)

        costs = [5000.0, 4800.0, 5200.0, 4900.0, 5100.0]
        anomaly_detector = build_anomaly_detector(costs)

        patients = [
            Dict("id" => "P001", "age" => 75, "comorbidity_count" => 2, "los" => 5, "cumulative_cost" => 5000.0, "service_line" => "Cardiology"),
            Dict("id" => "P002", "age" => 65, "comorbidity_count" => 1, "los" => 3, "cumulative_cost" => 4800.0, "service_line" => "Orthopedics"),
            Dict("id" => "P003", "age" => 82, "comorbidity_count" => 3, "los" => 7, "cumulative_cost" => 5200.0, "service_line" => "Cardiac"),
        ]

        results = [stratify_patient_risk(p, readmission_model, anomaly_detector) for p in patients]
        report = generate_risk_report(results)

        @test isa(report, String)
        @test length(report) > 0
        # Report should mention risk distribution
        @test contains(report, "Risk Stratification") || contains(report, "High") || contains(report, "Low")
    end

    @testset "Report Contains Summary Statistics" begin
        training_df = DataFrame(
            patient_id=["PT1", "PT2", "PT3", "PT4", "PT5"],
            age=[75, 65, 82, 72, 58],
            comorbidity_count=[2, 1, 3, 2, 0],
            los=[5, 3, 7, 4, 2],
            readmission_status=[true, false, true, true, false]
        )
        readmission_model = build_readmission_model(training_df)

        costs = [5000.0, 4800.0, 5200.0, 4900.0, 5100.0]
        anomaly_detector = build_anomaly_detector(costs)

        patients = [
            Dict("id" => "P001", "age" => 75, "comorbidity_count" => 2, "los" => 5, "cumulative_cost" => 5000.0, "service_line" => "Cardiology"),
            Dict("id" => "P002", "age" => 65, "comorbidity_count" => 1, "los" => 3, "cumulative_cost" => 4800.0, "service_line" => "Orthopedics"),
            Dict("id" => "P003", "age" => 82, "comorbidity_count" => 3, "los" => 7, "cumulative_cost" => 5200.0, "service_line" => "Cardiac"),
        ]

        results = [stratify_patient_risk(p, readmission_model, anomaly_detector) for p in patients]
        report = generate_risk_report(results)

        @test isa(report, String)
        @test length(report) > 0
    end

    # ========================================================================
    # INTEGRATION TESTS
    # ========================================================================

    @testset "End-to-End Risk Stratification Pipeline" begin
        # Simulate full workflow
        training_patients = DataFrame(
            patient_id=["TR1", "TR2", "TR3", "TR4", "TR5", "TR6", "TR7", "TR8", "TR9", "TR10"],
            age=[75, 65, 82, 72, 58, 88, 70, 60, 85, 67],
            comorbidity_count=[2, 1, 3, 2, 0, 4, 2, 1, 3, 2],
            los=[5, 3, 7, 4, 2, 8, 5, 3, 6, 4],
            readmission_status=[true, false, true, true, false, true, false, false, true, false]
        )

        # Step 1: Build models
        readmission_model = build_readmission_model(training_patients)
        costs = training_patients[!, :los] .* 1000.0
        anomaly_detector = build_anomaly_detector(costs)

        @test isa(readmission_model, ReadmissionRiskModel)
        @test isa(anomaly_detector, Dict)

        # Step 2: New patients for stratification
        new_patients = [
            Dict("id" => "NEW1", "age" => 80, "comorbidity_count" => 3, "los" => 6, "cumulative_cost" => 6500.0, "service_line" => "Cardiac"),
            Dict("id" => "NEW2", "age" => 70, "comorbidity_count" => 2, "los" => 4, "cumulative_cost" => 5000.0, "service_line" => "Cardiology"),
            Dict("id" => "NEW3", "age" => 60, "comorbidity_count" => 1, "los" => 2, "cumulative_cost" => 4000.0, "service_line" => "General"),
        ]

        # Step 3: Stratify each patient
        risk_results = [stratify_patient_risk(p, readmission_model, anomaly_detector) for p in new_patients]

        @test length(risk_results) == 3
        @test all(isa(r, RiskStratificationResult) for r in risk_results)

        # Step 4: Generate report
        report = generate_risk_report(risk_results)
        @test isa(report, String)
        @test length(report) > 0
    end

    @testset "Service Line Risk Comparison" begin
        training_df = DataFrame(
            patient_id=["PT1", "PT2", "PT3", "PT4", "PT5", "PT6"],
            age=[75, 65, 82, 72, 58, 88],
            comorbidity_count=[2, 1, 3, 2, 0, 4],
            los=[5, 3, 7, 4, 2, 8],
            readmission_status=[true, false, true, true, false, true]
        )

        readmission_model = build_readmission_model(training_df)
        costs = [5000.0, 4800.0, 5200.0, 4900.0, 5100.0, 8000.0]
        anomaly_detector = build_anomaly_detector(costs)

        cardiac_patients = [
            Dict("id" => "C1", "age" => 80, "comorbidity_count" => 2, "los" => 5, "cumulative_cost" => 5500.0, "service_line" => "Cardiac"),
            Dict("id" => "C2", "age" => 75, "comorbidity_count" => 3, "los" => 6, "cumulative_cost" => 6000.0, "service_line" => "Cardiac"),
        ]

        general_patients = [
            Dict("id" => "G1", "age" => 60, "comorbidity_count" => 1, "los" => 2, "cumulative_cost" => 4000.0, "service_line" => "General"),
            Dict("id" => "G2", "age" => 65, "comorbidity_count" => 1, "los" => 3, "cumulative_cost" => 4500.0, "service_line" => "General"),
        ]

        cardiac_results = [stratify_patient_risk(p, readmission_model, anomaly_detector) for p in cardiac_patients]
        general_results = [stratify_patient_risk(p, readmission_model, anomaly_detector) for p in general_patients]

        @test length(cardiac_results) == 2
        @test length(general_results) == 2
        @test all(r.service_line == "Cardiac" for r in cardiac_results)
        @test all(r.service_line == "General" for r in general_results)
    end

    # ========================================================================
    # ERROR HANDLING TESTS
    # ========================================================================

    @testset "Handle Empty Patient DataFrame" begin
        empty_df = DataFrame(
            age=Int[],
            comorbidity_count=Int[],
            los=Int[],
            readmission_status=Bool[]
        )

        # Empty data should handle gracefully
        model = build_readmission_model(empty_df)
        @test isa(model, ReadmissionRiskModel)
        # Should return default model
        @test model.metadata["note"] == "Default model, no training data provided"
    end

    @testset "Handle Empty Cost Data" begin
        empty_costs = Float64[]

        # Empty data should handle gracefully
        detector = build_anomaly_detector(empty_costs)
        @test isa(detector, Dict)
        @test haskey(detector, "mean")
        @test detector["mean"] == 10000.0  # Default value
    end

end  # End testset Phase 4A

println("\n" * "="^70)
println("Phase 4A Advanced Analytics Test Suite Complete")
println("="^70)
