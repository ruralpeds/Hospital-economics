"""
Stipple reactive model for Scenario & Sensitivity Lab (E22).
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in base_params::Dict{String,Any} = Dict{String,Any}()
    @in param_ranges::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @in n_psa_iterations::Int = 1000
    @in param1_name::String = ""
    @in param1_range::Vector{Float64} = Float64[]
    @in param2_name::String = ""
    @in param2_range::Vector{Float64} = Float64[]
    @out best_case::Dict{String,Any} = Dict{String,Any}()
    @out base_case::Dict{String,Any} = Dict{String,Any}()
    @out worst_case::Dict{String,Any} = Dict{String,Any}()
    @out tornado_data::Vector{PlotData} = PlotData[]
    @out tornado_layout::PlotLayout = PlotLayout()
    @out heatmap_data::Vector{PlotData} = PlotData[]
    @out heatmap_layout::PlotLayout = PlotLayout()
    @out psa_data::Vector{PlotData} = PlotData[]
    @out psa_layout::PlotLayout = PlotLayout()
    @in run_scenarios::Bool = false
    @in run_tornado::Bool = false
    @in run_2way::Bool = false
    @in run_psa::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange run_scenarios begin
        run_scenarios || return
        running = true
        errors = String[]
        try
            best_case = Dict{String,Any}()
            base_case = Dict{String,Any}()
            worst_case = Dict{String,Any}()
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        run_scenarios = false
    end
end

const scenario_lab_model = @init
