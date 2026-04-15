"""
Stipple reactive model for Telehealth ROI Analysis.
Models financial return on telehealth investments including direct revenue and avoided transfers.
Delegates to RuralHospitalSim.calculate_telehealth_roi() for ROI computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: calculate_telehealth_roi, telehealth_service_comparison,
    TelehealthService, TelehealthInvestment, TelehealthROI


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

            # Build domain types
            services = [
                TelehealthService(svc1_name, svc1_volume, svc1_revenue, svc1_cost,
                    svc1_transfers_avoided, svc1_transfer_cost),
                TelehealthService(svc2_name, svc2_volume, svc2_revenue, svc2_cost,
                    svc2_transfers_avoided, svc2_transfer_cost),
            ]
            investment = TelehealthInvestment(;
                infrastructure_cost=infrastructure_cost,
                annual_licensing=annual_licensing,
                annual_staffing=annual_staffing,
                broadband_upgrade=broadband_upgrade,
                training_cost=training_cost,
                projection_years=projection_years,
            )

            # Call domain engine
            result = calculate_telehealth_roi(services, investment)

            # Map domain results
            direct_revenue = result.direct_revenue
            direct_costs = result.direct_costs
            avoided_transfer_savings = result.avoided_transfer_savings
            total_investment = result.total_investment
            net_benefit_year1 = result.net_benefit_year1
            roi_pct = result.roi_pct
            breakeven_months = result.breakeven_months

            years_labels = ["Year $yr" for yr in 1:projection_years]
            cumulative_vals = result.cumulative_benefits

            roi_chart_data = [PlotData(x=years_labels, y=round.(cumulative_vals, digits=0),
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Cumulative Net Benefit",
                marker=Dict("color" => "#4CAF50"))]
            @info "Telehealth ROI (domain): $(roi_pct)%, breakeven $(breakeven_months)mo"
        end
    end
end

const telehealth_model = @init
