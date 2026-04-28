"""
    wacc.jl — DSL UI for nonprofit WACC calculator (A-04)

Renders input controls, calculation button, results display, and peer comparison.
"""
function ui_wacc()
    page(
        model = @current,
        partial = true,
        [
            heading("Nonprofit WACC Calculator", class="text-h4 q-mb-md")

            row(
                cell(class="col-xs-12 col-sm-6",
                    card(
                        card_section(
                            class="bg-blue-1",
                            [
                                heading("Hospital Profile", class="text-h6 q-mb-md")
                                separator()

                                textfield(
                                    :ccn,
                                    label="CCN (6-digit)",
                                    placeholder="e.g., 011300",
                                    class="full-width q-mb-md"
                                )

                                textfield(
                                    :fiscal_year,
                                    label="Fiscal Year",
                                    type="number",
                                    class="full-width q-mb-md"
                                )

                                toggle(
                                    :use_hcris,
                                    label="Auto-populate from HCRIS",
                                    class="q-mb-md"
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
                                heading("CAPM Parameters", class="text-h6 q-mb-md")
                                separator()

                                select(
                                    :cost_of_equity_model,
                                    label="Cost of Equity Model",
                                    options=[:capm => "CAPM", :conservative => "Conservative", :aggressive => "Aggressive"],
                                    class="full-width q-mb-md"
                                )

                                textfield(
                                    :risk_free_rate,
                                    label="Risk-Free Rate",
                                    type="number",
                                    step=0.001,
                                    class="full-width q-mb-md"
                                )

                                textfield(
                                    :market_risk_premium,
                                    label="Market Risk Premium",
                                    type="number",
                                    step=0.001,
                                    class="full-width q-mb-md"
                                )

                                textfield(
                                    :beta,
                                    label="Beta",
                                    type="number",
                                    step=0.1,
                                    class="full-width q-mb-md"
                                )

                                select(
                                    :sp_rating,
                                    label="S&P Rating",
                                    options=[
                                        "AAA" => "AAA (Excellent)",
                                        "AA" => "AA (Very Good)",
                                        "A" => "A (Good)",
                                        "BBB" => "BBB (Adequate)",
                                        "BB" => "BB (Speculative)",
                                        "B" => "B (Highly Speculative)",
                                        "CCC" => "CCC (Distressed)"
                                    ],
                                    class="full-width q-mb-md"
                                )
                            ]
                        )
                    )
                )
            )

            # Manual balance sheet section (collapse when use_hcris=true)
            row(
                cell(class="col-xs-12 col-sm-6",
                    card(
                        card_section(
                            class="bg-amber-1",
                            [
                                heading("Capital Structure (Manual)", class="text-h6 q-mb-md")
                                separator()

                                textfield(
                                    :manual_lt_debt,
                                    label="Long-term Debt ($)",
                                    type="number",
                                    class="full-width q-mb-md"
                                )

                                textfield(
                                    :manual_net_assets,
                                    label="Net Assets Unrestricted ($)",
                                    type="number",
                                    class="full-width q-mb-md"
                                )
                            ]
                        )
                    )
                )
            )

            # Calculate button
            row(
                cell(class="col-xs-12 col-sm-3 q-offset-sm-9",
                    button(
                        "Calculate WACC",
                        @click("calculate_wacc_btn"),
                        color="primary",
                        size="lg",
                        class="full-width",
                        :disable = :is_loading
                    )
                )
            )

            # Error display
            @if(:is_loading)
                row(
                    cell(class="col-xs-12",
                        linear_progress(value=0.5, color="primary")
                    )
                )
            @end

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

            # Results section
            @if(:wacc_value > 0)
                heading("Results", class="text-h5 q-mt-lg q-mb-md")

                row(
                    cell(class="col-xs-12 col-sm-3",
                        card(
                            card_section(
                                class="text-center",
                                [
                                    text("WACC", class="text-caption text-grey-7")
                                    heading(
                                        @text(:wacc_value; format(x) = Printf.@sprintf("%.2f%%", x * 100)),
                                        class="text-h3 text-primary q-my-md"
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
                                    text("Cost of Equity", class="text-caption text-grey-7")
                                    heading(
                                        @text(:cost_of_equity; format(x) = Printf.@sprintf("%.2f%%", x * 100)),
                                        class="text-h5 q-my-md"
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
                                    text("Cost of Debt", class="text-caption text-grey-7")
                                    heading(
                                        @text(:cost_of_debt; format(x) = Printf.@sprintf("%.2f%%", x * 100)),
                                        class="text-h5 q-my-md"
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
                                    text("Debt Ratio", class="text-caption text-grey-7")
                                    heading(
                                        @text(:target_debt_ratio; format(x) = Printf.@sprintf("%.1f%%", x * 100)),
                                        class="text-h5 q-my-md"
                                    )
                                ]
                            )
                        )
                    )
                )

                # Peer comparison
                row(
                    cell(class="col-xs-12",
                        card(
                            card_section(
                                class="bg-blue-1",
                                [
                                    heading("Peer Comparison", class="text-h6 q-mb-md")
                                    text(@text(:relative_position), class="text-body1 q-mb-md")

                                    # Simple benchmark bar
                                    linear_progress(
                                        @bind(:wacc_value, :peer_median_wacc, :peer_std_wacc),
                                        value=(:wacc_value / (:peer_median_wacc + :peer_std_wacc * 2)),
                                        color="primary",
                                        class="q-mb-md"
                                    )
                                    text(
                                        "Your WACC: " * @text(:wacc_value; format(x) = Printf.@sprintf("%.2f%%", x * 100)) *
                                        " | Peer Median: " * @text(:peer_median_wacc; format(x) = Printf.@sprintf("%.2f%%", x * 100)),
                                        class="text-caption text-grey-7"
                                    )
                                ]
                            )
                        )
                    )
                )
            @end

            # Advanced settings toggle
            row(
                cell(class="col-xs-12 q-mt-lg",
                    button(
                        "Advanced Settings",
                        @click("toggle_advanced_btn"),
                        color="secondary",
                        flat=true,
                        class="full-width"
                    )
                )
            )

            @if(:show_advanced)
                row(
                    cell(class="col-xs-12",
                        card(
                            card_section(
                                [
                                    heading("Advanced Sensitivity Analysis", class="text-h6 q-mb-md")
                                    text("Scenario analysis: adjust beta and risk premium to see WACC sensitivity")
                                ]
                            )
                        )
                    )
                )
            @end
        ]
    ) |> html
end
