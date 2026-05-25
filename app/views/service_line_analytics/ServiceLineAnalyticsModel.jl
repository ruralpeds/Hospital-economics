"""
Stipple reactive model for Service Line Analytics Dashboard.
Integrates Phase 4A AdvancedAnalytics for service line-level risk analysis.
"""
using Stipple, StippleUI, StipplePlotly
using Dates, Statistics

@app begin
    # ── UI State ────────────────────────────────────────────────────────────
    @in left_drawer_open::Bool = true

    # ── Export ──────────────────────────────────────────────────────────────
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false

    @in selected_service_line::String = "all"  # "all" or specific service line
    @in comparison_type::String = "cost_vs_risk"  # "cost_vs_risk", "quality", "volume"
    @in date_range_start::String = "2024-01-01"
    @in date_range_end::String = "2024-12-31"
    @in recalculate::Bool = false

    # ── Data Inputs ─────────────────────────────────────────────────────────
    @in service_line_data::Vector{Dict} = []  # Complete patient records with service line
    @in service_lines::Vector{String} = []  # Available service lines

    # ── Service Line Selection ──────────────────────────────────────────────
    @out selected_service_name::String = "All Service Lines"
    @out case_volume::Int = 0
    @out avg_cost::Float64 = 0.0
    @out avg_los::Float64 = 0.0
    @out quality_score::Float64 = 0.0
    @out readmission_rate::Float64 = 0.0
    @out mortality_rate::Float64 = 0.0
    @out avg_risk_score::Float64 = 0.0

    # ── Cost vs Risk Scatter Plot ───────────────────────────────────────────
    @out cost_vs_risk_scatter::Vector{PlotData} = []
    @out cost_vs_risk_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Cost vs Risk by Service Line"),
        xaxis = PlotLayoutAxis(title = "Average Risk Score"),
        yaxis = PlotLayoutAxis(title = "Average Cost (\$)"),
        hovermode = "closest"
    )

    # ── Service Line Comparison (Radar Chart) ───────────────────────────────
    @out comparison_radar::Vector{PlotData} = []
    @out comparison_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Service Line Performance Comparison"),
        polar = Dict("radialaxis" => Dict("visible" => true, "range" => [0, 100]))
    )

    # ── Key Metrics Cards ───────────────────────────────────────────────────
    @out metrics_data::Vector{Dict} = []

    # ── Case Volume & Trend ─────────────────────────────────────────────────
    @out case_volume_trend::Vector{PlotData} = []
    @out case_volume_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Case Volume Trend"),
        xaxis = PlotLayoutAxis(title = "Month"),
        yaxis = PlotLayoutAxis(title = "Cases")
    )

    # ── Cost Efficiency (Cost per Quality Point) ───────────────────────────
    @out cost_efficiency::Dict = Dict("efficiency_score" => 0.0, "rank" => 0, "percentile" => 0.0)

    # ── Top Risk Factors by Service Line ────────────────────────────────────
    @out top_risk_factors::Vector{Dict} = []

    # ── Service Line Comparison Table ───────────────────────────────────────
    @out comparison_table::Vector{Dict} = []
    @out comparison_columns::Vector{Dict} = [
        Dict("name" => "service_line", "label" => "Service Line", "field" => "service_line", "align" => "left"),
        Dict("name" => "case_volume", "label" => "Cases", "field" => "case_volume", "align" => "center"),
        Dict("name" => "avg_cost", "label" => "Avg Cost", "field" => "avg_cost", "align" => "right", "format" => "\$#,##0"),
        Dict("name" => "avg_los", "label" => "Avg LOS", "field" => "avg_los", "align" => "center", "format" => "{value:.1f}"),
        Dict("name" => "quality_score", "label" => "Quality", "field" => "quality_score", "align" => "center", "format" => "{value:.0%}"),
        Dict("name" => "readmission_rate", "label" => "Readmission", "field" => "readmission_rate", "align" => "center", "format" => "{value:.0%}"),
        Dict("name" => "avg_risk_score", "label" => "Avg Risk", "field" => "avg_risk_score", "align" => "center", "format" => "{value:.0%}"),
    ]

    # ── Handlers ────────────────────────────────────────────────────────────
    @onchange recalculate, selected_service_line, comparison_type begin
        if recalculate || !isempty(service_line_data)
            recalculate = false

            # Get all service lines from data
            all_sls = unique([get(p, "service_line", "Unknown") for p in service_line_data])
            sls = filter(!isempty, all_sls)

            if isempty(sls)
                return
            end

            # Filter data by selected service line
            if selected_service_line == "all"
                filtered_data = service_line_data
                selected_service_name = "All Service Lines"
            else
                filtered_data = filter(p -> get(p, "service_line", "Unknown") == selected_service_line, service_line_data)
                selected_service_name = selected_service_line
            end

            # Calculate service line metrics
            case_volume = length(filtered_data)
            if case_volume > 0
                avg_cost = mean([get(p, "total_cost", 0.0) for p in filtered_data])
                avg_los = mean([get(p, "los", 0) for p in filtered_data])
                quality_score = mean([get(p, "quality_score", 0.0) for p in filtered_data])
                readmission_rate = mean([get(p, "readmission_risk", 0.0) for p in filtered_data])
                mortality_rate = mean([get(p, "mortality_rate", 0.0) for p in filtered_data])
                avg_risk_score = mean([get(p, "risk_score", 0.0) for p in filtered_data])
            else
                avg_cost = 0.0
                avg_los = 0.0
                quality_score = 0.0
                readmission_rate = 0.0
                mortality_rate = 0.0
                avg_risk_score = 0.0
            end

            # Build cost vs risk scatter plot (all service lines)
            if comparison_type == "cost_vs_risk"
                scatter_x = []
                scatter_y = []
                scatter_text = []
                scatter_color = []

                for sl in sls
                    sl_data = filter(p -> get(p, "service_line", "Unknown") == sl, service_line_data)
                    if !isempty(sl_data)
                        sl_avg_risk = mean([get(p, "risk_score", 0.0) for p in sl_data])
                        sl_avg_cost = mean([get(p, "total_cost", 0.0) for p in sl_data])
                        push!(scatter_x, sl_avg_risk)
                        push!(scatter_y, sl_avg_cost)
                        push!(scatter_text, sl)
                        # Color by volume
                        push!(scatter_color, length(sl_data))
                    end
                end

                cost_vs_risk_scatter = [
                    PlotData(x=scatter_x, y=scatter_y, text=scatter_text, mode="markers",
                        marker=PlotDataMarker(
                            size=8,
                            color=scatter_color,
                            colorscale="Viridis",
                            showscale=true,
                            colorbar=Dict("title" => "Case Volume")
                        ),
                        plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER
                    )
                ]
            end

            # Build comparison radar chart
            if !isempty(sls) && length(sls) > 1
                # Get metrics for top 4 service lines by volume
                volume_ranks = sort([(sl, count(p -> get(p, "service_line", "Unknown") == sl, service_line_data)) for sl in sls],
                    by=x -> x[2], rev=true)
                top_sls = [x[1] for x in volume_ranks[1:min(4, length(volume_ranks))]]

                # Prepare radar data (normalize to 0-100 scale)
                categories = ["Cost", "Quality", "Volume", "LOS", "Risk"]
                for sl in top_sls
                    sl_data = filter(p -> get(p, "service_line", "Unknown") == sl, service_line_data)
                    if !isempty(sl_data)
                        # Normalize each metric to 0-100
                        cost_norm = 100.0 - clamp(mean([get(p, "total_cost", 0.0) for p in sl_data]) / 200.0, 0.0, 100.0)  # Inverse (lower is better)
                        quality_norm = clamp(100.0 * mean([get(p, "quality_score", 0.0) for p in sl_data]), 0.0, 100.0)
                        volume_norm = clamp(length(sl_data) * 100.0 / 50.0, 0.0, 100.0)  # Normalize to ~50 cases
                        los_norm = 100.0 - clamp(mean([get(p, "los", 0) for p in sl_data]) * 10.0, 0.0, 100.0)  # Inverse
                        risk_norm = 100.0 - clamp(100.0 * mean([get(p, "risk_score", 0.0) for p in sl_data]), 0.0, 100.0)  # Inverse

                        push!(comparison_radar,
                            PlotData(r=[cost_norm, quality_norm, volume_norm, los_norm, risk_norm],
                                theta=categories,
                                plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR,
                                fill="toself", name=sl,
                                hoverinfo="r+theta"
                            )
                        )
                    end
                end
            end

            # Build service line comparison table
            comparison_table = []
            for sl in sls
                sl_data = filter(p -> get(p, "service_line", "Unknown") == sl, service_line_data)
                if !isempty(sl_data)
                    push!(comparison_table, Dict(
                        "service_line" => sl,
                        "case_volume" => length(sl_data),
                        "avg_cost" => mean([get(p, "total_cost", 0.0) for p in sl_data]),
                        "avg_los" => mean([get(p, "los", 0) for p in sl_data]),
                        "quality_score" => mean([get(p, "quality_score", 0.0) for p in sl_data]),
                        "readmission_rate" => mean([get(p, "readmission_risk", 0.0) for p in sl_data]),
                        "avg_risk_score" => mean([get(p, "risk_score", 0.0) for p in sl_data])
                    ))
                end
            end

            # Sort by case volume (descending)
            sort!(comparison_table, by=d -> d["case_volume"], rev=true)

            # Calculate cost efficiency for selected service line
            if case_volume > 0
                cost_per_quality = avg_cost / clamp(quality_score, 0.1, 1.0)
                all_efficiencies = [
                    (sl, mean([get(p, "total_cost", 0.0) for p in filter(p -> get(p, "service_line", "Unknown") == sl, service_line_data)]) /
                          clamp(mean([get(p, "quality_score", 0.0) for p in filter(p -> get(p, "service_line", "Unknown") == sl, service_line_data)]), 0.1, 1.0))
                    for sl in sls
                ]
                sorted_efficiency = sort(all_efficiencies, by=x -> x[2])
                rank = findfirst(x -> x[1] == selected_service_line || selected_service_line == "all", sorted_efficiency)
                rank = isnothing(rank) ? length(sorted_efficiency) : rank
                percentile = (1.0 - (rank - 1) / max(length(sorted_efficiency) - 1, 1)) * 100.0

                cost_efficiency = Dict(
                    "efficiency_score" => cost_per_quality,
                    "rank" => rank,
                    "percentile" => percentile
                )
            end

            # Identify top risk factors for selected service line
            if case_volume > 0
                risk_counts = Dict{String,Int}()
                for p in filtered_data
                    if get(p, "risk_score", 0.0) > 0.5
                        get(p, "age", 65) > 75 && (risk_counts["Age > 75"] = get(risk_counts, "Age > 75", 0) + 1)
                        get(p, "comorbidity_count", 0) > 2 && (risk_counts["High Comorbidities"] = get(risk_counts, "High Comorbidities", 0) + 1)
                        get(p, "total_cost", 0.0) > 10000.0 && (risk_counts["High Cost"] = get(risk_counts, "High Cost", 0) + 1)
                        get(p, "readmission_risk", 0.0) > 0.5 && (risk_counts["Readmission Risk"] = get(risk_counts, "Readmission Risk", 0) + 1)
                    end
                end

                if !isempty(risk_counts)
                    top_factors = sort(collect(risk_counts), by=x -> x[2], rev=true)[1:min(5, length(risk_counts))]
                    top_risk_factors = [Dict("factor" => f, "count" => c) for (f, c) in top_factors]
                end
            end

            # Build metrics cards
            metrics_data = [
                Dict("label" => "Case Volume", "value" => case_volume, "color" => "blue"),
                Dict("label" => "Avg Cost", "value" => "\$" * string(Int(round(avg_cost))), "color" => "purple"),
                Dict("label" => "Avg LOS", "value" => string(round(avg_los; digits=1)) * " days", "color" => "orange"),
                Dict("label" => "Quality Score", "value" => string(round(quality_score * 100; digits=0)) * "%", "color" => "green"),
                Dict("label" => "Readmission Rate", "value" => string(round(readmission_rate * 100; digits=0)) * "%", "color" => "red"),
                Dict("label" => "Avg Risk", "value" => string(round(avg_risk_score * 100; digits=0)) * "%", "color" => "orange"),
            ]
        end
    end
end
