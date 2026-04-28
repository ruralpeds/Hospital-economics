"""
ExportBar — `app/components/export_bar.jl`

Horizontal toolbar of export/copy action buttons.

Each button corresponds to a Bool `@in` reactive field on the model.
When the user clicks a button the field is toggled to `true`; the model's
`@onchange` handler performs the actual export and resets the field.

Buttons rendered (all optional — pass `nothing` to omit):
  CSV            — download flat CSV
  XLSX           — download multi-sheet workbook
  JSON           — download JSON payload
  PDF            — generate PDF report via `export_to_pdf`
  PNG            — capture current chart as PNG
  Copy methods   — copy auto-generated methods paragraph to clipboard

Usage:
```julia
export_bar(
    csv_field   = :do_export_csv,
    xlsx_field  = :do_export_xlsx,
    json_field  = :do_export_json,
    pdf_field   = :do_export_pdf,
    png_field   = :do_export_png,
    methods_field = :do_copy_methods,
    label       = "Export results",
)
```
"""

"""
    export_bar(; csv_field, xlsx_field, json_field, pdf_field, png_field,
               methods_field, label, class)

Render a row of export action buttons.

Pass `nothing` for any button you do not need.  The optional `label`
appears as a small caption to the left of the buttons.
"""
function export_bar(;
    csv_field::Union{Symbol,Nothing}     = nothing,
    xlsx_field::Union{Symbol,Nothing}    = nothing,
    json_field::Union{Symbol,Nothing}    = nothing,
    pdf_field::Union{Symbol,Nothing}     = nothing,
    png_field::Union{Symbol,Nothing}     = nothing,
    methods_field::Union{Symbol,Nothing} = nothing,
    label::String                        = "",
    class::String                        = "",
)
    buttons = []

    isnothing(csv_field) || push!(buttons,
        btn("CSV", icon="table_rows", outline=true, color="primary",
            dense=true, no_caps=true,
            @click(csv_field)))

    isnothing(xlsx_field) || push!(buttons,
        btn("XLSX", icon="grid_on", outline=true, color="primary",
            dense=true, no_caps=true,
            @click(xlsx_field)))

    isnothing(json_field) || push!(buttons,
        btn("JSON", icon="data_object", outline=true, color="secondary",
            dense=true, no_caps=true,
            @click(json_field)))

    isnothing(pdf_field) || push!(buttons,
        btn("PDF", icon="picture_as_pdf", outline=true, color="negative",
            dense=true, no_caps=true,
            @click(pdf_field)))

    isnothing(png_field) || push!(buttons,
        btn("PNG", icon="image", outline=true, color="secondary",
            dense=true, no_caps=true,
            @click(png_field)))

    isnothing(methods_field) || push!(buttons,
        btn("Copy methods", icon="content_copy", flat=true, color="grey-7",
            dense=true, no_caps=true,
            @click(methods_field)))

    label_el = isempty(label) ? [] :
        [span(label, class="text-caption text-grey-7 q-mr-sm")]

    row(class="q-gutter-xs items-center " * class,
        [label_el..., buttons...])
end
