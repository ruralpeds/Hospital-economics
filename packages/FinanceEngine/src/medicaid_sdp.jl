"""
    medicaid_sdp.jl — Medicaid State Directed Payments (MBA Gap E-08)

Implements the financial analytics for Medicaid State Directed Payments (SDPs)
authorized under 42 CFR § 438.6(c) and the CAA 2021.

## Background
Since 2016, CMS has allowed states with managed care Medicaid to require MCOs
to make directed payments to specific hospitals or classes of providers at rates
above what the MCO would otherwise negotiate. SDPs have become the primary
mechanism for states to pass supplemental Medicaid revenue to safety-net and
rural hospitals without going through a traditional State Plan Amendment.

## Key SDP types
1. **ATB (Across-the-Board)** — uniform rate increase for all Medicaid-enrolled
   hospitals in the state (or a defined class).
2. **Safety-net directed payment** — targeted at DSH hospitals and high-Medicaid-
   utilisation hospitals.
3. **Rural/CAH directed payment** — specifically targets Critical Access Hospitals
   and rural hospitals to maintain rural access.
4. **Transition-related directed payment** — used during MCO procurement transitions.

## Payment mechanics
1. State defines a **base payment amount** per encounter class (IP, OP, etc.).
2. State directs MCOs to pay hospitals at `base_payment × directed_rate_multiplier`.
3. MCOs are reimbursed through their capitation rate (CMS pre-approves the additional
   capitation cost).
4. **Upper Payment Limit (UPL)** test: aggregate SDP + base MCO payment cannot exceed
   what Medicare FFS would pay for the same services.

## CMS approval requirements (42 CFR § 438.6(c))
- State plan amendment required.
- CMS pre-approval of the SDP before implementation.
- Annual reporting: total payments made by MCO per provider.
- UPL certification required by state actuary.

References:
- 42 CFR § 438.6(c) (Medicaid Managed Care SDPs).
- CMS CMCS Informational Bulletin (April 2022): Updated SDP guidance.
- KFF (2024). Medicaid Directed Payments: Status Across States.
- Dobson | DaVanzo (2023). Rural Hospital SDP Estimator Technical Report.
"""

using Statistics
using Printf

# ─────────────────────────────────────────────────────────────────────────────
# SDP types and eligibility
# ─────────────────────────────────────────────────────────────────────────────

"""
    SDPType

Types of Medicaid state directed payments.
"""
@enum SDPType begin
    atb_all_hospitals        = 1   # Across-the-board: all MCO-enrolled hospitals
    safety_net_directed      = 2   # Targeted at DSH/high-Medicaid hospitals
    rural_cah_directed       = 3   # Rural + CAH specific
    transition_directed      = 4   # MCO transition-related
    value_based_directed     = 5   # Performance-contingent directed payments
end

"""
    SDPEligibilityTier

Hospital eligibility tier within the SDP programme.
Higher tiers receive larger directed payment rates.
"""
@enum SDPEligibilityTier begin
    tier_1_cah_sole_community  = 1   # CAHs + sole community providers: highest payment
    tier_2_rural_hospital      = 2   # Rural PPS hospitals
    tier_3_safety_net_urban    = 3   # Urban DSH hospitals with high Medicaid share
    tier_4_all_eligible        = 4   # Broad eligibility
end

# ─────────────────────────────────────────────────────────────────────────────
# Payment input types
# ─────────────────────────────────────────────────────────────────────────────

"""
    SDPHospitalInputs

Hospital-specific inputs for SDP calculation.

# Fields
- `hospital_id::Any`
- `hospital_name::String`
- `hospital_type::Symbol`: `:cah`, `:rural_pps`, `:dsh`, `:urban_general`.
- `is_cah::Bool`
- `is_sole_community::Bool`
- `medicaid_managed_care_days::Int`: Medicaid MCO inpatient days per year.
- `medicaid_mc_op_visits::Int`: Medicaid MCO outpatient/clinic visits per year.
- `medicaid_mc_ip_charges::Float64`: Medicaid MCO inpatient charges per year.
- `medicaid_mc_op_charges::Float64`: Medicaid MCO outpatient charges per year.
- `medicare_ip_payment_rate::Float64`: Medicare FFS payment per IP day (for UPL).
- `medicare_op_payment_rate::Float64`: Medicare FFS payment per OP visit (for UPL).
- `current_mcaid_base_payment_ip::Float64`: Current MCO IP payment rate per day.
- `current_mcaid_base_payment_op::Float64`: Current MCO OP payment rate per visit.
"""
@kwdef struct SDPHospitalInputs
    hospital_id::Any
    hospital_name::String
    hospital_type::Symbol                   = :cah
    is_cah::Bool                            = true
    is_sole_community::Bool                 = false
    medicaid_managed_care_days::Int         = 0
    medicaid_mc_op_visits::Int              = 0
    medicaid_mc_ip_charges::Float64         = 0.0
    medicaid_mc_op_charges::Float64         = 0.0
    medicare_ip_payment_rate::Float64       = 0.0   # for UPL ceiling
    medicare_op_payment_rate::Float64       = 0.0
    current_mcaid_base_payment_ip::Float64  = 0.0
    current_mcaid_base_payment_op::Float64  = 0.0
end

"""
    SDPProgramInputs

State SDP programme-level parameters.

# Fields
- `sdp_type::SDPType`
- `state::String`: Two-letter state abbreviation.
- `effective_date::String`
- `ip_directed_rate_multiplier::Dict{SDPEligibilityTier,Float64}`:
  Multiplier applied to base IP payment per eligibility tier.
  e.g. `Dict(tier_1_cah_sole_community => 1.50)` = pay 50% above base.
- `op_directed_rate_multiplier::Dict{SDPEligibilityTier,Float64}`
- `mco_capitation_add_on_pmpm::Float64`: Additional PMPM paid to MCOs to
  fund the directed payments (funded by state + federal Medicaid match).
- `upl_ceiling_pct::Float64 = 1.0`: UPL ceiling as % of Medicare rate (≤ 1.0).
"""
@kwdef struct SDPProgramInputs
    sdp_type::SDPType
    state::String                           = "XX"
    effective_date::String                  = "2026-01-01"
    ip_directed_rate_multiplier::Dict{SDPEligibilityTier,Float64} =
        Dict(tier_1_cah_sole_community => 1.50,
             tier_2_rural_hospital     => 1.35,
             tier_3_safety_net_urban   => 1.25,
             tier_4_all_eligible       => 1.15)
    op_directed_rate_multiplier::Dict{SDPEligibilityTier,Float64} =
        Dict(tier_1_cah_sole_community => 1.45,
             tier_2_rural_hospital     => 1.30,
             tier_3_safety_net_urban   => 1.20,
             tier_4_all_eligible       => 1.12)
    mco_capitation_add_on_pmpm::Float64     = 0.0
    upl_ceiling_pct::Float64                = 1.00
end

# ─────────────────────────────────────────────────────────────────────────────
# Eligibility classification
# ─────────────────────────────────────────────────────────────────────────────

"""
    sdp_eligibility_tier(hospital::SDPHospitalInputs, sdp_type::SDPType) -> SDPEligibilityTier

Determine a hospital's SDP eligibility tier based on its characteristics.
"""
function sdp_eligibility_tier(hospital::SDPHospitalInputs, sdp_type::SDPType)::SDPEligibilityTier
    if sdp_type == rural_cah_directed
        # Rural/CAH SDP: tier by hospital type
        (hospital.is_cah || hospital.is_sole_community) && return tier_1_cah_sole_community
        hospital.hospital_type == :rural_pps && return tier_2_rural_hospital
        return tier_4_all_eligible
    elseif sdp_type == safety_net_directed
        hospital.hospital_type == :dsh && return tier_3_safety_net_urban
        return tier_4_all_eligible
    else
        # ATB: all hospitals at tier_4; CAHs at tier_1
        (hospital.is_cah || hospital.is_sole_community) && return tier_1_cah_sole_community
        return tier_4_all_eligible
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# SDP calculation
# ─────────────────────────────────────────────────────────────────────────────

"""
    SDPPaymentResult

SDP payment calculation result for one hospital.

# Fields
- `hospital_id`
- `hospital_name::String`
- `eligibility_tier::SDPEligibilityTier`
- `ip_directed_rate_multiplier::Float64`
- `op_directed_rate_multiplier::Float64`
- `directed_ip_payment_annual::Float64`: Additional IP payment above base MCO rate.
- `directed_op_payment_annual::Float64`
- `total_directed_payment::Float64`: IP + OP combined.
- `base_mcaid_payment_annual::Float64`: Current MCO base payment (IP + OP).
- `total_mcaid_payment_with_sdp::Float64`: After directed payment.
- `upl_ceiling_ip::Float64`: Maximum IP payment under UPL.
- `upl_ceiling_op::Float64`
- `upl_compliant::Bool`: Whether total payment is within UPL.
- `upl_headroom_ip::Float64`: IP savings before hitting UPL ceiling.
- `upl_headroom_op::Float64`
- `effective_medicaid_rate_improvement_pct::Float64`
"""
struct SDPPaymentResult
    hospital_id::Any
    hospital_name::String
    eligibility_tier::SDPEligibilityTier
    ip_directed_rate_multiplier::Float64
    op_directed_rate_multiplier::Float64
    directed_ip_payment_annual::Float64
    directed_op_payment_annual::Float64
    total_directed_payment::Float64
    base_mcaid_payment_annual::Float64
    total_mcaid_payment_with_sdp::Float64
    upl_ceiling_ip::Float64
    upl_ceiling_op::Float64
    upl_compliant::Bool
    upl_headroom_ip::Float64
    upl_headroom_op::Float64
    effective_medicaid_rate_improvement_pct::Float64
end

"""
    calculate_sdp_payment(
        hospital::SDPHospitalInputs,
        program::SDPProgramInputs
    ) -> SDPPaymentResult

Calculate Medicaid SDP payments for a hospital.

## Algorithm
1. Determine eligibility tier.
2. Directed payment = base_MCO_payment × (multiplier − 1) × volume.
   i.e. the MCO is directed to pay `multiplier × base` instead of `base`.
3. UPL test: directed payment + base ≤ Medicare equivalent.
4. Cap at UPL if needed.

# Example
```julia
hospital = SDPHospitalInputs(
    hospital_id = "001",
    hospital_name = "Valley CAH",
    is_cah = true,
    medicaid_managed_care_days = 820,
    medicaid_mc_op_visits = 4_200,
    current_mcaid_base_payment_ip = 650.0,   # \$650/day currently
    current_mcaid_base_payment_op = 85.0,    # \$85/visit currently
    medicare_ip_payment_rate = 1_800.0,      # Medicare FFS equivalent
    medicare_op_payment_rate = 180.0,
)
program = SDPProgramInputs(sdp_type=rural_cah_directed, state="KS")
r = calculate_sdp_payment(hospital, program)
r.total_directed_payment   # ~\$220,000 additional annual Medicaid revenue
```
"""
function calculate_sdp_payment(
    hospital::SDPHospitalInputs,
    program::SDPProgramInputs,
)::SDPPaymentResult

    tier = sdp_eligibility_tier(hospital, program.sdp_type)

    ip_mult = get(program.ip_directed_rate_multiplier, tier, 1.0)
    op_mult = get(program.op_directed_rate_multiplier, tier, 1.0)

    # Base MCO payments
    base_ip = hospital.current_mcaid_base_payment_ip * hospital.medicaid_managed_care_days
    base_op = hospital.current_mcaid_base_payment_op * hospital.medicaid_mc_op_visits

    # Directed payment = base × (multiplier − 1) × volume  [the *additional* amount]
    directed_ip = base_ip * (ip_mult - 1.0)
    directed_op = base_op * (op_mult - 1.0)

    total_directed = directed_ip + directed_op
    total_base     = base_ip + base_op
    total_with_sdp = total_base + total_directed

    # UPL ceiling (Medicare rate × volume × upl_ceiling_pct)
    upl_ip = hospital.medicare_ip_payment_rate *
             hospital.medicaid_managed_care_days * program.upl_ceiling_pct
    upl_op = hospital.medicare_op_payment_rate *
             hospital.medicaid_mc_op_visits * program.upl_ceiling_pct

    # Check compliance
    total_with_sdp_ip = base_ip + directed_ip
    total_with_sdp_op = base_op + directed_op
    upl_ok_ip = upl_ip <= 0 || total_with_sdp_ip <= upl_ip
    upl_ok_op = upl_op <= 0 || total_with_sdp_op <= upl_op
    upl_compliant = upl_ok_ip && upl_ok_op

    # If not compliant, cap
    if !upl_ok_ip && upl_ip > 0
        directed_ip = max(0.0, upl_ip - base_ip)
    end
    if !upl_ok_op && upl_op > 0
        directed_op = max(0.0, upl_op - base_op)
    end
    total_directed = directed_ip + directed_op

    headroom_ip = max(0.0, upl_ip - (base_ip + directed_ip))
    headroom_op = max(0.0, upl_op - (base_op + directed_op))

    eff_improvement = total_base > 0 ? total_directed / total_base * 100 : 0.0

    SDPPaymentResult(
        hospital.hospital_id, hospital.hospital_name, tier,
        ip_mult, op_mult,
        directed_ip, directed_op, total_directed,
        total_base, total_base + total_directed,
        upl_ip, upl_op, upl_compliant,
        headroom_ip, headroom_op,
        eff_improvement,
    )
end

"""
    sdp_portfolio_analysis(
        hospitals::Vector{SDPHospitalInputs},
        program::SDPProgramInputs
    ) -> NamedTuple

Run SDP analysis for a portfolio of hospitals (e.g. all hospitals in a state
or a regional system).

# Returns
- `results::Vector{SDPPaymentResult}`: sorted by total_directed_payment desc.
- `total_directed_statewide::Float64`
- `n_upl_constrained::Int`
- `tier_summary::Dict`
"""
function sdp_portfolio_analysis(
    hospitals::Vector{SDPHospitalInputs},
    program::SDPProgramInputs,
)
    results = [calculate_sdp_payment(h, program) for h in hospitals]
    sort!(results; by=r -> -r.total_directed_payment)

    total_directed = sum(r.total_directed_payment for r in results)
    n_constrained  = count(r -> !r.upl_compliant, results)

    tier_summ = Dict{SDPEligibilityTier,NamedTuple}()
    for tier in instances(SDPEligibilityTier)
        subset = filter(r -> r.eligibility_tier == tier, results)
        isempty(subset) && continue
        tier_summ[tier] = (
            n_hospitals         = length(subset),
            total_directed      = sum(r.total_directed_payment for r in subset),
            avg_improvement_pct = mean(r.effective_medicaid_rate_improvement_pct for r in subset),
        )
    end

    (
        results             = results,
        total_directed_statewide = total_directed,
        n_hospitals         = length(results),
        n_upl_constrained   = n_constrained,
        n_cah_eligible      = count(r -> r.eligibility_tier == tier_1_cah_sole_community, results),
        tier_summary        = tier_summ,
    )
end
