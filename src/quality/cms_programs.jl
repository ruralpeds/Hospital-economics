# CMS Quality Payment Program Calculation Engines
#
# Implements seven CMS quality programs: VBP, HACRP, HRRP, Star Ratings,
# MIPS, HAI, and Combined Payment Impact. Ported from the Rust
# sci-quality-cms / cah-calc-bridge implementations.

# ═══════════════════════════════════════════════════════════════
# VBP — Value-Based Purchasing Program
# ═══════════════════════════════════════════════════════════════

"""
    VBPMeasure

A single measure within a VBP domain.

# Fields
- `measure_id::String`: unique measure identifier (e.g. "AMI-7a")
- `achievement_points::Float64`: points earned for current performance (0-10)
- `improvement_points::Float64`: points earned for improvement over baseline (0-10)
- `benchmark::Float64`: national benchmark rate
- `floor::Float64`: minimum performance threshold (floor)
- `threshold::Float64`: achievement threshold
"""
@kwdef struct VBPMeasure
    measure_id::String
    achievement_points::Float64
    improvement_points::Float64
    benchmark::Float64
    floor::Float64
    threshold::Float64
end

"""
    VBPDomainScore

Aggregated score for one of the four VBP domains.

# Fields
- `domain_name::String`: domain name (e.g. "Clinical", "Safety")
- `measures::Vector{VBPMeasure}`: measures in this domain
- `weight::Float64`: domain weight in TPS calculation (default 0.25)
"""
@kwdef struct VBPDomainScore
    domain_name::String
    measures::Vector{VBPMeasure}
    weight::Float64 = 0.25
end

"""
    VBPResult

Full VBP calculation result.

# Fields
- `domain_scores::Vector{VBPDomainScore}`: per-domain results
- `total_performance_score::Float64`: weighted TPS (0-100)
- `payment_multiplier::Float64`: multiplicative DRG adjustment
- `net_adjustment_pct::Float64`: net percentage payment change
"""
@kwdef struct VBPResult
    domain_scores::Vector{VBPDomainScore}
    total_performance_score::Float64
    payment_multiplier::Float64
    net_adjustment_pct::Float64
end

"""
    _domain_score(measures::Vector{VBPMeasure}) -> Float64

Compute the domain score as the weighted average of per-measure scores.
Each measure score is the maximum of achievement and improvement points,
scaled to 0-100.
"""
function _domain_score(measures::Vector{VBPMeasure})::Float64
    isempty(measures) && return 0.0
    total = 0.0
    for m in measures
        total += max(m.achievement_points, m.improvement_points)
    end
    # Domain score is the average measure score, scaled so max 10 pts => 100
    return (total / length(measures)) * 10.0
end

"""
    calculate_vbp(clinical::Vector{VBPMeasure}, safety::Vector{VBPMeasure},
                  person_community::Vector{VBPMeasure}, efficiency::Vector{VBPMeasure},
                  base_operating_drg_amount::Float64;
                  withhold_pct::Float64=0.02) -> VBPResult

Compute CMS VBP payment adjustment.

Domain weights: Clinical 0.25, Safety 0.25, Person/Community 0.25, Efficiency 0.25.
TPS = weighted sum of domain scores. CMS withholds `withhold_pct` (default 2%) of
base DRG payments and redistributes based on TPS relative to the median (~50):

    multiplier = 1.0 - withhold_pct + (TPS / 50.0) * withhold_pct

At TPS=50 → multiplier=1.0 (break-even), TPS=100 → 1.02 (full bonus), TPS=0 → 0.98 (full penalty).
"""
function calculate_vbp(clinical::Vector{VBPMeasure}, safety::Vector{VBPMeasure},
                       person_community::Vector{VBPMeasure}, efficiency::Vector{VBPMeasure},
                       base_operating_drg_amount::Float64;
                       withhold_pct::Float64=0.02)::VBPResult

    clinical_score = _domain_score(clinical)
    safety_score = _domain_score(safety)
    person_score = _domain_score(person_community)
    efficiency_score = _domain_score(efficiency)

    domains = [
        VBPDomainScore(domain_name="Clinical", measures=clinical, weight=0.25),
        VBPDomainScore(domain_name="Safety", measures=safety, weight=0.25),
        VBPDomainScore(domain_name="Person & Community", measures=person_community, weight=0.25),
        VBPDomainScore(domain_name="Efficiency", measures=efficiency, weight=0.25),
    ]

    scores = [clinical_score, safety_score, person_score, efficiency_score]
    weights = [0.25, 0.25, 0.25, 0.25]
    tps = sum(scores .* weights)

    # Payment multiplier: CMS withholds withhold_pct and redistributes based on TPS
    # relative to the median (~50). At TPS=50 break-even, TPS=100 full bonus, TPS=0 full penalty.
    multiplier = 1.0 - withhold_pct + (tps / 50.0) * withhold_pct
    net_adj = (multiplier - 1.0) * 100.0  # as percentage

    return VBPResult(
        domain_scores=domains,
        total_performance_score=tps,
        payment_multiplier=multiplier,
        net_adjustment_pct=net_adj,
    )
end

# ═══════════════════════════════════════════════════════════════
# HACRP — Hospital-Acquired Condition Reduction Program
# ═══════════════════════════════════════════════════════════════

"""
    HACRPMeasure

A single HACRP sub-measure (e.g. PSI-90, individual HAI z-score).

# Fields
- `measure_id::String`: measure identifier
- `observed::Float64`: observed rate or value
- `predicted::Float64`: risk-adjusted predicted rate
- `z_score::Float64`: standardized z-score (will be winsorized to [-3, 3])
"""
@kwdef struct HACRPMeasure
    measure_id::String
    observed::Float64
    predicted::Float64
    z_score::Float64
end

"""
    HACRPResult

HACRP calculation result.

# Fields
- `total_score::Float64`: weighted total HAC score
- `percentile::Float64`: estimated percentile rank (0-100)
- `penalty_applies::Bool`: true if in bottom quartile
- `penalty_pct::Float64`: penalty percentage (0.0 or -0.01)
"""
@kwdef struct HACRPResult
    total_score::Float64
    percentile::Float64
    penalty_applies::Bool
    penalty_pct::Float64
end

"""
    _winsorize_z(z::Float64) -> Float64

Winsorize a z-score to the range [-3, 3].
"""
function _winsorize_z(z::Float64)::Float64
    return clamp(z, -3.0, 3.0)
end

"""
    calculate_hacrp(measures::Vector{HACRPMeasure};
                    psi90_weight::Float64=0.5,
                    hai_weight::Float64=0.5,
                    quartile_cutoff::Float64=0.75) -> HACRPResult

Compute HACRP total score from winsorized z-scores. Hospitals in the
bottom quartile (above the 75th percentile cutoff for adverse scores)
receive a 1% DRG payment penalty.

The total score is the weighted average of winsorized z-scores. The
`quartile_cutoff` represents the z-score threshold above which a hospital
is considered bottom-quartile.
"""
function calculate_hacrp(measures::Vector{HACRPMeasure};
                         psi90_weight::Float64=0.5,
                         hai_weight::Float64=0.5,
                         quartile_cutoff::Float64=0.75)::HACRPResult
    isempty(measures) && return HACRPResult(
        total_score=0.0, percentile=0.0, penalty_applies=false, penalty_pct=0.0)

    # Winsorize all z-scores and separate into PSI-90 vs HAI measures
    psi_scores = Float64[]
    hai_scores = Float64[]
    for m in measures
        wz = _winsorize_z(m.z_score)
        if startswith(m.measure_id, "PSI")
            push!(psi_scores, wz)
        else
            push!(hai_scores, wz)
        end
    end

    # Weighted average: PSI-90 measures get psi90_weight, HAI measures get hai_weight
    total_score = if !isempty(psi_scores) && !isempty(hai_scores)
        psi_avg = sum(psi_scores) / length(psi_scores)
        hai_avg = sum(hai_scores) / length(hai_scores)
        (psi_avg * psi90_weight + hai_avg * hai_weight) / (psi90_weight + hai_weight)
    elseif !isempty(psi_scores)
        sum(psi_scores) / length(psi_scores)
    elseif !isempty(hai_scores)
        sum(hai_scores) / length(hai_scores)
    else
        0.0
    end

    # Estimate percentile from z-score (linear approximation for simplicity)
    # Map z from [-3, 3] to [0, 100]
    percentile = clamp((total_score + 3.0) / 6.0 * 100.0, 0.0, 100.0)

    # Penalty applies if total score exceeds quartile cutoff (higher = worse)
    penalty_applies = total_score > quartile_cutoff
    penalty_pct = penalty_applies ? -0.01 : 0.0

    return HACRPResult(
        total_score=total_score,
        percentile=percentile,
        penalty_applies=penalty_applies,
        penalty_pct=penalty_pct,
    )
end

# ═══════════════════════════════════════════════════════════════
# HRRP — Hospital Readmissions Reduction Program
# ═══════════════════════════════════════════════════════════════

"""
    HRRPCondition

A single condition under HRRP evaluation.

# Fields
- `condition::Symbol`: condition identifier (e.g. :ami, :hf, :pn, :copd, :hip_knee, :cabg)
- `predicted::Float64`: predicted readmission count (model-based)
- `expected::Float64`: expected readmission count (national average adjusted)
- `dual_eligible_adj::Float64`: dual-eligible proportion adjustment factor (default 1.0)
- `drg_payments::Float64`: DRG payments for this condition, used for payment-weighted averaging (default 1.0)
"""
@kwdef struct HRRPCondition
    condition::Symbol
    predicted::Float64
    expected::Float64
    dual_eligible_adj::Float64 = 1.0
    drg_payments::Float64 = 1.0
end

"""
    HRRPConditionResult

Per-condition result with excess readmission ratio.

# Fields
- `condition::Symbol`: condition identifier
- `excess_readmission_ratio::Float64`: ERR = predicted / expected * dual_adj
"""
@kwdef struct HRRPConditionResult
    condition::Symbol
    excess_readmission_ratio::Float64
end

"""
    HRRPResult

HRRP program calculation result.

# Fields
- `condition_results::Vector{HRRPConditionResult}`: per-condition ERR values
- `payment_adjustment::Float64`: multiplicative payment factor (e.g. 0.98 = 2% penalty)
- `penalty_pct::Float64`: penalty as a decimal fraction (0.0 to -0.03)
"""
@kwdef struct HRRPResult
    condition_results::Vector{HRRPConditionResult}
    payment_adjustment::Float64
    penalty_pct::Float64
end

"""
    calculate_hrrp(conditions::Vector{HRRPCondition},
                   base_drg_payments::Float64) -> HRRPResult

Compute HRRP payment adjustment from per-condition readmission data.

For each condition, the excess readmission ratio (ERR) is
`predicted / expected * dual_eligible_adj`. The aggregate penalty is
the DRG-payment-weighted sum of max(0, ERR - 1), capped at 3%.
"""
function calculate_hrrp(conditions::Vector{HRRPCondition},
                        base_drg_payments::Float64)::HRRPResult
    isempty(conditions) && return HRRPResult(
        condition_results=HRRPConditionResult[],
        payment_adjustment=1.0,
        penalty_pct=0.0,
    )

    results = HRRPConditionResult[]
    weighted_excess = 0.0
    total_payments = 0.0

    for c in conditions
        err = if c.expected > 0.0
            (c.predicted / c.expected) * c.dual_eligible_adj
        else
            1.0
        end
        push!(results, HRRPConditionResult(condition=c.condition,
                                            excess_readmission_ratio=err))
        weighted_excess += max(0.0, err - 1.0) * c.drg_payments
        total_payments += c.drg_payments
    end

    # Payment-weighted excess across conditions, capped at 3%
    avg_excess = total_payments > 0.0 ? weighted_excess / total_payments : 0.0
    penalty = min(avg_excess, 0.03)

    payment_adj = 1.0 - penalty
    penalty_pct = -penalty  # decimal fraction (e.g. -0.03 for 3% penalty)

    return HRRPResult(
        condition_results=results,
        payment_adjustment=payment_adj,
        penalty_pct=penalty_pct,
    )
end

# ═══════════════════════════════════════════════════════════════
# Star Ratings — Overall Hospital Quality Star Rating
# ═══════════════════════════════════════════════════════════════

"""
    StarRatingsMeasure

A measure within the CMS Star Ratings system.

# Fields
- `measure_id::String`: measure identifier
- `score::Float64`: standardized score (0.0-1.0)
- `weight::Float64`: measure weight within its group
- `group::String`: measure group name (e.g. "Mortality", "Safety of Care")
"""
@kwdef struct StarRatingsMeasure
    measure_id::String
    score::Float64
    weight::Float64
    group::String
end

"""
    StarRatingsResult

Star Ratings calculation result.

# Fields
- `overall_stars::Int`: assigned star rating (1-5)
- `group_scores::Vector{NamedTuple{(:group, :score, :weight), Tuple{String, Float64, Float64}}}`: per-group weighted scores
- `weighted_score::Float64`: overall weighted summary score
"""
@kwdef struct StarRatingsResult
    overall_stars::Int
    group_scores::Vector{NamedTuple{(:group, :score, :weight), Tuple{String, Float64, Float64}}}
    weighted_score::Float64
end

"""
    calculate_star_ratings(measures::Vector{StarRatingsMeasure}) -> StarRatingsResult

Compute the CMS Overall Hospital Quality Star Rating.

Groups measures by their `group` field, computes a weighted average within
each group, then a weighted summary score across groups. The summary score
is mapped to 1-5 stars using evenly spaced thresholds (0.2 intervals).
"""
function calculate_star_ratings(measures::Vector{StarRatingsMeasure})::StarRatingsResult
    isempty(measures) && return StarRatingsResult(
        overall_stars=1, group_scores=NamedTuple{(:group, :score, :weight), Tuple{String, Float64, Float64}}[], weighted_score=0.0)

    # Group measures by group name
    groups = Dict{String, Vector{StarRatingsMeasure}}()
    for m in measures
        push!(get!(Vector{StarRatingsMeasure}, groups, m.group), m)
    end

    # Compute per-group weighted score
    group_results = NamedTuple{(:group, :score, :weight), Tuple{String, Float64, Float64}}[]
    total_weight = 0.0
    weighted_sum = 0.0

    for (group_name, group_measures) in groups
        w_sum = sum(m.weight for m in group_measures)
        if w_sum > 0.0
            score = sum(m.score * m.weight for m in group_measures) / w_sum
        else
            score = sum(m.score for m in group_measures) / length(group_measures)
        end
        # Use the average weight as the group weight
        group_weight = w_sum / length(group_measures)
        push!(group_results, (group=group_name, score=score, weight=group_weight))
        total_weight += group_weight
        weighted_sum += score * group_weight
    end

    summary_score = total_weight > 0.0 ? weighted_sum / total_weight : 0.0

    # Map summary score to 1-5 stars using explicit threshold bands
    stars = if summary_score >= 0.8
        5
    elseif summary_score >= 0.6
        4
    elseif summary_score >= 0.4
        3
    elseif summary_score >= 0.2
        2
    else
        1
    end

    return StarRatingsResult(
        overall_stars=stars,
        group_scores=group_results,
        weighted_score=summary_score,
    )
end

"""
    star_ratings_sensitivity(measures::Vector{StarRatingsMeasure},
                             target_stars::Int) -> Dict{String, Float64}

What-if analysis: how much each measure group's score needs to change
to reach the target star rating. Returns a dictionary mapping group
names to the required score delta.
"""
function star_ratings_sensitivity(measures::Vector{StarRatingsMeasure},
                                  target_stars::Int)::Dict{String, Float64}
    1 <= target_stars <= 5 || error("target_stars must be between 1 and 5; got $target_stars")

    current = calculate_star_ratings(measures)
    # Target summary score is the midpoint of the star band
    # Stars map: 1 => [0, 0.2), 2 => [0.2, 0.4), ..., 5 => [0.8, 1.0]
    target_score = (target_stars - 0.5) / 5.0
    gap = target_score - current.weighted_score

    result = Dict{String, Float64}()
    for gs in current.group_scores
        # Per-group score change needed: gap/weight (since group contributes weight to overall)
        if gs.weight > 0.0
            result[gs.group] = gap / gs.weight
        else
            result[gs.group] = 0.0
        end
    end
    return result
end

# ═══════════════════════════════════════════════════════════════
# MIPS — Merit-Based Incentive Payment System
# ═══════════════════════════════════════════════════════════════

"""
    MIPSCategory

A single MIPS performance category.

# Fields
- `category_name::String`: category name (Quality, Cost, Promoting Interoperability, Improvement Activities)
- `score::Float64`: category score (0-100)
- `weight::Float64`: category weight (sums to 1.0)
"""
@kwdef struct MIPSCategory
    category_name::String
    score::Float64
    weight::Float64
end

"""
    MIPSResult

MIPS calculation result.

# Fields
- `categories::Vector{MIPSCategory}`: per-category breakdown
- `final_score::Float64`: weighted final MIPS score (0-100)
- `payment_adjustment_pct::Float64`: payment adjustment percentage
"""
@kwdef struct MIPSResult
    categories::Vector{MIPSCategory}
    final_score::Float64
    payment_adjustment_pct::Float64
end

"""
    calculate_mips(quality_score::Float64, cost_score::Float64,
                   pi_score::Float64, ia_score::Float64;
                   threshold::Float64=75.0,
                   exceptional::Float64=89.0) -> MIPSResult

Compute MIPS final score and payment adjustment.

Weights: Quality 30%, Cost 30%, Promoting Interoperability 25%,
Improvement Activities 15%.

Payment adjustment is based on final score relative to threshold:
- Below threshold: negative adjustment (linear, up to -9%)
- At threshold: 0%
- Above threshold: positive adjustment (linear, up to +9% at exceptional and above)
"""
function calculate_mips(quality_score::Float64, cost_score::Float64,
                        pi_score::Float64, ia_score::Float64;
                        threshold::Float64=75.0,
                        exceptional::Float64=89.0)::MIPSResult
    categories = [
        MIPSCategory(category_name="Quality", score=quality_score, weight=0.30),
        MIPSCategory(category_name="Cost", score=cost_score, weight=0.30),
        MIPSCategory(category_name="Promoting Interoperability", score=pi_score, weight=0.25),
        MIPSCategory(category_name="Improvement Activities", score=ia_score, weight=0.15),
    ]

    final_score = sum(c.score * c.weight for c in categories)

    # Payment adjustment based on relationship to threshold
    if final_score < threshold
        # Linear negative adjustment: 0% at threshold, -9% at score 0
        payment_adj = -9.0 * (threshold - final_score) / threshold
    elseif final_score >= exceptional
        # At or above exceptional: full +9%
        payment_adj = 9.0
    else
        # Between threshold and exceptional: linear positive
        payment_adj = 9.0 * (final_score - threshold) / (exceptional - threshold)
    end

    return MIPSResult(
        categories=categories,
        final_score=final_score,
        payment_adjustment_pct=payment_adj,
    )
end

# ═══════════════════════════════════════════════════════════════
# HAI — Healthcare-Associated Infections
# ═══════════════════════════════════════════════════════════════

"""
    HAIRecord

A single HAI observation record.

# Fields
- `infection_type::Symbol`: one of :CLABSI, :CAUTI, :SSI, :MRSA, :CDI
- `observed_events::Int`: number of observed infection events
- `predicted_events::Float64`: NHSN model-predicted events
- `device_days_or_patient_days::Float64`: denominator (device-days or patient-days)
"""
@kwdef struct HAIRecord
    infection_type::Symbol
    observed_events::Int
    predicted_events::Float64
    device_days_or_patient_days::Float64
end

"""
    HAITypeResult

Per-infection-type SIR result.

# Fields
- `infection_type::Symbol`: infection type
- `sir::Float64`: standardized infection ratio (observed / predicted)
- `observed::Int`: observed events
- `predicted::Float64`: predicted events
"""
@kwdef struct HAITypeResult
    infection_type::Symbol
    sir::Float64
    observed::Int
    predicted::Float64
end

"""
    HAIResult

HAI calculation result.

# Fields
- `type_results::Vector{HAITypeResult}`: per-infection SIR values
- `overall_composite::Float64`: composite SIR across all infection types
- `compliance_flag::Bool`: true if overall SIR <= 1.0 (better than expected)
"""
@kwdef struct HAIResult
    type_results::Vector{HAITypeResult}
    overall_composite::Float64
    compliance_flag::Bool
end

"""
    calculate_hai(records::Vector{HAIRecord}) -> HAIResult

Compute Standardized Infection Ratio (SIR) for each infection type
and an overall composite. SIR = total observed / total predicted.
"""
function calculate_hai(records::Vector{HAIRecord})::HAIResult
    isempty(records) && return HAIResult(
        type_results=HAITypeResult[],
        overall_composite=0.0,
        compliance_flag=true,
    )

    # Group by infection type
    type_groups = Dict{Symbol, Vector{HAIRecord}}()
    for r in records
        push!(get!(Vector{HAIRecord}, type_groups, r.infection_type), r)
    end

    type_results = HAITypeResult[]
    total_observed = 0
    total_predicted = 0.0

    for (itype, recs) in type_groups
        obs = sum(r.observed_events for r in recs)
        pred = sum(r.predicted_events for r in recs)
        sir = if pred > 0.0
            obs / pred
        elseif obs > 0
            Inf
        else
            0.0
        end
        push!(type_results, HAITypeResult(
            infection_type=itype,
            sir=sir,
            observed=obs,
            predicted=pred,
        ))
        total_observed += obs
        total_predicted += pred
    end

    composite = if total_predicted > 0.0
        total_observed / total_predicted
    elseif total_observed > 0
        Inf
    else
        0.0
    end
    compliance = composite <= 1.0

    return HAIResult(
        type_results=type_results,
        overall_composite=composite,
        compliance_flag=compliance,
    )
end

# ═══════════════════════════════════════════════════════════════
# Combined Payment Impact
# ═══════════════════════════════════════════════════════════════

"""
    CombinedPaymentResult

Combined waterfall of all CMS quality payment adjustments.

All individual adjustments are expressed as decimal fractions (e.g. -0.01 = -1%).

# Fields
- `vbp_adjustment::Float64`: VBP net adjustment as decimal fraction (e.g. -0.002)
- `hacrp_penalty::Float64`: HACRP penalty as decimal fraction (0.0 or -0.01)
- `hrrp_penalty::Float64`: HRRP penalty as decimal fraction (0.0 to -0.03)
- `net_impact_pct::Float64`: combined percentage impact
- `net_impact_dollars::Float64`: dollar impact on base DRG payments
"""
@kwdef struct CombinedPaymentResult
    vbp_adjustment::Float64
    hacrp_penalty::Float64
    hrrp_penalty::Float64
    net_impact_pct::Float64
    net_impact_dollars::Float64
end

"""
    calculate_combined_payment_impact(vbp_result::VBPResult,
                                      hacrp_result::HACRPResult,
                                      hrrp_result::HRRPResult,
                                      base_drg_payments::Float64) -> CombinedPaymentResult

Compute the combined (multiplicative) effect of VBP, HACRP, and HRRP
on base DRG payments. Effective payment = base * (1+VBP) * (1+HACRP) * HRRP_adj.
"""
function calculate_combined_payment_impact(vbp_result::VBPResult,
                                           hacrp_result::HACRPResult,
                                           hrrp_result::HRRPResult,
                                           base_drg_payments::Float64)::CombinedPaymentResult
    vbp_adj = vbp_result.net_adjustment_pct / 100.0    # VBP net_adjustment_pct is percentage, convert to decimal
    hacrp_pen = hacrp_result.penalty_pct               # already decimal fraction
    hrrp_pen = hrrp_result.penalty_pct                  # already decimal fraction

    # Multiplicative waterfall: effective = base * (1 + vbp) * (1 + hacrp) * (1 + hrrp)
    combined_multiplier = (1.0 + vbp_adj) * (1.0 + hacrp_pen) * (1.0 + hrrp_pen)
    net_pct = (combined_multiplier - 1.0) * 100.0
    net_dollars = base_drg_payments * (combined_multiplier - 1.0)

    return CombinedPaymentResult(
        vbp_adjustment=vbp_adj,
        hacrp_penalty=hacrp_pen,
        hrrp_penalty=hrrp_pen,
        net_impact_pct=net_pct,
        net_impact_dollars=net_dollars,
    )
end
