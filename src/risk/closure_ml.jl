# ============================================================================
# ML-Enhanced Closure Prediction — Chartis-style 10-variable logistic
# regression model and simplified ensemble methods.
# ============================================================================

const CHARTIS_COEFFICIENTS = Dict{Symbol,Float64}(
    :years_negative_operating_margin => 0.45,
    :occupancy_rate                  => -2.1,
    :avg_age_of_plant                => 0.08,
    :case_mix_index                  => -0.35,
    :is_government_controlled        => -0.9,
    :state_has_medicaid_expansion    => -0.6,
    :traditional_medicare_pct_days   => 1.2,
    :pct_change_net_patient_revenue  => -3.0,
    :adc_swing_snf                   => -0.15,
    :avg_length_of_stay              => 0.1,
)

const CHARTIS_INTERCEPT = -1.5

"""Ten-variable feature set for Chartis-style logistic closure prediction."""
@kwdef struct ClosureMLFeatures
    case_mix_index::Float64                  = 1.0
    is_government_controlled::Bool           = false
    adc_swing_snf::Float64                   = 0.0
    avg_age_of_plant::Float64                = 12.0
    avg_length_of_stay::Float64              = 3.5
    occupancy_rate::Float64                  = 0.30
    pct_change_net_patient_revenue::Float64  = 0.0
    years_negative_operating_margin::Int     = 0
    state_has_medicaid_expansion::Bool       = true
    traditional_medicare_pct_days::Float64   = 0.40
end

"""Result of ML-enhanced closure prediction."""
@kwdef struct ClosureMLResult
    logistic_probability::Float64
    risk_tier::Symbol
    key_risk_factors::Vector{String}
    protective_factors::Vector{String}
    chartis_vulnerability_score::Float64
end

"""Standard logistic sigmoid function."""
_sigmoid(x::Float64) = 1.0 / (1.0 + exp(-x))

"""
    predict_closure_logistic(features::ClosureMLFeatures) -> ClosureMLResult

Chartis-style 10-variable logistic regression. Risk tiers: `:low` (<0.15),
`:moderate` (0.15-0.35), `:high` (0.35-0.65), `:critical` (>=0.65).
"""
function predict_closure_logistic(features::ClosureMLFeatures)::ClosureMLResult
    # Compute log-odds
    log_odds = CHARTIS_INTERCEPT +
        CHARTIS_COEFFICIENTS[:years_negative_operating_margin] * Float64(features.years_negative_operating_margin) +
        CHARTIS_COEFFICIENTS[:occupancy_rate]                  * features.occupancy_rate +
        CHARTIS_COEFFICIENTS[:avg_age_of_plant]                * features.avg_age_of_plant +
        CHARTIS_COEFFICIENTS[:case_mix_index]                  * features.case_mix_index +
        CHARTIS_COEFFICIENTS[:is_government_controlled]        * Float64(features.is_government_controlled) +
        CHARTIS_COEFFICIENTS[:state_has_medicaid_expansion]    * Float64(features.state_has_medicaid_expansion) +
        CHARTIS_COEFFICIENTS[:traditional_medicare_pct_days]   * features.traditional_medicare_pct_days +
        CHARTIS_COEFFICIENTS[:pct_change_net_patient_revenue]  * features.pct_change_net_patient_revenue +
        CHARTIS_COEFFICIENTS[:adc_swing_snf]                   * features.adc_swing_snf +
        CHARTIS_COEFFICIENTS[:avg_length_of_stay]              * features.avg_length_of_stay

    probability = _sigmoid(log_odds)

    # Assign risk tier
    risk_tier = if probability >= 0.65
        :critical
    elseif probability >= 0.35
        :high
    elseif probability >= 0.15
        :moderate
    else
        :low
    end

    # Identify key risk and protective factors
    risk_factors = String[]
    protective   = String[]

    features.years_negative_operating_margin >= 2 &&
        push!(risk_factors, "$(features.years_negative_operating_margin) years of negative operating margin")
    features.occupancy_rate < 0.25 &&
        push!(risk_factors, "Very low occupancy rate ($(round(features.occupancy_rate * 100, digits=1))%)")
    features.avg_age_of_plant > 15.0 &&
        push!(risk_factors, "Aging plant infrastructure ($(round(features.avg_age_of_plant, digits=1)) years)")
    features.traditional_medicare_pct_days > 0.50 &&
        push!(risk_factors, "High traditional Medicare dependency ($(round(features.traditional_medicare_pct_days * 100, digits=1))%)")
    features.pct_change_net_patient_revenue < -0.05 &&
        push!(risk_factors, "Declining net patient revenue ($(round(features.pct_change_net_patient_revenue * 100, digits=1))%)")
    features.avg_length_of_stay > 5.0 &&
        push!(risk_factors, "Extended average length of stay ($(round(features.avg_length_of_stay, digits=1)) days)")

    features.state_has_medicaid_expansion &&
        push!(protective, "State has Medicaid expansion")
    features.is_government_controlled &&
        push!(protective, "Government-controlled (access to public funding)")
    features.case_mix_index > 1.2 &&
        push!(protective, "Higher case mix index ($(round(features.case_mix_index, digits=2)))")
    features.occupancy_rate >= 0.45 &&
        push!(protective, "Adequate occupancy rate ($(round(features.occupancy_rate * 100, digits=1))%)")
    features.pct_change_net_patient_revenue > 0.03 &&
        push!(protective, "Growing net patient revenue (+$(round(features.pct_change_net_patient_revenue * 100, digits=1))%)")

    vuln_score = chartis_vulnerability_score(features)

    return ClosureMLResult(
        logistic_probability       = probability,
        risk_tier                  = risk_tier,
        key_risk_factors           = risk_factors,
        protective_factors         = protective,
        chartis_vulnerability_score = vuln_score,
    )
end

"""
    chartis_vulnerability_score(features::ClosureMLFeatures) -> Float64

0-100 composite vulnerability score. Higher = greater vulnerability.
"""
function chartis_vulnerability_score(features::ClosureMLFeatures)::Float64
    # Normalize each feature to a 0-1 risk contribution
    occ_risk    = clamp(1.0 - features.occupancy_rate / 0.70, 0.0, 1.0)
    age_risk    = clamp(features.avg_age_of_plant / 25.0, 0.0, 1.0)
    margin_risk = clamp(features.years_negative_operating_margin / 5.0, 0.0, 1.0)
    rev_risk    = clamp(-features.pct_change_net_patient_revenue / 0.15, 0.0, 1.0)
    medicare_risk = clamp(features.traditional_medicare_pct_days / 0.70, 0.0, 1.0)
    cmi_risk    = clamp(1.0 - features.case_mix_index / 1.5, 0.0, 1.0)
    alos_risk   = clamp((features.avg_length_of_stay - 2.0) / 6.0, 0.0, 1.0)

    # Protective binary factors reduce score
    gov_protect      = features.is_government_controlled ? 0.10 : 0.0
    medicaid_protect = features.state_has_medicaid_expansion ? 0.08 : 0.0

    raw = (0.25 * margin_risk +
           0.20 * occ_risk +
           0.15 * rev_risk +
           0.12 * age_risk +
           0.10 * medicare_risk +
           0.10 * cmi_risk +
           0.08 * alos_risk) - gov_protect - medicaid_protect

    return clamp(raw * 100.0, 0.0, 100.0)
end

"""
    closure_risk_trend(features_by_year::Vector{ClosureMLFeatures}) -> Vector{NamedTuple}

Track closure probability over multiple years and flag acceleration.
Returns `(year_index, probability, risk_tier, delta, accelerating)`.
"""
function closure_risk_trend(features_by_year::Vector{ClosureMLFeatures})::Vector{NamedTuple}
    results = NamedTuple[]
    prev_prob = 0.0
    prev_delta = 0.0

    for (i, feat) in enumerate(features_by_year)
        ml_result = predict_closure_logistic(feat)
        prob  = ml_result.logistic_probability
        delta = i == 1 ? 0.0 : prob - prev_prob
        accelerating = i >= 3 && delta > prev_delta && delta > 0.0

        push!(results, (
            year_index   = i,
            probability  = round(prob, digits=4),
            risk_tier    = ml_result.risk_tier,
            delta        = round(delta, digits=4),
            accelerating = accelerating,
        ))

        prev_delta = delta
        prev_prob  = prob
    end

    return results
end
