"""
Stipple reactive model for Service Line P&L Analysis.
Tracks revenue, cost, and contribution margin for each hospital service line.
Delegates to RuralHospitalSim.optimize_service_portfolio() for portfolio analysis.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: optimize_service_portfolio, PortfolioParams, PortfolioOptimizationResult


@app begin
    @in left_drawer_open::Bool = true
    # ── Service Line Revenue Inputs ─────────────────────────────────────
    @in sl_ed_revenue::Float64 = 4_200_000.0
    @in sl_inpatient_revenue::Float64 = 5_800_000.0
    @in sl_outpatient_revenue::Float64 = 3_100_000.0
    @in sl_surgical_revenue::Float64 = 2_400_000.0
    @in sl_imaging_revenue::Float64 = 1_800_000.0
    @in sl_lab_revenue::Float64 = 1_200_000.0
    @in sl_pharmacy_revenue::Float64 = 900_000.0
    @in sl_rehab_revenue::Float64 = 600_000.0

    # ── Service Line Cost Inputs ────────────────────────────────────────
    @in sl_ed_cost::Float64 = 3_900_000.0
    @in sl_inpatient_cost::Float64 = 6_200_000.0
    @in sl_outpatient_cost::Float64 = 2_600_000.0
    @in sl_surgical_cost::Float64 = 2_100_000.0
    @in sl_imaging_cost::Float64 = 1_500_000.0
    @in sl_lab_cost::Float64 = 950_000.0
    @in sl_pharmacy_cost::Float64 = 850_000.0
    @in sl_rehab_cost::Float64 = 500_000.0

    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    @out sl_names::Vector{String} = ["ED", "Inpatient", "Outpatient", "Surgical", "Imaging", "Lab", "Pharmacy", "Rehab"]
    @out sl_margins::Vector{Float64} = [300_000.0, -400_000.0, 500_000.0, 300_000.0, 300_000.0, 250_000.0, 50_000.0, 100_000.0]
    @out sl_margin_pcts::Vector{Float64} = [7.1, -6.9, 16.1, 12.5, 16.7, 20.8, 5.6, 16.7]
    @out total_contribution::Float64 = 1_400_000.0
    @out profitable_lines::Int = 7
    @out unprofitable_lines::Int = 1

    @out recommendations::Vector{Dict{String,String}} = [
        Dict("line" => "Inpatient", "action" => "Investigate high cost drivers; consider volume optimization or service redesign",
             "priority" => "high"),
        Dict("line" => "Pharmacy", "action" => "Review 340B eligibility and drug purchasing contracts",
             "priority" => "medium"),
        Dict("line" => "Outpatient", "action" => "Expand capacity in highest-margin outpatient services",
             "priority" => "medium"),
    ]

    # ── Chart Data ──────────────────────────────────────────────────────
    @out portfolio_chart_data::Vector{PlotData} = [
        PlotData(
            x = [4.2, 5.8, 3.1, 2.4, 1.8, 1.2, 0.9, 0.6],
            y = [7.1, -6.9, 16.1, 12.5, 16.7, 20.8, 5.6, 16.7],
            text = ["ED", "Inpatient", "Outpatient", "Surgical", "Imaging", "Lab", "Pharmacy", "Rehab"],
            mode = "markers+text",
            marker = Dict("size" => [42, 58, 31, 24, 18, 12, 9, 6], "sizemode" => "area", "sizeref" => 0.1),
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "Service Lines",
            textposition = "top center",
        )
    ]
    @out portfolio_chart_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Service Line Portfolio (Revenue vs Margin %)"),
        xaxis = [PlotLayoutAxis(title = "Revenue (\$M)")],
        yaxis = [PlotLayoutAxis(title = "Contribution Margin %")],
    )

    @out margin_bar_data::Vector{PlotData} = [
        PlotData(
            x = ["ED", "Inpatient", "Outpatient", "Surgical", "Imaging", "Lab", "Pharmacy", "Rehab"],
            y = [300, -400, 500, 300, 300, 250, 50, 100],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Contribution Margin (\$K)",
            marker = Dict("color" => ["green","red","green","green","green","green","green","green"]),
        )
    ]
    @out margin_bar_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Contribution Margin by Service Line (\$K)"),
        xaxis = [PlotLayoutAxis(title = "Service Line")],
        yaxis = [PlotLayoutAxis(title = "\$K")],
    )

    # ── Handlers ────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false
            revenues = [sl_ed_revenue, sl_inpatient_revenue, sl_outpatient_revenue, sl_surgical_revenue,
                        sl_imaging_revenue, sl_lab_revenue, sl_pharmacy_revenue, sl_rehab_revenue]
            costs = [sl_ed_cost, sl_inpatient_cost, sl_outpatient_cost, sl_surgical_cost,
                     sl_imaging_cost, sl_lab_cost, sl_pharmacy_cost, sl_rehab_cost]

            # Build portfolio params for domain engine
            service_data = [(sl_names[i], revenues[i], costs[i]) for i in 1:8]
            params = PortfolioParams(; service_lines=service_data)
            result = optimize_service_portfolio(params)

            # Map domain results
            sl_margins = result.margins
            sl_margin_pcts = result.margin_pcts
            total_contribution = result.total_contribution
            profitable_lines = result.profitable_count
            unprofitable_lines = result.unprofitable_count
            recommendations = result.recommendations

            # Update portfolio scatter from domain
            portfolio_chart_data = [PlotData(
                x=round.(revenues ./ 1e6, digits=1),
                y=sl_margin_pcts,
                text=sl_names,
                mode="markers+text",
                marker=Dict("size"=>round.(revenues ./ maximum(revenues) .* 50, digits=0), "sizemode"=>"area", "sizeref"=>0.1),
                plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER, name="Service Lines", textposition="top center")]

            margin_bar_data = [PlotData(
                x = sl_names,
                y = round.(sl_margins ./ 1000, digits=0),
                plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
                name = "Contribution Margin (\$K)",
                marker = Dict("color" => [m > 0 ? "green" : "red" for m in sl_margins]),
            )]
            @info "Service line P&L (domain): Total contribution: \$$(round(Int, total_contribution/1000))K"
        end
    end
end

const service_line_model = @init
