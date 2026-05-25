"""
Migration 009: Create audit_logs table for persistent audit trail
Supports HIPAA-compliant event logging with indexed lookups on
user, event type, timestamp, and resource.
"""

module CreateAuditLogs

import SearchLight.Migrations:
    create_table, column, columns, pk, add_index,
    drop_table

function up()
    create_table(:audit_logs) do
        [
            pk()
            column(:entry_id, :string; limit=36)
            column(:timestamp, :datetime)
            column(:user_id, :string; limit=255)
            column(:event_type, :string; limit=100)
            column(:resource_type, :string; limit=100)
            column(:resource_id, :string; limit=255)
            column(:action, :string; limit=100)
            column(:details, :text; null=true)
            column(:ip_address, :string; limit=45)
            column(:status, :string; limit=50)
            column(:record_count, :int, default=0)
            column(:outcome, :text; null=true)
            column(:created_at, :datetime)
        ]
    end

    add_index(:audit_logs, :entry_id; unique=true)
    add_index(:audit_logs, :user_id)
    add_index(:audit_logs, :event_type)
    add_index(:audit_logs, :timestamp)
    add_index(:audit_logs, :resource_id)
end

function down()
    drop_table(:audit_logs)
end

end
