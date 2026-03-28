"""
340B Drug Pricing Impact UI - savings analysis, policy risk scenarios.
"""

function ui_program_340b(model)
    app_layout(model, "340B Drug Pricing Impact", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("340B Drug Pricing Impact", class="q-mb-none"),
                p("Model drug savings, contract pharmacy economics, and legislative risk",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Calculate Impact", icon="calculate", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── Impact KPIs ─────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Net 340B Benefit", class="text-overline q-mb-none"),
                    h4("\${{ (net_benefit / 1e3).toFixed(0) }}K", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Margin Impact", class="text-overline q-mb-none"),
                    h4("+{{ margin_impact_pct.toFixed(1) }}%", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Contract Pharmacy Savings", class="text-overline q-mb-none"),
                    h4("\${{ (contract_pharmacy_savings / 1e3).toFixed(0) }}K", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Savings/Rx", class="text-overline q-mb-none"),
                    h4("\${{ savings_per_prescription.toFixed(2) }}", class="q-mb-none"),
                ])])
            ]),
        ]),

        # ── Input Sliders ───────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("340B Parameters", class="q-mb-md"),
                    textfield(:drug_spend, label="Total Drug Spend (\$)", type="number", filled=true, dense=true, class="q-mb-md"),
                    p("Discount Rate: {{ (discount_rate * 100).toFixed(0) }}%", class="q-mb-none"),
                    slider(:discount_rate, min=0.10, max=0.60, step=0.01, label=true, class="q-mb-md"),
                    p("Contract Pharmacy %: {{ (contract_pharmacy_pct * 100).toFixed(0) }}%", class="q-mb-none"),
                    slider(:contract_pharmacy_pct, min=0.0, max=1.0, step=0.05, label=true, class="q-mb-md"),
                    textfield(:admin_cost, label="Admin Cost (\$)", type="number", filled=true, dense=true, class="q-mb-md"),
                    toggle(:manufacturer_restrictions, label="Manufacturer Restrictions Active"),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:impact_chart_data, layout=:impact_chart_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Scenario Comparison ─────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:scenario_chart_data, layout=:scenario_chart_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Policy Risk Scenarios", class="q-mb-md"),
                    card(var"v-for"="(s, idx) in policy_risk_scenarios", key!="idx",
                        class="q-mb-sm", flat=true, bordered=true, [
                        card_section(class="q-pa-sm", [
                            strong("{{ s.scenario }}"),
                            badge("{{ s.probability }}", color="primary", class="q-ml-sm"),
                            p("\${{ (s.net_benefit / 1000).toFixed(0) }}K -- {{ s.description }}",
                              class="q-mb-none text-caption"),
                        ])
                    ]),
                ])])
            ]),
        ]),
    ])
end
