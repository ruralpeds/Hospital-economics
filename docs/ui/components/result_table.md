# ResultTable

**Component file:** `app/components/result_table.jl`  
**Demo route:** `/dev/components#sec-resulttable` (dev environment only)

## Overview

`ResultTable` renders a sortable, filterable Quasar `q-table` bound to a reactive model field that holds `Vector{Dict{String,Any}}` rows. It provides optional CSV/XLSX export buttons, a quick-filter search box, per-row sparkline support, and configurable column formatting.

## Usage

```julia
result_table(
    rows_field;
    columns          = [],
    title            = "",
    export_csv_field  = nothing,
    export_xlsx_field = nothing,
    filter_field      = nothing,
    rows_per_page    = 10,
    sparkline_field  = nothing,
    class            = "",
)
```

### Arguments

| Argument | Type | Description |
|---|---|---|
| `rows_field` | `Symbol` | `@out Vector{Dict{String,Any}}` reactive field |
| `columns` | `Vector` of `NamedTuple` | Column definitions (see below) |
| `title` | `String` | Optional card title |
| `export_csv_field` | `Symbol` or `nothing` | Bool `@in` field toggled by CSV button |
| `export_xlsx_field` | `Symbol` or `nothing` | Bool `@in` field toggled by XLSX button |
| `filter_field` | `Symbol` or `nothing` | String `@in` field for quick-search |
| `rows_per_page` | `Int` | Default rows per page (default: 10) |
| `sparkline_field` | `Symbol` or `nothing` | Per-row sparkline data column |
| `class` | `String` | Extra CSS classes |

### Column descriptor keys

| Key | Required | Description |
|---|---|---|
| `name` | ✅ | Internal column id |
| `label` | ✅ | Header label |
| `field` | ✅ | Key in the row dict |
| `sortable` | | `true`/`false` (default `false`) |
| `align` | | `"left"` / `"right"` / `"center"` |
| `format` | | `"currency"`, `"percent"`, `"number"`, or omit |

## Example

```julia
result_table(:projection_rows,
    columns=[
        (name="year",    label="Year",       field="year",    sortable=true),
        (name="revenue", label="Revenue",    field="revenue", sortable=true,
         align="right",  format="currency"),
        (name="margin",  label="Margin %",   field="margin",  sortable=true,
         align="right"),
    ],
    title="5-Year Projection",
    export_csv_field=:do_export_csv,
    export_xlsx_field=:do_export_xlsx,
    filter_field=:table_filter,
    rows_per_page=10)
```

## Model fields required

```julia
@out projection_rows::Vector{Dict{String,Any}} = []
@in  table_filter::String   = ""
@in  do_export_csv::Bool    = false
@in  do_export_xlsx::Bool   = false
```

The `@onchange do_export_csv` handler should call `DataController.handle_csv_export` or similar and reset the field to `false`.
