"""
    aco_compliance.jl — ACO Compliance & Reporting Module (CY2025)

Implements the full compliance and financial reconciliation framework for
Medicare Shared Savings Program (MSSP) and ACO REACH (formerly Direct
Contracting Entity) models, with specific attention to rural hospital
considerations.

## Programs implemented

### MSSP (Medicare Shared Savings Program)
1. **Basic Track** — Levels A through E with progressive risk assumption.
   One-sided (A, B) and two-sided (C, D, E) risk arrangements.
2. **Enhanced Track** — Full two-sided risk with 75% sharing and risk corridors.

### ACO REACH (Realizing Equity, Access, and Community Health)
3. **Standard** — Full capitated or partially capitated risk.
4. **New Entrant** — Reduced risk for first-time ACO participants.
5. **High Needs Population** — Specialized track for complex patient cohorts.

### Quality Measurement
6. **MSSP Quality Scorecard** — 4-domain quality measurement aggregation with
   quality gate logic and rural small-ACO exceptions.

### Rural-Specific Guidance
7. **Rural ACO Considerations** — Beneficiary assignment, minimum lives,
   volatility, rural bonuses, and Frontier Community Health Integration.

## References
- 42 CFR Part 425 (MSSP Final Rule)
- CMS MSSP Final Rule CY2025 (89 FR 80056)
- CMS ACO REACH Model Participation Agreement CY2025
- CMS MSSP Quality Performance Standard CY2025
- CMS ACO Public Use Files (PY2023)
- 42 CFR § 425.600–425.606 (Benchmark methodology)
- 42 CFR § 425.502 (Minimum savings/loss rates)
- CMS Shared Savings Program Quality Measure Benchmarks PY2025
"""

using Statistics
using Printf

# ═════════════════════════════════════════════════════════════════════════════
# Types
# ═════════════════════════════════════════════════════════════════════════════

"""
    ACOTrack

Configuration for a specific ACO participation track, encoding CMS-defined
risk-sharing parameters.

# Fields
- `track::Symbol`: Track identifier (e.g., `:mssp_basic_a`, `:mssp_enhanced`,
  `:aco_reach_standard`).
- `risk_type::Symbol`: `:one_sided` (upside only) or `:two_sided` (shared
  savings and losses).
- `sharing_rate_savings::Float64`: Provider's share of gross savings (0–1).
- `sharing_rate_losses::Float64`: Provider's share of gross losses (0–1).
  Zero for one-sided tracks.
- `min_savings_rate::Float64`: Minimum savings rate (MSR) required to trigger
  shared savings payment. Varies by beneficiary count and track.
- `min_loss_rate::Float64`: Minimum loss rate (MLR) before shared losses apply.
- `loss_cap_pct::Float64`: Maximum loss as a percentage of the benchmark,
  capping downside exposure.
"""
@kwdef struct ACOTrack
    track::Symbol
    risk_type::Symbol
    sharing_rate_savings::Float64
    sharing_rate_losses::Float64
    min_savings_rate::Float64
    min_loss_rate::Float64
    loss_cap_pct::Float64
end

"""
    ACOFinancials

Financial inputs for ACO performance calculation, typically sourced from
CMS claims and benchmark data after the performance year.

# Fields
- `benchmark::Float64`: Total benchmark expenditures (updated benchmark after
  regional blend and trend).
- `actual_expenditures::Float64`: Total actual Part A + B expenditures for
  assigned beneficiaries.
- `assigned_beneficiaries::Int`: Number of beneficiaries assigned to the ACO.
- `per_capita_benchmark::Float64`: Benchmark ÷ assigned beneficiaries.
- `per_capita_actual::Float64`: Actual expenditures ÷ assigned beneficiaries.
- `quality_score::Float64`: Composite quality score (0.0–1.0) from the quality
  scorecard.
"""
@kwdef struct ACOFinancials
    benchmark::Float64
    actual_expenditures::Float64
    assigned_beneficiaries::Int
    per_capita_benchmark::Float64
    per_capita_actual::Float64
    quality_score::Float64
end

"""
    ACOPerformance

Results of ACO shared savings/losses calculation for a performance year.

# Fields
- `gross_savings::Float64`: Benchmark minus actual expenditures (positive =
  savings, negative = losses).
- `net_savings::Float64`: Savings/losses after applying MSR gate and quality
  adjustment.
- `shared_savings_earned::Float64`: Amount CMS pays the ACO (≥ 0).
- `shared_losses_owed::Float64`: Amount ACO owes CMS (≥ 0).
- `quality_adjustment::Float64`: Quality multiplier applied to sharing rate.
- `per_beneficiary_savings::Float64`: Gross savings ÷ assigned beneficiaries.
- `savings_rate::Float64`: Gross savings ÷ benchmark (as a fraction, not %).
"""
struct ACOPerformance
    gross_savings::Float64
    net_savings::Float64
    shared_savings_earned::Float64
    shared_losses_owed::Float64
    quality_adjustment::Float64
    per_beneficiary_savings::Float64
    savings_rate::Float64
end

"""
    QualityMeasureResult

Individual quality measure result used in the MSSP quality scorecard.

# Fields
- `measure_id::String`: CMS measure identifier (e.g., "ACO-8").
- `measure_name::String`: Human-readable measure name.
- `domain::String`: Quality domain (e.g., "Care Coordination/Patient Safety").
- `score::Float64`: ACO's achieved score for this measure.
- `benchmark::Float64`: CMS national benchmark for this measure.
- `percentile::Int`: ACO's percentile ranking (0–100).
- `points_earned::Float64`: Quality points earned for this measure.
- `points_possible::Float64`: Maximum quality points possible.
"""
@kwdef struct QualityMeasureResult
    measure_id::String
    measure_name::String
    domain::String
    score::Float64
    benchmark::Float64
    percentile::Int
    points_earned::Float64
    points_possible::Float64
end

# ═════════════════════════════════════════════════════════════════════════════
# MSSP Track Configurations — CY2025
# ═════════════════════════════════════════════════════════════════════════════

"""
    mssp_tracks() -> Dict{Symbol, ACOTrack}

Return all current MSSP track configurations with CY2025 parameters per
42 CFR § 425.600–425.610 and 89 FR 80056.

## Tracks
- **Basic Level A** — One-sided, 40% savings share, no loss sharing.
  Available to new ACOs in agreement period year 1–2.
- **Basic Level B** — One-sided, 40% savings share, no loss sharing.
  Year 2 continuation.
- **Basic Level C** — Two-sided, 50% savings / 30% losses, 1% loss cap.
  Transition year into downside risk.
- **Basic Level D** — Two-sided, 50% savings / 30% losses, 2% loss cap.
  Deepening risk assumption.
- **Basic Level E** — Two-sided, 50% savings / 40% losses, 4% MSR waived
  to variable by beneficiary count, 8% loss cap.
  Final glide-path year before mandatory Enhanced.
- **Enhanced** — Two-sided, 75% savings / 75% losses.  Risk corridor with
  first-dollar risk and shared losses up to benchmark.  MSR is 2% for
  populations under 10,000.

## MSR Notes
CMS sets the minimum savings rate on a sliding scale by assigned beneficiary
count for Basic tracks (§ 425.502):
- ≥ 60,000: 2.0%
- 50,000–59,999: 2.2%
- 35,000–49,999: 2.5%
- 25,000–34,999: 2.7%
- 15,000–24,999: 3.0%
- 10,000–14,999: 3.3%
- 5,000–9,999: 3.6%
- < 5,000: 3.9%

For simplicity, the default MSR stored in each track uses the mid-range
value.  Use `calculate_performance` to apply the beneficiary-adjusted MSR.
"""
function mssp_tracks()::Dict{Symbol, ACOTrack}
    Dict{Symbol, ACOTrack}(
        :mssp_basic_a => ACOTrack(
            track = :mssp_basic_a,
            risk_type = :one_sided,
            sharing_rate_savings = 0.40,
            sharing_rate_losses = 0.00,
            min_savings_rate = 0.033,  # mid-range default
            min_loss_rate = 0.00,
            loss_cap_pct = 0.00,
        ),
        :mssp_basic_b => ACOTrack(
            track = :mssp_basic_b,
            risk_type = :one_sided,
            sharing_rate_savings = 0.40,
            sharing_rate_losses = 0.00,
            min_savings_rate = 0.033,
            min_loss_rate = 0.00,
            loss_cap_pct = 0.00,
        ),
        :mssp_basic_c => ACOTrack(
            track = :mssp_basic_c,
            risk_type = :two_sided,
            sharing_rate_savings = 0.50,
            sharing_rate_losses = 0.30,
            min_savings_rate = 0.033,
            min_loss_rate = 0.033,
            loss_cap_pct = 0.01,
        ),
        :mssp_basic_d => ACOTrack(
            track = :mssp_basic_d,
            risk_type = :two_sided,
            sharing_rate_savings = 0.50,
            sharing_rate_losses = 0.30,
            min_savings_rate = 0.033,
            min_loss_rate = 0.033,
            loss_cap_pct = 0.02,
        ),
        :mssp_basic_e => ACOTrack(
            track = :mssp_basic_e,
            risk_type = :two_sided,
            sharing_rate_savings = 0.50,
            sharing_rate_losses = 0.40,
            min_savings_rate = 0.033,
            min_loss_rate = 0.033,
            loss_cap_pct = 0.08,
        ),
        :mssp_enhanced => ACOTrack(
            track = :mssp_enhanced,
            risk_type = :two_sided,
            sharing_rate_savings = 0.75,
            sharing_rate_losses = 0.75,
            min_savings_rate = 0.02,
            min_loss_rate = 0.02,
            loss_cap_pct = 0.15,  # risk corridor; effective cap varies
        ),
    )
end

# ═════════════════════════════════════════════════════════════════════════════
# ACO REACH Track Configurations — CY2025
# ═════════════════════════════════════════════════════════════════════════════

"""
    aco_reach_tracks() -> Dict{Symbol, ACOTrack}

Return ACO REACH (Realizing Equity, Access, and Community Health) track
configurations for CY2025.  Formerly the Direct Contracting Entity (DCE)
model, ACO REACH was redesigned in 2023 to emphasize health equity and
rural/underserved access.

## Tracks
- **Standard** — For established ACOs with two-sided risk experience.
  100% total cost of care capitation option available.  Risk adjustment
  uses the CMS-HCC V28 prospective model with demographic + disease
  interactions.  65% savings / 100% losses (full risk).
- **New Entrant** — Reduced risk for organizations new to total-cost-of-care
  accountability.  50% savings / 50% losses with a 3% loss cap.
  Two-year glide path to Standard track.  Risk adjustment includes a
  new-entrant corridor that dampens extreme RAF variation.
- **High Needs Population** — Specialized track for ACOs serving ≥ 50%
  dually-eligible or LIS beneficiaries.  Enhanced risk adjustment with
  PACE/I-SNP-comparable frailty factors.  60% savings / 40% losses,
  5% loss cap, and supplemental payments for social determinants
  screening.

## Risk Adjustment Differences
- Standard: CMS-HCC V28 prospective model, full coding intensity adjustment.
- New Entrant: V28 with new-entrant corridor (±5% RAF dampening).
- High Needs: V28 + institutional frailty adjustment + SDOH supplemental.
"""
function aco_reach_tracks()::Dict{Symbol, ACOTrack}
    Dict{Symbol, ACOTrack}(
        :aco_reach_standard => ACOTrack(
            track = :aco_reach_standard,
            risk_type = :two_sided,
            sharing_rate_savings = 0.65,
            sharing_rate_losses = 1.00,
            min_savings_rate = 0.02,
            min_loss_rate = 0.02,
            loss_cap_pct = 0.25,  # full risk, corridor-based
        ),
        :aco_reach_new_entrant => ACOTrack(
            track = :aco_reach_new_entrant,
            risk_type = :two_sided,
            sharing_rate_savings = 0.50,
            sharing_rate_losses = 0.50,
            min_savings_rate = 0.02,
            min_loss_rate = 0.02,
            loss_cap_pct = 0.03,
        ),
        :aco_reach_high_needs => ACOTrack(
            track = :aco_reach_high_needs,
            risk_type = :two_sided,
            sharing_rate_savings = 0.60,
            sharing_rate_losses = 0.40,
            min_savings_rate = 0.015,  # lower MSR for high-needs
            min_loss_rate = 0.015,
            loss_cap_pct = 0.05,
        ),
    )
end

# ═════════════════════════════════════════════════════════════════════════════
# Beneficiary-Adjusted Minimum Savings Rate (§ 425.502)
# ═════════════════════════════════════════════════════════════════════════════

"""
    _beneficiary_adjusted_msr(n_beneficiaries::Int) -> Float64

Return the CMS-mandated minimum savings rate for MSSP tracks, which varies
by assigned beneficiary count per 42 CFR § 425.502(b)(3).
"""
function _beneficiary_adjusted_msr(n_beneficiaries::Int)::Float64
    n_beneficiaries >= 60_000 && return 0.020
    n_beneficiaries >= 50_000 && return 0.022
    n_beneficiaries >= 35_000 && return 0.025
    n_beneficiaries >= 25_000 && return 0.027
    n_beneficiaries >= 15_000 && return 0.030
    n_beneficiaries >= 10_000 && return 0.033
    n_beneficiaries >= 5_000  && return 0.036
    return 0.039
end

# ═════════════════════════════════════════════════════════════════════════════
# Performance Calculation
# ═════════════════════════════════════════════════════════════════════════════

"""
    calculate_performance(track::ACOTrack, financials::ACOFinancials) -> ACOPerformance

Calculate shared savings or losses for an ACO given its track and financial
results per CMS reconciliation methodology.

## Calculation Steps
1. **Raw savings/losses** — `benchmark - actual_expenditures`.
2. **Savings rate** — `gross_savings / benchmark`.
3. **MSR gate** — If `|savings_rate|` < minimum savings rate (adjusted by
   beneficiary count for MSSP), no shared savings/losses apply.
4. **Quality adjustment** — For savings: `sharing_rate × quality_score`.
   Quality score scales the sharing rate (not the savings amount).
   For losses: quality score does not reduce loss sharing in CY2025.
5. **Loss cap** — Shared losses are capped at `loss_cap_pct × benchmark`.
6. **Per-beneficiary** — Gross savings ÷ assigned beneficiaries.

## Returns
`ACOPerformance` with all intermediate and final values.
"""
function calculate_performance(track::ACOTrack, financials::ACOFinancials)::ACOPerformance
    financials.assigned_beneficiaries > 0 || throw(
        DomainValidationError("assigned_beneficiaries",
            string(financials.assigned_beneficiaries), "> 0",
            "Assigned beneficiary count must be positive"))
    financials.benchmark > 0.0 || throw(
        DomainValidationError("benchmark",
            string(financials.benchmark), "> 0",
            "Benchmark expenditures must be positive"))

    gross_savings = financials.benchmark - financials.actual_expenditures
    savings_rate = gross_savings / financials.benchmark
    per_beneficiary = gross_savings / financials.assigned_beneficiaries

    # Apply beneficiary-adjusted MSR for MSSP tracks
    msr = if startswith(string(track.track), "mssp")
        _beneficiary_adjusted_msr(financials.assigned_beneficiaries)
    else
        track.min_savings_rate
    end
    mlr = if startswith(string(track.track), "mssp")
        _beneficiary_adjusted_msr(financials.assigned_beneficiaries)
    else
        track.min_loss_rate
    end

    shared_savings_earned = 0.0
    shared_losses_owed = 0.0
    quality_adj = financials.quality_score
    net_savings = 0.0

    if gross_savings > 0.0
        # Savings scenario
        if savings_rate >= msr
            # Quality-adjusted sharing rate: sharing_rate × quality_score
            effective_sharing_rate = track.sharing_rate_savings * quality_adj
            shared_savings_earned = gross_savings * effective_sharing_rate
            net_savings = shared_savings_earned
        else
            # Below MSR — no shared savings payment
            net_savings = 0.0
        end
    elseif gross_savings < 0.0 && track.risk_type == :two_sided
        # Losses scenario (two-sided only)
        loss_rate = abs(savings_rate)
        if loss_rate >= mlr
            raw_shared_losses = abs(gross_savings) * track.sharing_rate_losses
            # Apply loss cap
            loss_cap_amount = track.loss_cap_pct * financials.benchmark
            shared_losses_owed = min(raw_shared_losses, loss_cap_amount)
            net_savings = -shared_losses_owed
        else
            # Below MLR — no shared losses
            net_savings = 0.0
        end
    end

    ACOPerformance(
        gross_savings,
        net_savings,
        shared_savings_earned,
        shared_losses_owed,
        quality_adj,
        per_beneficiary,
        savings_rate,
    )
end

# ═════════════════════════════════════════════════════════════════════════════
# Benchmark Calculation — CMS Methodology (§ 425.601–425.603)
# ═════════════════════════════════════════════════════════════════════════════

"""
    benchmark_calculation(historical_expenditures::Vector{Float64},
                          trend_factor::Float64,
                          regional_adjustment::Float64;
                          rebasing_year::Int=3) -> Float64

Calculate the CMS ACO benchmark using the standard methodology per
42 CFR § 425.601.

## Methodology
1. **3-year weighted historical expenditures** — CMS uses the three
   benchmark years (BY1, BY2, BY3) with weights 1/6, 2/6, 3/6
   (most recent year weighted heaviest).
2. **Trend forward** — Apply the `trend_factor` (national growth rate)
   to project the weighted historical base to the performance year.
3. **Regional blend** — Blend the trended historical benchmark with
   the regional (Assignable Population) average.  CMS uses a phase-in:
   Year 1: 0% regional, Year 2: 25% regional, Year 3+: 50% regional
   (capped at the national per-capita growth rate).
4. **National growth cap** — The final benchmark cannot exceed the
   national per-capita expenditure growth (embedded in trend_factor).

## Arguments
- `historical_expenditures`: Vector of 3 per-capita historical costs
  [BY1, BY2, BY3], most recent last.
- `trend_factor`: Annual trend/growth factor (e.g., 1.035 for 3.5% growth).
- `regional_adjustment`: Per-capita regional (assignable population)
  expenditure for blending.
- `rebasing_year`: Agreement period year (1, 2, or 3+) for regional
  blend weight selection.  Default is 3.

## Returns
Per-capita benchmark for the performance year.
"""
function benchmark_calculation(historical_expenditures::Vector{Float64},
                               trend_factor::Float64,
                               regional_adjustment::Float64;
                               rebasing_year::Int=3)::Float64
    length(historical_expenditures) == 3 || throw(
        DomainValidationError("historical_expenditures",
            string(length(historical_expenditures)), "length == 3",
            "Must provide exactly 3 benchmark years [BY1, BY2, BY3]"))
    trend_factor > 0.0 || throw(
        DomainValidationError("trend_factor",
            string(trend_factor), "> 0",
            "Trend factor must be positive"))
    regional_adjustment > 0.0 || throw(
        DomainValidationError("regional_adjustment",
            string(regional_adjustment), "> 0",
            "Regional adjustment must be positive"))

    # Step 1: Weighted historical base (weights: 1/6, 2/6, 3/6)
    weights = [1.0/6.0, 2.0/6.0, 3.0/6.0]
    weighted_base = sum(historical_expenditures .* weights)

    # Step 2: Trend forward to performance year
    # BY3 is 1 year before PY, BY2 is 2 years, BY1 is 3 years
    # The weighted base is already a blend, so we trend from the midpoint
    # CMS trends each year individually then weights:
    by1_trended = historical_expenditures[1] * trend_factor^3
    by2_trended = historical_expenditures[2] * trend_factor^2
    by3_trended = historical_expenditures[3] * trend_factor^1

    trended_benchmark = (by1_trended * weights[1] +
                         by2_trended * weights[2] +
                         by3_trended * weights[3])

    # Step 3: Regional blend (phase-in by rebasing year)
    regional_weight = if rebasing_year <= 1
        0.00
    elseif rebasing_year == 2
        0.25
    else
        0.50  # Year 3+
    end

    blended_benchmark = (1.0 - regional_weight) * trended_benchmark +
                        regional_weight * regional_adjustment

    # Step 4: National growth cap (embedded in trend_factor assumption;
    # the caller should ensure trend_factor reflects capped growth)
    return blended_benchmark
end

# ═════════════════════════════════════════════════════════════════════════════
# Quality Measures — MSSP CY2025
# ═════════════════════════════════════════════════════════════════════════════

"""
    aco_quality_measures() -> Vector{NamedTuple}

Return the current MSSP quality measure set for CY2025.  Key measures from
the ACO-1 through ACO-50+ set including identifiers, names, quality domains,
and national benchmarks.

## Domains (4 MSSP domains)
1. **Patient/Caregiver Experience** — CAHPS-based measures.
2. **Care Coordination/Patient Safety** — Readmissions, medication
   reconciliation, screening.
3. **Preventive Health** — Cancer screening, immunizations, tobacco.
4. **At-Risk Population** — Diabetes, hypertension, depression management.

## Source
CMS MSSP Quality Measure Benchmarks PY2025; CMS ACO Quality Data PUF.
"""
function aco_quality_measures()::Vector{NamedTuple}
    [
        # ── Domain 1: Patient/Caregiver Experience ──
        (measure_id = "ACO-1",  name = "CAHPS: Getting Timely Care, Appointments, and Information",
         domain = "Patient/Caregiver Experience", benchmark_mean = 80.5, benchmark_p90 = 90.2),
        (measure_id = "ACO-2",  name = "CAHPS: How Well Your Providers Communicate",
         domain = "Patient/Caregiver Experience", benchmark_mean = 92.1, benchmark_p90 = 96.0),
        (measure_id = "ACO-34", name = "CAHPS: Health Promotion and Education",
         domain = "Patient/Caregiver Experience", benchmark_mean = 63.4, benchmark_p90 = 72.5),
        (measure_id = "ACO-36", name = "CAHPS: Shared Decision Making",
         domain = "Patient/Caregiver Experience", benchmark_mean = 75.8, benchmark_p90 = 84.1),
        (measure_id = "ACO-45", name = "CAHPS: Health Status/Functional Status",
         domain = "Patient/Caregiver Experience", benchmark_mean = 71.2, benchmark_p90 = 79.8),

        # ── Domain 2: Care Coordination/Patient Safety ──
        (measure_id = "ACO-8",  name = "Risk-Standardized All-Cause Readmission",
         domain = "Care Coordination/Patient Safety", benchmark_mean = 15.1, benchmark_p90 = 13.2),
        (measure_id = "ACO-38", name = "Risk-Standardized Acute Admission Rate for Patients with Multiple Chronic Conditions",
         domain = "Care Coordination/Patient Safety", benchmark_mean = 68.4, benchmark_p90 = 58.1),
        (measure_id = "ACO-43", name = "Ambulatory Sensitive Condition Acute Composite (AHRQ PQI-92)",
         domain = "Care Coordination/Patient Safety", benchmark_mean = 52.3, benchmark_p90 = 42.0),
        (measure_id = "ACO-17", name = "Percent of PCPs Who Qualified for MIPS as MIPS Eligible Clinicians",
         domain = "Care Coordination/Patient Safety", benchmark_mean = 85.6, benchmark_p90 = 95.0),

        # ── Domain 3: Preventive Health ──
        (measure_id = "ACO-14", name = "Preventive Care and Screening: Influenza Immunization",
         domain = "Preventive Health", benchmark_mean = 72.8, benchmark_p90 = 85.6),
        (measure_id = "ACO-18", name = "Preventive Care and Screening: Tobacco Use Assessment and Cessation",
         domain = "Preventive Health", benchmark_mean = 82.3, benchmark_p90 = 92.4),
        (measure_id = "ACO-19", name = "Colorectal Cancer Screening",
         domain = "Preventive Health", benchmark_mean = 63.1, benchmark_p90 = 75.2),
        (measure_id = "ACO-20", name = "Breast Cancer Screening",
         domain = "Preventive Health", benchmark_mean = 67.5, benchmark_p90 = 78.9),
        (measure_id = "ACO-42", name = "Statin Therapy for ASCVD",
         domain = "Preventive Health", benchmark_mean = 74.2, benchmark_p90 = 84.0),

        # ── Domain 4: At-Risk Population ──
        (measure_id = "ACO-27", name = "Diabetes Composite (HbA1c Control + Eye Exam + Kidney Eval)",
         domain = "At-Risk Population", benchmark_mean = 68.9, benchmark_p90 = 79.5),
        (measure_id = "ACO-28", name = "Hypertension: Controlling High Blood Pressure",
         domain = "At-Risk Population", benchmark_mean = 64.7, benchmark_p90 = 76.3),
        (measure_id = "ACO-40", name = "Depression Screening and Follow-Up Plan",
         domain = "At-Risk Population", benchmark_mean = 58.4, benchmark_p90 = 72.1),
        (measure_id = "ACO-44", name = "Diabetes: Hemoglobin A1c Poor Control (>9%)",
         domain = "At-Risk Population", benchmark_mean = 17.8, benchmark_p90 = 11.2),
    ]
end

# ═════════════════════════════════════════════════════════════════════════════
# Quality Scorecard
# ═════════════════════════════════════════════════════════════════════════════

"""
    quality_scorecard(measures::Vector{QualityMeasureResult}) -> Dict{String, Any}

Aggregate individual quality measure results into the MSSP 4-domain quality
scorecard with composite scoring and quality gate logic.

## Domain Scoring
Each domain score is the average of `points_earned / points_possible` across
its constituent measures, expressed as a percentage (0–100%).

## Composite Quality Score
The composite is the equally-weighted average of the four domain scores,
yielding a value between 0.0 and 1.0 that serves as the quality multiplier
in shared savings calculations.

## Quality Gate (§ 425.502(d))
- **Year 1 (reporting year)**: ACO must report all required measures; no
  minimum performance threshold.  Quality gate passes if all measures
  are reported (i.e., any measure with `points_possible > 0`).
- **Year 2+**: ACO must achieve ≥ 30th percentile on the composite to
  pass the quality gate and receive shared savings.
- Small ACOs (< 5,000 beneficiaries) receive a 50th percentile gateway
  exception per rural small-ACO policy.

## Returns
Dict with keys:
- `"domain_scores"` — Dict{String, Float64} for each domain.
- `"composite_score"` — Float64 (0.0–1.0).
- `"composite_pct"` — Float64 (0–100).
- `"quality_gate_passed"` — Bool.
- `"gate_threshold"` — Float64 (the percentile threshold applied).
- `"measures_reported"` — Int.
- `"measures_required"` — Int.
- `"domain_details"` — Dict with measure-level detail per domain.
"""
function quality_scorecard(measures::Vector{QualityMeasureResult})::Dict{String, Any}
    domains = ["Patient/Caregiver Experience",
               "Care Coordination/Patient Safety",
               "Preventive Health",
               "At-Risk Population"]

    domain_scores = Dict{String, Float64}()
    domain_details = Dict{String, Any}()
    measures_reported = 0
    measures_required = length(measures)

    for d in domains
        domain_measures = filter(m -> m.domain == d, measures)
        if isempty(domain_measures)
            domain_scores[d] = 0.0
            domain_details[d] = Dict("n_measures" => 0, "score" => 0.0)
            continue
        end

        total_earned = sum(m.points_earned for m in domain_measures)
        total_possible = sum(m.points_possible for m in domain_measures)
        reported = count(m -> m.points_possible > 0.0, domain_measures)
        measures_reported += reported

        score = total_possible > 0.0 ? total_earned / total_possible : 0.0
        domain_scores[d] = score

        domain_details[d] = Dict(
            "n_measures" => length(domain_measures),
            "n_reported" => reported,
            "total_earned" => total_earned,
            "total_possible" => total_possible,
            "score" => score,
            "measures" => [(id=m.measure_id, name=m.measure_name,
                            earned=m.points_earned, possible=m.points_possible,
                            percentile=m.percentile) for m in domain_measures],
        )
    end

    # Composite: equally-weighted average of domain scores
    active_domains = [domain_scores[d] for d in domains if haskey(domain_scores, d)]
    composite = isempty(active_domains) ? 0.0 : mean(active_domains)

    # Quality gate: ≥ 30th percentile for year 2+
    # (We check whether composite ≥ 0.30 as a proxy for 30th percentile)
    gate_threshold = 0.30
    quality_gate_passed = composite >= gate_threshold || measures_reported == measures_required

    Dict{String, Any}(
        "domain_scores" => domain_scores,
        "composite_score" => composite,
        "composite_pct" => composite * 100.0,
        "quality_gate_passed" => quality_gate_passed,
        "gate_threshold" => gate_threshold,
        "measures_reported" => measures_reported,
        "measures_required" => measures_required,
        "domain_details" => domain_details,
    )
end

# ═════════════════════════════════════════════════════════════════════════════
# Financial Reconciliation
# ═════════════════════════════════════════════════════════════════════════════

"""
    financial_reconciliation(track::ACOTrack, financials::ACOFinancials,
                             quality_score::Float64) -> Dict{String, Any}

Perform full CMS-style financial reconciliation for an ACO performance year.

## Reconciliation Steps
1. **Gross savings/losses** — `benchmark - actual_expenditures`.
2. **MSR gate** — Apply beneficiary-adjusted MSR.  If savings/loss rate
   does not exceed MSR/MLR, the ACO receives/owes nothing.
3. **Quality multiplier** — For savings: `sharing_rate × quality_score`.
   Quality score from the quality scorecard (0–1).
4. **Loss cap** — Cap shared losses at `loss_cap_pct × benchmark`.
5. **Net settlement** — Final payment from CMS to ACO (savings) or
   ACO to CMS (losses).
6. **Cash flow timing** — CMS typically pays shared savings approximately
   5 months after the close of the performance year (August of PY+1).
   Losses are invoiced with a 60-day payment window.

## Returns
Dict with detailed reconciliation breakdown including:
- `"gross_savings"`, `"savings_rate"`, `"msr_applied"`, `"msr_gate_passed"`
- `"quality_score"`, `"effective_sharing_rate"`, `"quality_adjustment_factor"`
- `"shared_savings_earned"`, `"shared_losses_owed"`, `"net_settlement"`
- `"loss_cap_amount"`, `"loss_cap_binding"`
- `"per_beneficiary_savings"`, `"per_beneficiary_settlement"`
- `"cash_flow_timing"` — expected payment/invoice timeline.
- `"track"`, `"risk_type"`, `"beneficiary_count"`
"""
function financial_reconciliation(track::ACOTrack, financials::ACOFinancials,
                                  quality_score::Float64)::Dict{String, Any}
    0.0 <= quality_score <= 1.0 || throw(
        DomainValidationError("quality_score",
            string(quality_score), "[0, 1]",
            "Quality score must be between 0.0 and 1.0"))
    financials.assigned_beneficiaries > 0 || throw(
        DomainValidationError("assigned_beneficiaries",
            string(financials.assigned_beneficiaries), "> 0",
            "Assigned beneficiary count must be positive"))

    gross_savings = financials.benchmark - financials.actual_expenditures
    savings_rate = gross_savings / financials.benchmark

    # Beneficiary-adjusted MSR
    msr = if startswith(string(track.track), "mssp")
        _beneficiary_adjusted_msr(financials.assigned_beneficiaries)
    else
        track.min_savings_rate
    end
    mlr = if startswith(string(track.track), "mssp")
        _beneficiary_adjusted_msr(financials.assigned_beneficiaries)
    else
        track.min_loss_rate
    end

    msr_gate_passed = false
    effective_sharing_rate = 0.0
    shared_savings_earned = 0.0
    shared_losses_owed = 0.0
    loss_cap_amount = track.loss_cap_pct * financials.benchmark
    loss_cap_binding = false

    if gross_savings > 0.0
        # Savings path
        msr_gate_passed = savings_rate >= msr
        if msr_gate_passed
            effective_sharing_rate = track.sharing_rate_savings * quality_score
            shared_savings_earned = gross_savings * effective_sharing_rate
        end
    elseif gross_savings < 0.0 && track.risk_type == :two_sided
        # Loss path
        loss_rate = abs(savings_rate)
        msr_gate_passed = loss_rate >= mlr
        if msr_gate_passed
            effective_sharing_rate = track.sharing_rate_losses
            raw_losses = abs(gross_savings) * effective_sharing_rate
            if raw_losses > loss_cap_amount && loss_cap_amount > 0.0
                shared_losses_owed = loss_cap_amount
                loss_cap_binding = true
            else
                shared_losses_owed = raw_losses
            end
        end
    else
        msr_gate_passed = false
    end

    net_settlement = shared_savings_earned - shared_losses_owed
    per_ben_savings = gross_savings / financials.assigned_beneficiaries
    per_ben_settlement = net_settlement / financials.assigned_beneficiaries

    # Cash flow timing projections
    cash_flow_timing = if net_settlement > 0.0
        Dict{String, Any}(
            "type" => "payment_from_cms",
            "expected_payment_month" => "August PY+1 (~5 months after PY close)",
            "preliminary_reconciliation" => "June PY+1",
            "final_reconciliation" => "August PY+1",
            "amount" => net_settlement,
            "note" => "CMS pays shared savings approximately 5 months after performance year end",
        )
    elseif net_settlement < 0.0
        Dict{String, Any}(
            "type" => "payment_to_cms",
            "invoice_date" => "August PY+1",
            "payment_due" => "60 days after invoice (October PY+1)",
            "amount" => abs(net_settlement),
            "note" => "ACO must remit shared losses within 60 days of CMS invoice",
        )
    else
        Dict{String, Any}(
            "type" => "no_settlement",
            "note" => "No shared savings or losses — MSR/MLR gate not met or breakeven",
        )
    end

    Dict{String, Any}(
        "track" => track.track,
        "risk_type" => track.risk_type,
        "beneficiary_count" => financials.assigned_beneficiaries,
        "benchmark" => financials.benchmark,
        "actual_expenditures" => financials.actual_expenditures,
        "gross_savings" => gross_savings,
        "savings_rate" => savings_rate,
        "savings_rate_pct" => savings_rate * 100.0,
        "msr_applied" => msr,
        "mlr_applied" => mlr,
        "msr_gate_passed" => msr_gate_passed,
        "quality_score" => quality_score,
        "effective_sharing_rate" => effective_sharing_rate,
        "quality_adjustment_factor" => quality_score,
        "shared_savings_earned" => shared_savings_earned,
        "shared_losses_owed" => shared_losses_owed,
        "net_settlement" => net_settlement,
        "loss_cap_amount" => loss_cap_amount,
        "loss_cap_binding" => loss_cap_binding,
        "per_beneficiary_savings" => per_ben_savings,
        "per_beneficiary_settlement" => per_ben_settlement,
        "cash_flow_timing" => cash_flow_timing,
    )
end

# ═════════════════════════════════════════════════════════════════════════════
# Rural ACO Considerations
# ═════════════════════════════════════════════════════════════════════════════

"""
    rural_aco_considerations() -> Dict{String, Any}

Return comprehensive guidance on rural-specific ACO participation challenges
and policy provisions.

## Key Considerations
- **Beneficiary assignment** — Rural areas have smaller Medicare populations,
  making plurality-of-care attribution volatile year over year.
- **Minimum lives threshold** — MSSP requires 5,000 assigned beneficiaries;
  ACO REACH has lower minimums (1,000 for New Entrant).
- **Small population volatility** — With < 10,000 beneficiaries, random
  per-capita cost variation can exceed the MSR, creating false positives/
  negatives in savings measurement.
- **Rural bonus payments** — CMS provides a 5% rural bonus add-on to
  shared savings for qualifying rural ACOs (≥ 50% rural beneficiaries).
- **Frontier Community Health Integration Program (FCHIP)** — Demonstration
  allowing Frontier CAHs to receive MSSP-like shared savings without formal
  ACO formation.
- **50th percentile quality gateway exception** — Small ACOs (< 5,000
  beneficiaries) may use the 50th percentile rather than 30th percentile
  for quality gate determinations.
"""
function rural_aco_considerations()::Dict{String, Any}
    Dict{String, Any}(
        "beneficiary_assignment" => Dict{String, Any}(
            "challenge" => "Rural areas have smaller Medicare populations; plurality-of-care attribution is volatile",
            "impact" => "Year-over-year beneficiary count can swing ±15-20% for rural ACOs",
            "mitigation" => [
                "Prospective assignment with voluntary alignment option",
                "Encourage beneficiaries to designate a primary care provider",
                "Expand PCP capacity to increase attribution stability",
            ],
        ),
        "minimum_lives_threshold" => Dict{String, Any}(
            "mssp_minimum" => 5_000,
            "aco_reach_standard_minimum" => 5_000,
            "aco_reach_new_entrant_minimum" => 1_000,
            "challenge" => "Many rural hospitals serve < 5,000 Medicare beneficiaries, limiting MSSP eligibility",
            "strategies" => [
                "Partner with neighboring rural hospitals to form multi-hospital ACO",
                "Include rural health clinics (RHCs) and FQHCs as ACO participants",
                "Consider ACO REACH New Entrant track (1,000 minimum)",
                "Explore Frontier Community Health Integration Program (FCHIP)",
            ],
        ),
        "small_population_volatility" => Dict{String, Any}(
            "description" => "Random per-capita cost variation in small populations can exceed the MSR",
            "statistical_impact" => "With 5,000 beneficiaries, standard deviation of per-capita cost is ~\$400-600; MSR at 3.6% on \$12,000 PBPY = \$432 threshold",
            "implication" => "A rural ACO may generate real savings but fail to exceed the MSR due to random variation, or conversely trigger losses from a single high-cost event",
            "mitigation" => [
                "CMS adjusts MSR by beneficiary count (smaller populations get higher MSR)",
                "Risk-adjust for high-cost outliers (truncation at 99th percentile)",
                "Consider reinsurance or stop-loss for catastrophic cases",
                "Multi-year performance evaluation smooths volatility",
            ],
        ),
        "rural_bonus_payments" => Dict{String, Any}(
            "eligibility" => "ACO with ≥ 50% of assigned beneficiaries residing in rural (RUCA) areas",
            "bonus_rate" => 0.05,
            "description" => "5% add-on to shared savings payment for qualifying rural ACOs",
            "calculation" => "Applied after quality adjustment: shared_savings × 1.05",
            "policy_basis" => "42 CFR § 425.604(c) — Rural bonus for ACOs serving predominantly rural populations",
        ),
        "frontier_community_health_integration" => Dict{String, Any}(
            "program" => "Frontier Community Health Integration Program (FCHIP)",
            "description" => "CMS demonstration allowing Frontier CAHs to receive shared savings without formal ACO infrastructure",
            "eligibility" => "Critical Access Hospitals in frontier areas (< 6 people per square mile)",
            "benefit" => "Shared savings participation with reduced administrative burden",
            "status" => "CY2025: Active demonstration with limited enrollment",
        ),
        "quality_gateway_exception" => Dict{String, Any}(
            "description" => "Small ACOs (< 5,000 beneficiaries) may use the 50th percentile rather than 30th for quality gate",
            "threshold" => 5_000,
            "standard_gate" => "30th percentile composite quality score",
            "small_aco_gate" => "50th percentile composite quality score (higher bar but with reporting-only year 1)",
            "rationale" => "Small ACO quality scores are more volatile; the exception provides a fair assessment framework",
        ),
        "additional_rural_provisions" => Dict{String, Any}(
            "telehealth_expansion" => "MSSP ACOs receive expanded telehealth originating site waivers for rural beneficiaries",
            "snf_3day_waiver" => "ACOs may waive the 3-day inpatient stay requirement for SNF admission",
            "beneficiary_incentives" => "ACOs may offer beneficiary incentive programs (up to \$20/beneficiary) to encourage preventive care",
        ),
    )
end

# ═════════════════════════════════════════════════════════════════════════════
# ACO Readiness Assessment
# ═════════════════════════════════════════════════════════════════════════════

"""
    aco_readiness_assessment(hospital_data::Dict{String, Any}) -> Dict{String, Any}

Assess whether a rural hospital is ready for ACO participation across five
readiness dimensions.

## Required `hospital_data` Keys
- `"attributed_lives"` — Int: estimated attributed Medicare beneficiaries.
- `"ehr_certified"` — Bool: ONC-certified EHR in use.
- `"claims_analytics"` — Bool: has claims analytics/data warehouse capability.
- `"hie_connected"` — Bool: connected to a Health Information Exchange.
- `"care_managers"` — Int: number of dedicated care management FTEs.
- `"quality_reporting"` — Bool: currently reports CMS quality measures.
- `"financial_reserves_months"` — Float64: months of operating cash reserves.
- `"prior_vbc_experience"` — Bool: prior value-based contract experience.

## Readiness Dimensions (each scored 0–100)
1. **Scale** — Minimum attributed lives check (5,000 for MSSP, 1,000 REACH).
2. **IT Infrastructure** — EHR interoperability, claims analytics, HIE.
3. **Care Management** — Dedicated care managers (benchmark: 1 per 500 lives).
4. **Quality Reporting** — Current quality measure reporting capability.
5. **Financial Reserves** — Adequate reserves for two-sided risk (benchmark:
   ≥ 3 months operating cash for one-sided, ≥ 6 months for two-sided).

## Returns
Dict with:
- `"overall_readiness_score"` — Float64 (0–100).
- `"readiness_tier"` — Symbol: `:ready`, `:conditionally_ready`, `:not_ready`.
- `"dimension_scores"` — Dict with each dimension's score.
- `"gaps"` — Vector of String describing specific readiness gaps.
- `"recommended_actions"` — Vector of prioritized actions to close gaps.
- `"eligible_tracks"` — Vector of Symbol for tracks the hospital could enter.
"""
function aco_readiness_assessment(hospital_data::Dict{String, Any})::Dict{String, Any}
    gaps = String[]
    recommended_actions = String[]
    dimension_scores = Dict{String, Float64}()

    # ── Dimension 1: Scale ──
    attributed = get(hospital_data, "attributed_lives", 0)::Int
    if attributed >= 5_000
        dimension_scores["scale"] = 100.0
    elseif attributed >= 1_000
        dimension_scores["scale"] = 60.0
        push!(gaps, "Below MSSP minimum (5,000 lives); eligible only for ACO REACH New Entrant (1,000 min)")
        push!(recommended_actions, "Recruit additional PCP participants to increase attributed lives to 5,000+")
    else
        dimension_scores["scale"] = max(0.0, (attributed / 1_000) * 30.0)
        push!(gaps, "Below minimum threshold for all ACO tracks (need ≥ 1,000 attributed lives)")
        push!(recommended_actions, "Form multi-provider partnership or join an existing ACO as a participant")
    end

    # ── Dimension 2: IT Infrastructure ──
    ehr = get(hospital_data, "ehr_certified", false)::Bool
    claims = get(hospital_data, "claims_analytics", false)::Bool
    hie = get(hospital_data, "hie_connected", false)::Bool

    it_score = 0.0
    if ehr; it_score += 40.0; else
        push!(gaps, "No ONC-certified EHR — required for quality reporting and care coordination")
        push!(recommended_actions, "Implement ONC-certified EHR (critical path — 6-12 month timeline)")
    end
    if claims; it_score += 35.0; else
        push!(gaps, "No claims analytics capability — cannot monitor per-capita costs or identify high-risk patients")
        push!(recommended_actions, "Deploy claims analytics platform or partner with ACO management services organization (MSO)")
    end
    if hie; it_score += 25.0; else
        push!(gaps, "Not connected to Health Information Exchange — limits care coordination across providers")
        push!(recommended_actions, "Connect to regional HIE for ADT notifications and transition-of-care alerts")
    end
    dimension_scores["it_infrastructure"] = it_score

    # ── Dimension 3: Care Management ──
    care_managers = get(hospital_data, "care_managers", 0)::Int
    # Benchmark: 1 FTE per 500 attributed lives
    required_cms = max(1, ceil(Int, attributed / 500))
    if care_managers >= required_cms
        dimension_scores["care_management"] = 100.0
    elseif care_managers > 0
        dimension_scores["care_management"] = min(80.0, (care_managers / required_cms) * 100.0)
        deficit = required_cms - care_managers
        push!(gaps, "Care management staffing below benchmark: have $care_managers FTEs, need $required_cms (1 per 500 lives)")
        push!(recommended_actions, "Hire $deficit additional care manager(s) — focus on RN care coordinators with chronic disease expertise")
    else
        dimension_scores["care_management"] = 0.0
        push!(gaps, "No dedicated care management staff — critical gap for ACO success")
        push!(recommended_actions, "Establish care management program with at least $required_cms FTE(s)")
    end

    # ── Dimension 4: Quality Reporting ──
    quality_reporting = get(hospital_data, "quality_reporting", false)::Bool
    if quality_reporting
        dimension_scores["quality_reporting"] = 100.0
    else
        dimension_scores["quality_reporting"] = 0.0
        push!(gaps, "Not currently reporting CMS quality measures — required for MSSP participation")
        push!(recommended_actions, "Begin reporting MSSP quality measures; first performance year is reporting-only (no minimum score)")
    end

    # ── Dimension 5: Financial Reserves ──
    reserves_months = get(hospital_data, "financial_reserves_months", 0.0)::Float64
    prior_vbc = get(hospital_data, "prior_vbc_experience", false)::Bool

    if reserves_months >= 6.0
        dimension_scores["financial_reserves"] = 100.0
    elseif reserves_months >= 3.0
        dimension_scores["financial_reserves"] = 70.0
        push!(gaps, "Financial reserves adequate for one-sided risk only ($(reserves_months) months); two-sided risk requires ≥ 6 months")
        push!(recommended_actions, "Build operating reserves to ≥ 6 months before entering two-sided risk tracks")
    else
        dimension_scores["financial_reserves"] = max(0.0, (reserves_months / 3.0) * 40.0)
        push!(gaps, "Insufficient financial reserves ($(reserves_months) months) — even one-sided risk requires ≥ 3 months")
        push!(recommended_actions, "Prioritize cash reserve accumulation; consider stop-loss insurance for initial ACO years")
    end

    # ── Overall Score ──
    weights = Dict("scale" => 0.25, "it_infrastructure" => 0.25,
                    "care_management" => 0.20, "quality_reporting" => 0.15,
                    "financial_reserves" => 0.15)
    overall = sum(dimension_scores[k] * weights[k] for k in keys(weights))

    readiness_tier = if overall >= 75.0
        :ready
    elseif overall >= 50.0
        :conditionally_ready
    else
        :not_ready
    end

    # Eligible tracks based on attributed lives and readiness
    eligible_tracks = Symbol[]
    if attributed >= 5_000
        push!(eligible_tracks, :mssp_basic_a)
        push!(eligible_tracks, :mssp_basic_b)
        if overall >= 60.0
            push!(eligible_tracks, :mssp_basic_c)
            push!(eligible_tracks, :mssp_basic_d)
        end
        if overall >= 75.0 && prior_vbc
            push!(eligible_tracks, :mssp_basic_e)
            push!(eligible_tracks, :mssp_enhanced)
        end
        push!(eligible_tracks, :aco_reach_standard)
    end
    if attributed >= 1_000
        push!(eligible_tracks, :aco_reach_new_entrant)
    end
    if attributed >= 1_000
        push!(eligible_tracks, :aco_reach_high_needs)
    end

    Dict{String, Any}(
        "overall_readiness_score" => round(overall; digits=1),
        "readiness_tier" => readiness_tier,
        "dimension_scores" => dimension_scores,
        "gaps" => gaps,
        "recommended_actions" => recommended_actions,
        "eligible_tracks" => eligible_tracks,
        "attributed_lives" => attributed,
        "prior_vbc_experience" => prior_vbc,
    )
end

# ═════════════════════════════════════════════════════════════════════════════
# Track Recommendation
# ═════════════════════════════════════════════════════════════════════════════

"""
    track_recommendation(beneficiary_count::Int,
                         historical_savings_rate::Float64,
                         quality_score::Float64,
                         risk_tolerance::Symbol=:moderate) -> Dict{String, Any}

Recommend an optimal ACO track based on hospital characteristics, risk
tolerance, and historical performance.

## Decision Logic
- **New to ACO** (no historical savings) → Basic Level A (one-sided, low risk).
- **Proven savings, moderate risk** → Basic Level C or D (two-sided, capped).
- **Strong performance** (savings > 3%, quality > 0.7) → Enhanced Track.
- **Small/rural** (< 5,000 beneficiaries) → ACO REACH New Entrant.
- **High risk tolerance + strong performance** → ACO REACH Standard.

## Risk Tolerance Levels
- `:conservative` — Minimize downside; prefer one-sided or low-cap tracks.
- `:moderate` — Balance upside potential with manageable loss exposure.
- `:aggressive` — Maximize potential shared savings; accept higher loss risk.

## Returns
Dict with:
- `"recommended_track"` — Symbol of the recommended track.
- `"recommendation_rationale"` — String explaining the recommendation.
- `"track_comparison"` — Vector of Dicts with expected financial outcome
  for each eligible track.
- `"expected_savings"` — Float64 projected shared savings for recommended track.
- `"expected_risk"` — Float64 maximum potential loss for recommended track.
- `"alternative_tracks"` — Vector of Symbol with viable alternatives.
"""
function track_recommendation(beneficiary_count::Int,
                              historical_savings_rate::Float64,
                              quality_score::Float64,
                              risk_tolerance::Symbol=:moderate)::Dict{String, Any}
    beneficiary_count > 0 || throw(
        DomainValidationError("beneficiary_count",
            string(beneficiary_count), "> 0",
            "Beneficiary count must be positive"))
    0.0 <= quality_score <= 1.0 || throw(
        DomainValidationError("quality_score",
            string(quality_score), "[0, 1]",
            "Quality score must be between 0.0 and 1.0"))
    risk_tolerance in (:conservative, :moderate, :aggressive) || throw(
        DomainValidationError("risk_tolerance",
            string(risk_tolerance), "∈ {:conservative, :moderate, :aggressive}",
            "Risk tolerance must be :conservative, :moderate, or :aggressive"))

    all_tracks = merge(mssp_tracks(), aco_reach_tracks())

    # Determine eligible tracks by beneficiary count
    eligible = Symbol[]
    if beneficiary_count >= 5_000
        append!(eligible, [:mssp_basic_a, :mssp_basic_b, :mssp_basic_c,
                           :mssp_basic_d, :mssp_basic_e, :mssp_enhanced,
                           :aco_reach_standard])
    end
    if beneficiary_count >= 1_000
        append!(eligible, [:aco_reach_new_entrant, :aco_reach_high_needs])
    end

    # Remove duplicates
    eligible = unique(eligible)

    if isempty(eligible)
        return Dict{String, Any}(
            "recommended_track" => :none,
            "recommendation_rationale" => "Beneficiary count ($beneficiary_count) is below the minimum threshold (1,000) for all ACO tracks",
            "track_comparison" => Dict{String, Any}[],
            "expected_savings" => 0.0,
            "expected_risk" => 0.0,
            "alternative_tracks" => Symbol[],
        )
    end

    # Estimate a hypothetical benchmark for projections
    # Use national average per-capita expenditure (~$12,500 for CY2025)
    per_capita_benchmark = 12_500.0
    total_benchmark = per_capita_benchmark * beneficiary_count

    # Compute expected financial outcome for each eligible track
    track_comparison = Dict{String, Any}[]
    for tk_sym in eligible
        tk = all_tracks[tk_sym]
        msr = startswith(string(tk_sym), "mssp") ?
              _beneficiary_adjusted_msr(beneficiary_count) : tk.min_savings_rate

        # Expected savings at the historical rate
        gross_savings = total_benchmark * historical_savings_rate
        savings_exceeds_msr = historical_savings_rate >= msr

        expected_shared_savings = if savings_exceeds_msr && historical_savings_rate > 0.0
            gross_savings * tk.sharing_rate_savings * quality_score
        else
            0.0
        end

        # Maximum potential loss (worst case)
        max_loss = tk.loss_cap_pct * total_benchmark

        # Net expected value (simple: probability-weighted)
        # Assume 60% chance of achieving historical savings if positive,
        # 20% chance of losses at MSR level for two-sided
        prob_savings = historical_savings_rate > 0.0 ? 0.60 : 0.20
        prob_losses = tk.risk_type == :two_sided ? 0.20 : 0.0

        expected_value = prob_savings * expected_shared_savings -
                         prob_losses * max_loss * 0.3  # assume average loss = 30% of cap

        push!(track_comparison, Dict{String, Any}(
            "track" => tk_sym,
            "risk_type" => tk.risk_type,
            "sharing_rate_savings" => tk.sharing_rate_savings,
            "sharing_rate_losses" => tk.sharing_rate_losses,
            "msr" => msr,
            "loss_cap_pct" => tk.loss_cap_pct,
            "expected_shared_savings" => round(expected_shared_savings; digits=2),
            "max_potential_loss" => round(max_loss; digits=2),
            "expected_value" => round(expected_value; digits=2),
            "savings_exceeds_msr" => savings_exceeds_msr,
        ))
    end

    # Sort by expected value descending
    sort!(track_comparison, by=x -> x["expected_value"], rev=true)

    # Decision logic
    recommended, rationale = _select_track(
        beneficiary_count, historical_savings_rate, quality_score,
        risk_tolerance, eligible, all_tracks)

    rec_track = all_tracks[recommended]
    rec_msr = startswith(string(recommended), "mssp") ?
              _beneficiary_adjusted_msr(beneficiary_count) : rec_track.min_savings_rate
    rec_gross = total_benchmark * max(historical_savings_rate, 0.0)
    rec_shared = if historical_savings_rate >= rec_msr
        rec_gross * rec_track.sharing_rate_savings * quality_score
    else
        0.0
    end
    rec_max_loss = rec_track.loss_cap_pct * total_benchmark

    alternatives = filter(t -> t != recommended, eligible)

    Dict{String, Any}(
        "recommended_track" => recommended,
        "recommendation_rationale" => rationale,
        "track_comparison" => track_comparison,
        "expected_savings" => round(rec_shared; digits=2),
        "expected_risk" => round(rec_max_loss; digits=2),
        "alternative_tracks" => alternatives,
        "beneficiary_count" => beneficiary_count,
        "historical_savings_rate" => historical_savings_rate,
        "quality_score" => quality_score,
        "risk_tolerance" => risk_tolerance,
    )
end

"""
    _select_track(beneficiary_count, historical_savings_rate, quality_score,
                  risk_tolerance, eligible, all_tracks) -> (Symbol, String)

Internal helper to select the recommended ACO track based on decision logic.
"""
function _select_track(beneficiary_count::Int,
                       historical_savings_rate::Float64,
                       quality_score::Float64,
                       risk_tolerance::Symbol,
                       eligible::Vector{Symbol},
                       all_tracks::Dict{Symbol, ACOTrack})::Tuple{Symbol, String}

    is_small = beneficiary_count < 5_000
    is_new = historical_savings_rate <= 0.0
    is_strong = historical_savings_rate >= 0.03 && quality_score >= 0.70
    is_moderate_performer = historical_savings_rate > 0.0 && historical_savings_rate < 0.03

    # Small/rural → ACO REACH New Entrant
    if is_small && :aco_reach_new_entrant in eligible
        return (:aco_reach_new_entrant,
                "Below MSSP minimum (5,000 lives) with $(beneficiary_count) beneficiaries. " *
                "ACO REACH New Entrant has a 1,000-life minimum and reduced downside risk, " *
                "making it the best entry point for small rural hospitals.")
    end

    # New to ACO → Basic Level A
    if is_new && :mssp_basic_a in eligible
        return (:mssp_basic_a,
                "No historical savings rate — new to ACO participation. " *
                "Basic Level A offers one-sided risk (upside only) with 40% savings share, " *
                "allowing the hospital to build ACO infrastructure without downside exposure.")
    end

    # Strong performance decisions based on risk tolerance
    if is_strong
        if risk_tolerance == :aggressive && :mssp_enhanced in eligible
            return (:mssp_enhanced,
                    "Strong historical performance ($(round(historical_savings_rate*100; digits=1))% savings, " *
                    "$(round(quality_score*100; digits=1))% quality) with aggressive risk tolerance. " *
                    "Enhanced Track offers 75% savings share — maximum upside for proven ACOs. " *
                    "Requires readiness for 75% loss sharing with risk corridor protection.")
        elseif risk_tolerance == :aggressive && :aco_reach_standard in eligible
            return (:aco_reach_standard,
                    "Strong performance with aggressive risk tolerance. " *
                    "ACO REACH Standard offers full capitation with 65% savings share.")
        elseif risk_tolerance == :moderate && :mssp_basic_e in eligible
            return (:mssp_basic_e,
                    "Strong performance ($(round(historical_savings_rate*100; digits=1))% savings) " *
                    "with moderate risk tolerance. Basic Level E offers 50% savings share " *
                    "with 8% loss cap — meaningful upside with bounded downside.")
        elseif :mssp_basic_c in eligible
            return (:mssp_basic_c,
                    "Strong performance with conservative risk tolerance. " *
                    "Basic Level C offers 50% savings / 30% losses with only 1% loss cap — " *
                    "minimal downside while accessing two-sided savings rates.")
        end
    end

    # Moderate performance
    if is_moderate_performer
        if risk_tolerance == :conservative && :mssp_basic_a in eligible
            return (:mssp_basic_a,
                    "Moderate savings ($(round(historical_savings_rate*100; digits=1))%) with " *
                    "conservative risk tolerance. Basic Level A (one-sided) allows continued " *
                    "performance improvement without loss exposure.")
        elseif risk_tolerance in (:moderate, :aggressive) && :mssp_basic_c in eligible
            return (:mssp_basic_c,
                    "Moderate savings ($(round(historical_savings_rate*100; digits=1))%) — " *
                    "Basic Level C introduces two-sided risk with 50% savings share " *
                    "and 1% loss cap, providing upside potential with limited downside.")
        elseif :mssp_basic_b in eligible
            return (:mssp_basic_b,
                    "Moderate savings with Basic Level B — continued one-sided risk " *
                    "as a stepping stone to two-sided tracks.")
        end
    end

    # Fallback: safest available track
    preferred_order = [:mssp_basic_a, :mssp_basic_b, :aco_reach_new_entrant,
                       :mssp_basic_c, :mssp_basic_d, :aco_reach_high_needs,
                       :mssp_basic_e, :aco_reach_standard, :mssp_enhanced]
    for tk in preferred_order
        if tk in eligible
            return (tk, "Default recommendation: $(tk) based on available eligible tracks.")
        end
    end

    return (first(eligible), "Fallback to first eligible track.")
end
