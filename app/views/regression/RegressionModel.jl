"""
Stipple reactive model for Regression Lab (E12).
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in asset_id::String = ""
    @in model_type::String = "ols"
    @in outcome_col::String = ""
    @in predictor_cols::Vector{String} = String[]
    @in include_interactions::Bool = false
    @in robust_se::Bool = true
    @in fixed_effects::Vector{String} = String[]
    @out coef_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out model_stats::Dict{String,Any} = Dict{String,Any}()
    @out diagnostic_data::Vector{PlotData} = PlotData[]
    @out diagnostic_layout::PlotLayout = PlotLayout()
    @out vif_data::Vector{PlotData} = PlotData[]
    @out vif_layout::PlotLayout = PlotLayout()
    @in run::Bool = false
    @in save_model::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange run begin
        run || return
        running = true
        errors = String[]
        try
            coef_rows = Dict{String,Any}[]
            model_stats = Dict{String,Any}()
            diagnostic_data = PlotData[]
            vif_data = PlotData[]
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        run = false
    end
end

const regression_model = @init
