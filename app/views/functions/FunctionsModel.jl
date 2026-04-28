"""
Stipple reactive model for Function Explorer (E23).
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in search_query::String = ""
    @in section_filter::String = "all"
    @in status_filter::String = "all"
    @out filtered_functions::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out all_functions::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @in selected_function::String = ""
    @in inline_params::String = "{}"
    @out inline_result::String = ""
    @in run_inline::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange run_inline begin
        run_inline || return
        running = true
        errors = String[]
        try
            inline_result = ""
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        run_inline = false
    end
end

const functions_model = @init
