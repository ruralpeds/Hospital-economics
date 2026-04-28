"""
FormGrid — `app/components/form_grid.jl`

Auto-generated, typed input form from a `Vector{NamedTuple}` field spec.
Each field descriptor supports:
  - name        ::Symbol   — reactive model field name (used as Stipple binding key)
  - type        ::Symbol   — one of: :numeric, :currency, :percent, :integer, :date,
                             :daterange, :select, :multiselect, :toggle, :code_search,
                             :cohort_picker, :file, :dynamic_table
  - label       ::String   — display label (defaults to titlecased name)
  - default     ::Any      — default value (informational; model owns the value)
  - min         ::Number   — minimum value (numeric/percent/integer/currency)
  - max         ::Number   — maximum value
  - step        ::Number   — step (numeric/percent/integer/currency)
  - help        ::String   — tooltip text shown via q-icon hint
  - options     ::Vector   — [{label, value}] for select/multiselect
  - visible_when::String   — Vue expression; wraps field in v-if
  - columns     ::Vector   — column names for :dynamic_table type
  - col_class   ::String   — Quasar column class (default "col-md-4 col-sm-6 col-xs-12")

Usage (inside a ui_* view function):
```julia
form_grid([
    (name=:discount_rate, type=:percent, label="Discount Rate",
     default=0.03, min=0.0, max=0.15, help="Annual discount rate."),
    (name=:time_horizon,  type=:integer, label="Time Horizon (years)",
     default=10, min=1, max=50),
], upload_model_field=:fill_from_upload)
```

The optional `upload_model_field` wires the "Fill from upload" button to a
Bool reactive field that the model `@onchange` handler can act upon.
"""

# ---------------------------------------------------------------------------
# Helper: build a tooltip icon when help text is provided
# ---------------------------------------------------------------------------
# Robust JS string-literal escape: handles backslash, quotes, newlines, and
# the </script> sequence that would otherwise break out of a script context.
function _js_str(s::String)::String
    s = replace(s, "\\" => "\\\\")
    s = replace(s, "'"  => "\\'")
    s = replace(s, "\n" => "\\n")
    s = replace(s, "\r" => "\\r")
    s = replace(s, "</" => "<\\/")
    return "'" * s * "'"
end

function _field_hint(help::String)
    isempty(help) && return []
    [quasar(:icon, name="help_outline", class="q-ml-xs text-grey-6",
        var"v-tooltip.top"=_js_str(help))]
end

# ---------------------------------------------------------------------------
# Helper: optional v-if wrapper
# ---------------------------------------------------------------------------
function _maybe_vif(node, visible_when::String)
    isempty(visible_when) && return node
    # Wrap in a template with v-if so entire cell is hidden/shown
    template(var"v-if"=visible_when, [node])
end

# ---------------------------------------------------------------------------
# Render a single field based on its type
# ---------------------------------------------------------------------------
function _render_field(f::NamedTuple)
    nm       = get(f, :name, :field)
    ftype    = get(f, :type, :numeric)
    lbl      = get(f, :label, titlecase(replace(string(nm), "_" => " ")))
    help     = get(f, :help, "")
    mn       = get(f, :min, nothing)
    mx       = get(f, :max, nothing)
    stp      = get(f, :step, nothing)
    opts     = get(f, :options, [])
    vis      = get(f, :visible_when, "")
    col_cls  = get(f, :col_class, "col-md-4 col-sm-6 col-xs-12")
    dyn_cols = get(f, :columns, [:value])

    # Build the Quasar input widget
    widget = if ftype == :toggle
        toggle(nm, label=lbl)
    elseif ftype == :select
        # q-select with options vector bound from model or inline
        if isempty(opts)
            select(nm, label=lbl, filled=true, dense=true,
                var":options"=string(nm) * "_options")
        else
            opts_js = "[" * join(["{ label: '$(o[:label])', value: '$(o[:value])' }" for o in opts], ", ") * "]"
            select(nm, label=lbl, filled=true, dense=true,
                var":options"=opts_js)
        end
    elseif ftype == :multiselect
        if isempty(opts)
            select(nm, label=lbl, filled=true, dense=true, multiple=true,
                var":options"=string(nm) * "_options")
        else
            opts_js = "[" * join(["{ label: '$(o[:label])', value: '$(o[:value])' }" for o in opts], ", ") * "]"
            select(nm, label=lbl, filled=true, dense=true, multiple=true,
                var":options"=opts_js)
        end
    elseif ftype == :date
        textfield(nm, label=lbl, filled=true, dense=true, type="date")
    elseif ftype == :daterange
        row(class="q-gutter-xs", [
            cell(class="col", [
                textfield(Symbol(string(nm) * "_start"), label=lbl * " From",
                    filled=true, dense=true, type="date"),
            ]),
            cell(class="col", [
                textfield(Symbol(string(nm) * "_end"), label=lbl * " To",
                    filled=true, dense=true, type="date"),
            ]),
        ])
    elseif ftype == :file
        quasar(:file, nm, label=lbl, filled=true, dense=true,
            accept=".csv,.xlsx,.json")
    elseif ftype == :code_search
        textfield(nm, label=lbl * " (ICD/CPT/HCPCS)", filled=true, dense=true,
            var":hint"="'Enter code prefix to search'",
            clearable=true)
    elseif ftype == :cohort_picker
        # Lightweight inline: full CohortPicker component is separate
        select(nm, label=lbl, filled=true, dense=true,
            var":options"="cohort_options",
            var"option-label"="opt => opt.label",
            var"option-value"="opt => opt.value",
            var"emit-value"=true, var"map-options"=true)
    elseif ftype == :dynamic_table
        # Mini editable table — columns driven by field descriptor
        card(flat=true, bordered=true, class="q-pa-xs", [
            card_section([
                p(lbl, class="text-caption q-mb-xs text-grey-7"),
                quasar(:markup_table, dense=true, flat=true, class="q-mb-xs", [
                    Html.thead([
                        Html.tr([Html.th(titlecase(replace(string(c), "_" => " "))) for c in dyn_cols])
                    ]),
                    Html.tbody([
                        Html.tr(var"v-for"="(row, idx) in $(nm)", var":key"="idx", [
                            Html.td(var"v-for"="col in [$(join([_js_str(string(c)) for c in dyn_cols], ","))]",
                                var":key"="col", [
                                quasar(:input, var"v-model"="$(nm)[idx][col]",
                                    dense=true, borderless=true),
                            ])
                        ])
                    ]),
                ]),
                btn("+ Row", dense=true, flat=true, color="primary",
                    icon="add",
                    var"@click"="$(nm).push({" * join(["$(c): ''" for c in dyn_cols], ", ") * "})"),
            ]),
        ])
    else
        # numeric / currency / percent / integer — all use numberfield
        attrs = Dict{Symbol,Any}(:label => lbl, :filled => true, :dense => true)
        isnothing(mn)  || (attrs[:min]  = mn)
        isnothing(mx)  || (attrs[:max]  = mx)
        isnothing(stp) || (attrs[:step] = stp)
        if ftype == :currency
            attrs[Symbol("prefix")] = "\$"
        elseif ftype == :percent
            attrs[Symbol("suffix")] = "%"
            isnothing(stp) && (attrs[:step] = 0.1)
        elseif ftype == :integer
            attrs[:step] = 1
        end
        numberfield(nm; attrs...)
    end

    hint_els = _field_hint(help)
    inner = isempty(hint_els) ? widget :
        row(class="items-center", [
            cell(class="col", [widget]),
            cell(class="col-auto", hint_els),
        ])

    cell(class=col_cls, [_maybe_vif(inner, vis)])
end

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
"""
    form_grid(fields::Vector; upload_model_field::Union{Symbol,Nothing}=nothing,
              title::String="", class::String="")

Render a responsive Quasar grid of typed inputs from a field spec vector.

# Arguments
- `fields` — Vector of NamedTuples describing each input field.
- `upload_model_field` — Optional Symbol for a Bool `@in` field on the model.
  When provided, a "Fill from upload" button is rendered that toggles the field.
- `title` — Optional card header title.
- `class` — Extra CSS classes for the outer card.
"""
function form_grid(
    fields::Vector;
    upload_model_field::Union{Symbol,Nothing} = nothing,
    title::String = "",
    class::String = "",
)
    # Header row (title + optional upload button inline)
    header_row = isempty(title) ? [] : [
        row(class="items-center q-mb-sm", [
            cell(class="col", [h6(title, class="q-mb-none")]),
            isnothing(upload_model_field) ? [] : cell(class="col-auto", [
                btn("Fill from upload", icon="cloud_upload", flat=true,
                    color="secondary", dense=true,
                    @click(upload_model_field)),
            ]),
        ]),
    ]

    # When there is no title, render the upload button below the fields instead
    upload_btn_below = (isnothing(upload_model_field) || !isempty(title)) ? [] : [
        row(class="q-mt-sm", [
            cell(class="col-12", [
                btn("Fill from upload", icon="cloud_upload", color="secondary",
                    outline=true, dense=true, @click(upload_model_field)),
            ]),
        ]),
    ]

    rows_html = row(class="q-gutter-md", [_render_field(f) for f in fields])

    card(class="q-mb-md " * class, [
        card_section([header_row..., rows_html, upload_btn_below...]),
    ])
end
