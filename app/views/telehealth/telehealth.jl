"""
Telehealth ROI UI - multi-year return analysis for telehealth investments.
"""

function ui_telehealth(model)
    app_layout(model, "Telehealth ROI", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Telehealth ROI Analysis", class="q-mb-none"),
                p("Model financial returns from telehealth service investments", class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Calculate ROI", icon="trending_up", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ──────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("ROI", class="text-overline q-mb-none"),
                    h4("{{ roi_pct }}%", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Breakeven", class="text-overline q-mb-none"),
                    h4("{{ breakeven_months }} months", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Year 1 Net Benefit", class="text-overline q-mb-none"),
                    h4("\${{ (net_benefit_year1 / 1e3).toFixed(0) }}K", class="q-mb-none",
                       var":class"="net_benefit_year1 >= 0 ? 'text-green' : 'text-red'"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Transfer Savings", class="text-overline q-mb-none"),
                    h4("\${{ (avoided_transfer_savings / 1e3).toFixed(0) }}K", class="q-mb-none text-blue"),
                ])])
            ]),
        ]),

        # ── Inputs ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Service Line 1", class="q-mb-md"),
                    textfield(:svc1_name, label="Service Name", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:svc1_volume, label="Annual Volume", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:svc1_revenue, label="Revenue/Encounter (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:svc1_cost, label="Cost/Encounter (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:svc1_transfers_avoided, label="Transfers Avoided/Year", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:svc1_transfer_cost, label="Avg Transfer Cost (\$)", type="number", filled=true, dense=true),
                ]),
                card_section([
                    h6("Service Line 2", class="q-mb-md"),
                    textfield(:svc2_name, label="Service Name", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:svc2_volume, label="Annual Volume", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:svc2_revenue, label="Revenue/Encounter (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:svc2_cost, label="Cost/Encounter (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:svc2_transfers_avoided, label="Transfers Avoided/Year", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:svc2_transfer_cost, label="Avg Transfer Cost (\$)", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Investment Parameters", class="q-mb-md"),
                    textfield(:infrastructure_cost, label="Infrastructure Cost (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:annual_licensing, label="Annual Licensing (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:annual_staffing, label="Annual Staffing (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:broadband_upgrade, label="Broadband Upgrade (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:training_cost, label="Training Cost (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:projection_years, label="Projection Years", type="number", filled=true, dense=true),
                ])])
            ]),
        ]),

        # ── Chart ──────────────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:roi_chart_data, layout=:roi_chart_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
    ])
end
