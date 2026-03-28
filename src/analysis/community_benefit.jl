# ============================================================================
# IRS Schedule H Community Benefit Valuation
# ============================================================================
#
# Calculates total community benefit for tax-exempt hospitals following
# IRS Form 990 Schedule H methodology.  Compares community benefit
# against the estimated value of tax exemption to assess whether the
# hospital meets the AHA standard for community investment.
# ============================================================================

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

"""
    CommunityBenefitData

Input data for IRS Schedule H community benefit calculation, following
the standard reporting categories.

# Fields
- `charity_care_charges::Float64`: charges for charity care provided.
- `charity_care_costs::Float64`: cost of charity care (at cost-to-charge ratio).
- `medicaid_shortfall::Float64`: gap between Medicaid cost and reimbursement.
- `community_health_services::Float64`: cost of community health improvement.
- `health_professions_education::Float64`: cost of health professions education.
- `subsidized_services_cost::Float64`: cost of subsidised health services.
- `research::Float64`: cost of medical research.
- `cash_contributions::Float64`: cash and in-kind contributions to community.
- `community_building::Float64`: community-building activities cost.
- `total_expenses::Float64`: total hospital operating expenses.

# Example
```julia
data = CommunityBenefitData(
    charity_care_costs          = 2_500_000.0,
    medicaid_shortfall          = 4_000_000.0,
    community_health_services   = 800_000.0,
    total_expenses              = 80_000_000.0,
)
```
"""
@kwdef struct CommunityBenefitData
    charity_care_charges::Float64          = 0.0
    charity_care_costs::Float64            = 0.0
    medicaid_shortfall::Float64            = 0.0
    community_health_services::Float64     = 0.0
    health_professions_education::Float64  = 0.0
    subsidized_services_cost::Float64      = 0.0
    research::Float64                      = 0.0
    cash_contributions::Float64            = 0.0
    community_building::Float64            = 0.0
    total_expenses::Float64
end

"""
    CommunityBenefitResult

Outcome of the community benefit valuation, including comparison
against the estimated tax exemption value.

# Fields
- `total_community_benefit::Float64`: sum of all benefit categories.
- `benefit_as_pct_expenses::Float64`: total benefit / total expenses.
- `estimated_tax_exemption_value::Float64`: estimated annual tax savings.
- `net_community_investment::Float64`: benefit minus tax exemption value.
- `category_breakdown::Vector{NamedTuple}`: per-category detail.
- `meets_aha_standard::Bool`: true if benefit exceeds tax exemption.
"""
@kwdef struct CommunityBenefitResult
    total_community_benefit::Float64
    benefit_as_pct_expenses::Float64
    estimated_tax_exemption_value::Float64
    net_community_investment::Float64
    category_breakdown::Vector{NamedTuple}
    meets_aha_standard::Bool
end

function Base.show(io::IO, r::CommunityBenefitResult)
    pct = round(r.benefit_as_pct_expenses * 100; digits=2)
    print(io, "CommunityBenefitResult(benefit=\$", round(Int, r.total_community_benefit),
          " (", pct, "%), meets_AHA=", r.meets_aha_standard, ")")
end

# ---------------------------------------------------------------------------
# Core calculation
# ---------------------------------------------------------------------------

"""
    calculate_community_benefit(data; tax_rate=0.21, property_tax_rate=0.015,
                                assessed_value=0.0) -> CommunityBenefitResult

Compute total community benefit following IRS Schedule H categories and
estimate the value of tax exemption (federal corporate income tax +
local property tax savings).

The AHA standard is met when total community benefit exceeds the
estimated tax exemption value.

# Example
```julia
data = CommunityBenefitData(
    charity_care_costs = 2_500_000.0,
    medicaid_shortfall = 4_000_000.0,
    total_expenses     = 80_000_000.0,
)
result = calculate_community_benefit(data; assessed_value=25_000_000.0)
println("Meets AHA standard: ", result.meets_aha_standard)
```
"""
function calculate_community_benefit(data::CommunityBenefitData;
                                     tax_rate::Float64=0.21,
                                     property_tax_rate::Float64=0.015,
                                     assessed_value::Float64=0.0)::CommunityBenefitResult
    # Build category breakdown
    categories = [
        (category="Charity Care (at cost)",          amount=data.charity_care_costs),
        (category="Medicaid Shortfall",              amount=data.medicaid_shortfall),
        (category="Community Health Services",       amount=data.community_health_services),
        (category="Health Professions Education",    amount=data.health_professions_education),
        (category="Subsidized Services",             amount=data.subsidized_services_cost),
        (category="Research",                        amount=data.research),
        (category="Cash & In-Kind Contributions",    amount=data.cash_contributions),
        (category="Community Building",              amount=data.community_building),
    ]

    total_benefit = sum(c.amount for c in categories)
    benefit_pct = data.total_expenses > 0 ? total_benefit / data.total_expenses : 0.0

    # Estimate tax exemption value
    # 1. Federal corporate income tax on estimated taxable income
    #    Proxy: assume ~3% operating margin on total expenses as taxable income
    estimated_taxable_income = data.total_expenses * 0.03
    corporate_tax_savings = estimated_taxable_income * tax_rate

    # 2. Property tax savings
    property_tax_savings = assessed_value * property_tax_rate

    # 3. State/local sales tax exemption (rough estimate: 1% of expenses)
    sales_tax_savings = data.total_expenses * 0.01

    tax_exemption_value = corporate_tax_savings + property_tax_savings + sales_tax_savings

    net_investment = total_benefit - tax_exemption_value
    meets_aha = total_benefit >= tax_exemption_value

    return CommunityBenefitResult(
        total_community_benefit       = round(total_benefit; digits=2),
        benefit_as_pct_expenses       = round(benefit_pct; digits=4),
        estimated_tax_exemption_value = round(tax_exemption_value; digits=2),
        net_community_investment      = round(net_investment; digits=2),
        category_breakdown            = categories,
        meets_aha_standard            = meets_aha,
    )
end

# ---------------------------------------------------------------------------
# Benchmarking
# ---------------------------------------------------------------------------

"""
    community_benefit_comparison(hospital_data; national_median_pct=0.076) -> NamedTuple

Compare a hospital's community benefit percentage against the national
median (default 7.6% per AHA data).

Returns a `NamedTuple` with fields `hospital_pct`, `national_median_pct`,
`difference_pct`, `percentile_estimate`, and `rating`.
"""
function community_benefit_comparison(hospital_data::CommunityBenefitData;
                                      national_median_pct::Float64=0.076)::NamedTuple
    result = calculate_community_benefit(hospital_data)
    hospital_pct = result.benefit_as_pct_expenses

    diff = hospital_pct - national_median_pct

    # Rough percentile estimate based on national distribution
    # Assume approximately normal with mean=0.076, sd=0.04
    z = (hospital_pct - national_median_pct) / 0.04
    # Simple sigmoid approximation for CDF
    percentile = clamp(round(Int, 50.0 + 50.0 * tanh(z * 0.8)), 1, 99)

    rating = if hospital_pct >= national_median_pct * 1.5
        :exemplary
    elseif hospital_pct >= national_median_pct
        :above_average
    elseif hospital_pct >= national_median_pct * 0.5
        :below_average
    else
        :needs_improvement
    end

    return (
        hospital_pct       = round(hospital_pct; digits=4),
        national_median_pct = national_median_pct,
        difference_pct     = round(diff; digits=4),
        percentile_estimate = percentile,
        rating             = rating,
    )
end
