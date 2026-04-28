"""
Results Explorer UI - interactive charts, scenario comparison, and export.
"""

function ui_results(model)
    app_layout(model, "Results Explorer", [
        # ── Header & Controls ────────────────────────────────────────────
        row(class="q-mb-md items-center", [
            cell(class="col-md-4 col-xs-12", [
                h5("Results Explorer", class="q-mb-none"),
            ]),
            cell(class="col-md-3 col-xs-6", [
                q__select(:selected_simulation, options=:simulation_list,
                    label="Simulation", filled=true, dense=true,
                    var"emit-value"=true, var"map-options"=true)
            ]),
            cell(class="col-md-3 col-xs-6", [
                row(class="items-center q-gutter-sm", [
                    toggle(:show_comparison, label="Compare"),
                    q__select(var"v-if"="show_comparison",
                        fieldname=:comparison_simulation, options=:simulation_list,
                        label="Compare to", filled=true, dense=true,
                        var"emit-value"=true, var"map-options"=true, class="col"),
                ])
            ]),
            cell(class="col-md-2 col-xs-12 text-right", [
                btn_dropdown(label="Export", icon="download", color="primary", [
                    q__list([
                        item(clickable=true, @click("export_format='csv'; trigger_export=true"), [
                            item_section("CSV"),
                        ]),
                        item(clickable=true, @click("export_format='json'; trigger_export=true"), [
                            item_section("JSON"),
                        ]),
                        item(clickable=true, @click("export_format='pdf'; trigger_export=true"), [
                            item_section("PDF Report"),
                        ]),
                    ])
                ]),
            ]),
        ]),

        # ── Tab Navigation ───────────────────────────────────────────────
        tabs(:active_tab, dense=true, class="q-mb-md bg-grey-2", [
            tab(name="summary", label="Summary", icon="dashboard"),
            tab(name="projections", label="Projections", icon="timeline"),
            tab(name="distribution", label="Distribution", icon="bar_chart"),
            tab(name="sensitivity", label="Sensitivity", icon="tune"),
            tab(name="table", label="Data Table", icon="table_chart"),
        ]),

        # ── Tab: Summary ─────────────────────────────────────────────────
        tab_panels(:active_tab, animated=true, [
            tab_panel(name="summary", [
                # KPI Summary Cards
                row(class="q-mb-lg q-gutter-md", [
                    cell(class="col-md-3 col-sm-6 col-xs-12", [
                        card(class="kpi-card", [
                            card_section([
                                p("Mean Operating Margin", class="text-overline q-mb-none"),
                                h4(var":class"="mean_operating_margin < 0 ? 'text-red' : 'text-green'",
                                   "{{ (mean_operating_margin * 100).toFixed(1) }}%", class="q-mb-none"),
                                p("Median: {{ (median_operating_margin * 100).toFixed(1) }}%",
                                  class="text-caption text-grey"),
                            ])
                        ])
                    ]),
                    cell(class="col-md-3 col-sm-6 col-xs-12", [
                        card(class="kpi-card", [
                            card_section([
                                p("P(Positive Margin)", class="text-overline q-mb-none"),
                                h4("{{ (prob_positive_margin * 100).toFixed(0) }}%", class="q-mb-none"),
                                linear_progress(var":value"="prob_positive_margin", color="green",
                                    size="8px", rounded=true, class="q-mt-sm"),
                            ])
                        ])
                    ]),
                    cell(class="col-md-3 col-sm-6 col-xs-12", [
                        card(class="kpi-card", [
                            card_section([
                                p("Closure Risk Probability", class="text-overline q-mb-none"),
                                h4(var":class"="prob_closure_risk > 0.15 ? 'text-red' : 'text-green'",
                                   "{{ (prob_closure_risk * 100).toFixed(0) }}%", class="q-mb-none"),
                                linear_progress(var":value"="prob_closure_risk", color="red",
                                    size="8px", rounded=true, class="q-mt-sm"),
                            ])
                        ])
                    ]),
                    cell(class="col-md-3 col-sm-6 col-xs-12", [
                        card(class="kpi-card", [
                            card_section([
                                p("10-Year NPV", class="text-overline q-mb-none"),
                                h4(var":class"="npv_10yr < 0 ? 'text-red' : 'text-green'",
                                   "\${{ (npv_10yr / 1e6).toFixed(1) }}M", class="q-mb-none"),
                            ])
                        ])
                    ]),
                ]),

                # Additional summary metrics
                row(class="q-mb-lg q-gutter-md", [
                    cell(class="col-md-2 col-sm-4 col-xs-6", [
                        card(class="kpi-card-sm", [card_section(class="q-pa-sm", [
                            p("Breakeven Year", class="text-overline q-mb-none text-caption"),
                            h6("{{ breakeven_year }}", class="q-mb-none"),
                        ])])
                    ]),
                    cell(class="col-md-2 col-sm-4 col-xs-6", [
                        card(class="kpi-card-sm", [card_section(class="q-pa-sm", [
                            p("P10 Margin", class="text-overline q-mb-none text-caption"),
                            h6("{{ (p10_margin * 100).toFixed(1) }}%", class="q-mb-none text-red"),
                        ])])
                    ]),
                    cell(class="col-md-2 col-sm-4 col-xs-6", [
                        card(class="kpi-card-sm", [card_section(class="q-pa-sm", [
                            p("P90 Margin", class="text-overline q-mb-none text-caption"),
                            h6("{{ (p90_margin * 100).toFixed(1) }}%", class="q-mb-none text-green"),
                        ])])
                    ]),
                    cell(class="col-md-2 col-sm-4 col-xs-6", [
                        card(class="kpi-card-sm", [card_section(class="q-pa-sm", [
                            p("IRR", class="text-overline q-mb-none text-caption"),
                            h6("{{ (irr * 100).toFixed(1) }}%", class="q-mb-none"),
                        ])])
                    ]),
                    cell(class="col-md-2 col-sm-4 col-xs-6", [
                        card(class="kpi-card-sm", [card_section(class="q-pa-sm", [
                            p("Mean Days Cash (Y5)", class="text-overline q-mb-none text-caption"),
                            h6("{{ mean_days_cash }}", class="q-mb-none"),
                        ])])
                    ]),
                    cell(class="col-md-2 col-sm-4 col-xs-6", [
                        card(class="kpi-card-sm", [card_section(class="q-pa-sm", [
                            p("Payback Period", class="text-overline q-mb-none text-caption"),
                            h6("{{ payback_period.toFixed(1) }} yrs", class="q-mb-none"),
                        ])])
                    ]),
                ]),

                # Comparison panel
                card(var"v-if"="show_comparison", class="q-mb-md bg-blue-1", [
                    card_section([
                        h6("Scenario Comparison", class="q-mb-md"),
                        row(class="q-gutter-md text-center", [
                            cell(class="col-md-3", [
                                p("Comparison Mean Margin", class="text-overline"),
                                h5("{{ (comp_mean_margin * 100).toFixed(1) }}%", class="text-green"),
                                p("vs {{ (mean_operating_margin * 100).toFixed(1) }}%", class="text-caption"),
                            ]),
                            cell(class="col-md-3", [
                                p("Comparison NPV", class="text-overline"),
                                h5("\${{ (comp_npv / 1e6).toFixed(1) }}M", class="text-green"),
                            ]),
                            cell(class="col-md-3", [
                                p("P(Positive Margin)", class="text-overline"),
                                h5("{{ (comp_prob_positive * 100).toFixed(0) }}%"),
                            ]),
                            cell(class="col-md-3", [
                                p("Closure Risk", class="text-overline"),
                                h5("{{ (comp_prob_closure * 100).toFixed(0) }}%"),
                            ]),
                        ]),
                    ])
                ]),
            ]),

            # ── Tab: Projections ─────────────────────────────────────────
            tab_panel(name="projections", [
                row(class="q-gutter-md", [
                    cell(class="col-12", [
                        card([card_section([
                            toggle(:show_confidence_bands, label="Show confidence bands"),
                            plot(:margin_fan_data, layout=:margin_fan_layout,
                                 config="{ responsive: true }")
                        ])])
                    ]),
                    cell(class="col-12", [
                        card([card_section([
                            plot(:rev_exp_projection_data, layout=:rev_exp_layout,
                                 config="{ responsive: true }")
                        ])])
                    ]),
                ]),
            ]),

            # ── Tab: Distribution ────────────────────────────────────────
            tab_panel(name="distribution", [
                card([card_section([
                    plot(:margin_histogram_data, layout=:margin_histogram_layout,
                         config="{ responsive: true }")
                ])])
            ]),

            # ── Tab: Sensitivity ─────────────────────────────────────────
            tab_panel(name="sensitivity", [
                card([card_section([
                    plot(:tornado_data, layout=:tornado_layout,
                         config="{ responsive: true }")
                ])])
            ]),

            # ── Tab: Data Table ──────────────────────────────────────────
            tab_panel(name="table", [
                card([card_section([
                    h6("Annual Projection Data", class="q-mb-md"),
                    q__table(rows=:projection_rows, flat=true, dense=true,
                        var"row-key"="year",
                        columns="""[
                            {name:'year', label:'Year', field:'year', align:'center', sortable:true},
                            {name:'revenue', label:'Revenue', field:'revenue', align:'right',
                             format: val => '\\$' + (val/1e6).toFixed(2) + 'M'},
                            {name:'expenses', label:'Expenses', field:'expenses', align:'right',
                             format: val => '\\$' + (val/1e6).toFixed(2) + 'M'},
                            {name:'margin', label:'Margin', field:'margin', align:'right',
                             format: val => (val*100).toFixed(1) + '%'},
                            {name:'cash_flow', label:'Cash Flow', field:'cash_flow', align:'right',
                             format: val => '\\$' + (val/1e3).toFixed(0) + 'K'},
                            {name:'cum_cash', label:'Cumulative Cash', field:'cum_cash', align:'right',
                             format: val => '\\$' + (val/1e6).toFixed(2) + 'M'}
                        ]""")
                ])])
            ]),
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
