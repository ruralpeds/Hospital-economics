# MISSING FEATURES — Gap Analysis Report

**Repository:** `ruralpeds/Hospital-economics`
**Default branch:** `main` (HEAD commit `2a3b5a93`)
**Generated:** 2026-05-15
**Author:** Claude (remote-only audit via GitHub MCP)

---

## Executive Summary

**Estimated completion: ~92–95% of all planned scope; ~98% of "production-ready" v1.0 + v1.1 scope.**

The repo is substantially further along than its own `ISSUE_STATUS_2026_04_28.md` snapshot
suggests. Between that snapshot and HEAD, virtually every "❌ Missing" MBA-domain gap
(A-04 through F-07) has been closed via 30+ new `packages/FinanceEngine/src/*.jl`
modules, accompanied by matching `test/test_mba_domain_*.jl` test suites. `CHANGELOG.md`
v1.0.0 and v1.1.0 (both dated 2026-04-28) confirm closure of all P1 and P2 MBA gaps.
Phase 3 Tier-2 tasks T-021 through T-030 are all marked complete in
`HAIKU_BUILD_TRACKING_PHASE3.md` and their deliverables verified in source.

**Top remaining gaps (small list — most are pure-doc / aspirational future phases):**

1. **Phase 3 README success criteria (AI/ML)** — README claims Phase 3 will deliver
   95%+ prediction accuracy AI/ML, real-time anomaly detection (20% billing-error
   reduction), and EHR sync. No evidence of these in code; only basic
   `closure_ml.jl` + `readmission_risk.jl` (LACE + logistic regression).
2. **MVP-checklist HIPAA/infra items in README** — security audit, MFA + RBAC
   enforcement, AES-256-GCM at rest, audit-log SIEM wiring, EKS/Terraform IaC. The
   *standards* docs exist (`SECURITY_ARCHITECTURE.md`, `JULIA_HIPAA_STANDARDS.md`,
   `DEPLOYMENT_RUNBOOK.md`) but I find no Terraform, no Kubernetes manifests
   (`docker/` exists but no `k8s/` or `terraform/`), and only file-level audit
   logging (`src/data_ingestion/audit_logger.jl`) rather than a SIEM pipeline.
3. **Dashboard adoption / CMS 5500 submission / benchmarking $100K opportunities**
   — README v1.1 criteria; these are organizational/UAT milestones, not code
   deliverables.
4. **Codecov drop-fail policy** — wired (per BUILD_TRACKING) but the floor /
   "fail PRs on coverage drop >1pp" enforcement claimed by ISSUE_STATUS is not
   independently verified here.
5. **Minor unverified items** — e.g. the Phase 3 README plan listed real-time
   dashboard / streaming projections as deferred; `StreamingIngestion.jl` is a
   single 10 KB file and may be a thin stub rather than a full streaming engine.

---

## Methodology

**Planning docs reviewed (all on `main`):**

- `PROJECT_CHARTER.md` (28 KB, business/ROI scope)
- `REQUIREMENTS_DOCUMENT.md` (35 KB)
- `IMPLEMENTATION_GUIDE.md` (32 KB)
- `COPILOT_BUILD_PROMPT_2026_04_28.md` (32 KB)
- `HAIKU_BUILD_PLAN_PHASE3.md` (11 modules T-021..T-030)
- `HAIKU_BUILD_TRACKING_PHASE3.md` (read in full — all 10 marked ✅)
- `FUNCTIONS_CATALOG.md` (100+ planned function catalog)
- `BUILD_LOG.md` (V3.0 + V3.1 baseline of 38 + 15 modules)
- `CHANGELOG.md` (v1.0.0 and v1.1.0 — definitive closure record)
- `ISSUE_STATUS_2026_04_28.md` (the existing per-issue gap matrix)
- `RELEASE_NOTES.md` / `DATA_DICTIONARY.md` (skim)
- `.gap-analysis/build-ledger.jsonl` (empty — schema header only)
- `.gap-analysis/schema.md` (org-wide gap-analysis conventions)
- `README.md` (success criteria checklist)

**Code paths inspected (directory listings + spot-checks):**

- `src/` — 20 sub-modules listed; file sizes verified non-trivial (most 5–25 KB)
- `src/finance/` (15 files), `src/analysis/` (8 files), `src/risk/` (4 files),
  `src/simulation/` (6 files), `src/optimization/` (6 files), `src/utils/` (7
  files), `src/visualization/` (5 files), `src/policy/` (2 files),
  `src/health_economics/`, `src/patient_cohort/`, `src/data_ingestion/` (10
  files), `src/comparative_effectiveness/` (5 files), `src/network/`,
  `src/analytics/`, `src/streaming/`, `src/release/`, `src/clinical_integration/`,
  `src/validation/`, `src/episode/`, `src/payer_models/`, `src/patient_flow/`,
  `src/models/`, `src/data/`
- `packages/FinanceEngine/src/` — **74 `.jl` files** (full list extracted via
  GitHub search-code listing). Confirms presence of every MBA-domain module the
  prior gap report flagged missing.
- `packages/RuralCore/` — present
- `app/` — `app.jl`, `routes.jl` (69 KB), `views/`, `controllers/`, `db/`
- `test/` — 60+ test files including `test_mba_domain_{a,bd,c,e,f}.jl`,
  `test_mba_p1_*.jl`, `test_mba_p2_all_gaps.jl`, `test_tier2_t021_t030.jl`
- `e2e/` — Playwright TS suite (config + helpers + tests + fixtures)
- `scripts/` — `import_hcris.jl` (18 KB), `benchmark.jl`, `seed_data.jl`

**Cross-reference method:** For each module the planning docs called out as
missing or partial, I ran a `mcp__github__search_code` query for the function or
filename and verified existence (or absence) in the actual code tree.

---

## Built (Planned + Present)

### Core simulation & finance (V3.0 baseline — BUILD_LOG)

All 38 V3.0 modules listed in `BUILD_LOG.md` are present and sized as full
implementations (not stubs):

- Models: `src/models/{abstract,department,staffing,payer,financial,capital,hospital,scenarios,results}.jl`
- Finance: `src/finance/{costreport,reimbursement,ratios,depreciation,breakeven,cashflow,program340b,sensitivity}.jl`
- Simulation: `src/simulation/{deterministic,montecarlo,abm,systemdynamics,des,scenarios}.jl`
- Optimization: `src/optimization/{staffing,portfolio,capital_scoring}.jl`
- Risk: `src/risk/{closure,conversion,closure_ml,disaster_resilience}.jl`
- Analysis: `src/analysis/{comparison,community,payer_negotiation,sdoh,geographic_access,community_benefit,network_economics,reh_analytics}.jl`

### V3.1 add-ons (BUILD_LOG)

- `src/finance/{team_bundled,telehealth,vbc_transition,medicaid_supplemental,debt_capacity,margin_decomposition,rhc_optimization}.jl` — all present (~5–22 KB each).

### Phase 3 Tier-2 tasks (T-021 → T-030)

Verified against `HAIKU_BUILD_PLAN_PHASE3.md`:

| Task | Evidence |
|------|----------|
| T-021 MC perf / caching / convergence | `src/simulation/montecarlo.jl` (26 KB; contains `MCResultCache`, `ConvergenceCriteria`) |
| T-022 Hospital parallelization | `src/simulation/montecarlo.jl` (`bulk_project_hospitals`) |
| T-023 Ratio caching | `src/finance/ratios.jl` (14 KB; `RatioCache`) |
| T-024 Validation extraction | `src/utils/validation_utils.jl` (11 KB) |
| T-025 Hospital type registry | `src/utils/hospital_type_registry.jl` (15 KB) |
| T-026 VBC variants | `src/finance/vbc_transition.jl` (22 KB; `ExtendedVBCParams`) |
| T-027 ICER sensitivity | `src/health_economics/ICER.jl` (16 KB) |
| T-028 Cohort analysis | `src/patient_cohort/cohort_builder.jl` (20 KB) |
| T-029 REH analytics | `src/analysis/reh_analytics.jl` (17 KB) |
| T-030 Reporting framework | `src/visualization/reporting_framework.jl` (19 KB) |
| Test coverage | `test/test_tier2_t021_t030.jl` present |

### MBA gap closure — Domains A–F (per CHANGELOG v1.0.0 + v1.1.0)

All flagged "❌ Missing" items from `ISSUE_STATUS_2026_04_28.md` now have
matching files under `packages/FinanceEngine/src/`:

| Gap | Planned module | Evidence |
|---|---|---|
| A-04 nonprofit_wacc / MADS / synthetic rating | `nonprofit_wacc.jl` | Present |
| A-05/A-06 real options + IRR/MIRR/EAC | `real_options.jl`, `financial.jl` | Present |
| A-07 M&A valuation | `ma_valuation.jl` | Present |
| A-08 LBO / restructuring | `lbo_analysis.jl` | Present |
| A-09 Treasury 13-week | `treasury.jl` | Present |
| A-10 Working capital / CCC | `working_capital.jl` | Present |
| B-01 Balanced scorecard | `balanced_scorecard.jl` | Present |
| B-02 Blue Ocean | `blue_ocean.jl` | Present (v1.1.0) |
| B-03 Service-line portfolio | `service_line_portfolio.jl` | Present |
| B-04 REH real options | `reh_real_options.jl` | Present (v1.1.0) |
| B-05 Scenario / Porter / PESTLE | `scenario_planning.jl` | Present (v1.1.0) |
| B-06 Nash bargaining | `payer_negotiation_game.jl` | Present |
| B-07 HHI / market concentration | `competitive_analytics.jl` | Present |
| C-01 DEA-CCR/BCC | `dea.jl` | Present |
| C-02 SFA translog | `sfa.jl` | Present |
| C-03 Variance bridge | `variance_analysis.jl` | Present |
| C-04 Theory of constraints | `theory_of_constraints.jl` | Present (v1.1.0) |
| C-05 TDABC | `tdabc.jl` | Present |
| C-06 Reciprocal cost allocation | `reciprocal_cost_allocation.jl` | Present |
| C-07 Peer benchmarking | `peer_benchmarking.jl` | Present |
| D-01 Cox PH closure | `cox_ph_closure.jl` | Present |
| D-02 Readmission risk / LACE | `readmission_risk.jl` | Present (v1.1.0) |
| D-03 VBC Bayesian MSSP | `vbc_bayesian_mssp.jl` | Present |
| D-04 Copula MC | `copula_mc.jl` | Present |
| D-05/D-06 VaR / CVaR / CCAR | `var_cvar_stress.jl` | Present |
| D-07 Climate / TCFD | `climate_risk.jl` | Present (v1.1.0) |
| E-01 CAH outlier / TEFRA | `cah_outlier_payments.jl` | Present |
| E-03 Medicare Advantage HCC v28 | `medicare_advantage.jl` | Present |
| E-04 RHC AIR cap CAA 2021 | `rhc_air_cap.jl` | Present |
| E-05 340B contract pharmacy | `b340_contract_pharmacy.jl` | Present |
| E-06 MIPS/VBP/HRRP/HACRP | `mips_vbp_hrrp.jl` | Present |
| E-07 TEAM FY2026 | `team_bundled_payment.jl` | Present |
| E-08 Medicaid SDP / DSH | `medicaid_sdp.jl`, `medicaid_dsh.jl` | Present |
| E-09 NSA IDR | `nsa_idr.jl` | Present (v1.1.0) |
| F-01 Board packet | `src/visualization/board_packet.jl` (29 KB) | Present |
| F-02 Rating-agency memo | `rating_agency_memo.jl` | Present |
| F-04 Universal tornado API | `sensitivity_tornado.jl` | Present |
| F-05 Scenario diff | `scenario_diff.jl` | Present |
| F-06 HCRIS CLI | `scripts/import_hcris.jl` (18 KB) | Present |
| F-07 Federal Register monitor | `fed_register_parser.jl` | Present (v1.1.0) |

### Other built scope

- 27 Genie/Stipple Web UI views under `app/views/` (per BUILD_LOG, plus 9 new
  P2 views per CHANGELOG v1.1.0)
- 7 DB migrations (per BUILD_LOG)
- Data ingestion stack: `src/data_ingestion/` — 10 files including CMS API
  connectors, X12/FHIR `claims_formats.jl`, `deidentifiers.jl`, audit logger,
  HCRIS importer, ingestion API, validators
- Comparative effectiveness: `src/comparative_effectiveness/` — 5 files (ICER,
  QALY, threshold, sensitivity, comparative effectiveness)
- Policy: `src/policy/{MultiLevelPolicyCoupling,StateLevelPolicySimulation}.jl`
  (25 / 28 KB)
- E2E Playwright suite under `e2e/`
- 60+ test files in `test/`

---

## Partial (Planned, Partially Present)

### F-03 CFO 1-pager dashboard
- **Planned:** Sub-500 ms CFO 1-pager with sparklines + RAG + exception flags;
  `/cfo` route.
- **Evidence:** CHANGELOG v1.0.0 claims it shipped, but no `cfo_dashboard.jl`
  surfaced in my searches under `packages/FinanceEngine/src/`. May be implemented
  inside one of the `app/views/dashboard/` files (not exhaustively inspected) or
  inside `app/routes.jl` (69 KB — too large to read fully here).
- **Status:** Likely built per CHANGELOG; flagging because I could not directly
  confirm a single dedicated file. **Recommend manual verification.**

### Phase 4 Streaming
- **Planned (HAIKU_BUILD_PLAN_PHASE3 "Deferred to Phase 4"):** Real-time
  streaming projections.
- **Evidence:** `src/streaming/StreamingIngestion.jl` (10 KB) — single file,
  size suggests a slim implementation rather than a full streaming engine.
  `test/test_phase_4c_streaming.jl` exists.
- **Gap:** Likely a Phase-4 MVP but not the full "real-time dashboard" promised.

### Clinical-economic coupling
- **Evidence:** `src/clinical_integration/ClinicalEconomicCoupling.jl` (212 B)
  and `PhysiologicalModel.jl` (224 B) — **these are stubs** (file sizes well
  under 1 KB).
- **Gap:** Module shells exist; real implementation missing. Not flagged as
  high-priority in any planning doc.

### Codecov / coverage enforcement
- **Planned:** Codecov wiring + fail-PR on >1pp coverage drop.
- **Evidence:** `.codecov.yml` exists; CHANGELOG v1.0.0 says floor was set to
  60%. Not verified whether PR-blocking behavior is actually in `ci.yml`
  (workflow contents not inspected here).
- **Gap:** Configuration likely present but enforcement policy unverified.

---

## Missing (Planned, No Evidence in Code)

### README Phase-3 success criteria (AI/ML)
- **Planned (README "Phase 3" + "Success Criteria"):**
  - AI/ML models with **95%+ prediction accuracy**
  - Real-time anomaly detection → **20% billing-error reduction**
  - EHR integration with automated data sync
- **Evidence:** Only `src/risk/closure_ml.jl` (9 KB) and
  `packages/FinanceEngine/src/readmission_risk.jl` (logistic regression + LACE).
  No model-accuracy validation suite, no anomaly-detection module, no EHR
  connector beyond CMS-API ingestion.
- **Severity:** Roadmap (Phase 3 was a stretch goal post-v1.1).

### MVP HIPAA / infra checklist (README "Success Criteria — MVP")
- **Planned items not directly evidenced in code:**
  - **Terraform IaC** for EKS / RDS / ALB (`DEPLOYMENT_RUNBOOK.md` references
    it; no `terraform/` directory in repo root)
  - **Kubernetes manifests** (no `k8s/`, `manifests/`, or helm chart in root —
    `docker/` exists but k8s is not surfaced)
  - **SIEM / immutable audit-log shipping** — only file-level
    `audit_logger.jl` found
  - **MFA + RBAC enforcement** at app layer — not verified in
    `app/controllers/` (not inspected)
  - **AES-256-GCM column-level encryption** in PostgreSQL — DDL not inspected
- **Severity:** P0 if the project is approaching production go-live; lower if
  the deployment surface is operator-managed outside this repo.

### v1.1 organizational success criteria
- README v1.1 checklist contains items that are not code deliverables:
  - Dashboard adoption >80% by target users
  - CMS 5500 submission ready
  - Benchmarking identifies $100K+ optimization opportunities
- **Status:** Out of scope for a code audit; flagged for completeness.

### Phase 4 items deferred per HAIKU_BUILD_PLAN_PHASE3
The plan itself defers these — they are *expected absences*, not gaps:
- Machine-learning patient risk prediction (partially present — see above)
- Real-time dashboard
- Audit logging / compliance tracking (partial — `audit_logger.jl` present)
- API server (Genie already provides routes)
- Cloud deployment / containerization (Dockerfile present in `docker/`; full
  cloud IaC missing)

---

## Notes / Caveats

1. **The repo's own ISSUE_STATUS_2026_04_28.md is stale.** It was authored on
   2026-04-28 and listed ~30 gaps as ❌ Missing. The same-day CHANGELOG v1.0.0
   and v1.1.0 entries indicate all those gaps were merged that day or shortly
   after. The HEAD code tree confirms presence. The doc was not updated to
   reflect closures.
2. **I did not deeply read every module's source.** File-size heuristics and
   spot-checks of headers (e.g., `montecarlo.jl` 26 KB, ratio_cache types
   visible via search) are used as evidence of substance. A handful of files
   (≤ 1 KB: `ResourceAllocation.jl`, `Dashboards.jl`, `NMB.jl`,
   `Uncertainty.jl`, `CostEffectiveness.jl`, `ClinicalEconomicCoupling.jl`,
   `PhysiologicalModel.jl`, `utils/types.jl`) are stubs or re-exports.
3. **`app/routes.jl` is 69 KB** — too large for a single fetch in this audit.
   The CFO-dashboard route, /api/bugreport (recently de-duplicated), and the 9
   v1.1.0 P2 view routes are presumed to live here.
4. **`rust-sci-core` was named in scope** but I found no evidence
   `Hospital-economics` depends on it; `Project.toml` is pure Julia. No
   cross-repo dependency audit performed.
5. **Cited file paths are HEAD (`main`, commit `2a3b5a93`).**
6. **`.gap-analysis/build-ledger.jsonl` is empty** (schema header only) — the
   automated workflow has not appended events.

---

*Generated by Claude (Opus 4.7, 1M-context) via GitHub MCP — remote-only,
no git clone.*
