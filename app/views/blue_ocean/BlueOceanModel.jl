"""Blue Ocean Strategy Model (B-02)."""
using Stipple, StippleUI, StipplePlotly
using ...FinanceEngine: CompetitiveFactor, StrategicCanvas, blue_ocean_analysis

@app begin
    @in factor_names::Vector{String}     = ["Price","Wait Time","Telehealth","Community Trust","Inpatient Beds"]
    @in our_scores::Vector{Float64}      = [5.0, 7.0, 2.0, 8.0, 4.0]
    @in industry_scores::Vector{Float64} = [6.0, 6.0, 3.0, 5.0, 7.0]
    @in target_scores::Vector{Float64}   = [4.0, 4.0, 9.0, 9.0, 1.0]
    @in run_analysis::Bool               = false

    @out differentiation_index::Float64   = 0.0
    @out value_innovation_score::Float64  = 0.0
    @out top_opportunities::Vector{String} = ["Run analysis to see results"]
    @out convergence_warnings::Vector{String} = []

    @out canvas_chart::Vector{PlotData} = [
        PlotData(x=["Price","Wait Time","Telehealth","Trust","Inpatient"],
            y=[5.0,7.0,2.0,8.0,4.0], plot="scatterpolar", name="Our Hospital",
            fill="toself", line=PlotDataLine(color="#6366f1")),
        PlotData(x=["Price","Wait Time","Telehealth","Trust","Inpatient"],
            y=[6.0,6.0,3.0,5.0,7.0], plot="scatterpolar", name="Industry",
            fill="toself", line=PlotDataLine(color="#94a3b8")),
        PlotData(x=["Price","Wait Time","Telehealth","Trust","Inpatient"],
            y=[4.0,4.0,9.0,9.0,1.0], plot="scatterpolar", name="Target",
            fill="toself", line=PlotDataLine(color="#22c55e", dash="dash")),
    ]
    @out canvas_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Strategic Canvas"),
        polar=Dict("radialaxis"=>Dict("range"=>[0,10])), showlegend=true)

    @in errors::Vector{String} = String[]

    @onchange run_analysis begin
        if run_analysis
            run_analysis = false
            errors = String[]
            try
                actions = [:reduce,:reduce,:create,:raise,:eliminate]
                n = min(length(factor_names), 5)
                factors = [CompetitiveFactor(
                    name=factor_names[i], industry_score=industry_scores[i],
                    our_score=our_scores[i], target_score=target_scores[i],
                    errc_action=actions[i]) for i in 1:n]
                canvas = StrategicCanvas("My Hospital", factors, Dict())
                r = blue_ocean_analysis(canvas)
                differentiation_index = round(r.differentiation_index, digits=1)
                value_innovation_score = round(r.value_innovation_score, digits=1)
                top_opportunities = r.top_opportunities
                convergence_warnings = r.convergence_warnings
                canvas_chart = [
                    PlotData(x=factor_names[1:n], y=our_scores[1:n], plot="scatterpolar",
                        name="Our Hospital", fill="toself", line=PlotDataLine(color="#6366f1")),
                    PlotData(x=factor_names[1:n], y=industry_scores[1:n], plot="scatterpolar",
                        name="Industry", fill="toself", line=PlotDataLine(color="#94a3b8")),
                    PlotData(x=factor_names[1:n], y=target_scores[1:n], plot="scatterpolar",
                        name="Target", fill="toself", line=PlotDataLine(color="#22c55e", dash="dash")),
                ]
            catch e; errors = ["$(sprint(showerror,e))"]; end
        end
    end
end
const blue_ocean_model = @init
