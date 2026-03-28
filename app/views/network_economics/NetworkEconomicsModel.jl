"""
Stipple reactive model for Rural Health Network Economics.
Shared-service savings, ACO formation, and joint purchasing analysis.
"""
using Stipple, StippleUI, StipplePlotly


@app begin
    @in left_drawer_open::Bool = true
    # ── Member Inputs ───────────────────────────────────────────────────
    @in m1_name::String = "Prairie View Hospital"
    @in m1_revenue::Float64 = 18_000_000.0
    @in m1_expenses::Float64 = 19_000_000.0
    @in m1_fte::Int = 120

    @in m2_name::String = "Valley Medical Center"
    @in m2_revenue::Float64 = 22_000_000.0
    @in m2_expenses::Float64 = 21_500_000.0
    @in m2_fte::Int = 150

    @in m3_name::String = "Highland Community Hospital"
    @in m3_revenue::Float64 = 15_000_000.0
    @in m3_expenses::Float64 = 16_000_000.0
    @in m3_fte::Int = 95

    # ── Shared Service Inputs ───────────────────────────────────────────
    @in ss1_name::String = "IT / EHR"
    @in ss1_current::Float64 = 250_000.0
    @in ss1_network::Float64 = 180_000.0
    @in ss1_impl::Float64 = 100_000.0

    @in ss2_name::String = "Revenue Cycle"
    @in ss2_current::Float64 = 200_000.0
    @in ss2_network::Float64 = 140_000.0
    @in ss2_impl::Float64 = 50_000.0

    @in benchmark_per_bene::Float64 = 12_000.0
    @in total_beneficiaries::Int = 5000
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out annual_savings::Float64 = 390_000.0
    @out implementation_cost::Float64 = 150_000.0
    @out breakeven_years::Float64 = 0.38
    @out aco_shared_savings::Float64 = 0.0
    @out gpo_savings::Float64 = 0.0

    @out savings_chart_data::Vector{PlotData} = [
        PlotData(x=["IT / EHR", "Revenue Cycle"],
                 y=[210_000, 180_000],
                 plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                 name="Annual Savings", marker=Dict("color" => "#4CAF50"))
    ]
    @out savings_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Shared Service Savings by Category"),
        yaxis=[PlotLayoutAxis(title="Annual Savings (\$)")],
    )

    @out network_chart_data::Vector{PlotData} = [
        PlotData(x=["Shared Services", "ACO Savings", "GPO Savings"],
                 y=[390_000, 0, 0],
                 plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                 name="Network Benefits", marker=Dict("color" => "#2196F3"))
    ]
    @out network_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Total Network Economic Benefits"),
        yaxis=[PlotLayoutAxis(title="Annual Benefit (\$)")],
    )

    @onchange recalculate begin
        if recalculate
            recalculate = false
            n_members = 3
            # Shared services
            ss_current_total = (ss1_current + ss2_current) * n_members
            ss_network_total = (ss1_network + ss2_network) * n_members
            annual_savings = ss_current_total - ss_network_total
            implementation_cost = ss1_impl + ss2_impl
            breakeven_years = annual_savings > 0 ? round(implementation_cost / annual_savings, digits=2) : Inf

            ss1_total_save = (ss1_current - ss1_network) * n_members
            ss2_total_save = (ss2_current - ss2_network) * n_members

            savings_chart_data = [PlotData(x=[ss1_name, ss2_name],
                y=[ss1_total_save, ss2_total_save],
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Annual Savings",
                marker=Dict("color" => "#4CAF50"))]

            # ACO formation
            total_exp = m1_expenses + m2_expenses + m3_expenses
            medicare_exp = total_exp * 0.40
            cost_per_bene = total_beneficiaries > 0 ? medicare_exp / total_beneficiaries : 0.0
            eff = clamp(1.0 - 0.005 * n_members, 0.90, 1.0)
            adj_cost = cost_per_bene * eff
            benchmark_total = benchmark_per_bene * total_beneficiaries
            gross = benchmark_total - adj_cost * total_beneficiaries
            msr = total_beneficiaries >= 25_000 ? 0.02 : 0.033
            aco_shared_savings = gross > benchmark_total * msr ? round(gross * 0.50, digits=0) : 0.0

            # GPO
            supply_spend = total_exp * 0.30
            millions = supply_spend / 1e6
            vol_bonus = clamp(millions * 0.01, 0.0, 0.15)
            eff_disc = 0.05 + vol_bonus
            gpo_savings = round(supply_spend * eff_disc, digits=0)

            network_chart_data = [PlotData(x=["Shared Services", "ACO Savings", "GPO Savings"],
                y=[annual_savings, aco_shared_savings, gpo_savings],
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Network Benefits",
                marker=Dict("color" => "#2196F3"))]
            @info "Network: savings \$$(round(Int, annual_savings)), ACO \$$(round(Int, aco_shared_savings)), GPO \$$(round(Int, gpo_savings))"
        end
    end
end

const network_economics_model = @init
