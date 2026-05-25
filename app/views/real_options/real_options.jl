"""
Real Options (Black-Scholes-Merton) UI — strategic investment option valuation.
"""

function ui_real_options(model)
    app_layout(model, "Real Options", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Real Options Valuation (Black-Scholes)", class="q-mb-none"),
                p("Value strategic flexibility using Black-Scholes-Merton with convenience yield",
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
                    p("Call Value", class="text-overline q-mb-none"),
                    h4("\${{ (call_value / 1e6).toFixed(3) }}M", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Put Value", class="text-overline q-mb-none"),
                    h4("\${{ (put_value / 1e6).toFixed(3) }}M", class="q-mb-none text-red"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Delta", class="text-overline q-mb-none"),
                    h4("{{ delta.toFixed(4) }}", class="q-mb-none text-primary"),
                ])])
            ]),
        ]),

        # ── Input Parameters ───────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Project Parameters", class="q-mb-md"),
                    textfield(:underlying_value, label="Underlying Value (S) \$", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:exercise_price, label="Exercise Price (K) \$", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:time_to_expiry, label="Time to Expiry (years)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Market Parameters", class="q-mb-md"),
                    textfield(:risk_free_rate, label="Risk-Free Rate", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:volatility, label="Volatility (sigma)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:convenience_yield, label="Convenience Yield (q)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                ])])
            ]),
        ]),

        # ── Greeks Table ───────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Option Greeks", class="q-mb-md"),
                    table(var":rows"="greeks_table",
                          var":columns"="[
                              {name: 'greek', label: 'Greek', field: 'greek', align: 'left'},
                              {name: 'value', label: 'Value', field: 'value', align: 'right'},
                              {name: 'description', label: 'Description', field: 'description', align: 'left'}
                          ]",
                          flat=true, bordered=true, dense=true,
                          var"row-key"="'greek'"),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Put-Call Parity Verification", class="q-mb-md"),
                    p("C - P = S*exp(-qT) - K*exp(-rT)", class="text-grey-7 q-mb-sm"),
                    row(class="q-gutter-md", [
                        cell(class="col", [
                            card(flat=true, bordered=true, [card_section(class="text-center", [
                                p("C - P (LHS)", class="text-overline q-mb-none"),
                                h5("\${{ put_call_parity_lhs.toFixed(2) }}", class="q-mb-none"),
                            ])])
                        ]),
                        cell(class="col", [
                            card(flat=true, bordered=true, [card_section(class="text-center", [
                                p("Se^(-qT) - Ke^(-rT) (RHS)", class="text-overline q-mb-none"),
                                h5("\${{ put_call_parity_rhs.toFixed(2) }}", class="q-mb-none"),
                            ])])
                        ]),
                    ]),
                    p("d1 = {{ d1.toFixed(4) }}, d2 = {{ d2.toFixed(4) }}", class="text-grey-7 q-mt-md"),
                ])])
            ]),
        ]),

        # ── Chart ──────────────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:option_chart_data, layout=:option_chart_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
    ])
end
