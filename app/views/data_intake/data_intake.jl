"""
DataIntakeView — /data/intake (E4).

Composition:
  1. Source-type form (form_grid) — describes the upload's metadata.
  2. Upload component (universal multi-format intake from Phase 0).
  3. Validation panel — drives /api/ingest/validate against the committed asset.
  4. Recent-assets table — committed uploads with their source-type tags.
"""

function ui_data_intake(model)
    # The universal upload component is rendered by injecting the raw HTML
    # block it produces, which already contains its own q-stepper + reactive
    # bindings (matching the prefix "intake_" declared in DataIntakeModel.jl).
    upload_html = upload(
        id        = :intake,
        schema    = "patient",
        allow_phi = false,    # default-on de-identification for any PHI hits
    )

    app_layout(model, "Data Intake", [
        page_header(
            "Data Intake",
            "Upload a CSV, XLSX, JSON, or Parquet file and tag it with " *
            "the source type so downstream tabs can pick it up.",
            Pair{String,String}["Data" => "/data/intake",
                                "Intake" => "/data/intake"],
        ),

        error_banner(:errors),

        # ── 1. Describe the data ─────────────────────────────────────────
        form_grid([
            (name=:source_type, type=:select, label="Source type",
             help="Determines which downstream tabs treat this asset as input.",
             options=[Dict(:label=>"Hospital admin", :value=>"hospital"),
                      Dict(:label=>"Claims",         :value=>"claims"),
                      Dict(:label=>"Clinical / EHR", :value=>"clinical"),
                      Dict(:label=>"Financial",      :value=>"financial"),
                      Dict(:label=>"Registry",       :value=>"registry")]),

            (name=:date_from, type=:date, label="From",
             visible_when="source_type==='claims' || source_type==='registry'"),
            (name=:date_to,   type=:date, label="To",
             visible_when="source_type==='claims' || source_type==='registry'"),

            (name=:payer_id, type=:select, label="Payer",
             options=[Dict(:label=>"Medicare",   :value=>"medicare"),
                      Dict(:label=>"Medicaid",   :value=>"medicaid"),
                      Dict(:label=>"Commercial", :value=>"commercial")],
             visible_when="source_type==='claims'"),

            (name=:ehr_system, type=:select, label="EHR system",
             options=[Dict(:label=>"Epic",   :value=>"epic"),
                      Dict(:label=>"Cerner", :value=>"cerner"),
                      Dict(:label=>"Other",  :value=>"other")],
             visible_when="source_type==='clinical'"),

            (name=:facility_id, type=:numeric, label="CCN / Facility ID",
             help="Medicare CMS Certification Number, 6 digits.",
             visible_when="source_type==='financial'"),

            (name=:registry_name, type=:select, label="Registry",
             options=[Dict(:label=>"STS",       :value=>"sts"),
                      Dict(:label=>"NCDR",      :value=>"ncdr"),
                      Dict(:label=>"ACS-NSQIP", :value=>"nsqip")],
             visible_when="source_type==='registry'"),

            (name=:cohort_filters, type=:numeric, label="Cohort filter (JSON)",
             help="Optional JSON document describing inclusion criteria.",
             visible_when="source_type==='registry'"),
        ], title="1. Describe your data"),

        # ── 2. Upload + commit ───────────────────────────────────────────
        Html.div(class="q-mt-lg",
            Genie.Renderer.Html.raw(upload_html)),

        # ── 3. Validation panel ──────────────────────────────────────────
        card(class="q-mb-md q-mt-lg", [
            card_section([
                h6("3. Validate the committed asset", class="q-mb-md"),
                row(class="q-gutter-md items-end", [
                    cell(class="col", [
                        q__select(:rules_enabled,
                            options=:rules_options,
                            label="Rules",
                            multiple=true,
                            filled=true, dense=true,
                            var"emit-value"=true, var"map-options"=true,
                            var"use-chips"=true),
                    ]),
                    cell(class="col-auto", [
                        btn("Run validation",
                            icon="rule",
                            color="primary",
                            loading=:busy,
                            disable="!intake_asset_id",
                            @click(:run_validation)),
                    ]),
                ]),
                Html.div(class="text-caption text-grey-7 q-mt-xs",
                    "Validation runs against the most recently committed asset " *
                    "(asset_id: {{ intake_asset_id || '—' }})."),
            ]),
        ]),

        result_table(:validation_rows;
            title="Validation results",
            columns=[
                Dict("name" => "rule",      "label" => "Rule",      "field" => "rule",      "align" => "left"),
                Dict("name" => "passed",    "label" => "Passed",    "field" => "passed",    "align" => "center"),
                Dict("name" => "failed",    "label" => "Failed",    "field" => "failed",    "align" => "center"),
                Dict("name" => "row_count", "label" => "Rows",      "field" => "row_count", "align" => "right"),
                Dict("name" => "message",   "label" => "Message",   "field" => "message",   "align" => "left"),
            ],
            empty_message="Run validation to populate this table.",
        ),

        # ── 4. Recent assets ─────────────────────────────────────────────
        card(class="q-mb-md q-mt-lg", [
            card_section([
                row(class="q-mb-md items-center", [
                    cell(class="col", [
                        h6("4. Recently committed assets", class="q-mb-none"),
                    ]),
                    cell(class="col-auto", [
                        btn("Refresh", icon="refresh", flat=true,
                            color="primary", @click(:refresh_recent)),
                    ]),
                ]),
            ]),
        ]),

        result_table(:recent_assets;
            columns=[
                Dict("name" => "committed_at", "label" => "Committed",   "field" => "committed_at", "align" => "left"),
                Dict("name" => "asset_id",     "label" => "Asset",       "field" => "asset_id",     "align" => "left"),
                Dict("name" => "filename",     "label" => "File",        "field" => "filename",     "align" => "left"),
                Dict("name" => "format",       "label" => "Format",      "field" => "format",       "align" => "left"),
                Dict("name" => "source_type",  "label" => "Source type", "field" => "source_type",  "align" => "left"),
                Dict("name" => "row_count",    "label" => "Rows",        "field" => "row_count",    "align" => "right"),
                Dict("name" => "deidentified", "label" => "De-id",       "field" => "deidentified", "align" => "center"),
            ],
            empty_message="No assets committed yet.",
        ),
    ])
end
