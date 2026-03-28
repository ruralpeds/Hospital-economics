"""
Debt Capacity Calculator UI - DSCR chart, capital structure doughnut.
"""

function ui_debt_capacity(model)
    app_layout(model, "Debt Capacity Calculator", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Debt Capacity Calculator", class="q-mb-none"),
                p("Determine maximum borrowing capacity based on DSCR and capital structure",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Calculate", icon="account_balance", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── KPIs ────────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Current DSCR", class="text-overline q-mb-none"),
                    h5("{{ current_dscr.toFixed(2) }}x", class="q-mb-none",
                       var":class"="current_dscr < 1.25 ? 'text-red' : 'text-green'"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Max Borrowing", class="text-overline q-mb-none"),
                    h5("\${{ (max_new_borrowing / 1e6).toFixed(1) }}M", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Incremental Capacity", class="text-overline q-mb-none"),
                    h5("\${{ (incremental_capacity / 1e6).toFixed(1) }}M", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Debt/Capitalization", class="text-overline q-mb-none"),
                    h5("{{ (debt_to_cap_current * 100).toFixed(0) }}%", class="q-mb-none"),
                    p("Max: {{ (debt_to_cap_max * 100).toFixed(0) }}%", class="text-caption text-grey"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Max Debt Service", class="text-overline q-mb-none"),
                    h5("\${{ (max_annual_debt_service / 1e3).toFixed(0) }}K/yr", class="q-mb-none"),
                ])])
            ]),
        ]),

        # ── Inputs ──────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    h6("Financial Inputs", class="q-mb-md"),
                    textfield(:ebitda, label="EBITDA (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:current_debt, label="Current Debt (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:annual_debt_service, label="Annual Debt Service (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    p("Interest Rate: {{ (interest_rate * 100).toFixed(1) }}%", class="q-mb-none"),
                    slider(:interest_rate, min=0.03, max=0.10, step=0.005, label=true, class="q-mb-md"),
                    textfield(:loan_term_years, label="Loan Term (Years)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    p("Target DSCR: {{ target_dscr.toFixed(2) }}x", class="q-mb-none"),
                    slider(:target_dscr, min=1.0, max=2.5, step=0.05, label=true),
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    plot(:dscr_curve_data, layout=:dscr_curve_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    plot(:capital_structure_data, layout=:capital_structure_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
    ])
end
