"""
Treasury Forecast UI — 13-week cash position with LOC and Medicare delay stress test.
"""

function ui_treasury_forecast(model)
    app_layout(model, "13-Week Cash Forecast", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("13-Week Cash Flow Forecast", class="q-mb-none"),
                p("Treasury management with LOC draws and Medicare delay stress testing",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Forecast", icon="trending_up", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ─────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("Nadir Week", class="text-overline q-mb-none"),
                    h4("{{ nadir_week }}", class="q-mb-none text-red"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("Nadir Amount", class="text-overline q-mb-none"),
                    h5("{{ nadir_amount_str }}", class="q-mb-none text-red"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("LOC Draws", class="text-overline q-mb-none"),
                    h5("{{ total_loc_draws_str }}", class="q-mb-none text-orange"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("Interest Cost", class="text-overline q-mb-none"),
                    h5("{{ total_interest_str }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-4 col-xs-6", [
                card([card_section(class="text-center", [
                    p("Medicare Stress Impact", class="text-overline q-mb-none"),
                    h5("{{ medicare_stress_str }}", class="q-mb-none text-grey-8"),
                ])])
            ]),
        ]),

        # ── Starting Parameters ───────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Starting Parameters", class="q-mb-md"),
                    textfield(:starting_cash, label="Starting Cash (\$)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:loc_capacity, label="LOC Capacity (\$)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:loc_rate, label="LOC Annual Rate", type="number",
                              filled=true, dense=true, class="q-mb-sm",
                              hint="e.g. 0.065 = 6.5%"),
                    textfield(:min_cash_threshold, label="Min Cash Threshold (\$)", type="number",
                              filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Medicare Delay Stress Test", class="q-mb-md"),
                    textfield(:medicare_delay_weeks, label="Medicare Delay (weeks)", type="number",
                              filled=true, dense=true, class="q-mb-sm",
                              hint="0 = no stress test; 2-4 = typical delay scenario"),
                    textfield(:medicare_pct, label="Medicare % of Receipts", type="number",
                              filled=true, dense=true,
                              hint="e.g. 0.45 = 45%"),
                ])])
            ]),
        ]),

        # ── Weekly Profile Inputs ─────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Weekly Cash Flow Profiles", class="q-mb-md"),
                    p("Enter operating receipts and disbursements for each week", class="text-caption text-grey-7 q-mb-md"),

                    # Headers
                    row(class="q-mb-xs text-weight-bold text-grey-8", [
                        cell(class="col-1", [span("Week")]),
                        cell(class="col-5", [span("Operating Receipts (\$)")]),
                        cell(class="col-5", [span("Operating Disbursements (\$)")]),
                    ]),
                    # Weeks 1-13
                    row(class="q-gutter-sm q-mb-xs items-center", [
                        cell(class="col-1", [span("1", class="text-weight-bold")]),
                        cell(class="col-5", [textfield(:wk_receipts_1, type="number", filled=true, dense=true)]),
                        cell(class="col-5", [textfield(:wk_disbursements_1, type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-xs items-center", [
                        cell(class="col-1", [span("2")]),
                        cell(class="col-5", [textfield(:wk_receipts_2, type="number", filled=true, dense=true)]),
                        cell(class="col-5", [textfield(:wk_disbursements_2, type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-xs items-center", [
                        cell(class="col-1", [span("3")]),
                        cell(class="col-5", [textfield(:wk_receipts_3, type="number", filled=true, dense=true)]),
                        cell(class="col-5", [textfield(:wk_disbursements_3, type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-xs items-center", [
                        cell(class="col-1", [span("4")]),
                        cell(class="col-5", [textfield(:wk_receipts_4, type="number", filled=true, dense=true)]),
                        cell(class="col-5", [textfield(:wk_disbursements_4, type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-xs items-center", [
                        cell(class="col-1", [span("5")]),
                        cell(class="col-5", [textfield(:wk_receipts_5, type="number", filled=true, dense=true)]),
                        cell(class="col-5", [textfield(:wk_disbursements_5, type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-xs items-center", [
                        cell(class="col-1", [span("6")]),
                        cell(class="col-5", [textfield(:wk_receipts_6, type="number", filled=true, dense=true)]),
                        cell(class="col-5", [textfield(:wk_disbursements_6, type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-xs items-center", [
                        cell(class="col-1", [span("7")]),
                        cell(class="col-5", [textfield(:wk_receipts_7, type="number", filled=true, dense=true)]),
                        cell(class="col-5", [textfield(:wk_disbursements_7, type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-xs items-center", [
                        cell(class="col-1", [span("8")]),
                        cell(class="col-5", [textfield(:wk_receipts_8, type="number", filled=true, dense=true)]),
                        cell(class="col-5", [textfield(:wk_disbursements_8, type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-xs items-center", [
                        cell(class="col-1", [span("9")]),
                        cell(class="col-5", [textfield(:wk_receipts_9, type="number", filled=true, dense=true)]),
                        cell(class="col-5", [textfield(:wk_disbursements_9, type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-xs items-center", [
                        cell(class="col-1", [span("10")]),
                        cell(class="col-5", [textfield(:wk_receipts_10, type="number", filled=true, dense=true)]),
                        cell(class="col-5", [textfield(:wk_disbursements_10, type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-xs items-center", [
                        cell(class="col-1", [span("11")]),
                        cell(class="col-5", [textfield(:wk_receipts_11, type="number", filled=true, dense=true)]),
                        cell(class="col-5", [textfield(:wk_disbursements_11, type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-xs items-center", [
                        cell(class="col-1", [span("12")]),
                        cell(class="col-5", [textfield(:wk_receipts_12, type="number", filled=true, dense=true)]),
                        cell(class="col-5", [textfield(:wk_disbursements_12, type="number", filled=true, dense=true)]),
                    ]),
                    row(class="q-gutter-sm q-mb-xs items-center", [
                        cell(class="col-1", [span("13")]),
                        cell(class="col-5", [textfield(:wk_receipts_13, type="number", filled=true, dense=true)]),
                        cell(class="col-5", [textfield(:wk_disbursements_13, type="number", filled=true, dense=true)]),
                    ]),
                ])])
            ]),
        ]),

        # ── Cash Position Chart ───────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:cash_chart_data, layout=:cash_chart_layout,
                         config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Weekly Balance Table ──────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Weekly Cash Balances", class="q-mb-md"),
                    row(class="q-mb-xs text-weight-bold text-grey-8", [
                        cell(class="col-2", [span("Week")]),
                        cell(class="col-2", [span("Beginning")]),
                        cell(class="col-2", [span("Net CF")]),
                        cell(class="col-2", [span("LOC Draw")]),
                        cell(class="col-2", [span("LOC Repay")]),
                        cell(class="col-2", [span("Ending")]),
                    ]),
                    Html.div(var"v-for"="(wk, idx) in weekly_table", var":key"="idx", [
                        row(class="q-py-xs", var":class"="wk.ending_cash < $(min_cash_threshold) ? 'bg-red-1' : ''", [
                            cell(class="col-2", [span("Wk {{ wk.week }}", class="text-weight-bold")]),
                            cell(class="col-2", [span("\${{ wk.beginning_cash.toLocaleString() }}")]),
                            cell(class="col-2", [
                                span("\${{ wk.net_cash_flow.toLocaleString() }}",
                                     var":class"="wk.net_cash_flow < 0 ? 'text-red' : 'text-green'"),
                            ]),
                            cell(class="col-2", [span("\${{ wk.loc_draw.toLocaleString() }}")]),
                            cell(class="col-2", [span("\${{ wk.loc_repayment.toLocaleString() }}")]),
                            cell(class="col-2", [
                                span("\${{ wk.ending_cash.toLocaleString() }}", class="text-weight-bold"),
                            ]),
                        ]),
                        separator(),
                    ]),
                ])])
            ]),
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
