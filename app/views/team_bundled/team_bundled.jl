"""
TEAM Bundled Payment UI - CMS TEAM reconciliation with quality adjustments.
"""

function ui_team_bundled(model)
    app_layout(model, "TEAM Bundled Payment", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("TEAM Bundled Payment Simulation", class="q-mb-none"),
                p("CMS Transforming Episode Accountability Model reconciliation calculator",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Calculate", icon="calculate", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ──────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Net Payment Adjustment", class="text-overline q-mb-none"),
                    h4("\${{ (net_payment_adjustment / 1e3).toFixed(1) }}K", class="q-mb-none",
                       var":class"="net_payment_adjustment >= 0 ? 'text-green' : 'text-red'"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Raw Reconciliation", class="text-overline q-mb-none"),
                    h4("\${{ (raw_reconciliation / 1e3).toFixed(1) }}K", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Quality Adjusted", class="text-overline q-mb-none"),
                    h4("\${{ (quality_adj_reconciliation / 1e3).toFixed(1) }}K", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Low Volume Exempt", class="text-overline q-mb-none"),
                    h4("{{ is_low_volume_exempt ? 'Yes' : 'No' }}", class="q-mb-none",
                       var":class"="is_low_volume_exempt ? 'text-orange' : 'text-green'"),
                ])])
            ]),
        ]),

        # ── Inputs ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Episode Parameters", class="q-mb-md"),
                    textfield(:episode_count, label="Episode Count", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:avg_target_price, label="Avg Target Price (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:avg_actual_cost, label="Avg Actual Cost (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    slider(:quality_score, label=true, var":label-value"="'Quality: ' + (quality_score * 100).toFixed(0) + '%'",
                           var":min"="0", var":max"="1", var":step"="0.05", class="q-mb-sm"),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Model Settings", class="q-mb-md"),
                    q__select(:risk_track, options=:risk_track_options, label="Risk Track",
                              filled=true, dense=true, var"emit-value"=true, var"map-options"=true, class="q-mb-sm"),
                    textfield(:discount_factor, label="Discount Factor", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:quality_adjustment_pct, label="Quality Adjustment %", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:low_volume_threshold, label="Low Volume Threshold", type="number", filled=true, dense=true),
                ])])
            ]),
        ]),

        # ── Chart ──────────────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:episode_chart_data, layout=:episode_chart_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
