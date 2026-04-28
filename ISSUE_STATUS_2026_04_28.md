# Hospital-Economics — Issue Status Report

**Generated:** 2026-04-28  
**Inspected by:** Claude Sonnet 4.6  
**Method:** Full git clone + code inspection of all 35 branches (API blocked; git-based only)

---

## Branch Status — All Clear ✅

All 34 remote branches are **fully merged into `main`** — zero unique commits outstanding in any branch. All `copilot/*` and `claude/*` branches are stale but fully absorbed into `main`. Branch cleanup (deletion) is needed cosmetically but no work is lost.

---

## Closed Issues / PRs — Confirmed by Commit History

| # | Description | Status |
|---|---|---|
| #1, #2, #4 | Early V3.0 simulator builds (phases 1–10) | ✅ CLOSED |
| #17 | Phase 3.2 — Publication-ready visualization (`PolicyAnalysisReporting.jl`, 77 tests) | ✅ CLOSED |
| #18 | Phase 3.3 — Real-world policy validation: KY Medicaid, MD All-Payer, Rural Closures, COVID-19 (82 tests, MAPE <10%) | ✅ CLOSED |
| #19 | Phase 3.4 — v1.0 release readiness (803+ total tests) | ✅ CLOSED |
| #36–#58 | E4–E26 Web UI tabs (23 Stipple reactive views) | ✅ CLOSED (PR #78) |
| #64 | Repo hygiene GitHub Actions workflow | ✅ CLOSED |
| #65 | FinanceEngine package ported | ✅ CLOSED |
| #66 | Phase 1 build plan (T-001–T-020) | ✅ CLOSED |
| #67 | Removed 42 macOS Finder duplicate files + CI enforcement | ✅ CLOSED |
| #69 | Initial plan | ✅ CLOSED |
| #70 | Merged all 26 outstanding branches into `main` | ✅ CLOSED |
| #71 | Phase 0 reusable component library (upload, form_grid, result_table, plot_panel, export_bar, cohort_picker, scenario_picker, audit_log_viewer) | ✅ CLOSED (landed via #80) |
| #72 | CMS API connectors, X12/FHIR parsers, quality extensions | ✅ CLOSED |
| #73 | Capital budgeting + budgeting engine ported from `healthcare-finance-julia` — adds `three_statement.jl`, `dupont.jl`, `distress_scoring.jl`, `vbc_bayesian.jl`, `accounting.jl`, `actuarial.jl`, `budgeting.jl`, `forecasting.jl`, `ma_risk.jl` | ✅ CLOSED |
| #75, #77 | Removed unregistered `ReadStatTables` dep (CI failure) | ✅ CLOSED |
| #78 | E4–E26 Web UI closure + Phase 3 closure | ✅ CLOSED |
| #79 | `ruralpeds` repository allowlist | ✅ CLOSED |
| #80 | Merge conflict resolution: Phase 0 component library → `main` | ✅ CLOSED (most recent) |
| E27 | PHI redaction regex ordering bug (PHONE before bare-9-digit SSN) | ✅ FIXED — confirmed in `main` (`bug_report_redaction.jl` lines 31–35) |

---

## Open Issues — Phase 3 Tier 2 Tasks (T-021–T-030)

Tracked in `HAIKU_BUILD_TRACKING_PHASE3.md`. All **⏳ PENDING**. No implementation in any branch.

| Task | Description | Category | Hours | Impact |
|---|---|---|---|---|
| **T-021** | Monte Carlo performance — streaming collection, result caching, optional early stopping; target: 50k iterations <30s | Performance | 3h | High |
| **T-022** | Hospital projection parallelization — `bulk_project_hospitals()`, thread-safe result aggregation; target: 8x speedup on 8-hospital network (8 threads) | Performance | 2.5h | High |
| **T-023** | Ratio calculation caching — optional cache on `compute_all_ratios()`, auto-invalidation, statistics API; target: 10x faster on repeated calls | Performance | 1.5h | Medium |
| **T-024** | Extract common validation patterns — validation utility module, 40%+ duplication reduction | Code Quality | 2.5h | Medium |
| **T-025** | Hospital type registry — `AbstractHospitalType` hierarchy, `hospital_types()` registry, `create_hospital()` factory | Architecture | 2h | Medium |
| **T-026** | VBC model variants for specialized ACOs — beyond 4 basic MSSP/Pioneer/Next-Gen/REACH models | Features | 3h | High |
| **T-027** | ICER sensitivity analysis framework — parameter variation across ICER calculations, tornado-style output | Analytics | 2.5h | Medium |
| **T-028** | Patient cohort analysis enhancement — advanced grouping, filtering, subgroup analysis | Analytics | 2.5h | Medium |
| **T-029** | REH-specific analytics module — consolidate scattered REH-specific analyses | Specialized | 3h | Low |
| **T-030** | Reporting & export framework — centralized report generation, standardized output | Specialized | 3.5h | High |

**Dependency chain:** T-021 → T-023; T-024 → T-025, T-026.

---

## Open Issues — MBA Gap Analysis Domains

From `MBA_GAP_ANALYSIS_2026.md` (authored 2026-04-27). PR #73 (merged 2026-04-28) closed A-01, A-02, A-03, and D-03 (partial). The following remain genuinely absent from the codebase after code inspection.

### Domain A — Corporate Finance & Valuation

| ID | Priority | Gap | Target Module | Status |
|---|---|---|---|---|
| A-04 | **P0** | `nonprofit_wacc`, `mads_headroom`, `synthetic_rating` — nonprofit WACC + covenant calculator | `packages/FinanceEngine/src/capital_structure.jl` | ❌ Functions absent (0 grep matches) |
| A-05 | P1 | `irr()`, `mirr()`, `profitability_index()`, `equivalent_annual_cost()` | `packages/FinanceEngine/src/financial.jl` | ❌ Absent |
| A-06 | **P0** | Real-options valuation on service lines (BSM continuous, binomial lattice, LSM early-exercise) | `src/finance/real_options.jl` (new file) | ❌ File does not exist |
| A-07 | P1 | M&A / affiliation valuation engine — DCF + synergy + integration cost + accretion/dilution | `src/finance/ma_valuation.jl` (new file) | ❌ File does not exist |
| A-08 | P2 | LBO / restructuring model — REIT-leaseback and distressed-hospital takeout | `src/finance/lbo_model.jl` (new file) | ❌ File does not exist |
| A-09 | **P0** | Treasury & liquidity stress test — 13-week cash-flow, Medicare-delay shock | `src/finance/treasury.jl` (new file) | ❌ File does not exist |
| A-10 | P1 | Working-capital optimization — AR/AP cycle, CCC model | `src/finance/working_capital.jl` (new file) | ❌ File does not exist |

### Domain B — Strategic & Decision Analytics

| ID | Priority | Gap | Target Module | Status |
|---|---|---|---|---|
| B-01 | P1 | Balanced Scorecard / Strategy Map engine — 4-perspective scorecard + mermaid map | `src/strategy/balanced_scorecard.jl` (new file) | ❌ Missing |
| B-03 | **P0** | Service-line portfolio optimization — Markowitz efficient frontier, integer "open/close" | `src/optimization/service_line_portfolio.jl` (new file) | ❌ Missing |
| B-06 | P1 | Game-theoretic payer negotiation — Nash bargaining, BATNA, multi-round simulation | Extend `src/analysis/payer_negotiation.jl` | ❌ Missing |
| B-07 | P1 | HHI computation for HRR/HSA competitive analytics | Extend `src/analysis/network_economics.jl` | ❌ Missing |

### Domain C — Operational & Productivity Analytics

| ID | Priority | Gap | Target Module | Status |
|---|---|---|---|---|
| C-01 | **P0** | Data Envelopment Analysis (DEA-CCR and DEA-BCC) for peer efficiency frontier | `src/analytics/dea.jl` (new file) | ❌ File does not exist |
| C-02 | P1 | Stochastic Frontier Analysis (SFA) — translog cost function, half-normal inefficiency | `src/analytics/sfa.jl` (new file) | ❌ Missing |
| C-03 | **P0** | Variance analysis (price/volume/mix bridge) for revenue cycle | `src/finance/variance_analysis.jl` (new file) | ❌ Missing |
| C-04 | P2 | Theory-of-Constraints bottleneck — ED, OR, swing-bed; throughput $/hour | `src/analytics/toc_bottleneck.jl` (new file) | ❌ Missing |
| C-05 | P1 | Time-Driven Activity-Based Costing (TDABC) — Kaplan/Anderson method | Extend `packages/FinanceEngine/src/cost_accounting.jl` | ❌ Missing |
| C-06 | P1 | Reciprocal-method cost allocation (all three: direct, step-down, reciprocal) | Extend `packages/FinanceEngine/src/cost_accounting.jl` | ❌ Missing |
| C-07 | **P0** | Productivity benchmarking against MGMA/AHA/Flex Monitoring percentiles | `src/analytics/peer_benchmarking.jl` (new file) | ❌ Missing |

### Domain D — Risk & ML Analytics

| ID | Priority | Gap | Target Module | Status |
|---|---|---|---|---|
| D-04 | **P0** | Copula-correlated inputs for Monte Carlo (Gaussian/t-copula on arbitrary marginals) | Extend `src/simulation/montecarlo.jl` | ❌ No copula — confirmed independent draws only |
| D-05 | P1 | VaR and CVaR on operating margin, days-cash, net assets | `src/risk/var_cvar.jl` (new file) | ❌ Missing |
| D-06 | P1 | CCAR-style stress test — adverse and severely-adverse macro scenarios | `src/risk/stress_test.jl` (new file) | ❌ Missing |
| D-07 | P2 | Climate/disaster stress test extended with NOAA SVI + climate projections | Extend `src/risk/disaster_resilience.jl` | ❌ Missing |

### Domain E — Reimbursement & Policy

| ID | Priority | Gap | Target Module | Status |
|---|---|---|---|---|
| E-01 | **P0** | CAH outlier payments, TEFRA target rate variants — missing from reimbursement engine | Extend `src/finance/reimbursement.jl` | ❌ 0 grep matches for `outlier_payment`/`tefra` |
| E-03 | **P0** | Medicare Advantage v28 HCC risk model + MA rural hospital pass-through | `src/finance/medicare_advantage.jl` (new file) | ❌ File does not exist |
| E-06 | **P0** | MIPS/VBP/HRRP/HACRP scoring algorithms with current CMS threshold tables | `src/policy/mips_vbp_hrrp.jl` (new file) | ❌ File does not exist |
| E-07 | **P0** | TEAM bundled payment — audit `team_bundled.jl` vs FY2026 mandatory model final rule | Audit `src/finance/team_bundled.jl` | ⚠️ Needs verification against Jan 2026 TEAM specs |
| E-04 | P1 | RHC AIR cap phase-in per CAA 2021 — full mechanism end-to-end | Extend `src/finance/rhc_optimization.jl` | ⚠️ Partially implemented |
| E-05 | P1 | 340B contract-pharmacy dispensing model, modifier JG/TB tracking | Extend `src/finance/program340b.jl` | ⚠️ Partial |
| E-08 | P1 | State-directed payments (SDPs), GME, HRSA-funded RHC enhanced payments | Extend `src/finance/medicaid_supplemental.jl` | ❌ Missing |
| E-09 | P2 | NSA IDR economics — Qualified Payment Amount (QPA), batch-eligible claims | `src/policy/nsa_idr.jl` (new file) | ❌ Missing |

### Domain F — Reporting & Presentation

| ID | Priority | Gap | Target Module | Status |
|---|---|---|---|---|
| F-01 | **P0** | Board-ready 12-page PDF packet (Weave.jl or Typst.jl rendering chain) | `src/visualization/board_packet.jl` (new file) | ❌ Missing |
| F-03 | **P0** | CFO 1-pager — sparklines, RAG status, exception flags; <500ms load | Extend `app/views/dashboard/` | ❌ Not confirmed in current dashboard |
| F-06 | **P0** | HCRIS auto-importer CLI — `julia scripts/import_hcris.jl --ccn <CCN> --year <YEAR>` | `scripts/import_hcris.jl` (new file) | ❌ Missing |
| F-02 | P1 | Rating-agency memo (Moody's/Fitch format) — HTML + PDF via Weave/Typst | `src/visualization/rating_memo.jl` (new file) | ❌ Missing |
| F-04 | P1 | Sensitivity-tornado universal API — single `tornado(model, params)` call across all modules | `src/visualization/tornado.jl` (new file) | ❌ Missing |
| F-05 | P1 | Scenario diff/compare — side-by-side delta table from two stored scenarios | Extend `packages/FinanceEngine/src/scenario_persistence.jl` | ❌ Missing |
| F-07 | P2 | Federal Register/proposed-rule monitor — IPPS, OPPS, REH, 340B rules → margin impact | `scripts/fed_register_monitor.jl` (new file) | ❌ Missing |

---

## Open Repo Hygiene Issues

| Issue | Severity | Details |
|---|---|---|
| Julia compat split | ⚠️ Medium | Umbrella `Project.toml` = `julia = "1.11"`, `packages/FinanceEngine/Project.toml` = `julia = "1.12"`. Recommend pinning both to 1.11 (LTS). |
| No Codecov integration | ❌ P0 | `ci.yml` has no coverage reporting step. Coverage claims are self-asserted. Wire `Codecov.jl` + fail PRs that drop coverage >1pp. |
| 34 stale branches | ⚠️ Medium | All merged but cluttering the remote. Delete all `copilot/*` and `claude/*` branches via GitHub UI or cleanup script. |
| Playwright files at root | ⚠️ Low | `tsconfig.json`, `package.json`, `playwright.config.ts` should move to `e2e/` so root advertises pure-Julia app. |
| CMS rate TODOs | ⚠️ Medium | 5 TODOs in `src/utils/constants.jl` (REH monthly payment, OUTVAC, IPPS, RHC AIR cap, TEAM rate — all need CY/FY 2025-2026 updates). 1 TODO in `src/finance/vbc_transition.jl:128` (MSSP Enhanced loss cap). |
| Duplicate `/api/bugreport` route | ⚠️ Low | PR #80 may have introduced a duplicate route registration in `app/routes.jl`. Verify Genie doesn't silently overwrite the first registration. |

---

## Priority Summary

### P0 — Must close before "CFO-ready" milestone (M1)

A-04, A-06, A-09, B-03, C-01, C-03, C-07, D-04, E-01, E-03, E-06, F-01, F-03, F-06 + Codecov wiring

### P1 — Required for "Strategy-consultant-ready" milestone (M2)

A-05, A-07, A-10, B-01, B-06, B-07, C-02, C-05, C-06, D-05, D-06, E-04, E-05, E-08, F-02, F-04, F-05

### P2 — Differentiator features (M3)

A-08, B-02, B-05, C-04, D-07, E-09, F-07

### Internal tasks (T-series)

T-021 through T-030 — all PENDING, ~26h total work

---

*Generated by Claude Sonnet 4.6 via git-based code inspection of all 35 branches*  
*Repository: ruralpeds/Hospital-economics | Branch: main*
