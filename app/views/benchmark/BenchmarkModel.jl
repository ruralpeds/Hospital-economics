"""
Stipple reactive model for Benchmarking Radar.
Delegates to RuralHospitalSim.compare_to_benchmarks() for percentile comparison.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: default_cah_benchmarks, compare_to_benchmarks, BenchmarkData


@app begin
    @in left_drawer_open::Bool = true
    # ── Metric Inputs (6 key metrics) ───────────────────────────────────
    @in metric_operating_margin::Float64 = -3.8
    @in metric_days_cash::Float64 = 42.0
    @in metric_current_ratio::Float64 = 1.35
    @in metric_occupancy::Float64 = 33.2
    @in metric_fte_per_aob::Float64 = 5.8
    @in metric_avg_age_plant::Float64 = 14.2
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    @out composite_score::Float64 = 38.0
    @out metrics_above_median::Int = 1
    @out metrics_below_median::Int = 5
    @out weakest_area::String = "Operating Margin"
    @out strongest_area::String = "FTE/AOB"

    @out metric_cards::Vector{Dict{String,Any}} = [
        Dict("name"=>"Operating Margin", "value"=>-3.8, "p50"=>-1.2, "p75"=>2.5,
             "unit"=>"%", "status"=>"below"),
        Dict("name"=>"Days Cash", "value"=>42.0, "p50"=>58.0, "p75"=>95.0,
             "unit"=>"days", "status"=>"below"),
        Dict("name"=>"Current Ratio", "value"=>1.35, "p50"=>1.65, "p75"=>2.10,
             "unit"=>"x", "status"=>"below"),
        Dict("name"=>"Occupancy", "value"=>33.2, "p50"=>38.5, "p75"=>52.0,
             "unit"=>"%", "status"=>"below"),
        Dict("name"=>"FTE/AOB", "value"=>5.8, "p50"=>5.2, "p75"=>4.5,
             "unit"=>"", "status"=>"above"),
        Dict("name"=>"Avg Age of Plant", "value"=>14.2, "p50"=>12.0, "p75"=>8.5,
             "unit"=>"yrs", "status"=>"below"),
    ]

    # ── Radar Chart Data ────────────────────────────────────────────────
    @out radar_chart_data::Vector{PlotData} = [
        PlotData(r=[22, 45, 55, 42, 65, 38],
            theta=["Op Margin", "Days Cash", "Current Ratio", "Occupancy", "FTE/AOB", "Age of Plant"],
            plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR,
            fill="toself", name="Your Hospital",
            fillcolor="rgba(33,150,243,0.2)", line=PlotDataLine(color="#2196F3")),
        PlotData(r=[50, 50, 50, 50, 50, 50],
            theta=["Op Margin", "Days Cash", "Current Ratio", "Occupancy", "FTE/AOB", "Age of Plant"],
            plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR,
            fill="toself", name="50th Percentile",
            fillcolor="rgba(255,152,0,0.1)", line=PlotDataLine(color="orange", dash="dash")),
        PlotData(r=[75, 75, 75, 75, 75, 75],
            theta=["Op Margin", "Days Cash", "Current Ratio", "Occupancy", "FTE/AOB", "Age of Plant"],
            plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR,
            fill="toself", name="75th Percentile",
            fillcolor="rgba(76,175,80,0.05)", line=PlotDataLine(color="green", dash="dot")),
    ]
    @out radar_chart_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Benchmarking Radar"),
        polar = Dict("radialaxis" => Dict("visible" => true, "range" => [0, 100])),
    )

    # ── Handlers ────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false

            # Build metrics dict for domain engine
            hospital_metrics = Dict{String,Float64}(
                "operating_margin"   => metric_operating_margin / 100.0,  # input is %, domain expects ratio
                "days_cash_on_hand"  => metric_days_cash,
                "current_ratio"      => metric_current_ratio,
                "occupancy_rate"     => metric_occupancy / 100.0,
                "fte_per_aob"        => metric_fte_per_aob,
                "average_age_of_plant" => metric_avg_age_plant,
            )

            # Call domain engine
            benchmarks = default_cah_benchmarks()
            comparisons = compare_to_benchmarks(hospital_metrics, benchmarks)

            # Map to percentile scores (0-100 scale)
            labels = ["Op Margin", "Days Cash", "Current Ratio", "Occupancy", "FTE/AOB", "Age of Plant"]
            p50_vals = [-1.2, 58.0, 1.65, 38.5, 5.2, 12.0]
            p75_vals = [2.5, 95.0, 2.10, 52.0, 4.5, 8.5]
            actual = [metric_operating_margin, metric_days_cash, metric_current_ratio,
                      metric_occupancy, metric_fte_per_aob, metric_avg_age_plant]
            lower_better = [false, false, false, false, true, true]

            scores = Float64[]
            cards = Dict{String,Any}[]
            for i in 1:6
                if lower_better[i]
                    score = clamp((p50_vals[i] - actual[i]) / max(p50_vals[i] - p75_vals[i], 0.01) * 25 + 50, 0, 100)
                else
                    score = clamp((actual[i] - p50_vals[i]) / max(p75_vals[i] - p50_vals[i], 0.01) * 25 + 50, 0, 100)
                end
                push!(scores, round(score, digits=0))
                status = score >= 50 ? "above" : "below"
                units = ["%" , "days", "x", "%", "", "yrs"]
                push!(cards, Dict{String,Any}("name"=>labels[i], "value"=>actual[i],
                    "p50"=>p50_vals[i], "p75"=>p75_vals[i], "unit"=>units[i], "status"=>status))
            end

            composite_score = round(sum(scores) / 6, digits=0)
            metrics_above_median = count(s -> s >= 50, scores)
            metrics_below_median = count(s -> s < 50, scores)
            metric_cards = cards

            # Find weakest/strongest
            min_idx = argmin(scores)
            max_idx = argmax(scores)
            weakest_area = labels[min_idx]
            strongest_area = labels[max_idx]

            radar_chart_data = [
                PlotData(r=scores, theta=labels, plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR,
                    fill="toself", name="Your Hospital",
                    fillcolor="rgba(33,150,243,0.2)", line=PlotDataLine(color="#2196F3")),
                PlotData(r=fill(50.0, 6), theta=labels, plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR,
                    fill="toself", name="50th Percentile",
                    fillcolor="rgba(255,152,0,0.1)", line=PlotDataLine(color="orange", dash="dash")),
                PlotData(r=fill(75.0, 6), theta=labels, plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR,
                    fill="toself", name="75th Percentile",
                    fillcolor="rgba(76,175,80,0.05)", line=PlotDataLine(color="green", dash="dot")),
            ]
            @info "Benchmark: composite=$(composite_score), $(metrics_above_median) above median, weakest=$(weakest_area)"
        end
    end
end

const benchmark_model = @init
