"""
Stipple reactive model for Network & Systems (E21).
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in referral_asset_id::String = ""
    @in patient_pathway_id::String = ""
    @in encounters_asset_id::String = ""
    @in starting_condition::String = "chest_pain"
    @in rng_seed::Int = 42
    @in active_tab::String = "network"
    @out network_data::Vector{PlotData} = PlotData[]
    @out network_layout::PlotLayout = PlotLayout()
    @out sankey_data::Vector{PlotData} = PlotData[]
    @out sankey_layout::PlotLayout = PlotLayout()
    @out pathway_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out gap_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out team_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @in do_network::Bool = false
    @in do_pathway::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange do_network begin
        do_network || return
        running = true
        errors = String[]
        try
            network_data = PlotData[]
            sankey_data = PlotData[]
            pathway_rows = Dict{String,Any}[]
            gap_rows = Dict{String,Any}[]
            team_rows = Dict{String,Any}[]
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        do_network = false
    end
end

const systems_model = @init
