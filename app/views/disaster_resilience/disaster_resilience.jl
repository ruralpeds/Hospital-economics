"""
Disaster / Climate Resilience UI - vulnerability scoring and stress testing.
"""

function ui_disaster_resilience(model)
    app_layout(model, "Disaster Resilience", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Disaster & Climate Resilience Assessment", class="q-mb-none"),
                p("Vulnerability scoring, financial exposure, and stress testing", class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Assess", icon="emergency", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ──────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Resilience Score", class="text-overline q-mb-none"),
                    h4("{{ resilience_score.toFixed(0) }}%", class="q-mb-none",
                       var":class"="resilience_score >= 70 ? 'text-green' : resilience_score >= 50 ? 'text-orange' : 'text-red'"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Financial Exposure", class="text-overline q-mb-none"),
                    h4("\${{ (financial_exposure / 1e6).toFixed(1) }}M", class="q-mb-none text-red"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Interruption Days", class="text-overline q-mb-none"),
                    h4("{{ interruption_days.toFixed(0) }}", class="q-mb-none text-orange"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Insurance Gap", class="text-overline q-mb-none"),
                    h4("\${{ (insurance_gap / 1e3).toFixed(0) }}K", class="q-mb-none text-red"),
                ])])
            ]),
        ]),

        # ── Inputs ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    h6("Hazard Profile", class="q-mb-md"),
                    textfield(:fema_risk_score, label="FEMA Risk Score (0-1)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    quasar(:select, var"v-model"=:flood_zone, options=:flood_options,
                           label="Flood Zone", filled=true, dense=true, class="q-mb-sm", var"emit-value"=true, var"map-options"=true),
                    quasar(:select, var"v-model"=:wildfire_risk, options=:wildfire_options,
                           label="Wildfire Risk", filled=true, dense=true, class="q-mb-sm", var"emit-value"=true, var"map-options"=true),
                    toggle(:hurricane_zone, label="Hurricane Zone"),
                    toggle(:earthquake_zone, label="Earthquake Zone"),
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    h6("Preparedness", class="q-mb-md"),
                    textfield(:days_generator_fuel, label="Generator Fuel (Days)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    toggle(:has_helipad, label="Has Helipad"),
                    textfield(:surge_bed_capacity, label="Surge Bed Capacity", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:supply_chain_redundancy, label="Supply Redundancy (0-1)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:insurance_coverage_pct, label="Insurance Coverage %", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    h6("Financials", class="q-mb-md"),
                    textfield(:annual_revenue, label="Annual Revenue (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:annual_expenses, label="Annual Expenses (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:cash_reserves, label="Cash Reserves (\$)", type="number", filled=true, dense=true),
                ])])
            ]),
        ]),

        # ── Recommendations ────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Recommendations", class="q-mb-sm"),
                    quasar(:list, dense=true, [
                        template("", var"v-for"="(rec, i) in recommendations", var":key"="i", [
                            item([
                                item_section(avatar=true, [q__icon(name="warning", color="orange")]),
                                item_section([item_label("{{ rec }}")]),
                            ]),
                        ]),
                    ]),
                ])])
            ]),
        ]),

        # ── Charts ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:stress_data, layout=:stress_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:vuln_data, layout=:vuln_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
