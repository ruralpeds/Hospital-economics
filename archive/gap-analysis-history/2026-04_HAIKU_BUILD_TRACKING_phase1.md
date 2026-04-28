# HAIKU Build Tracking: Phase 1 Status Matrix

**Last Updated:** 2026-04-27 (Session 1 - 70% Complete)  
**Branch:** `claude/audit-fix-planning-DVvmd`  
**Phase:** 1 (Tier 0 Critical Fixes) - 7 of 10 tasks complete

---

## Phase 1 Status Summary

| Task | Title | Status | Owner | Effort (hrs) | Commits |
|------|-------|--------|-------|---------|---------|
| T-001 | Payer Negotiation Rate Formula | ✅ COMPLETE | Haiku | 2 | afe6c78 |
| T-002 | Total Margin Calculation | ✅ COMPLETE | Haiku | 2 | 73b1da2 |
| T-003 | REH Facility-Payment Constants | ✅ COMPLETE | Haiku | 3 | 7a8863e |
| T-004 | OPPS/IPPS/Outlier Constants | ✅ COMPLETE | Haiku | 4 | 7a8863e |
| T-005 | Monte Carlo Sample-Capture | ✅ COMPLETE | Haiku | 2 | e9bfbd8 |
| T-006 | CAH Bad Debt Reimbursement | ✅ COMPLETE | Haiku | 2 | 8f1ee1a |
| T-007 | VBC MSR & Loss-Cap Tables | ✅ COMPLETE | Haiku | 3 | ecced05 |
| T-008 | ICER CEAC & Constants | ⏳ PENDING | Haiku | 2 | — |
| T-009 | RuralHospitalSim Includes | ⏳ PENDING | Haiku | 2 | — |
| T-010 | Conversion Formula REH Base | ⏳ PENDING | Haiku | 2 | — |

**Legend:**
- ✅ COMPLETE: Done, tested, committed
- ⏳ PENDING: Not yet started
- 🔄 IN_PROGRESS: Currently being worked on
- ⚠️ BLOCKED: Waiting for external input
- ❌ FAILED: Issue encountered, needs review

**Overall Progress:** 7/10 tasks complete (70%)

---

## Detailed Task Tracking

---

### T-001: Payer Negotiation Rate Formula Correction

**Status:** ⏳ PENDING

**File Location:** `src/analysis/payer_negotiation.jl:219`

**Issue Summary:**
The required rate formula at line 219 uses:
```julia
required_rate = ccr * (1.0 + target_margin)
```
This may be mathematically incorrect for healthcare financial models. The formula treats cost-to-charge ratio (CCR) as if it's operating cost, then multiplies by (1 + margin). Standard healthcare economics models use different formulations depending on whether CCR is expressed as costs-per-charges or costs-per-revenue.

**Acceptance Criteria Checklist:**
- [ ] Formula validated against authoritative healthcare financial models
- [ ] Docstring clarifies the basis of CCR in the formula
- [ ] Unit tests confirm margin targets (2%, 5%, 10%) produce correct rates
- [ ] CAH example test: 0.85 CCR with 3% target margin produces rate ~0.88-0.95
- [ ] Code review signed off on formula logic

**Dependencies:** None (foundational formula)

**Subtasks:**
1. [ ] Read healthcare finance literature on rate-setting formulas
2. [ ] Compare current formula to CAH case studies in codebase
3. [ ] Implement corrected formula if needed
4. [ ] Add/update unit tests with expected values
5. [ ] Update docstring with formula basis explanation

**Notes:**
- May need to involve domain expert (healthcare economist)
- Check if formula matches other modules (check ratios.jl, reimbursement.jl patterns)

---

### T-002: Total Margin Calculation Fix

**Status:** ⏳ PENDING

**File Location:** `src/finance/ratios.jl:25-29`

**Issue Summary:**
The `total_margin()` function calculates:
```julia
net_income = financials.total_revenue - financials.total_operating_expenses
return net_income / financials.total_revenue
```

This does not subtract non-operating expenses (interest, taxes, depreciation adjustments, etc.), leading to overstated margin calculations. The net income should account for all expenses, not just operating.

**Current Formula:**
```
total_margin = (total_revenue - operating_expenses) / total_revenue
```

**Corrected Formula:**
```
total_margin = (total_revenue - operating_expenses - non_operating_expenses) / total_revenue
```

**Acceptance Criteria Checklist:**
- [ ] Audit `AnnualFinancials` struct: identify all expense fields
- [ ] Verify which fields should be included in net_income
- [ ] Implement corrected formula
- [ ] Test against known CAH financials: 10M revenue, 9M operating costs, 0.5M other → expect ~5% not 10%
- [ ] Validate against Flex Monitoring Team total_margin definition
- [ ] Update docstring

**Dependencies:** T-001 (understand financial ratio relationships)

**Subtasks:**
1. [ ] Read AnnualFinancials definition (search: `struct AnnualFinancials`)
2. [ ] List all fields and categorize (operating vs. non-operating)
3. [ ] Research Flex Monitoring standard definition
4. [ ] Write corrected function
5. [ ] Create test case with manual verification
6. [ ] Run existing tests to check for regressions

**Notes:**
- Check if ratios.jl is used in other modules (grep for `total_margin`)
- May need to update dependent calculations

---

### T-003: REH Facility-Payment Constant Reconciliation

**Status:** ⏳ PENDING

**File Location:** Multiple reimbursement files (TBD during audit)

**Issue Summary:**
Rural Eligible Hospital (REH) facility payment multipliers and base amounts may be outdated or inconsistent across modules. Need to reconcile all REH constants against official 2024-2025 CMS sources.

**Scope:**
- REH IPPS base payment amount
- REH adjustment factors (DRG weight, outlier threshold)
- REH bundle vs. unbundled payment split
- Any module-specific REH overrides

**Acceptance Criteria Checklist:**
- [ ] Inventory all REH constants across codebase
- [ ] Document source (CMS rule + effective date) for each
- [ ] Cross-check against CMS 2025 IPPS rate update notice
- [ ] Update any values that differ from CMS by >0.5%
- [ ] Add comment citations for each REH constant
- [ ] Projection test: REH reimbursement falls within expected range

**Dependencies:** T-001, T-002 (foundation)

**Subtasks:**
1. [ ] Search codebase for "REH" keyword
2. [ ] Create inventory of all REH constants and their locations
3. [ ] Document current values and where they come from
4. [ ] Fetch CMS 2025 IPPS rule (Federal Register + PDF)
5. [ ] Compare and identify discrepancies
6. [ ] Update values with inline comments citing CMS source
7. [ ] Write projection test for REH facility

**Notes:**
- REH rules are complex; CMS often updates them annually
- May need to distinguish between different REH payment models

---

### T-004: OPPS/IPPS/Outlier Constants Refresh

**Status:** ⏳ PENDING

**File Location:** Multiple (primary: `src/finance/reimbursement.jl`)

**Issue Summary:**
Outpatient Prospective Payment System (OPPS), Inpatient Prospective Payment System (IPPS), and outlier threshold constants may be outdated. These are regulatory rates that change annually and must match CMS effective rates.

**Scope:**
- OPPS conversion factors and APC weights
- IPPS DRG base payment rates and relative weights
- Outlier thresholds (cost > X% of DRG payment)
- Cost-to-charge ratio (CCR) caps and floors
- High-cost outlier (HCO) multiplier rates

**Acceptance Criteria Checklist:**
- [ ] Identify all hardcoded OPPS/IPPS constants
- [ ] Document source and effective date for each
- [ ] Cross-check against CMS 2025 rate update notice
- [ ] Update any rates differing from CMS by >1%
- [ ] Add inline documentation citing CMS source
- [ ] Validate with 2-3 example claims (outlier triggering, payment calculation)
- [ ] No regression in existing unit tests

**Dependencies:** T-003 (REH is subset of IPPS)

**Subtasks:**
1. [ ] Grep for hardcoded rate constants (numbers like 0.85, conversion factors)
2. [ ] Categorize: OPPS vs. IPPS vs. outlier vs. other
3. [ ] Create mapping of constants to CMS schedule items
4. [ ] Fetch latest CMS rate notices
5. [ ] Identify discrepancies
6. [ ] Update code with CMS source citations
7. [ ] Manual claim calculations to verify
8. [ ] Run unit tests

**Notes:**
- OPPS rates change January 1 each year
- IPPS DRG rates typically change October 1
- Need to track effective date for each constant

---

### T-005: Monte Carlo Sample-Capture Consistency

**Status:** ⏳ PENDING

**File Location:** `src/simulation/montecarlo.jl:128-157`

**Issue Summary:**
The functions `_sample_deterministic_params()` (lines 128-138) and `_collect_sampled_params()` (lines 146-157) sample parameters inconsistently:
- Deterministic: samples 7 parameters including `reimbursement_adjustment`
- Collector: samples 8 different parameters, missing `reimbursement_adjustment`

This inconsistency breaks reproducibility and audit trails. When seeded with same RNG, the two functions will diverge.

**Current Problem:**
```julia
# _sample_deterministic_params: reimbursement_adjustment sampled here
reimbursement_adjustment = sample(mc_params.cost_inflation, rng) * 0.5

# _collect_sampled_params: does NOT sample reimbursement_adjustment
# But DOES sample: ma_penetration_growth, staffing_turnover, travel_nurse_premium
```

**Acceptance Criteria Checklist:**
- [ ] Align both functions to sample identical parameter set
- [ ] Add `reimbursement_adjustment` to collector OR remove from deterministic
- [ ] Both functions call `sample()` in identical order
- [ ] Unit test: fixed seed → both functions produce identical sampled dicts
- [ ] Reproducibility test: MC run with seed=123 → same results on repeat
- [ ] No change to MC output accuracy (only audit trail improvement)

**Dependencies:** None (pure refactoring)

**Critical for:** All downstream MC-based projections

**Subtasks:**
1. [ ] Inspect both functions side-by-side
2. [ ] Decide: should deterministic also sample ma_penetration_growth, etc.?
3. [ ] Refactor to unified sampling list
4. [ ] Write unit test for sampling consistency
5. [ ] Write reproducibility test with fixed seed
6. [ ] Run full MC test suite

**Notes:**
- Reproducibility is critical for validation
- Changes to sampling order will change RNG sequence for all iterations
- May need to regenerate MC validation results

---

### T-006: CAH Bad Debt Reimbursement Rate

**Status:** ⏳ PENDING

**File Location:** `src/finance/reimbursement.jl:480`

**Issue Summary:**
The CAH bad debt reimbursement function applies a 101% multiplier to the reimbursement rate, which appears to be incorrect interpretation of the CMS rule.

**Current Code:**
```julia
function apply_bad_debt_adjustment(total_bad_debt::Float64;
                                   reimbursement_rate::Float64=0.65,
                                   is_cah::Bool=false)
    effective_rate = is_cah ? min(reimbursement_rate * 1.01, 1.0) : reimbursement_rate
```

**Problem:**
- Multiplies rate by 1.01 → e.g., 0.65 becomes 0.6565
- CMS rule states CAHs may receive "101% of bad debt" through cost report settlement
- Correct interpretation: CAH receives up to 101% of actual bad debt write-offs (not 101% × rate)
- Example: 100k bad debt → CAH should get ~101k reimbursement (if rule allows), not 65.65k

**Acceptance Criteria Checklist:**
- [ ] Verify CMS rule text (Pub. 100-04, Chapter 3 or IOM sections on CAH)
- [ ] Clarify intent: 101% reimbursement vs. 101% of bad debt writes?
- [ ] Correct formula per official CMS guidance
- [ ] Test: CAH with 100k bad debt → reimbursement matches expected (likely ~65k-101k depending on rule)
- [ ] Add regression test with known CAH bad debt example
- [ ] Update docstring to clarify CAH treatment

**Dependencies:** None (isolated calculation)

**Subtasks:**
1. [ ] Research CMS bad debt rules for CAH in IOM
2. [ ] Document official rule text and effective date
3. [ ] Understand current implementation intent vs. rule
4. [ ] Implement corrected formula
5. [ ] Create test with known CAH bad debt scenario
6. [ ] Verify result against manual calculation
7. [ ] Update docstring

**Notes:**
- CAH = Critical Access Hospital (specifically: <25 beds, Medicare Dependent, or located in HPSA)
- This rule likely depends on hospital Medicare status
- May need to check `is_cah` flag is set correctly upstream

---

### T-007: Value-Based Care MSR & Loss-Cap Tables

**Status:** ⏳ PENDING

**File Location:** `src/finance/vbc_transition.jl`

**Issue Summary:**
Minimum Savings Rate (MSR) and loss-cap parameters for Accountable Care Organizations (ACOs) may be incomplete or outdated. Need to verify MSR tiers, loss-cap percentages, and recapture rates align with current CMS ACO rules.

**Scope:**
- MSR tiers by ACO model (Track 1, Track 2, 2-sided risk)
- MSR by year (year 1 lower than year 3+)
- Loss-cap percentages by risk category (Oncology, Behavioral Health, etc.)
- Recapture rates and bonus multipliers
- ACO Beneficiary Incentive Program (ABI) bonus rules

**Acceptance Criteria Checklist:**
- [ ] Inventory current MSR values and loss-cap tables
- [ ] Document source (CMS ACO guidance + effective date) for each
- [ ] Verify MSR tiers match Track 1/Track 2/2-sided models
- [ ] Cross-check loss-caps against latest ACO guidance (2025)
- [ ] If tables incomplete, add missing risk categories
- [ ] Projection test: 5M assigned ACO → MSR and loss-cap ranges correct
- [ ] Document in-code rationale for any ACO-specific assumptions

**Dependencies:** T-001, T-002 (ratio understanding)

**Subtasks:**
1. [ ] Examine vbc_transition.jl for MSR tables/constants
2. [ ] Search for loss-cap logic and risk category mappings
3. [ ] Document current values and track their origin
4. [ ] Fetch CMS ACO shared savings guidance
5. [ ] Compare and identify gaps/errors
6. [ ] Update or add missing parameters
7. [ ] Write test with known ACO scenario
8. [ ] Validate MSR and cap calculations

**Notes:**
- ACO rules are complex and change frequently
- Different tracks have very different economics
- May have state-specific variations

---

### T-008: ICER build_ceac & Missing Constants

**Status:** ⏳ PENDING

**File Location:** `src/health_economics/ICER.jl`

**Issue Summary:**
Cost-Effectiveness Acceptability Curve (CEAC) function may be incomplete. Need to verify the `build_ceac()` function correctly captures the cost-effectiveness frontier and that all required constants (willingness-to-pay thresholds) are defined.

**Scope:**
- `build_ceac()` function logic and implementation
- Cost-effectiveness frontier calculation
- Zip operation on cost/effect/ICER arrays (ensure no data loss)
- Standard WTP thresholds ($50k, $100k, $150k per QALY)
- CEAC probability aggregation across scenarios

**Acceptance Criteria Checklist:**
- [ ] Verify `build_ceac()` produces correct 2D cost-effectiveness plane
- [ ] Confirm all cost/effect pairs zipped without data loss
- [ ] Document standard WTP thresholds or make parameterizable
- [ ] Test: 100 simulation runs → CEAC probabilities in [0, 1]
- [ ] Test: CEAC probabilities sum correctly across thresholds
- [ ] Unit test with known cost-effectiveness data
- [ ] Add any missing constant definitions (threshold values, etc.)

**Dependencies:** T-005 (reproducible sampling)

**Subtasks:**
1. [ ] Read build_ceac() function and understand implementation
2. [ ] Check for hardcoded thresholds vs. parameters
3. [ ] Review zip operation logic
4. [ ] Write unit test with known cost-effect data
5. [ ] Verify CEAC correctness mathematically
6. [ ] Document or add WTP threshold constants
7. [ ] Run projection test with multiple scenarios

**Notes:**
- CEAC is important for health economics communication
- Threshold choices affect interpretation (common: $50k-150k/QALY)
- May need to match published ICER methodologies

---

### T-009: RuralHospitalSim Package Includes

**Status:** ⏳ PENDING

**File Location:** `src/RuralHospitalSim.jl`

**Issue Summary:**
Module includes in `src/RuralHospitalSim.jl` may reference non-existent paths or unwired package directories. Need to audit all `include()` statements and ensure correct module structure.

**Problem Areas:**
- Stale `include()` statements pointing to deleted files
- Missing module declarations for packages in `packages/` directory
- Circular dependencies between submodules
- `include()` used instead of `using` for package modules

**Scope:**
- All `include()` statements in RuralHospitalSim.jl
- Verify each referenced file exists
- Check `packages/` directory structure (FinanceEngine, RuralCore, etc.)
- Confirm proper module initialization order

**Acceptance Criteria Checklist:**
- [ ] Inventory all `include()` calls in RuralHospitalSim.jl
- [ ] Verify each file exists at referenced path
- [ ] Identify which should be `using` instead of `include()`
- [ ] Convert package includes to `using` statements
- [ ] Test: `using RuralHospitalSim` loads without errors
- [ ] Run full test suite: all tests pass
- [ ] No circular dependency warnings

**Dependencies:** None (prerequisite for other tests)

**Critical for:** Module loading and initialization

**Subtasks:**
1. [ ] Examine RuralHospitalSim.jl top-level includes
2. [ ] List each include() with file path
3. [ ] Check file existence (ls or find)
4. [ ] Determine: include() or using Package?
5. [ ] Update module includes
6. [ ] Test basic loading
7. [ ] Run runtests.jl
8. [ ] Fix any load-time errors

**Notes:**
- May need to check Julia package structure (Project.toml)
- Include order matters for dependencies
- Consider running with julia --check-bounds=yes for extra validation

---

### T-010: Conversion Formula & REH Revenue Base

**Status:** ⏳ PENDING

**File Location:** `src/risk/conversion.jl:158-159`

**Issue Summary:**
REH revenue base conversion at lines 158-159 may have an incorrect formula for blending inpatient and outpatient reimbursement. REH typically use hybrid DRG+APC models, and revenue base must correctly weight the two.

**Problem:**
- REH payment models blend inpatient DRG rates with outpatient APC rates
- If revenue base doesn't properly weight inpatient vs. outpatient, reimbursement will be incorrect
- Likely overstatement for outpatient-heavy REH

**Scope:**
- Lines 158-159 in conversion.jl
- REH revenue base formula
- Payer mix split validation
- DRG vs. APC weighting

**Acceptance Criteria Checklist:**
- [ ] Examine lines 158-159 and document current formula
- [ ] Verify REH revenue base = (inpatient_vol × DRG_rate) + (outpatient_vol × APC_rate)
- [ ] If different formula, validate against CMS REH payment rules
- [ ] Test: REH with 60% inpatient, 40% outpatient → revenue reflects correct split
- [ ] Cross-check against published REH facility examples
- [ ] Unit test with known inpatient/outpatient split
- [ ] Update docstring with formula basis

**Dependencies:** T-003 (REH constants), T-004 (DRG/APC rates)

**Subtasks:**
1. [ ] Read lines 158-159 and understand current logic
2. [ ] Document the formula mathematically
3. [ ] Check for DRG vs. APC rate constants
4. [ ] Research CMS REH payment model
5. [ ] Validate formula against CMS guidance
6. [ ] Write unit test with known REH mix
7. [ ] Manual calculation verification
8. [ ] Update documentation

**Notes:**
- REH payment model is complex (hybrid of inpatient/outpatient)
- May have special rules for certain service lines (e.g., psychiatry)
- Coordinate with T-003 for REH constants used here

---

## Cross-Task Dependencies

```
Foundation:
  T-001 (Payer Formula) ←→ T-002 (Total Margin)
    ↓
Core Constants:
  T-003 (REH Constants) → T-004 (OPPS/IPPS)
    ↓
Downstream Modules:
  T-005 (MC Sampling) ← T-006, T-007, T-008
  T-009 (Module Wiring) ← All (prerequisite)
  T-010 (REH Revenue) ← T-003, T-004
```

## Rollout Plan

**Week 1:**
- T-001, T-002, T-005 (foundational fixes)

**Week 2:**
- T-003, T-004, T-009 (constants and wiring)

**Week 3:**
- T-006, T-007, T-008 (domain-specific rules)

**Week 4:**
- T-010 (integration validation)

## Known Blockers

None currently. Awaiting Haiku execution.

## Change Log

- **2026-04-27**: Initial Phase 1 plan created (10 tasks, 24 hour estimate)
