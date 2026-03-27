"""
Stipple reactive model for Closure Risk Assessment.
Computes multi-factor risk scores and identifies vulnerabilities.
"""
using Stipple, StippleUI, StipplePlotly

@appname ClosureRiskApp

@app begin
    # ── Selection ────────────────────────────────────────────────────────
    @in selected_hospital_id::Int = 1
    @out hospital_options::Vector{Dict{String,Any}} = [
        Dict("label"=>"Prairie View Community Hospital", "value"=>1),
        Dict("label"=>"Mountain Valley Medical Center", "value"=>2),
        Dict("label"=>"Delta Regional Hospital", "value"=>3),
        Dict("label"=>"High Plains Health", "value"=>4),
    ]
    @in run_assessment::Bool = false

    # ── Overall Risk ─────────────────────────────────────────────────────
    @out overall_risk_score::Int = 72
    @out risk_level::String = "high"
    @out financial_distress_index::Float64 = 0.78
    @out closure_probability_1yr::Float64 = 0.08
    @out closure_probability_3yr::Float64 = 0.18
    @out closure_probability_5yr::Float64 = 0.31
    @out peer_avg_risk_score::Int = 45

    # ── Risk Factor Breakdown ────────────────────────────────────────────
    @out risk_factors::Vector{Dict{String,Any}} = [
        Dict("name"=>"Operating Margin Trend", "score"=>85, "weight"=>0.25,
             "weighted_score"=>21.25, "severity"=>"critical",
             "detail"=>"Negative margin for 8 consecutive quarters, worsening trend"),
        Dict("name"=>"Cash Reserves", "score"=>70, "weight"=>0.20,
             "weighted_score"=>14.0, "severity"=>"high",
             "detail"=>"42 days cash on hand, below 60-day threshold"),
        Dict("name"=>"Volume Trends", "score"=>65, "weight"=>0.15,
             "weighted_score"=>9.75, "severity"=>"moderate",
             "detail"=>"Inpatient volume declining 2% annually, outpatient stable"),
        Dict("name"=>"Payer Mix Risk", "score"=>75, "weight"=>0.15,
             "weighted_score"=>11.25, "severity"=>"high",
             "detail"=>"62% Medicare, 18% Medicaid — high government payer dependency"),
        Dict("name"=>"Community Demographics", "score"=>60, "weight"=>0.10,
             "weighted_score"=>6.0, "severity"=>"moderate",
             "detail"=>"Population declining 0.3%/yr, aging faster than state average"),
        Dict("name"=>"Market Competition", "score"=>45, "weight"=>0.10,
             "weighted_score"=>4.5, "severity"=>"low",
             "detail"=>"Nearest hospital 35 miles away, limited competition"),
        Dict("name"=>"Regulatory Risk", "score"=>50, "weight"=>0.05,
             "weighted_score"=>2.5, "severity"=>"moderate",
             "detail"=>"CAH designation stable, state Medicaid rates uncertain"),
    ]

    # ── Trend Data ───────────────────────────────────────────────────────
    @out risk_trend_data::Vector{PlotData} = [
        PlotData(x=["2022-Q1","2022-Q2","2022-Q3","2022-Q4","2023-Q1","2023-Q2","2023-Q3","2023-Q4",
                     "2024-Q1","2024-Q2","2024-Q3","2024-Q4","2025-Q1","2025-Q2","2025-Q3","2025-Q4"],
                 y=[48, 50, 52, 55, 57, 59, 61, 63, 65, 66, 68, 69, 70, 71, 71, 72],
                 plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                 name="Risk Score", mode="lines+markers",
                 line=PlotDataLine(color="red")),
        PlotData(x=["2022-Q1","2022-Q2","2022-Q3","2022-Q4","2023-Q1","2023-Q2","2023-Q3","2023-Q4",
                     "2024-Q1","2024-Q2","2024-Q3","2024-Q4","2025-Q1","2025-Q2","2025-Q3","2025-Q4"],
                 y=[42, 43, 43, 44, 44, 44, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45],
                 plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                 name="Peer Average", mode="lines",
                 line=PlotDataLine(dash="dot", color="grey")),
    ]
    @out risk_trend_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Closure Risk Score Trend"),
        xaxis=[PlotLayoutAxis(title="Quarter")],
        yaxis=[PlotLayoutAxis(title="Risk Score (0-100)", range=[0, 100])],
        shapes=[Dict("type"=>"line", "y0"=>70, "y1"=>70, "x0"=>0, "x1"=>1,
                      "xref"=>"paper", "line"=>Dict("color"=>"red", "dash"=>"dash"))],
    )

    # ── Radar Chart for Factor Scores ────────────────────────────────────
    @out radar_data::Vector{PlotData} = [
        PlotData(
            r=[85, 70, 65, 75, 60, 45, 50],
            theta=["Margin", "Cash", "Volume", "Payer Mix", "Demographics", "Competition", "Regulatory"],
            plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR,
            fill="toself", name="Your Hospital",
            fillcolor="rgba(255,0,0,0.15)", line=PlotDataLine(color="red")),
        PlotData(
            r=[40, 45, 42, 50, 48, 52, 38],
            theta=["Margin", "Cash", "Volume", "Payer Mix", "Demographics", "Competition", "Regulatory"],
            plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR,
            fill="toself", name="Peer Average",
            fillcolor="rgba(0,0,255,0.10)", line=PlotDataLine(color="blue", dash="dot")),
    ]
    @out radar_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Risk Factor Comparison"),
        polar=Dict("radialaxis"=>Dict("visible"=>true, "range"=>[0, 100])),
    )

    # ── Mitigation Recommendations ───────────────────────────────────────
    @out recommendations::Vector{Dict{String,Any}} = [
        Dict("priority"=>"high", "action"=>"Evaluate REH conversion",
             "impact"=>"Could improve margin by 5-7 percentage points",
             "timeline"=>"6-12 months", "category"=>"Strategic"),
        Dict("priority"=>"high", "action"=>"Reduce labor costs via staffing optimization",
             "impact"=>"Potential \$500K-\$800K annual savings",
             "timeline"=>"3-6 months", "category"=>"Financial"),
        Dict("priority"=>"medium", "action"=>"Expand outpatient services",
             "impact"=>"Increase outpatient revenue 10-15%",
             "timeline"=>"6-18 months", "category"=>"Revenue"),
        Dict("priority"=>"medium", "action"=>"Implement telehealth program",
             "impact"=>"Retain patients, add specialty access, \$200K+ revenue",
             "timeline"=>"3-9 months", "category"=>"Revenue"),
        Dict("priority"=>"medium", "action"=>"Renegotiate commercial payer contracts",
             "impact"=>"Improve commercial rates 5-10%",
             "timeline"=>"3-6 months", "category"=>"Revenue"),
        Dict("priority"=>"low", "action"=>"Build cash reserves — target 60+ days",
             "impact"=>"Improve financial stability and bond ratings",
             "timeline"=>"12-24 months", "category"=>"Financial"),
    ]

    # ── Handlers ─────────────────────────────────────────────────────────
    @onchange selected_hospital_id begin
        @info "Loading closure risk for hospital $selected_hospital_id"
        if selected_hospital_id == 1
            overall_risk_score = 72
            risk_level = "high"
            closure_probability_3yr = 0.18
        elseif selected_hospital_id == 2
            overall_risk_score = 38
            risk_level = "low"
            closure_probability_3yr = 0.04
        elseif selected_hospital_id == 3
            overall_risk_score = 82
            risk_level = "critical"
            closure_probability_3yr = 0.32
        else
            overall_risk_score = 25
            risk_level = "low"
            closure_probability_3yr = 0.02
        end
    end

    @onchange run_assessment begin
        if run_assessment
            run_assessment = false
            @info "Running full closure risk assessment for hospital $selected_hospital_id"
        end
    end
end

const closure_risk_model = @init
