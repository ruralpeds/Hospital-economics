"""
Monthly Cash Flow Projection UI - monthly bar chart, nadir indicator.
"""

function ui_cash_flow(model)
    app_layout(model, "Cash Flow Projection", [
        loading_overlay("is_loading"),

        page_header("Monthly Cash Flow Projection",
            "Project 12-month cash position with seasonal patterns and capital events",
            breadcrumbs=["Dashboard" => "/dashboard", "Finance" => "#", "Cash Flow Projection" => ""]),

        row(class="q-mb-md items-center", [
            cell(class="col-auto", [
                btn("Project", icon="account_balance_wallet", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── Summary KPIs ────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Starting Cash", class="text-overline q-mb-none"),
                    h5("\${{ (starting_cash / 1e6).toFixed(2) }}M", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Ending Cash", class="text-overline q-mb-none"),
                    h5("\${{ (ending_cash / 1e3).toFixed(0) }}K", class="q-mb-none",
                       var":class"="ending_cash < starting_cash ? 'text-red' : 'text-green'"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card(class="bg-red-1", [card_section(class="text-center q-pa-sm", [
                    p("Cash Nadir", class="text-overline q-mb-none"),
                    h5("\${{ (nadir_balance / 1e3).toFixed(0) }}K", class="q-mb-none text-red"),
                    p("Month {{ nadir_month }}", class="text-caption"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Days Cash", class="text-overline q-mb-none"),
                    h5("{{ days_cash_on_hand }}", class="q-mb-none",
                       var":class"="days_cash_on_hand < 30 ? 'text-red' : days_cash_on_hand < 60 ? 'text-orange' : 'text-green'"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Months Below Threshold", class="text-overline q-mb-none"),
                    h5("{{ months_below_threshold }}", class="q-mb-none",
                       var":class"="months_below_threshold > 3 ? 'text-red' : ''"),
                ])])
            ]),
            cell(class="col-md-2 col-sm-4 col-xs-6", [
                card([card_section(class="text-center q-pa-sm", [
                    p("Avg Monthly Burn", class="text-overline q-mb-none"),
                    h5("\${{ (avg_monthly_burn / 1e3).toFixed(0) }}K", class="q-mb-none"),
                ])])
            ]),
        ]),

        # ── Inputs and Chart ────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-xs-12", [
                card([card_section([
                    h6("Cash Flow Parameters", class="q-mb-md"),
                    textfield(:starting_cash, label="Starting Cash (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:monthly_revenue, label="Monthly Revenue (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:monthly_operating_expense, label="Monthly OpEx (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:monthly_debt_service, label="Monthly Debt Service (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    p("Revenue Seasonality: {{ (revenue_seasonality * 100).toFixed(0) }}%", class="q-mb-none"),
                    slider(:revenue_seasonality, min=0.0, max=0.25, step=0.01, label=true, class="q-mb-md"),
                    textfield(:collection_lag_days, label="Collection Lag (days)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:capex_month, label="CapEx Month (1-12)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:capex_amount, label="CapEx Amount (\$)", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-9 col-xs-12", [
                card([card_section([
                    plot(:cash_flow_data, layout=:cash_flow_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
