"""
Physician Compensation UI — wRVU productivity, outlier detection, cohort analysis.
"""

function ui_physician_comp(model)
    app_layout(model, "Physician Compensation", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Physician Compensation Analysis", class="q-mb-none"),
                p("Evaluate comp/wRVU productivity, flag outliers, and compare cohorts",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Analyze", icon="analytics", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ─────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Total Physicians", class="text-overline q-mb-none"),
                    h4("{{ total_physicians }}", class="q-mb-none text-primary"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Outliers Flagged", class="text-overline q-mb-none"),
                    h4("{{ total_outliers }}", class="q-mb-none",
                       var":class"="total_outliers > 0 ? 'text-red' : 'text-green'"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Avg Comp/wRVU", class="text-overline q-mb-none"),
                    h4("{{ avg_comp_per_wrvu }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Avg Productivity", class="text-overline q-mb-none"),
                    h4("{{ avg_productivity_pct }}", class="q-mb-none"),
                ])])
            ]),
        ]),

        # ── Physician Input Rows ──────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Physician Profiles", class="q-mb-md"),
                    p("Enter physician data below (leave Name blank to skip a row)", class="text-caption text-grey-7 q-mb-md"),

                    # Row 1
                    row(class="q-gutter-sm q-mb-sm items-center", [
                        cell(class="col-md-2", [textfield(:phys1_name, label="Name", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys1_specialty, label="Specialty", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys1_wrvu, label="wRVU Actual", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys1_benchmark, label="wRVU Benchmark", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys1_salary, label="Base Salary", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys1_bonus_pct, label="Bonus %", type="number", filled=true, dense=true, hint="0.05 = 5%")]),
                    ]),
                    # Row 2
                    row(class="q-gutter-sm q-mb-sm items-center", [
                        cell(class="col-md-2", [textfield(:phys2_name, label="Name", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys2_specialty, label="Specialty", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys2_wrvu, label="wRVU Actual", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys2_benchmark, label="wRVU Benchmark", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys2_salary, label="Base Salary", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys2_bonus_pct, label="Bonus %", type="number", filled=true, dense=true)]),
                    ]),
                    # Row 3
                    row(class="q-gutter-sm q-mb-sm items-center", [
                        cell(class="col-md-2", [textfield(:phys3_name, label="Name", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys3_specialty, label="Specialty", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys3_wrvu, label="wRVU Actual", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys3_benchmark, label="wRVU Benchmark", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys3_salary, label="Base Salary", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys3_bonus_pct, label="Bonus %", type="number", filled=true, dense=true)]),
                    ]),
                    # Row 4
                    row(class="q-gutter-sm q-mb-sm items-center", [
                        cell(class="col-md-2", [textfield(:phys4_name, label="Name", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys4_specialty, label="Specialty", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys4_wrvu, label="wRVU Actual", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys4_benchmark, label="wRVU Benchmark", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys4_salary, label="Base Salary", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys4_bonus_pct, label="Bonus %", type="number", filled=true, dense=true)]),
                    ]),
                    # Row 5
                    row(class="q-gutter-sm q-mb-sm items-center", [
                        cell(class="col-md-2", [textfield(:phys5_name, label="Name", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys5_specialty, label="Specialty", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys5_wrvu, label="wRVU Actual", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys5_benchmark, label="wRVU Benchmark", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys5_salary, label="Base Salary", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys5_bonus_pct, label="Bonus %", type="number", filled=true, dense=true)]),
                    ]),
                    # Row 6
                    row(class="q-gutter-sm items-center", [
                        cell(class="col-md-2", [textfield(:phys6_name, label="Name", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys6_specialty, label="Specialty", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys6_wrvu, label="wRVU Actual", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys6_benchmark, label="wRVU Benchmark", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys6_salary, label="Base Salary", type="number", filled=true, dense=true)]),
                        cell(class="col-md-2", [textfield(:phys6_bonus_pct, label="Bonus %", type="number", filled=true, dense=true)]),
                    ]),
                ])])
            ]),
        ]),

        # ── Results Table ─────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Compensation Results", class="q-mb-md"),
                    Html.div(var"v-for"="(row, idx) in results_table", var":key"="idx", [
                        row(class="q-py-xs items-center", [
                            cell(class="col-md-2", [
                                Html.div([
                                    span("{{ row.name }}", class="text-weight-bold"),
                                    q__badge(var"v-if"="row.outlier", label="OUTLIER", color="red",
                                             class="q-ml-sm"),
                                ]),
                            ]),
                            cell(class="col-md-2", [span("{{ row.specialty }}", class="text-grey-8")]),
                            cell(class="col-md-2", [span("\${{ row.total_comp.toLocaleString() }}")]),
                            cell(class="col-md-2", [span("\${{ row.comp_per_wrvu }}/wRVU")]),
                            cell(class="col-md-2", [span("{{ row.productivity_pct }}%")]),
                            cell(class="col-md-2", [span("{{ row.benchmark_ratio }}x benchmark")]),
                        ]),
                        separator(),
                    ]),
                ])])
            ]),
        ]),

        # ── Cohort Summary ────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            Html.div(var"v-for"="(cohort, idx) in cohort_summaries", var":key"="idx",
                     class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section([
                    h6("{{ cohort.specialty }}", class="q-mb-sm"),
                    Html.div(class="q-gutter-xs", [
                        Html.div([span("Physicians: ", class="text-weight-bold"), span("{{ cohort.n_physicians }}")]),
                        Html.div([span("Mean Comp: ", class="text-weight-bold"), span("\${{ cohort.mean_total_comp.toLocaleString() }}")]),
                        Html.div([span("Mean \$/wRVU: ", class="text-weight-bold"), span("\${{ cohort.mean_comp_per_wrvu }}")]),
                        Html.div([span("Mean Productivity: ", class="text-weight-bold"), span("{{ cohort.mean_productivity_pct }}%")]),
                        Html.div([span("Total wRVU: ", class="text-weight-bold"), span("{{ cohort.total_wrvu.toLocaleString() }}")]),
                        Html.div([span("Outliers: ", class="text-weight-bold"),
                                  span("{{ cohort.n_outliers }}",
                                       var":class"="cohort.n_outliers > 0 ? 'text-red text-weight-bold' : 'text-green'")]),
                    ]),
                ])])
            ]),
        ]),

        # ── Chart ─────────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:comp_chart_data, layout=:comp_chart_layout,
                         config="{ responsive: true }")
                ])])
            ]),
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
