# HAIKU Build Tracking: Phase 2 Status Matrix

**Created:** 2026-04-27  
**Branch:** `claude/audit-fix-planning-DVvmd`  
**Phase:** 2 (Tier 1 Validation & Code Quality)

---

## Phase 2 Status Summary

| Task | Title | Status | Owner | Effort (hrs) | Complexity | Priority |
|------|-------|--------|-------|---------|-----------|----------|
| T-011 | Ratio Bounds Validation | ⏳ PENDING | Haiku | 2 | Medium | High |
| T-012 | Reimbursement Input Validation | ⏳ PENDING | Haiku | 2 | Medium | High |
| T-013 | Hospital Model Validation | ⏳ PENDING | Haiku | 2.5 | Medium | High |
| T-014 | Monte Carlo Parameter Range Validation | ⏳ PENDING | Haiku | 2.5 | Medium | High |
| T-015 | VBC Parameter Type Safety | ⏳ PENDING | Haiku | 2 | Medium | Medium |
| T-016 | ICER Threshold Documentation | ⏳ PENDING | Haiku | 1.5 | Low | Medium |
| T-017 | Risk Conversion Validation | ⏳ PENDING | Haiku | 2 | Medium | Medium |
| T-018 | Payer Mix Consistency Validation | ⏳ PENDING | Haiku | 2 | Medium | Medium |
| T-019 | Depreciation/Amortization Consistency | ⏳ PENDING | Haiku | 1.5 | Low | Low |
| T-020 | Constants Module Completeness | ⏳ PENDING | Haiku | 2 | Low | Low |

**Legend:**
- ⏳ PENDING: Not started
- 🔄 IN_PROGRESS: Currently being worked on
- ✅ COMPLETE: Done, tested, committed
- ⚠️ BLOCKED: Waiting for external input
- ❌ FAILED: Issue encountered, needs review

**Overall Progress:** 0/10 tasks complete (0%)

**Effort Allocation:**
- High Priority: 6 tasks, 9 hours (43%)
- Medium Priority: 3 tasks, 6 hours (29%)
- Low Priority: 1 task, 6 hours (29%)

---

## Task Breakdown

### T-011: Ratio Bounds Validation

**Status:** ⏳ PENDING

**File Location:** `src/finance/ratios.jl`

**Scope:**
- Validate output bounds for all ratio functions
- Add warnings for suspicious values
- Document edge case behavior

**Key Changes:**
- operating_margin: ensure [-1.0, 1.0]
- debt_to_capitalization: ensure [0.0, 1.0]
- days_cash_on_hand: document Inf case
- Add warning thresholds

**Acceptance Criteria:**
- [ ] All ratio functions validate bounds
- [ ] Warning messages logged for out-of-range
- [ ] Docstrings explain edge cases
- [ ] Unit tests for zero, negative, extreme values

**Dependencies:** None

---

### T-012: Reimbursement Input Validation

**Status:** ⏳ PENDING

**File Location:** `src/finance/reimbursement.jl`

**Scope:**
- Validate all rate/ratio parameters [0.0, 1.0]
- Validate costs <= revenue relationships
- Add warnings for unusual combinations

**Key Changes:**
- apply_bad_debt_adjustment: rate bounds [0.0, 1.0]
- Cost-to-charge ratio bounds [0.2, 0.95]
- Add parameter validation in all functions

**Acceptance Criteria:**
- [ ] Rate parameters validated [0.0, 1.0]
- [ ] Cost validations prevent illogical scenarios
- [ ] Clear error messages
- [ ] Unit tests verify validation

**Dependencies:** T-011

---

### T-013: Hospital Model Validation

**Status:** ⏳ PENDING

**File Location:** `src/models/hospital.jl`

**Scope:**
- Validate CAH bed count (<= 25)
- Validate REH conversion requirements
- Validate geographic coordinates
- Validate service area population

**Key Changes:**
- Add custom struct constructors with validation
- CAH: beds <= 25
- REH: validate conversion eligibility
- Coordinates: ±90 lat, ±180 lon
- Service area > 0

**Acceptance Criteria:**
- [ ] CAH bed validation (<= 25)
- [ ] REH conversion validated
- [ ] Geographic bounds enforced
- [ ] Service area > 0
- [ ] Error messages cite regulations
- [ ] Unit tests cover invalid configs

**Dependencies:** None

---

### T-014: Monte Carlo Parameter Validation

**Status:** ⏳ PENDING

**File Location:** `src/simulation/montecarlo.jl`

**Scope:**
- Validate distribution parameters
- Validate realistic inflation bounds
- Validate n_iterations > 0
- Document valid ranges

**Key Changes:**
- Add MonteCarloParams constructor validation
- Distribution std < 2×mean
- Inflation rates [0.0, 0.15]
- n_iterations > 0, projection_years > 0
- Document ranges in docstring

**Acceptance Criteria:**
- [ ] Distribution parameters validated
- [ ] Inflation rates bounded
- [ ] n_iterations validated > 0
- [ ] Docstring documents valid ranges
- [ ] Unit tests verify validation
- [ ] Error messages actionable

**Dependencies:** T-011, T-012

---

### T-015: VBC Parameter Type Safety

**Status:** ⏳ PENDING

**File Location:** `src/finance/vbc_transition.jl`

**Scope:**
- Add struct constructor validation
- Validate model_type at construction
- Validate quality_score [0.0, 1.0]
- Model-specific parameter validation

**Key Changes:**
- Custom VBCParams constructor
- model_type validation
- quality_score bounds [0.0, 1.0]
- Shared rate validation per model
- Document valid combinations

**Acceptance Criteria:**
- [ ] Constructor validates parameters
- [ ] model_type error at construction
- [ ] quality_score bounds [0.0, 1.0]
- [ ] Model-specific rules enforced
- [ ] Clear error messages
- [ ] Unit tests verify constructor

**Dependencies:** T-012

---

### T-016: ICER Threshold Documentation

**Status:** ⏳ PENDING

**File Location:** `src/health_economics/ICER.jl`

**Scope:**
- Document threshold constants
- Make WTP thresholds configurable
- Document standard thresholds
- Add interpretation guidelines

**Key Changes:**
- Document current thresholds with sources
- Parameterize WTP thresholds
- Add threshold reference table
- Document ICER interpretation

**Acceptance Criteria:**
- [ ] Thresholds documented with sources
- [ ] WTP configurable (not hardcoded)
- [ ] Standard thresholds documented
- [ ] Interpretation guidelines clear
- [ ] Unit tests verify thresholds
- [ ] Examples provided

**Dependencies:** None

---

### T-017: Risk Conversion Validation

**Status:** ⏳ PENDING

**File Location:** `src/risk/conversion.jl`

**Scope:**
- Validate base revenue/costs >= 0
- Validate conversion assumptions
- Validate volume_retention [0.0, 1.0]
- Warn if revenue < costs

**Key Changes:**
- Add input validation functions
- Bounds checking on assumptions
- volume_retention [0.0, 1.0]
- Warning for revenue < costs
- Document assumptions

**Acceptance Criteria:**
- [ ] Revenue/costs validated >= 0
- [ ] Assumptions bounded
- [ ] volume_retention [0.0, 1.0]
- [ ] Warning if revenue < costs
- [ ] Clear error messages
- [ ] Unit tests cover edge cases

**Dependencies:** T-013

---

### T-018: Payer Mix Consistency Validation

**Status:** ⏳ PENDING

**File Location:** `src/models/payer.jl`

**Scope:**
- Validate volume shares sum to 1.0
- Validate rates [0.0, 2.0]
- Validate volume_share [0.0, 1.0]
- Document tolerance levels

**Key Changes:**
- Add validation method
- Volume shares sum check (tolerance 0.01)
- Rate bounds [0.0, 2.0]
- volume_share bounds [0.0, 1.0]
- Document assumptions

**Acceptance Criteria:**
- [ ] Volume shares validate sum ~1.0
- [ ] Rate bounds [0.0, 2.0]
- [ ] volume_share bounds [0.0, 1.0]
- [ ] Validation method provided
- [ ] Clear error messages
- [ ] Unit tests cover invalid mixes

**Dependencies:** T-012

---

### T-019: Depreciation/Amortization Consistency

**Status:** ⏳ PENDING

**File Location:** `src/models/financial.jl`

**Scope:**
- Validate depreciation <= assets
- Validate depreciation + amortization <= expenses
- Document typical depreciation rates
- Add warnings for suspicious values

**Key Changes:**
- Depreciation <= total_assets / 20
- Depreciation + amortization <= operating_expenses
- Bounds on depreciation rate
- Warning for out-of-range
- Document by facility type

**Acceptance Criteria:**
- [ ] Depreciation validated against assets
- [ ] Depreciation + amortization <= operating_expenses
- [ ] Depreciation rate bounds documented
- [ ] Warnings for out-of-range
- [ ] Clear error messages
- [ ] Unit tests verify bounds

**Dependencies:** None

---

### T-020: Constants Module Completeness

**Status:** ⏳ PENDING

**File Location:** `src/utils/constants.jl`

**Scope:**
- Add version/last_updated to constants
- Document CMS rate variations
- Add missing rates (outlier payment %)
- Create annual update checklist

**Key Changes:**
- Add last_updated comments
- Document variations by type/year
- Add outlier payment rates
- Add validation function
- Create update checklist

**Acceptance Criteria:**
- [ ] All constants have last_updated date
- [ ] CMS sources cited
- [ ] Variations documented
- [ ] No orphaned constants
- [ ] Validation function provided
- [ ] Update checklist created

**Dependencies:** None

---

## Execution Strategy

**Phase 2A (High Priority - 9 hours):**
- T-011, T-012, T-013, T-014
- Focus on core domain validation
- These blocks T-015, T-018

**Phase 2B (Medium Priority - 6 hours):**
- T-015, T-016, T-017, T-018
- Advanced analytics and domain rules

**Phase 2C (Low Priority - 6 hours):**
- T-019, T-020
- Supporting improvements, can be deferred

---

## Cross-Task Dependencies

```
Foundation:
  None (Phase 2 independent from Phase 1)

Validation Tier:
  T-012 (Reimbursement) → T-015 (VBC), T-018 (Payer Mix)
  T-013 (Hospital) → T-017 (Risk Conversion)
  T-014 (Monte Carlo) → standalone

Documentation Tier:
  T-016 (ICER), T-020 (Constants) → standalone
  T-019 (Depreciation) → standalone
```

---

## Rollout Phases

**Week 1 (Phase 2A):**
- T-011: Ratio bounds (2h)
- T-012: Reimbursement validation (2h)
- T-013: Hospital model validation (2.5h)
- T-014: Monte Carlo parameters (2.5h)

**Week 2 (Phase 2B):**
- T-015: VBC type safety (2h)
- T-016: ICER documentation (1.5h)
- T-017: Risk conversion validation (2h)
- T-018: Payer mix validation (2h)

**Week 3 (Phase 2C):**
- T-019: Depreciation consistency (1.5h)
- T-020: Constants completeness (2h)

---

## Known Considerations

1. **T-011/T-012 interdependence**: Ratio functions used in reimbursement validation
2. **T-013 regulatory basis**: Validations must cite CFR sections
3. **T-014 distribution assumptions**: Document rationale for std/mean bounds
4. **T-020 CMS tracking**: Requires annual review cycle setup

---

## Success Metrics

- **Code Coverage**: All validation paths tested (target: 90%+)
- **Error Messages**: Clear, actionable, cite regulations where applicable
- **Documentation**: Every parameter documented with valid range
- **Backward Compatibility**: Phase 2 fixes should not break existing code

---

## Change Log

- **2026-04-27**: Initial Phase 2 plan created (10 tasks, 21 hour estimate)
