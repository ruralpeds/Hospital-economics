"""
    wacc.jl — DSL UI for nonprofit WACC calculator (A-04)

Renders input controls, calculation button, results display, and peer comparison.
"""
function ui_wacc(model)
    app_layout(model, "WACC Calculator", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Nonprofit WACC Calculator", class="q-mb-none"),
                p("Weighted average cost of capital tailored for rural nonprofit hospitals",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Calculate WACC", icon="calculate", color="primary",
                    @click("calculate_wacc_btn"),
                    :disable = :is_loading),
            ]),
        ]),

        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-xs-12 col-sm-6", [
                card([card_section(class="bg-blue-1", [
                    h6("Hospital Profile", class="q-mb-md"),
                    separator(),
                    textfield(:ccn, label="CCN (6-digit)", placeholder="e.g., 011300",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:fiscal_year, label="Fiscal Year", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    toggle(:use_hcris, label="Auto-populate from HCRIS", class="q-mb-sm"),
                ])])
            ]),

            cell(class="col-xs-12 col-sm-6", [
                card([card_section(class="bg-green-1", [
                    h6("CAPM Parameters", class="q-mb-md"),
                    separator(),
                    select(:cost_of_equity_model, label="Cost of Equity Model",
                           options=[:capm => "CAPM", :conservative => "Conservative", :aggressive => "Aggressive"],
                           filled=true, dense=true, class="q-mb-sm"),
                    textfield(:risk_free_rate, label="Risk-Free Rate", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:market_risk_premium, label="Market Risk Premium", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:beta, label="Beta", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    select(:sp_rating, label="S&P Rating",
                           options=[
                               "AAA" => "AAA (Excellent)",
                               "AA" => "AA (Very Good)",
                               "A" => "A (Good)",
                               "BBB" => "BBB (Adequate)",
                               "BB" => "BB (Speculative)",
                               "B" => "B (Highly Speculative)",
                               "CCC" => "CCC (Distressed)"
                           ],
                           filled=true, dense=true, class="q-mb-sm"),
                ])])
            ]),
        ]),

        # Manual balance sheet section (collapse when use_hcris=true)
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-xs-12 col-sm-6", [
                card([card_section(class="bg-amber-1", [
                    h6("Capital Structure (Manual)", class="q-mb-md"),
                    separator(),
                    textfield(:manual_lt_debt, label="Long-term Debt (\$)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:manual_net_assets, label="Net Assets Unrestricted (\$)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                ])])
            ]),
        ]),

        # Error display
        @if(:is_loading)
            row([
                cell(class="col-xs-12", [
                    linear_progress(value=0.5, color="primary")
                ])
            ])
        @end

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

        # Results section
        @if(:wacc_value > 0)
            row(class="q-mb-lg q-gutter-md", [
                cell(class="col-xs-12 col-sm-3", [
                    card([card_section(class="text-center", [
                        text("WACC", class="text-caption text-grey-7"),
                        heading(
                            @text(:wacc_value; format(x) = Printf.@sprintf("%.2f%%", x * 100)),
                            class="text-h3 text-primary q-my-md"
                        ),
                    ])])
                ]),
                cell(class="col-xs-12 col-sm-3", [
                    card([card_section(class="text-center", [
                        text("Cost of Equity", class="text-caption text-grey-7"),
                        heading(
                            @text(:cost_of_equity; format(x) = Printf.@sprintf("%.2f%%", x * 100)),
                            class="text-h5 q-my-md"
                        ),
                    ])])
                ]),
                cell(class="col-xs-12 col-sm-3", [
                    card([card_section(class="text-center", [
                        text("Cost of Debt", class="text-caption text-grey-7"),
                        heading(
                            @text(:cost_of_debt; format(x) = Printf.@sprintf("%.2f%%", x * 100)),
                            class="text-h5 q-my-md"
                        ),
                    ])])
                ]),
                cell(class="col-xs-12 col-sm-3", [
                    card([card_section(class="text-center", [
                        text("Debt Ratio", class="text-caption text-grey-7"),
                        heading(
                            @text(:target_debt_ratio; format(x) = Printf.@sprintf("%.1f%%", x * 100)),
                            class="text-h5 q-my-md"
                        ),
                    ])])
                ]),
            ])

            # Peer comparison
            row(class="q-mb-lg", [
                cell(class="col-xs-12", [
                    card([card_section(class="bg-blue-1", [
                        h6("Peer Comparison", class="q-mb-md"),
                        text(@text(:relative_position), class="text-body1 q-mb-md"),
                        linear_progress(
                            @bind(:wacc_value, :peer_median_wacc, :peer_std_wacc),
                            value=(:wacc_value / (:peer_median_wacc + :peer_std_wacc * 2)),
                            color="primary",
                            class="q-mb-md"
                        ),
                        text(
                            "Your WACC: " * @text(:wacc_value; format(x) = Printf.@sprintf("%.2f%%", x * 100)) *
                            " | Peer Median: " * @text(:peer_median_wacc; format(x) = Printf.@sprintf("%.2f%%", x * 100)),
                            class="text-caption text-grey-7"
                        ),
                    ])])
                ])
            ])
        @end

        # Advanced settings toggle
        row([
            cell(class="col-xs-12 q-mt-lg", [
                button(
                    "Advanced Settings",
                    @click("toggle_advanced_btn"),
                    color="secondary",
                    flat=true,
                    class="full-width"
                )
            ])
        ])

        @if(:show_advanced)
            row([
                cell(class="col-xs-12", [
                    card([card_section([
                        h6("Advanced Sensitivity Analysis", class="q-mb-md"),
                        text("Scenario analysis: adjust beta and risk premium to see WACC sensitivity"),
                    ])])
                ])
            ])
        @end

        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
