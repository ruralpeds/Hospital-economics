"""
Revenue Variance Bridge UI — three-way decomposition into price, volume, and mix.
"""

function ui_revenue_variance(model)
    app_layout(model, "Revenue Variance Bridge", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Revenue Variance Bridge Analysis", class="q-mb-none"),
                p("Decompose revenue changes into price, volume, and mix components",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Analyze", icon="waterfall_chart", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ─────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Total Variance", class="text-overline q-mb-none"),
                    h4("{{ total_variance_str }}", class="q-mb-none text-primary"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Price Variance ({{ price_pct_str }})", class="text-overline q-mb-none"),
                    h5("{{ price_variance_str }}", class="q-mb-none text-blue"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Volume Variance ({{ volume_pct_str }})", class="text-overline q-mb-none"),
                    h5("{{ volume_variance_str }}", class="q-mb-none text-orange"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Mix Variance ({{ mix_pct_str }})", class="text-overline q-mb-none"),
                    h5("{{ mix_variance_str }}", class="q-mb-none text-purple"),
                ])])
            ]),
        ]),

        # ── Service Line Input Table ──────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Service Line Revenue Data", class="q-mb-md"),
                    p("Enter prior and current period data (leave Name blank to skip a row)", class="text-caption text-grey-7 q-mb-md"),

                    # Headers
                    row(class="q-mb-xs text-weight-bold text-grey-8", [
                        cell(class="col-md-2", [span("Service Line")]),
                        cell(class="col-md-2", [span("Prior Volume")]),
                        cell(class="col-md-3", [span("Current Volume")]),
                        cell(class="col-md-2", [span("Prior Price (\$)")]),
                        cell(class="col-md-3", [span("Current Price (\$)")]),
                    ]),

                    # Row 1
                    row(class="q-gutter-sm q-mb-sm items-center", [
                        cell(class="col-md-2", [textfield(:svc1_name, label="Name", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:svc1_prior_vol, label="Prior Vol", type="number", filled=true, dense=true)]),
                        cell(class="col-md-3", [textfield(:svc1_current_vol, label="Current Vol", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:svc1_prior_price, label="Prior Price", type="number", filled=true, dense=true)]),
                        cell(class="col-md-3", [textfield(:svc1_current_price, label="Current Price", type="number", filled=true, dense=true)]),
                    ]),
                    # Row 2
                    row(class="q-gutter-sm q-mb-sm items-center", [
                        cell(class="col-md-2", [textfield(:svc2_name, label="Name", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:svc2_prior_vol, label="Prior Vol", type="number", filled=true, dense=true)]),
                        cell(class="col-md-3", [textfield(:svc2_current_vol, label="Current Vol", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:svc2_prior_price, label="Prior Price", type="number", filled=true, dense=true)]),
                        cell(class="col-md-3", [textfield(:svc2_current_price, label="Current Price", type="number", filled=true, dense=true)]),
                    ]),
                    # Row 3
                    row(class="q-gutter-sm q-mb-sm items-center", [
                        cell(class="col-md-2", [textfield(:svc3_name, label="Name", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:svc3_prior_vol, label="Prior Vol", type="number", filled=true, dense=true)]),
                        cell(class="col-md-3", [textfield(:svc3_current_vol, label="Current Vol", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:svc3_prior_price, label="Prior Price", type="number", filled=true, dense=true)]),
                        cell(class="col-md-3", [textfield(:svc3_current_price, label="Current Price", type="number", filled=true, dense=true)]),
                    ]),
                    # Row 4
                    row(class="q-gutter-sm q-mb-sm items-center", [
                        cell(class="col-md-2", [textfield(:svc4_name, label="Name", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:svc4_prior_vol, label="Prior Vol", type="number", filled=true, dense=true)]),
                        cell(class="col-md-3", [textfield(:svc4_current_vol, label="Current Vol", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:svc4_prior_price, label="Prior Price", type="number", filled=true, dense=true)]),
                        cell(class="col-md-3", [textfield(:svc4_current_price, label="Current Price", type="number", filled=true, dense=true)]),
                    ]),
                    # Row 5
                    row(class="q-gutter-sm q-mb-sm items-center", [
                        cell(class="col-md-2", [textfield(:svc5_name, label="Name", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:svc5_prior_vol, label="Prior Vol", type="number", filled=true, dense=true)]),
                        cell(class="col-md-3", [textfield(:svc5_current_vol, label="Current Vol", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:svc5_prior_price, label="Prior Price", type="number", filled=true, dense=true)]),
                        cell(class="col-md-3", [textfield(:svc5_current_price, label="Current Price", type="number", filled=true, dense=true)]),
                    ]),
                    # Row 6
                    row(class="q-gutter-sm items-center", [
                        cell(class="col-md-2", [textfield(:svc6_name, label="Name", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:svc6_prior_vol, label="Prior Vol", type="number", filled=true, dense=true)]),
                        cell(class="col-md-3", [textfield(:svc6_current_vol, label="Current Vol", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:svc6_prior_price, label="Prior Price", type="number", filled=true, dense=true)]),
                        cell(class="col-md-3", [textfield(:svc6_current_price, label="Current Price", type="number", filled=true, dense=true)]),
                    ]),
                ])])
            ]),
        ]),

        # ── Waterfall Chart ───────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:waterfall_chart_data, layout=:waterfall_chart_layout,
                         config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Service Line Detail Chart ─────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:detail_chart_data, layout=:detail_chart_layout,
                         config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Variance Breakdown Table ──────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Service Line Variance Detail", class="q-mb-md"),
                    row(class="q-mb-xs text-weight-bold text-grey-8", [
                        cell(class="col-md-3", [span("Service Line")]),
                        cell(class="col-md-2", [span("Price Var")]),
                        cell(class="col-md-2", [span("Volume Var")]),
                        cell(class="col-md-2", [span("Mix Var")]),
                        cell(class="col-md-3", [span("Total Var")]),
                    ]),
                    Html.div(var"v-for"="(svc, idx) in service_details", var":key"="idx", [
                        row(class="q-py-xs", [
                            cell(class="col-md-3", [span("{{ svc.name }}", class="text-weight-bold")]),
                            cell(class="col-md-2", [
                                span("\${{ svc.price_var.toLocaleString() }}",
                                     var":class"="svc.price_var >= 0 ? 'text-green' : 'text-red'"),
                            ]),
                            cell(class="col-md-2", [
                                span("\${{ svc.volume_var.toLocaleString() }}",
                                     var":class"="svc.volume_var >= 0 ? 'text-green' : 'text-red'"),
                            ]),
                            cell(class="col-md-2", [
                                span("\${{ svc.mix_var.toLocaleString() }}",
                                     var":class"="svc.mix_var >= 0 ? 'text-green' : 'text-red'"),
                            ]),
                            cell(class="col-md-3", [
                                span("\${{ svc.total_var.toLocaleString() }}",
                                     class="text-weight-bold",
                                     var":class"="svc.total_var >= 0 ? 'text-green' : 'text-red'"),
                            ]),
                        ]),
                        separator(),
                    ]),
                ])])
            ]),
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
