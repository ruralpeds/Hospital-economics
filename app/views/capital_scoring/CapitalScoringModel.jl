"""
Stipple reactive model for MCDA Capital Replacement Scoring.
Weighted multi-criteria scoring, budget-constrained selection, and priority reporting.
"""
using Stipple, StippleUI, StipplePlotly


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
            names = [p1_name, p2_name, p3_name, p4_name]
            costs = [p1_cost, p2_cost, p3_cost, p4_cost]
            safeties = [p1_safety, p2_safety, p3_safety, p4_safety]
            revenues = [p1_revenue, p2_revenue, p3_revenue, p4_revenue]
            failures = [p1_failure, p2_failure, p3_failure, p4_failure]
            strategics = [p1_strategic, p2_strategic, p3_strategic, p4_strategic]
            efficiencies = [p1_efficiency, p2_efficiency, p3_efficiency, p4_efficiency]
            max_rev = maximum(revenues)
            max_eff = maximum(efficiencies)
            scores = Float64[]
            for i in 1:4
                rev_norm = max_rev > 0 ? revenues[i] / max_rev : 0.0
                eff_norm = max_eff > 0 ? efficiencies[i] / max_eff : 0.0
                s = w_safety * safeties[i] + w_revenue * rev_norm +
                    w_condition * failures[i] + w_strategic * strategics[i] +
                    w_efficiency * eff_norm
                push!(scores, round(s, digits=3))
            end
            ranks = sortperm(scores, rev=true)
            project_names = names
            project_scores = scores
            project_ranks = invperm(ranks)
            sel = String[]
            total_cost = 0.0
            total_benefit = 0.0
            for idx in ranks
                if total_cost + costs[idx] <= annual_capex_budget
                    push!(sel, names[idx])
                    total_cost += costs[idx]
                    total_benefit += revenues[idx] + efficiencies[idx]
                end
            end
            selected_projects = sel
            total_cost_selected = total_cost
            budget_utilization = annual_capex_budget > 0 ? round(total_cost / annual_capex_budget, digits=3) : 0.0
            total_annual_benefit = total_benefit
            score_data = [PlotData(x=names, y=scores,
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Weighted Score",
                marker=Dict("color" => [n in sel ? "#4CAF50" : "#9E9E9E" for n in names]))]
            remaining = max(annual_capex_budget - total_cost, 0.0)
            budget_data = [PlotData(labels=["Selected", "Remaining"],
                values=[total_cost, remaining],
                plot=StipplePlotly.Charts.PLOT_TYPE_PIE,
                marker=Dict("colors" => ["#4CAF50", "#E0E0E0"]))]
            @info "Capital scoring: $(length(sel)) projects selected, \$$(round(Int, total_cost)) of \$$(round(Int, annual_capex_budget)) budget"
        end
    end
end

const capital_scoring_model = @init
