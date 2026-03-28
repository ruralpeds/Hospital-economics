"""
Community Benefit UI - IRS Schedule H valuation with AHA benchmarking.
"""

function ui_community_benefit(model)
    app_layout(model, "Community Benefit", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Community Benefit Valuation", class="q-mb-none"),
                p("IRS Schedule H community benefit vs. tax exemption analysis", class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Calculate", icon="volunteer_activism", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ──────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Total Benefit", class="text-overline q-mb-none"),
                    h4("\${{ (total_community_benefit / 1e6).toFixed(1) }}M", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("% of Expenses", class="text-overline q-mb-none"),
                    h4("{{ (benefit_as_pct * 100).toFixed(1) }}%", class="q-mb-none",
                       var":class"="benefit_as_pct >= 0.076 ? 'text-green' : 'text-orange'"),
                    p("National median: 7.6%", class="text-caption text-grey"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Meets AHA Standard", class="text-overline q-mb-none"),
                    h4("{{ meets_aha_standard ? 'Yes' : 'No' }}", class="q-mb-none",
                       var":class"="meets_aha_standard ? 'text-green' : 'text-red'"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Percentile", class="text-overline q-mb-none"),
                    h4("{{ percentile_estimate }}th", class="q-mb-none text-blue"),
                    badge("{{ rating.replace('_', ' ').toUpperCase() }}",
                          var":color"="rating==='exemplary'?'green':rating==='above_average'?'blue':rating==='below_average'?'orange':'red'"),
                ])])
            ]),
        ]),

        # ── Inputs ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Benefit Categories (Schedule H)", class="q-mb-md"),
                    textfield(:charity_care_costs, label="Charity Care at Cost (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:medicaid_shortfall, label="Medicaid Shortfall (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:community_health_services, label="Community Health Services (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:health_professions_education, label="Health Professions Education (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:subsidized_services_cost, label="Subsidized Services (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:cash_contributions, label="Cash & In-Kind (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:community_building, label="Community Building (\$)", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Hospital & Tax Parameters", class="q-mb-md"),
                    textfield(:total_expenses, label="Total Operating Expenses (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:assessed_value, label="Property Assessed Value (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:tax_rate, label="Corporate Tax Rate", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:property_tax_rate, label="Property Tax Rate", type="number", filled=true, dense=true),
                ])])
            ]),
        ]),

        # ── Charts ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:category_data, layout=:category_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:comparison_data, layout=:comparison_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
    ])
end
