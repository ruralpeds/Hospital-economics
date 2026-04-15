"""
Medicaid Supplemental Payments UI - DSH/UPL/SDP calculator with reform scenarios.
"""

function ui_medicaid_supplemental(model)
    app_layout(model, "Medicaid Supplemental", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Medicaid Supplemental Payments", class="q-mb-none"),
                p("DSH, UPL, and State Directed Payment calculations with reform modeling",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Calculate", icon="payments", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ──────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("DSH", class="text-overline q-mb-none"),
                    h5("\${{ (dsh_payment / 1e6).toFixed(2) }}M", class="q-mb-none text-blue"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("UPL", class="text-overline q-mb-none"),
                    h5("\${{ (upl_payment / 1e6).toFixed(2) }}M", class="q-mb-none text-teal"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("SDP", class="text-overline q-mb-none"),
                    h5("\${{ (sdp_payment / 1e6).toFixed(2) }}M", class="q-mb-none text-purple"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("Total", class="text-overline q-mb-none"),
                    h5("\${{ (total_supplemental / 1e6).toFixed(2) }}M", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("Shortfall", class="text-overline q-mb-none"),
                    h5("\${{ (net_medicaid_shortfall / 1e6).toFixed(2) }}M", class="q-mb-none text-red"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("Provider Tax", class="text-overline q-mb-none"),
                    h5("\${{ (provider_tax_cost / 1e6).toFixed(2) }}M", class="q-mb-none text-orange"),
                ])])
            ]),
        ]),

        # ── Inputs ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Hospital Financials", class="q-mb-md"),
                    textfield(:medicaid_costs, label="Medicaid Costs (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:medicaid_payments, label="Medicaid Payments (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:uncompensated_care_costs, label="Uncompensated Care (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:gross_patient_revenue, label="Gross Patient Revenue (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:total_operating_expenses, label="Total Operating Expenses (\$)", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Provider Settings", class="q-mb-md"),
                    q__select(:provider_class, options=:provider_class_options, label="Provider Class",
                              filled=true, dense=true, var"emit-value"=true, var"map-options"=true, class="q-mb-sm"),
                    toggle(:state_has_expansion, label="State Has Medicaid Expansion", class="q-mb-sm"),
                    textfield(:provider_tax_rate, label="Provider Tax Rate", type="number", filled=true, dense=true),
                ])])
            ]),
        ]),

        # ── Charts ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:payment_chart_data, layout=:payment_chart_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:reform_chart_data, layout=:reform_chart_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
    ])
end
