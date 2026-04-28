"""
Stipple reactive model for Data Intake (E4).
Manages file upload, source selection, validation rules, and committed assets.
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in source_type::String = "hospital"
    @in date_from::String = ""
    @in date_to::String = ""
    @in payer_id::String = ""
    @in ehr_system::String = "epic"
    @in facility_id::String = ""
    @in registry_name::String = ""
    @in cohort_filters::String = ""
    @in committed_asset_id::String = ""
    @in committed_phi_detected::Bool = false
    @in committed_row_count::Int = 0
    @in errors::Vector{String} = String[]
    @in running::Bool = false
    @out recent_assets::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @in rules_enabled::Vector{String} = ["schema", "icd10", "cpt", "encounter"]
    @out validation_result::Dict{String,Any} = Dict{String,Any}()
    @in run_validation::Bool = false

    @onchange run_validation begin
        run_validation || return
        running = true
        errors = String[]
        try
            validation_result = Dict{String,Any}(
                "status" => "pending",
                "asset_id" => committed_asset_id,
                "rules" => rules_enabled,
                "checked_at" => string(now()),
            )
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        run_validation = false
    end
end

const data_intake_model = @init
