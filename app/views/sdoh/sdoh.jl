"""
SDOH Integration UI - social determinants impact on hospital financial performance.
"""

function ui_sdoh(model)
    app_layout(model, "SDOH Integration", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Social Determinants of Health Integration", class="q-mb-none"),
                p("Assess how community SDOH factors impact hospital finances", class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Analyze", icon="people", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ──────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Composite Risk", class="text-overline q-mb-none"),
                    h4("{{ (composite_risk_score * 100).toFixed(0) }}", class="q-mb-none"),
                    badge("{{ risk_tier.toUpperCase() }}",
                          var":color"="risk_tier==='critical'?'red':risk_tier==='high'?'orange':risk_tier==='moderate'?'yellow-8':'green'"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Net Margin Impact", class="text-overline q-mb-none"),
                    h4("\${{ (net_margin_impact / 1e3).toFixed(0) }}K", class="q-mb-none",
                       var":class"="net_margin_impact >= 0 ? 'text-green' : 'text-red'"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("ED Utilization", class="text-overline q-mb-none"),
                    h4("{{ ed_utilization_multiplier.toFixed(2) }}x", class="q-mb-none text-orange"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Telehealth Viability", class="text-overline q-mb-none"),
                    h4("{{ (telehealth_viability * 100).toFixed(0) }}%", class="q-mb-none",
                       var":class"="telehealth_viability >= 0.7 ? 'text-green' : 'text-orange'"),
                ])])
            ]),
        ]),

        # ── Inputs ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Community Profile", class="q-mb-md"),
                    slider(:svi_score, label=true, var":label-value"="'SVI: ' + svi_score.toFixed(2)",
                           var":min"="0", var":max"="1", var":step"="0.01", class="q-mb-sm"),
                    textfield(:adi_national_rank, label="ADI National Rank (1-100)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    slider(:food_desert_pct, label=true, var":label-value"="'Food Desert: ' + (food_desert_pct*100).toFixed(0) + '%'",
                           var":min"="0", var":max"="1", var":step"="0.01", class="q-mb-sm"),
                    slider(:broadband_pct, label=true, var":label-value"="'Broadband: ' + (broadband_pct*100).toFixed(0) + '%'",
                           var":min"="0", var":max"="1", var":step"="0.01", class="q-mb-sm"),
                    toggle(:transportation_desert, label="Transportation Desert", class="q-mb-sm"),
                    slider(:health_literacy_score, label=true, var":label-value"="'Health Literacy: ' + health_literacy_score.toFixed(2)",
                           var":min"="0", var":max"="1", var":step"="0.01", class="q-mb-sm"),
                    slider(:uninsured_rate, label=true, var":label-value"="'Uninsured: ' + (uninsured_rate*100).toFixed(0) + '%'",
                           var":min"="0", var":max"="0.5", var":step"="0.01", class="q-mb-sm"),
                    slider(:poverty_rate, label=true, var":label-value"="'Poverty: ' + (poverty_rate*100).toFixed(0) + '%'",
                           var":min"="0", var":max"="0.6", var":step"="0.01"),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Hospital Financials", class="q-mb-md"),
                    textfield(:base_revenue, label="Base Revenue (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:base_expenses, label="Base Expenses (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:median_household_income, label="Median Household Income (\$)", type="number", filled=true, dense=true),
                ])])
            ]),
        ]),

        # ── Charts ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:radar_data, layout=:radar_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:impact_data, layout=:impact_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
    ])
end
