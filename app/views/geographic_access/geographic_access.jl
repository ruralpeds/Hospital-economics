"""
Geographic Access UI - catchment analysis and drive-time modeling.
"""

function ui_geographic_access(model)
    app_layout(model, "Geographic Access", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Geographic Access Modeling", class="q-mb-none"),
                p("2SFCA catchment area and drive-time analysis for rural facilities", class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Analyze", icon="map", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ──────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Catchment Population", class="text-overline q-mb-none"),
                    h4("{{ catchment_population.toLocaleString() }}", class="q-mb-none text-blue"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Avg Drive Time", class="text-overline q-mb-none"),
                    h4("{{ avg_drive_time }} min", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Market Share", class="text-overline q-mb-none"),
                    h4("{{ (market_share * 100).toFixed(1) }}%", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Volume Estimate", class="text-overline q-mb-none"),
                    h4("{{ volume_estimate }}", class="q-mb-none text-purple"),
                ])])
            ]),
        ]),

        # ── Inputs ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    h6("Facility", class="q-mb-md"),
                    textfield(:facility_name, label="Name", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:facility_lat, label="Latitude", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:facility_lon, label="Longitude", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:facility_capacity, label="Capacity (relative)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:max_drive_minutes, label="Max Drive (min)", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-8 col-xs-12", [
                card([card_section([
                    h6("Population Centers", class="q-mb-md"),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-3", [textfield(:pop1_name, label="Town 1", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:pop1_lat, label="Lat", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:pop1_lon, label="Lon", type="number", filled=true, dense=true)]),
                        cell(class="col-3", [textfield(:pop1_population, label="Population", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:pop1_pct_over_65, label=">65%", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-3", [textfield(:pop2_name, label="Town 2", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:pop2_lat, label="Lat", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:pop2_lon, label="Lon", type="number", filled=true, dense=true)]),
                        cell(class="col-3", [textfield(:pop2_population, label="Population", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:pop2_pct_over_65, label=">65%", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm", [
                        cell(class="col-3", [textfield(:pop3_name, label="Town 3", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:pop3_lat, label="Lat", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:pop3_lon, label="Lon", type="number", filled=true, dense=true)]),
                        cell(class="col-3", [textfield(:pop3_population, label="Population", type="number", filled=true, dense=true)]),
                        cell(class="col-2", [textfield(:pop3_pct_over_65, label=">65%", type="number", filled=true, dense=true)]),
                    ]),
                ])])
            ]),
        ]),

        # ── Charts ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:access_chart_data, layout=:access_chart_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:drive_time_data, layout=:drive_time_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
    ])
end
