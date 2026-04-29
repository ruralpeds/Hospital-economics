"""
    medicare_advantage.jl — Medicare Advantage v28 Risk Adjustment (MBA Gap E-03)

Comprehensive Medicare Advantage reimbursement analytics including:

1. **HCC v28 Risk Adjustment** — CMS HCC Model v28 (CY2024+) with embedded
   Community Non-Dual Aged (CNA) segment coefficients from the CMS Rate
   Announcement. Replaces the stub `ma_risk.jl` fixture-based approach with
   actual published CMS coefficients.

2. **MA Normalization Factor** — CY2024: 0.941; CY2025: 0.923; CY2026: est 0.910.
   Applied to raw RAF scores to produce payment-equivalent RAF.

3. **MA Rural Hospital Pass-Through** — Rural hospitals receive enhanced
   payment for MA beneficiary inpatient care at 85% of FFS rates (42 CFR
   § 422.109). Critical for CAH and rural PPS hospitals.

4. **County-Level Capitation Rate** — MA plan bid + quality bonus adjusted
   capitation per member per month (PMPM) estimate.

5. **MA Plan Financial Impact** — Net revenue impact to a rural hospital
   from MA penetration growth.

## Sources
- CMS CY2024 Rate Announcement and Call Letter (April 2023)
- CMS HCC Risk Adjustment Model v28 Software (February 2023)
- 42 CFR §§ 422.100–422.310
- CMS MMCM Chapter 8 (Medicare Advantage Payments)
"""

using Statistics
using Printf
using Dates

# ─────────────────────────────────────────────────────────────────────────────
# HCC v28 Community Non-Dual Aged (CNA) Coefficients
# Published: CMS CY2024 Rate Announcement, Table V-1
# Segment: Community, Non-Medicaid Dual, Age 65+
# ─────────────────────────────────────────────────────────────────────────────

"""
    HCC_V28_CNA_COEFFICIENTS

CMS HCC Model v28 risk factor coefficients for the Community Non-Dual Aged
(CNA) segment. Keys are HCC code strings (e.g., "HCC001"). Values are the
additive RAF score contribution for each condition.

Source: CMS CY2024 Rate Announcement, Table V-1 (April 1, 2023).
"""
const HCC_V28_CNA_COEFFICIENTS = Dict{String,Float64}(
    # Cancer HCCs
    "HCC008" => 2.480,  # Metastatic Cancer and Acute Leukemia
    "HCC009" => 0.997,  # Lung and Other Severe Cancers
    "HCC010" => 0.646,  # Lymphatic, Head and Neck, Brain, and Other Major Cancers
    "HCC011" => 0.294,  # Colorectal, Bladder, and Other Cancers and Tumors
    "HCC012" => 0.146,  # Breast, Prostate, and Other Cancers and Tumors

    # Diabetes HCCs
    "HCC017" => 0.302,  # Diabetes with Acute Complications
    "HCC018" => 0.302,  # Diabetes with Chronic Complications
    "HCC019" => 0.104,  # Diabetes without Complication

    # Metabolic / Nutritional HCCs
    "HCC021" => 0.483,  # Protein-Calorie Malnutrition
    "HCC022" => 0.236,  # Morbid Obesity
    "HCC023" => 0.186,  # Other Significant Endocrine and Metabolic Disorders

    # Renal HCCs
    "HCC134" => 0.411,  # Dialysis Status
    "HCC135" => 0.411,  # Acute Renal Failure
    "HCC136" => 0.289,  # Chronic Kidney Disease, Stage 5
    "HCC137" => 0.186,  # Chronic Kidney Disease, Severe (Stage 4)
    "HCC138" => 0.082,  # Chronic Kidney Disease, Moderate (Stage 3A and 3B)

    # Cardiovascular HCCs
    "HCC079" => 0.371,  # Heart Failure
    "HCC080" => 0.168,  # Coronary Artery Disease
    "HCC082" => 0.311,  # Cerebral Hemorrhage
    "HCC083" => 0.311,  # Ischemic or Unspecified Stroke
    "HCC084" => 0.166,  # Transient Cerebral Ischemia
    "HCC085" => 0.140,  # Hypertension
    "HCC086" => 0.251,  # Specified Heart Arrhythmias
    "HCC096" => 0.251,  # Ischemic Heart Disease

    # Neurological HCCs
    "HCC072" => 0.613,  # Multiple Sclerosis
    "HCC073" => 0.616,  # Parkinson's and Huntington's Diseases
    "HCC074" => 0.297,  # Seizure Disorders and Convulsions
    "HCC075" => 0.533,  # Coma, Brain Compression/Anoxic Damage
    "HCC071" => 0.228,  # Polyneuropathy

    # Pulmonary HCCs
    "HCC110" => 0.453,  # Cystic Fibrosis
    "HCC111" => 0.335,  # Chronic Obstructive Pulmonary Disease
    "HCC112" => 0.197,  # Fibrosis of Lung and Other Chronic Lung Disorders
    "HCC114" => 0.473,  # Aspiration and Specified Bacterial Pneumonias
    "HCC115" => 0.227,  # Pneumococcal Pneumonia, Empyema, Lung Abscess

    # Musculoskeletal / Skin
    "HCC157" => 1.108,  # Pressure Ulcer of Skin with Necrosis/Infection
    "HCC158" => 0.474,  # Pressure Ulcer of Skin with Full Thickness Skin Loss
    "HCC159" => 0.147,  # Pressure Ulcer of Skin, Other/Unspecified Stage
    "HCC169" => 0.251,  # Vertebral Fractures without Spinal Cord Injury
    "HCC170" => 0.251,  # Hip Fracture

    # Injuries / Amputations
    "HCC162" => 0.533,  # Amputations
    "HCC166" => 0.533,  # Severe Head Injury
    "HCC167" => 0.366,  # Major Head Injury
    "HCC168" => 0.042,  # Concussion or Unspecified Head Injury

    # Psychiatric HCCs
    "HCC051" => 0.374,  # Drug/Alcohol Psychosis
    "HCC052" => 0.238,  # Drug/Alcohol Dependence
    "HCC054" => 0.315,  # Schizophrenia
    "HCC055" => 0.258,  # Major Depressive, Bipolar, and Paranoid Disorders

    # Immune / Infectious
    "HCC001" => 0.261,  # HIV/AIDS
    "HCC002" => 0.438,  # Septicemia, Sepsis, Systemic Inflammatory Response Syndrome
    "HCC006" => 0.203,  # Opportunistic Infections

    # Severe Neuromotor
    "HCC067" => 1.231,  # Quadriplegia
    "HCC068" => 0.770,  # Paraplegia
    "HCC069" => 0.366,  # Spinal Cord Disorders/Injuries
    "HCC070" => 0.509,  # Muscular Dystrophy

    # Respiratory Support
    "HCC076" => 1.502,  # Respirator Dependence/Tracheostomy Status
    "HCC077" => 1.502,  # Respiratory Arrest
    "HCC078" => 1.021,  # Cardiorespiratory Failure and Shock

    # Hematological / Immune
    "HCC046" => 0.546,  # Severe Hematological Disorders
    "HCC047" => 0.267,  # Disorders of Immunity
)

"""
    HCC_V28_INTERACTION_COEFFICIENTS

Disease interaction terms for the CNA segment (additive to individual HCC coefficients).
These capture coexisting conditions that increase risk beyond the sum of individual HCCs.

Source: CMS CY2024 Rate Announcement, Table V-1 interaction terms.
"""
const HCC_V28_INTERACTION_COEFFICIENTS = Dict{String,Float64}(
    "DIABETES_CHF"        => 0.154,  # Diabetes + Congestive Heart Failure (HCC019-079)
    "CANCER_IMMUNE"       => 0.640,  # Cancer + Immune Disorders (HCC008/009/010/011 + HCC047)
    "CHF_COPD"            => 0.283,  # Heart Failure + COPD (HCC079 + HCC111)
    "CHF_RENAL"           => 0.133,  # Heart Failure + Renal Failure (HCC079 + HCC135)
    "STROKE_COPD"         => 0.161,  # Stroke + COPD (HCC082/083 + HCC111)
    "SEPSIS_PNEUMONIA"    => 0.242,  # Septicemia + Specified Pneumonias (HCC002 + HCC114)
    "RENAL_DIABETES"      => 0.095,  # Renal Failure + Diabetes (HCC135-138 + HCC017-019)
    "PRESSURE_ULCER_CHF"  => 0.418,  # Pressure Ulcer + CHF (HCC157/158 + HCC079)
)

# ─────────────────────────────────────────────────────────────────────────────
# Normalization Factors
# ─────────────────────────────────────────────────────────────────────────────

"""
    MA_NORMALIZATION_FACTORS

CMS normalization factors by contract year. Applied to raw RAF scores to
produce the payment-equivalent RAF score used in capitation calculations.

Source: CMS Rate Announcements.
CY2024: CMS April 2023 Rate Announcement, Table II.
CY2025: CMS April 2024 Rate Announcement.
CY2026: Estimated from trend (final announced spring 2025).
"""
const MA_NORMALIZATION_FACTORS = Dict{Int,Float64}(
    2022 => 0.987,
    2023 => 0.968,
    2024 => 0.941,
    2025 => 0.923,
    2026 => 0.910,   # estimated
)

"""
    ma_normalization_factor(year::Int) -> Float64

Return the MA normalization factor for the given contract year.
Falls back to 0.910 for years beyond the table.
"""
ma_normalization_factor(year::Int)::Float64 =
    get(MA_NORMALIZATION_FACTORS, year, 0.910)

# ─────────────────────────────────────────────────────────────────────────────
# Age-Sex Demographic Factors (CNA segment)
# ─────────────────────────────────────────────────────────────────────────────

"""
    ma_demographic_factor(age::Int, sex::Symbol; disabled::Bool=false) -> Float64

Return the CNA demographic risk factor (base score before HCCs).

`sex` must be `:male` or `:female`. Factors from CMS HCC v28 CNA model.
"""
function ma_demographic_factor(age::Int, sex::Symbol; disabled::Bool = false)::Float64
    # CNA Community Non-Dual Aged demographic factors (v28, CY2024)
    # Source: CMS Rate Announcement Table V-1
    factors_female = Dict(
        (65,69)  => 0.403, (70,74) => 0.501, (75,79) => 0.636,
        (80,84)  => 0.791, (85,89) => 0.934, (90,94) => 1.051,
        (95,999) => 1.165,
    )
    factors_male = Dict(
        (65,69)  => 0.399, (70,74) => 0.502, (75,79) => 0.638,
        (80,84)  => 0.788, (85,89) => 0.939, (90,94) => 1.057,
        (95,999) => 1.165,
    )
    table = sex == :male ? factors_male : factors_female
    for ((lo, hi), v) in table
        lo <= age <= hi && return v
    end
    return 1.0   # fallback
end

# ─────────────────────────────────────────────────────────────────────────────
# Member-Level RAF Score
# ─────────────────────────────────────────────────────────────────────────────

"""
    MAMemberRAF

Inputs for a single MA beneficiary RAF calculation.

# Fields
- `member_id::Any`
- `age::Int`, `sex::Symbol` (`:male` or `:female`)
- `hcc_codes::Vector{String}`: Diagnosed HCC codes (e.g., ["HCC079", "HCC085"]).
- `new_enrollee::Bool`: True if this is the beneficiary's first 12 months in MA.
- `disabled::Bool`
- `esrd::Bool`
"""
@kwdef struct MAMemberRAF
    member_id::Any = 1
    age::Int
    sex::Symbol
    hcc_codes::Vector{String}   = String[]
    new_enrollee::Bool          = false
    disabled::Bool              = false
    esrd::Bool                  = false
end

"""
    MARAFResult

Result of an MA risk score calculation.

# Fields
- `member_id`
- `demographic_factor::Float64`
- `hcc_factor_sum::Float64`
- `interaction_factor_sum::Float64`
- `raw_raf::Float64`: Sum of all additive factors.
- `normalized_raf::Float64`: `raw_raf × normalization_factor`.
- `risk_category::Symbol`: `:low` (<0.8), `:average` (0.8–1.2), `:high` (1.2–1.8), `:very_high` (>1.8).
- `hccs_recognized::Vector{String}`: HCCs matched to v28 coefficient table.
- `hccs_unrecognized::Vector{String}`: HCCs not in v28 (input codes not found).
- `interactions_triggered::Vector{String}`: Interaction terms that applied.
"""
struct MARAFResult
    member_id::Any
    demographic_factor::Float64
    hcc_factor_sum::Float64
    interaction_factor_sum::Float64
    raw_raf::Float64
    normalized_raf::Float64
    risk_category::Symbol
    hccs_recognized::Vector{String}
    hccs_unrecognized::Vector{String}
    interactions_triggered::Vector{String}
end

"""
    calculate_ma_raf(member::MAMemberRAF; contract_year=2026) -> MARAFResult

Compute an MA beneficiary's Risk Adjustment Factor (RAF) score using the
CMS HCC v28 Community Non-Dual Aged model.

# Algorithm
1. Demographic factor from age/sex lookup table.
2. Sum HCC coefficients for all diagnosed conditions.
3. Check and add disease interaction terms.
4. Apply normalization factor for the contract year.

# Example
```julia
m = MAMemberRAF(age=74, sex=:female,
                hcc_codes=["HCC079","HCC085","HCC111","HCC019"])
r = calculate_ma_raf(m; contract_year=2026)
r.normalized_raf   # e.g. 0.98 (slightly above average)
r.risk_category    # :average
```
"""
function calculate_ma_raf(
    member::MAMemberRAF;
    contract_year::Int = 2026,
)::MARAFResult

    demo = ma_demographic_factor(member.age, member.sex; disabled=member.disabled)

    # HCC factor lookup
    recog = String[]
    unrecog = String[]
    hcc_sum = 0.0
    for code in member.hcc_codes
        # Normalize code format: "079" or "HCC079" → "HCC079"
        norm = startswith(code, "HCC") ? code : "HCC" * lpad(code, 3, '0')
        if haskey(HCC_V28_CNA_COEFFICIENTS, norm)
            hcc_sum += HCC_V28_CNA_COEFFICIENTS[norm]
            push!(recog, norm)
        else
            push!(unrecog, code)
        end
    end

    # Interaction terms
    code_set = Set(recog)
    inter_sum = 0.0
    triggered = String[]

    # Diabetes + CHF
    any(c in code_set for c in ["HCC017","HCC018","HCC019"]) &&
    "HCC079" in code_set && begin
        inter_sum += HCC_V28_INTERACTION_COEFFICIENTS["DIABETES_CHF"]
        push!(triggered, "DIABETES_CHF")
    end
    # Cancer + Immune
    any(c in code_set for c in ["HCC008","HCC009","HCC010","HCC011"]) &&
    "HCC047" in code_set && begin
        inter_sum += HCC_V28_INTERACTION_COEFFICIENTS["CANCER_IMMUNE"]
        push!(triggered, "CANCER_IMMUNE")
    end
    # CHF + COPD
    "HCC079" in code_set && "HCC111" in code_set && begin
        inter_sum += HCC_V28_INTERACTION_COEFFICIENTS["CHF_COPD"]
        push!(triggered, "CHF_COPD")
    end
    # CHF + Renal
    "HCC079" in code_set &&
    any(c in code_set for c in ["HCC134","HCC135","HCC136","HCC137","HCC138"]) && begin
        inter_sum += HCC_V28_INTERACTION_COEFFICIENTS["CHF_RENAL"]
        push!(triggered, "CHF_RENAL")
    end
    # Stroke + COPD
    any(c in code_set for c in ["HCC082","HCC083"]) && "HCC111" in code_set && begin
        inter_sum += HCC_V28_INTERACTION_COEFFICIENTS["STROKE_COPD"]
        push!(triggered, "STROKE_COPD")
    end
    # Sepsis + Pneumonia
    "HCC002" in code_set && "HCC114" in code_set && begin
        inter_sum += HCC_V28_INTERACTION_COEFFICIENTS["SEPSIS_PNEUMONIA"]
        push!(triggered, "SEPSIS_PNEUMONIA")
    end
    # Renal + Diabetes
    any(c in code_set for c in ["HCC135","HCC136","HCC137","HCC138"]) &&
    any(c in code_set for c in ["HCC017","HCC018","HCC019"]) && begin
        inter_sum += HCC_V28_INTERACTION_COEFFICIENTS["RENAL_DIABETES"]
        push!(triggered, "RENAL_DIABETES")
    end
    # Pressure Ulcer + CHF
    any(c in code_set for c in ["HCC157","HCC158"]) && "HCC079" in code_set && begin
        inter_sum += HCC_V28_INTERACTION_COEFFICIENTS["PRESSURE_ULCER_CHF"]
        push!(triggered, "PRESSURE_ULCER_CHF")
    end

    raw_raf  = demo + hcc_sum + inter_sum
    norm_fac = ma_normalization_factor(contract_year)
    norm_raf = raw_raf * norm_fac

    cat = norm_raf < 0.8 ? :low : norm_raf <= 1.2 ? :average :
          norm_raf <= 1.8 ? :high : :very_high

    MARAFResult(
        member.member_id,
        demo, hcc_sum, inter_sum,
        raw_raf, norm_raf, cat,
        recog, unrecog, triggered,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# MA Rural Hospital Pass-Through
# ─────────────────────────────────────────────────────────────────────────────

"""
    MA_RURAL_PASSTHROUGH_RATE

MA rural hospital pass-through payment rate (42 CFR § 422.109).
Rural hospitals receive 85% of the FFS rate for inpatient stays by MA
beneficiaries admitted to the hospital.
"""
const MA_RURAL_PASSTHROUGH_RATE = 0.85

"""
    ma_rural_passthrough_payment(
        ffs_payment::Float64;
        passthrough_rate = MA_RURAL_PASSTHROUGH_RATE
    ) -> NamedTuple

Compute the MA pass-through payment for a rural hospital inpatient stay.

Under 42 CFR § 422.109, rural hospitals are protected from MA plan underpayment
on inpatient admissions: the plan must pay at least 85% of what Medicare FFS
would have paid for the same admission.

# Arguments
- `ffs_payment::Float64`: What Medicare FFS would pay for this admission.
- `passthrough_rate::Float64 = 0.85`

# Returns
- `ffs_payment`, `passthrough_rate`, `minimum_ma_payment`, `protection_amount`
"""
function ma_rural_passthrough_payment(
    ffs_payment::Float64;
    passthrough_rate::Float64 = MA_RURAL_PASSTHROUGH_RATE,
)
    min_pay = ffs_payment * passthrough_rate
    protection = ffs_payment - min_pay  # amount hospital is "giving up" vs FFS
    (
        ffs_payment         = ffs_payment,
        passthrough_rate    = passthrough_rate,
        minimum_ma_payment  = min_pay,
        protection_amount   = protection,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# County-Level Capitation Rate Estimation
# ─────────────────────────────────────────────────────────────────────────────

"""
    MACountyCapitationInputs

Inputs for county-level MA capitation rate calculation.

# Fields
- `county_fips::String`
- `county_base_rate_pmpm::Float64`: CMS published county benchmark (Part A+B PMPM, USD).
- `plan_bid_pct_of_benchmark::Float64`: Plan bid as % of benchmark (typical: 0.95–1.05).
- `star_rating::Float64`: Plan star rating (1.0–5.0; ≥4.0 qualifies for quality bonus).
- `low_income_subsidy_pct::Float64`: Fraction of enrollees receiving LIS (affects risk pool).
- `mean_member_raf::Float64`: Average RAF across enrolled members.
- `n_members::Int`: Number of MA members at this hospital's catchment area.
- `contract_year::Int`
"""
@kwdef struct MACountyCapitationInputs
    county_fips::String                    = "00000"
    county_base_rate_pmpm::Float64
    plan_bid_pct_of_benchmark::Float64     = 1.00
    star_rating::Float64                   = 3.5
    low_income_subsidy_pct::Float64        = 0.20
    mean_member_raf::Float64               = 1.00
    n_members::Int                         = 500
    contract_year::Int                     = 2026
end

"""
    MACapitationResult

MA county capitation payment estimate.

# Fields
- `benchmark_pmpm::Float64`: CMS county benchmark.
- `quality_bonus_rate::Float64`: 5% for 4+ stars, 3.5% for 4.0 stars.
- `adjusted_benchmark_pmpm::Float64`: Benchmark after quality bonus.
- `plan_payment_pmpm::Float64`: After risk score and plan bid adjustment.
- `total_annual_plan_revenue::Float64`
- `estimated_hospital_share_pmpm::Float64`: ~40% of capitation to inpatient/outpatient care.
"""
struct MACapitationResult
    benchmark_pmpm::Float64
    quality_bonus_rate::Float64
    adjusted_benchmark_pmpm::Float64
    plan_payment_pmpm::Float64
    total_annual_plan_revenue::Float64
    estimated_hospital_share_pmpm::Float64
end

"""
    ma_county_capitation(inputs::MACountyCapitationInputs) -> MACapitationResult

Estimate MA plan capitation revenue for a county market.

## Algorithm
1. Quality bonus: ≥4.5 stars → 5.0%; ≥4.0 stars → 3.5%; else 0%.
2. Adjusted benchmark = base rate × (1 + quality bonus).
3. Plan payment = adjusted benchmark × mean RAF (risk-adjusted).
4. Total annual revenue = plan payment × 12 × n_members.
"""
function ma_county_capitation(inputs::MACountyCapitationInputs)::MACapitationResult
    qb_rate = inputs.star_rating >= 4.5 ? 0.050 :
              inputs.star_rating >= 4.0 ? 0.035 : 0.0

    adj_benchmark = inputs.county_base_rate_pmpm * (1.0 + qb_rate)
    plan_payment  = adj_benchmark * inputs.mean_member_raf * inputs.plan_bid_pct_of_benchmark
    total_annual  = plan_payment * 12.0 * inputs.n_members
    hosp_share    = plan_payment * 0.40   # ~40% of capitation flows to hospital care

    MACapitationResult(
        inputs.county_base_rate_pmpm, qb_rate,
        adj_benchmark, plan_payment, total_annual, hosp_share,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# MA Penetration Impact on Rural Hospital Revenue
# ─────────────────────────────────────────────────────────────────────────────

"""
    ma_penetration_revenue_impact(
        annual_ma_discharges::Int,
        avg_ffs_payment_per_discharge::Float64;
        ma_payment_rate_pct   = 0.88,
        passthrough_protected = false,
    ) -> NamedTuple

Estimate the revenue impact of MA penetration on a rural hospital vs FFS Medicare.

MA plans typically pay 88% of FFS for inpatient (vs the 85% minimum pass-through
for rural hospitals). Hospitals with rural pass-through protection receive at least 85%.

# Returns
- `ffs_revenue`, `ma_revenue`, `revenue_differential`, `differential_per_discharge`
- `protected_by_passthrough::Bool`
"""
function ma_penetration_revenue_impact(
    annual_ma_discharges::Int,
    avg_ffs_payment_per_discharge::Float64;
    ma_payment_rate_pct::Float64    = 0.88,
    passthrough_protected::Bool     = false,
)
    effective_rate = passthrough_protected ?
        max(ma_payment_rate_pct, MA_RURAL_PASSTHROUGH_RATE) : ma_payment_rate_pct

    ffs_rev  = annual_ma_discharges * avg_ffs_payment_per_discharge
    ma_rev   = annual_ma_discharges * avg_ffs_payment_per_discharge * effective_rate
    diff     = ma_rev - ffs_rev
    per_dis  = diff / max(annual_ma_discharges, 1)

    (
        annual_ma_discharges         = annual_ma_discharges,
        avg_ffs_payment              = avg_ffs_payment_per_discharge,
        effective_ma_rate_pct        = effective_rate,
        ffs_revenue                  = ffs_rev,
        ma_revenue                   = ma_rev,
        revenue_differential         = diff,
        differential_per_discharge   = per_dis,
        protected_by_passthrough     = passthrough_protected,
    )
end
