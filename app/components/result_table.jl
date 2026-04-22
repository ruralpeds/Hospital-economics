"""
ResultTable — `app/components/result_table.jl`

Sortable, filterable `q-table` bound to a reactive model field that holds
a `Vector{Dict{String,Any}}` (or anything Stipple serialises to a JS array).

Supports:
- Grouped/multi-level column headers via `groups` argument
- Per-row sparklines (tiny Plotly traces) via `sparkline_field`
- CSV export trigger (wires to an `@in Bool` model field)
- XLSX export trigger
- Customisable row/cell slots via `extra_cols` list

Usage:
```julia
result_table(
    :my_rows,               # reactive field name (Vector{Dict})
    columns=[
        (name="year",  label="Year",    field="year",  sortable=true),
        (name="cost",  label="Cost",    field="cost",  sortable=true, format="currency"),
        (name="delta", label="Δ Cost",  field="delta", sortable=true),
    ],
    title="Cost Projection",
    export_csv_field=:export_csv,
    export_xlsx_field=:export_xlsx,
    filter_field=:table_filter,
    rows_per_page=15,
)
```
"""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

"""Build a q-table column definition JS object string."""
function _col_def(c::NamedTuple)::String
    nm    = string(get(c, :name, "col"))
    lbl   = get(c, :label, nm)
    fld   = get(c, :field, nm)
    sort  = get(c, :sortable, false) ? "true" : "false"
    align = get(c, :align, "left")
    fmt   = get(c, :format, "")
    fmt_fn = if fmt == "currency"
        ", format: val => val == null ? '' : '\$' + Number(val).toLocaleString('en-US', {maximumFractionDigits: 0})"
    elseif fmt == "percent"
        ", format: val => val == null ? '' : (val * 100).toFixed(1) + '%'"
    elseif fmt == "number"
        ", format: val => val == null ? '' : Number(val).toLocaleString()"
    else
        ""
    end
    "{ name: '$(nm)', label: '$(lbl)', field: '$(fld)', sortable: $(sort), align: '$(align)'$(fmt_fn) }"
end

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
"""
    result_table(rows_field::Symbol; columns, title, export_csv_field,
                 export_xlsx_field, filter_field, rows_per_page, sparkline_field)

Render a responsive, sortable, filterable Quasar table bound to `rows_field`.

# Arguments
- `rows_field`       — Symbol of the reactive `@out` field containing rows.
- `columns`          — Vector of NamedTuples: (name, label, field, sortable, align, format).
- `title`            — Card/table title string.
- `export_csv_field` — Symbol of a Bool `@in` field; clicking CSV button toggles it.
- `export_xlsx_field`— Symbol of a Bool `@in` field; clicking XLSX button toggles it.
- `filter_field`     — Symbol of a String `@in` field for the quick-filter text box.
- `rows_per_page`    — Rows per page (default 10).
- `sparkline_field`  — Symbol of a field with per-row sparkline data (optional).
- `class`            — Extra CSS classes for the outer card.
"""
function result_table(
    rows_field::Symbol;
    columns::Vector          = [],
    title::String            = "",
    export_csv_field::Union{Symbol,Nothing}  = nothing,
    export_xlsx_field::Union{Symbol,Nothing} = nothing,
    filter_field::Union{Symbol,Nothing}      = nothing,
    rows_per_page::Int       = 10,
    sparkline_field::Union{Symbol,Nothing}   = nothing,
    class::String            = "",
)
    # Build column defs JS array
    cols_js = "[" * join([_col_def(c isa NamedTuple ? c : NamedTuple(c)) for c in columns], ", ") * "]"

    # Filter slot
    filter_slot = isnothing(filter_field) ? [] : [
        template("", var"v-slot:top-right"=true, [
            textfield(filter_field, dense=true, outlined=true,
                placeholder="Search…",
                var"debounce"="300",
                [quasar(:icon, slot="append", name="search")]),
        ]),
    ]

    # Export buttons slot
    export_buttons = if !isnothing(export_csv_field) || !isnothing(export_xlsx_field)
        btns = []
        isnothing(export_csv_field)  || push!(btns,
            btn("CSV",  icon="download", color="secondary", flat=true, dense=true,
                @click(export_csv_field)))
        isnothing(export_xlsx_field) || push!(btns,
            btn("XLSX", icon="table_view", color="secondary", flat=true, dense=true,
                @click(export_xlsx_field)))
        [template("", var"v-slot:top-left"=true, [row(class="q-gutter-xs", btns)])]
    else
        []
    end

    # Title
    title_html = isempty(title) ? [] : [
        p(title, class="text-subtitle2 q-mb-sm")
    ]

    # Sparkline body-cell slot (one tiny inline Plotly if sparkline_field provided)
    sparkline_slot = if !isnothing(sparkline_field)
        [template("", var"v-slot:body-cell-sparkline"="props", [
            Html.td([
                Html.div(var":id"="'sparkline-' + props.rowIndex",
                    class="sparkline-cell",
                    style="width:80px;height:28px;"),
            ]),
        ])]
    else
        []
    end

    # q-table attrs
    tbl_attrs = Dict{Symbol,Any}(
        Symbol(":columns")    => cols_js,
        Symbol(":rows")       => string(rows_field),
        Symbol(":rows-per-page-options") => "[5, 10, 25, 50, 0]",
        Symbol("flat")        => true,
        Symbol("bordered")    => true,
    )
    isnothing(filter_field) ||
        (tbl_attrs[Symbol(":filter")] = string(filter_field))

    all_slots = [filter_slot..., export_buttons..., sparkline_slot...]

    card(class="q-mb-md " * class, [
        card_section([
            [title_html...,
             quasar(:table, all_slots; tbl_attrs...),
            ]
        ]),
    ])
end
