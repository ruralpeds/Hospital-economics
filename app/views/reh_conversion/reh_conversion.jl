"""REH Conversion Decision UI."""
function ui_reh_conversion(model)
    app_layout(model, "REH Conversion", [
        row(class="q-mb-md items-center", [
            cell(class="col", [h5("CAH to REH Conversion Decision", class="q-mb-none"),
                p("Should your CAH convert to Rural Emergency Hospital designation?", class="text-grey-7")]),
            cell(class="col-auto", [btn("Analyse", icon="swap_horiz", color="primary", @click(:run_analysis))]),
        ]),
        row(class="q-gutter-md", [
            cell(class="col-md-3 col-xs-12", [card([card_section([
                h6("Hospital Profile", class="q-mb-md"),
                textfield(:annual_ed_visits, label="Annual ED Visits", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:annual_ip_discharges, label="Annual IP Discharges", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:cah_revenue, label="CAH Net Revenue", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:cah_expenses, label="Total Expenses", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:opps_rate_per_visit, label="OPPS Rate/Visit", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:inpatient_revenue_pct, label="Inpatient Revenue %", type="number", filled=true, dense=true),
            ])])]),
            cell(class="col-md-9 col-xs-12", [
                row(class="q-gutter-sm q-mb-md", [
                    cell(class="col-md-2 col-xs-4", [card(class="text-center", [card_section([p("CAH Margin", class="text-overline text-caption q-mb-none"), p("{{ cah_margin }}%", class="text-weight-bold", var":class"="cah_margin < 0 ? 'text-red' : 'text-green'")])])]),
                    cell(class="col-md-2 col-xs-4", [card(class="text-center", [card_section([p("REH Revenue", class="text-overline text-caption q-mb-none"), p("{{ (reh_total_revenue/1e6).toFixed(2) }}M", class="text-weight-bold")])])]),
                    cell(class="col-md-2 col-xs-4", [card(class="text-center", [card_section([p("REH Margin", class="text-overline text-caption q-mb-none"), p("{{ reh_margin }}%", class="text-weight-bold", var":class"="reh_margin < 0 ? 'text-red' : 'text-green'")])])]),
                    cell(class="col-md-2 col-xs-4", [card(class="text-center", [card_section([p("Revenue Delta", class="text-overline text-caption q-mb-none"), p("{{ (annual_revenue_delta/1000).toFixed(0) }}K", class="text-weight-bold", var":class"="annual_revenue_delta > 0 ? 'text-green' : 'text-red'")])])]),
                    cell(class="col-md-2 col-xs-4", [card(class="text-center", [card_section([p("5-Yr NPV", class="text-overline text-caption q-mb-none"), p("{{ (npv_5yr/1e6).toFixed(2) }}M", class="text-weight-bold", var":class"="npv_5yr > 0 ? 'text-green' : 'text-red'")])])]),
                    cell(class="col-md-2 col-xs-4", [card(class="text-center", [card_section([p("Break-Even Visits", class="text-overline text-caption q-mb-none"), p("{{ breakeven_ed_visits.toLocaleString() }}", class="text-weight-bold")])])]),
                ]),
                card(class="q-mb-md", [card_section([
                    badge("{{ recommendation }}", var":color"="recommendation_color", class="text-h6 q-pa-sm"),
                    p("{{ community_note }}", class="text-body2 q-mt-sm q-mb-none"),
                ])]),
                card([card_section([
                    plot(:comparison_chart, layout=:comparison_layout, config="{ responsive: true }"),
                ])]),
            ]),
        ]),
    ])
end
