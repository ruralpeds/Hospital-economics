"""
DataIntakeModel — reactive model for /data/intake (E4).

First user-facing consumer of the Phase 0 Upload component. Lets users
describe the source type for an upload (hospital admin, claims, EHR/clinical,
financial, registry), commit the file via /api/data/upload, and tag the
resulting `DataAsset` with source-specific metadata so downstream tabs can
filter by it.

The upload step itself is owned by `app/components/upload.jl`. This model
declares the upload's reactive fields with the prefix `intake_` and adds
its own state for source-type filters, validation, and the recent-asset
list.
"""
using Stipple, StippleUI, StipplePlotly
using Dates

@app begin
    @in left_drawer_open::Bool = true

    # ── Source-type description form ─────────────────────────────────────
    @in source_type::String   = "hospital"   # hospital|claims|clinical|financial|registry
    @in date_from::String     = ""
    @in date_to::String       = ""
    @in payer_id::String      = "medicare"   # claims only
    @in ehr_system::String    = "epic"       # clinical only
    @in facility_id::String   = ""           # financial only
    @in registry_name::String = "sts"        # registry only
    @in cohort_filters::String = ""          # registry only — JSON

    @out source_type_options::Vector{Dict{String,Any}} = [
        Dict("label" => "Hospital admin",  "value" => "hospital"),
        Dict("label" => "Claims",          "value" => "claims"),
        Dict("label" => "Clinical / EHR",  "value" => "clinical"),
        Dict("label" => "Financial",       "value" => "financial"),
        Dict("label" => "Registry",        "value" => "registry"),
    ]
    @out payer_options::Vector{Dict{String,Any}} = [
        Dict("label" => "Medicare",   "value" => "medicare"),
        Dict("label" => "Medicaid",   "value" => "medicaid"),
        Dict("label" => "Commercial", "value" => "commercial"),
    ]
    @out ehr_options::Vector{Dict{String,Any}} = [
        Dict("label" => "Epic",   "value" => "epic"),
        Dict("label" => "Cerner", "value" => "cerner"),
        Dict("label" => "Other",  "value" => "other"),
    ]
    @out registry_options::Vector{Dict{String,Any}} = [
        Dict("label" => "STS",       "value" => "sts"),
        Dict("label" => "NCDR",      "value" => "ncdr"),
        Dict("label" => "ACS-NSQIP", "value" => "nsqip"),
    ]

    # ── Upload component state (prefix: intake_) ─────────────────────────
    # Matches `upload_model_fields("intake")` from app/components/upload.jl.
    @in  intake_step::Int = 1
    @in  intake_file_staged::Bool = false
    @in  intake_filename::String = ""
    @in  intake_format::String = ""
    @in  intake_file_size_bytes::Int = 0
    @in  intake_row_count::Int = 0
    @out intake_column_names::Vector{String} = String[]
    @out intake_column_types::Dict = Dict()
    @out intake_column_summary::Vector = []
    @out intake_preview_rows::Vector = []
    @out intake_preview_columns::Vector = []
    @out intake_phi_detected::Bool = false
    @out intake_phi_columns::Vector{String} = String[]
    @in  intake_column_mapping::Dict = Dict()
    @out intake_target_fields::Vector{String} = String[]
    @in  intake_validating::Bool = false
    @out intake_validation_rules::Vector = []
    @out intake_validation_failed::Bool = false
    @in  intake_apply_deidentify::Bool = true
    @in  intake_org_salt::String = "HealthcareEconomicsOrg2024"
    @in  intake_committing::Bool = false
    @out intake_committed::Bool = false
    @out intake_asset_id::String = ""
    @out intake_committed_rows::Int = 0
    @out intake_deidentified::Bool = false
    @out intake_audit_entry_id::String = ""
    @out intake_commit_error::Bool = false
    @out intake_commit_error_msg::String = ""

    # ── Validation panel ─────────────────────────────────────────────────
    @in rules_enabled::Vector{String} = ["schema", "icd10", "cpt", "encounter"]
    @out rules_options::Vector{Dict{String,Any}} = [
        Dict("label" => "Schema completeness", "value" => "schema"),
        Dict("label" => "ICD-10 codes",        "value" => "icd10"),
        Dict("label" => "CPT/HCPCS codes",     "value" => "cpt"),
        Dict("label" => "Patient encounter",   "value" => "encounter"),
    ]
    @in run_validation::Bool = false
    @out validation_result::Dict{String,Any} = Dict{String,Any}()
    @out validation_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]

    # ── Tagging ──────────────────────────────────────────────────────────
    # When the upload component finishes (intake_committed flips true), we
    # POST the source-type metadata to /api/ingest/tag so the asset's
    # meta.json picks up source_type / payer_id / etc.
    @in run_tag::Bool = false
    @out tag_result::Dict{String,Any} = Dict{String,Any}()

    # ── Recent assets table ──────────────────────────────────────────────
    @in refresh_recent::Bool = false
    @out recent_assets::Vector{Dict{String,Any}} = Dict{String,Any}[]

    # ── Errors / status ──────────────────────────────────────────────────
    @in errors::Vector{String} = String[]
    @in busy::Bool = false

    # ── Handlers ─────────────────────────────────────────────────────────
    @onchange intake_committed begin
        # Auto-tag the asset with source-type metadata as soon as the
        # universal upload commits. Avoids requiring the user to click
        # twice for the common path.
        if intake_committed && !isempty(intake_asset_id)
            run_tag = true
        end
    end

    @onchange run_tag begin
        run_tag || return
        try
            payload = Dict{String,Any}(
                "asset_id"       => intake_asset_id,
                "source_type"    => source_type,
                "date_from"      => date_from,
                "date_to"        => date_to,
                "payer_id"       => payer_id,
                "ehr_system"     => ehr_system,
                "facility_id"    => facility_id,
                "registry_name"  => registry_name,
                "cohort_filters" => cohort_filters,
            )
            tag_result = IngestionController.tag_asset_metadata(payload)
            refresh_recent = true
        catch e
            push!(errors, sprint(showerror, e))
        finally
            run_tag = false
        end
    end

    @onchange run_validation begin
        run_validation || return
        if isempty(intake_asset_id)
            push!(errors, "Commit an upload before running validation.")
            run_validation = false
            return
        end
        try
            busy = true
            validation_result = IngestionController.run_validation(
                intake_asset_id, rules_enabled,
            )
            validation_rows = get(validation_result, "rules", Dict{String,Any}[])
        catch e
            push!(errors, sprint(showerror, e))
        finally
            busy = false
            run_validation = false
        end
    end

    @onchange refresh_recent begin
        refresh_recent || return
        try
            recent_assets = IngestionController.list_recent_assets(20)
        catch e
            push!(errors, sprint(showerror, e))
        finally
            refresh_recent = false
        end
    end
end

const data_intake_model = @init
