"""
    mips_vbp_hrrp.jl — CMS Quality Payment Adjustment Programs (MBA Gap E-06)

Implements the four major CMS hospital quality payment adjustment programs
with their actual scoring algorithms and payment adjustment thresholds.
This is the missing layer above the generic `value_based_care.jl` helpers.

## Programs implemented

### Physician-Level
1. **MIPS** (Merit-based Incentive Payment System) — CY2025 rules.
   4 performance categories → composite score → ±9% payment adjustment.

### Hospital-Level
2. **Hospital VBP** (Value-Based Purchasing) — FY2026 rules.
   4 domains → Total Performance Score (TPS) → ±2% payment adjustment.
3. **HRRP** (Hospital Readmissions Reduction Program) — FY2026 rules.
   Excess Readmission Ratio → 0% to -3% payment reduction.
4. **HACRP** (Hospital-Acquired Condition Reduction Program) — FY2026 rules.
   HAC Score (winsorized domain average) → -1% reduction for bottom quartile.

## References
- CMS MIPS Final Rule CY2025 (88 FR 77150)
- CMS IPPS Final Rule FY2026 (Tables 12–15)
- 42 CFR § 412.160–412.167 (VBP)
- 42 CFR § 412.150–412.154 (HRRP)
- 42 CFR § 412.170–412.178 (HACRP)
- CMS QualityNet: https://qualitynet.cms.gov
"""

using Statistics
using Printf

# ═════════════════════════════════════════════════════════════════════════════
# MIPS — Merit-Based Incentive Payment System (CY2025)
# ═════════════════════════════════════════════════════════════════════════════

"""
    MIPS category weights for CY2025 (final rule).

Quality: 30%, Promoting Interoperability: 25%, Improvement Activities: 15%,
Cost: 30%. Weights shift when categories are reweighted for small practices.
"""
const MIPS_WEIGHTS_CY2025 = (
    quality = 0.30,
    pi      = 0.25,   # Promoting Interoperability
    ia      = 0.15,   # Improvement Activities
    cost    = 0.30,
)

"""
    MIPS payment adjustment thresholds for CY2025.
- Performance threshold: 75 points → neutral adjustment.
- Exceptional performance threshold: 89 points → additional positive adjustment.
- Maximum negative adjustment: -9%.
- Maximum positive adjustment: +9% (scaled linearly above threshold).
- Exceptional performance adjustment: additional up to +10% (linear scaling above 89).
"""
const MIPS_THRESHOLDS_CY2025 = (
    performance_threshold     = 75.0,
    exceptional_threshold     = 89.0,
    max_negative_adjustment   = -0.09,
    max_positive_adjustment   = +0.09,
    exceptional_bonus_max     = +0.10,
)

"""
    MIPSScores

Input scores for the four MIPS performance categories.

# Fields
- `quality_score::Float64`: Quality category score (0–100).
- `pi_score::Float64`: Promoting Interoperability score (0–100; or `missing` if exempt).
- `ia_score::Float64`: Improvement Activities score (0–100).
- `cost_score::Float64`: Cost category score (0–100).
- `small_practice::Bool`: If `true`, reweights categories (Quality 50%, Cost 50%).
- `pi_exempt::Bool`: If `true`, PI weight redistributed to Quality.
- `reweight_ia::Bool`: If `true`, IA weight redistributed to Quality.
"""
@kwdef struct MIPSScores
    quality_score::Float64
    pi_score::Float64      = 50.0   # default if PI scored
    ia_score::Float64      = 40.0   # default partial credit
    cost_score::Float64    = 50.0
    small_practice::Bool   = false
    pi_exempt::Bool        = false
    reweight_ia::Bool      = false
end

"""
    MIPSResult

MIPS composite score and payment adjustment.

# Fields
- `composite_score::Float64`: Weighted average across categories (0–100).
- `payment_adjustment_pct::Float64`: % payment adjustment (positive or negative).
- `exceptional_bonus_pct::Float64`: Additional exceptional performance bonus.
- `total_adjustment_pct::Float64`: `payment_adjustment_pct + exceptional_bonus_pct`.
- `category_scores::NamedTuple`: Weighted contribution from each category.
- `performance_tier::Symbol`: `:negative`, `:neutral`, `:positive`, `:exceptional`.
"""
struct MIPSResult
    composite_score::Float64
    payment_adjustment_pct::Float64
    exceptional_bonus_pct::Float64
    total_adjustment_pct::Float64
    category_scores::NamedTuple
    performance_tier::Symbol
end

"""
    calculate_mips(scores::MIPSScores) -> MIPSResult

Compute MIPS composite score and payment adjustment per CY2025 rules.

# Payment adjustment logic
- Below 75: negative adjustment, scaled linearly: `(score / 75) × 9% - 9%`.
- At 75 (exactly): 0% adjustment.
- Above 75 and ≤ 89: positive adjustment, scaled: `(score - 75) / 25 × 9%`.
- Above 89: same positive slope + exceptional bonus up to 10%.
"""
function calculate_mips(scores::MIPSScores)::MIPSResult
    # Determine weights with reweighting
    w_quality = MIPS_WEIGHTS_CY2025.quality
    w_pi      = MIPS_WEIGHTS_CY2025.pi
    w_ia      = MIPS_WEIGHTS_CY2025.ia
    w_cost    = MIPS_WEIGHTS_CY2025.cost

    if scores.small_practice
        w_quality = 0.50; w_pi = 0.0; w_ia = 0.0; w_cost = 0.50
    else
        if scores.pi_exempt
            w_quality += w_pi; w_pi = 0.0
        end
        if scores.reweight_ia
            w_quality += w_ia; w_ia = 0.0
        end
    end

    cat_q  = scores.quality_score * w_quality
    cat_pi = scores.pi_score      * w_pi
    cat_ia = scores.ia_score      * w_ia
    cat_c  = scores.cost_score    * w_cost

    composite = cat_q + cat_pi + cat_ia + cat_c

    t = MIPS_THRESHOLDS_CY2025
    adj, bonus = 0.0, 0.0
    tier = :neutral

    if composite < t.performance_threshold
        # Negative: linear from -9% (score=0) to 0% (score=75)
        adj  = (composite / t.performance_threshold - 1.0) * abs(t.max_negative_adjustment)
        tier = :negative
    elseif composite == t.performance_threshold
        adj  = 0.0
        tier = :neutral
    elseif composite <= t.exceptional_threshold
        # Positive: linear from 0% (75) to +9% (scaled)
        adj  = (composite - t.performance_threshold) /
               (100.0 - t.performance_threshold) * t.max_positive_adjustment
        tier = :positive
    else
        # Exceptional: same positive slope + exceptional bonus
        adj  = (composite - t.performance_threshold) /
               (100.0 - t.performance_threshold) * t.max_positive_adjustment
        bonus = (composite - t.exceptional_threshold) /
                (100.0 - t.exceptional_threshold) * t.exceptional_bonus_max
        tier = :exceptional
    end

    MIPSResult(
        composite, adj, bonus, adj + bonus,
        (quality=cat_q, pi=cat_pi, ia=cat_ia, cost=cat_c),
        tier,
    )
end

# ═════════════════════════════════════════════════════════════════════════════
# Hospital Value-Based Purchasing (VBP) — FY2026
# ═════════════════════════════════════════════════════════════════════════════

"""
    VBP domain weights for FY2026.

Clinical Outcomes: 40%, Person & Community Engagement: 25%,
Safety: 25%, Efficiency & Cost Reduction: 10%.
"""
const VBP_DOMAIN_WEIGHTS_FY2026 = (
    clinical_outcomes = 0.40,
    person_engagement = 0.25,
    safety            = 0.25,
    efficiency        = 0.10,
)

"""
    VBP payment adjustment parameters for FY2026.
Maximum withhold: 2% of base operating payments.
Payment range: 0% to 4% (2% withhold redistributed → max +2% net above baseline).
"""
const VBP_ADJUSTMENT_PARAMS_FY2026 = (
    withhold_pct     = 0.02,    # 2% withheld from IPPS payments
    min_tps_for_full = 100.0,   # TPS at which hospital receives 100% of withhold + full bonus
)

"""
    VBPDomainScores

Achievement and improvement scores for the four VBP domains.

Each domain score is 0–100 from the higher of achievement or improvement.

# Fields (for each domain: `:clinical_outcomes`, `:person_engagement`, `:safety`, `:efficiency`)
Each field: `Float64` score 0–100.
"""
@kwdef struct VBPDomainScores
    clinical_outcomes::Float64
    person_engagement::Float64
    safety::Float64
    efficiency::Float64
end

"""
    VBPResult

Hospital VBP Total Performance Score and payment adjustment.

# Fields
- `domain_scores::VBPDomainScores`
- `tps::Float64`: Total Performance Score (0–100).
- `payment_adjustment_pct::Float64`: Net adjustment to base operating IPPS payment.
- `withhold_recovered_pct::Float64`: Portion of 2% withhold returned (0–2%).
- `bonus_pct::Float64`: Any bonus above the returned withhold.
- `performance_tier::Symbol`: `:below_median`, `:above_median`, `:top_performer`.
"""
struct VBPResult
    domain_scores::VBPDomainScores
    tps::Float64
    payment_adjustment_pct::Float64
    withhold_recovered_pct::Float64
    bonus_pct::Float64
    performance_tier::Symbol
end

"""
    calculate_vbp(domain_scores::VBPDomainScores) -> VBPResult

Compute Hospital VBP Total Performance Score and payment adjustment for FY2026.

## TPS Calculation
TPS = weighted sum of the 4 domain scores (each 0–100).

## Payment Adjustment
- TPS is mapped linearly: TPS=0 → lose all 2% withhold (−2% net);
  TPS=50 → neutral (recover all 2%); TPS=100 → +2% bonus above withhold.
- Net adjustment = `(TPS / 50 − 1) × 2%`, clamped to [−2%, +2%].

# Example
```julia
scores = VBPDomainScores(clinical_outcomes=62.0, person_engagement=74.0,
                          safety=58.0, efficiency=70.0)
r = calculate_vbp(scores)
r.tps                    # ~64 (above neutral)
r.payment_adjustment_pct # ~+0.56% net adjustment
```
"""
function calculate_vbp(domain_scores::VBPDomainScores)::VBPResult
    w = VBP_DOMAIN_WEIGHTS_FY2026
    tps = (domain_scores.clinical_outcomes * w.clinical_outcomes +
           domain_scores.person_engagement * w.person_engagement +
           domain_scores.safety            * w.safety            +
           domain_scores.efficiency        * w.efficiency)

    # Linear scaling: TPS 0 → −2%, TPS 50 → 0%, TPS 100 → +2%
    net_adj = clamp((tps / 50.0 - 1.0) * VBP_ADJUSTMENT_PARAMS_FY2026.withhold_pct, -0.02, 0.02)

    # Decompose into withhold recovery + bonus
    withhold_recovered = min(net_adj + VBP_ADJUSTMENT_PARAMS_FY2026.withhold_pct,
                             VBP_ADJUSTMENT_PARAMS_FY2026.withhold_pct)
    bonus = max(net_adj, 0.0)

    tier = tps >= 75 ? :top_performer : tps >= 50 ? :above_median : :below_median

    VBPResult(domain_scores, tps, net_adj, withhold_recovered, bonus, tier)
end

# ═════════════════════════════════════════════════════════════════════════════
# Hospital Readmissions Reduction Program (HRRP) — FY2026
# ═════════════════════════════════════════════════════════════════════════════

"""
    HRRP_MEASURES_FY2026

The six conditions measured under HRRP for FY2026.
Key: condition symbol → display name.
"""
const HRRP_MEASURES_FY2026 = Dict{Symbol,String}(
    :ami    => "Acute Myocardial Infarction (AMI)",
    :cabg   => "Coronary Artery Bypass Graft (CABG)",
    :copd   => "Chronic Obstructive Pulmonary Disease (COPD)",
    :hf     => "Heart Failure",
    :pna    => "Pneumonia",
    :tha_tka => "Total Hip/Knee Arthroplasty (THA/TKA)",
)

"""
    HRRPMeasure

Observed and expected readmission data for one HRRP condition.

# Fields
- `condition::Symbol`
- `observed_readmissions::Int`
- `predicted_readmissions::Float64`: Model-predicted readmissions.
- `expected_readmissions::Float64`: Expected given case mix (from CMS regression model).
- `discharges::Int`
"""
@kwdef struct HRRPMeasure
    condition::Symbol
    observed_readmissions::Int
    predicted_readmissions::Float64
    expected_readmissions::Float64
    discharges::Int
end

"""
    HRRPResult

HRRP payment reduction result.

# Fields
- `measures::Vector{HRRPMeasure}`
- `excess_readmission_ratios::Dict{Symbol,Float64}`: ERR = predicted / expected per condition.
- `aggregate_payments_ratio::Float64`: Weighted aggregate payment ratio (APR).
- `payment_reduction_pct::Float64`: 0% to -3% (APR maps to reduction).
- `n_conditions_excess::Int`: How many conditions have ERR > 1.0.
- `performance_tier::Symbol`: `:no_penalty`, `:penalty_1`, `:penalty_2`, `:max_penalty`.
"""
struct HRRPResult
    measures::Vector{HRRPMeasure}
    excess_readmission_ratios::Dict{Symbol,Float64}
    aggregate_payments_ratio::Float64
    payment_reduction_pct::Float64
    n_conditions_excess::Int
    performance_tier::Symbol
end

"""
    calculate_hrrp(measures::Vector{HRRPMeasure}) -> HRRPResult

Compute HRRP payment reduction for FY2026.

## Algorithm (42 CFR § 412.154)
1. For each condition: ERR = predicted_readmissions / expected_readmissions.
   - ERR ≤ 1.0: no excess readmissions for this condition.
   - ERR > 1.0: excess readmissions present.

2. Aggregate Payment Ratio (APR):
   APR = sum(predicted) / sum(expected) — weighted by discharges.

3. Payment reduction:
   - APR ≤ 1.0: no reduction.
   - APR 1.0–1.10: reduction = (APR − 1.0) × 30% (up to 3%).
   - APR > 1.10: maximum −3%.
   (Approximation of the CMS piecewise adjustment function.)
"""
function calculate_hrrp(measures::Vector{HRRPMeasure})::HRRPResult
    isempty(measures) && throw(ArgumentError("measures must not be empty"))

    errs = Dict{Symbol,Float64}()
    for m in measures
        m.expected_readmissions > 0 ||
            throw(ArgumentError("expected_readmissions must be > 0 for condition $(m.condition)"))
        errs[m.condition] = m.predicted_readmissions / m.expected_readmissions
    end

    # APR: ratio of sums
    total_predicted = sum(m.predicted_readmissions for m in measures)
    total_expected  = sum(m.expected_readmissions  for m in measures)
    apr = total_expected > 0 ? total_predicted / total_expected : 1.0

    # Payment reduction
    reduction = if apr <= 1.0
        0.0
    elseif apr <= 1.10
        min((apr - 1.0) * 0.30, 0.03)
    else
        0.03
    end
    reduction = -reduction   # negative

    n_excess = count(v -> v > 1.0, values(errs))
    tier = reduction == 0.0 ? :no_penalty :
           reduction > -0.01 ? :penalty_1 :
           reduction > -0.02 ? :penalty_2 : :max_penalty

    HRRPResult(measures, errs, apr, reduction, n_excess, tier)
end

# ═════════════════════════════════════════════════════════════════════════════
# Hospital-Acquired Condition Reduction Program (HACRP) — FY2026
# ═════════════════════════════════════════════════════════════════════════════

"""
    HACRP domain composition for FY2026.

Domain 1 (weighted 15%): AHRQ PSI-90 composite.
Domain 2 (weighted 85%): CDC NHSN HAI measures:
  - CLABSI (Central Line-Associated Bloodstream Infection)
  - CAUTI (Catheter-Associated Urinary Tract Infection)
  - SSI (Surgical Site Infection) — Colon and Hysterectomy
  - MRSA Bacteremia
  - CDI (C. difficile Infection)

HAC Score = winsorized average of Domain 1 and Domain 2 scores.
Bottom quartile (HAC Score in top 25%) → 1% payment reduction.
"""
const HACRP_DOMAIN_WEIGHTS_FY2026 = (
    domain1_psi90 = 0.15,
    domain2_nhsn  = 0.85,
)

"""
    HACRPInputs

HAC scores for the two HACRP domains.

Scores are Standardized Infection Ratios (SIR) or PSI composites —
lower is better.

# Fields
- `psi90_score::Float64`: AHRQ PSI-90 composite (lower = fewer patient safety events).
  Typical range 0.5–1.5; national mean ≈ 1.00.
- `clabsi_sir::Float64`, `cauti_sir::Float64`, `ssi_colon_sir::Float64`,
  `ssi_hyst_sir::Float64`, `mrsa_sir::Float64`, `cdi_sir::Float64`:
  NHSN standardized infection ratios (0 = no infections; 1.0 = national average).
"""
@kwdef struct HACRPInputs
    psi90_score::Float64       = 1.00
    clabsi_sir::Float64        = 1.00
    cauti_sir::Float64         = 1.00
    ssi_colon_sir::Float64     = 1.00
    ssi_hyst_sir::Float64      = 1.00
    mrsa_sir::Float64          = 1.00
    cdi_sir::Float64           = 1.00
end

"""
    HACRPResult

HACRP HAC score and payment reduction.

# Fields
- `domain1_score::Float64`: PSI-90 (winsorized to [0.05, 2.0]).
- `domain2_score::Float64`: Mean NHSN SIR (winsorized to [0.05, 2.5]).
- `hac_score::Float64`: Weighted composite (lower is better).
- `payment_reduction_pct::Float64`: 0% or -1%.
- `bottom_quartile::Bool`: Whether this hospital is in the worst-performing quartile.
  NOTE: Bottom-quartile designation requires national peer comparison data not
  embedded here. This flag is set by `is_bottom_quartile` parameter.
- `performance_tier::Symbol`: `:penalty` or `:no_penalty`.
"""
struct HACRPResult
    domain1_score::Float64
    domain2_score::Float64
    hac_score::Float64
    payment_reduction_pct::Float64
    bottom_quartile::Bool
    performance_tier::Symbol
end

"""
    calculate_hacrp(inputs::HACRPInputs; is_bottom_quartile=nothing,
                    national_mean_hac_score=1.0) -> HACRPResult

Compute HACRP HAC score and payment reduction.

## Algorithm (42 CFR § 412.170–412.178)
1. Winsorize Domain 1 (PSI-90) to [0.05, 2.0].
2. Winsorize each Domain 2 measure to [0.05, 2.5], then average.
3. HAC Score = 0.15 × Domain1 + 0.85 × Domain2.
4. Hospitals in the worst-performing quartile nationally receive −1%.

## Bottom-quartile determination
Set `is_bottom_quartile = true` if you know the hospital's national ranking.
Set `is_bottom_quartile = nothing` (default) to use a proxy comparison:
  HAC score > `national_mean_hac_score × 1.25` → probable bottom quartile.

# Example
```julia
inputs = HACRPInputs(psi90_score=1.45, clabsi_sir=1.8, cauti_sir=1.2,
                      ssi_colon_sir=0.9, ssi_hyst_sir=1.1,
                      mrsa_sir=1.5, cdi_sir=1.3)
r = calculate_hacrp(inputs; national_mean_hac_score=1.00)
r.hac_score           # > 1.0 → likely penalty
r.payment_reduction_pct  # -0.01 if bottom quartile
```
"""
function calculate_hacrp(
    inputs::HACRPInputs;
    is_bottom_quartile::Union{Bool,Nothing} = nothing,
    national_mean_hac_score::Float64 = 1.0,
)::HACRPResult

    # Domain 1: PSI-90 (winsorized)
    d1 = clamp(inputs.psi90_score, 0.05, 2.0)

    # Domain 2: NHSN measures (winsorize each, then average)
    sirs = [inputs.clabsi_sir, inputs.cauti_sir, inputs.ssi_colon_sir,
            inputs.ssi_hyst_sir, inputs.mrsa_sir, inputs.cdi_sir]
    d2_measures = clamp.(sirs, 0.05, 2.5)
    d2 = mean(d2_measures)

    # Weighted HAC score
    hac = HACRP_DOMAIN_WEIGHTS_FY2026.domain1_psi90 * d1 +
          HACRP_DOMAIN_WEIGHTS_FY2026.domain2_nhsn  * d2

    # Bottom-quartile determination
    bq = if isnothing(is_bottom_quartile)
        hac > national_mean_hac_score * 1.25   # proxy: >25% above mean
    else
        is_bottom_quartile
    end

    reduction = bq ? -0.01 : 0.0
    tier = bq ? :penalty : :no_penalty

    HACRPResult(d1, d2, hac, reduction, bq, tier)
end

# ═════════════════════════════════════════════════════════════════════════════
# Combined Quality Payment Impact
# ═════════════════════════════════════════════════════════════════════════════

"""
    HospitalQualityPaymentImpact

Combined impact of all three hospital-level CMS quality programs.

# Fields
- `vbp_result::VBPResult`
- `hrrp_result::HRRPResult`
- `hacrp_result::HACRPResult`
- `total_adjustment_pct::Float64`: VBP + HRRP + HACRP combined.
- `net_dollar_impact::Float64`: Dollar impact on the hospital's annual IPPS revenue.
"""
struct HospitalQualityPaymentImpact
    vbp_result::VBPResult
    hrrp_result::HRRPResult
    hacrp_result::HACRPResult
    total_adjustment_pct::Float64
    net_dollar_impact::Float64
end

"""
    hospital_quality_payment_impact(
        vbp_scores::VBPDomainScores,
        hrrp_measures::Vector{HRRPMeasure},
        hacrp_inputs::HACRPInputs;
        annual_ipps_revenue,
        is_bottom_quartile = nothing
    ) -> HospitalQualityPaymentImpact

Compute the combined quality payment adjustment across VBP, HRRP, and HACRP.

Note: The three programs are applied sequentially to the IPPS base payment.
The total_adjustment_pct approximates the combined effect.

# Example
```julia
impact = hospital_quality_payment_impact(
    VBPDomainScores(clinical_outcomes=65.0, person_engagement=70.0,
                    safety=55.0, efficiency=62.0),
    hrrp_measures,
    HACRPInputs(psi90_score=1.1),
    annual_ipps_revenue = 12_000_000.0,
)
impact.net_dollar_impact   # e.g. -\$85,000
```
"""
function hospital_quality_payment_impact(
    vbp_scores::VBPDomainScores,
    hrrp_measures::Vector{HRRPMeasure},
    hacrp_inputs::HACRPInputs;
    annual_ipps_revenue::Float64,
    is_bottom_quartile::Union{Bool,Nothing} = nothing,
)::HospitalQualityPaymentImpact

    vbp  = calculate_vbp(vbp_scores)
    hrrp = calculate_hrrp(hrrp_measures)
    hacrp = calculate_hacrp(hacrp_inputs; is_bottom_quartile=is_bottom_quartile)

    total_pct = vbp.payment_adjustment_pct +
                hrrp.payment_reduction_pct +
                hacrp.payment_reduction_pct

    dollar_impact = annual_ipps_revenue * total_pct

    HospitalQualityPaymentImpact(vbp, hrrp, hacrp, total_pct, dollar_impact)
end
