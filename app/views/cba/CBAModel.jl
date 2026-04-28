"""
Stipple reactive model for Cost-Benefit Analysis & Budget Impact (E15).
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in discount_rate::Float64 = 0.03
    @in cost_year::Int = 2024
    @in time_horizon::Int = 10
    @in cashflow_rows::Vector{Dict{String,Any}} = [
        Dict("year"=>1,"cost"=>100000.0,"benefit"=>80000.0),
    ]
    @in population_size::Int = 10_000
    @in adoption_rate_start::Float64 = 0.05
    @in adoption_rate_max::Float64 = 0.80
    @in cost_per_patient::Float64 = 500.0
    @in population_growth::Float64 = 0.02
    @out npv::Float64 = 0.0
    @out roi::Float64 = 0.0
    @out bcr::Float64 = 0.0
    @out irr::Float64 = 0.0
    @out break_even_year::Int = 0
    @out cashflow_plot_data::Vector{PlotData} = PlotData[]
    @out cashflow_plot_layout::PlotLayout = PlotLayout()
    @out budget_impact_data::Vector{PlotData} = PlotData[]
    @out budget_impact_layout::PlotLayout = PlotLayout()
    @in run::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange run begin
        run || return
        running = true
        errors = String[]
        try
            npv = 0.0
            roi = 0.0
            bcr = 0.0
            irr = 0.0
            break_even_year = 0
            cashflow_plot_data = PlotData[]
            budget_impact_data = PlotData[]
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        run = false
    end
end

const cba_model = @init
