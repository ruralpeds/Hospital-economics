"""
Stipple reactive model for Data Preparation (E5).
Manages pipeline steps: normalize IDs, code standardization, aggregation,
risk adjustment, imputation, and time-series formatting.
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in source_asset_id::String = ""
    @in transform::String = "normalize_ids"
    @in id_columns::Vector{String} = ["patient_id"]
    @in code_source::String = "icd9"
    @in code_target::String = "icd10"
    @in bucket::String = "episode"
    @in risk_model::String = "hcc"
    @in impute_strategy::String = "median"
    @in impute_columns::Vector{String} = String[]
    @in ts_date_col::String = "encounter_date"
    @in ts_value_col::String = "cost"
    @in ts_interval::String = "monthly"
    @out pipeline_steps::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out preview_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out preview_columns::Vector{String} = String[]
    @in do_run::Bool = false
    @in do_commit::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange do_run begin
        do_run || return
        running = true
        errors = String[]
        try
            pipeline_steps = [
                Dict{String,Any}("step" => transform, "status" => "queued",
                                 "asset_id" => source_asset_id),
            ]
            preview_rows = Dict{String,Any}[]
            preview_columns = String[]
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        do_run = false
    end
end

const data_prepare_model = @init
