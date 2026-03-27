# ============================================================================
# Medicare Reimbursement Calculations — Multiple Dispatch
# ============================================================================

# ---------------------------------------------------------------------------
# Concrete hospital types (defined here for dispatch; in full project these
# would live in types/)
# ---------------------------------------------------------------------------

"""Critical Access Hospital — eligible for 101% cost-based reimbursement."""
struct CriticalAccessHospital <: AbstractRuralHospital
    name::String
    provider_id::String
    beds::Int
    case_mix_index::Float64
    wage_index::Float64
    cost_to_charge_ratio::Float64
    total_costs::Float64
    total_charges::Float64
    medicare_charges::Float64
    medicare_days::Int
    outpatient_visits::Int
    payer_mix::Dict{String,Float64}
end

"""Rural Emergency Hospital — REH designation (no inpatient beds)."""
struct RuralEmergencyHospital <: AbstractRuralHospital
    name::String
    provider_id::String
    case_mix_index::Float64
    wage_index::Float64
    total_costs::Float64
    total_charges::Float64
    medicare_charges::Float64
    outpatient_visits::Int
    ed_visits::Int
    payer_mix::Dict{String,Float64}
    opps_relative_weights::Float64
end

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
    # Calculate Medicare cost share using CCR method
    ccr = hospital.cost_to_charge_ratio
    allowable_costs = hospital.medicare_charges * ccr

    # 101% cost-based reimbursement
    cost_reimbursement = allowable_costs * 1.01

    # Apply sequestration
    seq_amount = sequestration ? cost_reimbursement * 0.02 : 0.0
    net_after_seq = cost_reimbursement - seq_amount

    # Bad debt reimbursement (65% of Medicare bad debt)
    medicare_share = hospital.total_charges > 0 ?
        hospital.medicare_charges / hospital.total_charges : 0.0
    estimated_bad_debt = hospital.total_charges * 0.05 * medicare_share  # assume 5% bad debt
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

    reh_addon = opps_base * 0.05

    facility_payment = 272866.30 * 12  # annual

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

    wage_adjusted = conversion_factor * (
        labor_share * hospital.wage_index + nonlabor_share
    )

    # Total OPPS = wage-adjusted CF × sum of relative weights for all services
    total_opps = wage_adjusted * hospital.opps_relative_weights

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
