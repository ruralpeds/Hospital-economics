"""
    vbc_bayesian.jl — DSL UI for VBC Bayesian scenario modeling (A-07)

Renders scenario inputs, posterior sampling, prior/posterior visualization, and scenario ranking.
"""
function ui_vbc_bayesian()
    page(
        model = @current,
        partial = true,
        [
            heading("VBC Scenario Modeling with Bayesian Uncertainty", class="text-h4 q-mb-md")

            row(
                cell(class="col-xs-12 col-sm-6",
                    card(
                        card_section(
                            class="bg-blue-1",
                            [
                                heading("Scenario Configuration", class="text-h6 q-mb-md")
                                separator()

                                textfield(
                                    :scenario_name,
                                    label="Scenario Name",
                                    placeholder="e.g., ACO Partnership 2024",
                                    class="full-width q-mb-md"
                                )

                                select(
                                    :scenario_type,
                                    label="Scenario Type",
                                    options=[
                                        "ccm" => "Chronic Care Management (CCM)",
                                        "aco" => "Accountable Care Organization (ACO)",
                                        "mip" => "Medicaid Incentive Program (MIP)",
                                        "hip" => "Health Insurance Provider (HIP)"
                                    ],
                                    class="full-width q-mb-md"
                                )

                                textfield(
                                    :shared_savings_rate,
                                    label="Shared Savings Rate (%)",
                                    type="number",
                                    step=0.01,
                                    class="full-width q-mb-md"
                                )

                                textfield(
                                    :risk_bearing,
                                    label="Risk Bearing (%)",
                                    type="number",
                                    step=0.01,
                                    class="full-width"
                                )
                            ]
                        )
                    )
                ),

                cell(class="col-xs-12 col-sm-6",
                    card(
                        card_section(
                            class="bg-green-1",
                            [
                                heading("Historical Savings Data", class="text-h6 q-mb-md")
                                separator()

                                text(
                                    "Provide historical annual savings to establish prior distribution",
                                    class="text-caption text-grey-7 q-mb-md"
                                )

                                textfield(
                                    :new_historical_value,
                                    label="Annual Savings ($)",
                                    type="number",
                                    placeholder="e.g., 150000",
                                    class="full-width q-mb-md"
                                )

                                button(
                                    "Add Data Point",
                                    @click("add_historical_datapoint_btn"),
                                    color="primary",
                                    class="full-width"
                                )

                                @if(!isempty(:historical_savings_json))
                                    text(
                                        "Data points: " * @text(:historical_savings_json),
                                        class="text-caption q-mt-md"
                                    )
                                @end
                            ]
                        )
                    )
                )
            )

            # Error display
            @if(!isempty(:error_message))
                row(
                    cell(class="col-xs-12",
                        card(
                            card_section(
                                class="bg-red-2 text-red-9",
                                [
                                    icon("warning", class="q-mr-md")
                                    text(:error_message)
                                ]
                            )
                        )
                    )
                )
            @end

            # Sample button
            row(
                cell(class="col-xs-12 col-sm-3 q-offset-sm-9",
                    button(
                        "Sample Posterior",
                        @click("sample_posterior_btn"),
                        color="primary",
                        size="lg",
                        class="full-width",
                        :disable = :is_calculating
                    )
                )
            )

            @if(:is_calculating)
                row(
                    cell(class="col-xs-12",
                        linear_progress(value=0.5, color="primary")
                    )
                )
            @end

            # Results section
            @if(:posterior_mean > 0)
                heading("Posterior Analysis", class="text-h5 q-mt-lg q-mb-md")

                # Summary cards
                row(
                    cell(class="col-xs-12 col-sm-3",
                        card(
                            card_section(
                                class="text-center bg-blue-1",
                                [
                                    text("Posterior Mean", class="text-caption text-grey-7")
                                    heading(
                                        @text(:posterior_mean; format(x) = Printf.@sprintf("$%.0f", x)),
                                        class="text-h4 text-primary q-my-md"
                                    )
                                ]
                            )
                        )
                    ),

                    cell(class="col-xs-12 col-sm-3",
                        card(
                            card_section(
                                class="text-center bg-green-1",
                                [
                                    text("Posterior Std Dev", class="text-caption text-grey-7")
                                    heading(
                                        @text(:posterior_std; format(x) = Printf.@sprintf("$%.0f", x)),
                                        class="text-h5 q-my-md"
                                    )
                                ]
                            )
                        )
                    ),

                    cell(class="col-xs-12 col-sm-3",
                        card(
                            card_section(
                                class="text-center bg-amber-1",
                                [
                                    text("95% Credible Interval", class="text-caption text-grey-7")
                                    heading(
                                        @text(:ci_lower; format(x) = Printf.@sprintf("[%.0f, ", x)) *
                                        @text(:ci_upper; format(x) = Printf.@sprintf("%.0f]", x)),
                                        class="text-h6 q-my-md"
                                    )
                                ]
                            )
                        )
                    ),

                    cell(class="col-xs-12 col-sm-3",
                        card(
                            card_section(
                                class="text-center",
                                [
                                    text("P(Positive Savings)", class="text-caption text-grey-7")
                                    heading(
                                        @text(:prob_positive; format(x) = Printf.@sprintf("%.1f%%", x * 100)),
                                        class="text-h4 q-my-md",
                                        :style = "color: " * Dict(
                                            "green" => "rgb(76, 175, 80)",
                                            "yellow" => "rgb(255, 193, 7)",
                                            "red" => "rgb(244, 67, 54)"
                                        )[get(@data(:prob_positive_badge_color), "green")]
                                    )
                                ]
                            )
                        )
                    )
                )

                # Prior vs Posterior visualization
                row(
                    cell(class="col-xs-12 q-mt-lg",
                        plot(
                            type="scatter",
                            layout=attr(
                                title="Prior vs Posterior Distribution",
                                xaxis=attr(title="Annual Savings ($)"),
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
                    )
                )

                # Clear button
                row(
                    cell(class="col-xs-12 q-mt-lg",
                        button(
                            "Clear Results",
                            @click("clear_data_btn"),
                            color="negative",
                            flat=true,
                            class="full-width"
                        )
                    )
                )
            @end

            # Scenario comparison section
            row(
                cell(class="col-xs-12 q-mt-lg",
                    toggle(
                        :compare_mode,
                        label="Compare Multiple Scenarios",
                        class="q-mb-md"
                    )
                )
            )

            @if(:compare_mode)
                row(
                    cell(class="col-xs-12",
                        card(
                            card_section(
                                class="bg-blue-1",
                                [
                                    heading("Scenario Comparison", class="text-h6 q-mb-md")
                                    text("Paste JSON array of scenarios to compare", class="text-caption text-grey-7 q-mb-md")

                                    textarea(
                                        :scenarios_json,
                                        label="Scenarios (JSON)",
                                        rows=6,
                                        class="full-width q-mb-md"
                                    )

                                    button(
                                        "Compare Scenarios",
                                        @click("compare_scenarios_btn"),
                                        color="primary",
                                        class="full-width"
                                    )
                                ]
                            )
                        )
                    )
                )

                @if(!isempty(:comparison_results))
                    row(
                        cell(class="col-xs-12 q-mt-lg",
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
                                    yaxis=attr(title="Expected Savings ($)")
                                )
                            )
                        )
                    )

                    row(
                        cell(class="col-xs-12 q-mt-lg",
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
                        )
                    )
                @end
            @end
        ]
    ) |> html
end
