# Phase B — Core Finance Tabs — Detailed Brief for Copilot

Phase B ships six new concept tabs that build on the Phase A component
library (#59 shared framework, #60 Upload, #61 widgets — FormGrid,
ResultTable, PlotPanel, ExportBar, CohortPicker, ScenarioPicker,
AuditLogViewer).

This document is the authoritative brief for the Copilot agents
implementing epics **E4–E9** (issues #36, #37, #38, #39, #40, #41). Each
issue body will point at its section here once this doc is merged.

## Common conventions

### Shared file scaffold per tab
```
app/views/<tab>/<Tab>Model.jl   — @app reactive block (Stipple)
app/views/<tab>/<tab>.jl        — ui_<tab>(model) view function
app/controllers/<Tab>Controller.jl  — HTTP handlers (one per domain function)
app/routes.jl                   — new route stanza + API routes
app/app.jl                      — include new model/view/controller
test/views/<tab>_test.jl        — stubbed unit tests (pattern used in PR #61)
e2e/tests/<tab>.spec.ts         — Playwright flow: input → submit → result
docs/ui/tabs/<tab>.md           — screenshot + usage + linked functions
```

### Reactive model pattern
```julia
using Stipple, StippleUI, StipplePlotly
using ...HospitalFinanceToolbox: fn_a, fn_b           # when available
using ...RuralHospitalSim: fn_c, fn_d                 # domain calls

@app begin
    @in left_drawer_open::Bool = true

    # Shared across concept tabs
    @in data_asset_id::String = ""          # from Upload commit
    @in cohort_id::String = ""              # from CohortPicker
    @in errors::Vector{String} = []
    @in running::Bool = false

    # Tab-specific inputs go here as @in fields.
    # Tab-specific outputs go here as @out fields (DataFrames, plot data,
    # plain values).

    @onchange run_button begin
        running = true
        errors  = String[]
        try
            # call controller or domain functions directly
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
    end
end
```

### Controller pattern
Each tab owns one controller module. Every domain function exposed on the
tab gets its own handler. Handlers validate payload, call the domain
function, and return `Dict("status" => "success", "result" => ...)` or
`Dict("status" => "error", "message" => ...)`. Route handlers follow the
existing `_safe_error` wrapper in `app/routes.jl`.

### Test pattern (from PR #61)
Unit tests stub `Stipple`, `StippleUI`, `Genie.Html`, and the domain
package so the view module loads without a server. A minimal test asserts
the returned node tree is non-empty for each rendered form/chart/table.

### UI scaffold per page
```julia
function ui_<tab>(model)
    content = [
        page_header(title="…", subtitle="…"),
        error_banner(:errors),
        upload(id=:upload, schema="...", on_committed="on_upload_committed",
               allow_phi=false),
        form_grid([...]; upload_model_field=:fill_from_upload),
        plot_panel(:chart_data, :chart_layout, preset=:trend),
        result_table(:result_rows; formatters=Dict("col"=>:currency)),
        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx,
                   methods_field=:do_copy_methods),
    ]
    app_layout(model, "<Tab Title>", content)
end
```

---

## E4 — Data Intake (`/data/intake`)  •  closes #36

### Goal
First consumer of the `Upload` component. Users pick a source type
(Hospital / Claims / Clinical / Financial / Registry), upload a file,
then commit the resulting `DataAsset` for use in downstream tabs.

### Dependencies
- #59 (E1) merged: `page_template`, `app_layout`, `common`.
- #60 (E2) merged: `upload(...)` component + `DataController.handle_universal_upload`.
- #61 (E3) merged: `result_table` component.

### Files
- `app/views/data_intake/DataIntakeModel.jl`
- `app/views/data_intake/data_intake.jl`
- `app/controllers/IngestionController.jl`
- `app/routes.jl` — add `route("/data/intake")` + API routes.
- `app/app.jl` — include new files.
- `test/views/test_data_intake.jl`
- `e2e/tests/data_intake.spec.ts`
- `docs/ui/tabs/data_intake.md`

### Reactive model (`DataIntakeModel.jl`)
```julia
@app begin
    @in source_type::String = "hospital"   # "hospital"|"claims"|"clinical"|"financial"|"registry"
    @in date_from::String = ""             # ISO date (for claims/registry)
    @in date_to::String   = ""
    @in payer_id::String  = ""             # claims only
    @in ehr_system::String = "epic"        # clinical only
    @in facility_id::String = ""           # financial only
    @in registry_name::String = ""         # registry only
    @in cohort_filters::String = ""        # JSON; registry only

    # Upload callback
    @in committed_asset_id::String = ""
    @in committed_phi_detected::Bool = false
    @in committed_row_count::Int = 0

    # Recent assets table
    @out recent_assets::Vector{Dict{String,Any}} = []

    # Validation panel
    @in rules_enabled::Vector{String} = ["schema", "icd10", "cpt", "encounter"]
    @out validation_result::Dict{String,Any} = Dict()
    @in run_validation::Bool = false

    @onchange run_validation begin
        run_validation || return
        try
            validation_result = IngestionController.run_validation(committed_asset_id, rules_enabled)
        catch e
            push!(errors, sprint(showerror, e))
        end
        run_validation = false
    end
end
```

### API endpoints (all `POST`)
| Route | Handler | Domain call |
|-------|---------|-------------|
| `/api/ingest/hospital`   | `IngestionController.handle_hospital`   | `ingest_hospital_data` |
| `/api/ingest/claims`     | `IngestionController.handle_claims`     | `ingest_claims_data` |
| `/api/ingest/clinical`   | `IngestionController.handle_clinical`   | `ingest_clinical_data` |
| `/api/ingest/financial`  | `IngestionController.handle_financial`  | `ingest_financial_statements` |
| `/api/ingest/registry`   | `IngestionController.handle_registry`   | `ingest_registry_data` |
| `/api/ingest/validate`   | `IngestionController.run_validation`    | `validate_data_source`, `detect_data_quality_issues` |

All delegate to a `DataAsset` produced by `handle_universal_upload` —
ingestion handlers should accept an `asset_id` and source-specific
filters, not raw file uploads (the Upload component already handled
that).

### Form spec
```julia
form_grid([
    (name=:source_type, type=:select, label="Source type",
     options=[(label="Hospital admin",  value="hospital"),
              (label="Claims",          value="claims"),
              (label="Clinical / EHR",  value="clinical"),
              (label="Financial",       value="financial"),
              (label="Registry",        value="registry")]),

    (name=:date_from, type=:date, label="From",
     visible_when="source_type==='claims' || source_type==='registry'"),
    (name=:date_to,   type=:date, label="To",
     visible_when="source_type==='claims' || source_type==='registry'"),

    (name=:payer_id, type=:select, label="Payer",
     options=[(label="Medicare", value="medicare"),
              (label="Medicaid", value="medicaid"),
              (label="Commercial", value="commercial")],
     visible_when="source_type==='claims'"),

    (name=:ehr_system, type=:select, label="EHR system",
     options=[(label="Epic", value="epic"), (label="Cerner", value="cerner"),
              (label="Other", value="other")],
     visible_when="source_type==='clinical'"),

    (name=:facility_id, type=:code_search, label="Facility",
     visible_when="source_type==='financial'"),

    (name=:registry_name, type=:select, label="Registry",
     options=[(label="STS", value="sts"),
              (label="NCDR", value="ncdr"),
              (label="ACS-NSQIP", value="nsqip")],
     visible_when="source_type==='registry'"),
],
title="1. Describe your data")
```

### Acceptance
- All 8 catalog-§1.1 functions reachable from the tab.
- Each commit posts a row to `recent_assets` without page reload.
- Rule failures in the validation panel link to row-level detail via the
  `ResultTable` drill-down slot.
- PHI columns de-identified automatically before preview.

### Unit tests
- Model loads with stubbed Stipple/Genie.
- `IngestionController.run_validation` returns an error Dict when
  `asset_id` is empty.
- Source-type visibility predicates render the correct sub-fields for
  each value.

### E2E (`e2e/tests/data_intake.spec.ts`)
Upload `test/fixtures/uploads/sample_patients.csv` through the Upload
stepper, commit, and assert the `recent_assets` row contains the new
asset id and correct `row_count`.

---

## E5 — Data Preparation (`/data/prepare`)  •  closes #37

### Goal
Chainable transformations over committed `DataAsset`s. Each step is
runnable in isolation and its output commits as a new asset — so a user
can build a pipeline (normalize → impute → aggregate) and feed it into
any downstream tab.

### Dependencies
- #59/#60/#61 merged.
- E4 merged (or at least the `DataAsset` persistence from E2).

### Files
- `app/views/data_prepare/DataPrepareModel.jl`
- `app/views/data_prepare/data_prepare.jl`
- `app/controllers/PreparationController.jl`
- `app/routes.jl`, `app/app.jl`
- `test/views/test_data_prepare.jl`
- `e2e/tests/data_prepare.spec.ts`
- `docs/ui/tabs/data_prepare.md`

### Reactive model
```julia
@app begin
    @in source_asset_id::String = ""

    # Transform selection
    @in transform::String = "normalize_ids"
    # One of:
    # "normalize_ids" | "standardize_codes" | "aggregate_encounters"
    # | "calculate_risk_adjusters" | "impute" | "create_time_series"

    # normalize_ids
    @in id_columns::Vector{String} = ["patient_id"]

    # standardize_codes
    @in code_source::String = "icd9"
    @in code_target::String = "icd10"

    # aggregate_encounters
    @in bucket::String = "episode"   # "episode"|"visit"|"daily"|"monthly"

    # risk adjusters
    @in risk_model::String = "hcc"   # "hcc"|"cms_hcc"|"charlson"|"elixhauser"

    # impute
    @in impute_strategy::String = "median"  # "mean"|"median"|"knn"|"mice"
    @in impute_columns::Vector{String} = []

    # time series
    @in ts_date_col::String = "encounter_date"
    @in ts_value_col::String = "cost"
    @in ts_interval::String = "monthly"

    # Pipeline history
    @out pipeline_steps::Vector{Dict{String,Any}} = []

    # Preview
    @out preview_rows::Vector{Dict{String,Any}} = []
    @out preview_columns::Vector{String} = []

    @in do_run::Bool = false
    @in do_commit::Bool = false
end
```

### API endpoints
One route per transform, under `/api/prepare/<name>`. Payload includes
`source_asset_id` + transform-specific fields. Returns preview (first
100 rows) and an optional `target_asset_id` when `commit=true`.

### Acceptance
- User can chain three transforms and commit the result as a new asset.
- Each transform logs an audit entry via `log_analysis_step`.
- Pipeline steps persist on reload (via Stipple session) so a refresh
  doesn't lose progress.

---

## E6 — Cohort Builder (`/cohorts`)  •  closes #38

### Goal
Create, save, and reuse patient cohorts. Power the `CohortPicker`
(from E3) on every other tab.

### Dependencies
- #59/#60/#61 merged.

### Files
- `app/views/cohorts/CohortsModel.jl`
- `app/views/cohorts/cohorts.jl`
- `app/controllers/CohortsController.jl`
- `app/routes.jl`, `app/app.jl`
- `test/views/test_cohorts.jl`
- `e2e/tests/cohorts.spec.ts`
- `docs/ui/tabs/cohorts.md`

### Reactive model
```julia
@app begin
    @in asset_id::String = ""

    # Inclusion criteria (each is a small struct dict)
    @in inclusion_age::Dict{String,Any} = Dict("min"=>0, "max"=>120)
    @in inclusion_dx::Vector{String} = []    # ICD-10 codes
    @in inclusion_px::Vector{String} = []    # CPT codes
    @in inclusion_payers::Vector{String} = []
    @in inclusion_los::Dict{String,Any} = Dict("min"=>0, "max"=>365)
    @in inclusion_dates::Dict{String,Any} = Dict("from"=>"", "to"=>"")
    @in inclusion_cost::Dict{String,Any} = Dict("min"=>0.0, "max"=>1e9)

    # Exclusion criteria (same shape)
    @in exclusion_age::Dict{String,Any} = Dict("min"=>0, "max"=>120)
    @in exclusion_dx::Vector{String} = []
    @in exclusion_px::Vector{String} = []

    # Live count
    @out matching_count::Int = 0
    @out preview_rows::Vector{Dict{String,Any}} = []

    # Saved cohorts
    @out saved_cohorts::Vector{Dict{String,Any}} = []
    @in cohort_name::String = ""
    @in cohort_description::String = ""
    @in save_cohort::Bool = false
    @in load_cohort_id::String = ""
    @in delete_cohort_id::String = ""

    # Statistics panel
    @out cohort_stats::Dict{String,Any} = Dict()
end
```

### API endpoints
- `POST /api/cohorts/preview` — returns `{count, preview_rows, stats}`.
- `POST /api/cohorts/save`    — body `{name, description, definition}`.
- `GET  /api/cohorts`          — list.
- `GET  /api/cohorts/:id`      — fetch one.
- `DELETE /api/cohorts/:id`.

### Acceptance
- Creating a cohort with 3 inclusion + 2 exclusion criteria returns an
  accurate count in < 2 s on a 100k-row asset.
- Saved cohort immediately available in `CohortPicker` elsewhere (same
  session).

---

## E7 — Cost Analysis (`/cost-analysis`)  •  closes #39

### Goal
Surface every §2.1 cost analysis function end-to-end.

### Dependencies
- #59/#60/#61 merged.
- #38 (E6) merged — `CohortPicker`.
- Optional: #36 (E4) merged — for direct asset pick.

### Files
- `app/views/cost_analysis/CostAnalysisModel.jl`
- `app/views/cost_analysis/cost_analysis.jl`
- `app/controllers/CostAnalysisController.jl`
- + standard routes / tests / docs files.

### Functions exposed
| Catalog function | Endpoint |
|---|---|
| `calculate_total_cost_of_care` | `/api/cost-analysis/total` |
| `break_down_costs_by_category` | `/api/cost-analysis/breakdown` |
| `calculate_cost_per_episode`   | `/api/cost-analysis/per-episode` |
| `calculate_cost_per_quality_adjusted_year` | `/api/cost-analysis/cpq` |
| `identify_high_cost_patients` / `analyze_high_cost_patients` | `/api/cost-analysis/high-cost` |
| `project_cost_trends`          | `/api/cost-analysis/project` |
| `inflate_cost` / `inflate_cohort_costs` | `/api/cost-analysis/inflate` |
| `calculate_cohort_total_cost` / `calculate_cohort_cost_summary` | `/api/cost-analysis/cohort-summary` |

### Reactive model
```julia
@app begin
    @in cohort_id::String = ""
    @in date_from::String = ""
    @in date_to::String   = ""
    @in cost_year::Int    = Dates.year(Dates.today())
    @in discount_rate::Float64 = 0.03
    @in high_cost_pct::Float64 = 0.05
    @in categories::Vector{String} = ["inpatient","outpatient","pharmacy","imaging","lab","dme"]

    # KPI outputs
    @out total_cost::Float64 = 0.0
    @out total_cost_ci_low::Float64 = 0.0
    @out total_cost_ci_high::Float64 = 0.0
    @out cost_per_qaly::Float64 = 0.0
    @out n_high_cost_patients::Int = 0

    # Table + chart outputs
    @out breakdown_rows::Vector{Dict{String,Any}} = []
    @out high_cost_rows::Vector{Dict{String,Any}} = []
    @out trend_data::Vector{PlotData} = []
    @out trend_layout::PlotLayout = PlotLayout()
    @out breakdown_data::Vector{PlotData} = []
    @out breakdown_layout::PlotLayout = PlotLayout()

    @in run::Bool = false
    @onchange run begin
        run || return
        running = true
        # call controller methods in sequence, update @outs
        running = false
        run = false
    end
end
```

### UI structure (`cost_analysis.jl`)
Five sections, each its own `q-card`:

1. Summary KPIs (total cost + CI, CPQ, n high-cost).
2. **Breakdown** — `plot_panel(:breakdown_data, :breakdown_layout, preset=:bar_breakdown)` + `result_table(:breakdown_rows, formatters=Dict("amount"=>:currency, "pct"=>:percent))`.
3. **Trend** — `plot_panel(:trend_data, :trend_layout, preset=:trend)` with CI ribbon.
4. **High-cost patients** — `result_table(:high_cost_rows, formatters=Dict("ytd_cost"=>:currency))`.
5. **Export** — `export_bar(...)`.

### Acceptance
- Running `identify_high_cost_patients` on a 10k-patient cohort finishes
  in < 3 s.
- Trend projection renders with 95 % CI ribbon.
- All 9 functions reachable from the tab and linked in
  `docs/ui/tabs/cost_analysis.md`.

---

## E8 — Revenue & Reimbursement (`/revenue`)  •  closes #40

### Goal
Consolidate §2.2 revenue functions; link out to existing
`/cost-reimbursement`, `/revenue-cycle`, `/payer-margin` tabs (do not
remove them — add cross-links).

### Dependencies
- #59/#60/#61 merged.

### Files
`app/views/revenue/{RevenueModel.jl,revenue.jl}` +
`app/controllers/RevenueController.jl` + standard scaffold.

### Functions exposed
| Function | Endpoint |
|---|---|
| `calculate_total_revenue`          | `/api/revenue/total` |
| `calculate_denied_claims_impact`   | `/api/revenue/denied` |
| `analyze_payor_mix`                | `/api/revenue/payor-mix` |
| `calculate_provider_payment`       | `/api/revenue/provider-payment` |
| `simulate_reimbursement_change`    | `/api/revenue/simulate` |

### Reactive model
```julia
@app begin
    @in claims_asset_id::String = ""
    @in fee_schedule_asset_id::String = ""
    @in scenario::String = "current"    # "current"|"policy_X"|"custom"
    @in policy_knob_1::Float64 = 0.0
    @in policy_knob_2::Float64 = 0.0

    # KPIs
    @out total_revenue::Float64 = 0.0
    @out denied_total::Float64 = 0.0
    @out denial_rate::Float64 = 0.0

    # Tables
    @out payor_mix_rows::Vector{Dict{String,Any}} = []
    @out denial_categories::Vector{Dict{String,Any}} = []

    # Charts
    @out payor_mix_data::Vector{PlotData} = []
    @out payor_mix_layout::PlotLayout = PlotLayout()
    @out waterfall_data::Vector{PlotData} = []
    @out waterfall_layout::PlotLayout = PlotLayout()

    @in run_sim::Bool = false
end
```

### UX
- Top: claims asset + fee schedule pickers.
- Left: payer-mix donut (`plot_panel(:payor_mix_data, :payor_mix_layout, preset=:pie)`).
- Right: denial categories bar chart.
- Bottom: "What-if" panel with sliders → waterfall chart showing
  per-payer revenue delta.

### Acceptance
- Payer-mix donut reconciles to 100 % ± 0.01.
- Simulated reimbursement change shows per-payer deltas with correct sign.

---

## E9 — Profitability & Operations (`/profitability`)  •  closes #41

### Goal
Home for §2.3 profitability + operations calculations. Cross-link to
existing `/cost-structure`, `/break-even`, `/payer-margin`, `/benchmark`.

### Dependencies
- #59/#60/#61 merged.

### Files
Standard scaffold. Controller: `ProfitabilityController.jl`.

### Functions exposed
| Function | Endpoint |
|---|---|
| `calculate_contribution_margin`        | `/api/profitability/contrib-margin` |
| `calculate_departmental_profitability` | `/api/profitability/by-dept` |
| `analyze_fixed_vs_variable_costs`      | `/api/profitability/fixed-variable` |
| `calculate_break_even_volume`          | `/api/profitability/break-even` |
| `calculate_operating_margin`           | `/api/profitability/operating-margin` |
| `margin_decomposition` (finance/)      | `/api/profitability/margin-decomp` |
| ratios, depreciation, debt_capacity    | `/api/profitability/ratios` etc. |

### Reactive model
```julia
@app begin
    @in period_from::String = ""
    @in period_to::String   = ""
    @in financial_asset_id::String = ""

    @in revenue::Float64 = 0.0
    @in variable_costs::Float64 = 0.0
    @in fixed_costs::Float64 = 0.0
    @in operating_income::Float64 = 0.0

    @out contribution_margin::Float64 = 0.0
    @out break_even_volume::Float64 = 0.0
    @out operating_margin::Float64 = 0.0

    @out departmental_rows::Vector{Dict{String,Any}} = []
    @out waterfall_data::Vector{PlotData} = []
    @out waterfall_layout::PlotLayout = PlotLayout()

    @in volume_slider::Float64 = 1.0
end
```

### UX
- Top: period + asset pickers, or direct numeric entry.
- Waterfall: Revenue → Variable → Contribution Margin → Fixed →
  Operating Income.
- Break-even calculator with `volume_slider` recomputing
  `break_even_volume` client-side via a Vue `@onchange` handler in
  under 250 ms.
- Departmental drill-down table (sortable).
- Peer benchmark overlay toggle (links `/benchmark`).

### Acceptance
- Waterfall sum reconciles to `operating_income` ± $1.
- Volume slider recomputes in < 250 ms.
- Departmental table supports sort by any numeric column.

---

## Shared acceptance criteria (all six epics)

- Every epic passes `julia --project -e 'using Pkg; Pkg.test()'` locally
  and in CI.
- Every epic has a Playwright spec that exercises the happy path.
- Every epic's tab loads with no console errors and is included in the
  nav drawer under the right concept header.
- Every epic's docs file has one screenshot and a "linked functions"
  section listing each catalog function with its endpoint.
- No new Julia deps added without justification in the PR description.

## Copilot assignment order

We must wait for Phase A to merge before assigning. Once Phase A lands:

1. Start **E4 (#36)** and **E6 (#38)** first — they produce the
   `DataAsset` and `Cohort` primitives every downstream tab consumes.
2. After E4/E6 merge, start **E5 (#37)** and **E7 (#39)** in parallel.
3. After those merge, finish with **E8 (#40)** and **E9 (#41)**.

Six issues become three waves of parallel agents. Keeps branch
divergence low and avoids repeated layout / routes merge conflicts.
