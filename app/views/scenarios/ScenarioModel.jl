"""
Stipple reactive model for the Scenario Builder.
Manages scenario creation, assumption editing, and scenario library.
"""
using Stipple, StippleUI


@app begin
    @in left_drawer_open::Bool = true
    # ── Scenario Library ─────────────────────────────────────────────────
    @in selected_scenario_id::Int = 0
    @out scenarios::Vector{Dict{String,Any}} = [
        Dict("id"=>1, "name"=>"Baseline", "description"=>"Current trajectory",
             "status"=>"completed", "created"=>"2026-01-15"),
        Dict("id"=>2, "name"=>"REH Conversion", "description"=>"Convert CAH to REH",
             "status"=>"completed", "created"=>"2026-02-01"),
        Dict("id"=>3, "name"=>"Telehealth Expansion", "description"=>"Add 5 telehealth specialties",
             "status"=>"draft", "created"=>"2026-02-20"),
        Dict("id"=>4, "name"=>"Cost Reduction", "description"=>"15% OpEx reduction plan",
             "status"=>"draft", "created"=>"2026-03-10"),
    ]

    # ── Wizard State ─────────────────────────────────────────────────────
    @in wizard_step::Int = 1
    @in wizard_active::Bool = false
    @in scenario_name::String = ""
    @in scenario_description::String = ""
    @in base_scenario::String = "baseline"

    # ── Revenue Assumptions ──────────────────────────────────────────────
    @in revenue_growth_rate::Float64 = 2.0
    @in volume_growth_rate::Float64 = -0.5
    @in rate_increase_pct::Float64 = 2.5
    @in new_service_revenue::Float64 = 0.0
    @in payer_mix_shift_medicare::Float64 = 0.0
    @in payer_mix_shift_medicaid::Float64 = 0.0
    @in payer_mix_shift_commercial::Float64 = 0.0
    @in outpatient_growth_rate::Float64 = 3.0
    @in telehealth_revenue::Float64 = 0.0
    @in bad_debt_change::Float64 = 0.0
    @in charity_care_change::Float64 = 0.0

    # ── Expense Assumptions ──────────────────────────────────────────────
    @in salary_increase_pct::Float64 = 3.0
    @in benefit_cost_change::Float64 = 4.0
    @in supply_cost_inflation::Float64 = 3.5
    @in drug_cost_inflation::Float64 = 5.0
    @in fte_change::Float64 = 0.0
    @in contract_labor_change::Float64 = 0.0
    @in capital_expenditure::Float64 = 0.0
    @in maintenance_capex::Float64 = 500_000.0
    @in technology_investment::Float64 = 0.0
    @in energy_cost_change::Float64 = 2.0

    # ── Regulatory / Policy Assumptions ──────────────────────────────────
    @in medicare_rate_update::Float64 = 1.5
    @in medicaid_expansion::Bool = false
    @in dsh_payment_change::Float64 = 0.0
    @in cost_report_settlement::Float64 = 0.0
    @in section_340b_eligible::Bool = true
    @in state_supplement_change::Float64 = 0.0
    @in reh_conversion::Bool = false
    @in reh_monthly_payment::Float64 = 272_866.0

    # ── Market / External Assumptions ────────────────────────────────────
    @in population_growth_rate::Float64 = -0.3
    @in aging_acceleration::Float64 = 0.5
    @in competitor_entry::Bool = false
    @in physician_recruitment::Int = 0
    @in inflation_rate::Float64 = 2.5
    @in interest_rate_change::Float64 = 0.0

    # ── Form Actions ─────────────────────────────────────────────────────
    @in save_scenario::Bool = false
    @in delete_scenario::Bool = false
    @in duplicate_scenario::Bool = false
    @in create_new::Bool = false
    @out save_status::String = ""
    @out validation_errors::Vector{String} = String[]

    @onchange create_new begin
        if create_new
            create_new = false
            wizard_active = true
            wizard_step = 1
            scenario_name = ""
            scenario_description = ""
        end
    end

    @onchange save_scenario begin
        if save_scenario
            save_scenario = false
            errors = String[]
            if isempty(scenario_name)
                push!(errors, "Scenario name is required")
            end
            if revenue_growth_rate < -20 || revenue_growth_rate > 50
                push!(errors, "Revenue growth rate must be between -20% and 50%")
            end
            validation_errors = errors
            if isempty(errors)
                new_id = length(scenarios) + 1
                new_scenario = Dict{String,Any}(
                    "id" => new_id, "name" => scenario_name,
                    "description" => scenario_description,
                    "status" => "draft", "created" => string(today())
                )
                scenarios = vcat(scenarios, [new_scenario])
                wizard_active = false
                save_status = "Scenario '$(scenario_name)' saved"
            end
        end
    end

    @onchange duplicate_scenario begin
        if duplicate_scenario && selected_scenario_id > 0
            duplicate_scenario = false
            src = findfirst(s -> s["id"] == selected_scenario_id, scenarios)
            if src !== nothing
                orig = scenarios[src]
                new_id = length(scenarios) + 1
                dup = Dict{String,Any}(
                    "id" => new_id, "name" => orig["name"] * " (copy)",
                    "description" => orig["description"],
                    "status" => "draft", "created" => string(today())
                )
                scenarios = vcat(scenarios, [dup])
                save_status = "Duplicated scenario"
            end
        end
    end

    @onchange delete_scenario begin
        if delete_scenario && selected_scenario_id > 0
            delete_scenario = false
            scenarios = filter(s -> s["id"] != selected_scenario_id, scenarios)
            selected_scenario_id = 0
            save_status = "Scenario deleted"
        end
    end
end

const scenario_model = @init
