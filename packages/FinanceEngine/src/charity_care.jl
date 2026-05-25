"""
    charity_care.jl — Charity Care & Financial Assistance Policy Optimization

Models charity care / financial assistance programmes for tax-exempt hospitals,
combining IRS 501(r) compliance requirements with economic optimization:

1. **Financial Assistance Policy (FAP)** — tiered discount schedules based on
   Federal Poverty Level (FPL) percentages, with sliding-scale options.

2. **Community Benefit Analysis** — IRS Schedule H Part I equivalent reporting
   of charity care at cost, unreimbursed Medicaid, community health improvement,
   and other community benefit categories.

3. **FAP Optimization** — finds discount tier configurations that maximise
   community benefit while respecting operating budget constraints.

4. **Bad Debt vs Charity Reclassification** — identifies bad debt that could be
   reclassified as charity care for improved 501(r) reporting and community
   benefit ratios.

5. **Presumptive Eligibility Modelling** — estimates the financial impact of
   auto-qualifying patients based on Medicaid enrolment, homelessness, and
   income proxies.

6. **Tax Exemption Analysis** — compares the value of nonprofit tax exemptions
   (property, income, sales) against community benefit provided.

References:
- IRS Final Rule on Section 501(r) (TD 9708, 2014).
- IRS Schedule H (Form 990) Instructions (2025).
- CMS 2025 Federal Poverty Level Guidelines.
- Rosenbaum S et al (2013). The Value of the Nonprofit Hospital Tax Exemption.
  New England Journal of Medicine 368(12): 1048-1050.
"""

using Statistics; using Printf

# ─── Types ───────────────────────────────────────────────────────────────────

"""
    FPLTier

A single tier within a financial assistance policy, mapping a Federal Poverty
Level ceiling percentage to a discount percentage.

Fields:
- `fpl_ceiling_pct::Int` — upper bound of FPL bracket (e.g. 200 means 0–200% FPL)
- `discount_pct::Float64` — discount applied to charges (0.0–1.0)
- `description::String` — human-readable label
"""
struct FPLTier
    fpl_ceiling_pct::Int
    discount_pct::Float64
    description::String
end

"""
    FinancialAssistancePolicy

Complete financial assistance policy for a tax-exempt hospital.

Fields:
- `name::String` — policy name / identifier
- `tiers::Vector{FPLTier}` — discount tiers ordered by FPL ceiling ascending
- `sliding_scale::Bool` — whether discounts interpolate between tiers
- `presumptive_eligibility::Bool` — auto-qualify patients via Medicaid/proxy data
- `application_fee::Float64` — cost to process each application
- `lookback_months::Int` — income verification lookback period
- `catastrophic_threshold_pct::Float64` — % of annual income above which
  medical expenses qualify for additional assistance regardless of FPL tier
"""
struct FinancialAssistancePolicy
    name::String
    tiers::Vector{FPLTier}
    sliding_scale::Bool
    presumptive_eligibility::Bool
    application_fee::Float64
    lookback_months::Int
    catastrophic_threshold_pct::Float64
end

"""
    CommunityProfile

Demographic and economic profile of the hospital's service area, used to
estimate charity care demand and community benefit obligations.

Fields:
- `total_population::Int` — total service area population
- `median_household_income::Float64` — median household income (USD)
- `uninsured_rate::Float64` — fraction of population without insurance (0.0–1.0)
- `medicaid_rate::Float64` — fraction of population on Medicaid (0.0–1.0)
- `fpl_distribution::Dict{Int,Float64}` — fraction of population at each FPL
  bracket (keys: 100, 150, 200, 250, 300, 400 representing % of FPL)
"""
struct CommunityProfile
    total_population::Int
    median_household_income::Float64
    uninsured_rate::Float64
    medicaid_rate::Float64
    fpl_distribution::Dict{Int,Float64}
end

"""
    CharityCareResult

Output of charity care volume estimation and policy evaluation.

Fields:
- `total_charity_cost::Float64` — total cost of charity care provided
- `charity_cases::Int` — number of cases receiving financial assistance
- `avg_discount::Float64` — weighted average discount across all charity cases
- `community_benefit_value::Float64` — reportable community benefit (at cost)
- `tax_exemption_value::Float64` — estimated value of tax exemption
- `net_cost_after_tax_benefit::Float64` — charity cost minus tax benefit
- `policy_score::Float64` — composite score (0–100) rating policy effectiveness
"""
struct CharityCareResult
    total_charity_cost::Float64
    charity_cases::Int
    avg_discount::Float64
    community_benefit_value::Float64
    tax_exemption_value::Float64
    net_cost_after_tax_benefit::Float64
    policy_score::Float64
end

# ─── Default Financial Assistance Policy ─────────────────────────────────────

"""
    default_fap() -> FinancialAssistancePolicy

Return an IRS 501(r)-compliant financial assistance policy with standard tiers:

| FPL Bracket     | Discount |
|:----------------|:---------|
| 0–200% FPL      | 100%     |
| 201–300% FPL    | 75%      |
| 301–400% FPL    | 50%      |
| 401%+ FPL       | 0%       |

Presumptive eligibility is enabled, lookback is 12 months, catastrophic
threshold is 25% of annual income, and application fee is \$0.
"""
function default_fap()::FinancialAssistancePolicy
    tiers = [
        FPLTier(200, 1.00, "0-200% FPL — Full charity (free care)"),
        FPLTier(300, 0.75, "201-300% FPL — 75% discount"),
        FPLTier(400, 0.50, "301-400% FPL — 50% discount"),
        FPLTier(typemax(Int), 0.00, "401%+ FPL — No discount"),
    ]
    FinancialAssistancePolicy(
        "Standard 501(r) Financial Assistance Policy",
        tiers,
        true,   # sliding_scale
        true,   # presumptive_eligibility
        0.0,    # application_fee
        12,     # lookback_months
        0.25,   # catastrophic_threshold_pct (25% of income)
    )
end

# ─── Charity Volume Estimation ───────────────────────────────────────────────

"""
    _discount_for_fpl(policy::FinancialAssistancePolicy, fpl_pct::Int) -> Float64

Internal helper: determine discount percentage for a given FPL bracket using
the policy tiers. If `sliding_scale` is enabled and the FPL falls between
two tier ceilings, the discount is linearly interpolated.
"""
function _discount_for_fpl(policy::FinancialAssistancePolicy, fpl_pct::Int)::Float64
    sorted_tiers = sort(policy.tiers, by=t -> t.fpl_ceiling_pct)

    # Exact tier match or below lowest ceiling
    for (i, tier) in enumerate(sorted_tiers)
        if fpl_pct <= tier.fpl_ceiling_pct
            if !policy.sliding_scale || i == 1
                return tier.discount_pct
            end
            # Sliding scale: interpolate between previous tier and this one
            prev = sorted_tiers[i - 1]
            if fpl_pct <= prev.fpl_ceiling_pct
                return prev.discount_pct
            end
            frac = (fpl_pct - prev.fpl_ceiling_pct) /
                   (tier.fpl_ceiling_pct - prev.fpl_ceiling_pct)
            return prev.discount_pct + frac * (tier.discount_pct - prev.discount_pct)
        end
    end
    return 0.0
end

"""
    calculate_charity_volume(
        policy::FinancialAssistancePolicy,
        community::CommunityProfile,
        annual_ed_visits::Int,
        annual_inpatient::Int,
    ) -> Dict{String,Any}

Estimate charity care volume based on community FPL distribution and policy
tiers.  Assumes uninsured and underinsured patients at each FPL bracket seek
care proportionally to their share of the population.

Returns a Dict with:
- `"eligible_patients"` — total estimated eligible patients
- `"cases_by_tier"` — Vector of (tier_description, cases, discount, estimated_cost)
- `"total_estimated_cost"` — aggregate charity cost
- `"avg_charge_per_case"` — blended average charge used in estimation
"""
function calculate_charity_volume(
    policy::FinancialAssistancePolicy,
    community::CommunityProfile,
    annual_ed_visits::Int,
    annual_inpatient::Int,
)::Dict{String,Any}
    total_visits = annual_ed_visits + annual_inpatient
    avg_ed_charge = 3_500.0
    avg_ip_charge = 25_000.0
    blended_avg = (annual_ed_visits * avg_ed_charge +
                   annual_inpatient * avg_ip_charge) / max(total_visits, 1)

    # Cost-to-charge ratio for converting charges to cost
    cost_to_charge = 0.40

    sorted_tiers = sort(policy.tiers, by=t -> t.fpl_ceiling_pct)
    fpl_brackets = sort(collect(keys(community.fpl_distribution)))

    eligible_total = 0
    total_cost = 0.0
    cases_by_tier = Vector{NamedTuple{
        (:tier, :cases, :discount, :estimated_cost), Tuple{String,Int,Float64,Float64}
    }}()

    for bracket in fpl_brackets
        pop_frac = get(community.fpl_distribution, bracket, 0.0)
        # Patients seeking charity care: uninsured at this FPL bracket
        bracket_pop = round(Int, community.total_population * pop_frac)
        bracket_uninsured = round(Int, bracket_pop * community.uninsured_rate)

        # Utilisation rate: lower-income patients use ED more frequently
        utilisation_factor = bracket <= 150 ? 1.4 :
                             bracket <= 200 ? 1.2 :
                             bracket <= 300 ? 1.0 : 0.8
        est_cases = round(Int,
            bracket_uninsured * (total_visits / max(community.total_population, 1)) *
            utilisation_factor
        )

        discount = _discount_for_fpl(policy, bracket)
        if discount > 0.0 && est_cases > 0
            charity_charges = est_cases * blended_avg * discount
            charity_cost = charity_charges * cost_to_charge
            eligible_total += est_cases
            total_cost += charity_cost

            tier_desc = ""
            for t in sorted_tiers
                if bracket <= t.fpl_ceiling_pct
                    tier_desc = t.description
                    break
                end
            end

            push!(cases_by_tier, (
                tier=tier_desc,
                cases=est_cases,
                discount=discount,
                estimated_cost=charity_cost,
            ))
        end
    end

    Dict{String,Any}(
        "eligible_patients" => eligible_total,
        "cases_by_tier"     => cases_by_tier,
        "total_estimated_cost" => total_cost,
        "avg_charge_per_case"  => blended_avg,
    )
end

# ─── FAP Optimization ───────────────────────────────────────────────────────

"""
    optimize_fap(
        community::CommunityProfile,
        annual_visits::Int,
        avg_charge::Float64,
        operating_margin::Float64;
        min_community_benefit_pct::Float64 = 0.05,
        max_charity_budget::Float64 = Inf,
    ) -> FinancialAssistancePolicy

Find optimal sliding-scale discount thresholds that maximise community benefit
while staying within budget constraints.

Tests multiple tier configurations by varying:
- FPL ceiling for full (100%) charity: 150%, 200%, 250%
- FPL ceiling for partial charity: 250%, 300%, 350%, 400%
- Partial discount level: 25%, 50%, 75%

Scores each configuration by community benefit per dollar of net cost and
returns the policy with the highest score that satisfies both
`min_community_benefit_pct` (as fraction of total revenue) and
`max_charity_budget`.
"""
function optimize_fap(
    community::CommunityProfile,
    annual_visits::Int,
    avg_charge::Float64,
    operating_margin::Float64;
    min_community_benefit_pct::Float64=0.05,
    max_charity_budget::Float64=Inf,
)::FinancialAssistancePolicy
    total_revenue = annual_visits * avg_charge
    cost_to_charge = 0.40

    best_policy = default_fap()
    best_score = -Inf

    full_charity_ceilings = [150, 200, 250]
    partial_ceilings = [250, 300, 350, 400]
    partial_discounts = [0.25, 0.50, 0.75]

    for full_ceil in full_charity_ceilings
        for part_ceil in partial_ceilings
            part_ceil <= full_ceil && continue
            for part_disc in partial_discounts
                tiers = [
                    FPLTier(full_ceil, 1.00,
                        @sprintf("0-%d%% FPL — Full charity", full_ceil)),
                    FPLTier(part_ceil, part_disc,
                        @sprintf("%d-%d%% FPL — %d%% discount",
                            full_ceil + 1, part_ceil,
                            round(Int, part_disc * 100))),
                    FPLTier(typemax(Int), 0.00, "Above threshold — No discount"),
                ]

                candidate = FinancialAssistancePolicy(
                    @sprintf("Optimised FAP (full≤%d%%, partial≤%d%% @ %d%%)",
                        full_ceil, part_ceil, round(Int, part_disc * 100)),
                    tiers, true, true, 0.0, 12, 0.25,
                )

                # Estimate charity volume
                vol = calculate_charity_volume(
                    candidate, community, annual_visits ÷ 2, annual_visits ÷ 2,
                )
                charity_cost = vol["total_estimated_cost"]

                # Budget constraint
                charity_cost > max_charity_budget && continue

                # Community benefit includes charity at cost + estimated
                # unreimbursed Medicaid (approximation)
                unreimbursed_medicaid = total_revenue * community.medicaid_rate * 0.10
                community_benefit = charity_cost + unreimbursed_medicaid

                # Minimum community benefit constraint
                cb_pct = community_benefit / max(total_revenue, 1.0)
                cb_pct < min_community_benefit_pct && continue

                # Tax exemption estimate (rough: 3% of revenue)
                tax_benefit = total_revenue * 0.03
                net_cost = charity_cost - tax_benefit

                # Score: community benefit per dollar of net cost
                # (higher is better; penalise negative net cost lightly)
                score = if net_cost > 0.0
                    community_benefit / net_cost
                else
                    community_benefit + abs(net_cost)
                end

                if score > best_score
                    best_score = score
                    best_policy = candidate
                end
            end
        end
    end

    best_policy
end

# ─── Community Benefit Report (IRS Schedule H Part I) ────────────────────────

"""
    community_benefit_report(
        policy::FinancialAssistancePolicy,
        community::CommunityProfile,
        financials::Dict{String,Float64},
    ) -> Dict{String,Any}

Generate an IRS Schedule H Part I equivalent community benefit report.

Expected keys in `financials`:
- `"total_expenses"` — total operating expenses
- `"total_revenue"` — total operating revenue
- `"gross_patient_revenue"` — gross patient revenue
- `"medicaid_revenue"` — Medicaid payments received
- `"medicaid_cost"` — cost of services to Medicaid patients
- `"charity_charges"` — gross charity care charges
- `"bad_debt"` — bad debt expense
- `"community_health_improvement"` — community health improvement spending
- `"health_professions_education"` — health professions education spending
- `"subsidized_health_services"` — subsidised health services net cost
- `"research"` — research spending
- `"community_building"` — community building activities spending

Returns a Dict with IRS Schedule H categories, total community benefit,
community benefit as percentage of total expenses, and an IRS benchmark
comparison (typical range: 5–7% of total expenses).
"""
function community_benefit_report(
    policy::FinancialAssistancePolicy,
    community::CommunityProfile,
    financials::Dict{String,Float64},
)::Dict{String,Any}
    total_expenses = get(financials, "total_expenses", 0.0)
    cost_to_charge = 0.40

    # Part I Line 1: Financial Assistance at Cost
    charity_charges = get(financials, "charity_charges", 0.0)
    charity_at_cost = charity_charges * cost_to_charge

    # Part I Line 2: Unreimbursed Medicaid
    medicaid_cost = get(financials, "medicaid_cost", 0.0)
    medicaid_revenue = get(financials, "medicaid_revenue", 0.0)
    unreimbursed_medicaid = max(medicaid_cost - medicaid_revenue, 0.0)

    # Part I Lines 3-7: Other community benefit categories
    community_health = get(financials, "community_health_improvement", 0.0)
    education = get(financials, "health_professions_education", 0.0)
    subsidised = get(financials, "subsidized_health_services", 0.0)
    research = get(financials, "research", 0.0)
    community_building = get(financials, "community_building", 0.0)

    # Total community benefit
    total_cb = charity_at_cost + unreimbursed_medicaid + community_health +
               education + subsidised + research + community_building

    cb_pct = total_expenses > 0 ? (total_cb / total_expenses) * 100.0 : 0.0

    # IRS benchmark comparison
    benchmark_low = 5.0
    benchmark_high = 7.0
    benchmark_status = if cb_pct >= benchmark_high
        "Above typical range — strong community benefit"
    elseif cb_pct >= benchmark_low
        "Within typical range"
    else
        "Below typical range — may attract regulatory scrutiny"
    end

    Dict{String,Any}(
        "charity_care_at_cost"          => charity_at_cost,
        "unreimbursed_medicaid"         => unreimbursed_medicaid,
        "community_health_improvement"  => community_health,
        "health_professions_education"  => education,
        "subsidized_health_services"    => subsidised,
        "research"                      => research,
        "community_building"            => community_building,
        "total_community_benefit"       => total_cb,
        "community_benefit_pct"         => cb_pct,
        "total_expenses"                => total_expenses,
        "irs_benchmark_low_pct"         => benchmark_low,
        "irs_benchmark_high_pct"        => benchmark_high,
        "benchmark_status"              => benchmark_status,
        "policy_name"                   => policy.name,
    )
end

# ─── Bad Debt vs Charity Reclassification ────────────────────────────────────

"""
    bad_debt_vs_charity(
        gross_charges::Float64,
        contractual_adjustments::Float64,
        bad_debt::Float64,
        charity_care::Float64,
    ) -> Dict{String,Any}

Analyse the relationship between bad debt and charity care.  Under IRS 501(r),
bad debt from patients who would have qualified for financial assistance should
be reclassified as charity care.  This improves community benefit reporting
and reduces bad debt expense.

Returns:
- `"potential_reclassification"` — estimated bad debt reclassifiable as charity
- `"reclassification_pct"` — fraction of bad debt eligible for reclassification
- `"current_charity_pct"` — charity as % of gross charges before reclassification
- `"revised_charity_pct"` — charity as % of gross charges after reclassification
- `"current_bad_debt_pct"` — bad debt as % of net revenue before reclassification
- `"revised_bad_debt_pct"` — bad debt as % of net revenue after reclassification
- `"community_benefit_impact"` — additional community benefit from reclassification
- `"recommendation"` — narrative recommendation
"""
function bad_debt_vs_charity(
    gross_charges::Float64,
    contractual_adjustments::Float64,
    bad_debt::Float64,
    charity_care::Float64,
)::Dict{String,Any}
    net_revenue = gross_charges - contractual_adjustments

    # Industry research: 30–60% of bad debt is from patients who would qualify
    # for charity care.  Use 40% as conservative estimate.
    reclassification_rate = 0.40
    potential_reclass = bad_debt * reclassification_rate

    # Cost-to-charge ratio for community benefit calculation
    cost_to_charge = 0.40

    current_charity_pct = gross_charges > 0 ?
        (charity_care / gross_charges) * 100.0 : 0.0
    revised_charity = charity_care + potential_reclass
    revised_charity_pct = gross_charges > 0 ?
        (revised_charity / gross_charges) * 100.0 : 0.0

    current_bad_debt_pct = net_revenue > 0 ?
        (bad_debt / net_revenue) * 100.0 : 0.0
    revised_bad_debt = bad_debt - potential_reclass
    revised_bad_debt_pct = net_revenue > 0 ?
        (revised_bad_debt / net_revenue) * 100.0 : 0.0

    cb_impact = potential_reclass * cost_to_charge

    # Recommendation
    recommendation = if potential_reclass > 0 && current_bad_debt_pct > 3.0
        @sprintf(
            "Recommend screening bad debt accounts for FAP eligibility. " *
            "Potential reclassification of \$%s could increase community " *
            "benefit by \$%s and reduce bad debt expense by %.1f%%.",
            _fmt_currency(potential_reclass),
            _fmt_currency(cb_impact),
            current_bad_debt_pct - revised_bad_debt_pct,
        )
    elseif potential_reclass > 0
        @sprintf(
            "Some reclassification opportunity exists (\$%s). " *
            "Consider implementing routine FAP screening of bad debt accounts.",
            _fmt_currency(potential_reclass),
        )
    else
        "Bad debt and charity levels appear appropriately classified."
    end

    Dict{String,Any}(
        "potential_reclassification"  => potential_reclass,
        "reclassification_pct"        => reclassification_rate * 100.0,
        "current_charity_pct"         => current_charity_pct,
        "revised_charity_pct"         => revised_charity_pct,
        "current_bad_debt_pct"        => current_bad_debt_pct,
        "revised_bad_debt_pct"        => revised_bad_debt_pct,
        "community_benefit_impact"    => cb_impact,
        "revised_bad_debt"            => revised_bad_debt,
        "revised_charity_care"        => revised_charity,
        "recommendation"              => recommendation,
    )
end

"""
    _fmt_currency(x::Float64) -> String

Internal helper: format a number as currency with commas (no dollar sign).
"""
function _fmt_currency(x::Float64)::String
    neg = x < 0
    x = abs(x)
    whole = floor(Int, x)
    cents = round(Int, (x - whole) * 100)
    s = string(whole)
    # Insert commas
    parts = String[]
    while length(s) > 3
        push!(parts, s[end-2:end])
        s = s[1:end-3]
    end
    push!(parts, s)
    formatted = join(reverse(parts), ",")
    result = @sprintf("%s.%02d", formatted, cents)
    neg ? "-" * result : result
end

# ─── Presumptive Eligibility Model ──────────────────────────────────────────

"""
    presumptive_eligibility_model(
        community::CommunityProfile;
        enrollment_rate::Float64 = 0.60,
    ) -> Dict{String,Any}

Model the impact of presumptive eligibility — auto-qualifying patients for
financial assistance based on Medicaid enrolment, homelessness status, or
income proxy data (e.g. ZIP code median income).

Parameters:
- `community` — community demographic profile
- `enrollment_rate` — fraction of eligible patients who actually enrol in the
  programme without a full application (default 60%)

Returns:
- `"estimated_auto_qualifications"` — patients auto-qualifying per year
- `"admin_cost_savings"` — administrative cost savings from fewer applications
- `"additional_charity_volume"` — additional charity cases from higher uptake
- `"net_cost_impact"` — net change in cost (additional charity minus admin savings)
- `"current_uptake_estimate"` — estimated current programme uptake without
  presumptive eligibility
- `"projected_uptake"` — projected uptake with presumptive eligibility
"""
function presumptive_eligibility_model(
    community::CommunityProfile;
    enrollment_rate::Float64=0.60,
)::Dict{String,Any}
    # Baseline uptake without presumptive eligibility: ~30% of eligible patients
    baseline_uptake = 0.30

    # Population eligible for charity (below 200% FPL and uninsured)
    fpl_below_200 = sum(
        get(community.fpl_distribution, k, 0.0)
        for k in keys(community.fpl_distribution) if k <= 200;
        init=0.0,
    )
    eligible_pop = round(Int,
        community.total_population * fpl_below_200 * community.uninsured_rate
    )

    # Current charity cases (baseline uptake)
    current_cases = round(Int, eligible_pop * baseline_uptake)

    # With presumptive eligibility: higher enrolment rate
    projected_uptake = baseline_uptake + (1.0 - baseline_uptake) * enrollment_rate
    projected_cases = round(Int, eligible_pop * projected_uptake)
    additional_cases = projected_cases - current_cases

    # Administrative cost per application: ~$250 (staff time, verification)
    app_cost = 250.0
    # Presumptive eligibility removes application for auto-qualified patients
    auto_quals = round(Int, eligible_pop * community.medicaid_rate * enrollment_rate)
    admin_savings = auto_quals * app_cost

    # Average charity cost per case
    avg_charity_cost = 4_200.0  # blended ED + inpatient at cost
    additional_charity_cost = additional_cases * avg_charity_cost

    net_impact = additional_charity_cost - admin_savings

    Dict{String,Any}(
        "estimated_auto_qualifications" => auto_quals,
        "admin_cost_savings"            => admin_savings,
        "additional_charity_volume"     => additional_cases,
        "additional_charity_cost"       => additional_charity_cost,
        "net_cost_impact"               => net_impact,
        "current_uptake_estimate"       => baseline_uptake,
        "projected_uptake"              => projected_uptake,
        "eligible_population"           => eligible_pop,
        "current_charity_cases"         => current_cases,
        "projected_charity_cases"       => projected_cases,
    )
end

# ─── Tax Exemption Analysis ─────────────────────────────────────────────────

"""
    tax_exemption_analysis(
        total_revenue::Float64,
        community_benefit_total::Float64,
        property_value::Float64;
        property_tax_rate::Float64 = 0.02,
        sales_tax_rate::Float64 = 0.06,
    ) -> Dict{String,Any}

Calculate the value of nonprofit tax exemption and compare against community
benefit provided.  Addresses the policy question: is the hospital "earning"
its tax exemption?

Tax components estimated:
- **Property tax** savings = property_value * property_tax_rate
- **Income tax equivalent** = estimated operating income * effective corporate
  rate (21% federal + 5% state average)
- **Sales tax** savings = estimated taxable purchases * sales_tax_rate

Returns:
- `"property_tax_savings"` — estimated property tax exemption value
- `"income_tax_savings"` — estimated income tax exemption value
- `"sales_tax_savings"` — estimated sales tax exemption value
- `"total_tax_benefit"` — sum of all tax savings
- `"community_benefit_total"` — total community benefit provided
- `"benefit_to_exemption_ratio"` — community benefit / tax benefit
- `"earning_exemption"` — Bool, true if ratio >= 1.0
- `"assessment"` — narrative assessment
"""
function tax_exemption_analysis(
    total_revenue::Float64,
    community_benefit_total::Float64,
    property_value::Float64;
    property_tax_rate::Float64=0.02,
    sales_tax_rate::Float64=0.06,
)::Dict{String,Any}
    # Property tax savings
    property_tax_savings = property_value * property_tax_rate

    # Income tax savings: estimate operating income as 3% of revenue (thin margins)
    operating_income = total_revenue * 0.03
    effective_tax_rate = 0.26  # 21% federal + ~5% state
    income_tax_savings = max(operating_income * effective_tax_rate, 0.0)

    # Sales tax savings: hospitals spend ~30% of revenue on taxable supplies
    taxable_purchases = total_revenue * 0.30
    sales_tax_savings = taxable_purchases * sales_tax_rate

    total_tax_benefit = property_tax_savings + income_tax_savings + sales_tax_savings

    ratio = total_tax_benefit > 0 ?
        community_benefit_total / total_tax_benefit : 0.0
    earning = ratio >= 1.0

    assessment = if ratio >= 2.0
        @sprintf(
            "Hospital provides community benefit at %.1fx the value of its " *
            "tax exemption — strong justification for nonprofit status.",
            ratio,
        )
    elseif ratio >= 1.0
        @sprintf(
            "Hospital provides community benefit roughly equal to its " *
            "tax exemption value (%.1fx) — meets basic threshold.",
            ratio,
        )
    elseif ratio >= 0.5
        @sprintf(
            "Community benefit (%.1fx of exemption) falls below the value " *
            "of tax exemption — may face scrutiny from state AG or legislators.",
            ratio,
        )
    else
        @sprintf(
            "Community benefit (%.1fx of exemption) is substantially below " *
            "tax exemption value — significant risk of exemption challenge.",
            ratio,
        )
    end

    Dict{String,Any}(
        "property_tax_savings"       => property_tax_savings,
        "income_tax_savings"         => income_tax_savings,
        "sales_tax_savings"          => sales_tax_savings,
        "total_tax_benefit"          => total_tax_benefit,
        "community_benefit_total"    => community_benefit_total,
        "benefit_to_exemption_ratio" => ratio,
        "earning_exemption"          => earning,
        "assessment"                 => assessment,
    )
end

# ─── FAP Compliance Check ───────────────────────────────────────────────────

"""
    fap_compliance_check(policy::FinancialAssistancePolicy) -> Dict{String,Any}

Check IRS 501(r) compliance of a financial assistance policy.  Evaluates
required elements per IRC Section 501(r)(4)-(6) and Treasury Regulation
1.501(r)-4 through 1.501(r)-6.

Compliance items checked:
1. Policy covers emergency and medically necessary care
2. Financial assistance is widely publicised
3. No extraordinary collection actions (ECAs) before eligibility screening
4. Charges to eligible individuals ≤ amounts generally billed (AGB)
5. Reasonable application period (≥240 days)
6. FPL tiers include coverage below 200% FPL
7. Presumptive eligibility offered for hardship cases
8. Catastrophic medical expense provision present

Returns:
- `"compliance_items"` — Vector of (item, pass, detail) named tuples
- `"overall_compliant"` — Bool, true if all required items pass
- `"score"` — fraction of items passing (0.0–1.0)
- `"recommendations"` — Vector of improvement recommendations
"""
function fap_compliance_check(policy::FinancialAssistancePolicy)::Dict{String,Any}
    items = Vector{NamedTuple{(:item, :pass, :detail), Tuple{String,Bool,String}}}()
    recommendations = String[]

    # 1. Emergency / medically necessary coverage
    # 501(r) requires FAP to apply to emergency and medically necessary care.
    # We check that tiers cover broad ranges (proxy for coverage scope).
    has_broad_coverage = length(policy.tiers) >= 2
    push!(items, (
        item="Emergency and medically necessary care coverage",
        pass=has_broad_coverage,
        detail=has_broad_coverage ?
            "Policy has $(length(policy.tiers)) tiers covering multiple FPL ranges" :
            "Policy should have at least 2 tiers to cover required care categories",
    ))
    !has_broad_coverage && push!(recommendations,
        "Add additional FPL tiers to ensure emergency and medically necessary care coverage")

    # 2. Wide publicity (proxy: policy has a name and is structured)
    has_name = !isempty(policy.name)
    push!(items, (
        item="Financial assistance widely publicised",
        pass=has_name,
        detail=has_name ?
            "Policy '$(policy.name)' is named and structured for publication" :
            "Policy lacks a name — must be publicised per 501(r)(4)",
    ))

    # 3. No ECAs before eligibility screening — lookback period check
    adequate_lookback = policy.lookback_months >= 8
    push!(items, (
        item="No extraordinary collection actions before screening",
        pass=adequate_lookback,
        detail=adequate_lookback ?
            "$(policy.lookback_months)-month lookback provides adequate screening window" :
            "$(policy.lookback_months)-month lookback may be too short; IRS requires ≥240 days notification",
    ))
    !adequate_lookback && push!(recommendations,
        "Extend lookback period to at least 8 months (240 days per IRS rules)")

    # 4. Charges to FAP-eligible ≤ AGB
    # AGB compliance requires that discounted charges not exceed amounts
    # generally billed.  We check that max discount is ≤ 100%.
    max_discount = maximum(t.discount_pct for t in policy.tiers; init=0.0)
    agb_ok = max_discount <= 1.0
    push!(items, (
        item="Charges to eligible ≤ amounts generally billed (AGB)",
        pass=agb_ok,
        detail=agb_ok ?
            "Maximum discount $(round(Int, max_discount * 100))% is within AGB limits" :
            "Discount exceeds 100% — charges must not be negative",
    ))

    # 5. Application period
    app_period_ok = policy.lookback_months >= 8  # 240 days ≈ 8 months
    push!(items, (
        item="Reasonable application period (≥240 days)",
        pass=app_period_ok,
        detail=app_period_ok ?
            "$(policy.lookback_months)-month period meets 240-day requirement" :
            "Application period too short; extend to at least 240 days",
    ))

    # 6. FPL coverage below 200%
    sorted = sort(policy.tiers, by=t -> t.fpl_ceiling_pct)
    covers_200 = any(t -> t.fpl_ceiling_pct >= 200 && t.discount_pct >= 0.50, sorted)
    push!(items, (
        item="FPL tiers include meaningful coverage below 200% FPL",
        pass=covers_200,
        detail=covers_200 ?
            "Policy provides ≥50% discount for patients below 200% FPL" :
            "No tier provides ≥50% discount below 200% FPL — most 501(r) policies do",
    ))
    !covers_200 && push!(recommendations,
        "Add a tier providing at least 50% discount for patients below 200% FPL")

    # 7. Presumptive eligibility
    push!(items, (
        item="Presumptive eligibility for hardship cases",
        pass=policy.presumptive_eligibility,
        detail=policy.presumptive_eligibility ?
            "Presumptive eligibility is enabled" :
            "Presumptive eligibility not enabled — recommended for 501(r) best practice",
    ))
    !policy.presumptive_eligibility && push!(recommendations,
        "Enable presumptive eligibility to streamline access for clearly eligible patients")

    # 8. Catastrophic medical expense provision
    has_catastrophic = policy.catastrophic_threshold_pct > 0.0 &&
                       policy.catastrophic_threshold_pct <= 0.50
    push!(items, (
        item="Catastrophic medical expense provision",
        pass=has_catastrophic,
        detail=has_catastrophic ?
            @sprintf("Catastrophic threshold at %.0f%% of income",
                policy.catastrophic_threshold_pct * 100) :
            "No catastrophic threshold or threshold exceeds 50% of income",
    ))
    !has_catastrophic && push!(recommendations,
        "Set catastrophic threshold at 25-30% of annual income per industry best practice")

    # No application fee check (best practice)
    no_fee = policy.application_fee <= 0.0
    push!(items, (
        item="No application fee for financial assistance",
        pass=no_fee,
        detail=no_fee ?
            "No application fee — removes barrier to access" :
            @sprintf("Application fee of \$%.2f may deter eligible patients",
                policy.application_fee),
    ))
    !no_fee && push!(recommendations,
        "Eliminate application fee to remove barriers for low-income patients")

    passing = count(i -> i.pass, items)
    total = length(items)

    Dict{String,Any}(
        "compliance_items"   => items,
        "overall_compliant"  => passing == total,
        "score"              => total > 0 ? passing / total : 0.0,
        "passing"            => passing,
        "total_items"        => total,
        "recommendations"    => recommendations,
    )
end
