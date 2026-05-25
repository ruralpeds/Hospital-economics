# ── Managed Care Tiered Contracting ────────────────────────────────────────
#
# Models managed care contract structures, tiered capitation, payer mix
# optimization, and FFS-to-capitation transition for rural hospitals.
#
# Provides:
# 1. Contract analysis with NPV, margin, and risk-adjusted returns
# 2. Tiered capitation modeling using CMS actuarial benchmarks
# 3. Capitation adequacy assessment and MLR by tier
# 4. FFS-to-capitation transition bridging with 3-year ramp
# 5. Risk pool analysis with stop-loss and utilization scenarios
# 6. Contract negotiation preparation with BATNA and concession strategy
# 7. Payer mix optimization under capacity constraints
# 8. Rural hospital benchmark data for CAH/critical access facilities
#
# References:
# - CMS Actuarial Value Calculator (2025).
# - Milliman Medical Index (2025): Commercial cost benchmarks.
# - HFMA (2024). Managed Care Contracting for Rural Hospitals.
# - MedPAC (2025). Report to the Congress: Medicare and the Health Care Delivery System.

using Statistics; using Printf

# ═══════════════════════════════════════════════════════════════════════════
# Constants — Contract type and reimbursement method symbols
# ═══════════════════════════════════════════════════════════════════════════

"""Valid managed care contract types."""
const CONTRACT_TYPES = (:hmo, :ppo, :pos, :epo, :aco, :direct_contract)

"""Valid reimbursement methods."""
const REIMBURSEMENT_METHODS = (
    :fee_for_service, :per_diem, :drg_case_rate, :capitation,
    :bundled, :shared_savings, :percentage_of_charges
)

# ═══════════════════════════════════════════════════════════════════════════
# Types
# ═══════════════════════════════════════════════════════════════════════════

"""
    TieredCapitation

Per-member-per-month (PMPM) capitation rates broken out by service tier.
Based on CMS actuarial value categories.
"""
@kwdef struct TieredCapitation
    primary_care_pmpm::Float64
    specialist_pmpm::Float64
    facility_pmpm::Float64
    pharmacy_pmpm::Float64
    total_pmpm::Float64
end

"""
    ContractTerms

Comprehensive managed care contract parameters for analysis and negotiation.

# Fields
- `name`: Contract or payer name
- `contract_type`: One of $CONTRACT_TYPES
- `reimbursement_method`: One of $REIMBURSEMENT_METHODS
- `base_rate`: Base reimbursement rate (per unit, per diem, PMPM, or % of charges)
- `escalator_pct`: Annual rate escalator (e.g. 0.03 = 3%)
- `term_years`: Contract duration in years
- `volume_threshold`: Minimum annual volume to trigger full rates
- `quality_bonus_pct`: Quality performance bonus as % of base (e.g. 0.02 = 2%)
- `risk_corridor_upside`: Max upside sharing % (e.g. 0.05 = 5% above target)
- `risk_corridor_downside`: Max downside risk % (e.g. 0.05 = 5% below target)
- `stoploss_threshold`: Individual stop-loss attachment point (\$)
"""
@kwdef struct ContractTerms
    name::String
    contract_type::Symbol
    reimbursement_method::Symbol
    base_rate::Float64
    escalator_pct::Float64         = 0.03
    term_years::Int                = 3
    volume_threshold::Int          = 0
    quality_bonus_pct::Float64     = 0.0
    risk_corridor_upside::Float64  = 0.05
    risk_corridor_downside::Float64 = 0.05
    stoploss_threshold::Float64    = 100_000.0
end

"""
    ContractAnalysis

Results of financial analysis for a single managed care contract.
"""
@kwdef struct ContractAnalysis
    annual_revenue::Float64
    cost_to_serve::Float64
    margin::Float64
    margin_pct::Float64
    risk_adjusted_margin::Float64
    breakeven_volume::Int
    contract_value_npv::Float64
end

"""
    ManagedCarePortfolio

Aggregate view of a hospital's managed care contract portfolio.
"""
@kwdef struct ManagedCarePortfolio
    contracts::Vector{ContractTerms}
    total_covered_lives::Int
    blended_pmpm::Float64
    total_annual_revenue::Float64
    concentration_risk::Float64    # HHI of revenue across contracts
end

# ═══════════════════════════════════════════════════════════════════════════
# CMS Actuarial Benchmarks — Rural Hospital Defaults (FY 2025/2026)
# ═══════════════════════════════════════════════════════════════════════════

# Commercial PMPM benchmarks by service tier (Milliman 2025, rural-adjusted)
const CMS_COMMERCIAL_PMPM_BENCHMARKS = Dict{String,Float64}(
    "primary_care"  => 55.00,   # Lower utilization in rural
    "specialist"    => 95.00,   # Fewer specialists, more referrals
    "facility"      => 210.00,  # Inpatient + outpatient facility
    "pharmacy"      => 120.00,  # Includes PBM pass-through
    "total"         => 480.00,
)

# Demographic risk adjustment factors (CMS HCC-like)
const DEMOGRAPHIC_RISK_FACTORS = Dict{String,Float64}(
    "pediatric_0_17"  => 0.60,
    "adult_18_34"     => 0.75,
    "adult_35_44"     => 0.90,
    "adult_45_54"     => 1.10,
    "adult_55_64"     => 1.45,
    "medicare_65_74"  => 1.30,
    "medicare_75_84"  => 1.55,
    "medicare_85_plus" => 1.85,
)

# Utilization benchmarks per 1,000 members (CMS/Milliman, rural)
const UTILIZATION_BENCHMARKS = Dict{String,Float64}(
    "inpatient_admits"          => 55.0,   # per 1,000
    "inpatient_days"            => 220.0,
    "ed_visits"                 => 450.0,  # higher in rural
    "outpatient_surgeries"      => 65.0,
    "office_visits_primary"     => 3800.0,
    "office_visits_specialist"  => 1200.0,
    "imaging_procedures"        => 600.0,
    "lab_tests"                 => 8500.0,
    "pharmacy_scripts"          => 12000.0,
)

# ═══════════════════════════════════════════════════════════════════════════
# Core Functions
# ═══════════════════════════════════════════════════════════════════════════

"""
    analyze_contract(terms::ContractTerms, expected_volume::Int,
                     avg_cost_per_unit::Float64;
                     discount_rate::Float64=0.08) -> ContractAnalysis

Perform comprehensive financial analysis of a managed care contract.

Calculates annual revenue (with quality bonus), cost to serve, margin,
risk-adjusted margin (applying risk corridor adjustments), breakeven
volume, and NPV of the contract over its full term.

# Arguments
- `terms`: Contract parameters (rates, escalators, corridors, etc.)
- `expected_volume`: Expected annual service volume (encounters/discharges)
- `avg_cost_per_unit`: Average cost per unit of service
- `discount_rate`: Discount rate for NPV calculation (default 8%)

# Returns
`ContractAnalysis` with revenue, cost, margin, and NPV metrics.

# Example
```julia
terms = ContractTerms(name="BlueCross PPO", contract_type=:ppo,
                      reimbursement_method=:drg_case_rate,
                      base_rate=8500.0, escalator_pct=0.03, term_years=3)
result = analyze_contract(terms, 1200, 7800.0)
```
"""
function analyze_contract(terms::ContractTerms, expected_volume::Int,
                          avg_cost_per_unit::Float64;
                          discount_rate::Float64=0.08)::ContractAnalysis
    expected_volume > 0 || throw(DomainValidationError("expected_volume",
        string(expected_volume), "> 0", "Expected volume must be positive"))
    avg_cost_per_unit > 0 || throw(DomainValidationError("avg_cost_per_unit",
        string(avg_cost_per_unit), "> 0", "Average cost must be positive"))
    discount_rate >= 0 || throw(DomainValidationError("discount_rate",
        string(discount_rate), ">= 0", "Discount rate must be non-negative"))

    # Year 1 revenue: base rate × volume + quality bonus
    effective_volume = max(expected_volume, terms.volume_threshold)
    annual_revenue = terms.base_rate * effective_volume
    quality_bonus = annual_revenue * terms.quality_bonus_pct
    annual_revenue += quality_bonus

    # Cost to serve
    cost_to_serve = avg_cost_per_unit * expected_volume

    # Raw margin
    margin = annual_revenue - cost_to_serve
    margin_pct = annual_revenue > 0 ? margin / annual_revenue : 0.0

    # Risk-adjusted margin: apply risk corridor adjustment
    # If margin is positive beyond upside corridor, cap the upside
    # If margin is negative beyond downside corridor, cap the downside
    upside_cap = annual_revenue * terms.risk_corridor_upside
    downside_cap = annual_revenue * terms.risk_corridor_downside
    risk_adjusted_margin = if margin > upside_cap
        upside_cap + (margin - upside_cap) * 0.5  # share excess upside
    elseif margin < -downside_cap
        -downside_cap - (-downside_cap - margin) * 0.5  # share excess downside
    else
        margin
    end

    # Breakeven volume: revenue per unit = cost per unit
    effective_rate = terms.base_rate * (1.0 + terms.quality_bonus_pct)
    breakeven_volume = if effective_rate > 0
        max(1, ceil(Int, cost_to_serve / effective_rate))
    else
        typemax(Int)
    end

    # NPV over contract term with annual escalation
    npv_total = 0.0
    for yr in 1:terms.term_years
        yr_rate = terms.base_rate * (1.0 + terms.escalator_pct)^(yr - 1)
        yr_revenue = yr_rate * effective_volume * (1.0 + terms.quality_bonus_pct)
        yr_cost = avg_cost_per_unit * (1.0 + 0.04)^(yr - 1) * expected_volume  # 4% cost inflation
        yr_margin = yr_revenue - yr_cost
        npv_total += yr_margin / (1.0 + discount_rate)^yr
    end

    return ContractAnalysis(
        annual_revenue       = round(annual_revenue, digits=2),
        cost_to_serve        = round(cost_to_serve, digits=2),
        margin               = round(margin, digits=2),
        margin_pct           = round(margin_pct, digits=4),
        risk_adjusted_margin = round(risk_adjusted_margin, digits=2),
        breakeven_volume     = breakeven_volume,
        contract_value_npv   = round(npv_total, digits=2),
    )
end

"""
    compare_contracts(contracts::Vector{ContractTerms}, expected_volume::Int,
                      avg_cost::Float64) -> Vector{ContractAnalysis}

Side-by-side comparison of multiple managed care contracts, ranked by NPV
(highest first). Useful for evaluating competing payer proposals.

# Arguments
- `contracts`: Vector of contract proposals to compare
- `expected_volume`: Expected annual volume (same for all)
- `avg_cost`: Average cost per unit of service

# Returns
Vector of `ContractAnalysis` sorted descending by `contract_value_npv`.
"""
function compare_contracts(contracts::Vector{ContractTerms}, expected_volume::Int,
                           avg_cost::Float64)::Vector{ContractAnalysis}
    isempty(contracts) && throw(DataValidationError(
        "Cannot compare empty contract list"))
    analyses = [analyze_contract(ct, expected_volume, avg_cost) for ct in contracts]
    sort!(analyses, by=a -> a.contract_value_npv, rev=true)
    return analyses
end

"""
    tiered_capitation_model(covered_lives::Int,
                            demographics::Dict{String,Float64},
                            utilization::Dict{String,Float64}) -> TieredCapitation

Calculate tiered PMPM capitation rates based on covered population demographics
and utilization patterns, using CMS actuarial benchmarks.

# Arguments
- `covered_lives`: Number of covered members
- `demographics`: Dict mapping age band → proportion (must sum to ~1.0).
  Keys from: "pediatric_0_17", "adult_18_34", "adult_35_44", "adult_45_54",
  "adult_55_64", "medicare_65_74", "medicare_75_84", "medicare_85_plus"
- `utilization`: Dict mapping service type → relative utilization factor
  (1.0 = benchmark). Keys from: "inpatient_admits", "ed_visits",
  "office_visits_primary", "office_visits_specialist", "pharmacy_scripts", etc.

# Returns
`TieredCapitation` with risk-adjusted PMPM rates per tier.

# Example
```julia
demographics = Dict("adult_45_54" => 0.30, "adult_55_64" => 0.40,
                     "medicare_65_74" => 0.30)
utilization = Dict("inpatient_admits" => 1.1, "ed_visits" => 1.2,
                    "office_visits_primary" => 0.9)
cap = tiered_capitation_model(5000, demographics, utilization)
```
"""
function tiered_capitation_model(covered_lives::Int,
                                 demographics::Dict{String,Float64},
                                 utilization::Dict{String,Float64})::TieredCapitation
    covered_lives > 0 || throw(DomainValidationError("covered_lives",
        string(covered_lives), "> 0", "Covered lives must be positive"))

    # Compute composite risk score from demographics
    risk_score = 0.0
    total_weight = 0.0
    for (band, proportion) in demographics
        factor = get(DEMOGRAPHIC_RISK_FACTORS, band, 1.0)
        risk_score += proportion * factor
        total_weight += proportion
    end
    # Normalize if proportions don't sum to 1
    if total_weight > 0 && abs(total_weight - 1.0) > 0.01
        risk_score /= total_weight
    end
    risk_score = max(risk_score, 0.5)  # floor at 0.5

    # Utilization adjustments by tier
    pc_util = get(utilization, "office_visits_primary", 1.0)
    spec_util = mean([
        get(utilization, "office_visits_specialist", 1.0),
        get(utilization, "imaging_procedures", 1.0),
    ])
    fac_util = mean([
        get(utilization, "inpatient_admits", 1.0),
        get(utilization, "ed_visits", 1.0),
        get(utilization, "outpatient_surgeries", 1.0),
    ])
    rx_util = get(utilization, "pharmacy_scripts", 1.0)

    # Calculate risk- and utilization-adjusted PMPM per tier
    primary_care_pmpm = CMS_COMMERCIAL_PMPM_BENCHMARKS["primary_care"] * risk_score * pc_util
    specialist_pmpm   = CMS_COMMERCIAL_PMPM_BENCHMARKS["specialist"] * risk_score * spec_util
    facility_pmpm     = CMS_COMMERCIAL_PMPM_BENCHMARKS["facility"] * risk_score * fac_util
    pharmacy_pmpm     = CMS_COMMERCIAL_PMPM_BENCHMARKS["pharmacy"] * risk_score * rx_util
    total_pmpm        = primary_care_pmpm + specialist_pmpm + facility_pmpm + pharmacy_pmpm

    return TieredCapitation(
        primary_care_pmpm = round(primary_care_pmpm, digits=2),
        specialist_pmpm   = round(specialist_pmpm, digits=2),
        facility_pmpm     = round(facility_pmpm, digits=2),
        pharmacy_pmpm     = round(pharmacy_pmpm, digits=2),
        total_pmpm        = round(total_pmpm, digits=2),
    )
end

"""
    capitation_adequacy(cap::TieredCapitation,
                        actual_costs::Dict{String,Float64}) -> Dict{String,Any}

Compare capitation revenue vs actual costs per tier to identify underfunded
service categories and calculate medical loss ratio (MLR) by tier.

# Arguments
- `cap`: Tiered capitation rates (PMPM)
- `actual_costs`: Dict with keys "primary_care", "specialist", "facility",
  "pharmacy" → actual PMPM cost per tier

# Returns
Dict with per-tier adequacy metrics, overall MLR, and list of underfunded tiers.
"""
function capitation_adequacy(cap::TieredCapitation,
                             actual_costs::Dict{String,Float64})::Dict{String,Any}
    tiers = Dict{String,Any}()
    underfunded = String[]
    total_cap_revenue = 0.0
    total_actual_cost = 0.0

    tier_map = Dict(
        "primary_care" => cap.primary_care_pmpm,
        "specialist"   => cap.specialist_pmpm,
        "facility"     => cap.facility_pmpm,
        "pharmacy"     => cap.pharmacy_pmpm,
    )

    for (tier_name, cap_pmpm) in tier_map
        actual = get(actual_costs, tier_name, 0.0)
        surplus_deficit = cap_pmpm - actual
        mlr_tier = actual > 0 ? actual / cap_pmpm : 0.0

        tiers[tier_name] = Dict{String,Any}(
            "capitation_pmpm"  => cap_pmpm,
            "actual_cost_pmpm" => actual,
            "surplus_deficit"  => round(surplus_deficit, digits=2),
            "mlr"              => round(mlr_tier, digits=4),
            "adequate"         => surplus_deficit >= 0,
        )

        if surplus_deficit < 0
            push!(underfunded, tier_name)
        end

        total_cap_revenue += cap_pmpm
        total_actual_cost += actual
    end

    overall_mlr = total_cap_revenue > 0 ? total_actual_cost / total_cap_revenue : 0.0

    return Dict{String,Any}(
        "tier_analysis"     => tiers,
        "underfunded_tiers" => underfunded,
        "overall_mlr"       => round(overall_mlr, digits=4),
        "total_cap_pmpm"    => round(total_cap_revenue, digits=2),
        "total_cost_pmpm"   => round(total_actual_cost, digits=2),
        "net_surplus_pmpm"  => round(total_cap_revenue - total_actual_cost, digits=2),
        "aca_compliant"     => overall_mlr >= 0.80,  # ACA MLR floor
    )
end

"""
    ffs_to_capitation_bridge(current_ffs_revenue::Float64, current_volume::Int,
                             target_lives::Int) -> Dict{String,Any}

Model the financial transition from fee-for-service to capitation with a
3-year graduated ramp. Calculates expected revenue change, risk pool
requirements, stop-loss needs, and recommended transition milestones.

# Arguments
- `current_ffs_revenue`: Annual FFS revenue (\$)
- `current_volume`: Current annual encounter/discharge volume
- `target_lives`: Target covered lives under capitation

# Returns
Dict with transition timeline, revenue projections, risk pool sizing,
and stop-loss recommendations.
"""
function ffs_to_capitation_bridge(current_ffs_revenue::Float64, current_volume::Int,
                                  target_lives::Int)::Dict{String,Any}
    current_ffs_revenue > 0 || throw(DomainValidationError("current_ffs_revenue",
        string(current_ffs_revenue), "> 0", "FFS revenue must be positive"))
    current_volume > 0 || throw(DomainValidationError("current_volume",
        string(current_volume), "> 0", "Current volume must be positive"))
    target_lives > 0 || throw(DomainValidationError("target_lives",
        string(target_lives), "> 0", "Target lives must be positive"))

    # Derive current per-unit economics
    ffs_per_unit = current_ffs_revenue / current_volume

    # Estimate equivalent capitation PMPM from current FFS economics
    # Assumes 12 months, and utilization of ~0.15 encounters/member/month for rural
    encounters_per_member_month = 0.15
    implied_pmpm = ffs_per_unit * encounters_per_member_month
    annual_cap_revenue = implied_pmpm * target_lives * 12

    revenue_change = annual_cap_revenue - current_ffs_revenue
    revenue_change_pct = current_ffs_revenue > 0 ? revenue_change / current_ffs_revenue : 0.0

    # Risk pool: 5% of capitation revenue, minimum $250K for rural
    risk_pool_target = max(annual_cap_revenue * 0.05, 250_000.0)

    # Stop-loss: individual @ $75K for rural, aggregate @ 125% of expected
    individual_stoploss = 75_000.0
    aggregate_stoploss = annual_cap_revenue * 1.25

    # Estimated stop-loss premium: 3-5% of capitation revenue for rural
    stoploss_premium = annual_cap_revenue * 0.04

    # 3-year transition ramp
    transition = Dict{String,Any}[]
    ramp_pcts = [0.25, 0.50, 1.00]  # % of lives moving to cap each year
    for yr in 1:3
        cap_lives = ceil(Int, target_lives * ramp_pcts[yr])
        ffs_lives = target_lives - cap_lives
        yr_cap_rev = implied_pmpm * cap_lives * 12
        yr_ffs_rev = current_ffs_revenue * (ffs_lives / target_lives)
        total_rev = yr_cap_rev + yr_ffs_rev
        push!(transition, Dict{String,Any}(
            "year"               => yr,
            "capitated_lives"    => cap_lives,
            "ffs_lives"          => ffs_lives,
            "capitation_pct"     => ramp_pcts[yr],
            "capitation_revenue" => round(yr_cap_rev, digits=2),
            "ffs_revenue"        => round(yr_ffs_rev, digits=2),
            "total_revenue"      => round(total_rev, digits=2),
            "risk_pool_funded"   => round(risk_pool_target * ramp_pcts[yr], digits=2),
        ))
    end

    return Dict{String,Any}(
        "current_ffs_revenue"     => current_ffs_revenue,
        "implied_pmpm"            => round(implied_pmpm, digits=2),
        "target_annual_cap_rev"   => round(annual_cap_revenue, digits=2),
        "revenue_change"          => round(revenue_change, digits=2),
        "revenue_change_pct"      => round(revenue_change_pct, digits=4),
        "risk_pool_target"        => round(risk_pool_target, digits=2),
        "individual_stoploss"     => individual_stoploss,
        "aggregate_stoploss"      => round(aggregate_stoploss, digits=2),
        "stoploss_premium_est"    => round(stoploss_premium, digits=2),
        "transition_timeline"     => transition,
        "key_milestones"          => [
            "Year 1: 25% of lives capitated — build care mgmt infrastructure",
            "Year 2: 50% of lives capitated — validate utilization management",
            "Year 3: 100% capitated — full risk, stop-loss in place",
        ],
        "prerequisites" => [
            "Care management program operational",
            "Claims data warehouse with ≥12 months history",
            "Stop-loss insurance secured",
            "Provider network agreements executed",
            "Quality measurement reporting capability",
        ],
    )
end

"""
    risk_pool_analysis(covered_lives::Int, pmpm::Float64;
                       risk_reserve_pct::Float64=0.05,
                       stoploss_attachment::Float64=100000.0) -> Dict{String,Any}

Analyze risk pool funding requirements, stop-loss premium estimates, and
expected surplus/deficit under multiple utilization scenarios (80%, 100%, 120%).

# Arguments
- `covered_lives`: Number of members in the risk pool
- `pmpm`: Per-member-per-month capitation rate
- `risk_reserve_pct`: Percentage of revenue held in risk reserve (default 5%)
- `stoploss_attachment`: Individual stop-loss attachment point (default \$100K)

# Returns
Dict with risk pool sizing, stop-loss costs, and scenario projections.
"""
function risk_pool_analysis(covered_lives::Int, pmpm::Float64;
                            risk_reserve_pct::Float64=0.05,
                            stoploss_attachment::Float64=100_000.0)::Dict{String,Any}
    covered_lives > 0 || throw(DomainValidationError("covered_lives",
        string(covered_lives), "> 0", "Covered lives must be positive"))
    pmpm > 0 || throw(DomainValidationError("pmpm",
        string(pmpm), "> 0", "PMPM must be positive"))

    annual_revenue = pmpm * covered_lives * 12
    risk_reserve = annual_revenue * risk_reserve_pct

    # Stop-loss premium estimate: based on attachment point and pool size
    # Smaller pools need more expensive stop-loss (adverse selection)
    pool_size_factor = if covered_lives < 1000
        1.5   # small pool surcharge
    elseif covered_lives < 5000
        1.2
    elseif covered_lives < 10000
        1.0
    else
        0.85  # large pool discount
    end

    # Base stop-loss premium: ~3% of capitation revenue, adjusted
    stoploss_premium = annual_revenue * 0.03 * pool_size_factor

    # Attachment point adjustment: lower attachment = higher premium
    attachment_factor = 100_000.0 / max(stoploss_attachment, 1.0)
    stoploss_premium *= min(attachment_factor, 3.0)

    # Expected medical costs at benchmark utilization (MLR ~85%)
    expected_medical_cost = annual_revenue * 0.85

    # Scenario analysis at 80%, 100%, 120% utilization
    scenarios = Dict{String,Any}[]
    for (label, util_factor) in [("low_80pct", 0.80), ("expected_100pct", 1.00), ("high_120pct", 1.20)]
        actual_cost = expected_medical_cost * util_factor
        admin_cost = annual_revenue * 0.12  # 12% admin load
        total_cost = actual_cost + admin_cost + stoploss_premium
        surplus_deficit = annual_revenue - total_cost
        mlr = annual_revenue > 0 ? actual_cost / annual_revenue : 0.0

        push!(scenarios, Dict{String,Any}(
            "scenario"        => label,
            "utilization_pct" => util_factor,
            "medical_cost"    => round(actual_cost, digits=2),
            "admin_cost"      => round(admin_cost, digits=2),
            "stoploss_cost"   => round(stoploss_premium, digits=2),
            "total_cost"      => round(total_cost, digits=2),
            "surplus_deficit"  => round(surplus_deficit, digits=2),
            "mlr"             => round(mlr, digits=4),
        ))
    end

    return Dict{String,Any}(
        "covered_lives"         => covered_lives,
        "annual_capitation_rev" => round(annual_revenue, digits=2),
        "risk_reserve_amount"   => round(risk_reserve, digits=2),
        "risk_reserve_pct"      => risk_reserve_pct,
        "stoploss_attachment"   => stoploss_attachment,
        "stoploss_premium_est"  => round(stoploss_premium, digits=2),
        "pool_size_factor"      => pool_size_factor,
        "scenarios"             => scenarios,
        "minimum_pool_recommendation" => max(1000, covered_lives),
        "adequacy_note" => covered_lives < 1000 ?
            "WARNING: Pool size <1,000 creates significant actuarial risk. Consider reinsurance or pool aggregation." :
            "Pool size adequate for basic risk spreading.",
    )
end

"""
    contract_negotiation_prep(current_terms::ContractTerms,
                              market_rates::Dict{String,Float64},
                              hospital_cost::Float64) -> Dict{String,Any}

Generate a negotiation brief for managed care contract renewal or new contract.
Includes current vs market rate comparison, BATNA (best alternative to negotiated
agreement), target rate, concession strategy, and prioritized term categories.

# Arguments
- `current_terms`: Current or proposed contract terms
- `market_rates`: Dict with keys "median_rate", "25th_pct", "75th_pct",
  "medicare_rate" → benchmark rates in the market
- `hospital_cost`: Average cost per unit to deliver services

# Returns
Dict with negotiation strategy, rate comparisons, BATNA, and term priorities.
"""
function contract_negotiation_prep(current_terms::ContractTerms,
                                   market_rates::Dict{String,Float64},
                                   hospital_cost::Float64)::Dict{String,Any}
    hospital_cost > 0 || throw(DomainValidationError("hospital_cost",
        string(hospital_cost), "> 0", "Hospital cost must be positive"))

    median_rate = get(market_rates, "median_rate", current_terms.base_rate)
    pct_25 = get(market_rates, "25th_pct", median_rate * 0.85)
    pct_75 = get(market_rates, "75th_pct", median_rate * 1.15)
    medicare_rate = get(market_rates, "medicare_rate", median_rate * 0.70)

    # Rate comparison
    rate_vs_median = current_terms.base_rate / median_rate
    rate_vs_medicare = medicare_rate > 0 ? current_terms.base_rate / medicare_rate : 0.0
    rate_percentile = if current_terms.base_rate <= pct_25
        "Below 25th percentile — significantly below market"
    elseif current_terms.base_rate <= median_rate
        "25th-50th percentile — below market median"
    elseif current_terms.base_rate <= pct_75
        "50th-75th percentile — above market median"
    else
        "Above 75th percentile — premium rate position"
    end

    # BATNA: walk-away point = cost + minimum acceptable margin (3% for rural)
    min_margin_pct = 0.03
    batna_rate = hospital_cost * (1.0 + min_margin_pct)

    # Target rate: cost + target margin (8-12% for rural commercial)
    target_margin_pct = 0.10
    target_rate = hospital_cost * (1.0 + target_margin_pct)

    # Stretch goal: 75th percentile market rate
    stretch_rate = pct_75

    # Current margin analysis
    current_margin = current_terms.base_rate - hospital_cost
    current_margin_pct = current_terms.base_rate > 0 ? current_margin / current_terms.base_rate : 0.0

    # Concession strategy: items to trade in negotiation
    concession_strategy = [
        Dict("priority" => 1, "item" => "Base rate increase to target",
             "value" => round(target_rate - current_terms.base_rate, digits=2),
             "flexibility" => "low"),
        Dict("priority" => 2, "item" => "Annual escalator ≥ 3%",
             "value" => "$(round(current_terms.escalator_pct * 100, digits=1))% current",
             "flexibility" => "medium"),
        Dict("priority" => 3, "item" => "Quality bonus program",
             "value" => "Up to $(round(target_rate * 0.03, digits=2)) per unit",
             "flexibility" => "medium"),
        Dict("priority" => 4, "item" => "Volume threshold reduction",
             "value" => "Current: $(current_terms.volume_threshold)",
             "flexibility" => "high"),
        Dict("priority" => 5, "item" => "Contract term length",
             "value" => "$(current_terms.term_years) years current",
             "flexibility" => "high"),
    ]

    must_haves = [
        "Base rate at or above BATNA (\$$(round(batna_rate, digits=2)))",
        "Annual escalator ≥ CPI-Medical (~3%)",
        "Stop-loss protection for outlier cases",
        "Timely payment terms (≤30 days clean claim)",
        "Dispute resolution process",
    ]

    nice_to_haves = [
        "Quality bonus opportunity (2-3% of base)",
        "Shared savings component",
        "Multi-year rate guarantee",
        "Carve-out for high-cost implants/devices",
        "Reduced prior authorization burden",
    ]

    return Dict{String,Any}(
        "current_rate"      => current_terms.base_rate,
        "market_comparison" => Dict{String,Any}(
            "median_rate"    => median_rate,
            "25th_pct"       => pct_25,
            "75th_pct"       => pct_75,
            "medicare_rate"  => medicare_rate,
            "rate_vs_median" => round(rate_vs_median, digits=3),
            "rate_vs_medicare" => round(rate_vs_medicare, digits=3),
            "percentile_position" => rate_percentile,
        ),
        "margin_analysis" => Dict{String,Any}(
            "hospital_cost"      => hospital_cost,
            "current_margin"     => round(current_margin, digits=2),
            "current_margin_pct" => round(current_margin_pct, digits=4),
        ),
        "negotiation_targets" => Dict{String,Any}(
            "batna_walkaway"  => round(batna_rate, digits=2),
            "target_rate"     => round(target_rate, digits=2),
            "stretch_goal"    => round(stretch_rate, digits=2),
            "target_margin"   => "$(round(target_margin_pct * 100, digits=1))%",
        ),
        "concession_strategy" => concession_strategy,
        "must_haves"          => must_haves,
        "nice_to_haves"       => nice_to_haves,
        "rural_considerations" => [
            "Essential community provider (ECP) status — leverage network adequacy requirements",
            "Limited alternative providers within 35-mile radius",
            "State any-willing-provider laws may apply",
            "Medicare-dependent hospital designation strengthens negotiating position",
            "Emphasize community access impact of inadequate rates",
        ],
    )
end

"""
    payer_mix_optimization(contracts::Vector{ContractTerms},
                           volumes::Vector{Int},
                           capacity::Int) -> Dict{String,Any}

Given limited hospital capacity, recommend optimal payer mix to maximize
total margin. Uses simple linear optimization logic (greedy by margin per unit).

# Arguments
- `contracts`: Available contract options
- `volumes`: Maximum volume available from each payer
- `capacity`: Total hospital capacity (encounters/discharges)

# Returns
Dict with optimal allocation, total margin, and capacity utilization.
"""
function payer_mix_optimization(contracts::Vector{ContractTerms},
                                volumes::Vector{Int},
                                capacity::Int)::Dict{String,Any}
    length(contracts) == length(volumes) || throw(DataValidationError(
        "contracts and volumes vectors must have equal length"))
    capacity > 0 || throw(DomainValidationError("capacity",
        string(capacity), "> 0", "Capacity must be positive"))

    n = length(contracts)

    # Estimate margin per unit for each contract
    # Use rural hospital average cost benchmark of $7,500/encounter
    avg_cost = 7500.0
    margin_per_unit = Float64[]
    for ct in contracts
        effective_rate = ct.base_rate * (1.0 + ct.quality_bonus_pct)
        push!(margin_per_unit, effective_rate - avg_cost)
    end

    # Greedy allocation: sort by margin per unit (descending), allocate capacity
    order = sortperm(margin_per_unit, rev=true)

    allocations = zeros(Int, n)
    remaining_capacity = capacity
    for idx in order
        alloc = min(volumes[idx], remaining_capacity)
        allocations[idx] = alloc
        remaining_capacity -= alloc
        remaining_capacity <= 0 && break
    end

    # Calculate results
    total_revenue = 0.0
    total_cost = 0.0
    total_volume = 0
    allocation_details = Dict{String,Any}[]
    for i in 1:n
        rev = contracts[i].base_rate * (1.0 + contracts[i].quality_bonus_pct) * allocations[i]
        cost = avg_cost * allocations[i]
        margin = rev - cost
        push!(allocation_details, Dict{String,Any}(
            "payer"            => contracts[i].name,
            "contract_type"    => string(contracts[i].contract_type),
            "allocated_volume" => allocations[i],
            "max_volume"       => volumes[i],
            "utilization_pct"  => volumes[i] > 0 ? round(allocations[i] / volumes[i], digits=3) : 0.0,
            "revenue"          => round(rev, digits=2),
            "cost"             => round(cost, digits=2),
            "margin"           => round(margin, digits=2),
            "margin_per_unit"  => round(margin_per_unit[i], digits=2),
        ))
        total_revenue += rev
        total_cost += cost
        total_volume += allocations[i]
    end

    total_margin = total_revenue - total_cost
    capacity_util = capacity > 0 ? total_volume / capacity : 0.0

    # Concentration risk (HHI of allocated revenue)
    revenue_shares = [
        d["revenue"] / max(total_revenue, 1.0)
        for d in allocation_details
    ]
    hhi = sum(s^2 for s in revenue_shares)

    return Dict{String,Any}(
        "allocations"        => allocation_details,
        "total_revenue"      => round(total_revenue, digits=2),
        "total_cost"         => round(total_cost, digits=2),
        "total_margin"       => round(total_margin, digits=2),
        "total_margin_pct"   => round(total_margin / max(total_revenue, 1.0), digits=4),
        "total_volume"       => total_volume,
        "capacity"           => capacity,
        "capacity_utilization" => round(capacity_util, digits=3),
        "unused_capacity"    => capacity - total_volume,
        "hhi_concentration"  => round(hhi, digits=4),
        "concentration_risk" => hhi > 0.25 ? "HIGH" : hhi > 0.15 ? "MODERATE" : "LOW",
        "recommendation"     => hhi > 0.25 ?
            "Revenue concentration is high. Diversify payer mix to reduce single-payer dependency." :
            "Payer mix diversification is adequate.",
    )
end

"""
    rural_hospital_benchmarks() -> Dict{String,Any}

Return benchmark managed care metrics for Critical Access Hospitals (CAHs)
and other rural hospitals, based on MedPAC, Flex Monitoring, and HFMA data.

Includes payer mix distributions, typical contract terms, financial
performance benchmarks, and managed care penetration data.
"""
function rural_hospital_benchmarks()::Dict{String,Any}
    return Dict{String,Any}(
        "payer_mix" => Dict{String,Any}(
            "medicare"          => Dict("min" => 0.50, "median" => 0.58, "max" => 0.65,
                                        "note" => "Medicare is dominant payer for rural hospitals"),
            "medicaid"          => Dict("min" => 0.15, "median" => 0.20, "max" => 0.25,
                                        "note" => "Higher in Medicaid expansion states"),
            "commercial"        => Dict("min" => 0.15, "median" => 0.18, "max" => 0.25,
                                        "note" => "Limited commercial volume in rural markets"),
            "self_pay_uninsured" => Dict("min" => 0.03, "median" => 0.05, "max" => 0.10,
                                        "note" => "Includes charity care and bad debt"),
            "other"             => Dict("min" => 0.01, "median" => 0.02, "max" => 0.05,
                                        "note" => "Workers comp, VA, TRICARE, etc."),
        ),
        "contract_terms" => Dict{String,Any}(
            "typical_escalator"           => Dict("min" => 0.02, "median" => 0.03, "max" => 0.04),
            "typical_term_years"          => Dict("min" => 1, "median" => 3, "max" => 5),
            "avg_commercial_to_medicare"  => Dict("min" => 1.10, "median" => 1.35, "max" => 1.80,
                "note" => "Rural hospitals average 135% of Medicare vs 200%+ urban"),
            "quality_bonus_range_pct"     => Dict("min" => 0.01, "median" => 0.02, "max" => 0.05),
            "typical_stoploss_attachment" => Dict("min" => 50_000, "median" => 75_000, "max" => 150_000),
        ),
        "financial_benchmarks" => Dict{String,Any}(
            "operating_margin"      => Dict("25th_pct" => -0.02, "median" => 0.02, "75th_pct" => 0.05,
                "note" => "CAHs report thin margins; many operate at a loss"),
            "total_margin"          => Dict("25th_pct" => 0.00, "median" => 0.03, "75th_pct" => 0.06),
            "days_cash_on_hand"     => Dict("25th_pct" => 30, "median" => 60, "75th_pct" => 120),
            "days_in_ar"            => Dict("25th_pct" => 45, "median" => 55, "75th_pct" => 70),
            "cost_per_adjusted_discharge" => Dict("25th_pct" => 8_500, "median" => 11_000, "75th_pct" => 14_500),
            "avg_daily_census"      => Dict("25th_pct" => 3, "median" => 6, "75th_pct" => 12),
        ),
        "managed_care_penetration" => Dict{String,Any}(
            "medicare_advantage_pct" => Dict("min" => 0.15, "median" => 0.35, "max" => 0.55,
                "note" => "MA penetration growing rapidly in rural markets"),
            "medicaid_managed_care_pct" => Dict("min" => 0.30, "median" => 0.55, "max" => 0.80,
                "note" => "Varies significantly by state"),
            "commercial_hmo_pct"   => Dict("min" => 0.05, "median" => 0.15, "max" => 0.30,
                "note" => "Limited HMO presence in many rural areas"),
            "commercial_ppo_pct"   => Dict("min" => 0.40, "median" => 0.60, "max" => 0.80,
                "note" => "PPO is dominant commercial product in rural"),
        ),
        "capitation_benchmarks" => Dict{String,Any}(
            "commercial_pmpm_total"   => Dict("min" => 380.0, "median" => 480.0, "max" => 620.0),
            "medicare_pmpm_total"     => Dict("min" => 800.0, "median" => 950.0, "max" => 1200.0),
            "medicaid_pmpm_total"     => Dict("min" => 250.0, "median" => 350.0, "max" => 500.0),
            "risk_pool_reserve_pct"   => Dict("min" => 0.03, "median" => 0.05, "max" => 0.08),
        ),
        "rural_specific" => Dict{String,Any}(
            "essential_community_provider" => "Most CAHs qualify as ECPs — leverage for network inclusion",
            "sole_community_hospital"      => "SCH designation strengthens negotiating position",
            "geographic_isolation"         => "Limited alternatives within 35+ miles supports rate justification",
            "volume_constraints"           => "Low volume limits risk pool size; consider multi-hospital pooling",
            "cah_cost_based_medicare"      => "CAH 101% cost-based Medicare reimbursement is a floor for negotiations",
            "state_flex_programs"          => "State FLEX programs may support managed care transition costs",
        ),
        "data_sources" => [
            "MedPAC (2025). Report to the Congress: Medicare Payment Policy.",
            "Flex Monitoring Team (2025). CAH Financial Indicators Report.",
            "HFMA (2024). Rural Hospital Managed Care Benchmarks.",
            "Milliman Medical Index (2025). Healthcare Cost Benchmarks.",
            "CMS Medicare Cost Reports (2024). Hospital Cost Report Data.",
        ],
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# Exports
# ═══════════════════════════════════════════════════════════════════════════

# Note: exports are declared in FinanceEngine.jl
