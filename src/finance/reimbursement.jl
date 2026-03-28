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
    cr === nothing && error("CriticalAccessHospital must have a cost_report for Medicare reimbursement calculation")

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
        cr.total_charges * 0.05 * (cr.total_costs > 0.0 ?
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

    # Get wage index from service area or default to national average
    # REHPayment is an empty struct; wage index lives on the hospital's service area
    # or can be derived from the cost report. Use a sensible default of 1.0.
    wage_idx = if hasproperty(hospital, :wage_index)
        hospital.wage_index
    elseif hospital.cost_report !== nothing
        # Approximate from cost report cost-to-charge ratio relative to national avg
        1.0
    else
        1.0  # national average
    end

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

# ============================================================================
# Commercial Payer Reimbursement
# ============================================================================

"""
    calculate_commercial_reimbursement(hospital::AbstractHospital;
                                       commercial_charges::Float64=0.0,
                                       pct_of_charges::Float64=0.85,
                                       pct_of_medicare::Float64=1.50,
                                       method::Symbol=:pct_charges,
                                       commercial_days::Int=0,
                                       per_diem::Float64=0.0,
                                       drg_base_rate::Float64=0.0,
                                       case_mix_index::Float64=1.0) -> NamedTuple

Calculate commercial (private) payer reimbursement using the specified
payment methodology.

# Methods
- `:pct_charges` — percentage of billed charges (default 85%)
- `:pct_medicare` — percentage of Medicare rates (default 150%)
- `:per_diem` — negotiated per-diem rate × days
- `:drg` — DRG-based with a negotiated base rate × CMI

Returns a named tuple with:
- `method`: the reimbursement method used
- `gross_charges`: total billed charges
- `contractual_adjustment`: discount from charges
- `net_payment`: expected commercial payment
"""
function calculate_commercial_reimbursement(hospital::AbstractHospital;
                                             commercial_charges::Float64=0.0,
                                             pct_of_charges::Float64=0.85,
                                             pct_of_medicare::Float64=1.50,
                                             method::Symbol=:pct_charges,
                                             commercial_days::Int=0,
                                             per_diem::Float64=0.0,
                                             drg_base_rate::Float64=0.0,
                                             case_mix_index::Float64=1.0)
    net_payment = 0.0

    if method == :pct_charges
        net_payment = commercial_charges * pct_of_charges
    elseif method == :pct_medicare
        # Estimate Medicare-equivalent payment using CCR
        ccr = hasproperty(hospital, :cost_to_charge_ratio) ?
            getproperty(hospital, :cost_to_charge_ratio) : 0.40
        medicare_equiv = commercial_charges * ccr
        net_payment = medicare_equiv * pct_of_medicare
    elseif method == :per_diem
        net_payment = commercial_days * per_diem
    elseif method == :drg
        net_payment = drg_base_rate * case_mix_index
    else
        error("Unknown commercial payment method: $method")
    end

    contractual_adjustment = commercial_charges - net_payment

    return (
        method = method,
        gross_charges = commercial_charges,
        contractual_adjustment = max(contractual_adjustment, 0.0),
        net_payment = net_payment,
    )
end

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
