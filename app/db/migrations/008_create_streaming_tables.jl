"""
Migration 008: Create streaming ingestion tables for Phase 4C
Adds support for real-time patient encounter streaming and alert management
"""

using SearchLight, SearchLight.Migrations

export up, down

function up()
    create_table(:patient_encounters_stream) do
        [
            pk_id(:id),
            column(:patient_id, :String, limit=50),
            column(:encounter_data, :jsonb),
            column(:validation_status, :String, limit=20, default="pending"),
            column(:is_deidentified, :boolean, default=false),
            column(:anomaly_flags, :text),  # JSON array stored as text
            column(:ingestion_timestamp, :datetime),
            column(:processing_latency_ms, :integer),
            column(:is_anomaly, :boolean, default=false),
            column(:risk_category, :String, limit=20),  # "low", "medium", "high"
            column(:created_at, :datetime, default="now()"),
            column(:updated_at, :datetime, default="now()")
        ]
    end

    create_table(:streaming_alerts) do
        [
            pk_id(:id),
            column(:patient_id, :String, limit=50),
            column(:alert_type, :String, limit=50),  # "readmission_risk", "cost_anomaly", "complication", "quality_issue"
            column(:severity, :String, limit=20),  # "info", "warning", "high", "critical"
            column(:description, :text),
            column(:alert_details, :jsonb),  # Additional context as JSON
            column(:alert_timestamp, :datetime),
            column(:acknowledged, :boolean, default=false),
            column(:acknowledged_by, :String, limit=255, allow_null=true),
            column(:acknowledged_at, :datetime, allow_null=true),
            column(:created_at, :datetime, default="now()"),
            column(:updated_at, :datetime, default="now()")
        ]
    end

    create_table(:streaming_metrics) do
        [
            pk_id(:id),
            column(:metric_name, :String, limit=100),
            column(:metric_category, :String, limit=50),  # "throughput", "latency", "error_rate", "validation"
            column(:metric_value, :float),
            column(:metric_timestamp, :datetime),
            column(:pipeline_id, :String, limit=50, allow_null=true),
            column(:created_at, :datetime, default="now()")
        ]
    end

    # Create indexes for frequently queried columns
    add_index(:patient_encounters_stream, :patient_id)
    add_index(:patient_encounters_stream, :ingestion_timestamp)
    add_index(:patient_encounters_stream, :validation_status)
    add_index(:patient_encounters_stream, :is_anomaly)
    add_index(:patient_encounters_stream, :created_at)

    add_index(:streaming_alerts, :patient_id)
    add_index(:streaming_alerts, :alert_type)
    add_index(:streaming_alerts, :severity)
    add_index(:streaming_alerts, :alert_timestamp)
    add_index(:streaming_alerts, :acknowledged)
    add_index(:streaming_alerts, :created_at)

    add_index(:streaming_metrics, :metric_name)
    add_index(:streaming_metrics, :metric_category)
    add_index(:streaming_metrics, :metric_timestamp)
end

function down()
    drop_table(:streaming_metrics)
    drop_table(:streaming_alerts)
    drop_table(:patient_encounters_stream)
end
