"""
Stipple reactive model for Workforce RVU Analysis.
Compares provider wRVU production against benchmarks and compensation.
"""
using Stipple, StippleUI, StipplePlotly


@app begin
    @in left_drawer_open::Bool = true
    # ── Provider Inputs (5 providers) ───────────────────────────────────
    @in prov1_name::String = "Dr. Smith (FM)"
    @in prov1_wrvus::Float64 = 4200.0
    @in prov1_comp::Float64 = 280_000.0
    @in prov2_name::String = "Dr. Jones (FM)"
    @in prov2_wrvus::Float64 = 3800.0
    @in prov2_comp::Float64 = 265_000.0
    @in prov3_name::String = "Dr. Chen (IM)"
    @in prov3_wrvus::Float64 = 4500.0
    @in prov3_comp::Float64 = 310_000.0
    @in prov4_name::String = "NP Williams"
    @in prov4_wrvus::Float64 = 2800.0
    @in prov4_comp::Float64 = 145_000.0
    @in prov5_name::String = "PA Garcia"
    @in prov5_wrvus::Float64 = 2600.0
    @in prov5_comp::Float64 = 135_000.0

    @in benchmark_50th_wrvu::Float64 = 4200.0
    @in benchmark_75th_wrvu::Float64 = 5200.0
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out cost_per_wrvu::Vector{Float64} = [66.67, 69.74, 68.89, 51.79, 51.92]
    @out production_vs_benchmark::Vector{Float64} = [100.0, 90.5, 107.1, 66.7, 61.9]
    @out total_wrvus::Float64 = 17_900.0
    @out avg_cost_per_wrvu::Float64 = 63.41
    @out total_compensation::Float64 = 1_135_000.0
    @out benchmark_median_cost::Float64 = 62.00

    # ── Chart Data ──────────────────────────────────────────────────────
    @out wrvu_comparison_data::Vector{PlotData} = [
        PlotData(
            x = ["Dr. Smith", "Dr. Jones", "Dr. Chen", "NP Williams", "PA Garcia"],
            y = [4200, 3800, 4500, 2800, 2600],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Actual wRVUs"),
        PlotData(
            x = ["Dr. Smith", "Dr. Jones", "Dr. Chen", "NP Williams", "PA Garcia"],
            y = [4200, 4200, 4200, 4200, 4200],
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "50th Percentile",
            mode = "lines",
            line = PlotDataLine(dash="dash", color="orange")),
        PlotData(
            x = ["Dr. Smith", "Dr. Jones", "Dr. Chen", "NP Williams", "PA Garcia"],
            y = [5200, 5200, 5200, 5200, 5200],
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "75th Percentile",
            mode = "lines",
            line = PlotDataLine(dash="dot", color="red")),
    ]
    @out wrvu_comparison_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Provider wRVU Production vs Benchmarks"),
        xaxis = [PlotLayoutAxis(title = "Provider")],
        yaxis = [PlotLayoutAxis(title = "wRVUs")],
    )

    @out cost_wrvu_data::Vector{PlotData} = [
        PlotData(
            x = ["Dr. Smith", "Dr. Jones", "Dr. Chen", "NP Williams", "PA Garcia"],
            y = [66.67, 69.74, 68.89, 51.79, 51.92],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Cost per wRVU"),
    ]
    @out cost_wrvu_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Cost per wRVU by Provider"),
        xaxis = [PlotLayoutAxis(title = "Provider")],
        yaxis = [PlotLayoutAxis(title = "\$/wRVU")],
    )

    # ── Handlers ────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false
            wrvus = [prov1_wrvus, prov2_wrvus, prov3_wrvus, prov4_wrvus, prov5_wrvus]
            comps = [prov1_comp, prov2_comp, prov3_comp, prov4_comp, prov5_comp]
            names = [prov1_name, prov2_name, prov3_name, prov4_name, prov5_name]

            cost_per_wrvu = round.(comps ./ max.(wrvus, 1.0), digits=2)
            production_vs_benchmark = round.(wrvus ./ benchmark_50th_wrvu .* 100, digits=1)
            total_wrvus = sum(wrvus)
            total_compensation = sum(comps)
            avg_cost_per_wrvu = round(total_compensation / max(total_wrvus, 1.0), digits=2)

            wrvu_comparison_data = [
                PlotData(x=names, y=wrvus, plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Actual wRVUs"),
                PlotData(x=names, y=fill(benchmark_50th_wrvu, 5), plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                    name="50th Percentile", mode="lines", line=PlotDataLine(dash="dash", color="orange")),
                PlotData(x=names, y=fill(benchmark_75th_wrvu, 5), plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                    name="75th Percentile", mode="lines", line=PlotDataLine(dash="dot", color="red")),
            ]
            cost_wrvu_data = [PlotData(x=names, y=cost_per_wrvu,
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Cost per wRVU")]
            @info "Workforce RVU analysis complete: $(total_wrvus) total wRVUs"
        end
    end
end

const workforce_rvu_model = @init
