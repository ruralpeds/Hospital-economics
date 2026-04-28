"""
UI for the DuPont decomposition view.
"""

function ui_dupont(model::M) where {M}
    app_layout(model, "DuPont Financial Decomposition", [
        row([cell(class="col", [
            md"## Input: Annual Financials",
            card(class="q-mb-md", [
                card_section([
                    row([
                        cell(class="col-md-4", [
                            q__input(:"v-model.number"=>:baseline_revenue, label="Revenue", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:ebit, label="EBIT", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:interest_expense, label="Interest Expense", filled=true, dense=true)
                        ]),
                        cell(class="col-md-2", [])
                    ]),
                    row([
                        cell(class="col-md-4", [
                            q__input(:"v-model.number"=>:ebt, label="EBT", filled=true, dense=true)
                        ]),
                        cell(class="col-md-4", [
                            q__input(:"v-model.number"=>:net_income, label="Net Income", filled=true, dense=true)
                        ]),
                        cell(class="col-md-4", [
                            q__toggle(:"v-model"=>:tax_exempt, label="Tax-Exempt Entity", dense=true)
                        ])
                    ])
                ])
            ])
        ])]),

        row([cell(class="col", [
            md"## Input: Balance Sheet",
            card(class="q-mb-md", [
                card_section([
                    md"### Assets",
                    row([
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_cash, label="Cash", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_ar, label="AR", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_inventory, label="Inventory", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_gross_ppe, label="Gross PP&E", filled=true, dense=true)
                        ])
                    ]),
                    row([
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_accumulated_depr, label="Accum. Depr.", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_short_term_inv, label="ST Inv", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_lt_inv, label="LT Inv", filled=true, dense=true)
                        ])
                    ]),
                    md"### Liabilities & Equity",
                    row([
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_ap, label="AP", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_accrued_exp, label="Accrued Exp", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_cp_debt, label="CP Debt", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_lt_debt, label="LT Debt", filled=true, dense=true)
                        ])
                    ]),
                    row([
                        cell(class="col-md-6", [
                            q__input(:"v-model.number"=>:bs_net_assets, label="Net Assets (Unrestricted)", filled=true, dense=true)
                        ])
                    ])
                ])
            ])
        ])]),

        row([cell(class="col", [
            q__btn(color="primary", label="Calculate DuPont", @click=(:run_analysis => true), dense=true, class="q-mb-md")
        ])]),

        # Loading & error
        row([cell(class="col", [
            @if(:is_loading)
                card(class="q-mb-md", [card_section(["Computing DuPont decomposition..."])])
            end,
            @if(!isempty(:error_message))
                card(class="q-mb-md bg-negative", [card_section([:error_message])])
            end
        ])]),

        # Results
        @if(!isnothing(:three_factor))
            [
                row([cell(class="col", [
                    md"## Three-Factor DuPont Analysis",
                    card([
                        card_section([
                            row([
                                cell(class="col-md-3", [
                                    q__card([
                                        q__card_section(class="text-center", [
                                            div(class="text-h6", ["Net Profit Margin"]),
                                            div(class="text-h4 text-primary", [
                                                string(round(:three_factor["net_profit_margin"] * 100, digits=2), "%")
                                            ])
                                        ])
                                    ])
                                ]),
                                cell(class="col-md-3", [
                                    q__card([
                                        q__card_section(class="text-center", [
                                            div(class="text-h6", ["Asset Turnover"]),
                                            div(class="text-h4 text-primary", [
                                                string(round(:three_factor["asset_turnover"], digits=3))
                                            ])
                                        ])
                                    ])
                                ]),
                                cell(class="col-md-3", [
                                    q__card([
                                        q__card_section(class="text-center", [
                                            div(class="text-h6", ["Equity Multiplier"]),
                                            div(class="text-h4 text-primary", [
                                                string(round(:three_factor["equity_multiplier"], digits=3))
                                            ])
                                        ])
                                    ])
                                ]),
                                cell(class="col-md-3", [
                                    q__card([
                                        q__card_section(class="text-center", [
                                            div(class="text-h6", ["RONA (3F)"]),
                                            div(class="text-h4 text-positive", [
                                                string(round(:three_factor["return_on_net_assets"] * 100, digits=2), "%")
                                            ])
                                        ])
                                    ])
                                ])
                            ])
                        ])
                    ])
                ])]),

                row([cell(class="col", [
                    md"## Five-Factor DuPont Analysis",
                    card([
                        card_section([
                            row([
                                cell(class="col-md-2", [
                                    q__card([
                                        q__card_section(class="text-center", [
                                            div(class="text-caption", ["Operating Margin"]),
                                            div(class="text-body2 text-primary", [
                                                string(round(:five_factor["operating_margin"] * 100, digits=2), "%")
                                            ])
                                        ])
                                    ])
                                ]),
                                cell(class="col-md-2", [
                                    q__card([
                                        q__card_section(class="text-center", [
                                            div(class="text-caption", ["Asset Turnover"]),
                                            div(class="text-body2 text-primary", [
                                                string(round(:five_factor["asset_turnover"], digits=3))
                                            ])
                                        ])
                                    ])
                                ]),
                                cell(class="col-md-2", [
                                    q__card([
                                        q__card_section(class="text-center", [
                                            div(class="text-caption", ["Equity Mult"]),
                                            div(class="text-body2 text-primary", [
                                                string(round(:five_factor["equity_multiplier"], digits=3))
                                            ])
                                        ])
                                    ])
                                ]),
                                cell(class="col-md-2", [
                                    q__card([
                                        q__card_section(class="text-center", [
                                            div(class="text-caption", ["Interest Burden"]),
                                            div(class="text-body2 text-orange", [
                                                string(round(:five_factor["interest_burden"], digits=3))
                                            ])
                                        ])
                                    ])
                                ]),
                                cell(class="col-md-2", [
                                    q__card([
                                        q__card_section(class="text-center", [
                                            div(class="text-caption", ["Tax Burden"]),
                                            div(class="text-body2", [
                                                string(round(:five_factor["tax_burden"], digits=3))
                                            ])
                                        ])
                                    ])
                                ]),
                                cell(class="col-md-2", [
                                    q__card([
                                        q__card_section(class="text-center", [
                                            div(class="text-caption", ["RONA (5F)"]),
                                            div(class="text-body1 text-positive", [
                                                string(round(:five_factor["return_on_net_assets"] * 100, digits=2), "%")
                                            ])
                                        ])
                                    ])
                                ])
                            ])
                        ])
                    ])
                ])]),

                row([cell(class="col", [
                    md"## Component Comparison",
                    card([
                        card_section([
                            plotly(:(data) => [
                                bar(
                                    x=["NPM (3F)", "ATO (3F)", "EM (3F)", "RONA (3F)"],
                                    y=[
                                        :three_factor["net_profit_margin"],
                                        :three_factor["asset_turnover"],
                                        :three_factor["equity_multiplier"],
                                        :three_factor["return_on_net_assets"]
                                    ],
                                    name="3-Factor",
                                    marker=Dict("color"=>"#1976d2")
                                ),
                                bar(
                                    x=["OM (5F)", "IB (5F)", "TB (5F)", "RONA (5F)"],
                                    y=[
                                        :five_factor["operating_margin"],
                                        :five_factor["interest_burden"],
                                        :five_factor["tax_burden"],
                                        :five_factor["return_on_net_assets"]
                                    ],
                                    name="5-Factor",
                                    marker=Dict("color"=>"#43a047")
                                )
                            ],
                            layout=Dict(
                                "barmode"=>"group",
                                "xaxis"=>Dict("title"=>"Components"),
                                "yaxis"=>Dict("title"=>"Value"),
                                "margin"=>Dict("l"=>50, "r"=>50, "t"=>50, "b"=>50),
                                "height"=>400
                            ))
                        ])
                    ])
                ])]),

                row([cell(class="col", [
                    md"## Summary",
                    card([
                        card_section([
                            md"Revenue: \$", string(round(:metadata["revenue"] / 1e6, digits=1)), "M  |  Net Income: \$", string(round(:metadata["net_income"] / 1e6, digits=1)), "M",
                        ])
                    ])
                ])])
            ]
        end
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
