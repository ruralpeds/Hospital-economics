"""
Stipple reactive model for Rural Health Network Economics.
Shared-service savings, ACO formation, and joint purchasing analysis.
Delegates to RuralHospitalSim.evaluate_network() for computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: evaluate_network, network_aco_formation, joint_purchasing_savings,
    NetworkMember, SharedService, NetworkResult


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
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

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

            # Build domain types
            members = [
                NetworkMember(m1_name, m1_revenue, m1_expenses, m1_fte),
                NetworkMember(m2_name, m2_revenue, m2_expenses, m2_fte),
                NetworkMember(m3_name, m3_revenue, m3_expenses, m3_fte),
            ]
            shared_services = [
                SharedService(ss1_name, ss1_current, ss1_network, ss1_impl),
                SharedService(ss2_name, ss2_current, ss2_network, ss2_impl),
            ]

            # Call domain engine
            result = evaluate_network(members, shared_services)
            annual_savings = result.annual_savings
            implementation_cost = result.implementation_cost
            breakeven_years = result.breakeven_years

            # ACO from domain
            aco_result = network_aco_formation(members; benchmark_per_bene=benchmark_per_bene,
                total_beneficiaries=total_beneficiaries)
            aco_shared_savings = aco_result.shared_savings

            # GPO from domain
            gpo_result = joint_purchasing_savings(members)
            gpo_savings = gpo_result.annual_savings

            ss_names = [ss1_name, ss2_name]
            ss_saves = [result.service_savings[i] for i in 1:length(shared_services)]
            savings_chart_data = [PlotData(x=ss_names, y=ss_saves,
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Annual Savings",
                marker=Dict("color" => "#4CAF50"))]

            network_chart_data = [PlotData(x=["Shared Services", "ACO Savings", "GPO Savings"],
                y=[annual_savings, aco_shared_savings, gpo_savings],
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Network Benefits",
                marker=Dict("color" => "#2196F3"))]
            @info "Network (domain): savings \$$(round(Int, annual_savings)), ACO \$$(round(Int, aco_shared_savings)), GPO \$$(round(Int, gpo_savings))"
        end
    end
end

const network_economics_model = @init
