"""
Time Series Forecasting UI — SES, Holt, and Weighted Moving Average methods.
"""

function ui_forecasting_tools(model)
    app_layout(model, "Forecasting Tools", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Time Series Forecasting", class="q-mb-none"),
                p("Exponential smoothing and weighted moving average methods for hospital finance",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Forecast", icon="trending_up", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── Accuracy Metrics Cards ─────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("RMSE", class="text-overline q-mb-none"),
                    h4("{{ rmse.toFixed(2) }}", class="q-mb-none text-primary"),
                    p("Root Mean Squared Error", class="text-caption text-grey-7"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("MAPE", class="text-overline q-mb-none"),
                    h4("{{ mape.toFixed(1) }}%", class="q-mb-none text-orange"),
                    p("Mean Absolute Percentage Error", class="text-caption text-grey-7"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Bias", class="text-overline q-mb-none"),
                    h4("{{ bias.toFixed(2) }}", class="q-mb-none",
                       var":class"="bias >= 0 ? 'text-green' : 'text-red'"),
                    p("Mean Signed Error", class="text-caption text-grey-7"),
                ])])
            ]),
        ]),

        # ── Method Selector & Data Input ───────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-8 col-xs-12", [
                card([card_section([
                    h6("Data Input", class="q-mb-md"),
                    textfield(:values_input, label="Time Series Values (comma-separated)",
                              filled=true, type="textarea", class="q-mb-sm"),
                    q__select(:method_selector, options=:method_options, label="Forecasting Method",
                              filled=true, dense=true, var"emit-value"=true, var"map-options"=true, class="q-mb-sm"),
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    h6("Parameters", class="q-mb-md"),
                    slider(:alpha, label=true,
                           var":label-value"="'Alpha: ' + alpha.toFixed(2)",
                           var":min"="0.01", var":max"="0.99", var":step"="0.01", class="q-mb-md"),
                    slider(:beta, label=true,
                           var":label-value"="'Beta: ' + beta.toFixed(2)",
                           var":min"="0.01", var":max"="0.99", var":step"="0.01", class="q-mb-md"),
                    textfield(:n_forecast, label="Forecast Periods", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:weights_input, label="WMA Weights (comma-separated)",
                              filled=true, dense=true,
                              hint="Used only for Weighted Moving Average"),
                ])])
            ]),
        ]),

        # ── Chart ──────────────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:forecast_chart_data, layout=:forecast_chart_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
    ])
end
