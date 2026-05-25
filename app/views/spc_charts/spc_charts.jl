"""
SPC Charts UI — Statistical Process Control with 11 chart types.
"""

function ui_spc_charts(model)
    app_layout(model, "SPC Control Charts", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Statistical Process Control Charts", class="q-mb-none"),
                p("11 SPC chart types: I-MR, p, u, c, np, Laney p'/u', g, t, CUSUM, EWMA",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Build Chart", icon="show_chart", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ─────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Center Line", class="text-overline q-mb-none"),
                    h4("{{ center_line_val }}", class="q-mb-none text-primary"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Upper Control Limit", class="text-overline q-mb-none"),
                    h6("{{ ucl_val }}", class="q-mb-none text-red"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Lower Control Limit", class="text-overline q-mb-none"),
                    h6("{{ lcl_val }}", class="q-mb-none text-red"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Signals Detected", class="text-overline q-mb-none"),
                    h4("{{ signals_count }}", class="q-mb-none",
                       var":class"="signals_count > 0 ? 'text-red' : 'text-green'"),
                ])])
            ]),
        ]),

        # ── Chart Type & Parameters ───────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    h6("Chart Type", class="q-mb-md"),
                    q__select(:chart_type, options=:chart_type_options,
                              label="Select SPC Chart", filled=true, dense=true,
                              var"emit-value"=true, var"map-options"=true, class="q-mb-sm"),
                    p("{{ chart_description }}", class="text-caption text-grey-7 q-mt-sm"),
                ])])
            ]),
            cell(class="col-md-8 col-xs-12", [
                card([card_section([
                    h6("Data Input", class="q-mb-md"),
                    q__input(:data_input, label="Values (comma-separated)",
                             type="textarea", filled=true, dense=true, class="q-mb-sm",
                             hint="Enter numeric values separated by commas"),
                    Html.div(var"v-show"="chart_type == 'p' || chart_type == 'u' || chart_type == 'laney_p' || chart_type == 'laney_u'", [
                        q__input(:sample_sizes_input, label="Sample Sizes / Units (comma-separated)",
                                 type="textarea", filled=true, dense=true, class="q-mb-sm",
                                 hint="One per data point — required for p, u, Laney charts"),
                    ]),
                    Html.div(var"v-show"="chart_type == 'np'", [
                        textfield(:np_sample_size, label="Fixed Sample Size (n)", type="number",
                                  filled=true, dense=true, class="q-mb-sm"),
                    ]),
                ])])
            ]),
        ]),

        # ── CUSUM / EWMA Parameters ──────────────────────────────
        Html.div(var"v-show"="chart_type == 'CUSUM'", [
            row(class="q-mb-lg", [
                cell(class="col-12", [
                    card([card_section([
                        h6("CUSUM Parameters", class="q-mb-md"),
                        row(class="q-gutter-md", [
                            cell(class="col-md-4", [
                                textfield(:cusum_target, label="Target (mu_0)", type="number",
                                          filled=true, dense=true),
                            ]),
                            cell(class="col-md-4", [
                                textfield(:cusum_k, label="Allowance k (sigma units)", type="number",
                                          filled=true, dense=true),
                            ]),
                            cell(class="col-md-4", [
                                textfield(:cusum_h, label="Decision Interval h (sigma units)", type="number",
                                          filled=true, dense=true),
                            ]),
                        ]),
                    ])])
                ]),
            ]),
        ]),

        Html.div(var"v-show"="chart_type == 'EWMA'", [
            row(class="q-mb-lg", [
                cell(class="col-12", [
                    card([card_section([
                        h6("EWMA Parameters", class="q-mb-md"),
                        row(class="q-gutter-md", [
                            cell(class="col-md-6", [
                                textfield(:ewma_lambda, label="Lambda (smoothing, 0-1)", type="number",
                                          filled=true, dense=true),
                            ]),
                            cell(class="col-md-6", [
                                textfield(:ewma_L, label="L (sigma multiplier)", type="number",
                                          filled=true, dense=true),
                            ]),
                        ]),
                    ])])
                ]),
            ]),
        ]),

        # ── Signal Status ─────────────────────────────────────────
        row(class="q-mb-md", [
            cell(class="col-12", [
                card(class="q-pa-sm", [card_section([
                    Html.div(class="text-subtitle1", [
                        q__icon(var":name"="signals_count > 0 ? 'warning' : 'check_circle'",
                                var":color"="signals_count > 0 ? 'red' : 'green'",
                                class="q-mr-sm"),
                        span("{{ signals_text }}"),
                    ]),
                ])])
            ]),
        ]),

        # ── Chart ─────────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:spc_chart_data, layout=:spc_chart_layout,
                         config="{ responsive: true }")
                ])])
            ]),
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
