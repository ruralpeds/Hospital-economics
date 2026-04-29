# HAIKU Build Tracking: Phase 3 Status Matrix

**Created:** 2026-04-27  
**Updated:** 2026-04-28  
**Branch:** `claude/tier2-t021-t030-implementation`  
**Phase:** 3 (Tier 2 Optimizations & Advanced Features)

---

## Phase 3 Status Summary

| Task | Title | Status | Category | Effort (h) | Complexity | Impact |
|------|-------|--------|----------|-----------|-----------|--------|
| T-021 | Monte Carlo Performance | ✅ COMPLETE | Performance | 3 | High | High |
| T-022 | Hospital Parallelization | ✅ COMPLETE | Performance | 2.5 | High | High |
| T-023 | Ratio Caching | ✅ COMPLETE | Performance | 1.5 | Low | Medium |
| T-024 | Validation Extraction | ✅ COMPLETE | Quality | 2.5 | Medium | Medium |
| T-025 | Hospital Type Registry | ✅ COMPLETE | Architecture | 2 | Medium | Medium |
| T-026 | VBC Model Variants | ✅ COMPLETE | Features | 3 | High | High |
| T-027 | ICER Sensitivity | ✅ COMPLETE | Analytics | 2.5 | Medium | Medium |
| T-028 | Cohort Analysis | ✅ COMPLETE | Analytics | 2.5 | Medium | Medium |
| T-029 | REH Analytics | ✅ COMPLETE | Specialized | 3 | Medium | Low |
| T-030 | Reporting Framework | ✅ COMPLETE | Specialized | 3.5 | High | High |

**Overall Progress:** 10/10 tasks complete (100%)

---

## Deliverables by Task

### T-021: Monte Carlo Performance ✅
**Files modified:** `src/simulation/montecarlo.jl`  
**New types:** `MCResultCache`, `ConvergenceCriteria`  
**New functions:** `clear_mc_cache!()`, `mc_cache_stats()`, updated `run_monte_carlo/2` with `use_cache`, `convergence`, `progress_cb` kwargs  
**Acceptance criteria met:**
- [x] Streaming pre-allocation (no `push!` in hot loop)
- [x] Result caching with `MCResultCache` and LRU-style semantics
- [x] Optional convergence-based early stopping (`ConvergenceCriteria`)
- [x] Progress callback support
- [x] Reproducible regardless of thread count (per-iteration seeded RNGs)

### T-022: Hospital Projection Parallelization ✅
**Files modified:** `src/simulation/montecarlo.jl`  
**New types:** `HospitalProjectionResult`  
**New functions:** `bulk_project_hospitals()`, `aggregate_network_projection()`  
**Acceptance criteria met:**
- [x] Parallel across hospitals via `Threads.@threads`
- [x] Per-hospital seed perturbation for deterministic results
- [x] Error isolation (one failed hospital doesn't abort the network run)
- [x] Progress callback
- [x] `aggregate_network_projection()` for network-level roll-up

### T-023: Ratio Calculation Caching ✅
**Files modified:** `src/finance/ratios.jl`  
**New types:** `RatioCache`  
**New functions:** `clear_ratio_cache!()`, `ratio_cache_stats()`, updated both `compute_all_ratios` overloads with `use_cache` kwarg  
**Acceptance criteria met:**
- [x] Cache on `compute_all_ratios(financials; use_cache=true)`
- [x] Staffing-aware variant keyed on all 4 arguments
- [x] Auto-invalidation via content-hash key (no manual invalidation needed)
- [x] Hit/miss statistics
- [x] LRU-style eviction at `max_size` entries
- [x] `use_cache=false` (default) is a zero-overhead passthrough

### T-024: Validation Utilities ✅
**Files created:** `src/utils/validation_utils.jl`  
**New types:** `ValidationResult`  
**New functions:** `merge_validations`, `validate!`, `check_positive`, `check_non_negative`, `check_in_range`, `check_finite`, `check_integer_range`, `check_non_empty_string`, `check_one_of`, `check_non_empty_collection`, `check_payer_mix`, `check_financial_field`, `check_rate`, `check_fiscal_year`, `check_date_range`, `check_fields`  
**Acceptance criteria met:**
- [x] `ValidationResult` accumulates errors without throwing
- [x] `validate!` converts to `ArgumentError`
- [x] `merge_validations` composes independent checks
- [x] Domain helpers cover payer mix, financial fields, rates, fiscal years, date ranges

### T-025: Hospital Type Registry ✅
**Files created:** `src/utils/hospital_type_registry.jl`  
**New types:** `AbstractHospitalType` + 10 concrete singletons, `HospitalTypeProperties`  
**New functions:** `hospital_types()`, `hospital_type_properties()`, `hospital_type_singleton()`, `hospital_type_of()`, `create_hospital()`, `rural_hospital_types()`, `cost_based_hospital_types()`, `inpatient_hospital_types()`  
**Acceptance criteria met:**
- [x] 10 hospital types registered with full metadata
- [x] Factory `create_hospital(:cah; kwargs...)` for CAH, REH, PPS
- [x] Reverse lookup `hospital_type_of(hospital)` → Symbol
- [x] Convenience query helpers (rural, cost-based, inpatient)

### T-026: VBC Model Variants ✅
**Files modified:** `src/finance/vbc_transition.jl`  
**New types:** `VBCModelProperties`, `ExtendedVBCParams`, `ExtendedVBCResult`  
**New functions:** `vbc_model_registry()`, `vbc_model_properties()`, `calculate_extended_vbc()`, `rural_vbc_models()`  
**10 models registered:** `:mssp_basic`, `:mssp_enhanced`, `:aco_lead`, `:aco_flex`, `:aco_reach_pioneer`, `:aco_global_cap`, `:mssp_low_revenue`, `:team_bundled`, `:kidney_care`, `:oncology_care`  
**Acceptance criteria met:**
- [x] Quality gating reduces savings proportionally
- [x] One-sided models never pay losses
- [x] Two-sided models apply loss cap
- [x] TEAM bundled payment model with FY2026 notes
- [x] Rural-eligibility filtering

### T-027: ICER Sensitivity Analysis ✅
**Files modified:** `src/health_economics/ICER.jl`  
**New types:** `ICERParameter`, `ICERSensitivityResult`, `ICERTornadoData`  
**New functions:** `icer_one_way_sensitivity()`, `icer_probabilistic_sensitivity()`  
**Acceptance criteria met:**
- [x] One-way sensitivity produces tornado-sorted `ICERTornadoData`
- [x] `absolute_swing` sorts rows (largest driver first)
- [x] PSA with user-supplied distribution functions
- [x] CEAC curve computed across 0–500k WTP range
- [x] `pct_cost_effective` at specified WTP threshold

### T-028: Cohort Analysis Enhancement ✅
**Files modified:** `src/patient_cohort/cohort_builder.jl`  
**New types:** `CohortGroupKey`, `SubCohortSummary`, `GroupedCohortAnalysis`  
**New functions:** `group_cohort()`, `risk_stratify_cohort()`, `compare_cohorts()`  
**6 grouping dimensions:** `:payer`, `:age_decade`, `:drg_major`, `:quarter`, `:los_bucket`, `:cost_tercile`, `:custom`  
**Acceptance criteria met:**
- [x] All 6 built-in grouping dimensions
- [x] Custom grouping via `group_fn`
- [x] Results sorted by `total_cost` descending
- [x] `risk_stratify_cohort` with composite scoring (cost/LOS/age)
- [x] `compare_cohorts` for A/B comparison

### T-029: REH Analytics ✅
**Files created:** `src/analysis/reh_analytics.jl`  
**New types:** `REHParams`, `REHConversionAnalysis`  
**New functions:** `reh_facility_payment`, `reh_outpatient_addon`, `reh_swing_bed_revenue`, `reh_total_revenue`, `reh_operating_margin`, `reh_annual_summary`, `reh_projection`, `analyze_cah_to_reh_conversion`, `reh_viability_score`, `reh_eligibility_check`  
**Acceptance criteria met:**
- [x] FY2026 facility payment ($295,000/month)
- [x] 5% outpatient add-on
- [x] Swing-bed revenue (up to 10 beds)
- [x] 5-year projection with visit growth and expense inflation
- [x] CAH→REH NPV, payback, break-even ED visits
- [x] Viability score (0–100 composite)
- [x] CMS eligibility screening (42 CFR § 485.502)

### T-030: Reporting & Export Framework ✅
**Files created:** `src/visualization/reporting_framework.jl`  
**New types:** `ReportCell`, `ReportTable`, `ReportKV`, `ReportSection`, `Report`  
**New functions:** `export_report()` (`:text`, `:markdown`, `:csv`, `:json`), `build_financial_summary_report()`, `build_mc_results_report()`, `build_reh_conversion_report()`  
**Acceptance criteria met:**
- [x] Composable `ReportSection` + `Report` data model
- [x] 4 export formats (text, markdown, CSV, JSON)
- [x] Currency / percent / integer / float / auto formatting
- [x] Convenience builders for common report types
- [x] No I/O in Report struct (pure data, export is separate)

---

## Repo Hygiene Completed (2026-04-28)

| Task | Status | Notes |
|------|--------|-------|
| Merge 5 feature branches to main | ✅ COMPLETE | Via claude/hygiene-merge-all-2026-04-28 |
| Delete 35 stale branches | ✅ COMPLETE | See below |
| Julia compat (1.12→1.11) | ✅ COMPLETE | FinanceEngine + RuralCore both fixed |
| Codecov wiring | ✅ COMPLETE | ci.yml + .codecov.yml + LCOV pipeline |
| CMS rate TODOs in constants.jl | ✅ COMPLETE | FY2026 values applied (all 5 TODOs cleared) |
| vbc_transition.jl TODO | ✅ COMPLETE | Documented; escalation handled by ExtendedVBCParams |
| Duplicate /api/bugreport route | ✅ COMPLETE | Second occurrence removed from routes.jl |
| JS toolchain moved to e2e/ | ✅ COMPLETE | tsconfig.json, package.json, playwright.config.ts, package-lock.json |
