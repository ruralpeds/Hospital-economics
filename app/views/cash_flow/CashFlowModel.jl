"""
Stipple reactive model for Monthly Cash Flow Projection.
Projects 12-month cash flow with nadir identification and days cash on hand.
"""
using Stipple, StippleUI, StipplePlotly


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in starting_cash::Float64 = 2_100_000.0
    @in monthly_revenue::Float64 = 1_540_000.0
    @in monthly_operating_expense::Float64 = 1_600_000.0
    @in monthly_debt_service::Float64 = 37_500.0
    @in revenue_seasonality::Float64 = 0.08
    @in collection_lag_days::Int = 45
    @in capex_month::Int = 6
    @in capex_amount::Float64 = 350_000.0
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out monthly_balances::Vector{Float64} = [2100, 1990, 1895, 1820, 1770, 1730, 1380, 1350, 1340, 1355, 1380, 1420, 1475]
    @out nadir_month::Int = 9
    @out nadir_balance::Float64 = 1_340_000.0
    @out ending_cash::Float64 = 1_475_000.0
    @out days_cash_on_hand::Int = 28
    @out months_below_threshold::Int = 8
    @out avg_monthly_burn::Float64 = 52_083.0

    @out month_labels::Vector{String} = ["Start","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

    # ── Chart Data ──────────────────────────────────────────────────────
    @out cash_flow_data::Vector{PlotData} = [
        PlotData(
            x = ["Start","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],
            y = [2100, 1990, 1895, 1820, 1770, 1730, 1380, 1350, 1340, 1355, 1380, 1420, 1475],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Cash Balance (\$K)",
            marker = Dict("color" => [b < 1500 ? "#F44336" : "#4CAF50" for b in
                [2100, 1990, 1895, 1820, 1770, 1730, 1380, 1350, 1340, 1355, 1380, 1420, 1475]]),
        ),
        PlotData(
            x = ["Start","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],
            y = fill(1500, 13),
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "30-Day Threshold",
            mode = "lines",
            line = PlotDataLine(dash="dash", color="orange"),
        ),
    ]
    @out cash_flow_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "12-Month Cash Flow Projection (\$K)"),
        xaxis = [PlotLayoutAxis(title = "Month")],
        yaxis = [PlotLayoutAxis(title = "\$K")],
    )

    # ── Handlers ────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false
            balances = Float64[starting_cash]
            daily_expense = (monthly_operating_expense * 12) / 365

            for m in 1:12
                # Seasonal revenue adjustment
                season_factor = 1.0 + revenue_seasonality * sin(2 * pi * (m - 3) / 12)
                rev = monthly_revenue * season_factor
                exp = monthly_operating_expense + monthly_debt_service
                capex = (m == capex_month) ? capex_amount : 0.0
                net = rev - exp - capex
                push!(balances, balances[end] + net)
            end

            monthly_balances = round.(balances ./ 1000, digits=0)
            nadir_idx = argmin(balances[2:end])
            nadir_month = nadir_idx
            nadir_balance = round(balances[nadir_idx + 1], digits=0)
            ending_cash = round(balances[end], digits=0)
            days_cash_on_hand = round(Int, balances[end] / max(daily_expense, 1.0))
            threshold = daily_expense * 30
            months_below_threshold = count(b -> b < threshold, balances[2:end])
            avg_monthly_burn = round((starting_cash - balances[end]) / 12, digits=0)

            cash_flow_data = [
                PlotData(x=month_labels, y=monthly_balances,
                    plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Cash Balance (\$K)",
                    marker=Dict("color"=>[b < round(threshold/1000) ? "#F44336" : "#4CAF50" for b in monthly_balances])),
                PlotData(x=month_labels, y=fill(round(threshold/1000, digits=0), 13),
                    plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER, name="30-Day Threshold",
                    mode="lines", line=PlotDataLine(dash="dash", color="orange")),
            ]
            @info "Cash flow: nadir \$$(round(Int, nadir_balance/1000))K in month $(nadir_month), $(days_cash_on_hand) days cash"
        end
    end
end

const cash_flow_model = @init
