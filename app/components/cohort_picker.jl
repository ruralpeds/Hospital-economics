"""
CohortPicker — `app/components/cohort_picker.jl`

Interactive inclusion/exclusion cohort builder panel that mirrors the API
of `src/patient_cohort/cohort_builder.jl`.

The component renders:
- Age range slider (min_age / max_age)
- Diagnosis code search (ICD-10 prefix)
- Procedure code search (CPT prefix)
- Payer multi-select
- Length of stay range
- Admission date range
- Cost range
- A "Save as named cohort" button

All fields bind to `@in` reactive fields on the calling model.  The
caller is responsible for declaring those fields and wiring an `@onchange`
handler to run `build_cohort` from `cohort_builder.jl`.

Required model fields (all prefixed with `cohort_` by convention):
  cohort_min_age::Int           = 0
  cohort_max_age::Int           = 120
  cohort_dx_codes::String       = ""      # comma-separated ICD-10 prefixes
  cohort_cpt_codes::String      = ""      # comma-separated CPT prefixes
  cohort_payers::Vector{String} = []
  cohort_min_los::Int           = 0
  cohort_max_los::Int           = 365
  cohort_date_start::String     = ""
  cohort_date_end::String       = ""
  cohort_min_cost::Float64      = 0.0
  cohort_max_cost::Float64      = 9_999_999.0
  cohort_name::String           = ""
  cohort_save::Bool             = false   # toggled to trigger save

Usage:
```julia
cohort_picker()
```

To customise field prefixes pass `prefix="my_"` (default is `"cohort_"`).
"""

"""
    cohort_picker(; prefix="cohort_", class="")

Render the cohort inclusion/exclusion criteria form.

All reactive fields use `prefix` as a namespace (default `"cohort_"`).
"""
function cohort_picker(; prefix::String = "cohort_", class::String = "")
    pf = Symbol ∘ (s -> prefix * s)

    payer_opts = """[
        { label: 'Medicare',   value: 'medicare' },
        { label: 'Medicaid',   value: 'medicaid' },
        { label: 'Commercial', value: 'commercial' },
        { label: 'Self-Pay',   value: 'self_pay' },
        { label: 'Other',      value: 'other' },
    ]"""

    card(class="q-mb-md " * class, [
        card_section([
            h6("Cohort Builder", class="q-mb-md"),

            # ── Demographics ────────────────────────────────────────────
            row(class="q-gutter-md q-mb-sm", [
                cell(class="col-md-6 col-xs-12", [
                    p("Age Range", class="text-caption q-mb-xs text-grey-7"),
                    row(class="q-gutter-sm", [
                        cell(class="col", [
                            numberfield(pf("min_age"),
                                label="Min Age", filled=true, dense=true,
                                min=0, max=120, step=1),
                        ]),
                        cell(class="col", [
                            numberfield(pf("max_age"),
                                label="Max Age", filled=true, dense=true,
                                min=0, max=120, step=1),
                        ]),
                    ]),
                ]),
                cell(class="col-md-6 col-xs-12", [
                    select(pf("payers"),
                        label="Payers", filled=true, dense=true,
                        multiple=true,
                        var":options"=payer_opts,
                        var"option-label"="opt => opt.label",
                        var"option-value"="opt => opt.value",
                        var"emit-value"=true,
                        var"map-options"=true),
                ]),
            ]),

            # ── Clinical Codes ──────────────────────────────────────────
            row(class="q-gutter-md q-mb-sm", [
                cell(class="col-md-6 col-xs-12", [
                    textfield(pf("dx_codes"),
                        label="Diagnosis Codes (ICD-10, comma-separated)",
                        filled=true, dense=true,
                        clearable=true,
                        hint="e.g. E11, J18.9"),
                ]),
                cell(class="col-md-6 col-xs-12", [
                    textfield(pf("cpt_codes"),
                        label="Procedure Codes (CPT, comma-separated)",
                        filled=true, dense=true,
                        clearable=true,
                        hint="e.g. 99213, 93000"),
                ]),
            ]),

            # ── LOS & Dates ─────────────────────────────────────────────
            row(class="q-gutter-md q-mb-sm", [
                cell(class="col-md-3 col-xs-6", [
                    numberfield(pf("min_los"), label="Min LOS (days)",
                        filled=true, dense=true, min=0, step=1),
                ]),
                cell(class="col-md-3 col-xs-6", [
                    numberfield(pf("max_los"), label="Max LOS (days)",
                        filled=true, dense=true, min=0, step=1),
                ]),
                cell(class="col-md-3 col-xs-6", [
                    textfield(pf("date_start"), label="Admission From",
                        filled=true, dense=true, type="date"),
                ]),
                cell(class="col-md-3 col-xs-6", [
                    textfield(pf("date_end"), label="Admission To",
                        filled=true, dense=true, type="date"),
                ]),
            ]),

            # ── Cost range ──────────────────────────────────────────────
            row(class="q-gutter-md q-mb-md", [
                cell(class="col-md-6 col-xs-12", [
                    numberfield(pf("min_cost"), label="Min Total Charges (\$)",
                        filled=true, dense=true, min=0, step=1000,
                        prefix="\$"),
                ]),
                cell(class="col-md-6 col-xs-12", [
                    numberfield(pf("max_cost"), label="Max Total Charges (\$)",
                        filled=true, dense=true, min=0, step=1000,
                        prefix="\$"),
                ]),
            ]),

            separator(class="q-mb-md"),

            # ── Save cohort ─────────────────────────────────────────────
            row(class="items-center q-gutter-sm", [
                cell(class="col", [
                    textfield(pf("name"), label="Save as named cohort…",
                        filled=true, dense=true, clearable=true),
                ]),
                cell(class="col-auto", [
                    btn("Save Cohort", icon="save", color="primary",
                        dense=true, @click(pf("save"))),
                ]),
            ]),
        ]),
    ])
end
