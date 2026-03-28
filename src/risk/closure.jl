# ============================================================================
# Closure Risk Prediction Engine
# ============================================================================

using Dates

# ---------------------------------------------------------------------------
# Weight constants for composite risk scoring
# ---------------------------------------------------------------------------

"""Weights for financial indicators in closure risk scoring."""
const FINANCIAL_WEIGHTS = Dict{String,Float64}(
    "operating_margin"    => 0.25,
    "total_margin"        => 0.15,
    "days_cash_on_hand"   => 0.20,
    "current_ratio"       => 0.15,
    "debt_to_cap"         => 0.10,
    "debt_service_coverage" => 0.15,
)

"""Weights for operational indicators in closure risk scoring."""
const OPERATIONAL_WEIGHTS = Dict{String,Float64}(
    "occupancy_rate"      => 0.25,
    "ed_visit_trend"      => 0.15,
    "outpatient_trend"    => 0.15,
    "fte_per_aob"         => 0.15,
    "avg_age_of_plant"    => 0.15,
    "physician_vacancy"   => 0.15,
)

"""Weights for market / environmental indicators in closure risk scoring."""
const MARKET_WEIGHTS = Dict{String,Float64}(
    "medicaid_expansion"       => 0.15,
    "ma_penetration"           => 0.20,
    "population_trend_5yr"     => 0.25,
    "nearest_competitor_miles" => 0.15,
    "poverty_rate"             => 0.15,
    "uninsured_rate"           => 0.10,
)

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

"""
    MarketData

Environmental and market data for closure risk assessment.

# Fields
- `medicaid_expansion::Bool`: whether the state has expanded Medicaid
- `ma_penetration::Float64`: Medicare Advantage penetration rate (0–1)
- `population_trend_5yr::Float64`: 5-year population growth rate (negative = decline)
- `nearest_competitor_miles::Float64`: distance to nearest alternative hospital
- `poverty_rate::Float64`: county poverty rate (0–1)
- `uninsured_rate::Float64`: county uninsured rate (0–1)
"""
struct MarketData
    medicaid_expansion::Bool
    ma_penetration::Float64
    population_trend_5yr::Float64
    nearest_competitor_miles::Float64
    poverty_rate::Float64
    uninsured_rate::Float64
end

# ClosureRiskAssessment is defined in types/results.jl — uses that struct.
# Fields: hospital_name, assessment_date, financial_risk_score,
#   operational_risk_score, market_risk_score, workforce_risk_score,
#   policy_risk_score, composite_risk_score, risk_category,
#   risk_drivers, mitigating_factors, closure_probability_1yr/3yr/5yr,
#   population_losing_access, nearest_alternative_hospital_miles,
#   jobs_at_risk, annual_economic_impact, mc_summary

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

"""
    normalize(value::Float64, low::Float64, high::Float64) -> Float64

Normalize a value to the [0, 1] range where `low` maps to 1.0 (highest risk)
and `high` maps to 0.0 (lowest risk). Values outside the range are clamped.
"""
function normalize(value::Float64, low::Float64, high::Float64)
    if high == low
        return 0.5
    end
    normed = (value - low) / (high - low)
    return clamp(1.0 - normed, 0.0, 1.0)  # inverted: lower value = higher risk
end

"""
    logistic_score(x::Float64; midpoint::Float64=0.5, steepness::Float64=10.0) -> Float64

Apply a logistic (sigmoid) transformation to produce a probability-like
risk score in [0, 1].
"""
function logistic_score(x::Float64; midpoint::Float64=0.5, steepness::Float64=10.0)
    return 1.0 / (1.0 + exp(-steepness * (x - midpoint)))
end

# ---------------------------------------------------------------------------
# Main assessment function
# ---------------------------------------------------------------------------

"""
    assess_closure_risk(hospital::AbstractHospital, market::MarketData;
                        financial_data::Dict{String,Float64}=Dict{String,Float64}(),
                        operational_data::Dict{String,Float64}=Dict{String,Float64}()) -> ClosureRiskAssessment

Assess the closure risk of a rural hospital using a weighted composite
scoring model across financial, operational, and market dimensions.

# Risk Tiers
- **Critical** (≥0.75): imminent closure risk within 1–2 years
- **High** (0.55–0.75): significant risk within 2–4 years
- **Moderate** (0.35–0.55): elevated risk; intervention recommended
- **Low** (<0.35): stable; routine monitoring

# Arguments
- `hospital`: hospital entity with standard fields
- `market`: market and demographic data
- `financial_data`: dictionary of financial metric names to values
- `operational_data`: dictionary of operational metric names to values
"""
function assess_closure_risk(hospital::AbstractHospital, market::MarketData;
                             financial_data::Dict{String,Float64}=Dict{String,Float64}(),
                             operational_data::Dict{String,Float64}=Dict{String,Float64}())
    # --- Financial risk score ---
    fin_scores = Float64[]
    fin_weights = Float64[]
    key_factors = String[]

    fin_norms = Dict(
        "operating_margin"      => (-0.15, 0.10),
        "total_margin"          => (-0.10, 0.10),
        "days_cash_on_hand"     => (0.0, 200.0),
        "current_ratio"         => (0.5, 3.0),
        "debt_to_cap"           => (0.0, 0.80),
        "debt_service_coverage" => (0.5, 3.0),
    )

    for (metric, weight) in FINANCIAL_WEIGHTS
        val = get(financial_data, metric, nothing)
        if val !== nothing
            bounds = fin_norms[metric]
            # For debt_to_cap, higher = riskier (don't invert)
            if metric == "debt_to_cap"
                score = clamp((val - bounds[1]) / (bounds[2] - bounds[1]), 0.0, 1.0)
            else
                score = normalize(val, bounds[1], bounds[2])
            end
            push!(fin_scores, score * weight)
            push!(fin_weights, weight)
            if score > 0.7
                push!(key_factors, "High financial risk: $metric")
            end
        end
    end

    financial_risk = isempty(fin_weights) ? 0.5 :
        sum(fin_scores) / sum(fin_weights)

    # --- Operational risk score ---
    op_scores = Float64[]
    op_weights = Float64[]

    op_norms = Dict(
        "occupancy_rate"    => (0.0, 0.70),
        "ed_visit_trend"    => (-0.15, 0.10),
        "outpatient_trend"  => (-0.15, 0.10),
        "fte_per_aob"       => (3.0, 8.0),
        "avg_age_of_plant"  => (5.0, 25.0),
        "physician_vacancy" => (0.0, 0.40),
    )

    for (metric, weight) in OPERATIONAL_WEIGHTS
        val = get(operational_data, metric, nothing)
        if val !== nothing
            bounds = op_norms[metric]
            if metric in ("avg_age_of_plant", "physician_vacancy")
                score = clamp((val - bounds[1]) / (bounds[2] - bounds[1]), 0.0, 1.0)
            else
                score = normalize(val, bounds[1], bounds[2])
            end
            push!(op_scores, score * weight)
            push!(op_weights, weight)
            if score > 0.7
                push!(key_factors, "High operational risk: $metric")
            end
        end
    end

    operational_risk = isempty(op_weights) ? 0.5 :
        sum(op_scores) / sum(op_weights)

    # --- Market risk score ---
    market_score_val = 0.0
    total_mkt_weight = 0.0

    # Medicaid expansion (protective factor)
    me_score = market.medicaid_expansion ? 0.2 : 0.8
    w = MARKET_WEIGHTS["medicaid_expansion"]
    market_score_val += me_score * w
    total_mkt_weight += w
    if !market.medicaid_expansion
        push!(key_factors, "Non-expansion state increases uncompensated care")
    end

    # MA penetration (higher = more risk for rural hospitals)
    ma_score = clamp(market.ma_penetration / 0.60, 0.0, 1.0)
    w = MARKET_WEIGHTS["ma_penetration"]
    market_score_val += ma_score * w
    total_mkt_weight += w

    # Population trend (negative = risk)
    pop_score = normalize(market.population_trend_5yr, -0.10, 0.05)
    w = MARKET_WEIGHTS["population_trend_5yr"]
    market_score_val += pop_score * w
    total_mkt_weight += w
    if market.population_trend_5yr < -0.03
        push!(key_factors, "Significant population decline in service area")
    end

    # Nearest competitor (closer = more competition, but also less sole-community protection)
    comp_score = normalize(market.nearest_competitor_miles, 5.0, 50.0)
    w = MARKET_WEIGHTS["nearest_competitor_miles"]
    market_score_val += comp_score * w
    total_mkt_weight += w

    # Poverty rate
    pov_score = clamp(market.poverty_rate / 0.30, 0.0, 1.0)
    w = MARKET_WEIGHTS["poverty_rate"]
    market_score_val += pov_score * w
    total_mkt_weight += w

    # Uninsured rate
    unins_score = clamp(market.uninsured_rate / 0.25, 0.0, 1.0)
    w = MARKET_WEIGHTS["uninsured_rate"]
    market_score_val += unins_score * w
    total_mkt_weight += w

    market_risk = total_mkt_weight > 0 ? market_score_val / total_mkt_weight : 0.5

    # --- Composite score ---
    composite = 0.45 * financial_risk + 0.30 * operational_risk + 0.25 * market_risk
    composite = logistic_score(composite; midpoint=0.50, steepness=8.0)

    # --- Tier classification ---
    tier = if composite >= 0.75
        "Critical"
    elseif composite >= 0.55
        "High"
    elseif composite >= 0.35
        "Moderate"
    else
        "Low"
    end

    # --- Years to distress ---
    ytd = estimate_distress_timeline(composite, financial_risk)

    name = hasproperty(hospital, :name) ? getproperty(hospital, :name) : "Unknown"

    # Map composite score to closure probabilities
    p1yr = composite >= 0.75 ? composite * 0.4 : composite * 0.15
    p3yr = composite >= 0.55 ? composite * 0.6 : composite * 0.25
    p5yr = min(composite * 0.8, 0.95)

    risk_cat = if composite >= 0.75
        :critical
    elseif composite >= 0.55
        :high
    elseif composite >= 0.35
        :moderate
    else
        :low
    end

    return ClosureRiskAssessment(
        hospital_name = name,
        assessment_date = Dates.today(),
        financial_risk_score = financial_risk,
        operational_risk_score = operational_risk,
        market_risk_score = market_risk,
        composite_risk_score = composite,
        risk_category = risk_cat,
        risk_drivers = key_factors,
        closure_probability_1yr = p1yr,
        closure_probability_3yr = p3yr,
        closure_probability_5yr = p5yr,
    )
end

"""
    estimate_distress_timeline(composite_score::Float64,
                                financial_score::Float64) -> Float64

Estimate the number of years until financial distress based on the
composite and financial risk scores.

Uses an inverse mapping: higher scores correspond to shorter timelines.
Returns `Inf` for hospitals with very low risk.
"""
function estimate_distress_timeline(composite_score::Float64,
                                     financial_score::Float64)
    # Weighted blend of composite and financial score
    blended = 0.6 * composite_score + 0.4 * financial_score

    if blended < 0.25
        return Inf  # no foreseeable distress
    elseif blended < 0.40
        return 8.0 + (0.40 - blended) / 0.15 * 2.0  # 8–10 years
    elseif blended < 0.55
        return 5.0 + (0.55 - blended) / 0.15 * 3.0  # 5–8 years
    elseif blended < 0.70
        return 3.0 + (0.70 - blended) / 0.15 * 2.0  # 3–5 years
    elseif blended < 0.85
        return 1.5 + (0.85 - blended) / 0.15 * 1.5  # 1.5–3 years
    else
        return max(0.5, 1.5 * (1.0 - blended) / 0.15)  # <1.5 years
    end
end
