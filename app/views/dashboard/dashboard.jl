"""
Dashboard UI - Main financial overview with KPI cards, charts, and alerts.
Uses Stipple HTML DSL and StipplePlotly for interactive visualizations.
"""

function ui_dashboard(model)
    app_layout(model, "Financial Dashboard", [
        # ── Alert Banners ────────────────────────────────────────────────
        section(class="q-mb-md", [
            quasar(:banner, var"v-for"="(alert, idx) in alerts", key! = "idx",
                class="q-mb-sm", dense=true, rounded=true,
                var"inline-actions" = true,
                var":class" = """alert.severity === 'error' ? 'bg-red-1 text-red-9' :
                                 alert.severity === 'warning' ? 'bg-orange-1 text-orange-9' :
                                 'bg-blue-1 text-blue-9'""",
                [
                    template("", var"v-slot:avatar" = true, [
                        q__icon(var":name" = """alert.severity === 'error' ? 'error' :
                                               alert.severity === 'warning' ? 'warning' : 'info'""",
                                var":color" = """alert.severity === 'error' ? 'red' :
                                                 alert.severity === 'warning' ? 'orange' : 'blue'""")
                    ]),
                    span("{{ alert.message }}"),
                ]
            )
        ]),

        # ── Hospital Selector & Controls ─────────────────────────────────
        row(class="q-mb-md items-center q-gutter-md", [
            cell(class="col-4", [
                Stipple.select(:selected_hospital_id,
                    options = :hospital_options,
                    label = "Select Hospital",
                    filled = true, dense = true,
                    var"emit-value" = true, var"map-options" = true)
            ]),
            cell(class="col-2", [
                q__select(:benchmark_comparison,
                    options = [:state_average => "State Average",
                               :national_average => "National Average",
                               :top_quartile => "Top Quartile"],
                    label = "Benchmark", filled = true, dense = true,
                    var"emit-value" = true, var"map-options" = true)
            ]),
            cell(class="col-2", [
                textfield(:projection_months, label = "Projection Months",
                    type = "number", filled = true, dense = true)
            ]),
            cell(class="col-auto", [
                btn("Refresh", icon = "refresh", color = "primary",
                    @click(:refresh_data), flat = true)
            ]),
        ]),

        # ── Hospital Header ──────────────────────────────────────────────
        row(class="q-mb-md", [
            cell(class="col-12", [
                h5("{{ hospital_name }}", class="q-mb-none"),
                p("{{ hospital_type }} | {{ hospital_beds }} beds | {{ hospital_state }}",
                  class="text-grey-7"),
            ])
        ]),

        # ── KPI Cards Row 1: Financial ───────────────────────────────────
        row(class="q-mb-md q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card(class="kpi-card", [
                    card_section([
                        p("Operating Margin", class="text-overline q-mb-none"),
                        h4(class="q-mb-none", var":class" = "operating_margin < 0 ? 'text-red' : 'text-green'", [
                            span("{{ (operating_margin * 100).toFixed(1) }}%")
                        ]),
                        p("{{ operating_margin_trend }}", class="text-caption text-grey"),
                    ])
                ])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card(class="kpi-card", [
                    card_section([
                        p("Total Margin", class="text-overline q-mb-none"),
                        h4(class="q-mb-none", var":class" = "total_margin < 0 ? 'text-red' : 'text-green'", [
                            span("{{ (total_margin * 100).toFixed(1) }}%")
                        ]),
                    ])
                ])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card(class="kpi-card", [
                    card_section([
                        p("Net Patient Revenue", class="text-overline q-mb-none"),
                        h4("\${{ (net_patient_revenue / 1e6).toFixed(1) }}M", class="q-mb-none"),
                    ])
                ])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card(class="kpi-card", [
                    card_section([
                        p("Days Cash on Hand", class="text-overline q-mb-none"),
                        h4("{{ days_cash_on_hand }}", class="q-mb-none",
                           var":class" = "days_cash_on_hand < 60 ? 'text-orange' : 'text-green'"),
                        p(var":class" = "days_cash_on_hand < 30 ? 'text-red text-caption' : 'text-caption text-grey'",
                          "{{ days_cash_on_hand < 30 ? 'CRITICAL' : days_cash_on_hand < 60 ? 'Below threshold' : 'Healthy' }}"),
                    ])
                ])
            ]),
        ]),

        # ── KPI Cards Row 2: Operations ──────────────────────────────────
        row(class="q-mb-md q-gutter-md", [
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [
                    card_section(class="q-pa-sm", [
                        p("Current Ratio", class="text-overline q-mb-none text-caption"),
                        h6("{{ current_ratio.toFixed(2) }}", class="q-mb-none"),
                    ])
                ])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [
                    card_section(class="q-pa-sm", [
                        p("Debt/Capital", class="text-overline q-mb-none text-caption"),
                        h6("{{ (debt_to_capitalization * 100).toFixed(0) }}%", class="q-mb-none"),
                    ])
                ])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [
                    card_section(class="q-pa-sm", [
                        p("Cost/Adj Discharge", class="text-overline q-mb-none text-caption"),
                        h6("\${{ cost_per_adjusted_discharge.toLocaleString() }}", class="q-mb-none"),
                    ])
                ])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [
                    card_section(class="q-pa-sm", [
                        p("Case Mix Index", class="text-overline q-mb-none text-caption"),
                        h6("{{ case_mix_index.toFixed(2) }}", class="q-mb-none"),
                    ])
                ])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [
                    card_section(class="q-pa-sm", [
                        p("FTE/AOB", class="text-overline q-mb-none text-caption"),
                        h6("{{ fte_per_aob.toFixed(1) }}", class="q-mb-none"),
                    ])
                ])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [
                    card_section(class="q-pa-sm", [
                        p("Avg Age of Plant", class="text-overline q-mb-none text-caption"),
                        h6("{{ average_age_of_plant.toFixed(1) }} yrs", class="q-mb-none"),
                    ])
                ])
            ]),
        ]),

        # ── KPI Cards Row 3: Volume ──────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [
                    card_section(class="q-pa-sm", [
                        p("Avg Daily Census", class="text-overline q-mb-none text-caption"),
                        h6("{{ avg_daily_census.toFixed(1) }}", class="q-mb-none"),
                    ])
                ])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [
                    card_section(class="q-pa-sm", [
                        p("Occupancy", class="text-overline q-mb-none text-caption"),
                        h6("{{ (occupancy_rate * 100).toFixed(1) }}%", class="q-mb-none"),
                    ])
                ])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [
                    card_section(class="q-pa-sm", [
                        p("ED Visits/Year", class="text-overline q-mb-none text-caption"),
                        h6("{{ ed_visits_annual.toLocaleString() }}", class="q-mb-none"),
                    ])
                ])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [
                    card_section(class="q-pa-sm", [
                        p("Outpatient %", class="text-overline q-mb-none text-caption"),
                        h6("{{ (outpatient_revenue_pct * 100).toFixed(0) }}%", class="q-mb-none"),
                    ])
                ])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [
                    card_section(class="q-pa-sm", [
                        p("Bad Debt", class="text-overline q-mb-none text-caption"),
                        h6("{{ (bad_debt_pct * 100).toFixed(1) }}%", class="q-mb-none"),
                    ])
                ])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="kpi-card-sm", [
                    card_section(class="q-pa-sm", [
                        p("Vacancy Rate", class="text-overline q-mb-none text-caption"),
                        h6("{{ (vacancy_rate * 100).toFixed(1) }}%", class="q-mb-none",
                           var":class" = "vacancy_rate > 0.10 ? 'text-red' : ''"),
                    ])
                ])
            ]),
        ]),

        # ── Charts ───────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([
                    card_section([
                        plot(:margin_trend_data, layout = :margin_trend_layout,
                             config = "{ responsive: true }")
                    ])
                ])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([
                    card_section([
                        plot(:revenue_expense_data, layout = :revenue_expense_layout,
                             config = "{ responsive: true }")
                    ])
                ])
            ]),
        ]),

        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([
                    card_section([
                        plot(:volume_chart_data, layout = :volume_chart_layout,
                             config = "{ responsive: true }")
                    ])
                ])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([
                    card_section([
                        plot(:payer_mix_data, layout = :payer_mix_layout,
                             config = "{ responsive: true }")
                    ])
                ])
            ]),
        ]),

        # ── Benchmark Comparison Table ───────────────────────────────────
        row(var"v-if" = "show_benchmarks", class="q-mb-lg", [
            cell(class="col-12", [
                card([
                    card_section([
                        h6("Benchmark Comparison", class="q-mb-md"),
                        table(class="q-table", [
                            thead([
                                tr([
                                    th("Metric"),
                                    th("Your Hospital"),
                                    th("{{ benchmark_comparison.replace('_', ' ') }}"),
                                    th("Variance"),
                                ])
                            ]),
                            tbody([
                                tr(var"v-for" = "(label, idx) in benchmark_labels", key! = "idx", [
                                    td("{{ label }}"),
                                    td("{{ benchmark_hospital_values[idx] }}"),
                                    td("{{ benchmark_peer_values[idx] }}"),
                                    td(var":class" = """(benchmark_hospital_values[idx] - benchmark_peer_values[idx]) < 0
                                        ? 'text-red' : 'text-green'""",
                                       "{{ (benchmark_hospital_values[idx] - benchmark_peer_values[idx]).toFixed(1) }}"),
                                ])
                            ]),
                        ])
                    ])
                ])
            ])
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
