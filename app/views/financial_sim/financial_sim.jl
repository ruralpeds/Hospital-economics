"""
7-Slider Financial Simulator UI - slider panel, line chart, payer doughnut.
"""

function ui_financial_sim(model)
    app_layout(model, "Financial Simulator", [
        loading_overlay("is_loading"),

        page_header("7-Slider Financial Simulator",
            "Adjust key operational parameters and project 5-year financial outcomes",
            breadcrumbs=["Dashboard" => "/dashboard", "Analytics" => "#", "Financial Simulator" => ""]),

        row(class="q-mb-md items-center", [
            cell(class="col-auto", [
                btn("Simulate", icon="tune", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── Summary KPIs ────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Year 1 Revenue", class="text-overline q-mb-none"),
                    h4("\${{ (year1_revenue / 1e6).toFixed(1) }}M", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Year 5 Revenue", class="text-overline q-mb-none"),
                    h4("\${{ (year5_revenue / 1e6).toFixed(1) }}M", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Year 5 Margin", class="text-overline q-mb-none"),
                    h4("{{ (year5_margin * 100).toFixed(1) }}%", class="q-mb-none",
                       var":class"="year5_margin < 0 ? 'text-red' : 'text-green'"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("5-Year Cumulative Gap", class="text-overline q-mb-none"),
                    h4("\${{ (total_5yr_gap / 1e6).toFixed(1) }}M", class="q-mb-none",
                       var":class"="total_5yr_gap < 0 ? 'text-red' : 'text-green'"),
                ])])
            ]),
        ]),

        # ── Slider Panel & Charts ───────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-xs-12", [
                card([card_section([
                    h6("Operational Sliders", class="q-mb-md"),
                    p("ED Visits: {{ ed_visits.toLocaleString() }}", class="q-mb-none"),
                    slider(:ed_visits, min=1000, max=10000, step=100, label=true, class="q-mb-md"),
                    p("IP Discharges: {{ ip_discharges }}", class="q-mb-none"),
                    slider(:ip_discharges, min=100, max=2000, step=10, label=true, class="q-mb-md"),
                    p("Medicare %: {{ (medicare_pct * 100).toFixed(0) }}%", class="q-mb-none"),
                    slider(:medicare_pct, min=0.20, max=0.85, step=0.01, label=true, class="q-mb-md"),
                    p("Commercial %: {{ (commercial_pct * 100).toFixed(0) }}%", class="q-mb-none"),
                    slider(:commercial_pct, min=0.05, max=0.40, step=0.01, label=true, class="q-mb-md"),
                    p("Inflation: {{ (inflation_rate * 100).toFixed(1) }}%", class="q-mb-none"),
                    slider(:inflation_rate, min=0.01, max=0.08, step=0.005, label=true, class="q-mb-md"),
                    p("Travel Nurse %: {{ (travel_nurse_pct * 100).toFixed(0) }}%", class="q-mb-none"),
                    slider(:travel_nurse_pct, min=0.0, max=0.30, step=0.01, label=true, class="q-mb-md"),
                    p("ALOS: {{ avg_length_of_stay.toFixed(1) }} days", class="q-mb-none"),
                    slider(:avg_length_of_stay, min=1.0, max=8.0, step=0.1, label=true),
                ])])
            ]),
            cell(class="col-md-5 col-xs-12", [
                card([card_section([
                    plot(:margin_trajectory_data, layout=:margin_trajectory_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    plot(:payer_doughnut_data, layout=:payer_doughnut_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
