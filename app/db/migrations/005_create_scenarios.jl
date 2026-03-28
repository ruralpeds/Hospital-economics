# Migration 005: Create scenarios and simulation_runs tables

module CreateScenarios

import SearchLight.Migrations:
    create_table, column, columns, pk, add_index,
    drop_table

function up()
    create_table(:scenarios) do
        [
            pk()
            column(:hospital_id, :int)
            column(:user_id, :int)
            column(:name, :string; limit=255)
            column(:description, :text, null=true)
            column(:scenario_type, :string; limit=50)  # baseline, optimistic, pessimistic, custom, reh_conversion
            column(:params_json, :text)  # JSON-serialized simulation parameters
            column(:is_baseline, :bool, default=false)
            column(:created_at, :datetime)
            column(:updated_at, :datetime)
        ]
    end

    add_index(:scenarios, :hospital_id)
    add_index(:scenarios, :user_id)

    create_table(:simulation_runs) do
        [
            pk()
            column(:scenario_id, :int)
            column(:run_uuid, :string; limit=36)
            column(:engine_type, :string; limit=30)  # deterministic, monte_carlo, abm, system_dynamics, des, optimization
            column(:status, :string; limit=20, default="pending")  # pending, running, completed, failed
            column(:started_at, :datetime, null=true)
            column(:completed_at, :datetime, null=true)
            column(:duration_seconds, :float, null=true)
            column(:results_json, :text, null=true)  # JSON-serialized results
            column(:summary_json, :text, null=true)  # JSON-serialized summary metrics
            column(:error_message, :text, null=true)
            column(:created_at, :datetime)
            column(:updated_at, :datetime)
        ]
    end

    add_index(:simulation_runs, :scenario_id)
    add_index(:simulation_runs, :run_uuid; unique=true)
    add_index(:simulation_runs, :status)
end

function down()
    drop_table(:simulation_runs)
    drop_table(:scenarios)
end

end
