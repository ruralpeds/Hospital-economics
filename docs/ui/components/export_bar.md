# ExportBar

**Component file:** `app/components/export_bar.jl`  
**Demo route:** `/dev/components#sec-exportbar` (dev environment only)

## Overview

`ExportBar` renders a compact horizontal toolbar of export/copy action buttons. Each button maps to a Bool `@in` reactive field on the model. Clicking a button sets the field to `true`; the model's `@onchange` handler performs the export and resets the field to `false`.

## Usage

```julia
export_bar(;
    csv_field     = nothing,
    xlsx_field    = nothing,
    json_field    = nothing,
    pdf_field     = nothing,
    png_field     = nothing,
    methods_field = nothing,
    label         = "",
    class         = "",
)
```

### Arguments

| Argument | Type | Description |
|---|---|---|
| `csv_field` | `Symbol` or `nothing` | Bool field for CSV export trigger |
| `xlsx_field` | `Symbol` or `nothing` | Bool field for XLSX multi-sheet export |
| `json_field` | `Symbol` or `nothing` | Bool field for JSON export |
| `pdf_field` | `Symbol` or `nothing` | Bool field for PDF generation |
| `png_field` | `Symbol` or `nothing` | Bool field for PNG chart capture |
| `methods_field` | `Symbol` or `nothing` | Bool field for "Copy methods paragraph" |
| `label` | `String` | Optional caption to the left of buttons |
| `class` | `String` | Extra CSS classes for the row |

Passing `nothing` for any field omits that button entirely.

## Example

```julia
# In the model:
@in do_export_csv::Bool  = false
@in do_export_xlsx::Bool = false
@in do_copy_methods::Bool = false

@onchange do_export_csv begin
    if do_export_csv
        DataController.handle_csv_export(result_data)
        do_export_csv = false
    end
end

# In the view:
export_bar(
    csv_field     = :do_export_csv,
    xlsx_field    = :do_export_xlsx,
    methods_field = :do_copy_methods,
    label         = "Export results:")
```

## XLSX multi-sheet note

The XLSX export handler should call `export_to_excel` from the domain layer. The resulting workbook must be valid for Excel 2016+ and LibreOffice 7+. Test with both applications before releasing.
