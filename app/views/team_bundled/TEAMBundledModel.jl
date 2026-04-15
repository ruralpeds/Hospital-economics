"""
Stipple reactive model for TEAM Bundled Payment Simulation.
Computes CMS TEAM reconciliation amounts with quality adjustments and stop-gain/loss caps.
Delegates to RuralHospitalSim.calculate_team_reconciliation() for computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: calculate_team_reconciliation, TEAMParams, TEAMResult


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in episode_count::Int = 50
    @in avg_target_price::Float64 = 25_000.0
    @in avg_actual_cost::Float64 = 23_500.0
    @in quality_score::Float64 = 0.65
    @in risk_track::String = "track2"
    @in discount_factor::Float64 = 0.03
    @in quality_adjustment_pct::Float64 = 0.02
    @in low_volume_threshold::Int = 31
    @in recalculate::Bool = false

    @out risk_track_options::Vector{Dict{String,Any}} = [
        Dict("label" => "Track 1 (10% cap)", "value" => "track1"),
        Dict("label" => "Track 2 (5% cap)", "value" => "track2"),
    ]

    # ── Outputs ─────────────────────────────────────────────────────────
    @out total_target_price::Float64 = 1_212_500.0
    @out total_actual_cost::Float64 = 1_175_000.0
    @out raw_reconciliation::Float64 = 37_500.0
    @out quality_adj_reconciliation::Float64 = 38_625.0
    @out net_payment_adjustment::Float64 = 38_625.0
    @out is_low_volume_exempt::Bool = false

    @out episode_chart_data::Vector{PlotData} = [
        PlotData(x=["Target Price", "Actual Cost", "Net Adjustment"],
                 y=[1_212_500, 1_175_000, 38_625],
                 plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                 marker=Dict("color" => ["#2196F3", "#FF9800", "#4CAF50"]))
    ]
    @out episode_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="TEAM Bundled Payment Summary"),
        yaxis=[PlotLayoutAxis(title="Dollars (\$)")],
    )

    # ── Handler ─────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false

            # Call domain engine
            params = TEAMParams(;
                episode_count=episode_count,
                avg_target_price=avg_target_price,
                avg_actual_cost=avg_actual_cost,
                quality_score=quality_score,
                risk_track=risk_track,
                discount_factor=discount_factor,
                quality_adjustment_pct=quality_adjustment_pct,
                low_volume_threshold=low_volume_threshold,
            )
            result = calculate_team_reconciliation(params)

            # Map domain results
            total_target_price = result.total_target_price
            total_actual_cost = result.total_actual_cost
            raw_reconciliation = result.raw_reconciliation
            quality_adj_reconciliation = result.quality_adj_reconciliation
            net_payment_adjustment = result.net_payment_adjustment
            is_low_volume_exempt = result.is_low_volume_exempt

            bar_color = net_payment_adjustment >= 0 ? "#4CAF50" : "#F44336"
            episode_chart_data = [PlotData(
                x=["Target Price", "Actual Cost", "Net Adjustment"],
                y=[total_target_price, total_actual_cost, net_payment_adjustment],
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                marker=Dict("color" => ["#2196F3", "#FF9800", bar_color]))]
            @info "TEAM reconciliation (domain): net adjustment \$$(round(Int, net_payment_adjustment))"
        end
    end
end

const team_bundled_model = @init
