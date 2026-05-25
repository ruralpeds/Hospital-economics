"""
Stipple reactive model for 13-Week Cash Forecast (Treasury Management).
Projects weekly cash positions with LOC draws and Medicare delay stress testing.
Delegates to RuralHospitalSim.forecast_treasury() for computation.
"""
using Stipple, StippleUI, StipplePlotly

using ...RuralHospitalSim: forecast_treasury, TreasuryInput, WeeklyProfile, TreasuryResult


@app begin
    @in left_drawer_open::Bool = true

    # ── Starting parameters ────────────────────────────────────────
    @in starting_cash::Float64 = 2_000_000.0
    @in loc_capacity::Float64 = 5_000_000.0
    @in loc_rate::Float64 = 0.065
    @in min_cash_threshold::Float64 = 500_000.0
    @in medicare_delay_weeks::Int = 0
    @in medicare_pct::Float64 = 0.45

    # ── Simplified weekly profile inputs (representative weeks) ────
    # Users enter weekly operating receipts and disbursements for weeks 1-13
    @in wk_receipts_1::Float64 = 800_000.0
    @in wk_receipts_2::Float64 = 750_000.0
    @in wk_receipts_3::Float64 = 700_000.0
    @in wk_receipts_4::Float64 = 850_000.0
    @in wk_receipts_5::Float64 = 780_000.0
    @in wk_receipts_6::Float64 = 720_000.0
    @in wk_receipts_7::Float64 = 800_000.0
    @in wk_receipts_8::Float64 = 760_000.0
    @in wk_receipts_9::Float64 = 810_000.0
    @in wk_receipts_10::Float64 = 790_000.0
    @in wk_receipts_11::Float64 = 830_000.0
    @in wk_receipts_12::Float64 = 770_000.0
    @in wk_receipts_13::Float64 = 820_000.0

    @in wk_disbursements_1::Float64 = 750_000.0
    @in wk_disbursements_2::Float64 = 780_000.0
    @in wk_disbursements_3::Float64 = 820_000.0
    @in wk_disbursements_4::Float64 = 760_000.0
    @in wk_disbursements_5::Float64 = 800_000.0
    @in wk_disbursements_6::Float64 = 790_000.0
    @in wk_disbursements_7::Float64 = 810_000.0
    @in wk_disbursements_8::Float64 = 850_000.0
    @in wk_disbursements_9::Float64 = 770_000.0
    @in wk_disbursements_10::Float64 = 800_000.0
    @in wk_disbursements_11::Float64 = 780_000.0
    @in wk_disbursements_12::Float64 = 810_000.0
    @in wk_disbursements_13::Float64 = 750_000.0

    @in recalculate::Bool = false

    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    # ── Outputs ────────────────────────────────────────────────────
    @out nadir_week::Int = 0
    @out nadir_amount_str::String = "\$0"
    @out total_loc_draws_str::String = "\$0"
    @out total_interest_str::String = "\$0"
    @out medicare_stress_str::String = "N/A"
    @out weekly_table::Vector{Dict{String,Any}} = Dict{String,Any}[]

    @out cash_chart_data::Vector{PlotData} = PlotData[]
    @out cash_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="13-Week Cash Position Forecast"),
        xaxis=[PlotLayoutAxis(title="Week")],
        yaxis=[PlotLayoutAxis(title="Cash (\$)")],
    )

    # ── Handler ────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false

            try
                # Build weekly profiles
                receipts = [wk_receipts_1, wk_receipts_2, wk_receipts_3, wk_receipts_4,
                            wk_receipts_5, wk_receipts_6, wk_receipts_7, wk_receipts_8,
                            wk_receipts_9, wk_receipts_10, wk_receipts_11, wk_receipts_12,
                            wk_receipts_13]
                disbursements = [wk_disbursements_1, wk_disbursements_2, wk_disbursements_3,
                                 wk_disbursements_4, wk_disbursements_5, wk_disbursements_6,
                                 wk_disbursements_7, wk_disbursements_8, wk_disbursements_9,
                                 wk_disbursements_10, wk_disbursements_11, wk_disbursements_12,
                                 wk_disbursements_13]

                profiles = [WeeklyProfile(week=i, operating_receipts=receipts[i],
                            operating_disbursements=disbursements[i])
                            for i in 1:13]

                input = TreasuryInput(
                    starting_cash=starting_cash,
                    weekly_profiles=profiles,
                    loc_capacity=loc_capacity,
                    loc_rate=loc_rate,
                    min_cash_threshold=min_cash_threshold,
                    medicare_delay_weeks=medicare_delay_weeks,
                    medicare_pct_of_receipts=medicare_pct,
                )
                result = forecast_treasury(input)

                nadir_week = result.nadir_week
                nadir_amount_str = "\$$(round(Int, result.nadir_amount) |> x -> string(x))"
                total_loc_draws_str = "\$$(round(Int, result.loc_draws) |> x -> string(x))"
                total_interest_str = "\$$(round(Int, result.interest_cost) |> x -> string(x))"
                medicare_stress_str = medicare_delay_weeks > 0 ?
                    "\$$(round(Int, result.medicare_stress_impact))" : "No stress test"

                # Build weekly table
                weekly_table = [Dict{String,Any}(
                    "week" => wb.week,
                    "beginning_cash" => round(Int, wb.beginning_cash),
                    "net_cash_flow" => round(Int, wb.net_cash_flow),
                    "loc_draw" => round(Int, wb.loc_draw),
                    "loc_repayment" => round(Int, wb.loc_repayment),
                    "ending_cash" => round(Int, wb.ending_cash),
                ) for wb in result.weekly_balances]

                # Build chart
                weeks = [wb.week for wb in result.weekly_balances]
                ending_cash = [wb.ending_cash for wb in result.weekly_balances]

                traces = PlotData[]
                push!(traces, PlotData(x=weeks, y=ending_cash, name="Ending Cash",
                    plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                    marker=Dict("color" => "#2196F3", "size" => 8),
                    fill="tozeroy",
                    fillcolor="rgba(33, 150, 243, 0.1)"))
                # Threshold line
                push!(traces, PlotData(x=[1, 13], y=[min_cash_threshold, min_cash_threshold],
                    name="Min Threshold", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                    marker=Dict("color" => "#F44336"), mode="lines",
                    line=Dict("dash" => "dash")))
                # Nadir marker
                nadir_bal = result.nadir_amount
                push!(traces, PlotData(x=[result.nadir_week], y=[nadir_bal],
                    name="Nadir", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                    mode="markers", marker=Dict("color" => "#F44336", "size" => 14, "symbol" => "diamond")))

                cash_chart_data = traces
                cash_chart_layout = PlotLayout(
                    title=PlotLayoutTitle(text="13-Week Cash Position Forecast"),
                    xaxis=[PlotLayoutAxis(title="Week", dtick=1)],
                    yaxis=[PlotLayoutAxis(title="Cash (\$)")],
                )

                @info "Treasury forecast: nadir=\$$(round(Int, result.nadir_amount)) @ wk$(result.nadir_week)"
            catch err
                nadir_week = 0
                nadir_amount_str = "Error"
                total_loc_draws_str = sprint(showerror, err)
                total_interest_str = ""
                medicare_stress_str = ""
                @error "Treasury forecast error" exception=(err, catch_backtrace())
            end
        end
    end
end

const treasury_forecast_model = @init
