# ── Healthcare Reimbursement Analytics ───────────────────────────────────────
#
# DRG/IPPS, OPPS/APC, RBRVS/RVU payment calculations, capitation,
# payer contract analytics, and revenue cycle KPI scorecard.
#
# Ported from healthcare-finance-julia/src/reimbursement/reimbursement_engine.jl

# ─── DRG / IPPS ──────────────────────────────────────────────────────────────

"""
    drg_payment(base_rate, drg_weight, cases;
                outlier_threshold=0.0, outlier_rate=0.8) -> Float64

Basic inpatient DRG payment with optional cost-outlier add-on.
"""
function drg_payment(base_rate::Real, drg_weight::Real, cases::Integer;
                     outlier_threshold::Real=0.0,
                     outlier_rate::Real=0.8)::Float64
    base_rate > 0  || throw(ArgumentError("base_rate must be positive"))
    drg_weight > 0 || throw(ArgumentError("drg_weight must be positive"))
    cases >= 0     || throw(ArgumentError("cases must be non-negative"))
    base_payment    = base_rate * drg_weight * cases
    outlier_payment = outlier_threshold > 0 ? outlier_threshold * outlier_rate * cases : 0.0
    return base_payment + outlier_payment
end

"""
    ms_drg_payment(base_rate, drg_weight, cases, cc_mcc_flag;
                   wage_index=1.0, dsh_adjustment=0.0, ime_adjustment=0.0)
        -> Float64

Full MS-DRG IPPS payment with wage index, DSH, and IME adjustments.
`cc_mcc_flag` must be `:none`, `:cc`, or `:mcc`.
CMS labor share = 68.8%.
"""
function ms_drg_payment(base_rate::Real, drg_weight::Real, cases::Integer,
                         cc_mcc_flag::Symbol;
                         wage_index::Real=1.0,
                         dsh_adjustment::Real=0.0,
                         ime_adjustment::Real=0.0)::Float64
    cc_mcc_flag in (:none, :cc, :mcc) ||
        throw(ArgumentError("cc_mcc_flag must be :none, :cc, or :mcc"))
    labor_share   = 0.688
    adjusted_base = base_rate * (labor_share * wage_index + (1 - labor_share))
    base_payment  = adjusted_base * drg_weight * cases
    return base_payment * (1 + dsh_adjustment + ime_adjustment)
end

"""
    apr_drg_payment(base_rate, drg_weight, severity_level, cases) -> Float64

All-Patient Refined DRG payment with severity adjustment.
`severity_level` must be 1 (minor) through 4 (extreme).
Severity adjustors: 1→0.60, 2→1.00, 3→1.50, 4→2.20.
"""
function apr_drg_payment(base_rate::Real, drg_weight::Real,
                          severity_level::Integer, cases::Integer)::Float64
    severity_level in 1:4 ||
        throw(ArgumentError("severity_level must be 1–4"))
    severity_adjustors = [0.60, 1.00, 1.50, 2.20]
    return base_rate * drg_weight * severity_adjustors[severity_level] * cases
end

# ─── OPPS / APC ──────────────────────────────────────────────────────────────

"""
    opps_apc_payment(conversion_factor, apc_relative_weight, visits;
                     copay_reduction=0.0, pass_through=0.0) -> Float64

Hospital Outpatient Prospective Payment System (OPPS) APC payment.
"""
function opps_apc_payment(conversion_factor::Real,
                           apc_relative_weight::Real,
                           visits::Integer;
                           copay_reduction::Real=0.0,
                           pass_through::Real=0.0)::Float64
    conversion_factor > 0    || throw(ArgumentError("conversion_factor must be positive"))
    apc_relative_weight > 0  || throw(ArgumentError("apc_relative_weight must be positive"))
    visits >= 0              || throw(ArgumentError("visits must be non-negative"))
    per_visit = conversion_factor * apc_relative_weight - copay_reduction + pass_through
    return per_visit * visits
end

# ─── RBRVS / RVU ─────────────────────────────────────────────────────────────

"""
    rvu_to_payment(work_rvu, pe_rvu, mp_rvu, conversion_factor;
                   gpci_work=1.0, gpci_pe=1.0, gpci_mp=1.0) -> Float64

Convert RVU components to Medicare Physician Fee Schedule payment.
Payment = (work_rvu×GPCI_w + pe_rvu×GPCI_pe + mp_rvu×GPCI_mp) × CF.
"""
function rvu_to_payment(work_rvu::Real, pe_rvu::Real, mp_rvu::Real,
                         conversion_factor::Real;
                         gpci_work::Real=1.0,
                         gpci_pe::Real=1.0,
                         gpci_mp::Real=1.0)::Float64
    conversion_factor > 0 || throw(ArgumentError("conversion_factor must be positive"))
    total_rvu = work_rvu * gpci_work + pe_rvu * gpci_pe + mp_rvu * gpci_mp
    return total_rvu * conversion_factor
end

"""
    rbrvs_payment(work_rvu, pe_rvu, mp_rvu, conversion_factor, units;
                  gpci_work=1.0, gpci_pe=1.0, gpci_mp=1.0) -> Float64

Total RBRVS payment for multiple service units.
"""
function rbrvs_payment(work_rvu::Real, pe_rvu::Real, mp_rvu::Real,
                        conversion_factor::Real, units::Integer;
                        gpci_work::Real=1.0,
                        gpci_pe::Real=1.0,
                        gpci_mp::Real=1.0)::Float64
    units >= 0 || throw(ArgumentError("units must be non-negative"))
    return rvu_to_payment(work_rvu, pe_rvu, mp_rvu, conversion_factor;
                          gpci_work=gpci_work, gpci_pe=gpci_pe, gpci_mp=gpci_mp) * units
end

# ─── Capitation / PMPM ────────────────────────────────────────────────────────

"""
    capitation_pmpm(total_expenditure, member_months) -> Float64

Per-member-per-month capitation rate from total expenditure.
"""
function capitation_pmpm(total_expenditure::Real, member_months::Real)::Float64
    member_months > 0 || throw(ArgumentError("member_months must be positive"))
    return total_expenditure / member_months
end

"""
    pmpm_trend(base_pmpm, trend_rate, months) -> Float64

Project PMPM forward using monthly compounding: base × (1+rate)^months.
"""
function pmpm_trend(base_pmpm::Real, trend_rate::Real, months::Integer)::Float64
    months >= 0 || throw(ArgumentError("months must be non-negative"))
    return base_pmpm * (1 + trend_rate)^months
end

"""
    payer_contract_net(charges, allowed_rate, payer_share, patient_copay)
        -> Float64

Net revenue under payer contract terms.
`allowed_rate` and `payer_share` must be in (0, 1].
"""
function payer_contract_net(charges::Real, allowed_rate::Real,
                             payer_share::Real, patient_copay::Real)::Float64
    0 < allowed_rate <= 1 || throw(ArgumentError("allowed_rate must be in (0, 1]"))
    0 < payer_share  <= 1 || throw(ArgumentError("payer_share must be in (0, 1]"))
    patient_copay >= 0    || throw(ArgumentError("patient_copay must be non-negative"))
    return charges * allowed_rate * payer_share + patient_copay
end

# ─── Revenue Cycle KPIs ───────────────────────────────────────────────────────

"""
    days_in_ar(ending_ar_balance, average_daily_revenue) -> Float64

Accounts receivable days = ending AR / average daily net revenue.
Industry benchmark: ≤ 40 days.
"""
function days_in_ar(ending_ar_balance::Real,
                    average_daily_revenue::Real)::Float64
    average_daily_revenue > 0 ||
        throw(ArgumentError("average_daily_revenue must be positive"))
    return ending_ar_balance / average_daily_revenue
end

"""
    denial_rate(denied_claims, total_claims_submitted) -> Float64

Claim denial rate. Benchmark: ≤ 3%.
"""
function denial_rate(denied_claims::Integer,
                     total_claims_submitted::Integer)::Float64
    total_claims_submitted > 0 ||
        throw(ArgumentError("total_claims_submitted must be positive"))
    return denied_claims / total_claims_submitted
end

"""
    clean_claim_rate(claims_paid_first_submission, total_claims_submitted)
        -> Float64

First-pass payment rate (clean claim rate). Benchmark: ≥ 98%.
"""
function clean_claim_rate(claims_paid_first_submission::Integer,
                           total_claims_submitted::Integer)::Float64
    total_claims_submitted > 0 ||
        throw(ArgumentError("total_claims_submitted must be positive"))
    return claims_paid_first_submission / total_claims_submitted
end

"""
    gross_collection_rate(payments_received, gross_charges) -> Float64

Payments as a percentage of gross charges billed.
"""
function gross_collection_rate(payments_received::Real,
                                gross_charges::Real)::Float64
    gross_charges > 0 || throw(ArgumentError("gross_charges must be positive"))
    return payments_received / gross_charges
end

"""
    cash_collection_efficiency(actual_cash_collected, net_revenue) -> Float64

Ratio of actual cash collected to net revenue.
Values > 1.0 indicate collection of prior-period AR.
"""
function cash_collection_efficiency(actual_cash_collected::Real,
                                     net_revenue::Real)::Float64
    net_revenue > 0 || throw(ArgumentError("net_revenue must be positive"))
    return actual_cash_collected / net_revenue
end

"""
    bad_debt_rate(bad_debt_expense, gross_revenue) -> Float64

Bad debt expense as a percentage of gross revenue.
"""
function bad_debt_rate(bad_debt_expense::Real, gross_revenue::Real)::Float64
    gross_revenue > 0 || throw(ArgumentError("gross_revenue must be positive"))
    return bad_debt_expense / gross_revenue
end

"""
    charity_care_rate(charity_care_cost, total_operating_expense) -> Float64

Charity care cost as a percentage of total operating expense.
"""
function charity_care_rate(charity_care_cost::Real,
                            total_operating_expense::Real)::Float64
    total_operating_expense > 0 ||
        throw(ArgumentError("total_operating_expense must be positive"))
    return charity_care_cost / total_operating_expense
end

"""
    uncompensated_care_rate(bad_debt_expense, charity_care_cost, gross_revenue)
        -> Float64

Combined bad debt + charity care as a percentage of gross revenue.
Community benefit reporting metric for nonprofit hospitals.
"""
function uncompensated_care_rate(bad_debt_expense::Real,
                                  charity_care_cost::Real,
                                  gross_revenue::Real)::Float64
    gross_revenue > 0 || throw(ArgumentError("gross_revenue must be positive"))
    return (bad_debt_expense + charity_care_cost) / gross_revenue
end

"""
    revenue_cycle_scorecard(; days_ar, denial_rt, clean_claim_rt,
                              cash_efficiency) -> NamedTuple

Score four revenue cycle KPIs against industry benchmarks.
Each returns `:exceeds`, `:meets`, or `:below`.

Benchmarks:
- days_ar        ≤ 40 exceeds, ≤ 50 meets
- denial_rate    ≤ 3% exceeds, ≤ 5% meets
- clean_claim_rt ≥ 98% exceeds, ≥ 95% meets
- cash_efficiency ≥ 102% exceeds, ≥ 100% meets
"""
function revenue_cycle_scorecard(; days_ar::Real, denial_rt::Real,
                                   clean_claim_rt::Real,
                                   cash_efficiency::Real)
    score_dar  = days_ar <= 40 ? :exceeds : days_ar <= 50 ? :meets : :below
    score_den  = denial_rt <= 0.03 ? :exceeds : denial_rt <= 0.05 ? :meets : :below
    score_ccr  = clean_claim_rt >= 0.98 ? :exceeds : clean_claim_rt >= 0.95 ? :meets : :below
    score_cash = cash_efficiency >= 1.02 ? :exceeds : cash_efficiency >= 1.0 ? :meets : :below
    return (days_ar=score_dar, denial_rate=score_den,
            clean_claim_rate=score_ccr, cash_efficiency=score_cash)
end
