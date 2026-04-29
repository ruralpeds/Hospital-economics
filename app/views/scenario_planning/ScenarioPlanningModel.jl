"""Scenario Planning Model (B-05)."""
using Stipple, StippleUI, StipplePlotly
using ...FinanceEngine: FiveForce, analyze_five_forces, default_rural_hospital_scenarios

@app begin
    @in rivalry_score::Float64        = 6.0
    @in new_entrants_score::Float64   = 3.0
    @in substitutes_score::Float64    = 4.0
    @in buyer_power_score::Float64    = 6.0
    @in supplier_power_score::Float64 = 7.0
    @in run_five_forces::Bool         = false

    @out overall_intensity::Float64  = 0.0
    @out intensity_tier::String      = "—"
    @out dominant_force::String      = "—"
    @out strategic_summary::String   = "Set scores and click Analyse"

    @out scenario_names::Vector{String}      = []
    @out scenario_probs::Vector{Float64}     = []
    @out scenario_narratives::Vector{String} = []
    @out robust_strategies::Vector{String}   = []

    @out forces_chart::Vector{PlotData} = [PlotData(
        x=["Rivalry","New Entrants","Substitutes","Buyer","Supplier"],
        y=[6.0,3.0,4.0,6.0,7.0], plot="bar",
        marker=Dict("color"=>["#ef4444","#22c55e","#f59e0b","#ef4444","#ef4444"]),
    )]
    @out forces_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Five Forces Threat Scores"),
        yaxis=[PlotLayoutAxis(title="Score (1–10)", range=[0.0,10.0])],
    )

    @in errors::Vector{String} = String[]

    @onchange run_five_forces begin
        if run_five_forces
            run_five_forces = false
            errors = String[]
            try
                forces = [
                    FiveForce(force=:rivalry,        score=rivalry_score),
                    FiveForce(force=:new_entrants,   score=new_entrants_score),
                    FiveForce(force=:substitutes,    score=substitutes_score),
                    FiveForce(force=:buyer_power,    score=buyer_power_score),
                    FiveForce(force=:supplier_power, score=supplier_power_score),
                ]
                r = analyze_five_forces("My Hospital", forces)
                overall_intensity = round(r.overall_intensity, digits=1)
                intensity_tier    = uppercase(string(r.intensity_tier))
                dominant_force    = string(r.dominant_force)
                strategic_summary = r.strategic_summary

                scores = [rivalry_score, new_entrants_score, substitutes_score,
                          buyer_power_score, supplier_power_score]
                colors = [s >= 7 ? "#ef4444" : s >= 5 ? "#f59e0b" : "#22c55e" for s in scores]
                forces_chart = [PlotData(
                    x=["Rivalry","New Entrants","Substitutes","Buyer","Supplier"],
                    y=scores, plot="bar", marker=Dict("color"=>colors))]

                matrix = default_rural_hospital_scenarios()
                scenario_names      = [s.name for s in matrix.scenarios]
                scenario_probs      = [Float64(round(s.probability*100)) for s in matrix.scenarios]
                scenario_narratives = [s.narrative[1:min(120,end)] for s in matrix.scenarios]
                robust_strategies   = matrix.recommended_robust_strategies
            catch e; errors = ["$(sprint(showerror,e))"]; end
        end
    end
end
const scenario_planning_model = @init
