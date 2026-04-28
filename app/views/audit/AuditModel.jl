"""
Stipple reactive model for Audit & Governance (E24).
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in active_sub_tab::String = "config"
    @in config_file_path::String = ""
    @in global_discount_rate::Float64 = 0.03
    @in global_cost_year::Int = 2024
    @in inflation_base_year::Int = 2020
    @in audit_analysis_id::String = ""
    @in audit_filter_from::String = ""
    @in audit_filter_to::String = ""
    @in deid_asset_id::String = ""
    @in deid_pii_columns::Vector{String} = String[]
    @in deid_salt::String = ""
    @out audit_log_entries::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out deid_result::Dict{String,Any} = Dict{String,Any}()
    @out config_status::String = ""
    @in save_config::Bool = false
    @in load_audit::Bool = false
    @in run_deid::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange save_config begin
        save_config || return
        running = true
        errors = String[]
        try
            config_status = ""
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        save_config = false
    end
end

const audit_model = @init
