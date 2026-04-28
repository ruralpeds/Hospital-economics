"""
Data Intake UI (E4) — upload, source selection, validation, recent assets.
"""

function ui_data_intake(model)
    app_layout(model, "Data Intake", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Data Intake", class="q-mb-none"),
                p("Ingest hospital, claims, clinical, financial, and registry data",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Run Validation", icon="verified", color="primary",
                    @click(:run_validation),
                    var":loading"="running"),
            ]),
        ]),

        # Error banner
        template(var"v-if"="errors && errors.length > 0", [
            card(class="q-mb-md bg-red-1 text-red-9", [
                card_section([
                    p("Errors:", class="text-weight-bold q-mb-xs"),
                    template(var"v-for"="(err, idx) in errors", var":key"="idx", [
                        p(var":key"="idx", class="q-mb-none", [
                            span("{{ err }}")
                        ]),
                    ]),
                ]),
            ]),
        ]),

        # Upload component
        card(class="q-mb-md", [
            card_section([
                h6("Upload Data File", class="q-mb-md"),
                p("Drag and drop a CSV, XLSX, JSON, Parquet, or HCRIS file, or click to browse.",
                  class="text-grey-7 q-mb-md"),
                quasar(:uploader, label="Drop file here or click", color="primary",
                    flat=true, bordered=true, class="full-width",
                    var"accept"=".csv,.xlsx,.json,.parquet,.feather,.rpt",
                    var"max-file-size"="524288000"),
            ]),
        ]),

        # Source type + conditional fields
        form_grid([
            (name=:source_type, type=:select, label="Source Type",
             options=[
                 Dict(:label=>"Hospital (HCRIS/Cost Report)", :value=>"hospital"),
                 Dict(:label=>"Claims (UB-04 / 837I)", :value=>"claims"),
                 Dict(:label=>"Clinical (EHR / FHIR)", :value=>"clinical"),
                 Dict(:label=>"Financial (GL / Trial Balance)", :value=>"financial"),
                 Dict(:label=>"Registry", :value=>"registry"),
             ]),
            (name=:date_from, type=:date, label="Date From"),
            (name=:date_to,   type=:date, label="Date To"),
            (name=:facility_id,    type=:numeric, label="Facility ID",
             visible_when="source_type === 'hospital' || source_type === 'financial'"),
            (name=:payer_id,       type=:numeric, label="Payer ID",
             visible_when="source_type === 'claims'"),
            (name=:ehr_system,     type=:select, label="EHR System",
             options=[
                 Dict(:label=>"Epic", :value=>"epic"),
                 Dict(:label=>"Cerner", :value=>"cerner"),
                 Dict(:label=>"Meditech", :value=>"meditech"),
                 Dict(:label=>"Other", :value=>"other"),
             ],
             visible_when="source_type === 'clinical'"),
            (name=:registry_name, type=:numeric, label="Registry Name",
             visible_when="source_type === 'registry'"),
            (name=:cohort_filters, type=:numeric, label="Cohort Filters",
             visible_when="source_type === 'registry'"),
        ], title="Source Configuration"),

        # Validation rules panel
        card(class="q-mb-md", [
            card_section([
                h6("Validation Rules", class="q-mb-md"),
                row(class="q-gutter-md", [
                    cell(class="col-auto", [
                        toggle(:rules_enabled, label="Schema",
                            var":val"="'schema'"),
                    ]),
                    cell(class="col-auto", [
                        toggle(:rules_enabled, label="ICD-10",
                            var":val"="'icd10'"),
                    ]),
                    cell(class="col-auto", [
                        toggle(:rules_enabled, label="CPT",
                            var":val"="'cpt'"),
                    ]),
                    cell(class="col-auto", [
                        toggle(:rules_enabled, label="Encounter",
                            var":val"="'encounter'"),
                    ]),
                ]),
                template(var"v-if"="validation_result && validation_result.status", [
                    separator(class="q-my-md"),
                    p("Validation Result:", class="text-weight-bold q-mb-xs"),
                    p("Status: {{ validation_result.status }}", class="q-mb-none"),
                    p("Asset ID: {{ validation_result.asset_id }}", class="q-mb-none"),
                    p("Rules: {{ (validation_result.rules || []).join(', ') }}", class="q-mb-none"),
                ]),
            ]),
        ]),

        # Recent assets table
        result_table(
            :recent_assets,
            columns=[
                (name="asset_id",   label="Asset ID",   field="asset_id",   sortable=true),
                (name="source",     label="Source",     field="source",     sortable=true),
                (name="row_count",  label="Rows",       field="row_count",  sortable=true, format="number"),
                (name="phi",        label="PHI",        field="phi_detected", sortable=false),
                (name="created_at", label="Ingested At", field="created_at", sortable=true),
            ],
            title="Recent Uploads",
        ),
    ])
end
