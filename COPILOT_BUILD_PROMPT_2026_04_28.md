# GitHub Copilot Build Prompt — Hospital-Economics Complete Build

**Repository:** `ruralpeds/Hospital-economics`  
**Branch:** `main`  
**Objective:** Implement all remaining open issues across the MBA gap analysis domains, Phase 3 Tier 2 optimizations, and repo hygiene items.  
**Date:** 2026-04-28  
**Stack:** Pure Julia — Genie.jl + Stipple.jl web app, `packages/FinanceEngine` + `packages/RuralCore` internal packages. No React, no Python, no Node services. Playwright for E2E only.

---

## IMPORTANT: Architecture Rules for All New Code

Every new analytics module must produce **four artifacts**:

1. **Domain function** in the appropriate `src/` family or `packages/FinanceEngine/src/`
   - Pure Julia. Typed structs in, typed result structs out. No I/O. No globals. Aqua + JET clean.
2. **Genie controller method** in `app/controllers/<relevant>Controller.jl` + route in `app/routes.jl`
   - Validates JSON payload, calls function (1), returns `JSON3.write(result)`.
3. **Stipple reactive view** in `app/views/<feature>/`
   - `@app` block with `@in` / `@out` / `@onchange`. UI via StippleUI (Quasar bindings). Charts via StipplePlotly.
4. **Tests** in `test/test_<feature>.jl` (unit, textbook-example verified) + `e2e/tests/<feature>.spec.ts` (smoke)

Output format for all reports: **HTML (Stipple-rendered) + PDF via Weave.jl or Typst.jl**. No DOCX in the runtime path.

Aqua.jl + JET.jl must pass in every `packages/*` package. Follow the `julia-enterprise-repo` skill standard.

---

## PHASE 1 — Repo Hygiene (Do First, Unblocks Everything Else)

### H-01: Fix Julia Compat Split

**Problem:** `Project.toml` declares `julia = "1.11"` but `packages/FinanceEngine/Project.toml` declares `julia = "1.12"`.

**Fix:**
```toml
# packages/FinanceEngine/Project.toml — change to:
[compat]
julia = "1.11"
```

Verify all Julia 1.12-specific syntax is absent from `packages/FinanceEngine/src/`. Run `julia --project=packages/FinanceEngine -e "using Pkg; Pkg.test()"` on Julia 1.11 to confirm.

### H-02: Wire Codecov

Add to `.github/workflows/ci.yml` after the test step:

```yaml
- name: Upload coverage to Codecov
  uses: codecov/codecov-action@v4
  with:
    token: ${{ secrets.CODECOV_TOKEN }}
    files: ./lcov.info
    fail_ci_if_error: true
```

Add to the Julia test step:
```yaml
- name: Run tests with coverage
  run: julia --project -e "
    using Pkg
    Pkg.add(\"LocalCoverage\")
    using LocalCoverage
    generate_coverage(\"RuralHospitalSim\"; run_julia_coverage=true)
  "
```

Also add a PR gate that fails if coverage drops >1pp from main.

### H-03: Move Playwright Config to `e2e/`

Move `tsconfig.json`, `package.json`, `playwright.config.ts` from repo root into `e2e/`. Update `.github/workflows/playwright.yml` to run from `e2e/`. The app itself has zero JS — only Playwright touches these files.

### H-04: Delete Stale Branches

Delete all 34 remote branches that are fully merged into `main`. They are:
- All `copilot/*` branches (24 branches)
- All `claude/*` branches (9 branches)  
- `feat/m1-cfo-foundation`, `feature/add-financeengine`

Use: `git push origin --delete <branch-name>` for each, or use the GitHub UI batch delete.

### H-05: Fix CMS Rate Constants

Update `src/utils/constants.jl` — replace all 5 TODO comments with verified FY/CY 2026 values from CMS final rules:
- REH monthly facility payment (CMS FY2026 OPPS final rule)
- OUTVAC rate
- IPPS base rate
- RHC AIR cap limit (CAA 2021 phase-in year 6)
- TEAM bundled payment reference price methodology

Also fix `src/finance/vbc_transition.jl:128` — implement year-based loss cap increases for MSSP Enhanced per CMS final rule table.

### H-06: Fix Duplicate `/api/bugreport` Route

In `app/routes.jl`, verify there is only ONE `route("/api/bugreport", ...)` registration. PR #80 may have added a duplicate. Remove the earlier one (pre-#80 version around line 806) if it conflicts.

---

## PHASE 2 — Phase 3 Tier 2 Optimizations (T-021 through T-030)

All tasks tracked in `HAIKU_BUILD_TRACKING_PHASE3.md`. Target: update that file to ✅ COMPLETE as each task lands.

### T-021: Monte Carlo Performance Optimization

**File:** `src/simulation/montecarlo.jl`

**Changes:**
- Replace upfront result array allocation with a streaming channel-based collector
- Add `MCCache` struct with optional result caching and configurable TTL
- Add `use_cache::Bool = false` and `cache_ttl::Int = 300` kwargs to `run_monte_carlo()`
- Add optional early stopping when convergence criterion is met (`std(results) / mean(results) < tol`)
- Optimize thread pool assignment: use `Threads.@threads` on outer iteration loop

**Acceptance criteria:**
- `@benchmark run_monte_carlo(model; n_iterations=50_000)` completes in <30 seconds on 8 cores
- Memory bounded to ~100MB + result size (no upfront allocation of 50k × scenario-width matrix)
- `run_monte_carlo(model; use_cache=true)` returns cached result on identical inputs
- All existing `test_monte_carlo.jl` tests still pass
- Add `test/test_monte_carlo_perf.jl` with benchmark assertions

### T-022: Hospital Projection Parallelization

**File:** `src/simulation/montecarlo.jl` (extend) or new `src/network/parallel_projection.jl`

**New function:**
```julia
function bulk_project_hospitals(
    hospitals::Vector{<:AbstractHospitalType},
    scenario::PolicyScenario;
    n_threads::Int = Threads.nthreads(),
    progress_cb::Union{Function, Nothing} = nothing
)::Vector{ProjectionResult}
```

**Changes:**
- Use `Threads.@threads` with thread-local result buffers
- Aggregate with `vcat` after all threads complete
- Call `progress_cb(completed, total)` if provided (optional callback)
- Ensure no shared mutable state — each thread operates on its own hospital + result buffer

**Acceptance criteria:**
- 8-hospital network projection is ≥4x faster than serial (wall clock) on a 4-core machine
- Results match serial execution to floating-point precision
- Thread safety verified by running 100 concurrent calls and checking result consistency
- Add `test/test_parallel_projection.jl`

### T-023: Ratio Calculation Caching

**File:** `src/finance/ratios.jl`

**Changes:**
- Add `RatioCache` struct: `Dict{UInt64, Tuple{NamedTuple, DateTime}}` keyed on `hash(financials)`
- Add `compute_all_ratios(financials; use_cache=true, cache_ttl=300)` overload
- Add `get_cache_stats()` → `(hits, misses, entries, memory_bytes)`
- Add `clear_ratio_cache!()`
- Cache invalidation: TTL-based expiry checked on each access

**Acceptance criteria:**
- Second call with identical financials returns in <1ms (cache hit)
- First call still correct — cache doesn't affect computed values
- `get_cache_stats()` returns accurate hit/miss counts
- Memory stays reasonable (<10MB for 1000 cached entries)
- Add `test/test_ratio_caching.jl`

### T-024: Extract Common Validation Patterns

**New file:** `src/utils/validation_utils.jl`

**Extract these patterns from all modules:**
- `validate_positive(x, name)` — throws `ArgumentError` if `x ≤ 0`
- `validate_range(x, lo, hi, name)` — throws if out of range
- `validate_rate(x, name)` — validates 0 ≤ x ≤ 1 (fraction) or 0 ≤ x ≤ 100 (percent); auto-detect
- `validate_date_range(start, stop, name)` — throws if start ≥ stop
- `validate_nonempty(v::Vector, name)` — throws if isempty
- `validate_nonnegative(x, name)` — throws if x < 0
- `validate_ccn(ccn::String)` — validates 6-digit CMS Certification Number format

Refactor existing validation calls in `src/finance/`, `src/simulation/`, `src/analytics/` to use these utilities. Target: ≥40% reduction in duplicated validation lines.

**Acceptance criteria:**
- `test/test_validation_utils.jl` covers all 7 functions with valid, boundary, and invalid inputs
- No regressions in existing tests (all existing test files still pass)
- `Aqua.test_all(RuralHospitalSim)` still passes

### T-025: Hospital Type Registry

**File:** `src/models/abstract.jl` (extend) + new `src/models/hospital_registry.jl`

**New types/functions:**
```julia
abstract type AbstractHospitalType end
struct CriticalAccessHospital <: AbstractHospitalType ... end
struct RuralEmergencyHospital <: AbstractHospitalType ... end
struct PPSHospital <: AbstractHospitalType ... end

hospital_types()::Vector{Type{<:AbstractHospitalType}}
create_hospital(type::Symbol, params::NamedTuple)::AbstractHospitalType
hospital_type_properties(T::Type{<:AbstractHospitalType})::NamedTuple
```

`create_hospital(:cah, params)` → `CriticalAccessHospital`; `:reh` → `RuralEmergencyHospital`; `:pps` → `PPSHospital`.

**Acceptance criteria:**
- `hospital_types()` returns all registered types
- `create_hospital` dispatches correctly for all 3 types
- `hospital_type_properties` returns bed limits, reimbursement type, Medicare designation
- Add `test/test_hospital_registry.jl`

### T-026: VBC Model Variants for Specialized ACOs

**File:** `src/finance/vbc_transition.jl`

**Add model variants:**
- `REACH_Alignment` — REACH ACO (formerly Global and Professional Direct Contracting)
- `MSSP_Enhanced_Prospective` — MSSP Enhanced Track with prospective assignment
- `KidneyCare_Choice` — CKD/ESRD-focused ACO model
- `ACO_REACH_HighNeed` — High-needs population variant

Each variant needs: `target_price_adjustment`, `quality_withhold_pct`, `shared_savings_rate`, `shared_loss_rate`, `minimum_savings_rate`, `benchmark_years`.

Fix the `TODO` at line 128 — implement year-based loss cap increases for MSSP Enhanced per the CMS final rule annual schedule.

**Acceptance criteria:**
- Each model variant computes correct shared savings/losses against a known CMS example
- Loss cap increases correctly year-over-year for MSSP Enhanced
- Add `test/test_vbc_variants.jl`

### T-027: ICER Sensitivity Analysis Framework

**File:** `src/comparative_effectiveness/SensitivityAnalysis.jl` (extend)

**New functions:**
```julia
function icer_sensitivity(
    base_params::NamedTuple,
    param_ranges::Dict{Symbol, Tuple{Float64,Float64}};
    n_steps::Int = 10
)::ICERSensitivityResult

struct ICERSensitivityResult
    icer_by_param::Dict{Symbol, Vector{Float64}}
    tornado_data::Vector{NamedTuple}  # sorted by range width descending
    threshold_crossings::Dict{Symbol, Float64}  # WTP at which ICER crosses threshold
end
```

Generate a tornado plot data structure sorted by parameter influence. Identify at which parameter value ICER crosses the standard WTP threshold ($100,000/QALY in the US).

**Acceptance criteria:**
- `icer_sensitivity` produces tornado data matching a hand-computed example
- `threshold_crossings` correctly identifies where each parameter drives ICER above/below WTP
- Add `test/test_icer_sensitivity.jl`

### T-028: Patient Cohort Analysis Enhancement

**File:** `src/patient_cohort/` (extend existing files)

**New capabilities:**
- Multi-level grouping: `group_cohort(cohort, [:drg_category, :payer, :age_band])`
- Subgroup comparison: `compare_subgroups(cohort_a, cohort_b; metrics=[:cost, :los, :readmission])`
- Temporal filtering: `filter_cohort_by_date(cohort, start_date, end_date)`
- Outlier trimming: `trim_outliers(cohort; method=:iqr, factor=1.5)`
- Summary statistics with CIs: `cohort_summary(cohort; ci_level=0.95)`

**Acceptance criteria:**
- Multi-level grouping produces correct aggregates (verify against manual calculation)
- Subgroup comparison returns p-values for difference in means (using `HypothesisTests.jl`)
- All new functions covered in `test/test_cohort_enhancement.jl`

### T-029: REH-Specific Analytics Module

**New file:** `src/analysis/reh_analytics.jl`

**Consolidate scattered REH logic into one module:**
- `reh_facility_payment(year, months_in_year)` — monthly facility payment × proration
- `reh_outpatient_addon_pct()` → 5% per CMS spec
- `reh_volume_viability(visits_per_year, revenue_per_visit, fixed_cost)::REHViabilityResult`
- `reh_vs_cah_comparison(cah::CriticalAccessHospital, reh_params::NamedTuple)::ConversionAnalysis`
- `reh_quality_program_impact(quality_score::Float64)::Float64` — payment adjustment

**Acceptance criteria:**
- `reh_facility_payment` matches CMS FY2026 REH payment example to within $1
- `reh_vs_cah_comparison` gives same result as the existing `risk/conversion.jl` for the same inputs (cross-validation)
- Add `test/test_reh_analytics.jl`

### T-030: Reporting & Export Framework

**New file:** `src/visualization/export_framework.jl`

**Unified export API:**
```julia
abstract type ReportFormat end
struct HTMLReport <: ReportFormat end
struct PDFReport <: ReportFormat end
struct CSVExport <: ReportFormat end
struct XLSXExport <: ReportFormat end

function export_analysis(
    result::Any,
    format::ReportFormat;
    title::String,
    metadata::Dict = Dict()
)::String  # returns file path
```

Dispatch on result type + format. All PDF via `Weave.jl` (Markdown → LaTeX → PDF). All XLSX via `XLSX.jl`. All CSV via `CSV.jl`. Templates stored in `src/visualization/templates/`.

**Acceptance criteria:**
- `export_analysis(icer_result, PDFReport(); title="ICER Analysis")` produces a readable PDF
- `export_analysis(ratio_result, XLSXExport(); title="Ratios")` produces valid XLSX with correct values
- Add `test/test_export_framework.jl`

---

## PHASE 3 — MBA Domain A: Corporate Finance & Valuation

### A-04: Nonprofit WACC + Covenant Calculator

**File:** `packages/FinanceEngine/src/capital_structure.jl` (extend)

**Add functions:**
```julia
function nonprofit_wacc(
    tax_exempt_bond_rate::Float64,
    equity_required_return::Float64,
    debt_to_total_capitalization::Float64,
    noncash_working_capital::Float64 = 0.0
)::Float64

function mads_headroom(
    projected_cash_flow::Vector{Float64},
    maximum_annual_debt_service::Float64,
    covenant_threshold::Float64 = 1.20
)::MADSResult

function synthetic_rating(
    dscr::Float64,
    days_cash::Float64,
    operating_margin::Float64,
    debt_to_capitalization::Float64
)::String  # "AAA", "AA", "A", "BBB", "BB", "B", "CCC"
```

The synthetic rating model should use a simple rule-based scoring matrix calibrated to Moody's rural hospital rating methodology (available in public rating reports).

**Acceptance criteria:**
- `nonprofit_wacc` on a known example matches hand computation within 0.01 pp
- `mads_headroom` flags covenant breach correctly when DSCR < threshold
- `synthetic_rating` returns "BBB" or below for a hospital with DSCR < 1.5 and days_cash < 60
- Add `test/test_nonprofit_wacc.jl`

### A-05: IRR, MIRR, Profitability Index, EAC

**File:** `packages/FinanceEngine/src/financial.jl` (extend)

**Add functions:**
```julia
function irr(cash_flows::Vector{Float64}; tol=1e-8, max_iter=1000)::Float64
function mirr(cash_flows::Vector{Float64}, finance_rate::Float64, reinvest_rate::Float64)::Float64
function profitability_index(initial_investment::Float64, pv_future_flows::Float64)::Float64
function equivalent_annual_cost(npv::Float64, r::Float64, n::Int)::Float64
```

IRR via Newton-Raphson with fallback bisection. MIRR per standard formula. PI = PV/|CF₀|.

**Acceptance criteria:**
- Standard textbook examples match to 4 decimal places
- `irr` handles non-conventional cash flows (multiple sign changes) with a warning
- Add `test/test_capital_budgeting.jl`

### A-06: Real-Options Valuation on Service Lines

**New file:** `src/finance/real_options.jl`

**Implement three methods:**

1. **Black-Scholes-Merton (continuous):**
```julia
function bsm_option_value(
    S::Float64,   # current value of underlying (service line NPV)
    K::Float64,   # exercise price (investment or exit cost)
    r::Float64,   # risk-free rate
    sigma::Float64, # volatility of underlying
    T::Float64,   # time to expiry (years)
    option_type::Symbol  # :call (option to expand) or :put (option to abandon)
)::BSMResult
```

2. **Binomial lattice (discrete):**
```julia
function binomial_option(S, K, r, sigma, T; n_steps=50, option_type=:american)::BinomialResult
```

3. **Longstaff-Schwartz LSM (early-exercise):**
```julia
function lsm_option(paths::Matrix{Float64}, K::Float64, r::Float64, dt::Float64)::LSMResult
```

**Clinical use case constructors:**
```julia
function option_to_expand_ob(hospital::AbstractHospitalType, ...)::BSMResult
function option_to_abandon_inpatient(hospital::AbstractHospitalType, ...)::BSMResult
function option_to_convert_cah_to_reh(hospital::CriticalAccessHospital, ...)::BinomialResult
```

**Acceptance criteria:**
- BSM closed-form matches a standard textbook European call to within $0.01
- Binomial lattice converges to BSM as n_steps → ∞ (within 1% at n=200)
- `option_to_convert_cah_to_reh` value exceeds `npv` of stay-as-CAH under a stress scenario
- Add `test/test_real_options.jl`

### A-09: Treasury & Liquidity Stress Test

**New file:** `src/finance/treasury.jl`

**Core struct:**
```julia
@kwdef struct TreasuryModel
    ar_days::Float64           # average days in AR
    ap_days::Float64           # average days in AP
    payroll_cycle_days::Int    # 14 (biweekly) or 7 (weekly)
    monthly_revenue::Float64
    monthly_expenses::Float64
    line_of_credit_limit::Float64
    beginning_cash::Float64
end
```

**Functions:**
```julia
function thirteen_week_cash_flow(model::TreasuryModel)::Vector{WeeklyCashFlow}

function medicare_delay_stress(
    model::TreasuryModel,
    delay_days::Int  # 30, 60, or 90
)::TreasuryStressResult

function days_cash_projection(
    model::TreasuryModel,
    n_months::Int = 13
)::Vector{Float64}

function loc_headroom(model::TreasuryModel)::Float64
```

**Acceptance criteria:**
- 13-week forecast cash balances correctly reconcile to beginning + inflows - outflows
- Medicare 90-day delay scenario correctly shifts $AR receipt$ forward
- LOC headroom = limit - maximum negative cash balance in the forecast
- Add `test/test_treasury.jl`

---

## PHASE 4 — MBA Domain C: Operational Analytics

### C-01: Data Envelopment Analysis

**New file:** `src/analytics/dea.jl`

**Implement both DEA-CCR (constant returns to scale) and DEA-BCC (variable returns to scale):**

```julia
@kwdef struct DEAModel
    inputs::Matrix{Float64}   # n_DMU × n_inputs
    outputs::Matrix{Float64}  # n_DMU × n_outputs
    dmu_names::Vector{String}
    input_names::Vector{String}
    output_names::Vector{String}
end

function dea_ccr(model::DEAModel; orientation=:input)::DEAResult
function dea_bcc(model::DEAModel; orientation=:input)::DEAResult

@kwdef struct DEAResult
    efficiency_scores::Vector{Float64}  # 0–1
    reference_sets::Vector{Vector{Int}} # lambda peers for each DMU
    slacks::Matrix{Float64}
    is_efficient::Vector{Bool}
    model_type::Symbol  # :ccr or :bcc
    orientation::Symbol # :input or :output
end
```

Solve each LP using `JuMP` with `HiGHS` (already in Project.toml). One LP per DMU.

**Rural-hospital use case:**
- Inputs: total FTEs, total beds, total capital (net PPE)
- Outputs: total discharges, annual ED visits, quality composite score

**Acceptance criteria:**
- Replicate the Färe, Grosskopf, Lovell (1994) textbook example to 3 decimal places
- Efficient DMUs have score = 1.0; inefficient < 1.0
- Reference sets non-empty for all inefficient DMUs
- Add `test/test_dea.jl`

### C-03: Revenue Cycle Variance Analysis

**New file:** `src/finance/variance_analysis.jl`

**Price/volume/mix bridge:**
```julia
function revenue_variance_bridge(
    prior::PeriodRevenue,
    current::PeriodRevenue
)::VarianceBridge

@kwdef struct PeriodRevenue
    volume::Float64         # cases or encounters
    case_mix_index::Float64
    net_revenue_per_cmi_unit::Float64
end

@kwdef struct VarianceBridge
    total_delta::Float64
    price_variance::Float64   # rate effect
    volume_variance::Float64  # volume effect
    mix_variance::Float64     # case mix effect
    check_sum::Bool           # price + volume + mix ≈ total_delta
end
```

**Acceptance criteria:**
- `price_variance + volume_variance + mix_variance ≈ total_delta` to within $0.01 (no unexplained residual)
- Matches a published AHA/HFMA revenue bridge example
- Add `test/test_variance_analysis.jl`

### C-07: Peer Benchmarking Engine

**New file:** `src/analytics/peer_benchmarking.jl`

```julia
function peer_benchmark(
    hospital::AbstractHospitalType,
    peer_set::Vector{AbstractHospitalType};
    metrics::Vector{Symbol} = [:operating_margin, :days_cash, :dscr, :nurse_hppd, :or_utilization]
)::PeerBenchmarkResult

@kwdef struct PeerBenchmarkResult
    hospital_values::Dict{Symbol, Float64}
    peer_percentiles::Dict{Symbol, Vector{Float64}}  # [10th, 25th, 50th, 75th, 90th]
    hospital_percentile_rank::Dict{Symbol, Float64}
    flex_monitoring_thresholds::Dict{Symbol, Float64}  # from CAH Flex Monitoring program
end
```

Load Flex Monitoring benchmark data from `data/flex_monitoring_benchmarks.csv` (create this file with FY2024 CAH benchmark data from the published Flex Monitoring report).

**Acceptance criteria:**
- `peer_benchmark` returns correct percentile ranks when compared against a known peer set
- Flex Monitoring thresholds load correctly from CSV
- Hospital below 25th percentile on any P0 metric is flagged
- Add `test/test_peer_benchmarking.jl`

---

## PHASE 5 — MBA Domain D: Risk & ML

### D-04: Copula-Correlated Monte Carlo

**File:** `src/simulation/montecarlo.jl` (extend)

**Add:**
```julia
abstract type CopulaSpec end
struct GaussianCopula <: CopulaSpec
    correlation_matrix::Matrix{Float64}
end
struct TCopula <: CopulaSpec
    correlation_matrix::Matrix{Float64}
    degrees_of_freedom::Float64
end

function run_monte_carlo_correlated(
    model,
    copula::CopulaSpec;
    n_iterations::Int = 10_000,
    marginals::Vector{<:Distribution}  # from Distributions.jl
)::MonteCarloResult
```

Algorithm: sample from copula (Cholesky decomposition of Σ) → apply probability-integral transform to get marginals → evaluate model.

**Acceptance criteria:**
- Recovered sample correlation matrix within 0.02 of specified Σ at n=10,000
- Results with identity Σ match independent-draws MC to within Monte Carlo error
- Add `test/test_copula_mc.jl`

### D-05: VaR and CVaR

**New file:** `src/risk/var_cvar.jl`

```julia
function var_cvar(
    returns::Vector{Float64};
    confidence::Float64 = 0.95,
    method::Symbol = :historical  # :historical, :parametric, :monte_carlo
)::VaRCVaRResult

@kwdef struct VaRCVaRResult
    var::Float64       # Value at Risk
    cvar::Float64      # Conditional Value at Risk (Expected Shortfall)
    confidence::Float64
    method::Symbol
    n_observations::Int
end
```

All three methods must return consistent results within 5% for a normal distribution at 95% confidence.

**Acceptance criteria:**
- Parametric VaR on N(0,1) at 95% = 1.645 σ ± 0.001
- CVaR > VaR always (by definition)
- Add `test/test_var_cvar.jl`

---

## PHASE 6 — MBA Domain E: Reimbursement & Policy

### E-01: CAH Outlier Payments + TEFRA

**File:** `src/finance/reimbursement.jl` (extend)

**Add:**
```julia
function cah_outlier_payment(
    total_covered_charges::Float64,
    fixed_loss_threshold::Float64,  # from CMS OPPS final rule
    cost_to_charge_ratio::Float64,
    medicare_share_of_outlier::Float64 = 0.80
)::Float64

function tefra_target_rate(
    base_year_cost_per_case::Float64,
    update_factor::Float64,
    dsh_adjustment::Float64 = 0.0
)::Float64

function cah_worksheet_e1(
    inpatient_costs::Float64,
    total_charges::Float64,
    medicare_charges::Float64,
    outlier_threshold_ratio::Float64
)::WorksheetE1Result  # line-by-line replica of CMS Worksheet E-1
```

**Acceptance criteria:**
- `cah_worksheet_e1` replicates a published CMS CAH cost report example within 0.5%
- `cah_outlier_payment` = 0 when charges below fixed-loss threshold
- Add `test/test_cah_reimbursement.jl`

### E-03: Medicare Advantage v28 HCC Risk Model

**New file:** `src/finance/medicare_advantage.jl`

```julia
@kwdef struct MedicareAdvantageModel
    hcc_codes::Vector{String}         # ICD-10 → HCC mapped codes
    normalization_factor::Float64 = 1.045  # CMS FY2026
    age_sex_coefficient::Float64
    disease_interaction_coefficients::Vector{Float64}
    county_fips::String               # for MA payment rate lookup
end

function ma_risk_score(model::MedicareAdvantageModel)::Float64
function ma_benchmark_rate(county_fips::String, year::Int)::Float64
function ma_rural_passthrough_payment(hospital::AbstractHospitalType, year::Int)::Float64
function ma_vs_traditional_medicare(hospital::AbstractHospitalType)::MAComparisonResult
```

Load HCC v28 coefficients from `data/hcc_v28_coefficients.csv` (create from CMS public HCC v28 model file).

**Acceptance criteria:**
- Risk score for a known CMS example patient matches CMS published example
- `ma_vs_traditional_medicare` shows MA share approaching 50% for the average rural hospital
- Add `test/test_medicare_advantage.jl`

### E-06: MIPS/VBP/HRRP/HACRP Scoring

**New file:** `src/policy/mips_vbp_hrrp.jl`

```julia
# MIPS — Merit-Based Incentive Payment System
function mips_payment_adjustment(
    quality_score::Float64,        # 0–100
    pi_score::Float64,             # Promoting Interoperability
    ia_score::Float64,             # Improvement Activities
    cost_score::Float64,           # Cost category
    year::Int = 2026
)::Float64  # payment adjustment as decimal (e.g., 0.09 = +9%)

# Hospital VBP — Value-Based Purchasing
function hvbp_adjustment(
    clinical_outcomes_score::Float64,
    person_community_engagement::Float64,
    safety_score::Float64,
    efficiency_cost_reduction::Float64,
    year::Int = 2026
)::Float64

# HRRP — Hospital Readmissions Reduction Program
function hrrp_adjustment(
    excess_readmission_ratios::Dict{String, Float64},  # condition → ERR
    year::Int = 2026
)::Float64  # payment reduction 0–0.03 (max 3%)

# HACRP — Hospital-Acquired Condition Reduction Program
function hacrp_adjustment(
    hac_score::Float64,  # total HAC score (1–10 scale)
    year::Int = 2026
)::Float64  # 0 or -0.01 (1% reduction for worst quartile)
```

Load CMS threshold tables from `data/cms_quality_thresholds_2026.csv`.

**Acceptance criteria:**
- Each function reproduces the CMS calculation methodology spec exactly
- A hospital in the worst HRRP quartile receives ≥1% penalty and ≤3% penalty
- Add `test/test_cms_quality_programs.jl`

---

## PHASE 7 — MBA Domain F: Reporting

### F-01: Board-Ready PDF Packet Generator

**New file:** `src/visualization/board_packet.jl`

**12-section board packet:**
1. Cover page (hospital name, fiscal year, date prepared)
2. Executive summary (3-bullet financial position)
3. Balanced scorecard (4 perspectives, RAG status)
4. Financial statements (IS/BS/CF from `three_statement.jl`)
5. Payer mix walk (prior year → current year bridge)
6. Scenario analysis (3 scenarios, key metrics)
7. Risk dashboard (closure risk, VaR, DSCR headroom)
8. Capital plan (capital scoring top 5 projects)
9. Productivity benchmarking (peer percentile bands)
10. Quality program impact (VBP/HRRP/HACRP adjustments)
11. Community impact summary
12. Appendix (data sources, methodology)

**Rendering chain:** Julia structs → Weave.jl Markdown template (`src/visualization/templates/board_packet.jmd`) → LaTeX → PDF. Charts via `Plots.savefig(p, "fig.pdf")` inserted into LaTeX.

```julia
function generate_board_packet(
    hospital::AbstractHospitalType,
    fiscal_year::Int,
    output_path::String = tempdir()
)::String  # returns path to PDF
```

**Acceptance criteria:**
- Produces a valid, readable PDF with all 12 sections populated
- Same inputs produce identical output (deterministic — mask timestamps for reproducibility test)
- PDF passes WCAG 2.1 level A for accessibility (use `pdfinfo` or `pdftext` to verify searchable text)
- Add `test/test_board_packet.jl`

### F-06: HCRIS Auto-Importer CLI

**New file:** `scripts/import_hcris.jl`

```julia
#!/usr/bin/env julia
# Usage: julia scripts/import_hcris.jl --ccn 011300 --year 2024 [--output db|json|csv]

using ArgParse
using ...  # RuralHospitalSim, FinanceEngine

function main()
    # Parse --ccn, --year, --output
    # Download HCRIS cost report from CMS (https://www.cms.gov/Research-Statistics-Data-and-Systems/Downloadable-Public-Use-Files/Cost-Reports/)
    # Parse Worksheet S-3 (beds), G-2 (income), G-3 (balance sheet), A-series (cost allocation)
    # Populate AnnualFinancials struct
    # Store in SearchLight DB (if --output db) or write JSON/CSV
    # Print summary to stdout
end
```

**Acceptance criteria:**
- `julia scripts/import_hcris.jl --ccn 011300 --year 2024` runs without error and populates an `AnnualFinancials` struct
- Key fields (operating_revenue, operating_expenses, total_assets) within 2% of published HCRIS data
- Add `test/test_hcris_cli.jl` using a fixture cost report from `test/fixtures/sample_hcris_2024.csv`

---

## PHASE 8 — Stipple Views for All New Modules

For each new analytics module above, create the corresponding Stipple reactive view. Follow the template in `MBA_GAP_ANALYSIS_2026.md §7.2`. Views live in `app/views/<feature>/`, with model in `<Feature>Model.jl` and layout in `<feature>.jl`. Routes in `app/routes.jl`.

**Priority order for views:**
1. F-03: CFO 1-pager dashboard enhancements (sparklines + RAG) — extend `app/views/dashboard/`
2. C-01: DEA efficiency — `app/views/dea/`
3. E-06: MIPS/VBP/HRRP calculator — `app/views/quality_programs/`
4. A-06: Real-options visualizer — `app/views/real_options/`
5. F-01: Board packet generator UI — `app/views/board_packet/`
6. D-04: Correlated MC runner — extend `app/views/simulation_runner/`

---

## PHASE 9 — Pluto.jl Reference Notebooks

Create in `notebooks/`:
- `01_three_statement_model.jl` — drive A-01 from a CCN → 5-yr projection
- `02_dupont_and_distress.jl` — A-02, A-03 walkthrough
- `03_cah_to_reh_real_options.jl` — A-06, E-02 decision under uncertainty
- `04_service_line_portfolio.jl` — B-03 efficient frontier (when implemented)
- `05_dea_efficiency.jl` — C-01 with a peer set
- `06_mips_vbp_hrrp_impact.jl` — E-06 payment-program impact

Each notebook: self-contained, fully reactive, executable on the current `packages/*` ecosystem.

---

## PHASE 10 — Package Decomposition (Final Step)

After all analytics modules are implemented and tested, split the umbrella per `MBA_GAP_ANALYSIS_2026.md §7.5`:

| New Package | Path | Contents |
|---|---|---|
| `RuralReimbursement.jl` | `packages/RuralReimbursement/` | All Domain E modules: `reimbursement.jl`, `medicare_advantage.jl`, `mips_vbp_hrrp.jl`, `team_bundled.jl`, `rhc_optimization.jl`, `program340b.jl`, `medicaid_supplemental.jl`, `nsa_idr.jl` |
| `RuralAnalytics.jl` | `packages/RuralAnalytics/` | `dea.jl`, `sfa.jl`, `peer_benchmarking.jl`, `var_cvar.jl`, `stress_test.jl`, `variance_analysis.jl`, `toc_bottleneck.jl` + `AdvancedAnalytics.jl` from `src/analytics/` |
| `RuralStrategy.jl` | `packages/RuralStrategy/` | `balanced_scorecard.jl`, `real_options.jl`, `ma_valuation.jl`, `lbo_model.jl`, `service_line_portfolio.jl`, `strategic_planning.jl` |
| `RuralReports.jl` | `packages/RuralReports/` | `board_packet.jl`, `rating_memo.jl`, `tornado.jl`, `export_framework.jl` + Weave/Typst templates |

Each package: standalone `Project.toml`, own `test/runtests.jl`, Aqua + JET gates, `julia = "1.11"` compat.

---

## Completion Criteria (Full v2.0 Release)

- [ ] All H-01 through H-06 hygiene items resolved
- [ ] All T-021 through T-030 tasks ✅ COMPLETE in `HAIKU_BUILD_TRACKING_PHASE3.md`
- [ ] All P0 MBA gaps implemented, tested, and wired into Stipple views
- [ ] All P1 MBA gaps implemented and tested
- [ ] Codecov badge on README showing ≥80% coverage
- [ ] 0 branches older than 7 days (branch cleanup enforced by hygiene CI)
- [ ] All 6 Pluto.jl notebooks execute without error
- [ ] Package decomposition complete (5 packages: `RuralCore`, `FinanceEngine`, `RuralReimbursement`, `RuralAnalytics`, `RuralReports`)
- [ ] `julia scripts/import_hcris.jl --ccn 011300 --year 2024` runs end-to-end
- [ ] Board-ready PDF produced for a sample CAH (include in `examples/sample_board_packet.pdf`)

---

*Source: Claude Sonnet 4.6 code inspection of ruralpeds/Hospital-economics, all branches, 2026-04-28*  
*See `ISSUE_STATUS_2026_04_28.md` for the companion issue status report*
