"""
Stipple reactive model for Cohort Risk Distribution Dashboard.
Analyzes risk score distribution and percentiles by aggregation level.
"""
using Stipple, StippleUI, StipplePlotly
using Dates, Statistics

@app begin
    @in cohort_name::String = "all"
    @in aggregation_level::String = "overall"  # "overall", "service_line", "age_group"
    @in recalculate::Bool = false

    @in cohort_data::Vector{Dict} = []

    # ── Summary Statistics ──────────────────────────────────────────────────
    @out p10::Float64 = 0.0
    @out p25::Float64 = 0.0
    @out p50::Float64 = 0.0
    @out p75::Float64 = 0.0
    @out p90::Float64 = 0.0
    @out mean_risk::Float64 = 0.0
    @out std_risk::Float64 = 0.0

    # ── Risk Percentile Chart ───────────────────────────────────────────────
    @out percentile_chart::Vector{PlotData} = []
    @out percentile_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Risk Score Percentiles"),
        xaxis = PlotLayoutAxis(title = "Percentile"),
        yaxis = PlotLayoutAxis(title = "Risk Score")
    )

    # ── Risk Trend Over Time ────────────────────────────────────────────────
    @out risk_trend::Vector{PlotData} = []
    @out trend_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Risk Trend Over Time"),
        xaxis = PlotLayoutAxis(title = "Period"),
        yaxis = PlotLayoutAxis(title = "Average Risk Score")
    )

    # ── Comorbidity-Risk Correlation ────────────────────────────────────────
    @out comorbidity_correlation::Vector{PlotData} = []
    @out comorbidity_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Comorbidity Count vs Risk Score"),
        xaxis = PlotLayoutAxis(title = "Comorbidity Count"),
        yaxis = PlotLayoutAxis(title = "Risk Score")
    )

    # ── Cost Anomaly Distribution ───────────────────────────────────────────
    @out anomaly_distribution::Vector{PlotData} = []
    @out anomaly_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Cost Anomaly Distribution"),
        xaxis = PlotLayoutAxis(title = "Cost Level"),
        yaxis = PlotLayoutAxis(title = "Count")
    )

    # ── Aggregation Results ─────────────────────────────────────────────────
    @out aggregated_results::Vector{Dict} = []

    # ── Handlers ────────────────────────────────────────────────────────────
    @onchange recalculate, aggregation_level begin
        if recalculate || !isempty(cohort_data)
            recalculate = false

            if isempty(cohort_data)
                return
            end

            risk_scores = [get(p, "risk_score", 0.0) for p in cohort_data]

            if !isempty(risk_scores)
                p10 = quantile(risk_scores, 0.1)
                p25 = quantile(risk_scores, 0.25)
                p50 = quantile(risk_scores, 0.5)
                p75 = quantile(risk_scores, 0.75)
                p90 = quantile(risk_scores, 0.9)
                mean_risk = mean(risk_scores)
                std_risk = std(risk_scores)

                # Percentile chart
                percentiles = ["10%", "25%", "50%", "75%", "90%"]
                values = [p10, p25, p50, p75, p90]
                percentile_chart = [
                    PlotData(x=percentiles, y=values, plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        marker=PlotDataMarker(color="rgba(33,150,243,0.6)"))
                ]

                # Comorbidity correlation scatter
                comorbidity_counts = [get(p, "comorbidity_count", 0) for p in cohort_data]
                if !isempty(comorbidity_counts) && !all(==(0), comorbidity_counts)
                    comorbidity_correlation = [
                        PlotData(x=comorbidity_counts, y=risk_scores,
                            mode="markers", plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                            marker=PlotDataMarker(size=6, color="rgba(76,175,80,0.5)"))
                    ]
                end

                # Anomaly distribution
                cost_levels = String[]
                cost_counts = Int[]
                high_cost_count = count(p -> get(p, "total_cost", 0.0) > 10000.0, cohort_data)
                normal_cost_count = count(p -> 5000.0 <= get(p, "total_cost", 0.0) <= 10000.0, cohort_data)
                low_cost_count = count(p -> get(p, "total_cost", 0.0) < 5000.0, cohort_data)
                push!(cost_levels, "Low (<5K)")
                push!(cost_levels, "Normal (5-10K)")
                push!(cost_levels, "High (>10K)")
                push!(cost_counts, low_cost_count)
                push!(cost_counts, normal_cost_count)
                push!(cost_counts, high_cost_count)

                anomaly_distribution = [
                    PlotData(x=cost_levels, y=cost_counts, plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        marker=PlotDataMarker(color="rgba(244,67,54,0.6)"))
                ]

                # Aggregation by level
                if aggregation_level == "age_group"
                    age_groups = ["<65", "65-74", "75-84", "85+"]
                    aggregated_results = []
                    for ag in age_groups
                        if ag == "<65"
                            group_data = filter(p -> get(p, "age", 65) < 65, cohort_data)
                        elseif ag == "65-74"
                            group_data = filter(p -> 65 <= get(p, "age", 65) < 75, cohort_data)
                        elseif ag == "75-84"
                            group_data = filter(p -> 75 <= get(p, "age", 65) < 85, cohort_data)
                        else
                            group_data = filter(p -> get(p, "age", 65) >= 85, cohort_data)
                        end

                        if !isempty(group_data)
                            group_risks = [get(p, "risk_score", 0.0) for p in group_data]
                            push!(aggregated_results, Dict(
                                "group" => ag,
                                "count" => length(group_data),
                                "p50" => quantile(group_risks, 0.5),
                                "mean" => mean(group_risks),
                                "p90" => quantile(group_risks, 0.9)
                            ))
                        end
                    end
                elseif aggregation_level == "service_line"
                    service_lines = unique([get(p, "service_line", "Unknown") for p in cohort_data])
                    aggregated_results = []
                    for sl in service_lines
                        group_data = filter(p -> get(p, "service_line", "Unknown") == sl, cohort_data)
                        if !isempty(group_data)
                            group_risks = [get(p, "risk_score", 0.0) for p in group_data]
                            push!(aggregated_results, Dict(
                                "group" => sl,
                                "count" => length(group_data),
                                "p50" => quantile(group_risks, 0.5),
                                "mean" => mean(group_risks),
                                "p90" => quantile(group_risks, 0.9)
                            ))
                        end
                    end
                else
                    aggregated_results = [Dict(
                        "group" => "Overall",
                        "count" => length(cohort_data),
                        "p50" => p50,
                        "mean" => mean_risk,
                        "p90" => p90
                    )]
                end
            end
        end
    end
end
