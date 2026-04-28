"""
Stipple reactive model for Causal Inference Lab (E13).
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in asset_id::String = ""
    @in method::String = "psm"
    @in treatment_col::String = ""
    @in outcome_col::String = ""
    @in covariate_cols::Vector{String} = String[]
    @in instrument_col::String = ""
    @in running_variable::String = ""
    @in cutoff::Float64 = 0.0
    @in pre_period::String = ""
    @in post_period::String = ""
    @in treated_group::String = ""
    @out treatment_effect::Float64 = 0.0
    @out effect_ci_low::Float64 = 0.0
    @out effect_ci_high::Float64 = 0.0
    @out balance_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out effect_plot_data::Vector{PlotData} = PlotData[]
    @out effect_plot_layout::PlotLayout = PlotLayout()
    @out parallel_trends_data::Vector{PlotData} = PlotData[]
    @out parallel_trends_layout::PlotLayout = PlotLayout()
    @in run::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange run begin
        run || return
        running = true
        errors = String[]
        try
            treatment_effect = 0.0
            effect_ci_low = 0.0
            effect_ci_high = 0.0
            balance_rows = Dict{String,Any}[]
            effect_plot_data = PlotData[]
            parallel_trends_data = PlotData[]
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        run = false
    end
end

const causal_model = @init
