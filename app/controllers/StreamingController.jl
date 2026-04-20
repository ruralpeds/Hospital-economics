"""
HTTP Controller for Streaming Ingestion API
Endpoints for submitting patient encounters and monitoring streaming pipeline
"""

module StreamingController

using Genie, Genie.Requests, Genie.Responses
using JSON3
using Dates

push!(LOAD_PATH, joinpath(@__DIR__, "..", "..", "src"))
using .StreamingIngestion

# Global streaming pipeline instance
const STREAMING_PIPELINE = Ref{Dict}(Dict())

"""
Initialize streaming pipeline on server startup
"""
function init_streaming()
    if isempty(STREAMING_PIPELINE[])
        config = StreamingIngestion.default_config()
        STREAMING_PIPELINE[] = StreamingIngestion.initialize_streaming(config)
        @info "Streaming pipeline initialized"
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# HTTP ENDPOINTS
# ═══════════════════════════════════════════════════════════════════════════

"""
POST /api/stream/encounter
Submit a single patient encounter to the streaming pipeline
"""
function post_encounter()
    try
        # Initialize if needed
        init_streaming()

        # Parse request body
        encounter_data = JSON3.read(payload())

        # Validate basic structure
        if !isa(encounter_data, Dict)
            return json(
                Dict(
                    "status" => "error",
                    "message" => "Request body must be a JSON object",
                    "code" => 400
                ),
                status = 400
            )
        end

        # Submit to pipeline
        record = StreamingIngestion.submit_encounter(encounter_data, STREAMING_PIPELINE[])

        return json(
            Dict(
                "status" => "accepted",
                "record_id" => record.id,
                "patient_id" => record.patient_id,
                "timestamp" => record.ingestion_timestamp,
                "queue_size" => length(STREAMING_PIPELINE[]["queue"])
            ),
            status = 202
        )
    catch e
        @error "Error submitting encounter" exception=(e, catch_backtrace())
        return json(
            Dict(
                "status" => "error",
                "message" => string(e),
                "code" => 500
            ),
            status = 500
        )
    end
end

"""
POST /api/stream/encounters-batch
Submit a batch of patient encounters
"""
function post_encounters_batch()
    try
        init_streaming()

        encounter_list = JSON3.read(payload())

        if !isa(encounter_list, Vector)
            return json(
                Dict(
                    "status" => "error",
                    "message" => "Request body must be a JSON array",
                    "code" => 400
                ),
                status = 400
            )
        end

        # Submit each encounter
        submitted = 0
        for encounter in encounter_list
            if isa(encounter, Dict)
                StreamingIngestion.submit_encounter(encounter, STREAMING_PIPELINE[])
                submitted += 1
            end
        end

        return json(
            Dict(
                "status" => "accepted",
                "batch_size" => length(encounter_list),
                "submitted" => submitted,
                "queue_size" => length(STREAMING_PIPELINE[]["queue"]),
                "timestamp" => now()
            ),
            status = 202
        )
    catch e
        @error "Error submitting batch" exception=(e, catch_backtrace())
        return json(
            Dict(
                "status" => "error",
                "message" => string(e),
                "code" => 500
            ),
            status = 500
        )
    end
end

"""
GET /api/stream/status
Get streaming pipeline status and metrics
"""
function get_status()
    try
        init_streaming()

        status = StreamingIngestion.get_status(STREAMING_PIPELINE[])

        return json(status, status = 200)
    catch e
        @error "Error getting status" exception=(e, catch_backtrace())
        return json(
            Dict(
                "status" => "error",
                "message" => string(e),
                "code" => 500
            ),
            status = 500
        )
    end
end

"""
GET /api/stream/metrics
Get detailed streaming metrics
"""
function get_metrics()
    try
        init_streaming()

        metrics = STREAMING_PIPELINE[]["metrics"]

        return json(
            Dict(
                "total_records" => metrics.total_records,
                "valid_records" => metrics.valid_records,
                "invalid_records" => metrics.invalid_records,
                "valid_rate" => metrics.total_records > 0 ? metrics.valid_records / metrics.total_records : 0.0,
                "anomaly_count" => metrics.anomaly_count,
                "anomaly_rate" => metrics.total_records > 0 ? metrics.anomaly_count / metrics.total_records : 0.0,
                "avg_latency_ms" => metrics.avg_latency_ms,
                "peak_throughput" => metrics.peak_throughput,
                "error_count" => length(metrics.errors),
                "last_update" => metrics.last_update
            ),
            status = 200
        )
    catch e
        @error "Error getting metrics" exception=(e, catch_backtrace())
        return json(
            Dict(
                "status" => "error",
                "message" => string(e),
                "code" => 500
            ),
            status = 500
        )
    end
end

"""
POST /api/stream/process
Trigger batch processing of queued encounters
"""
function post_process()
    try
        init_streaming()

        pipeline = STREAMING_PIPELINE[]
        queue = pipeline["queue"]

        if isempty(queue)
            return json(
                Dict(
                    "status" => "success",
                    "message" => "No records to process",
                    "processed" => 0
                ),
                status = 200
            )
        end

        # Process batch
        batch_size = min(pipeline["config"].batch_size, length(queue))
        batch = queue[1:batch_size]

        processed = StreamingIngestion.process_batch(batch, pipeline["config"])

        # Update metrics
        metrics = pipeline["metrics"]
        metrics.total_records += length(processed)
        metrics.valid_records += count(r -> r.validation_status == "valid", processed)
        metrics.invalid_records += count(r -> r.validation_status == "invalid", processed)
        metrics.anomaly_count += sum(length(r.anomaly_flags) for r in processed)

        # Clear processed records from queue
        deleteat!(queue, 1:batch_size)

        return json(
            Dict(
                "status" => "success",
                "processed" => length(processed),
                "valid" => count(r -> r.validation_status == "valid", processed),
                "invalid" => count(r -> r.validation_status == "invalid", processed),
                "anomalies_detected" => sum(length(r.anomaly_flags) for r in processed),
                "remaining_queue" => length(queue)
            ),
            status = 200
        )
    catch e
        @error "Error processing batch" exception=(e, catch_backtrace())
        return json(
            Dict(
                "status" => "error",
                "message" => string(e),
                "code" => 500
            ),
            status = 500
        )
    end
end

"""
DELETE /api/stream/reset
Reset streaming pipeline (development only)
"""
function delete_reset()
    try
        STREAMING_PIPELINE[] = Dict()
        init_streaming()

        return json(
            Dict(
                "status" => "success",
                "message" => "Pipeline reset",
                "new_state" => StreamingIngestion.get_status(STREAMING_PIPELINE[])
            ),
            status = 200
        )
    catch e
        @error "Error resetting pipeline" exception=(e, catch_backtrace())
        return json(
            Dict(
                "status" => "error",
                "message" => string(e),
                "code" => 500
            ),
            status = 500
        )
    end
end

end # module StreamingController
