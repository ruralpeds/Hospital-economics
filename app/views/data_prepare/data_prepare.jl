"""
Data Preparation UI (E5) — pipeline steps, transform selection, preview table.
"""

function ui_data_prepare(model)
    app_layout(model, "Data Preparation", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Data Preparation", class="q-mb-none"),
                p("Normalize IDs, standardize codes, aggregate episodes, risk-adjust, and impute",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Run Pipeline", icon="play_arrow", color="primary",
                    @click(:do_run),
                    var":loading"="running"),
                btn("Commit Output", icon="save", color="secondary",
                    class="q-ml-sm", @click(:do_commit),
                    var":disable"="running || pipeline_steps.length === 0"),
            ]),
        ]),

        # Error banner
        template(var"v-if"="errors && errors.length > 0", [
            card(class="q-mb-md bg-red-1 text-red-9", [
                card_section([
                    p("Errors:", class="text-weight-bold q-mb-xs"),
                    template(var"v-for"="(err, idx) in errors", var":key"="idx", [
                        p(class="q-mb-none", ["{{ err }}"]),
                    ]),
                ]),
            ]),
        ]),

        # Configuration
        form_grid([
            (name=:source_asset_id, type=:numeric, label="Source Asset ID",
             help="Asset ID from the Data Intake step"),
            (name=:transform, type=:select, label="Transform",
             options=[
                 Dict(:label=>"Normalize IDs",        :value=>"normalize_ids"),
                 Dict(:label=>"Standardize Codes",    :value=>"standardize_codes"),
                 Dict(:label=>"Aggregate Episodes",   :value=>"aggregate"),
                 Dict(:label=>"Risk Adjust",          :value=>"risk_adjust"),
                 Dict(:label=>"Impute Missing",       :value=>"impute"),
                 Dict(:label=>"Time-Series Format",   :value=>"time_series"),
             ]),
            (name=:code_source, type=:select, label="Source Code System",
             options=[
                 Dict(:label=>"ICD-9-CM",  :value=>"icd9"),
                 Dict(:label=>"ICD-10-CM", :value=>"icd10"),
                 Dict(:label=>"CPT-4",     :value=>"cpt4"),
                 Dict(:label=>"HCPCS",     :value=>"hcpcs"),
             ],
             visible_when="transform === 'standardize_codes'"),
            (name=:code_target, type=:select, label="Target Code System",
             options=[
                 Dict(:label=>"ICD-10-CM", :value=>"icd10"),
                 Dict(:label=>"ICD-11",    :value=>"icd11"),
             ],
             visible_when="transform === 'standardize_codes'"),
            (name=:bucket, type=:select, label="Episode Bucket",
             options=[
                 Dict(:label=>"Episode",  :value=>"episode"),
                 Dict(:label=>"30-Day",   :value=>"30day"),
                 Dict(:label=>"90-Day",   :value=>"90day"),
                 Dict(:label=>"Annual",   :value=>"annual"),
             ],
             visible_when="transform === 'aggregate'"),
            (name=:risk_model, type=:select, label="Risk Model",
             options=[
                 Dict(:label=>"CMS-HCC",      :value=>"hcc"),
                 Dict(:label=>"ACG",           :value=>"acg"),
                 Dict(:label=>"DxCG",          :value=>"dxcg"),
                 Dict(:label=>"Charlson CCI",  :value=>"charlson"),
             ],
             visible_when="transform === 'risk_adjust'"),
            (name=:impute_strategy, type=:select, label="Impute Strategy",
             options=[
                 Dict(:label=>"Median",    :value=>"median"),
                 Dict(:label=>"Mean",      :value=>"mean"),
                 Dict(:label=>"Mode",      :value=>"mode"),
                 Dict(:label=>"Zero",      :value=>"zero"),
                 Dict(:label=>"Drop Rows", :value=>"drop"),
             ],
             visible_when="transform === 'impute'"),
            (name=:ts_date_col,   type=:text, label="Date Column",
             visible_when="transform === 'time_series'"),
            (name=:ts_value_col,  type=:text, label="Value Column",
             visible_when="transform === 'time_series'"),
            (name=:ts_interval, type=:select, label="Interval",
             options=[
                 Dict(:label=>"Daily",    :value=>"daily"),
                 Dict(:label=>"Weekly",   :value=>"weekly"),
                 Dict(:label=>"Monthly",  :value=>"monthly"),
                 Dict(:label=>"Quarterly",:value=>"quarterly"),
                 Dict(:label=>"Annual",   :value=>"annual"),
             ],
             visible_when="transform === 'time_series'"),
        ], title="Pipeline Configuration"),

        # Pipeline steps status
        template(var"v-if"="pipeline_steps && pipeline_steps.length > 0", [
            result_table(
                :pipeline_steps,
                columns=[
                    (name="step",     label="Step",     field="step",     sortable=false),
                    (name="status",   label="Status",   field="status",   sortable=false),
                    (name="asset_id", label="Asset ID", field="asset_id", sortable=false),
                ],
                title="Pipeline Steps",
            ),
        ]),

        # Preview table
        template(var"v-if"="preview_rows && preview_rows.length > 0", [
            result_table(
                :preview_rows,
                title="Output Preview (first 20 rows)",
                rows_per_page=20,
            ),
        ]),
    ])
end
