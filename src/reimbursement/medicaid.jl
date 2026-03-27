# ============================================================================
# Medicaid Reimbursement Calculations
# ============================================================================

"""
    MedicaidFeeSchedule

State-specific Medicaid fee schedule parameters.

# Fields
- `state::String`: two-letter state code
- `inpatient_per_diem::Float64`: per-diem rate for inpatient stays
- `outpatient_rate_pct::Float64`: percentage of charges or cost paid
- `ed_visit_rate::Float64`: flat rate per emergency department visit
- `observation_rate::Float64`: flat rate per observation hour
- `cost_based::Bool`: true if state uses cost-based reimbursement
- `upper_payment_limit_pct::Float64`: UPL as fraction of Medicare rates
- `supplemental_pool::Float64`: annual DSH / supplemental payment pool
"""
struct MedicaidFeeSchedule
    state::String
    inpatient_per_diem::Float64
    outpatient_rate_pct::Float64
    ed_visit_rate::Float64
    observation_rate::Float64
    cost_based::Bool
    upper_payment_limit_pct::Float64
    supplemental_pool::Float64
end

"""
    calculate_medicaid_reimbursement(hospital::AbstractHospital,
                                     fee_schedule::MedicaidFeeSchedule;
                                     medicaid_days::Int=0,
                                     medicaid_outpatient_visits::Int=0,
                                     medicaid_ed_visits::Int=0,
                                     medicaid_charges::Float64=0.0) -> NamedTuple

Calculate Medicaid reimbursement for a hospital given a state fee schedule
and utilization data.

Supports both fee-schedule-based and cost-based state methodologies.

Returns a named tuple with:
- `inpatient_payment`: payment for inpatient days
- `outpatient_payment`: payment for outpatient services
- `ed_payment`: payment for emergency department visits
- `supplemental_payment`: DSH or supplemental payments
- `total_reimbursement`: sum of all Medicaid payments
"""
function calculate_medicaid_reimbursement(hospital::AbstractHospital,
                                          fee_schedule::MedicaidFeeSchedule;
                                          medicaid_days::Int=0,
                                          medicaid_outpatient_visits::Int=0,
                                          medicaid_ed_visits::Int=0,
                                          medicaid_charges::Float64=0.0)
    if fee_schedule.cost_based
        # Cost-based states reimburse at the cost-to-charge ratio
        ccr = hasproperty(hospital, :cost_to_charge_ratio) ?
            getproperty(hospital, :cost_to_charge_ratio) : 0.40
        inpatient_payment = medicaid_charges * 0.6 * ccr  # approx inpatient share
        outpatient_payment = medicaid_charges * 0.4 * ccr
        ed_payment = 0.0  # included in outpatient
    else
        # Fee-schedule-based
        inpatient_payment = medicaid_days * fee_schedule.inpatient_per_diem
        outpatient_payment = medicaid_outpatient_visits > 0 ?
            medicaid_charges * fee_schedule.outpatient_rate_pct : 0.0
        ed_payment = medicaid_ed_visits * fee_schedule.ed_visit_rate
    end

    # Supplemental / DSH payments (allocated proportionally)
    supplemental_payment = fee_schedule.supplemental_pool

    total = inpatient_payment + outpatient_payment + ed_payment + supplemental_payment

    return (
        inpatient_payment = inpatient_payment,
        outpatient_payment = outpatient_payment,
        ed_payment = ed_payment,
        supplemental_payment = supplemental_payment,
        total_reimbursement = total,
    )
end
