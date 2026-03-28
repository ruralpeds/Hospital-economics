"""
Stipple reactive model for Break-Even Analysis.
Calculates break-even volume with fixed/variable cost structure.
"""
using Stipple, StippleUI, StipplePlotly


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in fixed_costs::Float64 = 12_500_000.0
    @in variable_cost_per_encounter::Float64 = 280.0
    @in revenue_per_encounter::Float64 = 450.0
    @in current_volume::Int = 82_000
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out break_even_volume::Int = 73_529
    @out contribution_margin_per_unit::Float64 = 170.0
    @out current_net_income::Float64 = 1_440_000.0
    @out cushion_pct::Float64 = 0.115
    @out cushion_encounters::Int = 8_471
    @out margin_of_safety::Float64 = 0.103

    # ── Chart Data ──────────────────────────────────────────────────────
    @out breakeven_chart_data::Vector{PlotData} = [
        PlotData(
            x = [0, 30000, 50000, 73529, 82000, 100000],
            y = [0.0, 13.5, 22.5, 33.1, 36.9, 45.0],
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "Total Revenue (\$M)",
            mode = "lines",
            line = PlotDataLine(color="#4CAF50"),
        ),
        PlotData(
            x = [0, 30000, 50000, 73529, 82000, 100000],
            y = [12.5, 20.9, 26.5, 33.1, 35.5, 40.5],
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "Total Cost (\$M)",
            mode = "lines",
            line = PlotDataLine(color="#F44336"),
        ),
        PlotData(
            x = [73529],
            y = [33.1],
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "Break-Even Point",
            mode = "markers",
            marker = Dict("size" => 14, "color" => "orange", "symbol" => "diamond"),
        ),
    ]
    @out breakeven_chart_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Break-Even Analysis"),
        xaxis = [PlotLayoutAxis(title = "Patient Encounters")],
        yaxis = [PlotLayoutAxis(title = "\$ Millions")],
    )

    # ── Handlers ────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false
            contribution_margin_per_unit = revenue_per_encounter - variable_cost_per_encounter
            break_even_volume = contribution_margin_per_unit > 0 ?
                round(Int, fixed_costs / contribution_margin_per_unit) : 999_999
            current_net_income = current_volume * contribution_margin_per_unit - fixed_costs
            cushion_encounters = max(0, current_volume - break_even_volume)
            cushion_pct = round(cushion_encounters / max(current_volume, 1), digits=3)
            margin_of_safety = cushion_pct

            # Build chart points
            max_vol = round(Int, break_even_volume * 1.5)
            volumes = [0, round(Int, max_vol*0.3), round(Int, max_vol*0.5),
                       break_even_volume, current_volume, max_vol]
            revenues = [v * revenue_per_encounter / 1e6 for v in volumes]
            costs = [(fixed_costs + v * variable_cost_per_encounter) / 1e6 for v in volumes]
            be_rev = break_even_volume * revenue_per_encounter / 1e6

            breakeven_chart_data = [
                PlotData(x=volumes, y=round.(revenues, digits=1),
                    plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER, name="Total Revenue (\$M)",
                    mode="lines", line=PlotDataLine(color="#4CAF50")),
                PlotData(x=volumes, y=round.(costs, digits=1),
                    plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER, name="Total Cost (\$M)",
                    mode="lines", line=PlotDataLine(color="#F44336")),
                PlotData(x=[break_even_volume], y=[round(be_rev, digits=1)],
                    plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER, name="Break-Even Point",
                    mode="markers", marker=Dict("size"=>14, "color"=>"orange", "symbol"=>"diamond")),
            ]
            @info "Break-even at $(break_even_volume) encounters, cushion $(round(cushion_pct*100, digits=1))%"
        end
    end
end

const break_even_model = @init
