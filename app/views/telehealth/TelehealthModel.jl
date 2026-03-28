"""
Stipple reactive model for Telehealth ROI Analysis.
Models financial return on telehealth investments including direct revenue and avoided transfers.
"""
using Stipple, StippleUI, StipplePlotly


@app begin
    @in left_drawer_open::Bool = true
    # ── Service Inputs ──────────────────────────────────────────────────
    @in svc1_name::String = "Telestroke"
    @in svc1_volume::Int = 120
    @in svc1_revenue::Float64 = 250.0
    @in svc1_cost::Float64 = 80.0
    @in svc1_transfers_avoided::Int = 30
    @in svc1_transfer_cost::Float64 = 8_000.0

    @in svc2_name::String = "Telepsych"
    @in svc2_volume::Int = 200
    @in svc2_revenue::Float64 = 180.0
    @in svc2_cost::Float64 = 50.0
    @in svc2_transfers_avoided::Int = 15
    @in svc2_transfer_cost::Float64 = 5_000.0

    # ── Investment Inputs ───────────────────────────────────────────────
    @in infrastructure_cost::Float64 = 50_000.0
    @in annual_licensing::Float64 = 24_000.0
    @in annual_staffing::Float64 = 80_000.0
    @in broadband_upgrade::Float64 = 0.0
    @in training_cost::Float64 = 5_000.0
    @in projection_years::Int = 3
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out direct_revenue::Float64 = 66_000.0
    @out direct_costs::Float64 = 19_600.0
    @out avoided_transfer_savings::Float64 = 315_000.0
    @out total_investment::Float64 = 159_000.0
    @out net_benefit_year1::Float64 = 202_400.0
    @out roi_pct::Float64 = 125.0
    @out breakeven_months::Int = 6

    @out roi_chart_data::Vector{PlotData} = [
        PlotData(x=["Year 1", "Year 2", "Year 3"],
                 y=[202_400, 350_000, 510_000],
                 plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                 name="Cumulative Net Benefit",
                 marker=Dict("color" => "#4CAF50"))
    ]
    @out roi_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Telehealth ROI Projection"),
        yaxis=[PlotLayoutAxis(title="Cumulative Benefit (\$)")],
    )

    @onchange recalculate begin
        if recalculate
            recalculate = false
            rev = svc1_volume * svc1_revenue + svc2_volume * svc2_revenue
            costs = svc1_volume * svc1_cost + svc2_volume * svc2_cost
            transfers = svc1_transfers_avoided * svc1_transfer_cost + svc2_transfers_avoided * svc2_transfer_cost

            direct_revenue = rev
            direct_costs = costs
            avoided_transfer_savings = transfers

            one_time = infrastructure_cost + broadband_upgrade + training_cost
            annual_fixed = annual_licensing + annual_staffing
            total_investment = one_time + annual_fixed
            annual_net = rev - costs + transfers

            net_benefit_year1 = annual_net - total_investment

            cumulative = 0.0
            years_labels = String[]
            cumulative_vals = Float64[]
            for yr in 1:projection_years
                growth = 1.0 + 0.10 * (yr - 1)
                yr_net = (rev * growth) - (costs * growth) + (transfers * growth)
                yr_cost = yr == 1 ? total_investment : annual_fixed
                cumulative += yr_net - yr_cost
                push!(years_labels, "Year $yr")
                push!(cumulative_vals, round(cumulative, digits=0))
            end

            total_invested = one_time + annual_fixed * projection_years
            roi_pct = total_invested > 0 ? round(cumulative / total_invested * 100, digits=1) : 0.0
            monthly = annual_net / 12.0
            breakeven_months = monthly > 0 ? ceil(Int, total_investment / monthly) : 0

            roi_chart_data = [PlotData(x=years_labels, y=cumulative_vals,
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Cumulative Net Benefit",
                marker=Dict("color" => "#4CAF50"))]
            @info "Telehealth ROI: $(roi_pct)%, breakeven $(breakeven_months)mo"
        end
    end
end

const telehealth_model = @init
