"""
Strategic Financial Planner UI - timeline chart, initiative cards.
"""

function ui_strategic_planner(model)
    app_layout(model, "Strategic Financial Planner", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Strategic Financial Planner", class="q-mb-none"),
                p("Model 5-year financial trajectory with timed strategic initiatives",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Project", icon="timeline", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── Summary KPIs ────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Cumulative 5-Year Value", class="text-overline q-mb-none"),
                    h4("\${{ (cumulative_value / 1e6).toFixed(1) }}M", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Breakeven Year", class="text-overline q-mb-none"),
                    h4("Year {{ breakeven_year }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Year 5 Margin", class="text-overline q-mb-none"),
                    h4("{{ (year5_margin_pct * 100).toFixed(1) }}%", class="q-mb-none",
                       var":class"="year5_margin_pct > 0 ? 'text-green' : 'text-red'"),
                ])])
            ]),
        ]),

        # ── Base Financials ─────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-xs-12", [
                card([card_section([
                    h6("Base Financials", class="q-mb-md"),
                    textfield(:base_revenue, label="Base Revenue (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:base_expenses, label="Base Expenses (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    p("Revenue Growth: {{ (revenue_growth_rate * 100).toFixed(1) }}%", class="q-mb-none"),
                    slider(:revenue_growth_rate, min=-0.02, max=0.08, step=0.005, label=true, class="q-mb-md"),
                    p("Expense Growth: {{ (expense_growth_rate * 100).toFixed(1) }}%", class="q-mb-none"),
                    slider(:expense_growth_rate, min=0.01, max=0.08, step=0.005, label=true),
                ])])
            ]),

            # ── Initiative Cards ────────────────────────────────────────
            cell(class="col-md-9 col-xs-12", [
                row(class="q-gutter-md", [
                    cell(class="col-md-5 col-sm-6 col-xs-12", [
                        card([card_section([
                            h6("Initiative 1", class="q-mb-sm"),
                            textfield(:init1_name, label="Name", filled=true, dense=true, class="q-mb-sm"),
                            textfield(:init1_year, label="Start Year", type="number", filled=true, dense=true, class="q-mb-sm"),
                            textfield(:init1_revenue_impact, label="Revenue Impact (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                            textfield(:init1_cost_savings, label="Cost Savings (\$)", type="number", filled=true, dense=true),
                        ])])
                    ]),
                    cell(class="col-md-5 col-sm-6 col-xs-12", [
                        card([card_section([
                            h6("Initiative 2", class="q-mb-sm"),
                            textfield(:init2_name, label="Name", filled=true, dense=true, class="q-mb-sm"),
                            textfield(:init2_year, label="Start Year", type="number", filled=true, dense=true, class="q-mb-sm"),
                            textfield(:init2_revenue_impact, label="Revenue Impact (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                            textfield(:init2_cost_savings, label="Cost Savings (\$)", type="number", filled=true, dense=true),
                        ])])
                    ]),
                    cell(class="col-md-5 col-sm-6 col-xs-12", [
                        card([card_section([
                            h6("Initiative 3", class="q-mb-sm"),
                            textfield(:init3_name, label="Name", filled=true, dense=true, class="q-mb-sm"),
                            textfield(:init3_year, label="Start Year", type="number", filled=true, dense=true, class="q-mb-sm"),
                            textfield(:init3_revenue_impact, label="Revenue Impact (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                            textfield(:init3_cost_savings, label="Cost Savings (\$)", type="number", filled=true, dense=true),
                        ])])
                    ]),
                    cell(class="col-md-5 col-sm-6 col-xs-12", [
                        card([card_section([
                            h6("Initiative 4", class="q-mb-sm"),
                            textfield(:init4_name, label="Name", filled=true, dense=true, class="q-mb-sm"),
                            textfield(:init4_year, label="Start Year", type="number", filled=true, dense=true, class="q-mb-sm"),
                            textfield(:init4_revenue_impact, label="Revenue Impact (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                            textfield(:init4_cost_savings, label="Cost Savings (\$)", type="number", filled=true, dense=true),
                        ])])
                    ]),
                ]),
            ]),
        ]),

        # ── Charts ──────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-8 col-xs-12", [
                card([card_section([
                    plot(:trajectory_data, layout=:trajectory_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    plot(:initiative_value_data, layout=:initiative_value_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
    ])
end
