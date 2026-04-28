# AuditLogViewer

**Component file:** `app/components/audit_log_viewer.jl`  
**Demo route:** `/dev/components#sec-auditlog` (dev environment only)

## Overview

`AuditLogViewer` renders HIPAA-compliant audit log entries from `src/data_ingestion/audit_logger.jl` in a dense, sortable Quasar table with column-level filters (user, action type, date range, status). It includes a Refresh button and a CSV export button.

Per HIPAA §164.312(b) — Audit Controls — all PHI access events must be logged, and this component provides the operational view of those logs.

## Usage

```julia
audit_log_viewer(;
    prefix = "audit_",
    class  = "",
)
```

### Arguments

| Argument | Type | Description |
|---|---|---|
| `prefix` | `String` | Namespace prefix for all reactive field names (default `"audit_"`) |
| `class` | `String` | Extra CSS classes for the outer card |

## Required model fields

```julia
@out audit_entries::Vector{Dict{String,Any}} = []
@in  audit_filter_user::String        = ""
@in  audit_filter_action::String      = ""
@in  audit_filter_date_start::String  = ""
@in  audit_filter_date_end::String    = ""
@in  audit_filter_status::String      = ""
@in  audit_refresh::Bool              = false
@in  audit_export_csv::Bool           = false

@onchange audit_refresh begin
    if audit_refresh
        # Re-fetch entries from audit_logger.jl or database
        audit_entries = load_audit_entries(
            filter_user   = audit_filter_user,
            filter_action = audit_filter_action,
            date_start    = audit_filter_date_start,
            date_end      = audit_filter_date_end,
            status        = audit_filter_status,
        )
        audit_refresh = false
    end
end
```

## Entry dict shape

Each entry in `audit_entries` should have the following keys (matching `AuditLogEntry` from `audit_logger.jl`):

| Key | Type | Description |
|---|---|---|
| `"timestamp"` | `String` | ISO 8601 datetime |
| `"user_id"` | `String` | User who initiated the action |
| `"event_type"` | `String` | e.g. `INGESTION_START`, `EXPORT_COMPLETE` |
| `"resource_id"` | `String` | File, cohort, or dataset ID |
| `"record_count"` | `Int` | Number of records affected |
| `"status"` | `String` | `SUCCESS`, `PARTIAL_SUCCESS`, or `FAILED` |
| `"ip_address"` | `String` | Requester IP |

## Supported action types

`INGESTION_START`, `INGESTION_COMPLETE`, `RECORD_VALIDATED`,
`RECORD_DEIDENTIFIED`, `VALIDATION_ERROR`, `EXPORT_INITIATED`,
`EXPORT_COMPLETE`, `QUALITY_REPORT`

## Linked domain functions

- `src/data_ingestion/audit_logger.jl` — `log_ingestion_event`, `AuditLogEntry`
- HIPAA §164.312(b) — Audit Controls
