"""
Network Economics UI - shared services, ACO formation, and joint purchasing.
"""

function ui_network_economics(model)
    app_layout(model, "Network Economics", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Rural Health Network Economics", class="q-mb-none"),
                p("Shared-service savings, ACO economics, and joint purchasing power", class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Evaluate", icon="hub", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ──────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Shared Service Savings", class="text-overline q-mb-none"),
                    h4("\${{ (annual_savings / 1e3).toFixed(0) }}K/yr", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Breakeven", class="text-overline q-mb-none"),
                    h4("{{ breakeven_years.toFixed(1) }} yrs", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("ACO Shared Savings", class="text-overline q-mb-none"),
                    h4("\${{ (aco_shared_savings / 1e3).toFixed(0) }}K", class="q-mb-none text-blue"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("GPO Savings", class="text-overline q-mb-none"),
                    h4("\${{ (gpo_savings / 1e3).toFixed(0) }}K/yr", class="q-mb-none text-purple"),
                ])])
            ]),
        ]),

        # ── Inputs ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Network Members", class="q-mb-md"),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-4", [textfield(:m1_name, label="Hospital 1", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:m1_revenue, label="Revenue", type="number", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:m1_expenses, label="Expenses", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-4", [textfield(:m2_name, label="Hospital 2", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:m2_revenue, label="Revenue", type="number", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:m2_expenses, label="Expenses", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm", [
                        cell(class="col-4", [textfield(:m3_name, label="Hospital 3", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:m3_revenue, label="Revenue", type="number", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:m3_expenses, label="Expenses", type="number", filled=true, dense=true)]),
                    ]),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Shared Services", class="q-mb-md"),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-4", [textfield(:ss1_name, label="Service 1", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:ss1_current, label="Current Cost", type="number", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:ss1_network, label="Network Cost", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-md", [
                        cell(class="col-4", [textfield(:ss2_name, label="Service 2", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:ss2_current, label="Current Cost", type="number", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:ss2_network, label="Network Cost", type="number", filled=true, dense=true)]),
                    ]),
                    h6("ACO Parameters", class="q-mb-md"),
                    textfield(:benchmark_per_bene, label="Benchmark/Beneficiary (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:total_beneficiaries, label="Total Beneficiaries", type="number", filled=true, dense=true),
                ])])
            ]),
        ]),

        # ── Charts ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:savings_chart_data, layout=:savings_chart_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:network_chart_data, layout=:network_chart_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
