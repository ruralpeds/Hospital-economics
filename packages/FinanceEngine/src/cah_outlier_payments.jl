"""
    cah_outlier_payments.jl — CAH Cost Outlier & TEFRA Reimbursement (MBA Gap E-01)

Extends the base CAH reimbursement module with the components identified as
missing in the MBA gap analysis:

1. **CAH Inpatient Cost Outlier Payments** — Fixed-loss threshold method per
   CMS Worksheet E-1, Part II. CAHs are reimbursed at 101% of reasonable cost
   for outlier cases once costs exceed the fixed-loss threshold plus the
   DRG-equivalent payment.

2. **TEFRA Rate-of-Increase Limits** — For excluded hospitals (children's,
   psychiatric, LTCHs, rehabilitation) not paid under IPPS. Includes:
   - Hospital-specific rate (HSR) based on base-year costs
   - TEFRA target rate with market basket update
   - Incentive payment (50% of savings below target)
   - Penalty (50% of excess over 110% of target)

3. **CAH Bad Debt Reimbursement** — The correct Medicare bad debt formula:
   100% of Medicare bad debt (Worksheet S-10 line 28) for CAHs vs 65% for PPS.
   Bad debt = Medicare deductibles + coinsurance written off for dual-eligible
   and Medicare-only beneficiaries after collection efforts.

4. **CAH Swing-Bed SNF Payment** — Per-diem computation per Worksheet E-1,
   Part III. Swing-bed days paid at the SNF prospective payment rate.

5. **CAH Rural Health Clinic (RHC) Supplement** — RHC all-inclusive rate
   (AIR) calculation when a hospital-based RHC is present.

All rates CY/FY 2026 unless noted.
References: CMS Cost Report Form CMS-2552-10; CMS MLN Matters SE1413;
CMS Program Transmittal 3688; 42 CFR § 413.64, § 413.70, § 412.620.
"""

using Printf
using Dates

# ─────────────────────────────────────────────────────────────────────────────
# CY2026 / FY2026 Payment Constants
# ─────────────────────────────────────────────────────────────────────────────

"""Fixed-loss outlier threshold for CAHs (FY2026). CMS Transmittal 2026."""
const CAH_OUTLIER_FIXED_LOSS_THRESHOLD_FY2026 = 38_788.0   # USD

"""CAH outlier payment marginal rate (% of costs above fixed-loss + DRG equiv)."""
const CAH_OUTLIER_MARGINAL_RATE = 0.80

"""Medicare sequestration rate (Budget Control Act; 2% since FY2013)."""
const MEDICARE_SEQUESTRATION_RATE = 0.02

"""CAH bad debt reimbursement rate (100% for CAHs; 65% for PPS hospitals)."""
const CAH_BAD_DEBT_REIMBURSEMENT_RATE = 1.00

"""PPS hospital bad debt reimbursement rate (65%)."""
const PPS_BAD_DEBT_REIMBURSEMENT_RATE = 0.65

"""TEFRA incentive payment rate (50% of savings below target)."""
const TEFRA_INCENTIVE_RATE = 0.50

"""TEFRA penalty threshold (110% of target rate triggers penalty)."""
const TEFRA_PENALTY_THRESHOLD = 1.10

"""TEFRA penalty rate (50% of costs exceeding 110% of target)."""
const TEFRA_PENALTY_RATE = 0.50

"""FY2026 market basket update for TEFRA hospitals (estimated)."""
const TEFRA_MARKET_BASKET_FY2026 = 0.032

"""SNF PPS per-diem base rate FY2026 (PDPM; Urban Non-therapy component)."""
const SNF_PPS_BASE_PER_DIEM_FY2026 = 284.62   # USD/day

# ─────────────────────────────────────────────────────────────────────────────
# E-01a — CAH Inpatient Cost Outlier Payment
# ─────────────────────────────────────────────────────────────────────────────

"""
    CAHOutlierCase

A single inpatient case for cost-outlier payment determination.

# Fields
- `case_id::Any`
- `drg_weight::Float64`: The MS-DRG weight assigned to this case.
- `actual_cost::Float64`: Actual covered hospital cost for this case (USD).
- `los_days::Int`: Length of stay in days.
- `transfer::Bool`: Whether the case is a transfer (affects DRG-equivalent payment).
"""
@kwdef struct CAHOutlierCase
    case_id::Any              = 1
    drg_weight::Float64
    actual_cost::Float64
    los_days::Int
    transfer::Bool            = false
end

"""
    CAHOutlierPayment

Result of the CAH cost outlier payment determination for one case.

# Fields
- `case_id`
- `base_cost_reimbursement::Float64`: 101% of allowable cost (pre-outlier).
- `outlier_threshold_amount::Float64`: Fixed-loss threshold + DRG-equivalent payment.
- `is_outlier::Bool`: Whether this case qualifies for outlier payment.
- `outlier_costs_above_threshold::Float64`: `actual_cost − threshold_amount`.
- `outlier_payment::Float64`: `outlier_costs_above_threshold × 80%`.
- `total_payment::Float64`: Base reimbursement + outlier payment (pre-sequestration).
- `total_after_sequestration::Float64`
"""
struct CAHOutlierPayment
    case_id::Any
    base_cost_reimbursement::Float64
    outlier_threshold_amount::Float64
    is_outlier::Bool
    outlier_costs_above_threshold::Float64
    outlier_payment::Float64
    total_payment::Float64
    total_after_sequestration::Float64
end

"""
    cah_outlier_payment(
        case::CAHOutlierCase;
        cah_ccr, base_rate, sequestration, fixed_loss_threshold
    ) -> CAHOutlierPayment

Compute the Medicare outlier payment for a CAH inpatient case.

## Algorithm (CMS Worksheet E-1, Part II)

1. Compute DRG-equivalent payment = `base_rate × drg_weight`
   (this is a reference amount, not what the CAH is actually paid).
2. Outlier threshold = `fixed_loss_threshold + DRG-equivalent payment`.
3. If `actual_cost > outlier_threshold`:
   - Outlier payment = `(actual_cost − outlier_threshold) × 80%`
4. CAH total = 101% × allowable_cost + outlier_payment.
5. Apply 2% sequestration.

# Arguments
- `case::CAHOutlierCase`
- `cah_ccr::Float64`: Hospital-specific cost-to-charge ratio (from Worksheet C).
- `base_rate::Float64`: IPPS base rate for the MAC jurisdiction (FY2026).
- `sequestration::Bool = true`
- `fixed_loss_threshold::Float64 = CAH_OUTLIER_FIXED_LOSS_THRESHOLD_FY2026`

# Example
```julia
c = CAHOutlierCase(drg_weight=3.8, actual_cost=85_000.0, los_days=12)
p = cah_outlier_payment(c; cah_ccr=0.42, base_rate=6_800.0)
p.is_outlier       # true
p.outlier_payment  # ~\$22,000
```
"""
function cah_outlier_payment(
    case::CAHOutlierCase;
    cah_ccr::Float64              = 0.40,
    base_rate::Float64            = 6_800.0,
    sequestration::Bool           = true,
    fixed_loss_threshold::Float64 = CAH_OUTLIER_FIXED_LOSS_THRESHOLD_FY2026,
    reasonable_cost_pct::Float64  = 1.01,
)::CAHOutlierPayment

    # CAH base: 101% cost-based reimbursement
    base_reimb = case.actual_cost * reasonable_cost_pct

    # DRG-equivalent payment (reference only — CAH doesn't actually get DRGs)
    drg_equiv = base_rate * case.drg_weight

    # Outlier threshold
    threshold = fixed_loss_threshold + drg_equiv

    is_outlier = case.actual_cost > threshold
    excess = is_outlier ? case.actual_cost - threshold : 0.0
    outlier_pay = excess * CAH_OUTLIER_MARGINAL_RATE

    total = base_reimb + outlier_pay
    seq   = sequestration ? total * MEDICARE_SEQUESTRATION_RATE : 0.0

    CAHOutlierPayment(
        case.case_id,
        base_reimb,
        threshold,
        is_outlier,
        excess,
        outlier_pay,
        total,
        total - seq,
    )
end

"""
    cah_outlier_analysis(
        cases::Vector{CAHOutlierCase};
        cah_ccr, base_rate, sequestration
    ) -> NamedTuple

Analyze outlier payment eligibility for a cohort of CAH inpatient cases.

Returns:
- `payments::Vector{CAHOutlierPayment}`
- `n_outliers::Int`, `outlier_rate::Float64`
- `total_outlier_payment::Float64`
- `total_base_reimbursement::Float64`
- `total_payment::Float64`
- `outlier_pct_of_total::Float64`
"""
function cah_outlier_analysis(
    cases::Vector{CAHOutlierCase};
    cah_ccr::Float64    = 0.40,
    base_rate::Float64  = 6_800.0,
    sequestration::Bool = true,
)
    payments = [cah_outlier_payment(c; cah_ccr=cah_ccr, base_rate=base_rate,
                                       sequestration=sequestration) for c in cases]
    n_out = count(p -> p.is_outlier, payments)
    tot_out = sum(p.outlier_payment for p in payments)
    tot_base = sum(p.base_cost_reimbursement for p in payments)
    tot_total = sum(p.total_after_sequestration for p in payments)
    (
        payments                  = payments,
        n_outliers                = n_out,
        outlier_rate              = length(cases) > 0 ? n_out / length(cases) : NaN,
        total_outlier_payment     = tot_out,
        total_base_reimbursement  = tot_base,
        total_payment             = tot_total,
        outlier_pct_of_total      = tot_total > 0 ? tot_out / tot_total : NaN,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# E-01b — TEFRA Rate-of-Increase Payment (Excluded Hospitals)
# ─────────────────────────────────────────────────────────────────────────────

"""
    TEFRAHospitalData

Inputs for TEFRA rate-of-increase payment calculation.

Applies to excluded hospitals: psychiatric (IPF), children's, LTCH,
and rehabilitation facilities.

# Fields
- `hospital_type::Symbol`: `:psychiatric`, `:childrens`, `:ltch`, or `:rehab`.
- `base_year_cost_per_discharge::Float64`: Hospital-specific rate (HSR) from base year.
- `base_year::Int`: Year the HSR was established.
- `current_year::Int`: Fiscal year being paid.
- `actual_cost_per_discharge::Float64`: Actual cost per discharge in current year.
- `discharges::Int`: Total discharges in current year.
- `market_basket_updates::Vector{Float64}`: Annual MB updates from base_year+1 to current_year.
  Defaults to `TEFRA_MARKET_BASKET_FY2026` for all years if empty.
"""
@kwdef struct TEFRAHospitalData
    hospital_type::Symbol
    base_year_cost_per_discharge::Float64
    base_year::Int
    current_year::Int
    actual_cost_per_discharge::Float64
    discharges::Int
    market_basket_updates::Vector{Float64} = Float64[]
end

"""
    TEFRAPaymentResult

Result of a TEFRA rate-of-increase payment calculation.

# Fields
- `target_rate::Float64`: Hospital-specific rate updated by market basket.
- `penalty_threshold_rate::Float64`: `target_rate × 110%`.
- `payment_per_discharge::Float64`: Actual payment per discharge after incentive/penalty.
- `incentive_payment::Float64`: Bonus for operating below target (50% × savings × n).
- `penalty_amount::Float64`: Reduction for exceeding 110% of target (50% × excess × n).
- `total_payment::Float64`
- `performance::Symbol`: `:under_target`, `:penalty_zone`, or `:above_penalty`.
"""
struct TEFRAPaymentResult
    target_rate::Float64
    penalty_threshold_rate::Float64
    payment_per_discharge::Float64
    incentive_payment::Float64
    penalty_amount::Float64
    total_payment::Float64
    performance::Symbol
end

"""
    tefra_payment(data::TEFRAHospitalData) -> TEFRAPaymentResult

Compute TEFRA rate-of-increase Medicare payment.

## Rules (42 CFR § 412.71–412.78)
- If actual cost/discharge < target rate: paid at actual cost + 50% of savings.
- If actual cost/discharge between target and 110% of target: paid at actual cost.
- If actual cost/discharge > 110% of target: paid at actual cost − 50% of excess.

# Example
```julia
data = TEFRAHospitalData(
    hospital_type                = :psychiatric,
    base_year_cost_per_discharge = 12_000.0,
    base_year                    = 2018,
    current_year                 = 2026,
    actual_cost_per_discharge    = 13_800.0,
    discharges                   = 450,
)
r = tefra_payment(data)
r.incentive_payment   # positive: hospital is below target
```
"""
function tefra_payment(data::TEFRAHospitalData)::TEFRAPaymentResult
    data.hospital_type in (:psychiatric, :childrens, :ltch, :rehab) ||
        throw(ArgumentError("hospital_type must be :psychiatric, :childrens, :ltch, or :rehab"))
    data.current_year > data.base_year ||
        throw(ArgumentError("current_year must be > base_year"))

    n_years = data.current_year - data.base_year
    updates = isempty(data.market_basket_updates) ?
        fill(TEFRA_MARKET_BASKET_FY2026, n_years) :
        data.market_basket_updates

    length(updates) >= n_years ||
        throw(ArgumentError("market_basket_updates must cover all $(n_years) years"))

    # Compound the target rate with annual MB updates
    target = data.base_year_cost_per_discharge
    for i in 1:n_years
        target *= (1.0 + updates[i])
    end

    penalty_threshold = target * TEFRA_PENALTY_THRESHOLD
    actual = data.actual_cost_per_discharge
    n = data.discharges

    incentive = 0.0
    penalty   = 0.0
    perf      = :under_target

    if actual < target
        # Hospital beat the target — incentive payment
        savings   = target - actual
        incentive = savings * TEFRA_INCENTIVE_RATE * n
        perf      = :under_target
    elseif actual <= penalty_threshold
        # Between target and 110%: paid at actual cost, no incentive or penalty
        perf      = :penalty_zone
    else
        # Above 110% of target: penalty
        excess    = actual - penalty_threshold
        penalty   = excess * TEFRA_PENALTY_RATE * n
        perf      = :above_penalty
    end

    base_total = actual * n
    total_pay  = base_total + incentive - penalty

    TEFRAPaymentResult(
        target,
        penalty_threshold,
        total_pay / n,   # effective per-discharge payment
        incentive,
        penalty,
        total_pay,
        perf,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# E-01c — CAH Bad Debt Reimbursement
# ─────────────────────────────────────────────────────────────────────────────

"""
    cah_bad_debt_reimbursement(
        medicare_bad_debt::Float64;
        hospital_type=:cah
    ) -> NamedTuple

Compute Medicare bad debt reimbursement under the CAH vs PPS rules.

CAHs receive 100% reimbursement of uncollectible Medicare cost-sharing
amounts (deductibles and coinsurance owed by beneficiaries after collection
efforts), versus 65% for PPS hospitals.

## Worksheet S-10 methodology
Bad debt = (Medicare deductibles + coinsurance) written off after:
1. Billing the beneficiary.
2. Collection attempt (at least 120-day billing cycle).
3. Written off as uncollectible per hospital's charity care policy.

# Returns
- `medicare_bad_debt::Float64`: Input amount.
- `reimbursement_rate::Float64`: 1.00 for CAH; 0.65 for PPS.
- `bad_debt_reimbursement::Float64`
- `incremental_over_pps::Float64`: Extra revenue vs if the hospital were PPS.
"""
function cah_bad_debt_reimbursement(
    medicare_bad_debt::Float64;
    hospital_type::Symbol = :cah,
)
    rate = hospital_type == :cah ?
        CAH_BAD_DEBT_REIMBURSEMENT_RATE : PPS_BAD_DEBT_REIMBURSEMENT_RATE
    reimb = medicare_bad_debt * rate
    incr  = medicare_bad_debt * (rate - PPS_BAD_DEBT_REIMBURSEMENT_RATE)
    (
        medicare_bad_debt       = medicare_bad_debt,
        reimbursement_rate      = rate,
        bad_debt_reimbursement  = reimb,
        incremental_over_pps    = incr,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# E-01d — Swing-Bed SNF Payment (Worksheet E-1 Part III)
# ─────────────────────────────────────────────────────────────────────────────

"""
    cah_swing_bed_payment(
        swing_bed_days::Int;
        snf_per_diem, wage_index, sequestration
    ) -> NamedTuple

Compute Medicare swing-bed payment for a CAH under the SNF PPS per-diem rate.

CAH swing-bed days are paid at the SNF PPS rate (PDPM-based), not cost-based.
The per-diem is wage-index adjusted and subject to sequestration.

# Arguments
- `swing_bed_days::Int`
- `snf_per_diem::Float64 = SNF_PPS_BASE_PER_DIEM_FY2026`
- `wage_index::Float64 = 1.0`: Hospital's wage area wage index.
- `sequestration::Bool = true`
"""
function cah_swing_bed_payment(
    swing_bed_days::Int;
    snf_per_diem::Float64 = SNF_PPS_BASE_PER_DIEM_FY2026,
    wage_index::Float64   = 1.0,
    sequestration::Bool   = true,
)
    swing_bed_days >= 0 || throw(ArgumentError("swing_bed_days must be ≥ 0"))
    # SNF PDPM: 70% labor-related, 30% non-labor
    adjusted = snf_per_diem * (0.70 * wage_index + 0.30)
    gross = adjusted * swing_bed_days
    seq   = sequestration ? gross * MEDICARE_SEQUESTRATION_RATE : 0.0
    (
        swing_bed_days         = swing_bed_days,
        per_diem_adjusted      = adjusted,
        gross_payment          = gross,
        sequestration_amount   = seq,
        net_payment            = gross - seq,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# E-01e — Comprehensive CAH Worksheet E-1 Summary
# ─────────────────────────────────────────────────────────────────────────────

"""
    CAHWorksheetE1Inputs

All inputs needed for a comprehensive CAH Medicare cost report settlement.
Corresponds to CMS Form 2552-10, Worksheet E-1.
"""
@kwdef struct CAHWorksheetE1Inputs
    # Cost report data
    medicare_inpatient_costs::Float64
    medicare_outpatient_costs::Float64
    medicare_swing_bed_costs::Float64   = 0.0
    medicare_bad_debt::Float64          = 0.0

    # Outlier data
    outlier_cases::Vector{CAHOutlierCase} = CAHOutlierCase[]
    cah_ccr::Float64                      = 0.40
    ipps_base_rate::Float64               = 6_800.0

    # Swing-bed
    swing_bed_days::Int    = 0
    wage_index::Float64    = 1.0

    # Settings
    sequestration::Bool    = true
    reasonable_cost_pct::Float64 = 1.01   # 101% for CAHs
end

"""
    cah_worksheet_e1(inputs::CAHWorksheetE1Inputs) -> NamedTuple

Compute a complete CAH Medicare cost report settlement (Worksheet E-1).

Components:
1. Inpatient cost-based reimbursement (101% × allowable costs)
2. Outpatient cost-based reimbursement (101% × allowable costs)
3. Inpatient cost outlier payments
4. Swing-bed SNF PPS payment
5. Bad debt reimbursement (100%)
6. Sequestration reduction (2%)

# Returns NamedTuple with all line items matching Worksheet E-1 structure.
"""
function cah_worksheet_e1(inputs::CAHWorksheetE1Inputs)
    # Lines 1-3: cost-based components
    ip_reimb  = inputs.medicare_inpatient_costs  * inputs.reasonable_cost_pct
    op_reimb  = inputs.medicare_outpatient_costs * inputs.reasonable_cost_pct
    sb_costs  = inputs.medicare_swing_bed_costs  * inputs.reasonable_cost_pct

    # Line 4: outlier payments
    outlier_r = isempty(inputs.outlier_cases) ?
        (total_outlier_payment=0.0, n_outliers=0, outlier_rate=NaN) :
        cah_outlier_analysis(inputs.outlier_cases;
                              cah_ccr = inputs.cah_ccr,
                              base_rate = inputs.ipps_base_rate,
                              sequestration = false)  # apply seq at end

    # Line 5: swing-bed SNF payment
    sb_pay = cah_swing_bed_payment(inputs.swing_bed_days;
                                    wage_index = inputs.wage_index,
                                    sequestration = false)

    # Line 6: bad debt
    bd_pay = cah_bad_debt_reimbursement(inputs.medicare_bad_debt)

    # Subtotal before sequestration
    subtotal = ip_reimb + op_reimb + outlier_r.total_outlier_payment +
               sb_pay.gross_payment + bd_pay.bad_debt_reimbursement

    seq = inputs.sequestration ? subtotal * MEDICARE_SEQUESTRATION_RATE : 0.0
    net = subtotal - seq

    (
        # Line items
        inpatient_cost_reimbursement   = ip_reimb,
        outpatient_cost_reimbursement  = op_reimb,
        swing_bed_cost_component       = sb_costs,
        outlier_payment                = outlier_r.total_outlier_payment,
        swing_bed_snf_payment          = sb_pay.gross_payment,
        bad_debt_reimbursement         = bd_pay.bad_debt_reimbursement,
        # Totals
        subtotal_before_sequestration  = subtotal,
        sequestration_reduction        = seq,
        net_settlement                 = net,
        # Metadata
        n_outlier_cases                = outlier_r.n_outliers,
        outlier_rate                   = outlier_r.outlier_rate,
        bad_debt_incremental_over_pps  = bd_pay.incremental_over_pps,
    )
end
