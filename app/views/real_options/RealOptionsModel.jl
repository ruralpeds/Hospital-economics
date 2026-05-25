"""
Stipple reactive model for Real Options (Black-Scholes-Merton) valuation.
Computes call/put values and Greeks for strategic investment decisions.
Delegates to RuralHospitalSim.calculate_real_option() for computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: calculate_real_option, RealOptionInput, RealOptionResult


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in underlying_value::Float64 = 10_000_000.0
    @in exercise_price::Float64 = 8_000_000.0
    @in time_to_expiry::Float64 = 3.0
    @in risk_free_rate::Float64 = 0.05
    @in volatility::Float64 = 0.30
    @in convenience_yield::Float64 = 0.0
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out call_value::Float64 = 0.0
    @out put_value::Float64 = 0.0
    @out delta::Float64 = 0.0
    @out gamma::Float64 = 0.0
    @out vega::Float64 = 0.0
    @out theta::Float64 = 0.0
    @out d1::Float64 = 0.0
    @out d2::Float64 = 0.0
    @out put_call_parity_lhs::Float64 = 0.0
    @out put_call_parity_rhs::Float64 = 0.0

    @out greeks_table::Vector{Dict{String,Any}} = Dict{String,Any}[]

    @out option_chart_data::Vector{PlotData} = PlotData[]
    @out option_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Option Values vs Underlying"),
        xaxis=[PlotLayoutAxis(title="Underlying Value")],
        yaxis=[PlotLayoutAxis(title="Option Value (\$)")],
    )

    # ── Handler ─────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false

            input = RealOptionInput(;
                underlying_value=underlying_value,
                exercise_price=exercise_price,
                time_to_expiry=time_to_expiry,
                risk_free_rate=risk_free_rate,
                volatility=volatility,
                convenience_yield=convenience_yield,
            )
            result = calculate_real_option(input)

            call_value = result.call_value
            put_value = result.put_value
            delta = result.delta
            gamma = result.gamma
            vega = result.vega
            theta = result.theta
            d1 = result.d1
            d2 = result.d2

            # Put-call parity: C - P = S*e^(-qT) - K*e^(-rT)
            put_call_parity_lhs = call_value - put_value
            put_call_parity_rhs = underlying_value * exp(-convenience_yield * time_to_expiry) -
                                  exercise_price * exp(-risk_free_rate * time_to_expiry)

            greeks_table = [
                Dict("greek" => "Delta", "value" => round(result.delta, digits=4),
                     "description" => "Change in option value per \$1 change in underlying"),
                Dict("greek" => "Gamma", "value" => round(result.gamma, digits=6),
                     "description" => "Rate of change of delta"),
                Dict("greek" => "Vega", "value" => round(result.vega, digits=4),
                     "description" => "Sensitivity to 1% change in volatility"),
                Dict("greek" => "Theta", "value" => round(result.theta, digits=4),
                     "description" => "Daily time decay"),
            ]

            # Sensitivity chart: vary underlying from 50% to 150% of current
            n_pts = 50
            s_range = range(underlying_value * 0.5, underlying_value * 1.5, length=n_pts)
            call_vals = Float64[]
            put_vals = Float64[]
            for s in s_range
                inp = RealOptionInput(;
                    underlying_value=s,
                    exercise_price=exercise_price,
                    time_to_expiry=time_to_expiry,
                    risk_free_rate=risk_free_rate,
                    volatility=volatility,
                    convenience_yield=convenience_yield,
                )
                r = calculate_real_option(inp)
                push!(call_vals, r.call_value)
                push!(put_vals, r.put_value)
            end

            option_chart_data = [
                PlotData(x=collect(s_range), y=call_vals,
                         plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                         name="Call Value",
                         marker=Dict("color" => "#4CAF50")),
                PlotData(x=collect(s_range), y=put_vals,
                         plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                         name="Put Value",
                         marker=Dict("color" => "#F44336")),
            ]

            @info "Real Options: Call=\$$(round(call_value, digits=2)), Put=\$$(round(put_value, digits=2)), Delta=$(round(delta, digits=4))"
        end
    end
end

const real_options_model = @init
