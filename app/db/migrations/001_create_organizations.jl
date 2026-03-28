# Migration 001: Create organizations table (tenant boundary)

module CreateOrganizations

import SearchLight.Migrations:
    create_table, column, columns, pk, add_index, add_indices,
    drop_table

function up()
    create_table(:organizations) do
        [
            pk()
            column(:name, :string; limit=255)
            column(:slug, :string; limit=100)
            column(:org_type, :string; limit=50, default="hospital")  # hospital, system, flex_program, consultant
            column(:is_active, :bool, default=true)
            column(:created_at, :datetime)
            column(:updated_at, :datetime)
        ]
    end

    add_index(:organizations, :slug; unique=true)
end

function down()
    drop_table(:organizations)
end

end
