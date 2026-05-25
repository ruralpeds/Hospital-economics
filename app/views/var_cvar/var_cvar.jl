"""
Value-at-Risk & CVaR UI — historical simulation risk metrics.
"""

function ui_var_cvar(model)
    app_layout(model, "VaR & CVaR", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Value-at-Risk & Conditional VaR", class="q-mb-none"),
                p("Historical simulation approach to tail-risk measurement",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Calculate", icon="calculate", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ──────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Value-at-Risk", class="text-overline q-mb-none"),
                    h4("{{ (var_pct * 100).toFixed(2) }}%", class="q-mb-none text-red"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("CVaR (Expected Shortfall)", class="text-overline q-mb-none"),
                    h4("{{ (cvar_pct * 100).toFixed(2) }}%", class="q-mb-none text-orange"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Observations", class="text-overline q-mb-none"),
                    h4("{{ n_observations }}", class="q-mb-none text-primary"),
                ])])
            ]),
        ]),

        # ── Inputs ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-8 col-xs-12", [
                card([card_section([
                    h6("Return Data", class="q-mb-md"),
                    textfield(:returns_input, label="Returns (comma-separated decimals)",
                              filled=true, type="textarea", class="q-mb-sm"),
                    p("Enter historical returns as decimals, e.g. -0.02 = -2%", class="text-grey-7 text-caption"),
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    h6("Parameters", class="q-mb-md"),
                    slider(:confidence, label=true,
                           var":label-value"="'Confidence: ' + (confidence * 100).toFixed(0) + '%'",
                           var":min"="0.90", var":max"="0.99", var":step"="0.01", class="q-mb-md"),
                    textfield(:holding_period, label="Holding Period (days)", type="number",
                              filled=true, dense=true),
                ])])
            ]),
        ]),

        # ── Chart ──────────────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:histogram_data, layout=:histogram_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
    ])
end
