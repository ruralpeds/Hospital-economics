# ── Healthcare Actuarial Analysis ────────────────────────────────────────────
#
# Claims triangle development (chain-ladder), IBNR reserves, HCC risk
# adjustment, PMPM analytics, premium ratemaking, utilization metrics,
# frequency/severity/pure premium, and credibility weighting.
#
# Ported from healthcare-finance-julia/src/actuarial/actuarial_engine.jl

# ─── Claims Development / IBNR ───────────────────────────────────────────────

"""
    loss_development_factors(triangle::Matrix{Float64}) -> Vector{Float64}

Compute weighted-average age-to-age loss development factors (LDFs) from a
paid claims triangle. `triangle[i,j]` = cumulative paid claims for accident
year i at development age j. Unfilled (future) entries should be 0.0.
"""
function loss_development_factors(triangle::Matrix{Float64})::Vector{Float64}
    n = size(triangle, 1)
    size(triangle, 2) == n || throw(ArgumentError("triangle must be square"))
    ldfs = Float64[]
    for j in 1:(n - 1)
        num   = sum(triangle[i, j+1] for i in 1:(n-j) if triangle[i, j] > 0;
                    init=0.0)
        denom = sum(triangle[i, j]   for i in 1:(n-j) if triangle[i, j] > 0;
                    init=0.0)
        denom == 0 && throw(ArgumentError("zero denominator at development age $j"))
        push!(ldfs, num / denom)
    end
    return ldfs
end

"""
    claims_triangle_development(triangle::Matrix{Float64}) -> Matrix{Float64}

Complete an upper-left paid claims triangle using chain-ladder LDFs.
Returns the fully developed square matrix.
"""
function claims_triangle_development(triangle::Matrix{Float64})::Matrix{Float64}
    n = size(triangle, 1)
    size(triangle, 2) == n || throw(ArgumentError("triangle must be square"))
    ldfs      = loss_development_factors(triangle)
    developed = copy(triangle)
    for i in 2:n
        for j in (n - i + 2):n
            developed[i, j] = developed[i, j-1] * ldfs[j-1]
        end
    end
    return developed
end

"""
    ibnr_reserve(triangle::Matrix{Float64}) -> Vector{Float64}

Compute Incurred But Not Reported (IBNR) reserve per accident year.
`IBNR[i] = chain-ladder ultimate − latest diagonal paid`.
"""
function ibnr_reserve(triangle::Matrix{Float64})::Vector{Float64}
    n         = size(triangle, 1)
    developed = claims_triangle_development(triangle)
    return [developed[i, n] - triangle[i, n-i+1] for i in 1:n]
end

# ─── HCC Risk Adjustment ──────────────────────────────────────────────────────

"""
    hcc_risk_score(demographic_factor, hcc_factors; normalization_factor=1.0)
        -> Float64

Compute CMS-HCC risk score for a Medicare Advantage member using numeric
component factors (demographic coefficient + sum of HCC coefficients),
then divide by the CMS annual normalization factor.

Note: A separate method `hcc_risk_score(conditions::Vector{String}, ...)`
exists in risk_contracting.jl for condition-code-based scoring.
"""
function hcc_risk_score(demographic_factor::Real,
                         hcc_factors::AbstractVector{<:Real};
                         normalization_factor::Real=1.0)::Float64
    normalization_factor > 0 ||
        throw(ArgumentError("normalization_factor must be positive"))
    return (demographic_factor + sum(hcc_factors)) / normalization_factor
end

"""
    hcc_prospective_score(prior_year_raf, trend_factor=1.0) -> Float64

Project a prospective HCC Risk Adjustment Factor from the prior year.
"""
function hcc_prospective_score(prior_year_raf::Real,
                                trend_factor::Real=1.0)::Float64
    prior_year_raf > 0  || throw(ArgumentError("prior_year_raf must be positive"))
    trend_factor > 0    || throw(ArgumentError("trend_factor must be positive"))
    return prior_year_raf * trend_factor
end

# ─── PMPM Analytics ───────────────────────────────────────────────────────────

"""
    pmpm_by_category(expenditures, labels, member_months) -> Vector{NamedTuple}

Decompose total PMPM spending across service categories.
Each element: `(category, spend, pmpm)`.
"""
function pmpm_by_category(expenditures::AbstractVector{<:Real},
                           labels::AbstractVector{<:AbstractString},
                           member_months::Real)
    length(expenditures) == length(labels) ||
        throw(ArgumentError("expenditures and labels must have the same length"))
    member_months > 0 || throw(ArgumentError("member_months must be positive"))
    return [(category=labels[i], spend=Float64(expenditures[i]),
             pmpm=expenditures[i] / member_months) for i in eachindex(expenditures)]
end

"""
    admin_expense_ratio(admin_expenses, premium_revenue) -> Float64

Administrative expense ratio = admin expenses / premium revenue.
ACA MLR rules define allowable admin spend as a complement to the MLR floor.
"""
function admin_expense_ratio(admin_expenses::Real, premium_revenue::Real)::Float64
    premium_revenue > 0 || throw(ArgumentError("premium_revenue must be positive"))
    return admin_expenses / premium_revenue
end

# ─── Premium Rate Development ─────────────────────────────────────────────────

"""
    premium_rate_development(claims_pmpm, admin_loading, profit_margin,
                             risk_margin=0.0) -> Float64

Develop an insurance premium from projected claims PMPM.
`premium = claims_pmpm / (1 − admin_loading − profit_margin − risk_margin)`
"""
function premium_rate_development(claims_pmpm::Real,
                                   admin_loading::Real,
                                   profit_margin::Real,
                                   risk_margin::Real=0.0)::Float64
    claims_pmpm > 0 || throw(ArgumentError("claims_pmpm must be positive"))
    denominator = 1 - admin_loading - profit_margin - risk_margin
    denominator > 0 || throw(ArgumentError("combined loadings exceed 100%"))
    return claims_pmpm / denominator
end

"""
    community_rating_premium(market_claims_pmpm, admin_loading, profit_margin)
        -> Float64

Single community-rated premium for an entire rating area regardless of health status.
"""
function community_rating_premium(market_claims_pmpm::Real,
                                   admin_loading::Real,
                                   profit_margin::Real)::Float64
    return premium_rate_development(market_claims_pmpm, admin_loading, profit_margin)
end

# ─── Utilization Metrics ──────────────────────────────────────────────────────

"""
    utilization_rate(events, member_months; per=1000) -> Float64

Generic utilization rate: events per N member months (default per 1,000).
"""
function utilization_rate(events::Real, member_months::Real;
                           per::Real=1000)::Float64
    member_months > 0 || throw(ArgumentError("member_months must be positive"))
    return (events / member_months) * per
end

"""
    admissions_per_thousand(inpatient_admissions, member_months) -> Float64

Inpatient admits per 1,000 member years (annualised).
Benchmarks: commercial ~60–80, Medicare ~250–300.
"""
function admissions_per_thousand(inpatient_admissions::Real,
                                  member_months::Real)::Float64
    member_months > 0 || throw(ArgumentError("member_months must be positive"))
    return (inpatient_admissions / member_months) * 12_000
end

"""
    ed_visits_per_thousand(ed_visits, member_months) -> Float64

Emergency department visits per 1,000 member years (annualised).
"""
function ed_visits_per_thousand(ed_visits::Real, member_months::Real)::Float64
    member_months > 0 || throw(ArgumentError("member_months must be positive"))
    return (ed_visits / member_months) * 12_000
end

# ─── Frequency / Severity / Pure Premium ─────────────────────────────────────

"""
    claim_frequency(claim_count, exposure_units) -> Float64

Claims per unit of exposure (e.g., per member year).
"""
function claim_frequency(claim_count::Real, exposure_units::Real)::Float64
    exposure_units > 0 || throw(ArgumentError("exposure_units must be positive"))
    return claim_count / exposure_units
end

"""
    claim_severity(total_paid, claim_count) -> Float64

Average paid amount per claim.
"""
function claim_severity(total_paid::Real, claim_count::Real)::Float64
    claim_count > 0 || throw(ArgumentError("claim_count must be positive"))
    return total_paid / claim_count
end

"""
    pure_premium(claim_frequency_val, claim_severity_val) -> Float64

Pure premium = frequency × severity (expected cost per exposure unit).
"""
function pure_premium(claim_frequency_val::Real,
                       claim_severity_val::Real)::Float64
    return claim_frequency_val * claim_severity_val
end

# ─── Credibility Weighting ────────────────────────────────────────────────────

"""
    credibility_weight(observed_members, full_credibility_threshold=1082.0)
        -> Float64

Limited fluctuation credibility weight Z ∈ [0, 1].
Full credibility (Z=1) when observed_members ≥ threshold.
Default threshold corresponds to the 90/5 credibility standard.
"""
function credibility_weight(observed_members::Real,
                             full_credibility_threshold::Real=1082.0)::Float64
    full_credibility_threshold > 0 ||
        throw(ArgumentError("full_credibility_threshold must be positive"))
    return min(1.0, sqrt(observed_members / full_credibility_threshold))
end

"""
    blended_rate(group_rate, market_rate, credibility_z) -> Float64

Credibility-blended rate = Z × group_rate + (1−Z) × market_rate.
"""
function blended_rate(group_rate::Real, market_rate::Real,
                       credibility_z::Real)::Float64
    0 <= credibility_z <= 1 ||
        throw(ArgumentError("credibility_z must be in [0, 1]"))
    return credibility_z * group_rate + (1 - credibility_z) * market_rate
end
