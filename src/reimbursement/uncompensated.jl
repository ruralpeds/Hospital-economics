# ============================================================================
# Uncompensated Care — Bad Debt and Charity Care
# ============================================================================

"""
    calculate_uncompensated_care(hospital::AbstractHospital;
                                 total_charges::Float64=0.0,
                                 charity_pct::Float64=0.03,
                                 bad_debt_pct::Float64=0.05,
                                 charity_ccr_discount::Float64=1.0,
                                 medicare_bad_debt_eligible_pct::Float64=0.30,
                                 medicare_bad_debt_reimbursement::Float64=0.65) -> NamedTuple

Calculate uncompensated care costs including charity care and bad debt.

# Arguments
- `total_charges`: gross patient charges
- `charity_pct`: fraction of charges written off as charity (default 3%)
- `bad_debt_pct`: fraction of charges that become bad debt (default 5%)
- `charity_ccr_discount`: multiplier; 1.0 = full charges, <1.0 = at cost
- `medicare_bad_debt_eligible_pct`: share of bad debt eligible for Medicare
  reimbursement (default 30%)
- `medicare_bad_debt_reimbursement`: CMS reimbursement rate for eligible
  bad debt (default 65%)

Returns a named tuple with:
- `charity_care_charges`: total charity write-offs at charges
- `charity_care_cost`: charity care at cost
- `bad_debt_charges`: total bad debt at charges
- `bad_debt_cost`: bad debt at cost (using hospital CCR)
- `medicare_bad_debt_reimbursement`: amount reimbursed by CMS
- `net_uncompensated_cost`: total unreimbursed uncompensated care cost
- `uncompensated_pct`: uncompensated care as a percentage of charges
"""
function calculate_uncompensated_care(hospital::AbstractHospital;
                                      total_charges::Float64=0.0,
                                      charity_pct::Float64=0.03,
                                      bad_debt_pct::Float64=0.05,
                                      charity_ccr_discount::Float64=1.0,
                                      medicare_bad_debt_eligible_pct::Float64=0.30,
                                      medicare_bad_debt_reimbursement::Float64=0.65)
    ccr = hasproperty(hospital, :cost_to_charge_ratio) ?
        getproperty(hospital, :cost_to_charge_ratio) : 0.40

    # Charity care
    charity_charges = total_charges * charity_pct
    charity_cost = charity_charges * ccr * charity_ccr_discount

    # Bad debt
    bad_debt_charges = total_charges * bad_debt_pct
    bad_debt_cost = bad_debt_charges * ccr

    # Medicare bad debt reimbursement (65% of eligible bad debt)
    medicare_bd_reimb = bad_debt_charges * medicare_bad_debt_eligible_pct *
                        medicare_bad_debt_reimbursement

    # Net unreimbursed
    net_uncompensated = charity_cost + bad_debt_cost - medicare_bd_reimb

    uncompensated_pct = total_charges > 0 ?
        (charity_charges + bad_debt_charges) / total_charges : 0.0

    return (
        charity_care_charges = charity_charges,
        charity_care_cost = charity_cost,
        bad_debt_charges = bad_debt_charges,
        bad_debt_cost = bad_debt_cost,
        medicare_bad_debt_reimbursement = medicare_bd_reimb,
        net_uncompensated_cost = net_uncompensated,
        uncompensated_pct = uncompensated_pct,
    )
end
