"""
Stipple reactive model for Comparative Effectiveness (E16).
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in cohort_id::String = ""
    @in treatment_col::String = ""
    @in outcome_col::String = ""
    @in facility_id::String = ""
    @in time_period::String = "12months"
    @in provider_col::String = ""
    @in measure_col::String = ""
    @in subgroup_col::String = ""
    @in modifier_col::String = ""
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false

    @out forest_data::Vector{PlotData} = PlotData[]
    @out forest_layout::PlotLayout = PlotLayout()
    @out funnel_data::Vector{PlotData} = PlotData[]
    @out funnel_layout::PlotLayout = PlotLayout()
    @out smr_data::Vector{PlotData} = PlotData[]
    @out smr_layout::PlotLayout = PlotLayout()
    @out result_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @in run::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange run begin
        run || return
        running = true
        errors = String[]
        try
            forest_data = PlotData[]
            funnel_data = PlotData[]
            smr_data = PlotData[]
            result_rows = Dict{String,Any}[]
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        run = false
    end
end

const comparative_model = @init
