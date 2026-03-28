"""
Workforce RVU Analysis UI - provider comparison table, benchmark bars.
"""

function ui_workforce_rvu(model)
    app_layout(model, "Workforce RVU Analysis", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Workforce RVU Analysis", class="q-mb-none"),
                p("Compare provider wRVU production and cost efficiency against benchmarks",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Analyze", icon="assessment", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── Summary KPIs ────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Total wRVUs", class="text-overline q-mb-none"),
                    h4("{{ total_wrvus.toLocaleString() }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Avg Cost/wRVU", class="text-overline q-mb-none"),
                    h4("\${{ avg_cost_per_wrvu.toFixed(2) }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Total Compensation", class="text-overline q-mb-none"),
                    h4("\${{ (total_compensation / 1e6).toFixed(2) }}M", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Benchmark Cost/wRVU", class="text-overline q-mb-none"),
                    h4("\${{ benchmark_median_cost.toFixed(2) }}", class="q-mb-none text-grey"),
                ])])
            ]),
        ]),

        # ── Provider Inputs ─────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Provider Data", class="q-mb-md"),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-4", [textfield(:prov1_name, label="Provider 1 Name", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:prov1_wrvus, label="wRVUs", type="number", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:prov1_comp, label="Compensation (\$)", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-4", [textfield(:prov2_name, label="Provider 2 Name", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:prov2_wrvus, label="wRVUs", type="number", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:prov2_comp, label="Compensation (\$)", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-4", [textfield(:prov3_name, label="Provider 3 Name", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:prov3_wrvus, label="wRVUs", type="number", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:prov3_comp, label="Compensation (\$)", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-4", [textfield(:prov4_name, label="Provider 4 Name", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:prov4_wrvus, label="wRVUs", type="number", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:prov4_comp, label="Compensation (\$)", type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm", [
                        cell(class="col-4", [textfield(:prov5_name, label="Provider 5 Name", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:prov5_wrvus, label="wRVUs", type="number", filled=true, dense=true)]),
                        cell(class="col-4", [textfield(:prov5_comp, label="Compensation (\$)", type="number", filled=true, dense=true)]),
                    ]),
                ])])
            ]),
        ]),

        # ── Charts ──────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:wrvu_comparison_data, layout=:wrvu_comparison_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:cost_wrvu_data, layout=:cost_wrvu_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
    ])
end
