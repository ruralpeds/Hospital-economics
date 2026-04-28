# HAIKU Build Plan: Phase 3 Tier 2 Optimizations & Advanced Features

**Phase 3: Performance, Refactoring, and Advanced Analytics**

---

## Overview

Phase 3 addresses Tier 2 improvements focused on performance optimization, code refactoring, and advanced feature completeness. These enhancements improve efficiency, maintainability, and analytical depth without addressing critical bugs or missing validations (handled by Phases 1-2).

---

## T-021: Monte Carlo Performance Optimization

**File:** `src/simulation/montecarlo.jl`

**Issue:** Monte Carlo simulations scale poorly with large iteration counts (>10k iterations).

**Problem:**
- Current implementation allocates all iteration results upfront
- Thread-based parallelization has overhead for small n_iterations
- No result caching for repeated runs with same parameters
- Memory usage unbounded for large projections

**Scope:**
- Implement streaming result collection (process results in batches)
- Add optional result caching with expiration
- Optimize thread pool management for small/large n_iterations
- Implement early stopping for convergence detection (optional)

**Acceptance Criteria:**
- [ ] Monte Carlo 50k iterations runs in <30 seconds
- [ ] Memory usage bounded to ~100MB baseline + result size
- [ ] Result caching optional (configurable)
- [ ] Performance benchmarks documented
- [ ] Unit tests verify convergence behavior
- [ ] No accuracy loss from optimizations

**Effort Estimate:** 3 hours

---

## T-022: Hospital Projection Parallelization

**File:** `src/simulation/deterministic.jl`

**Issue:** Multi-hospital projections execute serially; could parallelize.

**Problem:**
- Hospital networks (10+ hospitals) project sequentially
- Each hospital projection is independent (parallelizable)
- No bulk projection API
- Wall-clock time scales linearly with hospital count

**Scope:**
- Add bulk_project_hospitals() function
- Parallelize across hospital set using Threads
- Implement result aggregation
- Add progress tracking for large runs

**Acceptance Criteria:**
- [ ] bulk_project_hospitals() parallelizes correctly
- [ ] 10-hospital network projects 8x faster (8 threads)
- [ ] Results match serial execution exactly
- [ ] Progress callback optional
- [ ] Unit tests verify parallelization
- [ ] Thread safety guaranteed

**Effort Estimate:** 2.5 hours

---

## T-023: Ratio Calculation Caching

**File:** `src/finance/ratios.jl`

**Issue:** Ratio calculations repeated for same financials; no caching mechanism.

**Problem:**
- compute_all_ratios() called multiple times per hospital
- 10 ratios recalculated on every call
- No memoization for unchanged financial data
- Time wasted on identical calculations

**Scope:**
- Add optional caching to compute_all_ratios()
- Implement cache invalidation on financials change
- Add cache statistics (hits/misses)
- Make caching configurable

**Acceptance Criteria:**
- [ ] compute_all_ratios() 10x faster on repeated calls
- [ ] Cache invalidation automatic
- [ ] Statistics API provided
- [ ] Caching optional (enabled by default)
- [ ] Unit tests verify cache correctness
- [ ] Memory usage reasonable

**Effort Estimate:** 1.5 hours

---

## T-024: Extract Common Validation Patterns

**File:** Various (src/finance/, src/models/)

**Issue:** Input validation code duplicated across multiple modules.

**Problem:**
- Rate bounds checking repeated in 5+ functions
- Cost validation patterns similar but implemented differently
- Hard to maintain consistent validation across codebase
- Missing centralized validation utility

**Scope:**
- Create validation utility module (src/utils/validation.jl)
- Extract common patterns: rate_valid(), cost_valid(), ratio_valid()
- Add centralized bound checking functions
- Refactor existing code to use utilities

**Acceptance Criteria:**
- [ ] Validation utilities module created
- [ ] At least 5 common patterns extracted
- [ ] Code duplication reduced by 40%+
- [ ] All validation calls use utilities
- [ ] Unit tests for validation utilities
- [ ] Backward compatible (no API changes)

**Effort Estimate:** 2.5 hours

---

## T-025: Add Hospital Type Discriminated Union

**File:** `src/models/hospital.jl`

**Issue:** Hospital types checked via type dispatch; no central registry.

**Problem:**
- New hospital types require code changes in multiple places
- No factory function for creating hospitals
- Hard to iterate over all hospital types
- Missing hospital type metadata

**Scope:**
- Create AbstractHospitalType hierarchy
- Add hospital_types() registry function
- Implement factory: create_hospital(type, params)
- Add hospital_type_properties() metadata

**Acceptance Criteria:**
- [ ] AbstractHospitalType hierarchy created
- [ ] Hospital registry function provided
- [ ] Factory function works for all types
- [ ] Metadata API provides type information
- [ ] Unit tests verify type dispatch
- [ ] Documentation updated

**Effort Estimate:** 2 hours

---

## T-026: VBC Model Variants for Specialized ACOs

**File:** `src/finance/vbc_transition.jl`

**Issue:** VBC module only supports 4 basic model types; real-world variants missing.

**Problem:**
- No support for regional variation (state-specific MSRs)
- ACO Beneficiary Incentive Program (ABI) not modeled
- No support for specialty ACOs (oncology, behavioral health)
- Shared savings calculations simplified compared to CMS rules

**Scope:**
- Add state-based MSR variations
- Implement ABI bonus calculation
- Add specialty ACO loss-cap rules
- Implement advance payment discounting

**Acceptance Criteria:**
- [ ] State-based MSR lookup table
- [ ] ABI bonus calculation documented
- [ ] Specialty ACO rules per CMS guidance
- [ ] Advance payment discounting optional
- [ ] Unit tests for each variant
- [ ] Backward compatible

**Effort Estimate:** 3 hours

---

## T-027: ICER Sensitivity Analysis Framework

**File:** `src/health_economics/ICER.jl`

**Issue:** ICER calculations lack sensitivity analysis; no way to vary parameters.

**Problem:**
- No built-in sensitivity analysis (tornado, one-way, two-way)
- Hard to understand parameter impact on ICER
- No uncertainty quantification
- Missing "break-even analysis"

**Scope:**
- Add one-way sensitivity analysis function
- Add two-way sensitivity analysis (2D grid)
- Implement break-even threshold finder
- Add tornado plot data generation

**Acceptance Criteria:**
- [ ] sensitivity_analysis_one_way() implemented
- [ ] sensitivity_analysis_two_way() implemented
- [ ] break_even_value() finder works
- [ ] Tornado plot data structure defined
- [ ] Unit tests verify calculations
- [ ] Examples provided

**Effort Estimate:** 2.5 hours

---

## T-028: Patient Cohort Analysis Enhancement

**File:** `src/analysis/` (cohort-related modules)

**Issue:** Patient cohort analysis lacks advanced grouping and filtering.

**Problem:**
- Limited cohort definitions (only basic service line splits)
- No risk stratification support
- Hard to analyze subpopulations
- Missing drill-down capabilities

**Scope:**
- Add risk-based cohort grouping (low/medium/high)
- Implement custom filter API
- Add cohort composition reporting
- Implement drill-down navigation

**Acceptance Criteria:**
- [ ] Risk-based cohort grouping works
- [ ] Custom filters chainable
- [ ] Composition report generated
- [ ] Drill-down API functional
- [ ] Unit tests for each feature
- [ ] Examples provided

**Effort Estimate:** 2.5 hours

---

## T-029: REH-Specific Analytics Module

**File:** `src/analysis/reh_analytics.jl` (new)

**Issue:** REH-specific analyses scattered; should be consolidated.

**Problem:**
- REH conversion analysis in risk/ subdirectory
- REH financials handled generically (miss type-specific insights)
- No REH-specific benchmarking
- Missing REH operational metrics

**Scope:**
- Create reh_analytics module
- Implement REH-specific metrics (inpatient/outpatient balance, etc.)
- Add REH benchmarking against peers
- Add REH-specific financial projections

**Acceptance Criteria:**
- [ ] REH analytics module created
- [ ] 5+ REH-specific metrics defined
- [ ] Benchmarking against REH peer data
- [ ] REH-specific projections tested
- [ ] Unit tests for new metrics
- [ ] Documentation with examples

**Effort Estimate:** 3 hours

---

## T-030: Reporting & Export Framework

**File:** `src/reporting/` (new directory)

**Issue:** No centralized reporting/export functionality; analyses hard to output.

**Problem:**
- Hospital projections not easily exportable
- No standard report formats (PDF, Excel, JSON)
- Hard to create custom reports
- No templating system

**Scope:**
- Create report generation framework
- Implement JSON export (standardized schema)
- Add CSV export for time series
- Add optional PDF generation (PlotlyJS)
- Implement simple templating

**Acceptance Criteria:**
- [ ] Report schema defined (JSON)
- [ ] JSON export working
- [ ] CSV export for projections
- [ ] PDF export optional
- [ ] Custom report API provided
- [ ] Unit tests for each format
- [ ] Examples provided

**Effort Estimate:** 3.5 hours

---

## Execution Plan

**Priority Order:**
1. **T-021, T-022**: Performance (impacts all Monte Carlo users)
2. **T-023, T-024**: Code Quality (improves maintainability)
3. **T-025, T-026**: Advanced Features (domain-specific)
4. **T-027, T-028**: Analytics (power-user features)
5. **T-029, T-030**: Specialized Tools (nice-to-have)

**Estimated Effort by Category:**
- Performance: 5.5h (T-021, T-022, T-023)
- Code Quality: 2.5h (T-024)
- Advanced Features: 5h (T-025, T-026)
- Analytics: 5h (T-027, T-028)
- Specialized: 6.5h (T-029, T-030)

**Total: ~24.5 hours across 10 tasks**

---

## Success Criteria

Phase 3 is complete when:
- Performance benchmarks met (MC 50k in <30s, bulk projects 8x faster)
- Code duplication reduced by >30%
- All new features have unit tests (>80% coverage)
- Documentation complete with examples
- Backward compatibility maintained

---

## Deferred to Phase 4

- Machine learning integration (patient risk prediction)
- Real-time dashboard (streaming projections)
- Audit logging and compliance tracking
- API server (RESTful endpoints)
- Cloud deployment (containerization)

---

## Technical Debt Addressed

- Eliminates validation code duplication (T-024)
- Consolidates hospital type logic (T-025)
- Centralizes VBC business rules (T-026)
- Establishes standard reporting (T-030)

---

## Risk Mitigation

1. **Performance (T-021, T-022)**: Benchmark before/after; maintain accuracy
2. **Refactoring (T-024, T-025)**: Maintain backward compatibility; extensive tests
3. **New Features (T-026-030)**: Keep optional/configurable; don't break existing code

---

## Dependencies

```
Performance Tier:
  T-021 → T-023 (caching uses optimized iteration)
  T-022 → no dependencies

Code Quality:
  T-024 → T-025, T-026 (use validation utilities)

Features:
  T-025 → T-026 (hospital registry used by VBC)
  T-027 → standalone
  T-028 → standalone
  T-029 → T-028 (cohort analysis)
  T-030 → all (exports depend on analyzable objects)
```

---

## Rollout Timeline

**Week 1-2 (Performance + Code Quality):**
- T-021: Monte Carlo optimization (3h)
- T-022: Hospital parallelization (2.5h)
- T-023: Ratio caching (1.5h)
- T-024: Validation extraction (2.5h)

**Week 3-4 (Advanced Features):**
- T-025: Hospital type registry (2h)
- T-026: VBC model variants (3h)
- T-027: ICER sensitivity (2.5h)
- T-028: Cohort analysis (2.5h)

**Week 5 (Specialized):**
- T-029: REH analytics (3h)
- T-030: Reporting framework (3.5h)

---

## Metrics to Track

1. **Performance**: Wall-clock time for standard workloads
2. **Quality**: Code duplication %, test coverage %
3. **Feature Completeness**: Feature count, API surface area
4. **User Experience**: Report formats supported, export options

---

## Change Log

- **2026-04-27**: Initial Phase 3 plan created (10 tasks, 24.5 hour estimate)
