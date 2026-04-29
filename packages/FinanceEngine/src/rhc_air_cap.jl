"""
    rhc_air_cap.jl — RHC All-Inclusive Rate Cap & CAA 2021 Phase-In (MBA Gap E-04)

Implements the Rural Health Clinic (RHC) payment cap mechanism introduced by
the Consolidated Appropriations Act of 2021 (CAA 2021, P.L. 116-260, § 122)
and its 7-year phase-in transition schedule.

## Background
Prior to CAA 2021, RHCs had no per-visit payment ceiling. Large provider-based
RHCs (hospital-owned) could receive unlimited per-visit payments under the
all-inclusive rate (AIR) methodology, creating significant Medicare expenditure
growth. The CAA 2021 imposed a cap with a 7-year phase-in for existing RHCs.

## Payment types
1. **Independent RHCs** — always had a statutory cap; CAA 2021 adjusts amounts.
2. **Provider-based RHCs** (hospital-owned) — historically uncapped; CAA 2021
   introduces new per-visit caps phased in 2022-2028.

## The AIR mechanism
RHCs are paid on an all-inclusive per-visit basis:
  payment = min(actual_clinic_costs / visits, cap_amount) × covered_visits × 0.80

Where:
  - actual_clinic_costs / visits = the RHC's calculated AIR
  - cap_amount = the applicable per-visit cap for the payment year
  - 0.80 = Medicare pays 80% (20% patient cost-share or coinsurance)
  - A "visit" = one face-to-face encounter with a qualifying RHC practitioner

## CAA 2021 Phase-in Schedule (Provider-based RHCs)
  CY2022: $100.00 per visit cap
  CY2023: $113.00 per visit
  CY2024: $126.00 per visit
  CY2025: $152.00 per visit (CMS CY2025 PFS Final Rule)
  CY2026: est. $158.00 per visit
  CY2027: est. $164.00 per visit
  CY2028+: Fully phased-in cap (same as independent RHC + market basket updates)

## Independent RHC Cap
  CY2024: $113.17 per visit (updated annually by MEI index)
  CY2025: $118.08 per visit
  CY2026: est. $122.76 per visit

References:
- CAA 2021 P.L. 116-260, § 122.
- CMS MLN Matters MM12250 (CAA 2021 RHC changes).
- CMS CY2025 Physician Fee Schedule Final Rule (CMS-1807-F).
- CMS FQHC/RHC Payment Comparison Table (updated annually).
- 42 CFR § 405.2462, 405.2464.
"""

using Printf

# ─────────────────────────────────────────────────────────────────────────────
# CAA 2021 per-visit cap schedule
# ─────────────────────────────────────────────────────────────────────────────

"""
    CAA2021_PROVIDER_BASED_CAPS

CAA 2021 per-visit payment caps for provider-based RHCs.
Keys: calendar year → cap amount per visit (USD).
Sources: CMS CY2024 and CY2025 PFS Final Rules; CY2026+ estimated.
"""
const CAA2021_PROVIDER_BASED_CAPS = Dict{Int,Float64}(
    2022 => 100.00,
    2023 => 113.00,
    2024 => 126.00,
    2025 => 152.00,   # CMS CY2025 PFS Final Rule (CMS-1807-F)
    2026 => 158.08,   # estimated (CY2025 × 1.04 MB update)
    2027 => 164.40,   # estimated
    2028 => 171.00,   # estimated (convergence with independent cap)
)

"""
    INDEPENDENT_RHC_CAPS

Annual per-visit caps for independent (non-hospital-owned) RHCs.
Keys: calendar year → cap amount (USD).
Updated annually by the Medicare Economic Index (MEI).
"""
const INDEPENDENT_RHC_CAPS = Dict{Int,Float64}(
    2020 => 86.31,
    2021 => 87.52,
    2022 => 92.23,
    2023 => 107.83,
    2024 => 113.17,
    2025 => 118.08,
    2026 => 122.76,   # estimated +4.0% MEI
    2027 => 127.67,   # estimated
)

"""
    MEDICARE_COINSURANCE_RATE

Medicare pays 80% of the covered RHC charge; patient/supplemental covers 20%.
"""
const MEDICARE_COINSURANCE_RATE = 0.80

# ─────────────────────────────────────────────────────────────────────────────
# RHC types
# ─────────────────────────────────────────────────────────────────────────────

"""
    RHCType

RHC ownership classification for cap determination.
- `:independent`: Freestanding RHC not owned by a hospital; MEI-indexed cap applies.
- `:provider_based`: Hospital-owned RHC subject to CAA 2021 phase-in caps.
- `:grandfathered`: Provider-based RHCs that existed before CAA 2021 and were
  operating under a different agreement; special transition rules apply.
"""
@enum RHCType independent=1 provider_based=2 grandfathered=3

# ─────────────────────────────────────────────────────────────────────────────
# Payment inputs and results
# ─────────────────────────────────────────────────────────────────────────────

"""
    RHCAIRInputs

Inputs for the RHC AIR cap calculation.

# Fields
- `rhc_id::Any`
- `rhc_type::RHCType`
- `calendar_year::Int`
- `total_allowable_costs::Float64`: Annual total RHC allowable costs (USD).
- `total_visits::Int`: Total covered Medicare visits.
- `medicare_visits::Int`: Medicare-covered visits (subset of total_visits).
- `medicaid_visits::Int`: Medicaid-covered visits.
- `uncompensated_care_visits::Int`: Charity/uncompensated visits.
- `pre_caa_air::Float64`: Calculated AIR per visit before cap
  (= allowable costs / total visits). If 0.0, computed from cost/visit.
"""
@kwdef struct RHCAIRInputs
    rhc_id::Any
    rhc_type::RHCType
    calendar_year::Int
    total_allowable_costs::Float64
    total_visits::Int
    medicare_visits::Int
    medicaid_visits::Int              = 0
    uncompensated_care_visits::Int    = 0
    pre_caa_air::Float64              = 0.0   # computed if not provided
end

"""
    RHCAIRPaymentResult

Result of the RHC AIR cap payment calculation.

# Fields
- `rhc_id`
- `calendar_year::Int`
- `rhc_type::RHCType`
- `calculated_air_per_visit::Float64`: Actual AIR = allowable costs / total visits.
- `applicable_cap::Float64`: The cap that applies for this year/type.
- `effective_rate_per_visit::Float64`: `min(calculated_air, applicable_cap)`.
- `is_capped::Bool`: Whether the AIR exceeds the cap.
- `cap_impact_per_visit::Float64`: Revenue reduction per visit from cap (0 if uncapped).
- `medicare_payment::Float64`: Total Medicare payment (80% × effective_rate × medicare_visits).
- `uncapped_medicare_payment::Float64`: What payment would be without the cap.
- `annual_cap_impact::Float64`: Total annual revenue reduction from cap.
- `phase_in_year::Int`: Which year of the 7-year phase-in (1=2022, 7=2028).
- `final_cap::Float64`: The fully-phased-in cap (after 2028).
- `additional_revenue_at_full_phase_in::Float64`: Revenue change when fully phased in.
"""
struct RHCAIRPaymentResult
    rhc_id::Any
    calendar_year::Int
    rhc_type::RHCType
    calculated_air_per_visit::Float64
    applicable_cap::Float64
    effective_rate_per_visit::Float64
    is_capped::Bool
    cap_impact_per_visit::Float64
    medicare_payment::Float64
    uncapped_medicare_payment::Float64
    annual_cap_impact::Float64
    phase_in_year::Int
    final_cap::Float64
    additional_revenue_at_full_phase_in::Float64
end

# ─────────────────────────────────────────────────────────────────────────────
# Core calculation
# ─────────────────────────────────────────────────────────────────────────────

"""
    rhc_applicable_cap(rhc_type::RHCType, year::Int) -> Float64

Return the applicable per-visit cap for an RHC in a given calendar year.
"""
function rhc_applicable_cap(rhc_type::RHCType, year::Int)::Float64
    if rhc_type == independent
        # Independent RHC: MEI-indexed cap; extrapolate beyond table
        max_year = maximum(keys(INDEPENDENT_RHC_CAPS))
        year <= max_year && return INDEPENDENT_RHC_CAPS[year]
        # Extrapolate at 4% annual MEI
        return INDEPENDENT_RHC_CAPS[max_year] * (1.04^(year - max_year))
    else
        # Provider-based: CAA 2021 phase-in cap
        max_year = maximum(keys(CAA2021_PROVIDER_BASED_CAPS))
        year <= max_year && return CAA2021_PROVIDER_BASED_CAPS[year]
        # Post-phase-in: same as independent cap (convergence)
        return rhc_applicable_cap(independent, year)
    end
end

"""
    calculate_rhc_air_payment(inputs::RHCAIRInputs) -> RHCAIRPaymentResult

Compute the RHC AIR Medicare payment for a given year including the CAA 2021 cap.

## Algorithm (42 CFR § 405.2462)
1. Compute actual AIR = total_allowable_costs / total_visits.
   (Or use pre_caa_air if provided.)
2. Apply the year-specific cap: effective_rate = min(AIR, cap).
3. Medicare payment = effective_rate × medicare_visits × 0.80.

# Example
```julia
inputs = RHCAIRInputs(
    rhc_id              = "Valley RHC",
    rhc_type            = provider_based,
    calendar_year       = 2025,
    total_allowable_costs = 1_250_000.0,
    total_visits        = 6_800,
    medicare_visits     = 3_900,
)
r = calculate_rhc_air_payment(inputs)
r.is_capped            # true: AIR exceeds CY2025 \$152 cap
r.annual_cap_impact    # revenue reduction from cap
r.effective_rate_per_visit  # \$152.00 for provider-based CY2025
```
"""
function calculate_rhc_air_payment(inputs::RHCAIRInputs)::RHCAIRPaymentResult
    inputs.total_visits > 0 ||
        throw(ArgumentError("total_visits must be > 0"))

    # Actual calculated AIR
    actual_air = inputs.pre_caa_air > 0 ?
        inputs.pre_caa_air :
        inputs.total_allowable_costs / inputs.total_visits

    # Applicable cap for this type/year
    cap = rhc_applicable_cap(inputs.rhc_type, inputs.calendar_year)

    effective_rate = min(actual_air, cap)
    is_capped      = actual_air > cap
    cap_impact_pv  = max(0.0, actual_air - cap)

    # Medicare payment (80% of covered rate × Medicare visits)
    medicare_payment = effective_rate * inputs.medicare_visits * MEDICARE_COINSURANCE_RATE
    uncapped_payment = actual_air     * inputs.medicare_visits * MEDICARE_COINSURANCE_RATE
    annual_cap_impact = (uncapped_payment - medicare_payment)

    # Phase-in year (1 = first year 2022, 7 = last year 2028)
    phase_in_year = clamp(inputs.calendar_year - 2021, 0, 7)

    # Final (fully phased-in) cap after 2028
    final_cap = rhc_applicable_cap(inputs.rhc_type == independent ? independent : independent,
                                    max(2028, inputs.calendar_year))

    # Revenue change when fully phased in vs current year
    current_payment = medicare_payment
    final_payment   = min(actual_air, final_cap) * inputs.medicare_visits * MEDICARE_COINSURANCE_RATE
    rev_at_full_phase_in = final_payment - current_payment

    RHCAIRPaymentResult(
        inputs.rhc_id,
        inputs.calendar_year,
        inputs.rhc_type,
        actual_air,
        cap,
        effective_rate,
        is_capped,
        cap_impact_pv,
        medicare_payment,
        uncapped_payment,
        annual_cap_impact,
        phase_in_year,
        final_cap,
        rev_at_full_phase_in,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Multi-year projection
# ─────────────────────────────────────────────────────────────────────────────

"""
    rhc_cap_projection(
        inputs::RHCAIRInputs;
        years, volume_growth_rate
    ) -> Vector{RHCAIRPaymentResult}

Project RHC Medicare payments over multiple years accounting for:
1. The CAA 2021 phase-in schedule (cap increases annually through 2028).
2. Annual visit volume growth.
3. Annual cost inflation (assumed same as cap growth for simplicity).

Useful for planning: shows when the cap transitions and how payment
changes year-over-year as the phase-in matures.
"""
function rhc_cap_projection(
    inputs::RHCAIRInputs;
    years::AbstractRange = inputs.calendar_year:inputs.calendar_year+6,
    volume_growth_rate::Float64 = 0.015,
)::Vector{RHCAIRPaymentResult}
    results = RHCAIRPaymentResult[]
    visits  = inputs.total_visits
    mc_visits = inputs.medicare_visits
    costs   = inputs.total_allowable_costs

    for yr in years
        yr_inputs = RHCAIRInputs(
            rhc_id             = inputs.rhc_id,
            rhc_type           = inputs.rhc_type,
            calendar_year      = yr,
            total_allowable_costs = costs,
            total_visits       = round(Int, visits),
            medicare_visits    = round(Int, mc_visits),
            medicaid_visits    = inputs.medicaid_visits,
        )
        push!(results, calculate_rhc_air_payment(yr_inputs))

        # Grow volumes and costs for next year
        visits    = visits    * (1 + volume_growth_rate)
        mc_visits = mc_visits * (1 + volume_growth_rate)
        # Costs grow with the phase-in cap rate (simplified)
        cap_growth = rhc_applicable_cap(inputs.rhc_type, yr+1) /
                     rhc_applicable_cap(inputs.rhc_type, yr)
        costs = costs * cap_growth
    end
    results
end

"""
    rhc_caa2021_summary(rhc_id, rhc_type::RHCType;
                         start_year=2022, end_year=2028) -> String

Generate a formatted summary table of the CAA 2021 phase-in caps
for a given RHC type across all transition years.
"""
function rhc_caa2021_summary(
    rhc_id,
    rhc_type::RHCType;
    start_year::Int = 2022,
    end_year::Int   = 2028,
)::String
    io = IOBuffer()
    println(io, "CAA 2021 Phase-In Summary — RHC: $rhc_id")
    println(io, "Type: $(rhc_type == provider_based ? "Provider-Based" : "Independent")")
    println(io, "─"^55)
    println(io, @sprintf("%-8s %-12s %-12s %-10s", "Year", "Cap (\$/visit)", "Phase-In Yr", "Status"))
    println(io, "─"^55)
    for yr in start_year:end_year
        cap = rhc_applicable_cap(rhc_type, yr)
        phase = clamp(yr - 2021, 1, 7)
        status = yr <= 2028 ? "Transition" : "Final"
        println(io, @sprintf("%-8d %-12.2f %-12d %-10s", yr, cap, phase, status))
    end
    println(io, "─"^55)
    String(take!(io))
end
