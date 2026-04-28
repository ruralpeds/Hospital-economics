"""
Stipple reactive model for Descriptive & Inferential Statistics (E11).
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in asset_id::String = ""
    @in variable_col::String = ""
    @in group_col::String = ""
    @in outcome_col::String = ""
    @in test_type::String = "ttest"
    @in confidence_level::Float64 = 0.95
    @in active_sub_tab::String = "descriptive"
    @out summary_stats::Dict{String,Any} = Dict{String,Any}()
    @out test_result::Dict{String,Any} = Dict{String,Any}()
    @out table1_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out stats_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out dist_data::Vector{PlotData} = PlotData[]
    @out dist_layout::PlotLayout = PlotLayout()
    @in run::Bool = false
    @in do_export::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange run begin
        run || return
        running = true
        errors = String[]
        try
            summary_stats = Dict{String,Any}()
            test_result = Dict{String,Any}()
            table1_rows = Dict{String,Any}[]
            stats_rows = Dict{String,Any}[]
            dist_data = PlotData[]
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        run = false
    end
end

const stats_model = @init
