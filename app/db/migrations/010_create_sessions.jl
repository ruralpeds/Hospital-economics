"""
Migration 010: Create sessions table for persistent session storage
Replaces the in-memory SESSION_STORE with a database-backed session store
to support horizontal scaling and session survival across restarts.
"""

module CreateSessions

import SearchLight.Migrations:
    create_table, column, columns, pk, add_index,
    drop_table

function up()
    create_table(:sessions) do
        [
            pk()
            column(:token, :string; limit=255)
            column(:user_id, :int)
            column(:email, :string; limit=255)
            column(:role, :string; limit=50)
            column(:organization_id, :int)
            column(:expires_at, :datetime)
            column(:created_at, :datetime)
        ]
    end

    add_index(:sessions, :token; unique=true)
    add_index(:sessions, :user_id)
    add_index(:sessions, :expires_at)
end

function down()
    drop_table(:sessions)
end

end
