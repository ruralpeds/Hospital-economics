# HAIKU Build Plan: Rural Healthcare Audit Fixes

**Phase 1: Tier 0 Critical Fixes (Atomic Units)**

---

## T-001: Payer Negotiation Rate Formula Correction

**File:** `src/analysis/payer_negotiation.jl:219`

**Issue:** The required rate formula incorrectly applies margin to cost-to-charge ratio (CCR).

**Current Code:**
```julia
required_rate = ccr * (1.0 + target_margin)
```

**Problem:**
- Formula treats CCR (costs/charges) as a base cost, then multiplies by (1+margin)
- Should be: `required_rate = ccr / (1.0 - target_margin)` OR clarify that this computes blended cost% including margin
- Medical economics standard: rate = CCR × (1 + desired_margin) applies when CCR is operating costs as % of revenue, not charges

**Acceptance Criteria:**
- [ ] Formula validated against healthcare financial models
- [ ] Docstring clarifies whether CCR or revenue-basis calculation
- [ ] Unit tests confirm margin targets (2%, 5%, 10%) produce correct required rates
- [ ] Verify against CAH example: 0.85 CCR → should require ~0.88-0.95 rate for 3% margin

---

## T-002: Total Margin Calculation Fix

**File:** `src/finance/ratios.jl:25-29`

**Issue:** Missing non-operating expenses in net income calculation.

**Current Code:**
```julia
function total_margin(financials::AnnualFinancials)::Float64
    financials.total_revenue == 0.0 && return 0.0
    net_income = financials.total_revenue - financials.total_operating_expenses
    return net_income / financials.total_revenue
end
```

**Problem:**
- Does NOT subtract non-operating expenses (interest, taxes, other)
- Net income should be: total_revenue - total_operating_expenses - (other_expenses)
- Current calculation overstates margin by including non-operating items improperly

**Acceptance Criteria:**
- [ ] Verify `AnnualFinancials` struct contains: `total_revenue`, `total_operating_expenses`, `non_operating_expenses`, and/or separate interest/tax fields
- [ ] Correct formula to: `net_income = financials.total_revenue - financials.total_operating_expenses - financials.non_operating_expenses`
- [ ] Test against known CAH: 10M revenue, 9M operating costs, 0.5M other expenses → should be 5% margin not 10%
- [ ] Validate Flex Monitoring Team benchmarking standard for total_margin definition

---

## T-003: REH Facility-Payment Constant Reconciliation

**File:** REH-related constants across multiple files

**Issue:** Rural Eligible Hospital (REH) facility payment multipliers may be outdated or inconsistent.

**Locations to audit:**
- `src/finance/reimbursement.jl` - REH payment caps/adjustments
- `src/simulation/constants.jl` (if exists) - REH base rates
- `packages/FinanceEngine/src/constants.jl` - any REH parameters

**Scope:**
- Reconcile REH facility payment base amounts (DRG base, outlier threshold)
- Cross-check 2024-2025 CMS Inpatient Prospective Payment System (IPPS) rule updates
- Verify REH adjustment factor in blended payment calculations

**Acceptance Criteria:**
- [ ] Document current REH constants and their CMS source
- [ ] Validate REH IPPS base payment and adjustment factor match official CMS rates
- [ ] If differences > 0.5%, update and add comment citing CMS rule effective date
- [ ] Run projection tests: confirm REH reimbursement falls within expected range

---

## T-004: OPPS/IPPS/Outlier Constants Refresh

**File:** Multiple reimbursement calculation files

**Issue:** Outpatient Prospective Payment System (OPPS), Inpatient Prospective Payment System (IPPS), and outlier thresholds may be outdated.

**Scope:**
- OPPS conversion factors (APC relative weights)
- IPPS DRG base payment rates and relative weights
- Outlier thresholds (cost > X% of DRG payment triggers outlier payment)
- Cost-to-charge ratio caps/floors

**Locations:**
- `src/finance/reimbursement.jl` - primary payment logic
- `packages/FinanceEngine/src/` - any constants modules

**Acceptance Criteria:**
- [ ] Identify files containing hardcoded OPPS, IPPS, or outlier constants
- [ ] Cross-check against CMS 2025 rate update notices
- [ ] Document source/effective date for each constant (comment in code)
- [ ] Update any rates that differ from CMS by >1%
- [ ] Validate with 2-3 example claims: outlier triggering, payment calculation matches CMS schedule

---

## T-005: Monte Carlo Sample-Capture Consistency

**File:** `src/simulation/montecarlo.jl:128-157`

**Issue:** Parameter sampling inconsistent between `_sample_deterministic_params` and `_collect_sampled_params`.

**Current Code:**
- `_sample_deterministic_params` (lines 128-138): samples 7 params, includes `reimbursement_adjustment`
- `_collect_sampled_params` (lines 146-157): samples 8 params, missing `reimbursement_adjustment`, includes extra params

**Problem:**
- Deterministic run samples one set of values but collector doesn't capture all sampled values
- Leads to loss of audit trail; can't reproduce MC iteration state
- Inconsistent RNG calls cause seed-based reproducibility to fail

**Acceptance Criteria:**
- [ ] Align both functions to sample identical parameter set
- [ ] Add `reimbursement_adjustment` to `_collect_sampled_params` OR remove from deterministic
- [ ] Ensure both functions call `sample()` in same order for reproducibility
- [ ] Test: seed RNG, run both functions, verify sampled dicts match parameter keys
- [ ] Add unit test: run MC with fixed seed 2x, confirm identical results

---

## T-006: CAH Bad Debt Reimbursement Rate

**File:** `src/finance/reimbursement.jl:480`

**Issue:** CAH 101% bad debt multiplier application appears incorrect.

**Current Code:**
```julia
effective_rate = is_cah ? min(reimbursement_rate * 1.01, 1.0) : reimbursement_rate
```

**Problem:**
- Multiplies reimbursement_rate by 1.01 (e.g., 0.65 → 0.6565)
- Comment says "101% of bad debt through cost report settlement" but multiplier placement is wrong
- Correct interpretation: CAH receives up to 101% of actual bad debt, not 101% × reimbursement_rate
- Should be: `effective_rate = is_cah ? min(1.01, 1.0) : reimbursement_rate` OR distinct bad debt cap

**Acceptance Criteria:**
- [ ] Verify CMS rule text on CAH bad debt settlement (Pub. 100-04, Chapter 3)
- [ ] Clarify: does CAH get 101% reimbursement or 101% of bad debt write-offs?
- [ ] Correct formula per CMS guidance
- [ ] Test: CAH with 100k bad debt → expect 101k reimbursement (if rule allows), not current calculation
- [ ] Add regression test with known CAH example

---

## T-007: Value-Based Care MSR & Loss-Cap Tables

**File:** `src/finance/vbc_transition.jl`

**Issue:** Minimum Savings Rate (MSR) and loss-cap parameters may be incomplete or outdated.

**Scope:**
- Verify MSR tiers (small vs. large ACO, year 1 vs. shared savings maturity)
- Loss-cap percentages by risk category (Oncology, Behavioral Health, etc.)
- Recapture rates and bonus multipliers

**Locations:**
- Check for hardcoded MSR arrays/dicts
- Check for loss-cap lookup tables
- Verify alignment with CMS ACO Beneficiary Incentive Program (ABI) rules

**Acceptance Criteria:**
- [ ] Document current MSR and loss-cap values with CMS source
- [ ] Verify MSR tiers match Track 1/Track 2/2-sided risk models
- [ ] Cross-check loss-caps against ACO guidance effective 2025
- [ ] If tables incomplete, add missing risk categories
- [ ] Test: ACO with 5M assigned population → MSR and cap ranges correct

---

## T-008: ICER build_ceac & Missing Constants

**File:** `src/health_economics/ICER.jl`

**Issue:** Cost-Effectiveness Acceptability Curve (CEAC) function incomplete or missing constants.

**Scope:**
- Verify `build_ceac()` function captures cost-effectiveness frontier correctly
- Check for missing thresholds (willingness-to-pay, lambda values)
- Ensure zip operation on ICER/cost/effect arrays doesn't drop values

**Locations:**
- `src/health_economics/ICER.jl` - primary function
- Check if CEAC thresholds hardcoded or parameterized

**Acceptance Criteria:**
- [ ] Verify `build_ceac()` produces correct 2D cost-effectiveness plane
- [ ] Ensure all cost/effect pairs zipped without loss
- [ ] Document standard thresholds (e.g., $50k, $100k, $150k per QALY)
- [ ] Test: 100 simulations → CEAC probabilities fall in [0, 1] and sum to 1 across threshold
- [ ] Add missing WTP threshold constants or make parameterizable

---

## T-009: RuralHospitalSim Package Includes

**File:** `src/RuralHospitalSim.jl`

**Issue:** Module includes may reference unwired or missing package directories.

**Problem:**
- Stale `include()` statements pointing to non-existent paths
- Missing module declarations for packages in `packages/` directory
- Circular dependency or missing submodule initializations

**Scope:**
- Audit all `include()` statements in `src/RuralHospitalSim.jl`
- Verify referenced files exist
- Check `packages/` structure: FinanceEngine, RuralCore, etc. should be `using` not `include()`

**Acceptance Criteria:**
- [ ] Inventory all `include()` calls in RuralHospitalSim.jl
- [ ] Verify each file exists and path is correct
- [ ] Convert package-level includes to `using` statements
- [ ] Test: `using RuralHospitalSim` loads without errors
- [ ] Run test suite: all tests in `test/runtests.jl` pass

---

## T-010: Conversion Formula & REH Revenue Base

**File:** `src/risk/conversion.jl:158-159`

**Issue:** REH revenue base conversion may have incorrect formula or constant.

**Current Code (approx lines 158-159):**
- Check actual conversion logic for REH inpatient-to-outpatient or similar base shift

**Problem:**
- REH payment models blend inpatient DRG and outpatient APC rates
- Base revenue calculation may not properly weight inpatient vs. outpatient mix
- Could lead to reimbursement overstatement for outpatient-heavy REH

**Scope:**
- REH revenue base formula at lines 158-159
- Check if uses correct payer mix split
- Verify DRG vs. APC weighting

**Acceptance Criteria:**
- [ ] Examine lines 158-159 and document current formula
- [ ] Verify REH revenue base = (inpatient_vol × DRG_rate) + (outpatient_vol × APC_rate)
- [ ] If different structure, validate against CMS REH payment model
- [ ] Test: REH 60% inpatient, 40% outpatient → revenue base reflects correct split
- [ ] Cross-check against known REH facilities

---

## Execution Plan

**Sequential Execution Order:**
1. **T-001 & T-002** (Finance & Negotiation): foundational formulas, low risk
2. **T-003 & T-004** (Constants): audit existing values, update with CMS sources
3. **T-005** (Sampling): ensure reproducibility for all downstream MC runs
4. **T-006 & T-010** (CAH & REH Specifics): facility-type rules
5. **T-007 & T-008** (VBC & ICER): advanced analytics integrity
6. **T-009** (Includes): final module wiring validation

**Estimated Effort:**
- T-001: 2h (formula review, test design, fix)
- T-002: 2h (field audit, calculation correction, test)
- T-003: 3h (constant inventory, CMS source cross-check, update)
- T-004: 4h (broader constant audit, rate comparison, documentation)
- T-005: 2h (alignment, reproducibility test)
- T-006: 2h (rule clarification, formula fix, test)
- T-007: 3h (table inventory, rule validation, update)
- T-008: 2h (function audit, threshold documentation, test)
- T-009: 2h (include audit, path verification, module wiring)
- T-010: 2h (formula documentation, REH model validation, test)

**Total: ~24 hours across 10 atomic tasks**

---

## Phase 1 Definition

Phase 1 is complete when all T-001 through T-010 tasks are:
- Audited (issue documented with code location)
- Fixed (code changes committed)
- Tested (acceptance criteria verified, regression tests added)
- Documented (source/rationale for change recorded in comments)
