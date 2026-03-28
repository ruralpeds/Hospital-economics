"""
Stipple reactive model for the Results Explorer.
Manages simulation result display, comparison, and export.
"""
using Stipple, StippleUI, StipplePlotly


@app begin
    @in left_drawer_open::Bool = true
    # ── Simulation Selection ─────────────────────────────────────────────
    @in selected_simulation::String = "sim_10001"
    @in comparison_simulation::String = ""
    @in show_comparison::Bool = false
    @out simulation_list::Vector{Dict{String,Any}} = [
        Dict("label"=>"Baseline (sim_10001)", "value"=>"sim_10001",
             "scenario"=>"Baseline", "date"=>"2026-03-15"),
        Dict("label"=>"REH Conversion (sim_10002)", "value"=>"sim_10002",
             "scenario"=>"REH Conversion", "date"=>"2026-03-18"),
        Dict("label"=>"Telehealth (sim_10003)", "value"=>"sim_10003",
             "scenario"=>"Telehealth Expansion", "date"=>"2026-03-22"),
    ]

    # ── Display Controls ─────────────────────────────────────────────────
    @in active_tab::String = "summary"
    @in chart_type::String = "line"
    @in show_confidence_bands::Bool = true
    @in show_percentiles::Bool = true
    @in export_format::String = "csv"
    @in trigger_export::Bool = false

    # ── Summary Statistics ───────────────────────────────────────────────
    @out mean_operating_margin::Float64 = -0.025
    @out median_operating_margin::Float64 = -0.022
    @out p10_margin::Float64 = -0.089
    @out p25_margin::Float64 = -0.055
    @out p75_margin::Float64 = 0.008
    @out p90_margin::Float64 = 0.031
    @out prob_positive_margin::Float64 = 0.32
    @out prob_closure_risk::Float64 = 0.18
    @out breakeven_year::Int = 2028
    @out npv_10yr::Float64 = -2_340_000.0
    @out irr::Float64 = -0.032
    @out payback_period::Float64 = 4.2
    @out mean_days_cash::Int = 38
    @out mean_revenue_year5::Float64 = 20_600_000.0
    @out mean_expense_year5::Float64 = 20_200_000.0

    # ── Comparison Summary ───────────────────────────────────────────────
    @out comp_mean_margin::Float64 = 0.015
    @out comp_npv::Float64 = 1_250_000.0
    @out comp_prob_positive::Float64 = 0.68
    @out comp_prob_closure::Float64 = 0.05

    # ── Annual Projections Table ─────────────────────────────────────────
    @out projection_rows::Vector{Dict{String,Any}} = [
        Dict("year"=>2026, "revenue"=>18_800_000, "expenses"=>19_100_000,
             "margin"=>-0.016, "cash_flow"=>-180_000, "cum_cash"=>2_020_000),
        Dict("year"=>2027, "revenue"=>19_200_000, "expenses"=>19_400_000,
             "margin"=>-0.010, "cash_flow"=>-80_000, "cum_cash"=>1_940_000),
        Dict("year"=>2028, "revenue"=>19_700_000, "expenses"=>19_650_000,
             "margin"=>0.003, "cash_flow"=>120_000, "cum_cash"=>2_060_000),
        Dict("year"=>2029, "revenue"=>20_100_000, "expenses"=>19_900_000,
             "margin"=>0.010, "cash_flow"=>280_000, "cum_cash"=>2_340_000),
        Dict("year"=>2030, "revenue"=>20_600_000, "expenses"=>20_200_000,
             "margin"=>0.019, "cash_flow"=>480_000, "cum_cash"=>2_820_000),
    ]

    # ── Chart: Margin Fan Chart ──────────────────────────────────────────
    @out margin_fan_data::Vector{PlotData} = [
        PlotData(x=["2026","2027","2028","2029","2030"],
                 y=[-0.089, -0.075, -0.058, -0.042, -0.028],
                 plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                 name="P10", mode="lines", line=PlotDataLine(dash="dot", color="rgba(255,0,0,0.3)")),
        PlotData(x=["2026","2027","2028","2029","2030"],
                 y=[-0.025, -0.018, -0.005, 0.008, 0.019],
                 plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                 name="Mean", mode="lines+markers", line=PlotDataLine(color="blue", width=3)),
        PlotData(x=["2026","2027","2028","2029","2030"],
                 y=[0.031, 0.038, 0.048, 0.058, 0.068],
                 plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                 name="P90", mode="lines", line=PlotDataLine(dash="dot", color="rgba(0,128,0,0.3)")),
    ]
    @out margin_fan_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Operating Margin Projection (with uncertainty)"),
        xaxis=[PlotLayoutAxis(title="Year")],
        yaxis=[PlotLayoutAxis(title="Operating Margin", tickformat=".1%")],
        showlegend=true,
    )

    # ── Chart: Revenue vs Expense Projection ─────────────────────────────
    @out rev_exp_projection_data::Vector{PlotData} = [
        PlotData(x=["2026","2027","2028","2029","2030"],
                 y=[18.8, 19.2, 19.7, 20.1, 20.6],
                 plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                 name="Revenue (\$M)", mode="lines+markers"),
        PlotData(x=["2026","2027","2028","2029","2030"],
                 y=[19.1, 19.4, 19.65, 19.9, 20.2],
                 plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                 name="Expenses (\$M)", mode="lines+markers"),
    ]
    @out rev_exp_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Revenue vs Expenses Projection"),
        xaxis=[PlotLayoutAxis(title="Year")],
        yaxis=[PlotLayoutAxis(title="\$ Millions")],
    )

    # ── Chart: Histogram of Terminal Margin ──────────────────────────────
    @out margin_histogram_data::Vector{PlotData} = [
        PlotData(x=randn(1000) .* 0.04 .+ 0.019,
                 plot=StipplePlotly.Charts.PLOT_TYPE_HISTOGRAM,
                 name="Year-5 Margin Distribution",
                 nbinsx=40),
    ]
    @out margin_histogram_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Distribution of Year-5 Operating Margin"),
        xaxis=[PlotLayoutAxis(title="Operating Margin", tickformat=".1%")],
        yaxis=[PlotLayoutAxis(title="Frequency")],
    )

    # ── Chart: Tornado / Sensitivity ─────────────────────────────────────
    @out tornado_data::Vector{PlotData} = [
        PlotData(
            y=["Medicare Rate","Revenue Growth","Volume Change","Salary Increase","Supply Inflation","Discount Rate"],
            x=[0.028, 0.025, 0.022, -0.018, -0.012, -0.008],
            plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
            orientation="h", name="Impact on Margin",
            marker=PlotDataMarker(color=["green","green","green","red","red","red"])),
    ]
    @out tornado_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Sensitivity Analysis — Tornado Chart"),
        xaxis=[PlotLayoutAxis(title="Impact on Operating Margin", tickformat=".1%")],
    )

    # ── Handlers ─────────────────────────────────────────────────────────
    @onchange selected_simulation begin
        @info "Loading results for simulation: $selected_simulation"
        # In production, this would fetch from the simulation results store
    end

    @onchange show_comparison begin
        if show_comparison && !isempty(comparison_simulation)
            @info "Loading comparison: $comparison_simulation"
        end
    end

    @onchange trigger_export begin
        if trigger_export
            trigger_export = false
            @info "Exporting results as $export_format for $selected_simulation"
        end
    end
end

const results_model = @init
