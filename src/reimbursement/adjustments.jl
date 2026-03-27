# ============================================================================
# Medicare Payment Adjustments
# ============================================================================

"""
    apply_wage_index(base_payment::Float64, wage_index::Float64;
                     labor_share::Float64=0.6862) -> Float64

Apply the Medicare Area Wage Index to a base payment amount.

The labor-related share of the payment is adjusted by the hospital's
geographic wage index; the non-labor share is unchanged.

# Arguments
- `base_payment`: unadjusted Medicare payment
- `wage_index`: CMS area wage index for the hospital's CBSA
- `labor_share`: labor-related share (default 68.62% for IPPS FY2024)

# Returns
Wage-index-adjusted payment amount.
"""
function apply_wage_index(base_payment::Float64, wage_index::Float64;
                          labor_share::Float64=0.6862)
    nonlabor_share = 1.0 - labor_share
    adjusted = base_payment * (labor_share * wage_index + nonlabor_share)
    return adjusted
end

"""
    apply_sequestration(payment::Float64;
                        rate::Float64=0.02) -> NamedTuple{(:net_payment, :reduction), Tuple{Float64, Float64}}

Apply the Budget Control Act sequestration reduction to a Medicare payment.

The statutory rate is 2% and applies to most Medicare FFS payments.

# Returns
A named tuple with:
- `net_payment`: payment after sequestration
- `reduction`: dollar amount of the sequestration cut
"""
function apply_sequestration(payment::Float64; rate::Float64=0.02)
    reduction = payment * rate
    net = payment - reduction
    return (net_payment = net, reduction = reduction)
end

"""
    apply_bad_debt_adjustment(total_bad_debt::Float64;
                              reimbursement_rate::Float64=0.65,
                              is_cah::Bool=false) -> NamedTuple

Calculate the Medicare bad debt adjustment.

For most hospitals, CMS reimburses 65% of allowable Medicare bad debt.
Critical Access Hospitals may receive a higher reimbursement for
cost-report-eligible bad debts.

# Arguments
- `total_bad_debt`: total Medicare-allowable bad debt
- `reimbursement_rate`: CMS reimbursement percentage (default 65%)
- `is_cah`: whether the hospital is a Critical Access Hospital

# Returns
A named tuple with:
- `allowable_bad_debt`: amount of bad debt eligible for reimbursement
- `reimbursement`: dollar amount CMS will reimburse
- `unreimbursed`: bad debt the hospital must absorb
"""
function apply_bad_debt_adjustment(total_bad_debt::Float64;
                                   reimbursement_rate::Float64=0.65,
                                   is_cah::Bool=false)
    # CAHs may receive 101% of bad debt through cost report settlement
    effective_rate = is_cah ? min(reimbursement_rate * 1.01, 1.0) : reimbursement_rate

    reimbursement = total_bad_debt * effective_rate
    unreimbursed = total_bad_debt - reimbursement

    return (
        allowable_bad_debt = total_bad_debt,
        reimbursement = reimbursement,
        unreimbursed = unreimbursed,
    )
end
