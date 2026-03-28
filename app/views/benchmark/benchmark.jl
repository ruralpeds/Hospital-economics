"""
Benchmarking Radar UI - radar chart with 50th/75th percentile overlays, metric cards.
"""

function ui_benchmark(model)
    app_layout(model, "Benchmarking Radar", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Benchmarking Radar", class="q-mb-none"),
                p("Compare your hospital's key metrics against peer percentiles",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Benchmark", icon="radar", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── Summary KPIs ────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Composite Score", class="text-overline q-mb-none"),
                    h4("{{ composite_score }}/100", class="q-mb-none",
                       var":class"="composite_score < 40 ? 'text-red' : composite_score < 60 ? 'text-orange' : 'text-green'"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Above Median", class="text-overline q-mb-none"),
                    h4("{{ metrics_above_median }} of 6", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Weakest Area", class="text-overline q-mb-none"),
                    h4("{{ weakest_area }}", class="q-mb-none text-red"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Strongest Area", class="text-overline q-mb-none"),
                    h4("{{ strongest_area }}", class="q-mb-none text-green"),
                ])])
            ]),
        ]),

        # ── Metric Inputs ───────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    h6("Your Metrics", class="q-mb-md"),
                    textfield(:metric_operating_margin, label="Operating Margin (%)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:metric_days_cash, label="Days Cash on Hand", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:metric_current_ratio, label="Current Ratio", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:metric_occupancy, label="Occupancy Rate (%)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:metric_fte_per_aob, label="FTE per AOB", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:metric_avg_age_plant, label="Avg Age of Plant (yrs)", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-8 col-xs-12", [
                card([card_section([
                    plot(:radar_chart_data, layout=:radar_chart_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Metric Detail Cards ─────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-2 col-sm-4 col-xs-6",
                var"v-for"="(m, idx) in metric_cards", key!="idx", [
                card(var":class"="m.status === 'below' ? 'bg-red-1' : 'bg-green-1'", [
                    card_section(class="text-center q-pa-sm", [
                        p("{{ m.name }}", class="text-overline q-mb-none"),
                        h5("{{ m.value }}{{ m.unit }}", class="q-mb-none"),
                        p("P50: {{ m.p50 }} | P75: {{ m.p75 }}", class="text-caption text-grey"),
                    ])
                ])
            ]),
        ]),
    ])
end
