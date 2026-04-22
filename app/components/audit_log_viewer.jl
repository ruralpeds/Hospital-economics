"""
AuditLogViewer — `app/components/audit_log_viewer.jl`

Renders entries from `src/data_ingestion/audit_logger.jl` in a sortable,
filterable table with column-level filtering (user, action/event type,
date range, status).

Required model fields (declared by the caller):
  audit_entries::Vector{Dict{String,Any}} = []
  audit_filter_user::String   = ""
  audit_filter_action::String = ""
  audit_filter_date_start::String = ""
  audit_filter_date_end::String   = ""
  audit_filter_status::String = ""
  audit_refresh::Bool         = false   # toggled to re-fetch log
  audit_export_csv::Bool      = false   # toggled to download CSV

Each entry dict should carry the keys that `AuditLogEntry` produces:
  "user_id", "event_type", "resource_id", "record_count",
  "ip_address", "status", "timestamp" (ISO string)

Usage:
```julia
audit_log_viewer()
```

Pass `prefix="my_audit_"` to namespace all reactive field names.
"""

"""
    audit_log_viewer(; prefix="audit_", class="")

Render the audit log viewer panel with filter controls and a data table.
"""
function audit_log_viewer(; prefix::String = "audit_", class::String = "")
    pf = Symbol ∘ (s -> prefix * s)

    status_opts = """[
        { label: 'All',            value: '' },
        { label: 'SUCCESS',        value: 'SUCCESS' },
        { label: 'PARTIAL',        value: 'PARTIAL_SUCCESS' },
        { label: 'FAILED',         value: 'FAILED' },
    ]"""

    action_opts = """[
        { label: 'All',                 value: '' },
        { label: 'INGESTION_START',     value: 'INGESTION_START' },
        { label: 'INGESTION_COMPLETE',  value: 'INGESTION_COMPLETE' },
        { label: 'RECORD_VALIDATED',    value: 'RECORD_VALIDATED' },
        { label: 'RECORD_DEIDENTIFIED', value: 'RECORD_DEIDENTIFIED' },
        { label: 'VALIDATION_ERROR',    value: 'VALIDATION_ERROR' },
        { label: 'EXPORT_INITIATED',    value: 'EXPORT_INITIATED' },
        { label: 'EXPORT_COMPLETE',     value: 'EXPORT_COMPLETE' },
        { label: 'QUALITY_REPORT',      value: 'QUALITY_REPORT' },
    ]"""

    cols_js = """[
        { name: 'timestamp',   label: 'Timestamp',    field: 'timestamp',   sortable: true,  align: 'left' },
        { name: 'user_id',     label: 'User',         field: 'user_id',     sortable: true,  align: 'left' },
        { name: 'event_type',  label: 'Action',       field: 'event_type',  sortable: true,  align: 'left' },
        { name: 'resource_id', label: 'Resource',     field: 'resource_id', sortable: false, align: 'left' },
        { name: 'record_count',label: 'Records',      field: 'record_count',sortable: true,  align: 'right' },
        { name: 'status',      label: 'Status',       field: 'status',      sortable: true,  align: 'left' },
        { name: 'ip_address',  label: 'IP',           field: 'ip_address',  sortable: false, align: 'left' },
    ]"""

    card(class="q-mb-md " * class, [
        card_section([
            # ── Header ─────────────────────────────────────────────────
            row(class="items-center q-mb-md", [
                cell(class="col", [
                    h6("Audit Log", class="q-mb-none"),
                    p("HIPAA §164.312(b) — all PHI access events",
                      class="text-caption text-grey-7 q-mb-none"),
                ]),
                cell(class="col-auto", [
                    btn("Refresh", icon="refresh", flat=true, color="primary",
                        dense=true, @click(pf("refresh"))),
                    btn("CSV", icon="download", flat=true, color="secondary",
                        dense=true, @click(pf("export_csv"))),
                ]),
            ]),

            # ── Filters ─────────────────────────────────────────────────
            row(class="q-gutter-md q-mb-md", [
                cell(class="col-md-3 col-xs-12", [
                    textfield(pf("filter_user"),
                        label="Filter by user",
                        filled=true, dense=true, clearable=true),
                ]),
                cell(class="col-md-3 col-xs-12", [
                    select(pf("filter_action"),
                        label="Action type",
                        filled=true, dense=true,
                        var":options"=action_opts,
                        var"option-label"="opt => opt.label",
                        var"option-value"="opt => opt.value",
                        var"emit-value"=true, var"map-options"=true),
                ]),
                cell(class="col-md-2 col-xs-6", [
                    textfield(pf("filter_date_start"),
                        label="From", filled=true, dense=true, type="date"),
                ]),
                cell(class="col-md-2 col-xs-6", [
                    textfield(pf("filter_date_end"),
                        label="To", filled=true, dense=true, type="date"),
                ]),
                cell(class="col-md-2 col-xs-12", [
                    select(pf("filter_status"),
                        label="Status",
                        filled=true, dense=true,
                        var":options"=status_opts,
                        var"option-label"="opt => opt.label",
                        var"option-value"="opt => opt.value",
                        var"emit-value"=true, var"map-options"=true),
                ]),
            ]),

            # ── Table ────────────────────────────────────────────────────
            quasar(:table,
                Symbol(":columns")     => cols_js,
                Symbol(":rows")        => string(pf("entries")),
                Symbol(":rows-per-page-options") => "[10, 25, 50, 0]",
                Symbol("flat")         => true,
                Symbol("bordered")     => true,
                Symbol("dense")        => true,
                [
                    # Status badge slot
                    template("", var"v-slot:body-cell-status"="props", [
                        Html.td([
                            quasar(:badge,
                                var":color"="""props.row.status === 'SUCCESS' ? 'positive' :
                                               props.row.status === 'FAILED'  ? 'negative' : 'warning'""",
                                var":label"="props.row.status"),
                        ]),
                    ]),
                ]
            ),
        ]),
    ])
end
