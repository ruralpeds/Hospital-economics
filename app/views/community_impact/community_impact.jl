"""
Community Economic Impact UI - impact cards, closure devastation gauge.
"""

function ui_community_impact(model)
    app_layout(model, "Community Economic Impact", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Community Economic Impact", class="q-mb-none"),
                p("Quantify the hospital's economic footprint and closure consequences",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Calculate Impact", icon="location_city", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── Impact KPIs ─────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Total Impact", class="text-overline q-mb-none"),
                    h5("\${{ (total_economic_impact / 1e6).toFixed(1) }}M", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Direct Impact", class="text-overline q-mb-none"),
                    h5("\${{ (direct_impact / 1e6).toFixed(1) }}M", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Indirect Impact", class="text-overline q-mb-none"),
                    h5("\${{ (indirect_impact / 1e6).toFixed(1) }}M", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Jobs Supported", class="text-overline q-mb-none"),
                    h5("{{ jobs_supported }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Impact/Capita", class="text-overline q-mb-none"),
                    h5("\${{ impact_per_capita.toLocaleString() }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("% County Employment", class="text-overline q-mb-none"),
                    h5("{{ (pct_county_employment * 100).toFixed(1) }}%", class="q-mb-none"),
                ])])
            ]),
        ]),

        # ── Inputs and Breakdown Chart ──────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    h6("Community Parameters", class="q-mb-md"),
                    textfield(:annual_payroll, label="Annual Payroll (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:employee_count, label="Employee Count", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:local_purchasing, label="Local Purchasing (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    p("Economic Multiplier: {{ economic_multiplier.toFixed(1) }}x", class="q-mb-none"),
                    slider(:economic_multiplier, min=1.0, max=3.0, step=0.1, label=true, class="q-mb-md"),
                    textfield(:county_population, label="County Population", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:median_household_income, label="Median Household Income (\$)", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    plot(:impact_breakdown_data, layout=:impact_breakdown_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    plot(:closure_gauge_data, layout=:closure_gauge_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Closure Devastation Cards ───────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card(class="bg-red-1", [card_section([
                    h6("If This Hospital Closes...", class="q-mb-md text-red"),
                    row(class="q-gutter-md", [
                        cell(class="col-md-2 col-sm-4 col-xs-6", [
                            p("Jobs Lost", class="text-overline q-mb-none"),
                            h5("{{ closure_job_loss }}", class="text-red q-mb-none"),
                        ]),
                        cell(class="col-md-2 col-sm-4 col-xs-6", [
                            p("Income Lost", class="text-overline q-mb-none"),
                            h5("\${{ (closure_income_loss / 1e6).toFixed(1) }}M", class="text-red q-mb-none"),
                        ]),
                        cell(class="col-md-2 col-sm-4 col-xs-6", [
                            p("Population Decline", class="text-overline q-mb-none"),
                            h5("{{ (closure_population_decline_pct * 100).toFixed(1) }}%", class="text-red q-mb-none"),
                        ]),
                        cell(class="col-md-2 col-sm-4 col-xs-6", [
                            p("Property Value Loss", class="text-overline q-mb-none"),
                            h5("{{ (closure_property_value_decline * 100).toFixed(0) }}%", class="text-red q-mb-none"),
                        ]),
                        cell(class="col-md-2 col-sm-4 col-xs-6", [
                            p("Nearest ER", class="text-overline q-mb-none"),
                            h5("{{ closure_nearest_er_miles }} mi", class="text-red q-mb-none"),
                        ]),
                        cell(class="col-md-2 col-sm-12", [
                            p("Mortality Impact", class="text-overline q-mb-none"),
                            p("{{ closure_mortality_impact }}", class="text-red text-caption"),
                        ]),
                    ]),
                ])])
            ]),
        ]),
    ])
end
