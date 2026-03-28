"""
Revenue Cycle Optimization UI - before/after comparison, waterfall chart.
"""

function ui_revenue_cycle(model)
    app_layout(model, "Revenue Cycle Optimization", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Revenue Cycle Optimization", class="q-mb-none"),
                p("Identify dollar impact of improving key revenue cycle metrics",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Calculate Impact", icon="trending_up", color="primary",
                    @click(:recalculate)),
            ]),
        ]),

        # ── Summary KPIs ────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Total Revenue Cycle Impact", class="text-overline q-mb-none"),
                    h4("\${{ (total_dollar_impact / 1e3).toFixed(0) }}K", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Target Days in A/R", class="text-overline q-mb-none"),
                    h4("{{ improved_days_in_ar.toFixed(0) }} days", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Target Collection Rate", class="text-overline q-mb-none"),
                    h4("{{ (improved_collection_rate * 100).toFixed(1) }}%", class="q-mb-none"),
                ])])
            ]),
        ]),

        # ── Current vs Target Inputs ────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Current Metrics", class="q-mb-md"),
                    textfield(:days_in_ar, label="Days in A/R", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:clean_claim_rate, label="Clean Claim Rate (0-1)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:denial_rate, label="Denial Rate (0-1)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:cost_to_collect, label="Cost to Collect (0-1)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:cash_collection_pct, label="Cash Collection % (0-1)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:days_to_bill, label="Days to Bill", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:point_of_service_collection, label="Point of Service Collection (0-1)", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Target Metrics", class="q-mb-md"),
                    textfield(:target_days_in_ar, label="Target Days in A/R", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:target_clean_claim_rate, label="Target Clean Claim Rate", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:target_denial_rate, label="Target Denial Rate", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:target_cost_to_collect, label="Target Cost to Collect", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:target_cash_collection, label="Target Cash Collection", type="number", filled=true, dense=true),
                ])])
            ]),
        ]),

        # ── Charts ──────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:waterfall_data, layout=:waterfall_layout, config="{ responsive: true }")
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    plot(:before_after_data, layout=:before_after_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Initiative Details ──────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Initiative Impact Details", class="q-mb-md"),
                    card(var"v-for"="(item, idx) in initiative_impacts", key!="idx",
                        class="q-mb-sm", flat=true, bordered=true, [
                        card_section(class="q-pa-sm", [
                            badge("{{ item.priority }}", var":color"="item.priority === 'high' ? 'red' : item.priority === 'medium' ? 'orange' : 'green'", class="q-mr-sm"),
                            strong("{{ item.initiative }}"),
                            span(" | Current: {{ item.current }} -> Target: {{ item.target }} | "),
                            span(class="text-green text-bold", "\${{ (item.dollar_impact / 1000).toFixed(0) }}K"),
                        ])
                    ]),
                ])])
            ]),
        ]),
    ])
end
