"""
Stipple reactive model for Cost Analysis (E7).
Computes total cost of care, episode costs, trend charts, and high-cost patient
identification for a given cohort.
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in cohort_id::String = ""
    @in date_from::String = ""
    @in date_to::String = ""
    @in cost_year::Int = 2024
    @in discount_rate::Float64 = 0.03
    @in high_cost_pct::Float64 = 0.05
    @in categories::Vector{String} = ["inpatient", "outpatient", "pharmacy", "imaging", "lab", "dme"]
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false

    @out total_cost::Float64 = 0.0
    @out total_cost_ci_low::Float64 = 0.0
    @out total_cost_ci_high::Float64 = 0.0
    @out cost_per_qaly::Float64 = 0.0
    @out n_high_cost_patients::Int = 0
    @out breakdown_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out high_cost_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out trend_data::Vector{PlotData} = PlotData[]
    @out trend_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Cost Trend"),
        xaxis = [PlotLayoutAxis(title = "Period")],
        yaxis = [PlotLayoutAxis(title = "Cost (\$)")],
    )
    @out breakdown_data::Vector{PlotData} = PlotData[]
    @out breakdown_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Cost Breakdown by Category"),
        barmode = "stack",
    )
    @in run::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange run begin
        run || return
        running = true
        errors = String[]
        try
            total_cost = 0.0
            total_cost_ci_low = 0.0
            total_cost_ci_high = 0.0
            cost_per_qaly = 0.0
            n_high_cost_patients = 0
            breakdown_rows = Dict{String,Any}[]
            high_cost_rows = Dict{String,Any}[]
            trend_data = PlotData[]
            breakdown_data = PlotData[]
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        run = false
    end
end

const cost_analysis_model = @init
