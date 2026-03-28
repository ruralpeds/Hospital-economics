"""
Service Line P&L Analysis UI - revenue, cost, and margin by service line.
"""

function ui_service_line(model)
    app_layout(model, "Service Line P&L", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Service Line P&L Analysis", class="q-mb-none"),
                p("Evaluate contribution margin and profitability across hospital service lines",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Recalculate", icon="calculate", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── Summary KPIs ────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Total Contribution", class="text-overline q-mb-none"),
                    h4("\${{ (total_contribution / 1e6).toFixed(2) }}M", class="q-mb-none",
                       var":class" = "total_contribution >= 0 ? 'text-green' : 'text-red'"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Profitable Lines", class="text-overline q-mb-none"),
                    h4("{{ profitable_lines }} of 8", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Unprofitable Lines", class="text-overline q-mb-none"),
                    h4("{{ unprofitable_lines }}", class="q-mb-none text-red"),
                ])])
            ]),
        ]),

        # ── Input Table ─────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Revenue by Service Line", class="q-mb-md"),
                    textfield(:sl_ed_revenue, label="ED Revenue", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:sl_inpatient_revenue, label="Inpatient Revenue", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:sl_outpatient_revenue, label="Outpatient Revenue", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:sl_surgical_revenue, label="Surgical Revenue", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:sl_imaging_revenue, label="Imaging Revenue", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:sl_lab_revenue, label="Lab Revenue", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:sl_pharmacy_revenue, label="Pharmacy Revenue", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:sl_rehab_revenue, label="Rehab Revenue", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Cost by Service Line", class="q-mb-md"),
                    textfield(:sl_ed_cost, label="ED Cost", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:sl_inpatient_cost, label="Inpatient Cost", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:sl_outpatient_cost, label="Outpatient Cost", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:sl_surgical_cost, label="Surgical Cost", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:sl_imaging_cost, label="Imaging Cost", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:sl_lab_cost, label="Lab Cost", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:sl_pharmacy_cost, label="Pharmacy Cost", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:sl_rehab_cost, label="Rehab Cost", type="number", filled=true, dense=true),
                ])])
            ]),
        ]),

        # ── Charts ──────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:margin_bar_data, layout=:margin_bar_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:portfolio_chart_data, layout=:portfolio_chart_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Recommendations ─────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Recommendations", class="q-mb-md"),
                    card(var"v-for"="(rec, idx) in recommendations", key!="idx",
                        class="q-mb-sm", flat=true, bordered=true, [
                        card_section(class="q-pa-sm", [
                            badge("{{ rec.priority }}", var":color"="rec.priority === 'high' ? 'red' : 'orange'", class="q-mr-sm"),
                            strong("{{ rec.line }}"), span(" -- {{ rec.action }}"),
                        ])
                    ]),
                ])])
            ]),
        ]),
    ])
end
