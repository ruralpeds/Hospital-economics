"""
    physician_employment.jl — Physician Employment vs Independent Contractor Economics

Comprehensive analysis of physician employment models for rural hospitals,
comparing W-2 employment against independent contractor (1099) arrangements.

Provides:
1. All-in W-2 employer cost calculation (salary, benefits, FICA, malpractice, etc.)
2. Independent contractor total cost estimation
3. Side-by-side employment model comparison with breakeven wRVU analysis
4. 2024 MGMA salary benchmarks for common rural specialties
5. Physician ROI calculation with ramp-up period accounting
6. Staffing gap analysis by specialty
7. Compensation package design using MGMA percentile targets

References:
- MGMA DataDive Provider Compensation 2024 (based on 2023 data).
- Sullivan Cotter Physician Compensation & Productivity Survey 2024.
- AMGA Medical Group Compensation and Productivity Survey 2024.
"""

using Statistics
using Printf

# ─────────────────────────────────────────────────────────────────────────────
# 2024 MGMA Salary Benchmarks — Common Rural Specialties
# Source: MGMA DataDive Provider Compensation 2024 (based on 2023 survey data)
# All figures in USD; wRVU benchmarks are annual.
# ─────────────────────────────────────────────────────────────────────────────

"""
    MGMA_BENCHMARKS_2024

Embedded 2024 MGMA salary and wRVU benchmarks for common rural hospital
specialties.  Keys are canonical specialty names.  Each entry stores
salary percentiles (p25, median, p75, p90) and corresponding wRVU
benchmarks.
"""
const MGMA_BENCHMARKS_2024 = Dict{String,NamedTuple{
        (:salary_p25,:salary_median,:salary_p75,:salary_p90,
         :wrvu_p25,:wrvu_median,:wrvu_p75,:wrvu_p90),
        NTuple{8,Float64}}}(
    "Family Medicine" => (
        salary_p25=235_000.0, salary_median=265_000.0,
        salary_p75=305_000.0, salary_p90=340_000.0,
        wrvu_p25=3800.0, wrvu_median=4600.0, wrvu_p75=5400.0, wrvu_p90=6200.0,
    ),
    "Internal Medicine" => (
        salary_p25=250_000.0, salary_median=280_000.0,
        salary_p75=320_000.0, salary_p90=360_000.0,
        wrvu_p25=3600.0, wrvu_median=4400.0, wrvu_p75=5200.0, wrvu_p90=6000.0,
    ),
    "General Surgery" => (
        salary_p25=380_000.0, salary_median=430_000.0,
        salary_p75=500_000.0, salary_p90=570_000.0,
        wrvu_p25=5200.0, wrvu_median=6400.0, wrvu_p75=7800.0, wrvu_p90=9000.0,
    ),
    "OB/GYN" => (
        salary_p25=310_000.0, salary_median=350_000.0,
        salary_p75=405_000.0, salary_p90=465_000.0,
        wrvu_p25=5000.0, wrvu_median=6200.0, wrvu_p75=7400.0, wrvu_p90=8400.0,
    ),
    "Psychiatry" => (
        salary_p25=260_000.0, salary_median=295_000.0,
        salary_p75=340_000.0, salary_p90=385_000.0,
        wrvu_p25=2800.0, wrvu_median=3500.0, wrvu_p75=4200.0, wrvu_p90=4800.0,
    ),
    "Emergency Medicine" => (
        salary_p25=310_000.0, salary_median=350_000.0,
        salary_p75=400_000.0, salary_p90=450_000.0,
        wrvu_p25=4200.0, wrvu_median=5200.0, wrvu_p75=6200.0, wrvu_p90=7000.0,
    ),
    "Orthopedics" => (
        salary_p25=510_000.0, salary_median=600_000.0,
        salary_p75=720_000.0, salary_p90=850_000.0,
        wrvu_p25=6800.0, wrvu_median=8200.0, wrvu_p75=10000.0, wrvu_p90=11500.0,
    ),
    "Pediatrics" => (
        salary_p25=225_000.0, salary_median=255_000.0,
        salary_p75=295_000.0, salary_p90=330_000.0,
        wrvu_p25=3400.0, wrvu_median=4200.0, wrvu_p75=5000.0, wrvu_p90=5600.0,
    ),
    "Hospitalist" => (
        salary_p25=280_000.0, salary_median=315_000.0,
        salary_p75=360_000.0, salary_p90=400_000.0,
        wrvu_p25=3200.0, wrvu_median=4000.0, wrvu_p75=4800.0, wrvu_p90=5400.0,
    ),
    "Anesthesiology" => (
        salary_p25=400_000.0, salary_median=450_000.0,
        salary_p75=510_000.0, salary_p90=570_000.0,
        wrvu_p25=4400.0, wrvu_median=5400.0, wrvu_p75=6400.0, wrvu_p90=7200.0,
    ),
)

# ─────────────────────────────────────────────────────────────────────────────
# Types
# ─────────────────────────────────────────────────────────────────────────────

"""
    PhysEmploymentProfile

Physician profile for employment-model economic analysis.  Named distinctly
from `PhysicianProfile` in physician_compensation.jl to avoid collision.
"""
@kwdef struct PhysEmploymentProfile
    specialty::String
    annual_wrvu::Float64
    years_experience::Int
    panel_size::Int
    fte::Float64 = 1.0
end

"""
    W2EmploymentModel

All cost components of a W-2 (employed) physician arrangement from the
hospital/employer perspective.
"""
@kwdef struct W2EmploymentModel
    base_salary::Float64
    wrvu_incentive_rate::Float64
    benefits_pct::Float64             = 0.25
    malpractice_annual::Float64
    cme_allowance::Float64            = 3000.0
    retirement_match_pct::Float64     = 0.06
    fica_employer_pct::Float64        = 0.0765
    health_insurance_annual::Float64  = 18_000.0
    recruitment_cost::Float64         = 30_000.0
    onboarding_months::Int            = 3
end

"""
    IndependentContractorModel

Cost components of a 1099 independent-contractor physician arrangement.
"""
@kwdef struct IndependentContractorModel
    hourly_rate::Float64
    expected_hours_per_year::Float64
    admin_fee_pct::Float64       = 0.10
    credentialing_cost::Float64  = 5000.0
    no_benefits::Bool            = true
end

"""
    EmploymentComparison

Side-by-side comparison result for W-2 vs independent-contractor models.
"""
struct EmploymentComparison
    w2_total_cost::Float64
    ic_total_cost::Float64
    w2_cost_per_wrvu::Float64
    ic_cost_per_wrvu::Float64
    breakeven_wrvu::Float64
    recommendation::Symbol
    factors::Dict{String,Any}
end

# ─────────────────────────────────────────────────────────────────────────────
# Core Functions
# ─────────────────────────────────────────────────────────────────────────────

"""
    total_w2_cost(profile::PhysEmploymentProfile, model::W2EmploymentModel)::Dict{String,Float64}

Calculate all-in employer cost for a W-2 physician, returning an itemised
breakdown.  Includes:

- Base salary (pro-rated by FTE)
- wRVU incentive payments
- Employer FICA (Social Security + Medicare)
- Health insurance
- Retirement match (401k / 403b)
- Malpractice insurance
- CME allowance
- Disability insurance (~2% of base)
- Workers compensation (~1% of base)
- Amortised recruitment cost (spread over 3 years)
"""
function total_w2_cost(profile::PhysEmploymentProfile, model::W2EmploymentModel)::Dict{String,Float64}
    base = model.base_salary * profile.fte
    wrvu_incentive = profile.annual_wrvu * model.wrvu_incentive_rate

    # Taxable compensation for FICA / retirement purposes
    total_cash_comp = base + wrvu_incentive

    fica          = total_cash_comp * model.fica_employer_pct
    retirement    = total_cash_comp * model.retirement_match_pct
    health_ins    = model.health_insurance_annual * profile.fte
    malpractice   = model.malpractice_annual * profile.fte
    cme           = model.cme_allowance * profile.fte
    disability    = base * 0.02   # ~2 % of base salary
    workers_comp  = base * 0.01   # ~1 % of base salary

    # Amortise recruitment + onboarding over 3 years
    onboarding_salary_cost = base * (model.onboarding_months / 12.0) * 0.5  # half-productive
    recruitment_amortised  = (model.recruitment_cost + onboarding_salary_cost) / 3.0

    breakdown = Dict{String,Float64}(
        "base_salary"           => base,
        "wrvu_incentive"        => wrvu_incentive,
        "employer_fica"         => fica,
        "health_insurance"      => health_ins,
        "retirement_match"      => retirement,
        "malpractice"           => malpractice,
        "cme_allowance"         => cme,
        "disability_insurance"  => disability,
        "workers_compensation"  => workers_comp,
        "recruitment_amortised" => recruitment_amortised,
    )

    breakdown["total"] = sum(values(breakdown))
    return breakdown
end

"""
    total_ic_cost(profile::PhysEmploymentProfile, model::IndependentContractorModel)::Dict{String,Float64}

Calculate total cost for an independent contractor physician.  The employer
pays the contracted rate plus administrative fees and credentialing but no
benefits, FICA, retirement, or malpractice.
"""
function total_ic_cost(profile::PhysEmploymentProfile, model::IndependentContractorModel)::Dict{String,Float64}
    hours     = model.expected_hours_per_year * profile.fte
    base_cost = model.hourly_rate * hours
    admin_fee = base_cost * model.admin_fee_pct

    # Credentialing amortised over 2 years (typical recredentialing cycle)
    credentialing = model.credentialing_cost / 2.0

    breakdown = Dict{String,Float64}(
        "contracted_payments"       => base_cost,
        "admin_fee"                 => admin_fee,
        "credentialing_amortised"   => credentialing,
    )

    breakdown["total"] = sum(values(breakdown))
    return breakdown
end

"""
    compare_employment(profile::PhysEmploymentProfile,
                       w2::W2EmploymentModel,
                       ic::IndependentContractorModel)::EmploymentComparison

Side-by-side comparison of W-2 and independent-contractor models.  Calculates
cost per wRVU for each, breakeven wRVU (the annual wRVU level at which the
W-2 arrangement becomes cheaper than the IC arrangement), and a
recommendation symbol: `:w2_preferred`, `:ic_preferred`, or `:neutral`
(within 5 % of each other).
"""
function compare_employment(profile::PhysEmploymentProfile,
                            w2::W2EmploymentModel,
                            ic::IndependentContractorModel)::EmploymentComparison
    w2_costs = total_w2_cost(profile, w2)
    ic_costs = total_ic_cost(profile, ic)

    w2_total = w2_costs["total"]
    ic_total = ic_costs["total"]

    wrvu = max(profile.annual_wrvu, 1.0)  # guard against division by zero
    w2_per_wrvu = w2_total / wrvu
    ic_per_wrvu = ic_total / wrvu

    # ── Breakeven wRVU ──────────────────────────────────────────────────
    # W2 total cost as a function of wRVU (x):
    #   W2(x) = fixed_w2 + x * wrvu_incentive_rate * (1 + fica + retirement)
    # IC total cost is independent of wRVU (fixed contracted hours):
    #   IC = ic_total  (fixed)
    # Breakeven: W2(x) = IC  →  x = (IC - fixed_w2) / marginal_w2
    base_fte = w2.base_salary * profile.fte
    # Fixed W2 costs (everything except wRVU-linked)
    fica_on_base      = base_fte * w2.fica_employer_pct
    retirement_on_base = base_fte * w2.retirement_match_pct
    fixed_w2 = (base_fte
                + fica_on_base
                + retirement_on_base
                + w2.health_insurance_annual * profile.fte
                + w2.malpractice_annual * profile.fte
                + w2.cme_allowance * profile.fte
                + base_fte * 0.02   # disability
                + base_fte * 0.01   # workers comp
                + (w2.recruitment_cost + base_fte * (w2.onboarding_months / 12.0) * 0.5) / 3.0)

    # Marginal cost per additional wRVU (incentive + employer payroll taxes on incentive)
    marginal_w2_per_wrvu = w2.wrvu_incentive_rate * (1.0 + w2.fica_employer_pct + w2.retirement_match_pct)

    breakeven_wrvu = if marginal_w2_per_wrvu > 0.0
        (ic_total - fixed_w2) / marginal_w2_per_wrvu
    else
        Inf  # no variable component → breakeven undefined
    end

    # ── Recommendation ──────────────────────────────────────────────────
    ratio = w2_total / max(ic_total, 1.0)
    recommendation = if ratio < 0.95
        :w2_preferred
    elseif ratio > 1.05
        :ic_preferred
    else
        :neutral
    end

    factors = Dict{String,Any}(
        "w2_breakdown"        => w2_costs,
        "ic_breakdown"        => ic_costs,
        "cost_difference"     => w2_total - ic_total,
        "pct_difference"      => (w2_total - ic_total) / max(ic_total, 1.0) * 100.0,
        "w2_includes_benefits" => true,
        "ic_includes_benefits" => false,
    )

    EmploymentComparison(
        w2_total, ic_total,
        w2_per_wrvu, ic_per_wrvu,
        breakeven_wrvu,
        recommendation,
        factors,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# MGMA Benchmarks
# ─────────────────────────────────────────────────────────────────────────────

"""
    mgma_benchmark_salary(specialty::String)::NamedTuple{(:p25,:median,:p75,:p90),NTuple{4,Float64}}

Return 2024 MGMA salary percentile benchmarks for the given specialty.
Throws `ArgumentError` if the specialty is not found in `MGMA_BENCHMARKS_2024`.
"""
function mgma_benchmark_salary(specialty::String)::NamedTuple{(:p25,:median,:p75,:p90),NTuple{4,Float64}}
    if !haskey(MGMA_BENCHMARKS_2024, specialty)
        available = join(sort(collect(keys(MGMA_BENCHMARKS_2024))), ", ")
        throw(ArgumentError(
            "Specialty \"$specialty\" not found.  Available: $available"))
    end
    b = MGMA_BENCHMARKS_2024[specialty]
    return (p25=b.salary_p25, median=b.salary_median,
            p75=b.salary_p75, p90=b.salary_p90)
end

# ─────────────────────────────────────────────────────────────────────────────
# Physician ROI
# ─────────────────────────────────────────────────────────────────────────────

"""
    physician_roi(profile::PhysEmploymentProfile,
                  w2::W2EmploymentModel,
                  collections_per_wrvu::Float64)::Dict{String,Float64}

Compute physician-level return on investment from the hospital's perspective.

Returns:
- `net_revenue`:           annual net patient revenue (wRVU × collections)
- `total_cost`:            all-in W-2 employer cost
- `contribution_margin`:   net_revenue − total_cost
- `roi_pct`:               contribution_margin / total_cost × 100
- `months_to_breakeven`:   accounting for onboarding ramp-up (50 % productivity
  during first `onboarding_months`, then full productivity until cumulative
  contribution covers recruitment cost)
"""
function physician_roi(profile::PhysEmploymentProfile,
                       w2::W2EmploymentModel,
                       collections_per_wrvu::Float64)::Dict{String,Float64}
    costs = total_w2_cost(profile, w2)
    total_cost = costs["total"]

    net_revenue = profile.annual_wrvu * collections_per_wrvu * profile.fte

    contribution_margin = net_revenue - total_cost
    roi_pct = total_cost > 0 ? (contribution_margin / total_cost) * 100.0 : 0.0

    # ── Months to breakeven ─────────────────────────────────────────────
    monthly_revenue_full   = net_revenue / 12.0
    monthly_cost           = total_cost / 12.0
    ramp_months            = w2.onboarding_months

    # During ramp: revenue = 50 %, cost = 100 %
    ramp_contribution = ramp_months * (monthly_revenue_full * 0.5 - monthly_cost)

    # After ramp: monthly net contribution
    monthly_net_post_ramp = monthly_revenue_full - monthly_cost

    months_to_breakeven = if monthly_net_post_ramp <= 0.0
        Inf  # never breaks even
    else
        # Cumulative contribution turns positive:
        cumulative_at_ramp_end = ramp_contribution
        if cumulative_at_ramp_end >= 0.0
            # Already positive during ramp — interpolate
            # Each ramp month contributes (0.5*rev - cost); find when cumulative = 0
            monthly_ramp_contrib = monthly_revenue_full * 0.5 - monthly_cost
            if monthly_ramp_contrib > 0.0
                0.0  # immediately positive (unlikely but handle)
            else
                # Turns positive during ramp is impossible if cumulative_at_ramp_end >= 0
                # when monthly_ramp_contrib <= 0 — contradicts; default to ramp_months
                Float64(ramp_months)
            end
        else
            # Additional months after ramp to recover deficit
            Float64(ramp_months) + abs(cumulative_at_ramp_end) / monthly_net_post_ramp
        end
    end

    Dict{String,Float64}(
        "net_revenue"          => net_revenue,
        "total_cost"           => total_cost,
        "contribution_margin"  => contribution_margin,
        "roi_pct"              => roi_pct,
        "months_to_breakeven"  => months_to_breakeven,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Staffing Gap Analysis
# ─────────────────────────────────────────────────────────────────────────────

"""
    staffing_gap_analysis(current_physicians::Vector{PhysEmploymentProfile},
                          target_wrvus::Dict{String,Float64})::Dict{String,Any}

Identify specialties where current aggregate wRVU production falls short of
target, and recommend additional FTEs needed (based on MGMA median wRVU
per physician for that specialty).

Returns a dictionary with keys:
- `gaps`:       Dict{String,NamedTuple} — per-specialty gap detail
- `summary`:    Dict with total additional FTEs needed and list of under-staffed
                specialties
"""
function staffing_gap_analysis(current_physicians::Vector{PhysEmploymentProfile},
                               target_wrvus::Dict{String,Float64})::Dict{String,Any}
    # Aggregate current wRVUs by specialty
    current_by_spec = Dict{String,Float64}()
    fte_by_spec     = Dict{String,Float64}()
    for p in current_physicians
        current_by_spec[p.specialty] = get(current_by_spec, p.specialty, 0.0) + p.annual_wrvu * p.fte
        fte_by_spec[p.specialty]     = get(fte_by_spec, p.specialty, 0.0) + p.fte
    end

    gaps = Dict{String,Any}()
    total_additional_fte = 0.0
    understaffed = String[]

    for (spec, target) in target_wrvus
        current = get(current_by_spec, spec, 0.0)
        current_fte = get(fte_by_spec, spec, 0.0)
        shortfall = target - current

        # Median wRVU per FTE for this specialty
        median_wrvu_per_fte = if haskey(MGMA_BENCHMARKS_2024, spec)
            MGMA_BENCHMARKS_2024[spec].wrvu_median
        else
            4500.0  # fallback default
        end

        additional_fte = shortfall > 0.0 ? ceil(shortfall / median_wrvu_per_fte * 10.0) / 10.0 : 0.0

        gaps[spec] = (
            target_wrvu      = target,
            current_wrvu     = current,
            current_fte      = current_fte,
            shortfall_wrvu   = max(shortfall, 0.0),
            surplus_wrvu     = max(-shortfall, 0.0),
            additional_fte   = additional_fte,
            status           = shortfall > 0 ? :understaffed : :adequate,
        )

        if shortfall > 0.0
            total_additional_fte += additional_fte
            push!(understaffed, spec)
        end
    end

    Dict{String,Any}(
        "gaps" => gaps,
        "summary" => Dict{String,Any}(
            "total_additional_fte_needed" => total_additional_fte,
            "understaffed_specialties"    => understaffed,
            "adequately_staffed_count"    => length(target_wrvus) - length(understaffed),
        ),
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Compensation Design
# ─────────────────────────────────────────────────────────────────────────────

"""
    compensation_design(specialty::String,
                        target_percentile::Symbol=:median;
                        quality_bonus_pct::Float64=0.10)::Dict{String,Any}

Design a competitive compensation package for a physician in the given
specialty, targeting the specified MGMA salary percentile.

The package includes:
- Base salary (from MGMA at target percentile)
- wRVU incentive tier structure (three tiers: threshold, target, stretch)
- Quality bonus component
- Total target compensation at expected (median) productivity

`target_percentile` may be `:p25`, `:median`, `:p75`, or `:p90`.
"""
function compensation_design(specialty::String,
                             target_percentile::Symbol=:median;
                             quality_bonus_pct::Float64=0.10)::Dict{String,Any}
    if !haskey(MGMA_BENCHMARKS_2024, specialty)
        available = join(sort(collect(keys(MGMA_BENCHMARKS_2024))), ", ")
        throw(ArgumentError(
            "Specialty \"$specialty\" not found.  Available: $available"))
    end

    b = MGMA_BENCHMARKS_2024[specialty]

    # Select base salary by percentile
    base_salary = if target_percentile == :p25
        b.salary_p25
    elseif target_percentile == :median
        b.salary_median
    elseif target_percentile == :p75
        b.salary_p75
    elseif target_percentile == :p90
        b.salary_p90
    else
        throw(ArgumentError(
            "Invalid target_percentile $target_percentile.  Use :p25, :median, :p75, or :p90."))
    end

    # wRVU benchmark at target percentile
    wrvu_target = if target_percentile == :p25
        b.wrvu_p25
    elseif target_percentile == :median
        b.wrvu_median
    elseif target_percentile == :p75
        b.wrvu_p75
    elseif target_percentile == :p90
        b.wrvu_p90
    end

    # ── wRVU incentive tier structure ───────────────────────────────────
    # Tier 1 (threshold): 75 % of target wRVU — lower rate to reward early
    # Tier 2 (target):    75-100 % of target — standard conversion factor
    # Tier 3 (stretch):   > 100 % of target — higher rate to incentivise
    #
    # Conversion factor derived so that at-target production yields ~20 %
    # above base salary in incentive pay.
    target_incentive_pool = base_salary * 0.20
    cf_standard = target_incentive_pool / (wrvu_target * 0.25)  # earned on top 25 % of target wRVUs

    tier_structure = Dict{String,Any}(
        "tier_1_threshold_wrvu" => round(wrvu_target * 0.75, digits=0),
        "tier_1_rate"           => round(cf_standard * 0.80, digits=2),     # 80 % of standard
        "tier_2_target_wrvu"    => round(wrvu_target, digits=0),
        "tier_2_rate"           => round(cf_standard, digits=2),            # standard rate
        "tier_3_stretch_wrvu"   => round(wrvu_target * 1.25, digits=0),
        "tier_3_rate"           => round(cf_standard * 1.20, digits=2),     # 120 % of standard
    )

    # ── Quality bonus ──────────────────────────────────────────────────
    quality_bonus = base_salary * quality_bonus_pct

    # ── Total target compensation ──────────────────────────────────────
    total_target_comp = base_salary + target_incentive_pool + quality_bonus

    Dict{String,Any}(
        "specialty"                 => specialty,
        "target_percentile"         => target_percentile,
        "base_salary"               => base_salary,
        "wrvu_target"               => wrvu_target,
        "wrvu_incentive_tiers"      => tier_structure,
        "target_incentive_at_wrvu"  => target_incentive_pool,
        "quality_bonus_pct"         => quality_bonus_pct,
        "quality_bonus_amount"      => quality_bonus,
        "total_target_compensation" => total_target_comp,
        "mgma_salary_benchmarks"    => (p25=b.salary_p25, median=b.salary_median,
                                        p75=b.salary_p75, p90=b.salary_p90),
        "mgma_wrvu_benchmarks"      => (p25=b.wrvu_p25, median=b.wrvu_median,
                                        p75=b.wrvu_p75, p90=b.wrvu_p90),
    )
end
