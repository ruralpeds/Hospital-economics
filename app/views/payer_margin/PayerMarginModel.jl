"""
Stipple reactive model for Payer-Specific Margin Analysis.
Breaks down margin by payer class and produces waterfall visualization.
Delegates to RuralHospitalSim.decompose_margin() for payer-level analysis.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: decompose_margin, margin_waterfall, MarginDecomposition


@app begin
    @in left_drawer_open::Bool = true
    # ── Revenue by Payer Inputs ─────────────────────────────────────────
    @in revenue_medicare::Float64 = 11_470_000.0
    @in revenue_medicaid::Float64 = 3_330_000.0
    @in revenue_commercial::Float64 = 2_220_000.0
    @in revenue_self_pay::Float64 = 1_480_000.0

    # ── Cost-to-Revenue Ratios (payer-specific) ─────────────────────────
    @in cost_ratio_medicare::Float64 = 1.02
    @in cost_ratio_medicaid::Float64 = 1.15
    @in cost_ratio_commercial::Float64 = 0.78
    @in cost_ratio_self_pay::Float64 = 1.45

    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    @out total_revenue::Float64 = 18_500_000.0
    @out total_cost::Float64 = 19_200_000.0
    @out blended_margin_pct::Float64 = -0.038
    @out best_payer::String = "Commercial"
    @out worst_payer::String = "Self-Pay"

    @out margin_by_payer::Vector{Dict{String,Any}} = [
        Dict("payer"=>"Medicare", "revenue"=>11_470_000, "cost"=>11_699_400,
             "margin"=>-229_400, "margin_pct"=>-2.0, "pct_revenue"=>62.0),
        Dict("payer"=>"Medicaid", "revenue"=>3_330_000, "cost"=>3_829_500,
             "margin"=>-499_500, "margin_pct"=>-15.0, "pct_revenue"=>18.0),
        Dict("payer"=>"Commercial", "revenue"=>2_220_000, "cost"=>1_731_600,
             "margin"=>488_400, "margin_pct"=>22.0, "pct_revenue"=>12.0),
        Dict("payer"=>"Self-Pay", "revenue"=>1_480_000, "cost"=>2_146_000,
             "margin"=>-666_000, "margin_pct"=>-45.0, "pct_revenue"=>8.0),
    ]

    # ── Chart Data ──────────────────────────────────────────────────────
    @out margin_bar_data::Vector{PlotData} = [
        PlotData(
            x = ["Medicare", "Medicaid", "Commercial", "Self-Pay"],
            y = [-2.0, -15.0, 22.0, -45.0],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Margin %",
            marker = Dict("color" => ["#FF9800", "#F44336", "#4CAF50", "#F44336"]),
        )
    ]
    @out margin_bar_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Margin by Payer Class (%)"),
        xaxis = [PlotLayoutAxis(title = "Payer")],
        yaxis = [PlotLayoutAxis(title = "Margin %")],
    )

    @out waterfall_data::Vector{PlotData} = [
        PlotData(
            x = ["Medicare", "Medicaid", "Commercial", "Self-Pay", "Total"],
            y = [-229, -500, 488, -666, -907],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Margin (\$K)",
            marker = Dict("color" => ["#FF9800","#F44336","#4CAF50","#F44336","#F44336"]),
        )
    ]
    @out waterfall_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Payer Margin Waterfall (\$K)"),
        xaxis = [PlotLayoutAxis(title = "")],
        yaxis = [PlotLayoutAxis(title = "\$K")],
    )

    # ── Handlers ────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false

            # Build payer data for domain engine
            payer_data = Dict{String,Dict{String,Float64}}(
                "Medicare" => Dict("revenue" => revenue_medicare, "cost_ratio" => cost_ratio_medicare),
                "Medicaid" => Dict("revenue" => revenue_medicaid, "cost_ratio" => cost_ratio_medicaid),
                "Commercial" => Dict("revenue" => revenue_commercial, "cost_ratio" => cost_ratio_commercial),
                "Self-Pay" => Dict("revenue" => revenue_self_pay, "cost_ratio" => cost_ratio_self_pay),
            )

            # Call domain engine
            decomposition = decompose_margin(payer_data)

            payers = ["Medicare", "Medicaid", "Commercial", "Self-Pay"]
            revenues = [revenue_medicare, revenue_medicaid, revenue_commercial, revenue_self_pay]
            costs = revenues .* [cost_ratio_medicare, cost_ratio_medicaid, cost_ratio_commercial, cost_ratio_self_pay]
            margins = revenues .- costs
            margin_pcts = round.((revenues .- costs) ./ max.(revenues, 1) .* 100, digits=1)

            total_revenue = decomposition.total_revenue
            total_cost = decomposition.total_cost
            blended_margin_pct = round(decomposition.blended_margin, digits=3)

            best_payer = decomposition.best_payer
            worst_payer = decomposition.worst_payer

            margin_by_payer = [
                Dict("payer"=>p, "revenue"=>round(Int, r), "cost"=>round(Int, c),
                     "margin"=>round(Int, m), "margin_pct"=>mp,
                     "pct_revenue"=>round(r/max(total_revenue,1)*100, digits=1))
                for (p, r, c, m, mp) in zip(payers, revenues, costs, margins, margin_pcts)
            ]

            colors = [mp >= 0 ? "#4CAF50" : mp > -10 ? "#FF9800" : "#F44336" for mp in margin_pcts]
            total_margin = sum(margins)
            push!(colors, total_margin >= 0 ? "#4CAF50" : "#F44336")

            margin_bar_data = [PlotData(x=payers, y=margin_pcts,
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Margin %",
                marker=Dict("color"=>colors[1:4]))]

            waterfall_data = [PlotData(
                x=vcat(payers, ["Total"]),
                y=round.(vcat(margins, [total_margin]) ./ 1000, digits=0),
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Margin (\$K)",
                marker=Dict("color"=>colors))]
            @info "Payer margin (domain): blended $(round(blended_margin_pct*100, digits=1))%, best=$(best_payer)"
        end
    end
end

const payer_margin_model = @init
