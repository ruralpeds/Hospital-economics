"""
Cohort Risk Distribution Dashboard View
"""
function ui_cohort_risk(model)
    app_layout(model, "Cohort Risk Distribution", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Cohort Risk Distribution", class="q-mb-none"),
                p("Analyze risk score distribution and percentiles by aggregation level",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                textfield(:aggregation_level, label="Aggregation Level", placeholder="overall",
                          filled=true, dense=true, class="q-mr-sm"),
            ]),
            cell(class="col-auto", [
                btn("Recalculate", icon="refresh", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── Percentile KPI Cards ───────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center bg-blue-1", [
                    p("P10", class="text-overline q-mb-none"),
                    h4("{{ (p10 * 100).toFixed(0) }}%", class="q-mb-none text-weight-bold"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center bg-blue-1", [
                    p("P50", class="text-overline q-mb-none"),
                    h4("{{ (p50 * 100).toFixed(0) }}%", class="q-mb-none text-weight-bold"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center bg-blue-1", [
                    p("P90", class="text-overline q-mb-none"),
                    h4("{{ (p90 * 100).toFixed(0) }}%", class="q-mb-none text-weight-bold"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center bg-blue-1", [
                    p("Mean Risk", class="text-overline q-mb-none"),
                    h4("{{ (mean_risk * 100).toFixed(0) }}%", class="q-mb-none text-weight-bold"),
                ])])
            ]),
        ]),

        # ── Charts ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-lg-6 col-xs-12", [
                card([card_section([
                    plot(:percentile_chart, layout=:percentile_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-lg-6 col-xs-12", [
                card([card_section([
                    plot(:anomaly_distribution, layout=:anomaly_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),

        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
