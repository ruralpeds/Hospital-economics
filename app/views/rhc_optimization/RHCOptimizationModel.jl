"""
Stipple reactive model for Rural Health Clinic Optimization.
AIR revenue optimization with behavioral health, telehealth, and CCM expansion.
Delegates to RuralHospitalSim.optimize_rhc_revenue() for computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: optimize_rhc_revenue, rhc_vs_hopd_comparison,
    RHCParams, RHCOptimizationResult


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in annual_visits::Int = 8000
    @in current_cost_per_visit::Float64 = 140.0
    @in payment_cap_per_visit::Float64 = 165.0
    @in behavioral_health_visits::Int = 500
    @in telehealth_visits::Int = 300
    @in ccm_eligible_patients::Int = 150
    @in ccm_monthly_revenue::Float64 = 62.0
    @in opps_rate::Float64 = 120.0
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out current_air::Float64 = 140.0
    @out optimized_air::Float64 = 165.0
    @out current_revenue::Float64 = 1_120_000.0
    @out optimized_revenue::Float64 = 1_563_200.0
    @out revenue_increase::Float64 = 443_200.0
    @out recommendations::Vector{String} = ["Capture cost gap to payment cap", "Add behavioral health visits"]

    @out revenue_chart_data::Vector{PlotData} = [
        PlotData(x=["Current", "Cost Optimization", "Behavioral Health", "Telehealth", "CCM"],
                 y=[1_120_000, 200_000, 82_500, 49_500, 111_600],
                 plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                 name="Revenue Components",
                 marker=Dict("color" => ["#2196F3", "#4CAF50", "#FF9800", "#9C27B0", "#00BCD4"]))
    ]
    @out revenue_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="RHC Revenue Optimization Waterfall"),
        yaxis=[PlotLayoutAxis(title="Annual Revenue (\$)")],
    )

    @out comparison_data::Vector{PlotData} = [
        PlotData(x=["RHC AIR", "OPPS Equivalent"],
                 y=[1_563_200, 1_056_000],
                 plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                 marker=Dict("color" => ["#4CAF50", "#FF9800"]))
    ]
    @out comparison_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="RHC vs OPPS Revenue Comparison"),
        yaxis=[PlotLayoutAxis(title="Annual Revenue (\$)")],
    )

    @onchange recalculate begin
        if recalculate
            recalculate = false

            # Call domain engine
            params = RHCParams(;
                annual_visits=annual_visits,
                current_cost_per_visit=current_cost_per_visit,
                payment_cap_per_visit=payment_cap_per_visit,
                behavioral_health_visits=behavioral_health_visits,
                telehealth_visits=telehealth_visits,
                ccm_eligible_patients=ccm_eligible_patients,
                ccm_monthly_revenue=ccm_monthly_revenue,
            )
            result = optimize_rhc_revenue(params)

            # Map domain results
            current_air = result.current_air
            optimized_air = result.optimized_air
            current_revenue = result.current_revenue
            optimized_revenue = result.optimized_revenue
            revenue_increase = result.revenue_increase
            recommendations = result.recommendations

            cost_gap_rev = result.cost_optimization_revenue
            bh_rev = result.behavioral_health_revenue
            th_rev = result.telehealth_revenue
            ccm_rev = result.ccm_revenue

            revenue_chart_data = [PlotData(
                x=["Current", "Cost Optimization", "Behavioral Health", "Telehealth", "CCM"],
                y=[current_revenue, cost_gap_rev, bh_rev, th_rev, ccm_rev],
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Revenue Components",
                marker=Dict("color" => ["#2196F3", "#4CAF50", "#FF9800", "#9C27B0", "#00BCD4"]))]

            # RHC vs HOPD comparison from domain
            comp = rhc_vs_hopd_comparison(params; opps_rate=opps_rate)
            comparison_data = [PlotData(x=["RHC AIR", "OPPS Equivalent"],
                y=[comp.rhc_revenue, comp.opps_revenue], plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                marker=Dict("color" => ["#4CAF50", "#FF9800"]))]
            @info "RHC optimization (domain): +\$$(round(Int, revenue_increase))"
        end
    end
end

const rhc_optimization_model = @init
