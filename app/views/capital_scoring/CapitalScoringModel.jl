"""
Stipple reactive model for MCDA Capital Replacement Scoring.
Weighted multi-criteria scoring, budget-constrained selection, and priority reporting.
Delegates to RuralHospitalSim.score_capital_projects() for MCDA computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: score_capital_projects, select_within_budget,
    CapitalRequest, CapitalScoreResult


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in annual_capex_budget::Float64 = 2_000_000.0
    @in p1_name::String = "HVAC Replacement"
    @in p1_cost::Float64 = 800_000.0
    @in p1_safety::Float64 = 0.7
    @in p1_revenue::Float64 = 50_000.0
    @in p1_failure::Float64 = 0.8
    @in p1_strategic::Float64 = 0.5
    @in p1_efficiency::Float64 = 30_000.0
    @in p2_name::String = "CT Scanner Upgrade"
    @in p2_cost::Float64 = 1_200_000.0
    @in p2_safety::Float64 = 0.4
    @in p2_revenue::Float64 = 400_000.0
    @in p2_failure::Float64 = 0.3
    @in p2_strategic::Float64 = 0.8
    @in p2_efficiency::Float64 = 100_000.0
    @in p3_name::String = "Roof Repair"
    @in p3_cost::Float64 = 350_000.0
    @in p3_safety::Float64 = 0.9
    @in p3_revenue::Float64 = 0.0
    @in p3_failure::Float64 = 0.95
    @in p3_strategic::Float64 = 0.2
    @in p3_efficiency::Float64 = 10_000.0
    @in p4_name::String = "EHR Module"
    @in p4_cost::Float64 = 500_000.0
    @in p4_safety::Float64 = 0.3
    @in p4_revenue::Float64 = 150_000.0
    @in p4_failure::Float64 = 0.2
    @in p4_strategic::Float64 = 0.9
    @in p4_efficiency::Float64 = 200_000.0
    @in w_safety::Float64 = 0.30
    @in w_revenue::Float64 = 0.25
    @in w_condition::Float64 = 0.20
    @in w_strategic::Float64 = 0.15
    @in w_efficiency::Float64 = 0.10
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    @out project_names::Vector{String} = ["HVAC Replacement", "CT Scanner Upgrade", "Roof Repair", "EHR Module"]
    @out project_scores::Vector{Float64} = [0.0, 0.0, 0.0, 0.0]
    @out project_ranks::Vector{Int} = [1, 2, 3, 4]
    @out selected_projects::Vector{String} = String[]
    @out total_cost_selected::Float64 = 0.0
    @out budget_utilization::Float64 = 0.0
    @out total_annual_benefit::Float64 = 0.0

    @out score_data::Vector{PlotData} = [
        PlotData(x=["HVAC", "CT Scanner", "Roof", "EHR"], y=[0.0, 0.0, 0.0, 0.0],
                 plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Weighted Score",
                 marker=Dict("color" => "#1976D2"))
    ]
    @out score_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Capital Project Scores (MCDA)"),
        yaxis=[PlotLayoutAxis(title="Weighted Score")],
    )
    @out budget_data::Vector{PlotData} = [
        PlotData(labels=["Selected", "Remaining"], values=[0.0, 2_000_000.0],
                 plot=StipplePlotly.Charts.PLOT_TYPE_PIE,
                 marker=Dict("colors" => ["#4CAF50", "#E0E0E0"]))
    ]
    @out budget_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Budget Utilization"),
    )

    @onchange recalculate begin
        if recalculate
            recalculate = false

            # Build domain types
            requests = [
                CapitalRequest(p1_name, p1_cost, p1_safety, p1_revenue, p1_failure, p1_strategic, p1_efficiency),
                CapitalRequest(p2_name, p2_cost, p2_safety, p2_revenue, p2_failure, p2_strategic, p2_efficiency),
                CapitalRequest(p3_name, p3_cost, p3_safety, p3_revenue, p3_failure, p3_strategic, p3_efficiency),
                CapitalRequest(p4_name, p4_cost, p4_safety, p4_revenue, p4_failure, p4_strategic, p4_efficiency),
            ]
            weights = Dict("safety"=>w_safety, "revenue"=>w_revenue, "condition"=>w_condition,
                "strategic"=>w_strategic, "efficiency"=>w_efficiency)

            # Call domain engine
            scored = score_capital_projects(requests, weights)
            selection = select_within_budget(scored, annual_capex_budget)

            # Map domain results
            names = [s.name for s in scored]
            scores = [s.score for s in scored]
            project_names = names
            project_scores = scores
            project_ranks = [s.rank for s in scored]

            sel = [s.name for s in selection.selected]
            selected_projects = sel
            total_cost_selected = selection.total_cost
            budget_utilization = selection.budget_utilization
            total_annual_benefit = selection.total_annual_benefit

            score_data = [PlotData(x=names, y=scores,
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Weighted Score",
                marker=Dict("color" => [n in sel ? "#4CAF50" : "#9E9E9E" for n in names]))]
            remaining = max(annual_capex_budget - total_cost_selected, 0.0)
            budget_data = [PlotData(labels=["Selected", "Remaining"],
                values=[total_cost_selected, remaining],
                plot=StipplePlotly.Charts.PLOT_TYPE_PIE,
                marker=Dict("colors" => ["#4CAF50", "#E0E0E0"]))]
            @info "Capital scoring (domain): $(length(sel)) projects selected, \$$(round(Int, total_cost_selected)) of \$$(round(Int, annual_capex_budget)) budget"
        end
    end
end

const capital_scoring_model = @init
