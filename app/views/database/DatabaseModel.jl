"""
Stipple reactive model for Database & Queries (E19).
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in entity_type::String = "patients"
    @in date_from::String = ""
    @in date_to::String = ""
    @in payer_filter::String = ""
    @in facility_filter::String = ""
    @in account_code::String = ""
    @in query_name::String = ""
    @in version_name::String = ""
    @out result_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out result_count::Int = 0
    @out saved_queries::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out version_history::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @in run_query::Bool = false
    @in save_query::Bool = false
    @in save_dataset::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange run_query begin
        run_query || return
        running = true
        errors = String[]
        try
            result_rows = Dict{String,Any}[]
            result_count = 0
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        run_query = false
    end
end

const database_model = @init
