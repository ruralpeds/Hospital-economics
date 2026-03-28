# Migration 007: Create capital_assets, capital_projects, and closure_risk_assessments tables

module CreateCapitalAndRisk

import SearchLight.Migrations:
    create_table, column, columns, pk, add_index,
    drop_table

function up()
    create_table(:capital_assets) do
        [
            pk()
            column(:hospital_id, :int)
            column(:asset_id, :string; limit=50)
            column(:description, :string; limit=255)
            column(:category, :string; limit=30)  # building, equipment, land, it_system, vehicle
            column(:acquisition_date, :date)
            column(:acquisition_cost, :float)
            column(:useful_life_years, :int)
            column(:salvage_value, :float, default=0.0)
            column(:depreciation_method, :string; limit=30, default="straight_line")
            column(:accumulated_depreciation, :float, default=0.0)
            column(:is_active, :bool, default=true)
            column(:funding_source, :string; limit=30, default="operating")
            column(:created_at, :datetime)
            column(:updated_at, :datetime)
        ]
    end

    add_index(:capital_assets, :hospital_id)

    create_table(:capital_projects) do
        [
            pk()
            column(:hospital_id, :int)
            column(:project_id, :string; limit=50)
            column(:name, :string; limit=255)
            column(:description, :text, null=true)
            column(:category, :string; limit=30)  # facility, equipment, it, renovation, expansion
            column(:estimated_cost, :float)
            column(:approved_budget, :float, default=0.0)
            column(:spent_to_date, :float, default=0.0)
            column(:start_date, :date, null=true)
            column(:expected_completion, :date, null=true)
            column(:status, :string; limit=20, default="proposed")
            column(:priority_rank, :int, default=0)
            column(:expected_useful_life_years, :int, default=10)
            column(:created_at, :datetime)
            column(:updated_at, :datetime)
        ]
    end

    add_index(:capital_projects, :hospital_id)

    create_table(:closure_risk_assessments) do
        [
            pk()
            column(:hospital_id, :int)
            column(:assessment_date, :date)
            column(:risk_score, :float)  # 0-100
            column(:risk_category, :string; limit=20)  # low, medium_low, medium_high, high
            column(:years_to_distress, :float, null=true)
            column(:factors_json, :text)  # JSON-serialized factor contributions
            column(:recommendations_json, :text, null=true)
            column(:created_at, :datetime)
            column(:updated_at, :datetime)
        ]
    end

    add_index(:closure_risk_assessments, :hospital_id)
    add_index(:closure_risk_assessments, [:hospital_id, :assessment_date])
end

function down()
    drop_table(:closure_risk_assessments)
    drop_table(:capital_projects)
    drop_table(:capital_assets)
end

end
