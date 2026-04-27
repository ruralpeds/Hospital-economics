# HAIKU Build Plan: Phase 2 Tier 1 Improvements

**Phase 2: Validation, Edge Cases, and Code Quality**

---

## Overview

Phase 2 addresses Tier 1 issues identified during Phase 1 audit. These are important but not critical: missing validations, incomplete edge case handling, documentation gaps, and code quality improvements that strengthen the foundation laid by Tier 0 fixes.

---

## T-011: Financial Ratio Bounds Validation

**File:** `src/finance/ratios.jl`

**Issue:** Ratio functions don't validate output bounds or warn on suspicious values.

**Problem:**
- `operating_margin()` can return negative values but doesn't warn if unsustainably low
- `debt_to_capitalization()` could exceed 1.0 if liabilities > capitalization+net_assets
- `days_cash_on_hand()` returns `Inf` on zero expenses but no warning message
- No upper bounds checks for unrealistic ratios

**Scope:**
- Add bounds validation (margins should be [-1.0, 1.0])
- Add warning thresholds (e.g., margin < -0.05 triggers warning)
- Document assumptions (e.g., why Inf is returned for zero expenses)
- Add tests for edge cases: negative revenue, zero assets, inverted balance sheet

**Acceptance Criteria:**
- [ ] All ratio functions validate output bounds
- [ ] Warning messages logged for out-of-range values
- [ ] Docstrings document edge case behavior
- [ ] Unit tests cover edge cases (zero, negative, extreme values)
- [ ] No ratio functions return silent NaN or Inf without explanation

---

## T-012: Reimbursement Function Input Validation

**File:** `src/finance/reimbursement.jl`

**Issue:** Functions accept invalid parameter combinations without validation.

**Problem:**
- `apply_bad_debt_adjustment()` accepts `reimbursement_rate > 1.0` without error
- No validation that rates are probabilities (0.0-1.0)
- OPPS/IPPS functions may not check cost-to-charge ratio bounds (typically 0.20-0.95)
- No warnings for suspicious combinations (e.g., bad debt > total operating expenses)

**Scope:**
- Add parameter validation: rates must be [0.0, 1.0]
- Add parameter validation: costs must be <= revenue
- Add warnings for unusual but valid combinations
- Document valid ranges in docstrings

**Acceptance Criteria:**
- [ ] All rate/ratio parameters validated as [0.0, 1.0]
- [ ] Cost validations prevent nonsensical scenarios
- [ ] Error messages are clear and actionable
- [ ] Unit tests verify validation logic
- [ ] No silent failures on invalid input

---

## T-013: Hospital Model Type Validation

**File:** `src/models/hospital.jl`

**Issue:** Hospital types not fully validated; conversions lack safeguards.

**Problem:**
- No validation that CAH beds <= 25 per regulation
- REH conversion doesn't validate "former_designation" field
- No checks that location is geographically valid (e.g., coordinates)
- Missing validation that service area population >= licensed beds

**Scope:**
- Add CAH bed count validation (max 25)
- Add REH conversion eligibility validation
- Add geographic coordinate bounds (±90 lat, ±180 lon)
- Add service area population sanity checks
- Document regulatory requirements

**Acceptance Criteria:**
- [ ] CAH bed count validated (<= 25)
- [ ] REH conversions validate former_designation
- [ ] Geographic coordinates validated
- [ ] Service area population > 0
- [ ] Error messages cite regulatory basis
- [ ] Unit tests cover invalid hospital configurations

---

## T-014: Monte Carlo Parameter Range Validation

**File:** `src/simulation/montecarlo.jl`

**Issue:** MonteCarloParams accept unrealistic distribution parameters.

**Problem:**
- No bounds on distribution means/stds (e.g., volume_growth std > mean allows >100% decrease)
- Projections can diverge with extreme inflation rates (>20%/year)
- No validation that n_iterations > 0
- Missing checks: random_seed validity, projection_years > 0

**Scope:**
- Add bounds on distribution parameters (e.g., std < 2×mean)
- Add sanity bounds on inflation (typically 0%-10%)
- Add n_iterations > 0 validation
- Document realistic ranges in docstring
- Add unit tests for invalid parameter combinations

**Acceptance Criteria:**
- [ ] Distribution parameters validated for realism
- [ ] Inflation rates bounded (0.0-0.15)
- [ ] n_iterations must be > 0
- [ ] Docstring documents valid ranges
- [ ] Unit tests verify parameter validation
- [ ] Error messages are actionable

---

## T-015: VBC Parameter Type Safety

**File:** `src/finance/vbc_transition.jl`

**Issue:** VBC model allows invalid model_type values without error.

**Problem:**
- Error checking happens in `calculate_vbc_outcome()` but not during struct creation
- No validation of model_type at construction time
- No bounds on quality_score precision (should be 0.0-1.0)
- Shared_savings_rate and shared_loss_rate not validated against model_type rules

**Scope:**
- Add custom struct constructor with validation
- Validate model_type in VBCParams constructor
- Validate quality_score bounds [0.0, 1.0]
- Add model-specific parameter validation (e.g., MSSP Basic doesn't use loss rates)
- Add docstring with valid parameter combinations

**Acceptance Criteria:**
- [ ] VBCParams constructor validates all parameters
- [ ] Invalid model_type throws error at construction
- [ ] quality_score bounds enforced [0.0, 1.0]
- [ ] Model-specific rules validated
- [ ] Clear error messages for invalid combinations
- [ ] Unit tests verify constructor validation

---

## T-016: ICER Threshold Documentation & Defaults

**File:** `src/health_economics/ICER.jl`

**Issue:** Willingness-to-pay thresholds not clearly documented or parameterized.

**Problem:**
- Hardcoded threshold values not documented
- No guidance on standard WTP thresholds by context (US, UK, WHO)
- Default ICER threshold not configurable
- Missing documentation on ICER interpretation (cost-effective vs. not)

**Scope:**
- Document current threshold constants with sources
- Add configurable WTP threshold parameter
- Document standard thresholds (e.g., $50k, $100k, $150k/QALY)
- Add utility function to check cost-effectiveness at threshold
- Document ICER interpretation guidelines

**Acceptance Criteria:**
- [ ] All threshold constants documented with sources
- [ ] WTP thresholds configurable (not hardcoded)
- [ ] Standard threshold reference table in docstring
- [ ] Cost-effectiveness interpretation documented
- [ ] Unit tests verify threshold behavior
- [ ] Examples show typical use cases

---

## T-017: Risk Conversion Validation

**File:** `src/risk/conversion.jl`

**Issue:** REH conversion analysis lacks input validation and edge case handling.

**Problem:**
- Base revenue/costs not validated (no negative checks)
- Conversion assumptions not validated against realistic ranges
- No bounds on volume_retention (should be 0.0-1.0)
- Missing validation that REH revenue > 0 after conversion

**Scope:**
- Add revenue/cost validation (must be >= 0)
- Add assumption bounds checking
- Validate volume_retention is [0.0, 1.0]
- Add warning if projected revenue < base_costs
- Document assumptions and ranges

**Acceptance Criteria:**
- [ ] Revenue and costs validated >= 0
- [ ] All assumptions bounded to realistic ranges
- [ ] volume_retention validated [0.0, 1.0]
- [ ] Warning if revenue < costs
- [ ] Clear error messages
- [ ] Unit tests cover edge cases

---

## T-018: Payer Mix Consistency Validation

**File:** `src/models/payer.jl`

**Issue:** Payer mix percentages not validated to sum to 1.0.

**Problem:**
- Payer contracts can be added without checking total volume share = 1.0
- No validation that rates are valid (typically 0.30-1.0 of charges)
- Missing check: volume_share >= 0
- No warning if payer mix changes significantly year-to-year

**Scope:**
- Add validation: payer volume shares must sum to 1.0 (within tolerance)
- Add rate bounds checking [0.0, 2.0]
- Add volume_share bounds [0.0, 1.0]
- Add methods to validate payer_mix consistency
- Document tolerance levels and assumptions

**Acceptance Criteria:**
- [ ] Payer volume shares validate to sum ~1.0
- [ ] Rate bounds enforced [0.0, 2.0]
- [ ] volume_share bounds validated
- [ ] Validation method provided (e.g., is_valid_payer_mix)
- [ ] Clear error messages for invalid mixes
- [ ] Unit tests cover invalid combinations

---

## T-019: Depreciation & Amortization Consistency

**File:** `src/models/financial.jl`

**Issue:** Depreciation/amortization values not validated against asset base.

**Problem:**
- Depreciation can exceed total assets
- No validation that depreciation + amortization <= total_operating_expenses
- Missing bounds: typical depreciation rate is 3-5% of assets/year
- No warning if depreciation expense seems too high

**Scope:**
- Add validation: depreciation <= total_assets / 20 (rough 5% limit)
- Add check: depreciation + amortization <= operating_expenses
- Add sanity bounds on depreciation rate
- Document typical depreciation rates by facility type
- Add warning for suspicious values

**Acceptance Criteria:**
- [ ] Depreciation expense validated against assets
- [ ] Depreciation + amortization <= operating_expenses
- [ ] Depreciation rate bounds documented
- [ ] Warnings for out-of-range values
- [ ] Error messages are clear
- [ ] Unit tests verify bounds

---

## T-020: Constants Module Completeness Audit

**File:** `src/utils/constants.jl`

**Issue:** Missing critical constants; values need periodic refresh.

**Problem:**
- No sequestration rate for different periods (changes over time)
- Missing outlier payment percentages (varies by facility type)
- COLA adjustments not documented with effective dates
- No version tracking for when constants were last updated

**Scope:**
- Add version/last_updated comments to each constant
- Document all CMS rate variations (IPPS vs. OPPS, etc.)
- Add missing outlier payment rates
- Add function to validate constant consistency
- Create audit checklist for annual updates

**Acceptance Criteria:**
- [ ] All constants have last_updated date
- [ ] CMS sources cited for each value
- [ ] Variation (by facility type, year) documented
- [ ] No orphaned constants
- [ ] Validation function prevents inconsistency
- [ ] Unit tests verify constant sanity

---

## Execution Plan

**Priority Order:**
1. **T-011, T-012**: Ratio & reimbursement validation (foundational)
2. **T-013, T-014**: Hospital & Monte Carlo validation (core domain)
3. **T-015, T-018**: VBC & payer mix (advanced analytics)
4. **T-016, T-019, T-020**: Documentation & completeness (supportive)
5. **T-017**: Risk conversion (specialized)

**Estimated Effort:**
- T-011: 2h
- T-012: 2h
- T-013: 2.5h
- T-014: 2.5h
- T-015: 2h
- T-016: 1.5h
- T-017: 2h
- T-018: 2h
- T-019: 1.5h
- T-020: 2h

**Total: ~21 hours across 10 tasks**

---

## Success Criteria

Phase 2 is complete when all T-011 through T-020 tasks are:
- Audited (validation requirements identified)
- Fixed (code changes implement validation)
- Tested (unit tests verify bounds & edge cases)
- Documented (docstrings explain valid ranges & assumptions)

---

## Deferred to Phase 3

- Performance optimizations (Monte Carlo parallelization)
- Refactoring (extract common validation patterns)
- Advanced features (ACO-specific model variants)
- Integration testing (end-to-end hospital projections)
