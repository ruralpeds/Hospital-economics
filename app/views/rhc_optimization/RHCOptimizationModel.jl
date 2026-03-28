"""
Stipple reactive model for Rural Health Clinic Optimization.
AIR revenue optimization with behavioral health, telehealth, and CCM expansion.
"""
using Stipple, StippleUI, StipplePlotly


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
            current_air = min(current_cost_per_visit, payment_cap_per_visit)
            current_revenue = current_air * annual_visits

            opt_cost = max(current_cost_per_visit, payment_cap_per_visit)
            optimized_air = min(opt_cost, payment_cap_per_visit)

            cost_gap_rev = max(0.0, (optimized_air - current_air) * annual_visits)
            bh_rev = optimized_air * behavioral_health_visits
            th_rev = optimized_air * telehealth_visits
            ccm_rev = ccm_eligible_patients * ccm_monthly_revenue * 12.0

            total_visits = annual_visits + behavioral_health_visits + telehealth_visits
            optimized_revenue = optimized_air * total_visits + ccm_rev
            revenue_increase = optimized_revenue - current_revenue

            recs = String[]
            cost_gap_rev > 0 && push!(recs, "Capture \$$(round(Int, cost_gap_rev)) by optimizing cost report to payment cap")
            bh_rev > 0 && push!(recs, "Behavioral health adds \$$(round(Int, bh_rev))/year")
            th_rev > 0 && push!(recs, "Telehealth expansion adds \$$(round(Int, th_rev))/year")
            ccm_rev > 0 && push!(recs, "CCM program adds \$$(round(Int, ccm_rev))/year outside AIR")
            recommendations = recs

            revenue_chart_data = [PlotData(
                x=["Current", "Cost Optimization", "Behavioral Health", "Telehealth", "CCM"],
                y=[current_revenue, cost_gap_rev, bh_rev, th_rev, ccm_rev],
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Revenue Components",
                marker=Dict("color" => ["#2196F3", "#4CAF50", "#FF9800", "#9C27B0", "#00BCD4"]))]

            rhc_total = optimized_air * total_visits
            opps_total = opps_rate * total_visits
            comparison_data = [PlotData(x=["RHC AIR", "OPPS Equivalent"],
                y=[rhc_total, opps_total], plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                marker=Dict("color" => ["#4CAF50", "#FF9800"]))]
            @info "RHC optimization: +\$$(round(Int, revenue_increase))"
        end
    end
end

const rhc_optimization_model = @init
