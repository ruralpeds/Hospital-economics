# Migration 002: Create users table with RBAC

module CreateUsers

import SearchLight.Migrations:
    create_table, column, columns, pk, add_index,
    drop_table

function up()
    create_table(:users) do
        [
            pk()
            column(:organization_id, :int)
            column(:email, :string; limit=255)
            column(:password_hash, :string; limit=255)
            column(:name, :string; limit=255)
            column(:role, :string; limit=50, default="viewer")  # admin, analyst, viewer
            column(:is_active, :bool, default=true)
            column(:last_login_at, :datetime; null=true)
            column(:created_at, :datetime)
            column(:updated_at, :datetime)
        ]
    end

    add_index(:users, :email; unique=true)
    add_index(:users, :organization_id)
end

function down()
    drop_table(:users)
end

end
