"""
Scenario Builder UI - guided wizard for creating and managing financial scenarios.
"""

function ui_scenarios(model)
    app_layout(model, "Scenario Builder", [
        # ── Header ───────────────────────────────────────────────────────
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Scenario Builder", class="q-mb-none"),
                p("Create and manage financial projection scenarios", class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("New Scenario", icon="add", color="primary", @click(:create_new)),
            ]),
        ]),

        # ── Scenario Library Table ───────────────────────────────────────
        card(var"v-if"="!wizard_active", class="q-mb-lg", [
            card_section([
                h6("Saved Scenarios", class="q-mb-md"),
                q__table(
                    rows=:scenarios, flat=true, dense=true,
                    var"row-key"="id",
                    columns="""[
                        {name:'name', label:'Name', field:'name', align:'left', sortable:true},
                        {name:'description', label:'Description', field:'description', align:'left'},
                        {name:'status', label:'Status', field:'status', align:'center'},
                        {name:'created', label:'Created', field:'created', align:'center', sortable:true},
                        {name:'actions', label:'Actions', align:'center'}
                    ]""",
                    [
                        template("", var"v-slot:body-cell-status"="props", [
                            q__td(props="props", [
                                badge("{{ props.value }}",
                                    var":color"="props.value === 'completed' ? 'green' : props.value === 'running' ? 'blue' : 'grey'")
                            ])
                        ]),
                        template("", var"v-slot:body-cell-actions"="props", [
                            q__td(props="props", [
                                btn("", icon="content_copy", flat=true, dense=true, round=true,
                                    @click("selected_scenario_id = props.row.id; duplicate_scenario = true")),
                                btn("", icon="delete", flat=true, dense=true, round=true, color="red",
                                    @click("selected_scenario_id = props.row.id; delete_scenario = true")),
                            ])
                        ]),
                    ]
                )
            ])
        ]),

        # ── Wizard ───────────────────────────────────────────────────────
        card(var"v-if"="wizard_active", class="q-mb-lg", [
            card_section([
                stepper(:wizard_step, vertical=false, animated=true, [
                    # Step 1: Basic Info
                    step(val=1, title="Basic Info", icon="info", [
                        p("Name and describe your scenario.", class="q-mb-md"),
                        textfield(:scenario_name, label="Scenario Name", filled=true,
                            rules="[val => val.length > 0 || 'Required']"),
                        textfield(:scenario_description, label="Description", filled=true,
                            type="textarea", class="q-mt-md"),
                        q__select(:base_scenario,
                            options=[:baseline=>"Start from Baseline",
                                     :current=>"Start from Current Data",
                                     :blank=>"Start Blank"],
                            label="Base Scenario", filled=true, class="q-mt-md",
                            var"emit-value"=true, var"map-options"=true),
                        step_navigation(class="q-mt-lg", [
                            btn("Cancel", flat=true, @click("wizard_active = false")),
                            btn("Next", color="primary", @click("wizard_step = 2")),
                        ]),
                    ]),

                    # Step 2: Revenue Assumptions
                    step(val=2, title="Revenue", icon="trending_up", [
                        h6("Revenue Assumptions", class="q-mb-md"),
                        row(class="q-gutter-md", [
                            cell(class="col-md-4 col-xs-6", [
                                numberfield(:revenue_growth_rate, label="Revenue Growth Rate (%)",
                                    filled=true, dense=true, step="0.1",
                                    hint="Annual revenue growth percentage")
                            ]),
                            cell(class="col-md-4 col-xs-6", [
                                numberfield(:volume_growth_rate, label="Volume Growth Rate (%)",
                                    filled=true, dense=true, step="0.1",
                                    hint="Patient volume change per year")
                            ]),
                            cell(class="col-md-4 col-xs-6", [
                                numberfield(:rate_increase_pct, label="Rate Increase (%)",
                                    filled=true, dense=true, step="0.1")
                            ]),
                        ]),
                        row(class="q-gutter-md q-mt-sm", [
                            cell(class="col-md-4 col-xs-6", [
                                numberfield(:outpatient_growth_rate, label="Outpatient Growth (%)",
                                    filled=true, dense=true, step="0.1")
                            ]),
                            cell(class="col-md-4 col-xs-6", [
                                numberfield(:telehealth_revenue, label="New Telehealth Revenue (\$)",
                                    filled=true, dense=true)
                            ]),
                            cell(class="col-md-4 col-xs-6", [
                                numberfield(:new_service_revenue, label="New Service Revenue (\$)",
                                    filled=true, dense=true)
                            ]),
                        ]),
                        separator(class="q-my-md"),
                        p("Payer Mix Shifts (% point change)", class="text-subtitle2"),
                        row(class="q-gutter-md", [
                            cell(class="col-md-4 col-xs-6", [
                                numberfield(:payer_mix_shift_medicare, label="Medicare Shift",
                                    filled=true, dense=true, step="0.5")
                            ]),
                            cell(class="col-md-4 col-xs-6", [
                                numberfield(:payer_mix_shift_medicaid, label="Medicaid Shift",
                                    filled=true, dense=true, step="0.5")
                            ]),
                            cell(class="col-md-4 col-xs-6", [
                                numberfield(:payer_mix_shift_commercial, label="Commercial Shift",
                                    filled=true, dense=true, step="0.5")
                            ]),
                        ]),
                        step_navigation(class="q-mt-lg", [
                            btn("Back", flat=true, @click("wizard_step = 1")),
                            btn("Next", color="primary", @click("wizard_step = 3")),
                        ]),
                    ]),

                    # Step 3: Expense Assumptions
                    step(val=3, title="Expenses", icon="trending_down", [
                        h6("Expense Assumptions", class="q-mb-md"),
                        row(class="q-gutter-md", [
                            cell(class="col-md-3 col-xs-6", [
                                numberfield(:salary_increase_pct, label="Salary Increase (%)",
                                    filled=true, dense=true, step="0.1")
                            ]),
                            cell(class="col-md-3 col-xs-6", [
                                numberfield(:benefit_cost_change, label="Benefit Cost Change (%)",
                                    filled=true, dense=true, step="0.1")
                            ]),
                            cell(class="col-md-3 col-xs-6", [
                                numberfield(:supply_cost_inflation, label="Supply Inflation (%)",
                                    filled=true, dense=true, step="0.1")
                            ]),
                            cell(class="col-md-3 col-xs-6", [
                                numberfield(:drug_cost_inflation, label="Drug Cost Inflation (%)",
                                    filled=true, dense=true, step="0.1")
                            ]),
                        ]),
                        row(class="q-gutter-md q-mt-sm", [
                            cell(class="col-md-3 col-xs-6", [
                                numberfield(:fte_change, label="FTE Change",
                                    filled=true, dense=true, step="0.5")
                            ]),
                            cell(class="col-md-3 col-xs-6", [
                                numberfield(:capital_expenditure, label="Capital Expenditure (\$)",
                                    filled=true, dense=true)
                            ]),
                            cell(class="col-md-3 col-xs-6", [
                                numberfield(:technology_investment, label="Tech Investment (\$)",
                                    filled=true, dense=true)
                            ]),
                            cell(class="col-md-3 col-xs-6", [
                                numberfield(:energy_cost_change, label="Energy Cost Change (%)",
                                    filled=true, dense=true, step="0.1")
                            ]),
                        ]),
                        step_navigation(class="q-mt-lg", [
                            btn("Back", flat=true, @click("wizard_step = 2")),
                            btn("Next", color="primary", @click("wizard_step = 4")),
                        ]),
                    ]),

                    # Step 4: Regulatory & Market
                    step(val=4, title="Regulatory & Market", icon="policy", [
                        h6("Regulatory Assumptions", class="q-mb-md"),
                        row(class="q-gutter-md", [
                            cell(class="col-md-3 col-xs-6", [
                                numberfield(:medicare_rate_update, label="Medicare Rate Update (%)",
                                    filled=true, dense=true, step="0.1")
                            ]),
                            cell(class="col-md-3 col-xs-6", [
                                toggle(:medicaid_expansion, label="Medicaid Expansion")
                            ]),
                            cell(class="col-md-3 col-xs-6", [
                                toggle(:reh_conversion, label="REH Conversion")
                            ]),
                            cell(class="col-md-3 col-xs-6", [
                                numberfield(:reh_monthly_payment, label="REH Monthly Payment (\$)",
                                    filled=true, dense=true, var"v-if"="reh_conversion")
                            ]),
                        ]),
                        separator(class="q-my-md"),
                        h6("Market Assumptions", class="q-mb-md"),
                        row(class="q-gutter-md", [
                            cell(class="col-md-3 col-xs-6", [
                                numberfield(:population_growth_rate, label="Population Growth (%)",
                                    filled=true, dense=true, step="0.1")
                            ]),
                            cell(class="col-md-3 col-xs-6", [
                                numberfield(:inflation_rate, label="General Inflation (%)",
                                    filled=true, dense=true, step="0.1")
                            ]),
                            cell(class="col-md-3 col-xs-6", [
                                toggle(:competitor_entry, label="New Competitor Entry")
                            ]),
                            cell(class="col-md-3 col-xs-6", [
                                numberfield(:physician_recruitment, label="Physicians to Recruit",
                                    filled=true, dense=true)
                            ]),
                        ]),
                        step_navigation(class="q-mt-lg", [
                            btn("Back", flat=true, @click("wizard_step = 3")),
                            btn("Save Scenario", icon="save", color="primary", @click(:save_scenario)),
                        ]),
                    ]),
                ])
            ])
        ]),

        # ── Status ───────────────────────────────────────────────────────
        quasar(:banner, var"v-if"="save_status !== ''", class="q-mb-md bg-green-1", dense=true, rounded=true, [
            span("{{ save_status }}")
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
