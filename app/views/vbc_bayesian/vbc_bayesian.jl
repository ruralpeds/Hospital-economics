"""
    vbc_bayesian.jl — DSL UI for VBC Bayesian scenario modeling (A-07)

Renders scenario inputs, posterior sampling, prior/posterior visualization, and scenario ranking.
"""
function ui_vbc_bayesian(model)
    app_layout(model, "VBC Bayesian", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("VBC Scenario Modeling with Bayesian Uncertainty", class="q-mb-none"),
                p("Fit priors, sample posteriors, and compare value-based care scenarios",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Sample Posterior", icon="science", color="primary",
                    @click("sample_posterior_btn"),
                    :disable = :is_calculating),
            ]),
        ]),

        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-xs-12 col-sm-6", [
                card([card_section(class="bg-blue-1", [
                    h6("Scenario Configuration", class="q-mb-md"),
                    separator(),
                    textfield(:scenario_name, label="Scenario Name",
                              placeholder="e.g., ACO Partnership 2024",
                              filled=true, dense=true, class="q-mb-sm"),
                    select(:scenario_type, label="Scenario Type",
                           options=[
                               "ccm" => "Chronic Care Management (CCM)",
                               "aco" => "Accountable Care Organization (ACO)",
                               "mip" => "Medicaid Incentive Program (MIP)",
                               "hip" => "Health Insurance Provider (HIP)"
                           ],
                           filled=true, dense=true, class="q-mb-sm"),
                    textfield(:shared_savings_rate, label="Shared Savings Rate (%)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:risk_bearing, label="Risk Bearing (%)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                ])])
            ]),

            cell(class="col-xs-12 col-sm-6", [
                card([card_section(class="bg-green-1", [
                    h6("Historical Savings Data", class="q-mb-md"),
                    separator(),
                    text("Provide historical annual savings to establish prior distribution",
                         class="text-caption text-grey-7 q-mb-md"),
                    textfield(:new_historical_value, label="Annual Savings (\$)", type="number",
                              placeholder="e.g., 150000",
                              filled=true, dense=true, class="q-mb-sm"),
                    btn("Add Data Point", color="primary", class="full-width",
                        @click("add_historical_datapoint_btn")),
                    @if(!isempty(:historical_savings_json))
                        text("Data points: " * @text(:historical_savings_json),
                             class="text-caption q-mt-md")
                    @end
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
        @if(:posterior_mean > 0)
            # Summary cards
            row(class="q-mb-lg q-gutter-md", [
                cell(class="col-xs-12 col-sm-3", [
                    card([card_section(class="text-center bg-blue-1", [
                        text("Posterior Mean", class="text-caption text-grey-7"),
                        heading(
                            @text(:posterior_mean; format(x) = Printf.@sprintf("\$%.0f", x)),
                            class="text-h4 text-primary q-my-md"
                        ),
                    ])])
                ]),
                cell(class="col-xs-12 col-sm-3", [
                    card([card_section(class="text-center bg-green-1", [
                        text("Posterior Std Dev", class="text-caption text-grey-7"),
                        heading(
                            @text(:posterior_std; format(x) = Printf.@sprintf("\$%.0f", x)),
                            class="text-h5 q-my-md"
                        ),
                    ])])
                ]),
                cell(class="col-xs-12 col-sm-3", [
                    card([card_section(class="text-center bg-amber-1", [
                        text("95% Credible Interval", class="text-caption text-grey-7"),
                        heading(
                            @text(:ci_lower; format(x) = Printf.@sprintf("[%.0f, ", x)) *
                            @text(:ci_upper; format(x) = Printf.@sprintf("%.0f]", x)),
                            class="text-h6 q-my-md"
                        ),
                    ])])
                ]),
                cell(class="col-xs-12 col-sm-3", [
                    card([card_section(class="text-center", [
                        text("P(Positive Savings)", class="text-caption text-grey-7"),
                        heading(
                            @text(:prob_positive; format(x) = Printf.@sprintf("%.1f%%", x * 100)),
                            class="text-h4 q-my-md",
                            :style = "color: " * Dict(
                                "green" => "rgb(76, 175, 80)",
                                "yellow" => "rgb(255, 193, 7)",
                                "red" => "rgb(244, 67, 54)"
                            )[get(@data(:prob_positive_badge_color), "green")]
                        ),
                    ])])
                ]),
            ])

            # Prior vs Posterior visualization
            row(class="q-mb-lg", [
                cell(class="col-xs-12", [
                    plot(
                        type="scatter",
                        layout=attr(
                            title="Prior vs Posterior Distribution",
                            xaxis=attr(title="Annual Savings (\$)"),
                            yaxis=attr(title="Density")
                        ),
                        data=[
                            attr(
                                x=:prior_vs_posterior_x,
                                y=:prior_vs_posterior_prior,
                                mode="lines",
                                name="Prior",
                                line=attr(color="rgb(100, 100, 100)", dash="dash")
                            ),
                            attr(
                                x=:prior_vs_posterior_x,
                                y=:prior_vs_posterior_posterior,
                                mode="lines",
                                name="Posterior",
                                line=attr(color="rgb(70, 130, 180)", width=3)
                            )
                        ]
                    )
                ])
            ])

            # Clear button
            row([
                cell(class="col-xs-12", [
                    btn("Clear Results", color="negative", flat=true, class="full-width",
                        @click("clear_data_btn")),
                ])
            ])
        @end

        # Scenario comparison section
        row([
            cell(class="col-xs-12 q-mt-lg", [
                toggle(:compare_mode, label="Compare Multiple Scenarios", class="q-mb-md"),
            ])
        ])

        @if(:compare_mode)
            row(class="q-mb-lg", [
                cell(class="col-xs-12", [
                    card([card_section(class="bg-blue-1", [
                        h6("Scenario Comparison", class="q-mb-md"),
                        text("Paste JSON array of scenarios to compare", class="text-caption text-grey-7 q-mb-md"),
                        textarea(:scenarios_json, label="Scenarios (JSON)", rows=6,
                                 filled=true, dense=true, class="q-mb-sm"),
                        btn("Compare Scenarios", color="primary", class="full-width",
                            @click("compare_scenarios_btn")),
                    ])])
                ])
            ])

            @if(!isempty(:comparison_results))
                row(class="q-mb-lg", [
                    cell(class="col-xs-12", [
                        plot(
                            type="bar",
                            data=[
                                attr(
                                    x=:comparison_chart_names,
                                    y=:comparison_chart_savings,
                                    error_y=attr(
                                        type="data",
                                        symmetric=false,
                                        array=(:comparison_chart_ci_upper .- :comparison_chart_savings),
                                        arrayminus=(:comparison_chart_savings .- :comparison_chart_ci_lower)
                                    ),
                                    type="bar",
                                    marker=attr(color="rgb(70, 130, 180)")
                                )
                            ],
                            layout=attr(
                                title="Scenario Comparison (with 95% CI)",
                                xaxis=attr(title="Scenario"),
                                yaxis=attr(title="Expected Savings (\$)")
                            )
                        )
                    ])
                ])

                row(class="q-mb-lg", [
                    cell(class="col-xs-12", [
                        table(
                            :comparison_results,
                            table_columns=[
                                (name="rank", label="Rank", field="rank", align="center"),
                                (name="scenario_name", label="Scenario", field="scenario_name", align="left"),
                                (name="posterior_mean", label="Expected Savings", field="posterior_mean", align="right"),
                                (name="posterior_std", label="Std Dev", field="posterior_std", align="right"),
                                (name="prob_positive", label="P(Positive)", field="prob_positive", align="right")
                            ],
                            flat=true,
                            bordered=true
                        )
                    ])
                ])
            @end
        @end

        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
