"""
Stipple reactive model for Revenue Cycle Optimization.
Tracks current vs target metrics and dollar impact per initiative.
References RuralHospitalSim financial ratio functions.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: compute_all_ratios


@app begin
    @in left_drawer_open::Bool = true
    # ── Current Metric Inputs ───────────────────────────────────────────
    @in days_in_ar::Float64 = 58.0
    @in clean_claim_rate::Float64 = 0.82
    @in denial_rate::Float64 = 0.12
    @in cost_to_collect::Float64 = 0.045
    @in cash_collection_pct::Float64 = 0.94
    @in days_to_bill::Float64 = 5.2
    @in point_of_service_collection::Float64 = 0.22

    # ── Target Metric Inputs ────────────────────────────────────────────
    @in target_days_in_ar::Float64 = 42.0
    @in target_clean_claim_rate::Float64 = 0.95
    @in target_denial_rate::Float64 = 0.05
    @in target_cost_to_collect::Float64 = 0.035
    @in target_cash_collection::Float64 = 0.97

    @in net_patient_revenue::Float64 = 18_500_000.0
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out total_dollar_impact::Float64 = 1_245_000.0
    @out improved_days_in_ar::Float64 = 42.0
    @out improved_collection_rate::Float64 = 0.97

    @out initiative_impacts::Vector{Dict{String,Any}} = [
        Dict("initiative" => "Reduce Days in A/R", "current" => "58 days", "target" => "42 days",
             "dollar_impact" => 485_000, "priority" => "high"),
        Dict("initiative" => "Improve Clean Claim Rate", "current" => "82%", "target" => "95%",
             "dollar_impact" => 310_000, "priority" => "high"),
        Dict("initiative" => "Reduce Denial Rate", "current" => "12%", "target" => "5%",
             "dollar_impact" => 275_000, "priority" => "medium"),
        Dict("initiative" => "Lower Cost to Collect", "current" => "4.5%", "target" => "3.5%",
             "dollar_impact" => 100_000, "priority" => "medium"),
        Dict("initiative" => "Improve Cash Collection", "current" => "94%", "target" => "97%",
             "dollar_impact" => 75_000, "priority" => "low"),
    ]

    # ── Chart Data ──────────────────────────────────────────────────────
    @out waterfall_data::Vector{PlotData} = [
        PlotData(
            x = ["A/R Days", "Clean Claims", "Denials", "Cost to Collect", "Collections", "Total"],
            y = [485, 310, 275, 100, 75, 1245],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Dollar Impact (\$K)",
            marker = Dict("color" => ["#2196F3","#2196F3","#2196F3","#2196F3","#2196F3","#4CAF50"]),
        )
    ]
    @out waterfall_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Revenue Cycle Improvement Waterfall (\$K)"),
        xaxis = [PlotLayoutAxis(title = "Initiative")],
        yaxis = [PlotLayoutAxis(title = "\$K Impact")],
    )

    @out before_after_data::Vector{PlotData} = [
        PlotData(
            x = ["Days in A/R", "Clean Claim %", "Denial %", "Cost to Collect %", "Collection %"],
            y = [58, 82, 12, 4.5, 94],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Current"),
        PlotData(
            x = ["Days in A/R", "Clean Claim %", "Denial %", "Cost to Collect %", "Collection %"],
            y = [42, 95, 5, 3.5, 97],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Target"),
    ]
    @out before_after_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Revenue Cycle Metrics: Current vs Target"),
        barmode = "group",
        xaxis = [PlotLayoutAxis(title = "Metric")],
        yaxis = [PlotLayoutAxis(title = "Value")],
    )

    # ── Handlers ────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false
            ar_impact = round((days_in_ar - target_days_in_ar) / 365 * net_patient_revenue, digits=0)
            claim_impact = round((target_clean_claim_rate - clean_claim_rate) * net_patient_revenue * 0.15, digits=0)
            denial_impact = round((denial_rate - target_denial_rate) * net_patient_revenue * 0.20, digits=0)
            ctc_impact = round((cost_to_collect - target_cost_to_collect) * net_patient_revenue, digits=0)
            coll_impact = round((target_cash_collection - cash_collection_pct) * net_patient_revenue * 0.15, digits=0)

            total_dollar_impact = ar_impact + claim_impact + denial_impact + ctc_impact + coll_impact
            improved_days_in_ar = target_days_in_ar
            improved_collection_rate = target_cash_collection

            waterfall_data = [PlotData(
                x = ["A/R Days", "Clean Claims", "Denials", "Cost to Collect", "Collections", "Total"],
                y = round.([ar_impact, claim_impact, denial_impact, ctc_impact, coll_impact, total_dollar_impact] ./ 1000, digits=0),
                plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
                name = "Dollar Impact (\$K)",
                marker = Dict("color" => ["#2196F3","#2196F3","#2196F3","#2196F3","#2196F3","#4CAF50"]),
            )]
            @info "Revenue cycle impact: \$$(round(Int, total_dollar_impact/1000))K"
        end
    end
end

const revenue_cycle_model = @init
