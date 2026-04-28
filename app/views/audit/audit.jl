"""
Audit & Governance UI (E24) — global config, audit log viewer,
and HIPAA de-identification with three sub-tabs.
"""

function ui_audit(model)
    app_layout(model, "Audit & Governance", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Audit & Governance", class="q-mb-none"),
                p("Global configuration, audit log viewer, data lineage, and HIPAA de-identification",
                  class="text-grey-7"),
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

        # Sub-tabs
        qtabs(:active_sub_tab, class="q-mb-md", [
            qtab(name="config",      label="Global Config"),
            qtab(name="auditlog",    label="Audit Log"),
            qtab(name="deidentify",  label="De-Identify"),
        ]),
        qtabpanels(:active_sub_tab, [
            # Config tab
            qtabpanel(name="config", [
                form_grid([
                    (name=:config_file_path,      type=:text,    label="Config File Path",
                     help="Optional path to TOML/JSON config file"),
                    (name=:global_discount_rate,  type=:numeric, label="Global Discount Rate",
                     help="Applied across all economic analyses (e.g. 0.03)"),
                    (name=:global_cost_year,      type=:numeric, label="Cost Reference Year"),
                    (name=:inflation_base_year,   type=:numeric, label="Inflation Base Year"),
                ], title="Global Settings"),

                row(class="q-mb-md q-gutter-sm", [
                    cell(class="col-auto", [
                        btn("Save Config", icon="save", color="primary",
                            @click(:save_config), var":loading"="running"),
                    ]),
                ]),

                template(var"v-if"="config_status", [
                    card(class="q-mb-md bg-green-1 text-green-9", [
                        card_section([
                            p("{{ config_status }}", class="q-mb-none"),
                        ]),
                    ]),
                ]),
            ]),

            # Audit log tab
            qtabpanel(name="auditlog", [
                form_grid([
                    (name=:audit_analysis_id, type=:text, label="Analysis ID Filter",
                     help="Filter log by analysis ID (leave blank for all)"),
                    (name=:audit_filter_from, type=:date, label="Date From"),
                    (name=:audit_filter_to,   type=:date, label="Date To"),
                ], title="Log Filters"),

                row(class="q-mb-md", [
                    cell(class="col-auto", [
                        btn("Load Audit Log", icon="history", color="primary",
                            @click(:load_audit), var":loading"="running"),
                    ]),
                ]),

                result_table(
                    :audit_log_entries,
                    columns=[
                        (name="timestamp",    label="Timestamp",   field="timestamp",    sortable=true),
                        (name="analysis_id",  label="Analysis ID", field="analysis_id",  sortable=true),
                        (name="user",         label="User",        field="user",         sortable=true),
                        (name="action",       label="Action",      field="action",       sortable=true),
                        (name="params_hash",  label="Params Hash", field="params_hash",  sortable=false),
                        (name="result_hash",  label="Result Hash", field="result_hash",  sortable=false),
                    ],
                    title="Audit Log",
                ),

                export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
            ]),

            # De-identify tab
            qtabpanel(name="deidentify", [
                form_grid([
                    (name=:deid_asset_id, type=:text, label="Source Asset ID",
                     help="Dataset to de-identify"),
                    (name=:deid_salt,     type=:text, label="Hash Salt",
                     help="Secret salt for pseudonymization (keep secure)"),
                ], title="De-Identification Settings"),

                row(class="q-mb-md", [
                    cell(class="col-auto", [
                        btn("Run De-Identification", icon="privacy_tip", color="warning",
                            @click(:run_deid), var":loading"="running"),
                    ]),
                ]),

                template(var"v-if"="deid_result && deid_result.status", [
                    card(class="q-mb-md", [
                        card_section([
                            h6("De-Identification Result", class="q-mb-sm"),
                            p("Status: {{ deid_result.status }}"),
                            p("Records processed: {{ deid_result.records_processed || '—' }}"),
                            p("Output asset ID: {{ deid_result.output_asset_id || '—' }}"),
                        ]),
                    ]),
                ]),
            ]),
        ]),
    ])
end
