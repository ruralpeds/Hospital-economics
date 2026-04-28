# Hospital Economics Web UI — Comprehensive Build Plan

> **Audience:** GitHub Copilot agents (and human reviewers) building out the
> interactive web front-end for `HospitalFinanceToolbox.jl` /
> `RuralHospitalSim.jl` using pure Julia with **Genie.jl + Stipple.jl +
> StippleUI (Quasar) + StipplePlotly**.
>
> **Goal:** Expose **every public function** in `FUNCTIONS_CATALOG.md` through
> a polished, reusable, HIPAA-aware web UI, organized into tabs that mirror
> the major concepts of hospital finance and health economics, with a shared
> component library for file intake (CSV, XLS/XLSX, JSON, Parquet, HCRIS) and
> data entry.

---

## 1. Architecture Overview

```
┌────────────────────────────────────────────────────────────────────┐
│                     Browser (Quasar + Plotly)                       │
│ ┌────────────┐ ┌──────────────┐ ┌───────────────┐ ┌──────────────┐ │
│ │ Top bar +  │ │ Left drawer  │ │ Tab container │ │ Upload drawer│ │
│ │ global KPIs│ │ (concept nav)│ │ (per concept) │ │ (reusable)   │ │
│ └────────────┘ └──────────────┘ └───────────────┘ └──────────────┘ │
└─────────────────────────────▲──────────────────────────────────────┘
                              │ WebSocket (Stipple reactive state)
                              │ REST (Genie controllers)
┌─────────────────────────────▼──────────────────────────────────────┐
│                   Genie.jl application (app/)                       │
│ views/<concept>/<Model>.jl   views/<concept>/<ui>.jl   routes.jl    │
│ controllers/ (Simulation, Optimization, Risk, Data, Function)       │
│ components/ (Upload, FormGrid, ResultTable, PlotPanel, ExportBar)   │
└─────────────────────────────▲──────────────────────────────────────┘
                              │ Julia calls (no IPC)
┌─────────────────────────────▼──────────────────────────────────────┐
│ Domain: HospitalFinanceToolbox.jl / RuralHospitalSim.jl / src/**    │
│ finance/ health_economics/ analytics/ data_ingestion/ episode/ ...  │
└─────────────────────────────────────────────────────────────────────┘
```

**Key principles**

1. **Pure Julia** — no Node/React build step. Quasar is delivered via Stipple.
2. **One tab per major concept** in hospital finance/economics. Each tab is a
   `@app` reactive model + a `ui_*` view function, wired into a `route`.
3. **Reusable components** live in `app/components/` and are used across
   tabs (`Upload`, `FormGrid`, `ResultTable`, `PlotPanel`, `ExportBar`,
   `CohortPicker`, `ScenarioPicker`, `AuditLogViewer`).
4. **Every function** in `FUNCTIONS_CATALOG.md` is exposed through:
   - a form on the appropriate concept tab, **and**
   - a JSON endpoint in `app/controllers/FunctionController.jl`, **and**
   - an entry in the universal **Function Explorer** tab.
5. **HIPAA-aware** — uploads route through `data_ingestion/deidentifiers.jl`,
   audit logged via `data_ingestion/audit_logger.jl`. No PHI ever leaves the
   browser unless the user explicitly disables de-id in a governance step.
6. **Accessible** — WCAG 2.1 AA. Every input has a `<label>` and `aria-*`
   attribute. Color is never the only signal.

---

## 2. Tab Inventory (one tab per major concept)

Tabs group the ~120 functions from `FUNCTIONS_CATALOG.md`. Existing
`app/views/*` scaffolds are reused where they already exist (marked "E" for
extend); gaps are net-new (marked "N").

| # | Concept Tab                        | Route                 | Status | Catalog §      |
|---|------------------------------------|-----------------------|--------|----------------|
| 1 | Data Intake                        | `/data/intake`        | N      | 1.1            |
| 2 | Data Preparation                   | `/data/prepare`       | N      | 1.2            |
| 3 | Cohort Builder                     | `/cohorts`            | N      | 8.1            |
| 4 | Cost Analysis                      | `/cost-analysis`      | N      | 2.1            |
| 5 | Revenue & Reimbursement            | `/revenue`            | E (`/cost-reimbursement`, `/revenue-cycle`) | 2.2 |
| 6 | Profitability & Operations         | `/profitability`      | E (`/cost-structure`, `/break-even`, `/payer-margin`) | 2.3 |
| 7 | Quality & Clinical Outcomes        | `/quality`            | N      | 3              |
| 8 | Descriptive & Inferential Stats    | `/stats`              | N      | 4.1, 4.2       |
| 9 | Regression Lab                     | `/regression`         | N      | 4.3            |
|10 | Causal Inference Lab               | `/causal`             | N      | 4.4            |
|11 | Cost-Effectiveness (CEA)           | `/cea`                | N      | 5.1            |
|12 | Cost-Benefit (CBA) + Budget Impact | `/cba`                | N      | 5.2, 5.3       |
|13 | Comparative Effectiveness          | `/comparative`        | N      | 6              |
|14 | Visualization Workbench            | `/visualize`          | E (`/results`) | 7.1      |
|15 | Reports & Export                   | `/reports`            | N      | 7.2            |
|16 | Database & Queries                 | `/database`           | N      | 8              |
|17 | Advanced Analytics / ML            | `/ml`                 | N      | 10.1           |
|18 | Network & Systems                  | `/systems`            | E (`/network-economics`) | 10.2 |
|19 | Scenario & Sensitivity Lab         | `/scenario-lab`       | E (`/sensitivity`, `/scenarios`) | 10.3 |
|20 | Hospital Profile                   | `/profile`            | ✅ (keep) | —           |
|21 | Simulation Runner                  | `/simulate`           | ✅ (keep) | —           |
|22 | Function Explorer                  | `/functions`          | N      | ALL            |
|23 | Audit & Governance                 | `/audit`              | N      | 9.2            |
|24 | Education Center                   | `/education`          | ✅ (keep) | —           |

Existing hospital-strategy tabs (`/340b`, `/telehealth`, `/vbc-transition`,
`/medicaid-supplemental`, `/rhc-optimization`, `/sdoh`,
`/geographic-access`, `/community-benefit`, `/disaster-resilience`,
`/capital-scoring`, `/closure-risk`, `/payer-negotiation`,
`/strategic-plan`, `/staffing`, `/workforce`, `/benchmark`, `/conversion`,
`/policy`, `/team-bundled`, `/debt-capacity`, `/cash-flow`, `/service-lines`,
`/financial-sim`, `/community-impact`) stay where they are and get the new
reusable upload/form widgets retrofitted in (Epic 23).

---

## 3. Reusable Component Library (`app/components/`)

Each component is a Julia function that takes keyword arguments and returns a
`Genie.Renderer.Html`-compatible node tree. Components bind to the calling
model via `@in`/`@out` fields passed by name (as `Symbol`s) so they stay
reactive.

### 3.1 `Upload` — universal file intake
- **Formats:** `.csv`, `.tsv`, `.xls`, `.xlsx`, `.json`, `.jsonl`, `.parquet`,
  `.feather`, `.sav` (SPSS), `.dta` (Stata), HCRIS `.rpt`/`.csv`, SAS `.sas7bdat`.
- **Steps (stepper):**
  1. **Drop file** — `q-uploader` multiple=false, max 500 MB, mime-filtered.
  2. **Preview** — first 20 rows, inferred types, missingness %, PHI sniff.
  3. **Map columns** — drag-to-map to a target schema (patient, claim,
     financial, registry). Saved mappings become reusable templates.
  4. **Validate** — runs `validate_data_source`, `validate_icd10_code`,
     `validate_cpt_code`, `validate_patient_encounter` etc. Shows red/amber
     /green per rule with row counts.
  5. **De-identify (optional, default ON for PHI-flagged uploads)** — calls
     `deidentify_encounter` / `generate_pseudonym`. Key stored server-side.
  6. **Commit** — persists to `data/uploads/<uuid>/` and emits a
     `DataAsset` record. Returns the asset id to the calling tab.
- **Hooks:** `on_preview`, `on_mapped`, `on_validated`, `on_committed`.
- **Controller:** `POST /api/data/upload` (delegates to
  `DataController.handle_universal_upload`).

### 3.2 `FormGrid` — auto-generated input form
- Accepts a Julia `NamedTuple` describing inputs (name, type, unit, min, max,
  help, default, visible-when). Emits a Quasar grid of typed inputs with
  tooltips, validation, and a **"Fill from upload"** button that pulls values
  from a committed `DataAsset`.
- Supported input types: `numeric`, `currency`, `percent`, `integer`,
  `date`, `daterange`, `select`, `multiselect`, `toggle`, `code_search`
  (ICD/CPT/HCPCS), `cohort_picker`, `file`, `dynamic_table`.

### 3.3 `ResultTable`
- Sortable, filterable table bound to a `DataFrame`. CSV/XLSX export via
  `ExportBar`. Supports grouped headers and sparklines per row.

### 3.4 `PlotPanel`
- Wraps StipplePlotly with a shared color palette, CI ribbons, and one-click
  export to PNG/SVG. Preset layouts: `trend`, `bar_breakdown`, `pie`,
  `scatter`, `tornado`, `forest`, `km`, `heatmap`, `geo`.

### 3.5 `ExportBar`
- Buttons for CSV, XLSX (multi-sheet), JSON, PDF, PNG, and "Copy methods
  paragraph". Uses `export_to_pdf`, `export_to_excel`.

### 3.6 `CohortPicker`
- Reuses `cohort_builder.jl`. Lets users define inclusion/exclusion criteria
  (age, dx, px, payer, LOS, date range, cost) and saves named cohorts.

### 3.7 `ScenarioPicker`
- Drop-in chooser over saved scenarios (`src/models/scenarios.jl`).

### 3.8 `AuditLogViewer`
- Renders entries from `audit_logger.jl` with filtering.

### 3.9 `BugReport` — in-app bug reporter (GitHub issues)
- **Entry point:** floating `bug_report_button()` included in
  `page_template` so every tab (and every future tab) automatically gets
  a "Report a bug" affordance.
- **Form:** category (bug / feature / data-quality / UX / performance /
  security), severity (S1–S4), one-line summary, steps to reproduce,
  expected vs. actual, optional screenshot (`html2canvas`), optional
  email for follow-up.
- **Auto-captured context:** route, browser UA, viewport, app version,
  git SHA, timestamp, last 20 reactive state deltas (scrubbed),
  authenticated user id if present.
- **PHI redaction:** client-side regex pass (SSN, DOB, MRN, name
  patterns) on every text field and the screenshot canvas **before** the
  payload leaves the browser. Server re-scans and strips on receipt.
- **Spam protection, layered:**
  1. Honeypot field (invisible; populated = silent reject).
  2. Minimum dwell time (reject submits < 3s).
  3. **Cloudflare Turnstile** widget (free, privacy-friendly, no
     tracking); fallback to hCaptcha.
  4. Rate limits: 5/hour/IP, 20/day/session, persisted in SearchLight.
  5. Content heuristics: minimum length, max URLs, basic profanity +
     PII regex.
- **Server:** `POST /api/bugreport` → `BugReportController.handle_submit`
  validates → calls GitHub REST
  `POST /repos/{owner}/{repo}/issues` with an env-var token
  (`BUG_REPORT_GITHUB_TOKEN`, fine-grained PAT scoped to
  `issues: write` on this repo only). Token is **never** sent to the
  browser.
- **Issue template** (`docs/ui/bug_report_template.md`): severity/
  category labels, reproduction checklist, env block,
  `Source: in-app` label, screenshot uploaded as gist if > 8 MB.
- **Tests:** unit tests for redaction + spam filters; Playwright E2E
  asserts a mocked GitHub API receives the expected payload.

---

## 4. Tab Specification Template

Every new tab issue follows this template so Copilot has a complete spec:

```
Path:            app/views/<tab>/{<Tab>Model.jl, <tab>.jl}
Route:           /<tab>  (add to app/routes.jl)
Model:           @app reactive block with @in inputs, @out outputs, @onchange handlers
UI:              ui_<tab>(model) using StippleUI + Upload + FormGrid + PlotPanel
Domain calls:    qualified calls to src/** (e.g. RuralHospitalSim.salary_to_revenue)
Reusables:       Upload(...), FormGrid(...), ResultTable(...), ExportBar(...)
API:             POST /api/<tab>/<function> in FunctionController / existing controllers
Tests:           test/views/<tab>_test.jl (unit) + e2e/<tab>.spec.ts (Playwright)
Docs:            docs/ui/<tab>.md (screenshot, usage, linked functions)
```

A tab is **complete** when every function listed under its catalog section
has (a) an input form, (b) a result view, (c) an API endpoint, (d) a test.

---

## 5. Function-to-Tab Mapping (authoritative)

The master mapping lives in `docs/ui/function_index.md`. An abbreviated view:

- **Data Intake (§1.1):** `ingest_hospital_data`, `ingest_claims_data`,
  `ingest_clinical_data`, `ingest_financial_statements`,
  `ingest_registry_data`, `validate_data_source`,
  `detect_data_quality_issues`, `ingest_csv`.
- **Data Preparation (§1.2):** `normalize_patient_identifiers`,
  `standardize_medical_codes`, `aggregate_encounters`,
  `calculate_risk_adjusters`, `impute_missing_values`, `create_time_series`.
- **Cost Analysis (§2.1):** `calculate_total_cost_of_care`,
  `break_down_costs_by_category`, `calculate_cost_per_episode`,
  `calculate_cost_per_quality_adjusted_year`, `identify_high_cost_patients`,
  `project_cost_trends`, `inflate_cost`, `inflate_cohort_costs`,
  `calculate_cohort_total_cost`, `calculate_cohort_cost_summary`,
  `analyze_high_cost_patients`.
- **Revenue & Reimbursement (§2.2):** `calculate_total_revenue`,
  `calculate_denied_claims_impact`, `analyze_payor_mix`,
  `calculate_provider_payment`, `simulate_reimbursement_change`.
- **Profitability & Operations (§2.3):** `calculate_contribution_margin`,
  `calculate_departmental_profitability`,
  `analyze_fixed_vs_variable_costs`, `calculate_break_even_volume`,
  `calculate_operating_margin`, `margin_decomposition`, `ratios`,
  `depreciation`, `debt_capacity`.
- **Quality & Clinical Outcomes (§3):** `calculate_readmission_rate`,
  `calculate_mortality_rate`, `calculate_infection_rates`,
  `calculate_complication_rates`, `calculate_patient_safety_indicator`,
  `calculate_quality_metric`, `track_functional_status`,
  `track_symptom_resolution`, `calculate_quality_of_life_score`,
  `identify_outcome_disparities`, `compare_outcomes_by_treatment`,
  `calculate_quality_metrics`.
- **Statistics (§4.1–4.2):** `calculate_population_demographics`,
  `calculate_comorbidity_burden`, `calculate_summary_statistics`,
  `compare_groups_descriptively`, `perform_t_test`, `perform_anova`,
  `perform_chi_square_test`, `perform_log_rank_test`,
  `calculate_confidence_intervals`.
- **Regression (§4.3):** `perform_linear_regression`,
  `perform_logistic_regression`, `perform_poisson_regression`,
  `perform_negative_binomial_regression`, `perform_cox_proportional_hazards`,
  `calculate_regression_diagnostics`.
- **Causal Inference (§4.4):** `perform_propensity_score_matching`,
  `perform_instrumental_variable_analysis`,
  `perform_difference_in_differences`, `perform_regression_discontinuity`,
  `estimate_heterogeneous_treatment_effects`.
- **CEA (§5.1):** `calculate_cost_effectiveness_ratio`, `calculate_icer`,
  `perform_sensitivity_analysis`, `perform_monte_carlo_simulation`,
  `calculate_incremental_net_benefit`, `generate_cost_effectiveness_plane`,
  `build_ceac`, `calculate_ceac_at_wtp`, `recommend_intervention`,
  `classify_dominance`.
- **CBA & Budget Impact (§5.2–5.3):** `calculate_net_present_value`,
  `calculate_return_on_investment`, `calculate_benefit_cost_ratio`,
  `perform_break_even_analysis`, `estimate_population_impact`,
  `calculate_budget_impact`, `project_budget_over_time`.
- **Comparative Effectiveness (§6):** `compare_treatment_outcomes`,
  `analyze_treatment_patterns`, `identify_practice_variation`,
  `benchmark_against_peers`, `calculate_standardized_mortality_ratio`,
  `calculate_outcome_by_subgroup`, `test_treatment_interaction`,
  `identify_predictors_of_response`, `compare_strategies`,
  `build_strategy_profiles`.
- **Visualization (§7.1):** `create_cost_trend_chart`,
  `create_cost_breakdown_chart`, `create_quality_metric_dashboard`,
  `create_cost_effectiveness_plane`, `create_tornado_diagram`,
  `create_survival_curve`, `create_forest_plot`, `create_heatmap`,
  `create_geographic_map`.
- **Reports (§7.2):** `generate_financial_report`, `generate_quality_report`,
  `generate_analysis_report`, `export_to_pdf`, `export_to_excel`,
  `create_executive_summary`.
- **Database (§8):** `query_patient_records`, `query_claims`,
  `query_encounters`, `query_financial_data`, `create_cohort_from_criteria`,
  `save_analysis_result`, `save_dataset_version`, `retrieve_archived_data`,
  `backup_database`.
- **Utilities & Audit (§9):** `load_configuration`, `set_discount_rate`,
  `set_cost_year`, `set_analysis_parameters`, `log_analysis_step`,
  `handle_missing_data_error`, `validate_analysis_inputs`,
  `generate_audit_log`, `adjust_for_inflation`, `calculate_present_value`,
  `merge_datasets`, `deidentify_data`.
- **Advanced Analytics (§10.1):** `predict_patient_risk`,
  `predict_readmission_probability`, `predict_high_cost_status`,
  `predict_treatment_response`, `train_prediction_model`,
  `evaluate_model_performance`, `build_readmission_model`,
  `build_anomaly_detector`, `detect_cost_anomalies`,
  `stratify_patient_risk`.
- **Network & Systems (§10.2):** `analyze_referral_network`,
  `identify_care_coordination_gaps`, `analyze_care_team_composition`,
  `simulate_care_pathway`.
- **Scenario & Sensitivity (§10.3):** `run_best_case_scenario`,
  `run_base_case_scenario`, `run_worst_case_scenario`,
  `sensitivity_to_parameter`, `two_way_sensitivity_analysis`,
  `conduct_one_way_sensitivity`, `conduct_two_way_sensitivity`,
  `conduct_probabilistic_sensitivity`, `tornado_analysis`.

The **Function Explorer** tab (`/functions`) lists all of them in a
searchable table with "Open form" deep-links into the right concept tab.

---

## 6. Build Phases

### Phase A — Foundations (Epic 1 + 2 + 3 + 27)
1. `app/components/` skeleton + doc for each reusable component.
2. `Upload` component with full CSV/XLS/Parquet support and preview.
3. `FormGrid`, `ResultTable`, `PlotPanel`, `ExportBar` minimum viable.
4. `BugReport` component wired into `page_template`, so every current
   and future tab ships with in-app bug reporting to GitHub issues.
5. `FunctionController` scaffolding and `/api/fn/<name>` pattern.
6. CI: Playwright smoke test for upload + one form submission + one
   bug report round-trip (mocked GitHub).

### Phase B — Core finance tabs (Epics 4–8)
1. Data Intake, Data Preparation, Cohort Builder, Cost Analysis,
   Revenue & Reimbursement, Profitability & Operations.

### Phase C — Clinical + statistical tabs (Epics 9–11)
1. Quality & Outcomes, Stats, Regression, Causal Inference.

### Phase D — Economic evaluation (Epics 12–14)
1. CEA, CBA+BIA, Comparative Effectiveness.

### Phase E — Cross-cutting & systems (Epics 15–19)
1. Visualization Workbench, Reports & Export, Database, ML, Systems,
   Scenario Lab, Function Explorer, Audit.

### Phase F — Retrofit existing tabs (Epic 23)
1. Re-skin the 38 existing tabs to use the new component library
   (`Upload`, `FormGrid`, `ExportBar`).

### Phase G — QA, docs, release (Epics 24–26)
1. Accessibility sweep, Playwright E2E matrix, user docs, screenshots, v1.0
   release notes.

---

## 7. Coding Standards for Copilot Agents

1. **Don't break backward compatibility** with the existing `app/views/*`
   modules unless explicitly told; prefer additive changes.
2. Every new `@in`/`@out` field must have a **type** and a **default**.
3. Every tab's `@onchange` handler must be wrapped in `try/catch` and surface
   errors via a `@out errors::Vector{String}`.
4. Follow `JULIA_HIPAA_STANDARDS.md` — PHI is never logged, and uploads of
   PHI must be de-identified before `@out` exposes them.
5. All new code gets tests (`test/views/*_test.jl`) **and** a Playwright E2E
   (`e2e/<tab>.spec.ts`) that asserts the form renders, validates, and
   produces a result.
6. Follow the naming convention: `verb_noun` (matches `FUNCTIONS_CATALOG.md`).
7. Code style: `using Stipple, StippleUI, StipplePlotly` at top of view
   modules. Do not `using` the domain package — prefer explicit
   `using ...RuralHospitalSim: fn1, fn2` or `using ...HospitalFinanceToolbox: fn`.
8. All new routes go in `app/routes.jl` under a clearly labeled section
   banner. Keep the `_safe_error` pattern.

---

## 8. Copilot Agent Workflow

Each issue below is sized so a single Copilot session can complete it. To run
one:

1. Open the issue. It contains: **goal**, **files to create/modify**,
   **domain calls**, **reusable components**, **acceptance tests**, **DoD**.
2. Check out `claude/hospital-finance-ui-plan-Wk2lK` (or a feature branch off
   it).
3. Implement, run `julia --project -e 'using Pkg; Pkg.test()'`, then
   `npx playwright test e2e/<tab>.spec.ts`.
4. Open a PR that links the issue and passes CI.

Copilot agents should **not** begin Phase B until Phase A is merged, and
should treat the tab specification template (§4) as binding.

---

## 9. Definition of Done (global)

- [ ] Every catalog function has: form + endpoint + test + docs.
- [ ] Every tab passes accessibility linting (axe) and Playwright E2E.
- [ ] `Upload` handles CSV/XLS/XLSX/JSON/Parquet end-to-end with preview,
      mapping, validation, de-id, commit.
- [ ] Function Explorer (`/functions`) enumerates everything in the catalog.
- [ ] No PHI in logs. Audit log captures every write/ingest.
- [ ] Release notes + screenshots in `docs/ui/`.

---

## 10. Issue Index

Issues filed on GitHub (see repo Issues tab, label `web-ui`):

| Epic | Title                                    |
|------|------------------------------------------|
| E1   | Shared UI framework + layout refresh     |
| E2   | Reusable `Upload` component (CSV/XLS/Parquet/JSON/HCRIS) |
| E3   | Reusable `FormGrid`, `ResultTable`, `PlotPanel`, `ExportBar` |
| E27  | Reusable `BugReport` — in-app bug reporter → GitHub issues (Phase A) |
| E4   | Data Intake tab (`/data/intake`)         |
| E5   | Data Preparation tab (`/data/prepare`)   |
| E6   | Cohort Builder tab (`/cohorts`)          |
| E7   | Cost Analysis tab (`/cost-analysis`)     |
| E8   | Revenue & Reimbursement tab (`/revenue`) |
| E9   | Profitability & Operations tab (`/profitability`) |
| E10  | Quality & Clinical Outcomes tab (`/quality`) |
| E11  | Stats tab (`/stats`)                     |
| E12  | Regression Lab (`/regression`)           |
| E13  | Causal Inference Lab (`/causal`)         |
| E14  | Cost-Effectiveness tab (`/cea`)          |
| E15  | Cost-Benefit + Budget Impact (`/cba`)    |
| E16  | Comparative Effectiveness (`/comparative`) |
| E17  | Visualization Workbench (`/visualize`)   |
| E18  | Reports & Export (`/reports`)            |
| E19  | Database & Queries (`/database`)         |
| E20  | Advanced Analytics / ML (`/ml`)          |
| E21  | Network & Systems (`/systems`)           |
| E22  | Scenario & Sensitivity Lab (`/scenario-lab`) |
| E23  | Function Explorer (`/functions`)         |
| E24  | Audit & Governance viewer (`/audit`)     |
| E25  | Retrofit 38 existing tabs to component library |
| E26  | Playwright E2E matrix, a11y sweep, release prep |

Each issue below carries the label `web-ui` plus a phase label
(`phase-A..G`) and an epic label (`epic-<n>`).
