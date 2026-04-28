"""
Stipple reactive model for Cost-Effectiveness Analysis (E14).
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in wtp_threshold::Float64 = 100_000.0
    @in n_simulations::Int = 1000
    @in strategy_rows::Vector{Dict{String,Any}} = [
        Dict("name"=>"Standard Care","cost"=>50000.0,"effect"=>0.8),
        Dict("name"=>"New Intervention","cost"=>75000.0,"effect"=>0.95),
    ]
    @out icer_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out inb::Float64 = 0.0
    @out nmb::Float64 = 0.0
    @out ce_plane_data::Vector{PlotData} = PlotData[]
    @out ce_plane_layout::PlotLayout = PlotLayout()
    @out ceac_data::Vector{PlotData} = PlotData[]
    @out ceac_layout::PlotLayout = PlotLayout()
    @out tornado_data::Vector{PlotData} = PlotData[]
    @out tornado_layout::PlotLayout = PlotLayout()
    @in run::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange run begin
        run || return
        running = true
        errors = String[]
        try
            icer_rows = Dict{String,Any}[]
            inb = 0.0
            nmb = 0.0
            ce_plane_data = PlotData[]
            ceac_data = PlotData[]
            tornado_data = PlotData[]
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        run = false
    end
end

const cea_model = @init
