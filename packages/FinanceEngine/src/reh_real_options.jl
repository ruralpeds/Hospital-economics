"""
    reh_real_options.jl — REH Conversion Decision Tree (MBA Gap B-04)

Real options decision framework for CAH-to-REH conversion.

The Rural Emergency Hospital (REH) designation (created by CAA 2021 §125,
effective Jan 2023) offers an alternative to full CAH closure. Key differences:
  - REH: 24/7 ED + observation ≤ 24h only; NO inpatient beds
  - REH payment: OPPS rates + 5% + monthly facility payment ($295,135/month FY2026)
  - CAH: 101% of reasonable cost; unlimited inpatient; swing beds allowed

Decision tree options:
  1. Stay as CAH — current status quo
  2. Convert to REH now — give up inpatient, gain facility payment
  3. Convert to REH later — option value of waiting (deferral option)
  4. Close — zero option, community loses access

References:
- CAA 2021, § 125 (42 U.S.C. § 1395x(kkk)).
- CMS REH Final Rule (CMS-1765-F), 87 FR 71752, Nov 23 2022.
- Chartis Center for Rural Health (2023). REH: Early Adopter Analysis.
"""

using Statistics; using Printf

const REH_MONTHLY_FACILITY_PAYMENT_FY2026 = 295_135.0
const REH_OPPS_PREMIUM_PCT                = 0.05   # 5% above standard OPPS
const CAH_COST_REIMBURSEMENT_PCT          = 1.01   # 101% of reasonable cost

@kwdef struct CAHFinancialProfile
    hospital_name::String
    annual_ed_visits::Int
    annual_inpatient_discharges::Int
    annual_observation_stays::Int          = 0
    net_patient_revenue_cah::Float64       # current CAH total revenue
    inpatient_revenue_pct::Float64 = 0.35  # fraction of revenue from inpatient
    ed_outpatient_revenue_pct::Float64 = 0.55
    swing_bed_revenue_pct::Float64 = 0.10
    total_operating_expenses::Float64
    inpatient_variable_cost_pct::Float64 = 0.60  # % of inpatient costs that are variable
    opps_rate_per_ed_visit::Float64 = 185.0      # current OPPS equivalent
    cah_cost_report_loss::Float64 = 0.0          # annual shortfall if negative margin
end

struct REHConversionResult
    hospital_name::String
    # CAH baseline
    cah_annual_revenue::Float64
    cah_annual_expenses::Float64
    cah_operating_margin::Float64
    # REH scenario
    reh_ed_opps_revenue::Float64
    reh_facility_payment_annual::Float64
    reh_total_revenue::Float64
    reh_saved_inpatient_costs::Float64
    reh_operating_expenses::Float64
    reh_operating_margin::Float64
    # Comparison
    annual_revenue_delta::Float64
    annual_margin_delta::Float64
    breakeven_ed_visits::Int
    recommendation::Symbol           # :convert_now, :wait, :stay_cah, :close_evaluate
    npv_conversion_5yr::Float64
    inpatient_community_impact::String
end

"""
    analyze_cah_to_reh_conversion(profile::CAHFinancialProfile;
        wacc, n_years, volume_growth) -> REHConversionResult

Analyse whether a CAH should convert to REH designation.

Key trade-off:
  + REH gains: monthly facility payment (~\$3.5M/yr) + OPPS 5% premium
  - REH loses: inpatient Medicare cost-based reimbursement + swing bed SNF revenue

The decision hinges on: Is the monthly facility payment > lost inpatient margin?
"""
function analyze_cah_to_reh_conversion(
    profile::CAHFinancialProfile;
    wacc::Float64           = 0.07,
    n_years::Int            = 5,
    volume_growth::Float64  = 0.01,
)::REHConversionResult

    # CAH baseline
    cah_rev  = profile.net_patient_revenue_cah
    cah_exp  = profile.total_operating_expenses
    cah_margin = (cah_rev - cah_exp) / cah_rev

    # REH revenue components
    ed_opps  = profile.annual_ed_visits *
               profile.opps_rate_per_ed_visit * (1 + REH_OPPS_PREMIUM_PCT)
    facility = REH_MONTHLY_FACILITY_PAYMENT_FY2026 * 12
    reh_rev  = ed_opps + facility

    # REH expenses: eliminate variable inpatient costs
    inpatient_total_cost = cah_exp * profile.inpatient_revenue_pct
    saved_var_costs      = inpatient_total_cost * profile.inpatient_variable_cost_pct
    reh_exp              = cah_exp - saved_var_costs
    reh_margin           = reh_rev > 0 ? (reh_rev - reh_exp) / reh_rev : -1.0

    # Deltas
    rev_delta    = reh_rev - cah_rev
    margin_delta = (reh_rev - reh_exp) - (cah_rev - cah_exp)

    # Break-even: how many ED visits needed for REH to equal CAH revenue?
    # reh_rev = ed_visits × opps_rate × 1.05 + facility
    # → ed_visits = (cah_rev - facility) / (opps_rate × 1.05)
    be_visits = max(0, round(Int,
        (cah_rev - facility) / (profile.opps_rate_per_ed_visit * (1 + REH_OPPS_PREMIUM_PCT))))

    # 5-year NPV of conversion
    pv = 0.0
    for yr in 1:n_years
        annual_benefit = margin_delta * (1 + volume_growth)^yr
        pv += annual_benefit / (1 + wacc)^yr
    end

    # Recommendation logic
    rec = if margin_delta > 200_000 && profile.annual_inpatient_discharges < 400
        :convert_now        # large gain, low inpatient volume (not much to lose)
    elseif margin_delta > 0 && profile.annual_inpatient_discharges < 800
        :convert_now
    elseif margin_delta > -100_000 && profile.cah_cost_report_loss < 0
        :wait               # marginal; deferral option has value
    elseif cah_margin < -0.05
        :close_evaluate     # deeply distressed; REH alone may not save it
    else
        :stay_cah
    end

    community_note = profile.annual_inpatient_discharges > 600 ?
        "High inpatient volume ($(profile.annual_inpatient_discharges) d/c/yr) — conversion would eliminate inpatient access for significant community need" :
        "Low inpatient volume ($(profile.annual_inpatient_discharges) d/c/yr) — community impact of losing inpatient beds is moderate"

    REHConversionResult(
        profile.hospital_name,
        cah_rev, cah_exp, cah_margin,
        ed_opps, facility, reh_rev, saved_var_costs, reh_exp, reh_margin,
        rev_delta, margin_delta, be_visits, rec, pv, community_note,
    )
end
