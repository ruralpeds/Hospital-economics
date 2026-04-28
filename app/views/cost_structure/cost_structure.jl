"""
Cost Structure Model UI - stacked bar chart, cost breakdown table.
"""

function ui_cost_structure(model)
    app_layout(model, "Cost Structure Model", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Cost Structure Model", class="q-mb-none"),
                p("Analyze fixed vs variable cost breakdown and operating leverage",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Analyze", icon="pie_chart", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── KPIs ────────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Total Cost", class="text-overline q-mb-none"),
                    h5("\${{ (total_cost / 1e6).toFixed(1) }}M", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Fixed %", class="text-overline q-mb-none"),
                    h5("{{ (fixed_pct * 100).toFixed(0) }}%", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Variable %", class="text-overline q-mb-none"),
                    h5("{{ (variable_pct * 100).toFixed(0) }}%", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Cost/Discharge", class="text-overline q-mb-none"),
                    h5("\${{ cost_per_adjusted_discharge.toLocaleString() }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Cost/ED Visit", class="text-overline q-mb-none"),
                    h5("\${{ cost_per_ed_visit.toLocaleString() }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Op Leverage", class="text-overline q-mb-none"),
                    h5("{{ operating_leverage.toFixed(2) }}x", class="q-mb-none"),
                ])])
            ]),
        ]),

        # ── Inputs and Charts ───────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-xs-12", [
                card([card_section([
                    h6("Hospital Parameters", class="q-mb-md"),
                    textfield(:beds, label="Licensed Beds", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:avg_daily_census, label="Avg Daily Census", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:ed_visits, label="Annual ED Visits", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:op_visits, label="Annual OP Visits", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:fte_count, label="FTE Count", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:avg_salary, label="Avg Salary (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    p("Travel Nurse %: {{ (travel_pct * 100).toFixed(0) }}%", class="q-mb-none"),
                    slider(:travel_pct, min=0.0, max=0.30, step=0.01, label=true),
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    plot(:cost_breakdown_data, layout=:cost_breakdown_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-5 col-xs-12", [
                card([card_section([
                    plot(:category_chart_data, layout=:category_chart_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Cost Category Table ─────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Cost Category Breakdown", class="q-mb-md"),
                    table(class="q-table", [
                        thead([tr([th("Category"), th("Amount"), th("% of Total"), th("Type")])]),
                        tbody([
                            tr(var"v-for"="(c, idx) in cost_categories", key!="idx", [
                                td("{{ c.category }}"),
                                td("\${{ (c.amount / 1000).toFixed(0) }}K"),
                                td("{{ c.pct.toFixed(1) }}%"),
                                td([badge("{{ c.type }}", var":color"="c.type === 'fixed' ? 'blue' : c.type === 'variable' ? 'orange' : 'grey'")]),
                            ])
                        ]),
                    ])
                ])])
            ]),
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
