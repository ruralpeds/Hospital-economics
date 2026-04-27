"""
UI for the three-statement projection view.
Uses Stipple DSL to render form inputs, charts, and result tables.
"""

function ui_three_statement(model::M) where {M}
    app_layout(model, "Three-Statement Financial Projection", [
        row([cell(class="col", [
            md"## Input: Baseline Financials",
            card(class="q-mb-md", [
                card_section([
                    row([
                        cell(class="col-md-6", [
                            q__input(:"v-model.number"=>:baseline_revenue, label="Baseline Annual Revenue", filled=true,
                                     hint="USD", dense=true)
                        ]),
                        cell(class="col-md-6", [
                            q__input(:"v-model.number"=>:baseline_expenses, label="Baseline Annual Expenses", filled=true,
                                     hint="USD", dense=true)
                        ])
                    ])
                ])
            ])
        ])]),

        row([cell(class="col", [
            md"## Input: Starting Balance Sheet (FY-end)",
            card(class="q-mb-md", [
                card_section([
                    md"### Current Assets",
                    row([
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_cash, label="Cash & Equivalents", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_short_term_inv, label="Short-term Investments", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_ar, label="Accounts Receivable", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_inventory, label="Inventory", filled=true, dense=true)
                        ])
                    ]),
                    md"### Fixed Assets",
                    row([
                        cell(class="col-md-4", [
                            q__input(:"v-model.number"=>:bs_gross_ppe, label="Gross PP&E", filled=true, dense=true)
                        ]),
                        cell(class="col-md-4", [
                            q__input(:"v-model.number"=>:bs_accumulated_depr, label="Accumulated Depreciation", filled=true, dense=true)
                        ]),
                        cell(class="col-md-4", [
                            q__input(:"v-model.number"=>:bs_lt_inv, label="Long-term Investments", filled=true, dense=true)
                        ])
                    ]),
                    md"### Current Liabilities",
                    row([
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_ap, label="Accounts Payable", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_accrued_exp, label="Accrued Expenses", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:bs_cp_debt, label="Current Portion LT Debt", filled=true, dense=true)
                        ])
                    ]),
                    md"### Debt & Equity",
                    row([
                        cell(class="col-md-6", [
                            q__input(:"v-model.number"=>:bs_lt_debt, label="Long-term Debt", filled=true, dense=true)
                        ]),
                        cell(class="col-md-6", [
                            q__input(:"v-model.number"=>:bs_net_assets, label="Net Assets (Unrestricted)", filled=true, dense=true)
                        ])
                    ])
                ])
            ])
        ])]),

        row([cell(class="col", [
            md"## Projection Assumptions",
            card(class="q-mb-md", [
                card_section([
                    md"### Horizon & Growth Rates (%)",
                    row([
                        cell(class="col-md-2", [
                            q__input(:"v-model.number"=>:horizon_years, label="Years", filled=true, type="number", min="1", max="10", dense=true)
                        ]),
                        cell(class="col-md-2", [
                            q__input(:"v-model.number"=>:rev_growth_yr1, label="Rev Gr. Yr1 (%)", filled=true, dense=true)
                        ]),
                        cell(class="col-md-2", [
                            q__input(:"v-model.number"=>:rev_growth_yr2, label="Yr2", filled=true, dense=true)
                        ]),
                        cell(class="col-md-2", [
                            q__input(:"v-model.number"=>:rev_growth_yr3, label="Yr3", filled=true, dense=true)
                        ]),
                        cell(class="col-md-2", [
                            q__input(:"v-model.number"=>:rev_growth_yr4, label="Yr4", filled=true, dense=true)
                        ]),
                        cell(class="col-md-2", [
                            q__input(:"v-model.number"=>:rev_growth_yr5, label="Yr5", filled=true, dense=true)
                        ])
                    ]),
                    md"### Expense Growth (%)",
                    row([
                        cell(class="col-md-2", []),
                        cell(class="col-md-2", [
                            q__input(:"v-model.number"=>:exp_growth_yr1, label="Exp Gr. Yr1 (%)", filled=true, dense=true)
                        ]),
                        cell(class="col-md-2", [
                            q__input(:"v-model.number"=>:exp_growth_yr2, label="Yr2", filled=true, dense=true)
                        ]),
                        cell(class="col-md-2", [
                            q__input(:"v-model.number"=>:exp_growth_yr3, label="Yr3", filled=true, dense=true)
                        ]),
                        cell(class="col-md-2", [
                            q__input(:"v-model.number"=>:exp_growth_yr4, label="Yr4", filled=true, dense=true)
                        ]),
                        cell(class="col-md-2", [
                            q__input(:"v-model.number"=>:exp_growth_yr5, label="Yr5", filled=true, dense=true)
                        ])
                    ]),
                    md"### Working Capital & Capital Assumptions",
                    row([
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:days_in_ar, label="Days in AR", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:days_in_inventory, label="Days in Inventory", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:days_in_ap, label="Days in AP", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:capex_pct_of_revenue, label="Capex % Revenue", filled=true, dense=true)
                        ])
                    ]),
                    md"### Debt & Financing",
                    row([
                        cell(class="col-md-4", [
                            q__input(:"v-model.number"=>:interest_rate, label="Interest Rate (%)", filled=true, dense=true)
                        ]),
                        cell(class="col-md-4", [
                            q__input(:"v-model.number"=>:debt_amort_years, label="Debt Amortization (years)", filled=true, type="number", dense=true)
                        ]),
                        cell(class="col-md-4", [])
                    ])
                ])
            ])
        ])]),

        row([cell(class="col", [
            q__btn(color="primary", label="Run Projection", @click=(:run_projection => true), dense=true, class="q-mb-md")
        ])]),

        # Loading & error states
        row([cell(class="col", [
            @if(:is_loading)
                card(class="q-mb-md", [card_section(["Computing 5-year projection..."])])
            end,
            @if(!isempty(:error_message))
                card(class="q-mb-md bg-negative", [card_section([:error_message])])
            end
        ])]),

        # Results section
        @if(!isnothing(:projection_data))
            [
                row([cell(class="col", [
                    # Balance check banner
                    @if(:all_bs_balance)
                        q__banner(class="bg-positive text-white", [
                            md"✓ All balance sheets balanced within $1 (good accounting!)"
                        ])
                    else
                        q__banner(class="bg-warning text-white", [
                            md"⚠ Some balance sheets do not balance — check inputs"
                        ])
                    end
                ])]),

                # Revenue chart
                row([cell(class="col", [
                    card([
                        card_section([
                            md"### Revenue Projection (5-Year)"
                        ]),
                        card_section([
                            plotly(:(data) => [
                                scatter(
                                    x=:chart_years,
                                    y=:chart_revenue,
                                    mode="lines+markers",
                                    name="Revenue",
                                    line=Dict("color"=>"#1976d2", "width"=>2),
                                    marker=Dict("size"=>8)
                                )
                            ],
                            layout=Dict(
                                "xaxis"=>Dict("title"=>"Year"),
                                "yaxis"=>Dict("title"=>"Revenue (USD)"),
                                "margin"=>Dict("l"=>50, "r"=>50, "t"=>50, "b"=>50),
                                "height"=>300
                            ))
                        ])
                    ])
                ])]),

                # Net assets chart
                row([cell(class="col", [
                    card([
                        card_section([
                            md"### Net Assets Projection (5-Year)"
                        ]),
                        card_section([
                            plotly(:(data) => [
                                scatter(
                                    x=:chart_years,
                                    y=:chart_net_assets,
                                    mode="lines+markers",
                                    name="Net Assets",
                                    line=Dict("color"=>"#43a047", "width"=>2),
                                    marker=Dict("size"=>8)
                                )
                            ],
                            layout=Dict(
                                "xaxis"=>Dict("title"=>"Year"),
                                "yaxis"=>Dict("title"=>"Net Assets (USD)"),
                                "margin"=>Dict("l"=>50, "r"=>50, "t"=>50, "b"=>50),
                                "height"=>300
                            ))
                        ])
                    ])
                ])]),

                # Income Statement Table
                row([cell(class="col", [
                    card([
                        card_section([
                            md"### Income Statement Projection"
                        ]),
                        card_section([
                            q_table(
                                rows=:is_table,
                                columns=[
                                    Dict("name"=>"year", "label"=>"Year", "field"=>"year", "align"=>"left"),
                                    Dict("name"=>"revenue", "label"=>"Revenue", "field"=>"revenue", "align"=>"right"),
                                    Dict("name"=>"depreciation", "label"=>"Depreciation", "field"=>"depreciation", "align"=>"right"),
                                    Dict("name"=>"ebitda", "label"=>"EBITDA", "field"=>"ebitda", "align"=>"right"),
                                    Dict("name"=>"interest_expense", "label"=>"Interest Expense", "field"=>"interest_expense", "align"=>"right"),
                                    Dict("name"=>"net_income", "label"=>"Net Income", "field"=>"net_income", "align"=>"right")
                                ],
                                style="font-size: 12px"
                            )
                        ])
                    ])
                ])]),

                # Balance Sheet Table
                row([cell(class="col", [
                    card([
                        card_section([
                            md"### Balance Sheet Projection (Year-end)"
                        ]),
                        card_section([
                            q_table(
                                rows=:bs_table,
                                columns=[
                                    Dict("name"=>"year", "label"=>"Year", "field"=>"year", "align"=>"left"),
                                    Dict("name"=>"cash", "label"=>"Cash", "field"=>"cash", "align"=>"right"),
                                    Dict("name"=>"ar", "label"=>"AR", "field"=>"ar", "align"=>"right"),
                                    Dict("name"=>"gross_ppe", "label"=>"Gross PP&E", "field"=>"gross_ppe", "align"=>"right"),
                                    Dict("name"=>"ap", "label"=>"AP", "field"=>"ap", "align"=>"right"),
                                    Dict("name"=>"lt_debt", "label"=>"LT Debt", "field"=>"lt_debt", "align"=>"right"),
                                    Dict("name"=>"net_assets", "label"=>"Net Assets", "field"=>"net_assets", "align"=>"right"),
                                    Dict("name"=>"balances", "label"=>"Balanced?", "field"=>"balances", "align"=>"center")
                                ],
                                style="font-size: 12px"
                            )
                        ])
                    ])
                ])]),

                # Cash Flow Table
                row([cell(class="col", [
                    card([
                        card_section([
                            md"### Cash Flow Statement"
                        ]),
                        card_section([
                            q_table(
                                rows=:cf_table,
                                columns=[
                                    Dict("name"=>"year", "label"=>"Year", "field"=>"year", "align"=>"left"),
                                    Dict("name"=>"operating_cf", "label"=>"Operating CF", "field"=>"operating_cf", "align"=>"right"),
                                    Dict("name"=>"investing_cf", "label"=>"Investing CF", "field"=>"investing_cf", "align"=>"right"),
                                    Dict("name"=>"financing_cf", "label"=>"Financing CF", "field"=>"financing_cf", "align"=>"right"),
                                    Dict("name"=>"net_change", "label"=>"Net Change in Cash", "field"=>"net_change", "align"=>"right")
                                ],
                                style="font-size: 12px"
                            )
                        ])
                    ])
                ])]),
            ]
        end
    ])
end
