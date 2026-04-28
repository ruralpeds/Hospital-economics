"""
Sensitivity / Tornado Analysis UI - tornado diagram with ranked variable impacts.
"""

function ui_sensitivity(model)
    app_layout(model, "Sensitivity Analysis", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Sensitivity / Tornado Analysis", class="q-mb-none"),
                p("Identify which variables have the greatest impact on financial outcomes",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Analyze", icon="swap_horiz", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── Summary KPIs ────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Base Net Income", class="text-overline q-mb-none"),
                    h4("\${{ (base_net_income / 1e3).toFixed(0) }}K", class="q-mb-none",
                       var":class"="base_net_income < 0 ? 'text-red' : 'text-green'"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Most Sensitive Variable", class="text-overline q-mb-none"),
                    h4("{{ most_sensitive_variable }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Max Swing", class="text-overline q-mb-none"),
                    h4("\${{ (max_swing / 1e6).toFixed(1) }}M", class="q-mb-none text-orange"),
                ])])
            ]),
        ]),

        # ── Base Inputs ─────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    h6("Base Financials", class="q-mb-md"),
                    textfield(:base_revenue, label="Base Revenue (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:base_expenses, label="Base Expenses (\$)", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-8 col-xs-12", [
                card([card_section([
                    h6("Variable Perturbations (% Swing)", class="q-mb-md"),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-6", [textfield(:var1_name, label="Variable 1", filled=true, dense=true)]),
                        cell(class="col-6", [textfield(:var1_pct, label="% Swing", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-6", [textfield(:var2_name, label="Variable 2", filled=true, dense=true)]),
                        cell(class="col-6", [textfield(:var2_pct, label="% Swing", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-6", [textfield(:var3_name, label="Variable 3", filled=true, dense=true)]),
                        cell(class="col-6", [textfield(:var3_pct, label="% Swing", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-6", [textfield(:var4_name, label="Variable 4", filled=true, dense=true)]),
                        cell(class="col-6", [textfield(:var4_pct, label="% Swing", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-6", [textfield(:var5_name, label="Variable 5", filled=true, dense=true)]),
                        cell(class="col-6", [textfield(:var5_pct, label="% Swing", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-6", [textfield(:var6_name, label="Variable 6", filled=true, dense=true)]),
                        cell(class="col-6", [textfield(:var6_pct, label="% Swing", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-6", [textfield(:var7_name, label="Variable 7", filled=true, dense=true)]),
                        cell(class="col-6", [textfield(:var7_pct, label="% Swing", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-6", [textfield(:var8_name, label="Variable 8", filled=true, dense=true)]),
                        cell(class="col-6", [textfield(:var8_pct, label="% Swing", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-6", [textfield(:var9_name, label="Variable 9", filled=true, dense=true)]),
                        cell(class="col-6", [textfield(:var9_pct, label="% Swing", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm", [
                        cell(class="col-6", [textfield(:var10_name, label="Variable 10", filled=true, dense=true)]),
                        cell(class="col-6", [textfield(:var10_pct, label="% Swing", type="number", filled=true, dense=true)]),
                    ]),
                ])])
            ]),
        ]),

        # ── Tornado Chart ───────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:tornado_data, layout=:tornado_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
