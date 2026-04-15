"""
Value-Based Care Transition UI - shared savings/loss modeling for ACO programs.
"""

function ui_vbc_transition(model)
    app_layout(model, "VBC Transition", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Value-Based Care Transition", class="q-mb-none"),
                p("Model shared savings/loss for Medicare ACO programs", class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Calculate", icon="account_balance", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ──────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Savings Rate", class="text-overline q-mb-none"),
                    h4("{{ (savings_rate * 100).toFixed(1) }}%", class="q-mb-none",
                       var":class"="savings_rate >= 0.02 ? 'text-green' : 'text-orange'"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Shared Savings", class="text-overline q-mb-none"),
                    h4("\${{ (shared_savings_payment / 1e6).toFixed(2) }}M", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Net Impact", class="text-overline q-mb-none"),
                    h4("\${{ (net_financial_impact / 1e3).toFixed(0) }}K", class="q-mb-none",
                       var":class"="net_financial_impact >= 0 ? 'text-green' : 'text-red'"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Per Beneficiary", class="text-overline q-mb-none"),
                    h4("\${{ per_beneficiary_savings.toFixed(0) }}", class="q-mb-none"),
                ])])
            ]),
        ]),

        # ── Inputs ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("ACO Parameters", class="q-mb-md"),
                    q__select(:model_type, options=:model_type_options, label="ACO Model",
                              filled=true, dense=true, var"emit-value"=true, var"map-options"=true, class="q-mb-sm"),
                    q__select(:risk_track, options=:risk_track_options, label="Risk Track",
                              filled=true, dense=true, var"emit-value"=true, var"map-options"=true, class="q-mb-sm"),
                    textfield(:benchmark, label="Benchmark (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:total_cost_of_care, label="Total Cost of Care (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:patient_panel_size, label="Patient Panel Size", type="number", filled=true, dense=true),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Financial Settings", class="q-mb-md"),
                    slider(:quality_score, label=true, var":label-value"="'Quality: ' + (quality_score * 100).toFixed(0) + '%'",
                           var":min"="0", var":max"="1", var":step"="0.05", class="q-mb-sm"),
                    textfield(:shared_savings_rate, label="Shared Savings Rate", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:shared_loss_rate, label="Shared Loss Rate", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:min_savings_rate, label="Min Savings Rate (MSR)", type="number", filled=true, dense=true, class="q-mb-sm"),
                    textfield(:care_management_investment, label="Care Management Investment (\$)", type="number", filled=true, dense=true),
                ])])
            ]),
        ]),

        # ── Chart ──────────────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:timeline_data, layout=:timeline_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
    ])
end
