"""
Policy Impact Simulator UI - toggle switches, stacked impact chart.
"""

function ui_policy_impact(model)
    app_layout(model, "Policy Impact Simulator", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Policy Impact Simulator", class="q-mb-none"),
                p("Toggle federal and state policy scenarios to see revenue and margin effects",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Simulate", icon="policy", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── Impact KPIs ─────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Year 1 Revenue Impact", class="text-overline q-mb-none"),
                    h4("\${{ (total_revenue_impact_yr1 / 1e3).toFixed(0) }}K", class="q-mb-none",
                       var":class"="total_revenue_impact_yr1 < 0 ? 'text-red' : 'text-green'"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Margin Change", class="text-overline q-mb-none"),
                    h4("{{ (total_margin_change * 100).toFixed(1) }}%", class="q-mb-none",
                       var":class"="total_margin_change < 0 ? 'text-red' : 'text-green'"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Net 5-Year Impact", class="text-overline q-mb-none"),
                    h4("\${{ (net_5yr_impact / 1e6).toFixed(1) }}M", class="q-mb-none",
                       var":class"="net_5yr_impact < 0 ? 'text-red' : 'text-green'"),
                ])])
            ]),
        ]),

        # ── Toggle Switches & Charts ────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-xs-12", [
                card([card_section([
                    h6("Policy Scenarios", class="q-mb-md"),
                    toggle(:sequestration, label="Medicare Sequestration (2%)", class="q-mb-sm",
                           color="red"),
                    toggle(:bad_debt_reduction, label="Bad Debt Reduction Program", class="q-mb-sm",
                           color="green"),
                    toggle(:ptc_expansion, label="PTC/DSH Expansion", class="q-mb-sm",
                           color="green"),
                    toggle(:medicaid_expansion, label="Medicaid Expansion", class="q-mb-sm",
                           color="green"),
                    toggle(:ma_growth, label="Medicare Advantage Growth", class="q-mb-sm",
                           color="red"),
                    toggle(:rural_health_redesign, label="Rural Health Redesign", class="q-mb-md",
                           color="green"),
                    textfield(:base_revenue, label="Base Revenue (\$)", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-5 col-xs-12", [
                card([card_section([
                    plot(:stacked_5yr_data, layout=:stacked_5yr_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    plot(:impact_summary_data, layout=:impact_summary_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
    ])
end
