"""
    ma_risk.jl — DSL UI for Medicare Advantage risk adjustment (A-06)

Renders member upload, RAF calculation, cohort analysis, and risk distribution.
"""
function ui_ma_risk(model)
    app_layout(model, "M&A Risk", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Medicare Advantage Risk Adjustment (HCC v28)", class="q-mb-none"),
                p("Member-level RAF scoring and cohort risk analysis",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Calculate RAF", icon="calculate", color="primary",
                    @click("calculate_raf_btn"),
                    :disable = :is_calculating),
            ]),
        ]),

        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-xs-12 col-sm-6", [
                card([card_section(class="bg-blue-1", [
                    h6("Data Input", class="q-mb-md"),
                    separator(),
                    btn("Load Sample Cohort (50 members)", color="primary", class="full-width q-mb-md",
                        @click("load_sample_data_btn")),
                    text("-- OR --", class="text-center q-my-md"),
                    textfield(:upload_csv, label="Upload CSV (member_id, age, sex, diagnoses)",
                              placeholder="CSV format: M001,65,M,HCC001|HCC009",
                              filled=true, dense=true, class="q-mb-sm"),
                ])])
            ]),

            cell(class="col-xs-12 col-sm-6", [
                card([card_section(class="bg-green-1", [
                    h6("Capitation Parameters", class="q-mb-md"),
                    separator(),
                    textfield(:annual_capitation, label="Annual Capitation per Member (\$)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    text("Benchmark RAF = 1.0; higher RAF = higher revenue per member",
                         class="text-caption text-grey-7"),
                ])])
            ]),
        ]),

        # Error display
        @if(!isempty(:error_message))
            row([
                cell(class="col-xs-12", [
                    card([card_section(class="bg-red-2 text-red-9", [
                        icon("warning", class="q-mr-md"),
                        text(:error_message),
                    ])])
                ])
            ])
        @end

        @if(:is_calculating)
            row([
                cell(class="col-xs-12", [
                    linear_progress(value=0.5, color="primary")
                ])
            ])
        @end

        # Results section
        @if(:member_count > 0)
            # Summary cards
            row(class="q-mb-lg q-gutter-md", [
                cell(class="col-xs-12 col-sm-3", [
                    card([card_section(class="text-center bg-blue-1", [
                        text("Member Count", class="text-caption text-grey-7"),
                        heading(
                            @text(:cohort_stats, format(x) = get(x, "member_count", 0)),
                            class="text-h4 text-primary q-my-md"
                        ),
                    ])])
                ]),
                cell(class="col-xs-12 col-sm-3", [
                    card([card_section(class="text-center bg-green-1", [
                        text("Mean RAF", class="text-caption text-grey-7"),
                        heading(
                            @text(:cohort_stats, format(x) = Printf.@sprintf("%.3f", get(x, "mean_raf", 0.0))),
                            class="text-h4 text-positive q-my-md"
                        ),
                    ])])
                ]),
                cell(class="col-xs-12 col-sm-3", [
                    card([card_section(class="text-center bg-amber-1", [
                        text("Std Dev", class="text-caption text-grey-7"),
                        heading(
                            @text(:cohort_stats, format(x) = Printf.@sprintf("%.3f", get(x, "std_raf", 0.0))),
                            class="text-h5 q-my-md"
                        ),
                    ])])
                ]),
                cell(class="col-xs-12 col-sm-3", [
                    card([card_section(class="text-center bg-orange-1", [
                        text("Capitation Impact (\$)", class="text-caption text-grey-7"),
                        heading(
                            @text(:cohort_stats, format(x) = Printf.@sprintf(
                                "%.0f", get(get(x, "capitation_impact", Dict()), "difference", 0.0)
                            )),
                            class="text-h5 q-my-md"
                        ),
                    ])])
                ]),
            ])

            # Risk band distribution pie chart
            row(class="q-mb-lg q-gutter-md", [
                cell(class="col-xs-12 col-sm-6", [
                    plot(
                        type="pie",
                        data=[
                            attr(
                                labels=:risk_band_chart_labels,
                                values=:risk_band_chart_values,
                                type="pie"
                            )
                        ],
                        layout=attr(title="Risk Band Distribution")
                    )
                ]),

                cell(class="col-xs-12 col-sm-6", [
                    plot(
                        type="histogram",
                        data=[
                            attr(
                                x=:raf_distribution_data,
                                type="histogram",
                                marker=attr(color="rgba(70, 130, 180, 0.7)")
                            )
                        ],
                        layout=attr(
                            title="RAF Distribution (Histogram)",
                            xaxis=attr(title="Member RAF"),
                            yaxis=attr(title="Member Count")
                        )
                    )
                ]),
            ])

            # Member-level table
            row(class="q-mb-lg", [
                cell(class="col-xs-12", [
                    h6("Member-Level RAF Scores", class="q-mb-md"),
                    table(
                        :member_rafs,
                        table_columns=[
                            (name="member_id", label="Member ID", field="member_id", align="left"),
                            (name="age", label="Age", field="age", align="center"),
                            (name="sex", label="Sex", field="sex", align="center"),
                            (name="diagnoses_count", label="# Diagnoses", field="diagnoses_count", align="center"),
                            (name="hcc_count", label="# HCCs", field="hcc_count", align="center"),
                            (name="member_raf", label="RAF", field="member_raf", align="right"),
                            (name="risk_band", label="Risk Band", field="risk_band", align="center")
                        ],
                        flat=true,
                        bordered=true,
                        dense=true,
                        pagination=attr(rowsPerPage=25)
                    )
                ])
            ])

            # Clear button
            row([
                cell(class="col-xs-12", [
                    btn("Clear All Data", color="negative", flat=true, class="full-width",
                        @click("clear_data_btn")),
                ])
            ])
        @end

        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
