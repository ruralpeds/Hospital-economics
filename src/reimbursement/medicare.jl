# ============================================================================
# Medicare Reimbursement Calculations — Multiple Dispatch
# ============================================================================

# Uses CriticalAccessHospital and RuralEmergencyHospital types from
# types/hospital.jl — no duplicate struct definitions needed here.

# ---------------------------------------------------------------------------
# Medicare reimbursement — Critical Access Hospital (cost-based, 101%)
# ---------------------------------------------------------------------------

"""
    calculate_medicare_reimbursement(hospital::CriticalAccessHospital;
                                     sequestration::Bool=true) -> NamedTuple

Calculate Medicare reimbursement for a Critical Access Hospital using
cost-based methodology at 101% of reasonable costs.

Returns a named tuple with line-item detail:
- `allowable_costs`: Medicare's share of allowable costs
- `cost_reimbursement`: 101% of allowable costs
- `sequestration_amount`: reduction from sequestration (if applicable)
- `bad_debt_payment`: reimbursable bad debt (65%)
- `total_reimbursement`: final Medicare payment
"""
function calculate_medicare_reimbursement(hospital::CriticalAccessHospital;
                                          sequestration::Bool=true)
    # Retrieve cost report data from the hospital's cost_report field
    cr = hospital.cost_report

    # Calculate Medicare cost share using CCR method
    ccr = cr.overall_cost_to_charge_ratio
    allowable_costs = cr.medicare_allowable_costs > 0.0 ?
        cr.medicare_allowable_costs :
        (cr.medicare_inpatient_costs + cr.medicare_outpatient_costs + cr.medicare_swing_bed_costs)

    # 101% cost-based reimbursement
    cost_reimbursement = allowable_costs * cr.reasonable_cost_percentage

    # Apply sequestration
    seq_amount = sequestration ? cost_reimbursement * 0.02 : 0.0
    net_after_seq = cost_reimbursement - seq_amount

    # Bad debt reimbursement (65% of Medicare bad debt)
    # Estimate bad debt from historical financials if available
    estimated_bad_debt = if !isempty(hospital.historical_financials)
        latest = hospital.historical_financials[end]
        latest.bad_debt_expense * latest.medicare_days_pct
    else
        cr.total_charges * 0.05 * (cr.total_charges > 0.0 ?
            (cr.medicare_inpatient_costs + cr.medicare_outpatient_costs) / cr.total_costs : 0.0)
    end
    bad_debt_payment = estimated_bad_debt * 0.65

    total = net_after_seq + bad_debt_payment

    return (
        allowable_costs = allowable_costs,
        cost_reimbursement = cost_reimbursement,
        sequestration_amount = seq_amount,
        bad_debt_payment = bad_debt_payment,
        total_reimbursement = total,
    )
end

# ---------------------------------------------------------------------------
# Medicare reimbursement — Rural Emergency Hospital (OPPS + 5% + facility)
# ---------------------------------------------------------------------------

"""
    calculate_medicare_reimbursement(hospital::RuralEmergencyHospital;
                                     sequestration::Bool=true) -> NamedTuple

Calculate Medicare reimbursement for a Rural Emergency Hospital.

REH payment = OPPS rate × (1 + 5% add-on) + monthly facility payment.
REHs do not have inpatient stays.

Returns a named tuple with:
- `opps_base`: base OPPS payment for outpatient services
- `reh_addon`: 5% add-on to OPPS
- `facility_payment`: annual REH facility payment
- `sequestration_amount`: reduction from sequestration (if applicable)
- `total_reimbursement`: final Medicare payment
"""
function calculate_medicare_reimbursement(hospital::RuralEmergencyHospital;
                                          sequestration::Bool=true)
    opps_base = calculate_opps_payment(hospital)

    reh_addon = opps_base * hospital.outpatient_add_on_pct

    facility_payment = hospital.monthly_facility_payment * 12  # annual

    gross = opps_base + reh_addon + facility_payment

    seq_amount = sequestration ? (opps_base + reh_addon) * 0.02 : 0.0
    # Note: facility payment is NOT subject to sequestration
    total = gross - seq_amount

    return (
        opps_base = opps_base,
        reh_addon = reh_addon,
        facility_payment = facility_payment,
        sequestration_amount = seq_amount,
        total_reimbursement = total,
    )
end

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

"""
    calculate_opps_payment(hospital::RuralEmergencyHospital) -> Float64

Calculate the Outpatient Prospective Payment System (OPPS) base payment
for a Rural Emergency Hospital, applying the conversion factor and
wage index adjustment.
"""
function calculate_opps_payment(hospital::RuralEmergencyHospital)
    conversion_factor = 89.93  # CY 2024
    labor_share = 0.60
    nonlabor_share = 0.40

    # Get wage index from payment designation or cost report
    wage_idx = hospital.payment_designation.wage_index

    wage_adjusted = conversion_factor * (
        labor_share * wage_idx + nonlabor_share
    )

    # Total OPPS = wage-adjusted CF × sum of relative weights for all services
    # Use outpatient costs from cost report as a proxy for relative weight volume
    opps_weights = if hospital.cost_report !== nothing
        cr = hospital.cost_report
        cr.medicare_outpatient_costs > 0.0 ? cr.medicare_outpatient_costs / conversion_factor : 0.0
    else
        0.0
    end

    total_opps = wage_adjusted * opps_weights

    return total_opps
end

"""
    calculate_interim_payments(hospital::CriticalAccessHospital;
                                frequency::Symbol=:monthly) -> Vector{Float64}

Estimate interim (periodic) Medicare payments for a Critical Access Hospital
based on historical utilization. CMS makes interim payments and reconciles
at cost report settlement.

`frequency` may be `:monthly`, `:biweekly`, or `:quarterly`.
"""
function calculate_interim_payments(hospital::CriticalAccessHospital;
                                     frequency::Symbol=:monthly)
    reimb = calculate_medicare_reimbursement(hospital)
    annual = reimb.total_reimbursement

    periods = if frequency == :monthly
        12
    elseif frequency == :biweekly
        26
    elseif frequency == :quarterly
        4
    else
        error("Unknown frequency: $frequency. Use :monthly, :biweekly, or :quarterly.")
    end

    payment_per_period = annual / periods
    return fill(payment_per_period, periods)
end
