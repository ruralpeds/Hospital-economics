"""
Stipple reactive model for Time Series Forecasting tools.
Supports SES, Holt double exponential, and weighted moving average methods.
Delegates to RuralHospitalSim forecasting functions for computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: simple_exponential_smoothing, holt_double_exponential,
    weighted_moving_average, forecast_accuracy, ForecastAccuracy


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in values_input::String = "100, 105, 102, 110, 108, 115, 112, 120, 118, 125, 122, 130"
    @in method_selector::String = "ses"
    @in alpha::Float64 = 0.3
    @in beta::Float64 = 0.1
    @in n_forecast::Int = 4
    @in weights_input::String = "0.1, 0.2, 0.3, 0.4"
    @in recalculate::Bool = false

    @out method_options::Vector{Dict{String,Any}} = [
        Dict("label" => "Simple Exponential Smoothing (SES)", "value" => "ses"),
        Dict("label" => "Holt Double Exponential", "value" => "holt"),
        Dict("label" => "Weighted Moving Average", "value" => "wma"),
    ]

    # ── Outputs ─────────────────────────────────────────────────────────
    @out forecast_values::Vector{Float64} = Float64[]
    @out rmse::Float64 = 0.0
    @out mape::Float64 = 0.0
    @out bias::Float64 = 0.0

    @out forecast_chart_data::Vector{PlotData} = PlotData[]
    @out forecast_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Actual vs Forecast"),
        xaxis=[PlotLayoutAxis(title="Period")],
        yaxis=[PlotLayoutAxis(title="Value")],
    )

    # ── Handler ─────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false

            # Parse values
            parts = split(strip(values_input), r"[,;\s]+")
            values = Float64[]
            for p in parts
                s = strip(p)
                isempty(s) && continue
                push!(values, parse(Float64, s))
            end

            if length(values) < 2
                @warn "Forecasting requires at least 2 observations"
                return
            end

            n = length(values)

            if method_selector == "ses"
                forecast_values = simple_exponential_smoothing(values, alpha, n_forecast)

                # In-sample fitted values for accuracy
                fitted = Float64[values[1]]
                level = values[1]
                for t in 2:n
                    push!(fitted, level)
                    level = alpha * values[t] + (1.0 - alpha) * level
                end

            elseif method_selector == "holt"
                forecast_values = holt_double_exponential(values, alpha, beta, n_forecast)

                # In-sample fitted for accuracy
                fitted = Float64[values[1]]
                level = values[1]
                trend = values[2] - values[1]
                for t in 2:n
                    push!(fitted, level + trend)
                    prev_level = level
                    level = alpha * values[t] + (1.0 - alpha) * (prev_level + trend)
                    trend = beta * (level - prev_level) + (1.0 - beta) * trend
                end

            elseif method_selector == "wma"
                # Parse weights
                wparts = split(strip(weights_input), r"[,;\s]+")
                weights = Float64[]
                for wp in wparts
                    ws = strip(wp)
                    isempty(ws) && continue
                    push!(weights, parse(Float64, ws))
                end

                if length(weights) < 1 || length(values) < length(weights)
                    @warn "WMA: need at least as many values as weights"
                    return
                end

                wma_val = weighted_moving_average(values, weights)
                forecast_values = fill(wma_val, n_forecast)

                # In-sample fitted (rolling WMA)
                k = length(weights)
                fitted = fill(NaN, k)  # Not enough data for first k points
                for t in (k+1):n
                    window = values[(t-k):(t-1)]
                    push!(fitted, weighted_moving_average(window, weights))
                end
            else
                @warn "Unknown method: $method_selector"
                return
            end

            # Compute accuracy on non-NaN fitted values
            valid_idx = [i for i in 1:min(n, length(fitted)) if !isnan(fitted[i])]
            if length(valid_idx) >= 2
                actual_subset = [values[i] for i in valid_idx]
                fitted_subset = [fitted[i] for i in valid_idx]
                acc = forecast_accuracy(actual_subset, fitted_subset)
                rmse = acc.rmse
                mape = acc.mape
                bias = acc.bias
            else
                rmse = 0.0
                mape = 0.0
                bias = 0.0
            end

            # Build chart
            actual_x = collect(1:n)
            forecast_x = collect((n+1):(n+n_forecast))
            all_x = vcat(actual_x, forecast_x)

            forecast_chart_data = [
                PlotData(x=actual_x, y=values,
                         plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                         mode="lines+markers",
                         name="Actual",
                         marker=Dict("color" => "#2196F3")),
                PlotData(x=forecast_x, y=forecast_values,
                         plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                         mode="lines+markers",
                         name="Forecast",
                         marker=Dict("color" => "#4CAF50"),
                         line=Dict("dash" => "dash")),
            ]

            # Add fitted line if available
            if length(valid_idx) >= 2
                fitted_x = valid_idx
                fitted_y = [fitted[i] for i in valid_idx]
                push!(forecast_chart_data,
                    PlotData(x=fitted_x, y=fitted_y,
                             plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                             mode="lines",
                             name="Fitted",
                             line=Dict("color" => "#FF9800", "dash" => "dot")))
            end

            @info "Forecasting ($(method_selector)): RMSE=$(round(rmse, digits=2)), MAPE=$(round(mape, digits=1))%"
        end
    end
end

const forecasting_model = @init
