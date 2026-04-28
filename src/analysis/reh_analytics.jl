"""
    reh_analytics.jl — Rural Emergency Hospital Analytics Module (T-029)

Consolidates REH-specific financial analyses previously scattered across
`risk/conversion.jl`, `finance/reimbursement.jl`, `finance/rhc_optimization.jl`,
and the `vbc_transition.jl` model variants into a single, queryable module.

Key capabilities:
- Monthly facility payment calculation (FY2026 rates)
- Outpatient add-on (5%) computation
- CAH → REH conversion NPV / break-even analysis
- REH viability scoring (composite)
- Annual budget projection (5-year)
- REH eligibility screening

All dollar figures in USD. All rates are CY/FY 2026 unless noted.
"""

using Dates
using Statistics

# ─────────────────────────────────────────────────────────────────────────────
# CMS REH Payment Constants (FY 2026)
# ─────────────────────────────────────────────────────────────────────────────

"""Monthly REH facility payment — CMS FY2026 rule (42 CFR § 485.508)."""
const REH_MONTHLY_FACILITY_PAYMENT_FY2026 = 295_000.00

"""REH outpatient add-on above standard OPPS rate."""
const REH_OUTPATIENT_ADDON_RATE = 0.05

"""Maximum swing beds allowed at REH (for observation / skilled-nursing use)."""
const REH_MAX_SWING_BEDS = 10

"""Minimum years as CAH or small rural PPS before REH conversion eligible."""
const REH_MIN_PRIOR_YEARS = 1

# ─────────────────────────────────────────────────────────────────────────────
# REH Parameters struct
# ─────────────────────────────────────────────────────────────────────────────

"""
    REHParams

All parameters needed to compute REH financials.

# Fields
- `annual_ed_visits::Int`: Emergency department visits per year.
- `annual_outpatient_visits::Int`: Non-ED outpatient visits.
- `avg_revenue_per_ed_visit::Float64`: Net revenue per ED visit (USD).
- `avg_revenue_per_outpatient_visit::Float64`: Net revenue per OP visit (USD).
- `annual_operating_expenses::Float64`: Total operating expenses ex-facility payment.
- `conversion_capex::Float64`: One-time capital cost to convert to REH.
- `swing_bed_days::Int`: Annual swing-bed patient days (≤ REH_MAX_SWING_BEDS × 365).
- `avg_swing_bed_revenue_per_day::Float64`: Net revenue per swing-bed day.
- `fiscal_year::Int`: Projection year (for rate updates).
- `months_operating::Int = 12`: Partial-year adjustment (1–12).
"""
@kwdef struct REHParams
    annual_ed_visits::Int
    annual_outpatient_visits::Int
    avg_revenue_per_ed_visit::Float64
    avg_revenue_per_outpatient_visit::Float64
    annual_operating_expenses::Float64
    conversion_capex::Float64          = 0.0
    swing_bed_days::Int                = 0
    avg_swing_bed_revenue_per_day::Float64 = 0.0
    fiscal_year::Int                   = 2026
    months_operating::Int              = 12
end

# ─────────────────────────────────────────────────────────────────────────────
# Core REH financial calculations
# ─────────────────────────────────────────────────────────────────────────────

"""
    reh_facility_payment(params::REHParams) -> Float64

Annual REH facility payment from CMS (prorated for partial years).

FY2026: \$295,000/month × `params.months_operating`.
"""
function reh_facility_payment(params::REHParams)::Float64
    REH_MONTHLY_FACILITY_PAYMENT_FY2026 * params.months_operating
end

"""
    reh_outpatient_addon(params::REHParams) -> Float64

Incremental revenue from the 5% REH outpatient add-on above OPPS rates.
Applied to both ED visits and outpatient visits.
"""
function reh_outpatient_addon(params::REHParams)::Float64
    total_visit_revenue = (params.annual_ed_visits * params.avg_revenue_per_ed_visit +
                           params.annual_outpatient_visits * params.avg_revenue_per_outpatient_visit)
    total_visit_revenue * REH_OUTPATIENT_ADDON_RATE * (params.months_operating / 12)
end

"""
    reh_swing_bed_revenue(params::REHParams) -> Float64

Revenue from optional REH swing-bed program (up to `REH_MAX_SWING_BEDS` beds).
Returns 0 if `swing_bed_days == 0`.
"""
function reh_swing_bed_revenue(params::REHParams)::Float64
    params.swing_bed_days == 0 && return 0.0
    max_days = REH_MAX_SWING_BEDS * 365
    actual_days = min(params.swing_bed_days, max_days)
    actual_days * params.avg_swing_bed_revenue_per_day * (params.months_operating / 12)
end

"""
    reh_total_revenue(params::REHParams) -> Float64

Total REH revenue = visit revenue + facility payment + outpatient add-on + swing beds.
"""
function reh_total_revenue(params::REHParams)::Float64
    visit_rev = (params.annual_ed_visits * params.avg_revenue_per_ed_visit +
                 params.annual_outpatient_visits * params.avg_revenue_per_outpatient_visit) *
                (params.months_operating / 12)
    visit_rev + reh_facility_payment(params) + reh_outpatient_addon(params) +
    reh_swing_bed_revenue(params)
end

"""
    reh_operating_margin(params::REHParams) -> Float64

REH operating margin = (total_revenue - operating_expenses) / total_revenue.
"""
function reh_operating_margin(params::REHParams)::Float64
    rev = reh_total_revenue(params)
    rev <= 0 && return -Inf
    (rev - params.annual_operating_expenses * (params.months_operating / 12)) / rev
end

"""
    reh_annual_summary(params::REHParams) -> NamedTuple

Complete annual financial summary for an REH.

# Returns fields
- `total_revenue`, `facility_payment`, `outpatient_addon`, `swing_bed_revenue`
- `visit_revenue`, `operating_expenses`, `operating_income`, `operating_margin`
- `revenue_per_ed_visit` (all-in, including facility payment allocation)
"""
function reh_annual_summary(params::REHParams)
    facility  = reh_facility_payment(params)
    addon     = reh_outpatient_addon(params)
    swing     = reh_swing_bed_revenue(params)
    visit_rev = (params.annual_ed_visits * params.avg_revenue_per_ed_visit +
                 params.annual_outpatient_visits * params.avg_revenue_per_outpatient_visit) *
                (params.months_operating / 12)
    total_rev = visit_rev + facility + addon + swing
    expenses  = params.annual_operating_expenses * (params.months_operating / 12)
    op_income = total_rev - expenses

    total_visits = params.annual_ed_visits + params.annual_outpatient_visits
    rev_per_visit = total_visits > 0 ? total_rev / total_visits : 0.0

    (
        total_revenue         = total_rev,
        facility_payment      = facility,
        outpatient_addon      = addon,
        swing_bed_revenue     = swing,
        visit_revenue         = visit_rev,
        operating_expenses    = expenses,
        operating_income      = op_income,
        operating_margin      = total_rev > 0 ? op_income / total_rev : NaN,
        revenue_per_visit     = rev_per_visit,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# 5-year projection
# ─────────────────────────────────────────────────────────────────────────────

"""
    reh_projection(params::REHParams; years=5, visit_growth=0.01, expense_inflation=0.03,
                   facility_payment_inflation=0.02) -> Vector{NamedTuple}

Project REH financials over `years` years. Each year returns the fields from
`reh_annual_summary` plus `:year` and `:cumulative_operating_income`.
"""
function reh_projection(
    params::REHParams;
    years::Int = 5,
    visit_growth::Float64           = 0.01,
    expense_inflation::Float64      = 0.03,
    facility_payment_inflation::Float64 = 0.02,
)::Vector{NamedTuple}

    rows = NamedTuple[]
    cumulative = 0.0
    ed_visits   = Float64(params.annual_ed_visits)
    op_visits   = Float64(params.annual_outpatient_visits)
    expenses    = params.annual_operating_expenses
    fmp         = REH_MONTHLY_FACILITY_PAYMENT_FY2026

    for yr in 1:years
        yr_params = REHParams(
            annual_ed_visits              = round(Int, ed_visits),
            annual_outpatient_visits      = round(Int, op_visits),
            avg_revenue_per_ed_visit      = params.avg_revenue_per_ed_visit,
            avg_revenue_per_outpatient_visit = params.avg_revenue_per_outpatient_visit,
            annual_operating_expenses     = expenses,
            swing_bed_days                = params.swing_bed_days,
            avg_swing_bed_revenue_per_day = params.avg_swing_bed_revenue_per_day,
            fiscal_year                   = params.fiscal_year + yr - 1,
            months_operating              = 12,
        )
        # Override facility payment for year
        raw = reh_annual_summary(yr_params)
        fmp_adj = fmp * (1 + facility_payment_inflation)^(yr - 1) * 12
        adj_total = raw.visit_revenue + fmp_adj + raw.outpatient_addon + raw.swing_bed_revenue
        op_income = adj_total - raw.operating_expenses
        cumulative += op_income
        push!(rows, merge(raw, (
            year                       = params.fiscal_year + yr - 1,
            facility_payment           = fmp_adj,
            total_revenue              = adj_total,
            operating_income           = op_income,
            operating_margin           = adj_total > 0 ? op_income / adj_total : NaN,
            cumulative_operating_income = cumulative,
        )))

        ed_visits *= (1 + visit_growth)
        op_visits *= (1 + visit_growth)
        expenses  *= (1 + expense_inflation)
        fmp        = fmp * (1 + facility_payment_inflation)
    end
    rows
end

# ─────────────────────────────────────────────────────────────────────────────
# CAH → REH conversion analysis
# ─────────────────────────────────────────────────────────────────────────────

"""
    REHConversionAnalysis

Output of `analyze_cah_to_reh_conversion`.

# Fields
- `reh_summary::NamedTuple`: Annual REH financials if converted.
- `conversion_capex::Float64`
- `payback_years::Float64`: Simple payback on capex from annual operating income delta.
- `five_year_npv::Float64`: NPV of 5-year REH projection minus CAH baseline, at `discount_rate`.
- `break_even_ed_visits::Int`: Minimum annual ED visits for positive operating income.
- `is_financially_viable::Bool`: `true` if 5-year NPV > 0 and operating margin > 0.
- `viability_score::Float64`: Composite 0–100 score (see `reh_viability_score`).
"""
struct REHConversionAnalysis
    reh_summary::NamedTuple
    conversion_capex::Float64
    payback_years::Float64
    five_year_npv::Float64
    break_even_ed_visits::Int
    is_financially_viable::Bool
    viability_score::Float64
end

"""
    analyze_cah_to_reh_conversion(
        reh_params;
        cah_annual_operating_income = 0.0,
        discount_rate = 0.05
    ) -> REHConversionAnalysis

Full CAH → REH conversion feasibility analysis.

# Arguments
- `reh_params::REHParams`: REH operating parameters post-conversion.
- `cah_annual_operating_income::Float64`: CAH status-quo annual operating income
  (used to compute the incremental benefit of conversion).
- `discount_rate::Float64 = 0.05`: WACC / discount rate for NPV calculation.
"""
function analyze_cah_to_reh_conversion(
    reh_params::REHParams;
    cah_annual_operating_income::Float64 = 0.0,
    discount_rate::Float64 = 0.05,
)::REHConversionAnalysis

    summary = reh_annual_summary(reh_params)
    projection = reh_projection(reh_params)

    # Simple payback
    annual_increment = summary.operating_income - cah_annual_operating_income
    payback = reh_params.conversion_capex <= 0 ? 0.0 :
              annual_increment > 0 ? reh_params.conversion_capex / annual_increment : Inf

    # 5-year NPV of incremental income minus capex
    npv = -reh_params.conversion_capex
    for (yr, row) in enumerate(projection)
        increment = row.operating_income - cah_annual_operating_income
        npv += increment / (1 + discount_rate)^yr
    end

    # Break-even ED visits (holding all else fixed)
    # Solve: rev_per_visit * n + facility + addon_rate*(n*rev_per_visit) = expenses
    # n * rev_per_visit * (1 + addon_rate) + facility = expenses
    # n = (expenses - facility) / (rev_per_visit * (1 + addon_rate))
    facility_annual = reh_facility_payment(reh_params)
    rev_per_ed = reh_params.avg_revenue_per_ed_visit * (1 + REH_OUTPATIENT_ADDON_RATE)
    be_visits = rev_per_ed > 0 ?
        max(0, ceil(Int, (reh_params.annual_operating_expenses - facility_annual) / rev_per_ed)) :
        typemax(Int)

    viable = npv > 0 && summary.operating_margin > 0
    score  = reh_viability_score(reh_params, summary)

    REHConversionAnalysis(summary, reh_params.conversion_capex, payback, npv, be_visits, viable, score)
end

"""
    reh_viability_score(params::REHParams, summary=nothing) -> Float64

Composite REH viability score on a 0–100 scale. Higher = more viable.

| Component | Weight | Scoring |
|---|---|---|
| Operating margin | 30 | >10% → 30; >5% → 20; >0% → 10; ≤0 → 0 |
| ED visit volume | 25 | >6000 → 25; >4000 → 18; >2000 → 10; else 0 |
| Facility payment coverage | 25 | Facility payment / expenses > 60% → 25; >40% → 18; >20% → 10; else 0 |
| Swing-bed utilization | 20 | Swing-bed revenue > 0 → 10 + up to 10 for volume |
"""
function reh_viability_score(
    params::REHParams,
    summary::Union{NamedTuple, Nothing} = nothing,
)::Float64
    s = isnothing(summary) ? reh_annual_summary(params) : summary

    # Operating margin (30 pts)
    margin_pts = s.operating_margin > 0.10 ? 30.0 :
                 s.operating_margin > 0.05 ? 20.0 :
                 s.operating_margin > 0.00 ? 10.0 : 0.0

    # ED visit volume (25 pts)
    vol_pts = params.annual_ed_visits > 6_000 ? 25.0 :
              params.annual_ed_visits > 4_000 ? 18.0 :
              params.annual_ed_visits > 2_000 ? 10.0 : 0.0

    # Facility payment as fraction of total expenses (25 pts)
    frac = s.operating_expenses > 0 ? s.facility_payment / s.operating_expenses : 0.0
    fac_pts = frac > 0.60 ? 25.0 : frac > 0.40 ? 18.0 : frac > 0.20 ? 10.0 : 0.0

    # Swing-bed program (20 pts)
    swing_pts = params.swing_bed_days == 0 ? 0.0 :
                10.0 + min(10.0, params.swing_bed_days / 100.0)

    margin_pts + vol_pts + fac_pts + swing_pts
end

# ─────────────────────────────────────────────────────────────────────────────
# Eligibility screening
# ─────────────────────────────────────────────────────────────────────────────

"""
    reh_eligibility_check(;
        current_designation, licensed_beds, years_as_cah_or_small_rural,
        has_inpatient_services
    ) -> NamedTuple

Screen a hospital for REH eligibility per 42 CFR § 485.502.

# Returns
- `eligible::Bool`
- `reasons_ineligible::Vector{String}`
- `conditions::Vector{String}`: Conditions that must be met if converting.
"""
function reh_eligibility_check(;
    current_designation::Symbol,
    licensed_beds::Int,
    years_as_cah_or_small_rural::Int,
    has_inpatient_services::Bool,
)
    reasons_ineligible = String[]
    conditions = String[]

    current_designation in (:cah, :small_rural_pps, :pps_rural) ||
        push!(reasons_ineligible, "Must currently be a CAH or small rural PPS hospital " *
                                  "(got: $(current_designation))")

    years_as_cah_or_small_rural >= REH_MIN_PRIOR_YEARS ||
        push!(reasons_ineligible, "Must have operated as CAH or small rural PPS for " *
                                  "≥$REH_MIN_PRIOR_YEARS year(s)")

    if has_inpatient_services
        push!(conditions, "Must cease inpatient services upon REH designation " *
                          "(swing beds limited to $REH_MAX_SWING_BEDS beds)")
    end

    licensed_beds > 50 &&
        push!(reasons_ineligible, "CAH bed limit is 25 (got $licensed_beds); " *
                                  "only hospitals that were ≤ 50 beds as a rural PPS may convert")

    (
        eligible              = isempty(reasons_ineligible),
        reasons_ineligible    = reasons_ineligible,
        conditions            = conditions,
        max_swing_beds        = REH_MAX_SWING_BEDS,
        monthly_facility_payment = REH_MONTHLY_FACILITY_PAYMENT_FY2026,
    )
end
