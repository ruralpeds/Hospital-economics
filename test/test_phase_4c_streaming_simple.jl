"""
Phase 4C: Real-Time Streaming Ingestion Tests (60+ tests)
Standalone test file for streaming module
"""

using Test, Dates, JSON3, Statistics

# Direct module load
include("../src/streaming/StreamingIngestion.jl")

@testset "Phase 4C: Real-Time Streaming Pipeline" begin

    # ───────────────────────────────────────────────────────────────────────
    # 1. STREAMING CONFIG INITIALIZATION (5 tests)
    # ───────────────────────────────────────────────────────────────────────

    @testset "StreamingConfig Initialization" begin
        config = StreamingIngestion.default_config()

        @test isa(config, StreamingIngestion.StreamingConfig)
        @test config.kafka_brokers == ["localhost:9092"]
        @test config.raw_topic == "patient-encounters-raw"
        @test config.batch_size == 100
        @test config.async_workers == 4
        @test config.timeout == 5.0
        @test config.persistence_enabled == true
        @test config.max_queue_size == 5000
    end

    @testset "StreamingConfig Customization" begin
        custom_config = StreamingIngestion.StreamingConfig(
            ["broker1:9092", "broker2:9092"],
            "custom-topic",
            "validation-topic",
            "deidentified-topic",
            "alerts-topic",
            50,
            2,
            3.0,
            true,
            "http://alerts-endpoint/send",
            2,
            10000
        )

        @test custom_config.kafka_brokers == ["broker1:9092", "broker2:9092"]
        @test custom_config.raw_topic == "custom-topic"
        @test custom_config.batch_size == 50
        @test custom_config.async_workers == 2
    end

    # ───────────────────────────────────────────────────────────────────────
    # 2. PIPELINE INITIALIZATION (5 tests)
    # ───────────────────────────────────────────────────────────────────────

    @testset "Pipeline Initialization" begin
        config = StreamingIngestion.default_config()
        pipeline = StreamingIngestion.initialize_streaming(config)

        @test isa(pipeline, Dict)
        @test haskey(pipeline, "config")
        @test haskey(pipeline, "metrics")
        @test haskey(pipeline, "queue")
        @test haskey(pipeline, "running")
        @test haskey(pipeline, "start_time")
        @test pipeline["running"] == true
        @test isempty(pipeline["queue"])
    end

    @testset "Metrics Initialization" begin
        metrics = StreamingIngestion.create_metrics()

        @test isa(metrics, StreamingIngestion.StreamingMetrics)
        @test metrics.total_records == 0
        @test metrics.valid_records == 0
        @test metrics.invalid_records == 0
        @test metrics.anomaly_count == 0
        @test metrics.avg_latency_ms == 0.0
        @test metrics.peak_throughput == 0.0
        @test isempty(metrics.errors)
    end

    # ───────────────────────────────────────────────────────────────────────
    # 3. ENCOUNTER VALIDATION (8 tests)
    # ───────────────────────────────────────────────────────────────────────

    @testset "Valid Encounter Validation" begin
        valid_encounter = Dict(
            "patient_id" => "P123",
            "encounter_date" => "2024-01-15",
            "primary_diagnosis" => "E11.9"
        )

        @test StreamingIngestion.validate_encounter_data(valid_encounter) == true
    end

    @testset "Missing Required Fields - patient_id" begin
        invalid_encounter = Dict(
            "encounter_date" => "2024-01-15",
            "primary_diagnosis" => "E11.9"
        )

        @test StreamingIngestion.validate_encounter_data(invalid_encounter) == false
    end

    @testset "Missing Required Fields - encounter_date" begin
        invalid_encounter = Dict(
            "patient_id" => "P123",
            "primary_diagnosis" => "E11.9"
        )

        @test StreamingIngestion.validate_encounter_data(invalid_encounter) == false
    end

    @testset "Missing Required Fields - primary_diagnosis" begin
        invalid_encounter = Dict(
            "patient_id" => "P123",
            "encounter_date" => "2024-01-15"
        )

        @test StreamingIngestion.validate_encounter_data(invalid_encounter) == false
    end

    @testset "Empty Required Field" begin
        invalid_encounter = Dict(
            "patient_id" => "",
            "encounter_date" => "2024-01-15",
            "primary_diagnosis" => "E11.9"
        )

        @test StreamingIngestion.validate_encounter_data(invalid_encounter) == false
    end

    @testset "Invalid Field Type - patient_id" begin
        invalid_encounter = Dict(
            "patient_id" => 123,  # Should be String
            "encounter_date" => "2024-01-15",
            "primary_diagnosis" => "E11.9"
        )

        @test StreamingIngestion.validate_encounter_data(invalid_encounter) == false
    end

    @testset "Whitespace-only Field" begin
        invalid_encounter = Dict(
            "patient_id" => "   ",
            "encounter_date" => "2024-01-15",
            "primary_diagnosis" => "E11.9"
        )

        @test StreamingIngestion.validate_encounter_data(invalid_encounter) == false
    end

    # ───────────────────────────────────────────────────────────────────────
    # 4. ANOMALY DETECTION (10 tests)
    # ───────────────────────────────────────────────────────────────────────

    @testset "Anomaly Detection - High Cost" begin
        encounter = Dict("total_cost" => 20000.0)
        anomalies = StreamingIngestion.detect_anomalies(encounter)

        @test "high_cost_anomaly" in anomalies
    end

    @testset "Anomaly Detection - Low Cost" begin
        encounter = Dict("total_cost" => 50.0)
        anomalies = StreamingIngestion.detect_anomalies(encounter)

        @test "low_cost_anomaly" in anomalies
    end

    @testset "Anomaly Detection - Normal Cost" begin
        encounter = Dict("total_cost" => 5000.0)
        anomalies = StreamingIngestion.detect_anomalies(encounter)

        @test !("high_cost_anomaly" in anomalies)
        @test !("low_cost_anomaly" in anomalies)
    end

    @testset "Anomaly Detection - Extended LOS" begin
        encounter = Dict("los" => 45)
        anomalies = StreamingIngestion.detect_anomalies(encounter)

        @test "extended_los" in anomalies
    end

    @testset "Anomaly Detection - Missing LOS" begin
        encounter = Dict("los" => 0)
        anomalies = StreamingIngestion.detect_anomalies(encounter)

        @test "missing_los" in anomalies
    end

    @testset "Anomaly Detection - Normal LOS" begin
        encounter = Dict("los" => 5)
        anomalies = StreamingIngestion.detect_anomalies(encounter)

        @test !("extended_los" in anomalies)
        @test !("missing_los" in anomalies)
    end

    @testset "Anomaly Detection - High Comorbidity" begin
        encounter = Dict("comorbidity_count" => 8)
        anomalies = StreamingIngestion.detect_anomalies(encounter)

        @test "high_comorbidity_burden" in anomalies
    end

    @testset "Anomaly Detection - Invalid Age" begin
        encounter = Dict("age" => 150)
        anomalies = StreamingIngestion.detect_anomalies(encounter)

        @test "invalid_age" in anomalies
    end

    @testset "Anomaly Detection - Negative Age" begin
        encounter = Dict("age" => -5)
        anomalies = StreamingIngestion.detect_anomalies(encounter)

        @test "invalid_age" in anomalies
    end

    @testset "Anomaly Detection - Multiple Anomalies" begin
        encounter = Dict(
            "total_cost" => 25000.0,
            "los" => 60,
            "comorbidity_count" => 7,
            "age" => 85
        )
        anomalies = StreamingIngestion.detect_anomalies(encounter)

        @test "high_cost_anomaly" in anomalies
        @test "extended_los" in anomalies
        @test "high_comorbidity_burden" in anomalies
        @test length(anomalies) == 3
    end

    # ───────────────────────────────────────────────────────────────────────
    # 5. ENCOUNTER SUBMISSION (8 tests)
    # ───────────────────────────────────────────────────────────────────────

    @testset "Submit Single Encounter" begin
        config = StreamingIngestion.default_config()
        pipeline = StreamingIngestion.initialize_streaming(config)

        encounter_data = Dict(
            "patient_id" => "P456",
            "encounter_date" => "2024-02-01",
            "primary_diagnosis" => "I10"
        )

        record = StreamingIngestion.submit_encounter(encounter_data, pipeline)

        @test isa(record, StreamingIngestion.EncounterRecord)
        @test record.patient_id == "P456"
        @test record.validation_status == "pending"
        @test record.deidentified == false
        @test length(pipeline["queue"]) == 1
    end

    @testset "Submit Multiple Encounters" begin
        config = StreamingIngestion.default_config()
        pipeline = StreamingIngestion.initialize_streaming(config)

        for i in 1:5
            encounter_data = Dict(
                "patient_id" => "P$i",
                "encounter_date" => "2024-02-01",
                "primary_diagnosis" => "I10"
            )
            StreamingIngestion.submit_encounter(encounter_data, pipeline)
        end

        @test length(pipeline["queue"]) == 5
    end

    @testset "Encounter Record ID Generation" begin
        config = StreamingIngestion.default_config()
        pipeline = StreamingIngestion.initialize_streaming(config)

        encounter1 = Dict(
            "patient_id" => "P1",
            "encounter_date" => "2024-02-01",
            "primary_diagnosis" => "I10"
        )
        record1 = StreamingIngestion.submit_encounter(encounter1, pipeline)

        encounter2 = Dict(
            "patient_id" => "P2",
            "encounter_date" => "2024-02-01",
            "primary_diagnosis" => "I10"
        )
        record2 = StreamingIngestion.submit_encounter(encounter2, pipeline)

        @test record1.id != record2.id
    end

    @testset "Queue Size Monitoring" begin
        config = StreamingIngestion.StreamingConfig(
            ["localhost:9092"],
            "patient-encounters-raw",
            "validation-results",
            "deidentified-encounters",
            "alerts",
            100,
            4,
            5.0,
            true,
            "http://localhost:8000/api/alerts",
            3,
            10  # max_queue_size = 10
        )
        pipeline = StreamingIngestion.initialize_streaming(config)

        for i in 1:10
            encounter_data = Dict(
                "patient_id" => "P$i",
                "encounter_date" => "2024-02-01",
                "primary_diagnosis" => "I10"
            )
            StreamingIngestion.submit_encounter(encounter_data, pipeline)
        end

        @test length(pipeline["queue"]) == 10
    end

    @testset "Encounter with Generated ID" begin
        config = StreamingIngestion.default_config()
        pipeline = StreamingIngestion.initialize_streaming(config)

        # No explicit encounter_id provided
        encounter_data = Dict(
            "patient_id" => "P789",
            "encounter_date" => "2024-02-01",
            "primary_diagnosis" => "I10"
        )
        record = StreamingIngestion.submit_encounter(encounter_data, pipeline)

        @test !isempty(record.id)
        @test record.id != "unknown"
    end

    # ───────────────────────────────────────────────────────────────────────
    # 6. BATCH PROCESSING (10 tests)
    # ───────────────────────────────────────────────────────────────────────

    @testset "Process Valid Batch" begin
        config = StreamingIngestion.default_config()
        batch = [
            StreamingIngestion.EncounterRecord(
                "E1",
                "P1",
                Dict("patient_id" => "P1", "encounter_date" => "2024-02-01", "primary_diagnosis" => "I10"),
                "pending",
                false,
                String[],
                now(),
                0
            ),
            StreamingIngestion.EncounterRecord(
                "E2",
                "P2",
                Dict("patient_id" => "P2", "encounter_date" => "2024-02-01", "primary_diagnosis" => "I10"),
                "pending",
                false,
                String[],
                now(),
                0
            )
        ]

        processed = StreamingIngestion.process_batch(batch, config)

        @test length(processed) == 2
        @test all(r -> r.validation_status in ["valid", "invalid"], processed)
        @test all(r -> r.deidentified == true, processed)
        @test all(r -> r.processing_latency_ms >= 0, processed)
    end

    @testset "Process Batch with Invalid Records" begin
        config = StreamingIngestion.default_config()
        batch = [
            StreamingIngestion.EncounterRecord(
                "E1",
                "P1",
                Dict("patient_id" => "P1", "encounter_date" => "2024-02-01", "primary_diagnosis" => "I10"),
                "pending",
                false,
                String[],
                now(),
                0
            ),
            StreamingIngestion.EncounterRecord(
                "E2",
                "P2",
                Dict("patient_id" => ""),  # Invalid: empty patient_id
                "pending",
                false,
                String[],
                now(),
                0
            )
        ]

        processed = StreamingIngestion.process_batch(batch, config)

        @test length(processed) == 2
        @test processed[1].validation_status == "valid"
        @test processed[2].validation_status == "invalid"
    end

    @testset "Process Batch with Anomalies" begin
        config = StreamingIngestion.default_config()
        batch = [
            StreamingIngestion.EncounterRecord(
                "E1",
                "P1",
                Dict(
                    "patient_id" => "P1",
                    "encounter_date" => "2024-02-01",
                    "primary_diagnosis" => "I10",
                    "total_cost" => 25000.0,
                    "los" => 5
                ),
                "pending",
                false,
                String[],
                now(),
                0
            )
        ]

        processed = StreamingIngestion.process_batch(batch, config)

        @test processed[1].validation_status == "valid"
        @test !isempty(processed[1].anomaly_flags)
        @test "high_cost_anomaly" in processed[1].anomaly_flags
    end

    @testset "Batch Processing Latency" begin
        config = StreamingIngestion.default_config()
        batch = [
            StreamingIngestion.EncounterRecord(
                "E$i",
                "P$i",
                Dict("patient_id" => "P$i", "encounter_date" => "2024-02-01", "primary_diagnosis" => "I10"),
                "pending",
                false,
                String[],
                now(),
                0
            )
            for i in 1:10
        ]

        processed = StreamingIngestion.process_batch(batch, config)
        latencies = [r.processing_latency_ms for r in processed]

        @test all(l >= 0 for l in latencies)
        @test mean(latencies) < 1000  # Should be fast (< 1s average)
    end

    @testset "Empty Batch Processing" begin
        config = StreamingIngestion.default_config()
        batch = StreamingIngestion.EncounterRecord[]

        processed = StreamingIngestion.process_batch(batch, config)

        @test isempty(processed)
    end

    @testset "Large Batch Processing" begin
        config = StreamingIngestion.default_config()
        batch = [
            StreamingIngestion.EncounterRecord(
                "E$i",
                "P$i",
                Dict("patient_id" => "P$i", "encounter_date" => "2024-02-01", "primary_diagnosis" => "I10"),
                "pending",
                false,
                String[],
                now(),
                0
            )
            for i in 1:100
        ]

        processed = StreamingIngestion.process_batch(batch, config)

        @test length(processed) == 100
    end

    @testset "Deidentification Flag Set" begin
        config = StreamingIngestion.default_config()
        batch = [
            StreamingIngestion.EncounterRecord(
                "E1",
                "P1",
                Dict("patient_id" => "P1", "encounter_date" => "2024-02-01", "primary_diagnosis" => "I10"),
                "pending",
                false,
                String[],
                now(),
                0
            )
        ]

        processed = StreamingIngestion.process_batch(batch, config)

        @test processed[1].deidentified == true
    end

    # ───────────────────────────────────────────────────────────────────────
    # 7. STREAMING RESULTS (6 tests)
    # ───────────────────────────────────────────────────────────────────────

    @testset "Create Result - All Valid" begin
        errors = String[]
        latencies = [10.5, 12.3, 11.8, 13.2]

        result = StreamingIngestion.create_result(4, 4, 0, errors, latencies)

        @test result.records_processed == 4
        @test result.records_valid == 4
        @test result.records_invalid == 0
        @test result.status == "success"
        @test result.latency_p50 > 0
        @test result.latency_p95 > result.latency_p50
    end

    @testset "Create Result - Partial Success" begin
        errors = ["validation_error_1"]
        latencies = [10.5, 12.3]

        result = StreamingIngestion.create_result(3, 2, 1, errors, latencies)

        @test result.records_processed == 3
        @test result.records_valid == 2
        @test result.records_invalid == 1
        @test result.status == "partial"
    end

    @testset "Create Result - All Failed" begin
        errors = ["validation_error_1", "validation_error_2", "validation_error_3"]
        latencies = Float64[]

        result = StreamingIngestion.create_result(3, 0, 3, errors, latencies)

        @test result.records_valid == 0
        @test result.records_invalid == 3
        @test result.status == "failed"
        @test result.latency_p50 == 0.0
    end

    @testset "Result Percentile Calculations" begin
        latencies = [5.0, 10.0, 15.0, 20.0, 25.0]
        result = StreamingIngestion.create_result(5, 5, 0, String[], latencies)

        @test result.latency_p50 ≈ 15.0 atol=1.0
        @test result.latency_p95 > result.latency_p50
    end

    @testset "Result Timestamp" begin
        before = now()
        result = StreamingIngestion.create_result(1, 1, 0, String[], [10.0])
        after = now()

        @test before <= result.timestamp <= after
    end

    # ───────────────────────────────────────────────────────────────────────
    # 8. PIPELINE STATUS (4 tests)
    # ───────────────────────────────────────────────────────────────────────

    @testset "Get Pipeline Status - Empty" begin
        config = StreamingIngestion.default_config()
        pipeline = StreamingIngestion.initialize_streaming(config)

        status = StreamingIngestion.get_status(pipeline)

        @test status["running"] == true
        @test status["queue_size"] == 0
        @test status["total_records"] == 0
        @test status["valid_records"] == 0
        @test status["invalid_records"] == 0
    end

    @testset "Get Pipeline Status - With Data" begin
        config = StreamingIngestion.default_config()
        pipeline = StreamingIngestion.initialize_streaming(config)

        for i in 1:5
            encounter_data = Dict(
                "patient_id" => "P$i",
                "encounter_date" => "2024-02-01",
                "primary_diagnosis" => "I10"
            )
            StreamingIngestion.submit_encounter(encounter_data, pipeline)
        end

        status = StreamingIngestion.get_status(pipeline)

        @test status["queue_size"] == 5
        @test status["running"] == true
    end

    @testset "Pipeline Uptime Calculation" begin
        config = StreamingIngestion.default_config()
        pipeline = StreamingIngestion.initialize_streaming(config)

        sleep(0.05)  # Wait 100ms
        status = StreamingIngestion.get_status(pipeline)

        @test status["uptime_seconds"] >= 0.05
    end

    @testset "Pipeline Shutdown" begin
        config = StreamingIngestion.default_config()
        pipeline = StreamingIngestion.initialize_streaming(config)

        shutdown_result = StreamingIngestion.shutdown_streaming(pipeline)

        @test pipeline["running"] == false
        @test shutdown_result["status"] == "shutdown"
        @test haskey(shutdown_result, "final_metrics")
    end

end

println("\n" * "="^70)
println("Phase 4C Streaming Tests Complete")
println("="^70)
