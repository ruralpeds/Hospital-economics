"""
Capital Scoring UI - MCDA weighted scoring with budget-constrained selection.
"""

function ui_capital_scoring(model)
    app_layout(model, "Capital Scoring", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("MCDA Capital Replacement Scoring", class="q-mb-none"),
                p("Multi-criteria scoring and budget-constrained project selection", class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Score & Select", icon="analytics", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ──────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Projects Selected", class="text-overline q-mb-none"),
                    h4("{{ selected_projects.length }} / 4", class="q-mb-none text-blue"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Total Cost Selected", class="text-overline q-mb-none"),
                    h4("\${{ (total_cost_selected / 1e6).toFixed(2) }}M", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Budget Utilization", class="text-overline q-mb-none"),
                    h4("{{ (budget_utilization * 100).toFixed(0) }}%", class="q-mb-none",
                       var":class"="budget_utilization > 0.80 ? 'text-green' : 'text-orange'"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Annual Benefit", class="text-overline q-mb-none"),
                    h4("\${{ (total_annual_benefit / 1e3).toFixed(0) }}K", class="q-mb-none text-green"),
                ])])
            ]),
        ]),

        # ── Budget & Weights ───────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    h6("Budget & Weights", class="q-mb-md"),
                    textfield(:annual_capex_budget, label="Annual CapEx Budget (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    separator(class="q-my-sm"),
                    textfield(:w_safety, label="Safety Weight", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:w_revenue, label="Revenue Weight", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:w_condition, label="Condition Weight", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:w_strategic, label="Strategic Weight", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:w_efficiency, label="Efficiency Weight", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-8 col-xs-12", [
                card([card_section([
                    h6("Projects", class="q-mb-md"),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-3", [textfield(:p1_name, label="Project 1", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:p1_cost, label="Cost", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:p1_safety, label="Safety", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:p1_revenue, label="Rev/yr", type="number", filled=true, dense=true)]),
                        cell(class="col-1", [textfield(:p1_failure, label="Fail", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:p1_strategic, label="Strat", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-3", [textfield(:p2_name, label="Project 2", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:p2_cost, label="Cost", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:p2_safety, label="Safety", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:p2_revenue, label="Rev/yr", type="number", filled=true, dense=true)]),
                        cell(class="col-1", [textfield(:p2_failure, label="Fail", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:p2_strategic, label="Strat", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-3", [textfield(:p3_name, label="Project 3", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:p3_cost, label="Cost", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:p3_safety, label="Safety", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:p3_revenue, label="Rev/yr", type="number", filled=true, dense=true)]),
                        cell(class="col-1", [textfield(:p3_failure, label="Fail", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:p3_strategic, label="Strat", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm", [
                        cell(class="col-3", [textfield(:p4_name, label="Project 4", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:p4_cost, label="Cost", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:p4_safety, label="Safety", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:p4_revenue, label="Rev/yr", type="number", filled=true, dense=true)]),
                        cell(class="col-1", [textfield(:p4_failure, label="Fail", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:p4_strategic, label="Strat", type="number", filled=true, dense=true)]),
                    ]),
                ])])
            ]),
        ]),

        # ── Charts ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-7 col-xs-12", [
                card([card_section([
                    plot(:score_data, layout=:score_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-5 col-xs-12", [
                card([card_section([
                    plot(:budget_data, layout=:budget_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Selected Projects ──────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Selected Projects (within budget)", class="q-mb-sm"),
                    quasar(:list, dense=true, [
                        template("", var"v-for"="(proj, i) in selected_projects", var":key"="i", [
                            item([
                                item_section(avatar=true, [q__icon(name="check_circle", color="green")]),
                                item_section([item_label("{{ proj }}")]),
                            ]),
                        ]),
                    ]),
                ])])
            ]),
        ]),
    ])
end
