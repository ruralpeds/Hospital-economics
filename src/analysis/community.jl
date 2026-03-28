# ============================================================================
# Community Economic Impact Modeling
# ============================================================================
#
# Estimates the direct, indirect, and induced economic effects of a rural
# hospital on its surrounding community, following BEA RIMS II methodology
# for economic multipliers.  Also models the multi-year devastation that
# accompanies a hospital closure.
# ============================================================================

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

"""
    CommunityImpactParams

Input parameters describing a hospital's economic footprint in its community.

# Fields
- `annual_payroll::Float64`: total annual payroll (salaries + benefits).
- `total_employees::Int`: headcount (FTE equivalent).
- `local_purchasing::Float64`: annual local purchasing of goods and services.
- `economic_multiplier::Float64`: BEA RIMS II regional multiplier (default 1.6 for rural areas).
- `tax_rate::Float64`: effective local/property tax rate on hospital-related economic activity.
- `property_value_impact::Float64`: estimated annual property-value decline rate per year after closure.
- `avg_home_value::Float64`: average home value in the service area.
- `homes_in_service_area::Int`: approximate number of residential units in the primary service area.

# Example
```julia
params = CommunityImpactParams(
    annual_payroll      = 12_000_000.0,
    total_employees     = 250,
    local_purchasing    = 3_000_000.0,
    economic_multiplier = 1.6,
)
```
"""
@kwdef struct CommunityImpactParams
    annual_payroll::Float64
    total_employees::Int
    local_purchasing::Float64
    economic_multiplier::Float64 = 1.6      # BEA RIMS II rural average
    tax_rate::Float64 = 0.02
    property_value_impact::Float64 = 0.05   # % decline per year after closure
    avg_home_value::Float64 = 150_000.0
    homes_in_service_area::Int = 3000
end

"""
    CommunityImpactResult

Quantified economic impact of a hospital on its community, including
a composite *closure devastation score* (0-100).

# Fields
- `direct_economic_impact::Float64`: payroll + local purchasing.
- `indirect_economic_impact::Float64`: multiplier-driven additional impact.
- `total_economic_impact::Float64`: direct + indirect.
- `jobs_supported::Int`: total jobs sustained (direct + induced).
- `tax_revenue_impact::Float64`: annual local tax revenue attributable to the hospital.
- `property_value_loss::Float64`: cumulative property-value loss over one year of closure.
- `closure_devastation_score::Float64`: composite score from 0 (minimal) to 100 (catastrophic).
"""
@kwdef struct CommunityImpactResult
    direct_economic_impact::Float64
    indirect_economic_impact::Float64
    total_economic_impact::Float64
    jobs_supported::Int
    tax_revenue_impact::Float64
    property_value_loss::Float64
    closure_devastation_score::Float64   # 0-100
end

function Base.show(io::IO, r::CommunityImpactResult)
    print(io, "CommunityImpactResult(total=\$$(round(Int, r.total_economic_impact)), ",
          "jobs=$(r.jobs_supported), devastation=$(round(r.closure_devastation_score, digits=1)))")
end

# ---------------------------------------------------------------------------
# Core calculation
# ---------------------------------------------------------------------------

"""
    calculate_community_impact(params::CommunityImpactParams) -> CommunityImpactResult

Compute the full community economic impact of a hospital.

The model applies the BEA RIMS II multiplier to estimate induced economic
activity, then scores the closure devastation potential on a 0-100 scale
combining payroll dependency, employment density, property value exposure,
and tax base contribution.

# Example
```julia
params = CommunityImpactParams(
    annual_payroll = 12_000_000.0,
    total_employees = 250,
    local_purchasing = 3_000_000.0,
)
result = calculate_community_impact(params)
println("Total impact: \$", round(Int, result.total_economic_impact))
println("Devastation score: ", result.closure_devastation_score)
```
"""
function calculate_community_impact(params::CommunityImpactParams)::CommunityImpactResult
    # Direct impact = payroll + local purchasing
    direct = params.annual_payroll + params.local_purchasing

    # Indirect / induced impact via multiplier
    total = direct * params.economic_multiplier
    indirect = total - direct

    # Jobs supported: direct employees + induced jobs
    # Rule of thumb: each dollar of indirect impact supports jobs at
    # roughly the same ratio as direct payroll → employees
    payroll_per_employee = params.annual_payroll / max(params.total_employees, 1)
    induced_jobs = payroll_per_employee > 0 ? round(Int, indirect / payroll_per_employee) : 0
    jobs_supported = params.total_employees + induced_jobs

    # Tax revenue impact
    tax_revenue = total * params.tax_rate

    # First-year property value loss from closure
    property_value_loss = params.avg_home_value * params.property_value_impact * params.homes_in_service_area

    # --- Closure Devastation Score (0-100) ---
    # Weighted composite of four sub-scores, each 0-25:
    #
    # 1. Economic dependency (payroll as fraction of estimated community income)
    #    Assume median household income of $50k and ~2.5 persons/household
    estimated_community_income = (params.homes_in_service_area * 50_000.0)
    econ_dependency = clamp(direct / max(estimated_community_income, 1.0), 0.0, 1.0)
    econ_score = econ_dependency * 25.0

    # 2. Employment concentration
    #    Compare hospital employees to approximate working-age population
    est_working_pop = params.homes_in_service_area * 1.2  # rough workers/household
    emp_concentration = clamp(params.total_employees / max(est_working_pop, 1.0), 0.0, 1.0)
    emp_score = emp_concentration * 25.0

    # 3. Property value exposure
    total_property_base = params.avg_home_value * params.homes_in_service_area
    prop_exposure = clamp(property_value_loss / max(total_property_base, 1.0), 0.0, 1.0)
    prop_score = prop_exposure * 25.0

    # 4. Tax base dependency
    #    Compare hospital-related tax revenue to approximate total property tax base
    est_total_tax = total_property_base * params.tax_rate
    tax_dependency = clamp(tax_revenue / max(est_total_tax, 1.0), 0.0, 1.0)
    tax_score = tax_dependency * 25.0

    devastation = econ_score + emp_score + prop_score + tax_score

    return CommunityImpactResult(
        direct_economic_impact  = direct,
        indirect_economic_impact = indirect,
        total_economic_impact   = total,
        jobs_supported          = jobs_supported,
        tax_revenue_impact      = tax_revenue,
        property_value_loss     = property_value_loss,
        closure_devastation_score = round(devastation; digits=1),
    )
end

# ---------------------------------------------------------------------------
# Multi-year closure projection
# ---------------------------------------------------------------------------

"""
    closure_impact_projection(params::CommunityImpactParams; years::Int=5) -> Vector{NamedTuple}

Project year-by-year community impact of a hospital closure over the given
time horizon.  Each year compounds the property-value decline and models
gradual economic recovery as some (but not all) displaced spending
finds alternative outlets.

Returns a vector of `NamedTuple`s with fields:
- `year::Int`
- `cumulative_property_loss::Float64`
- `annual_economic_loss::Float64`
- `cumulative_economic_loss::Float64`
- `jobs_lost::Int`
- `tax_revenue_loss::Float64`

# Example
```julia
params = CommunityImpactParams(annual_payroll=12e6, total_employees=250, local_purchasing=3e6)
projection = closure_impact_projection(params; years=5)
for row in projection
    println("Year \$(row.year): cumulative property loss = \$\$(round(Int, row.cumulative_property_loss))")
end
```
"""
function closure_impact_projection(params::CommunityImpactParams; years::Int=5)
    years >= 1 || error("years must be >= 1, got $years")

    base = calculate_community_impact(params)

    # Assumptions for multi-year modelling:
    #   - Economic recovery factor: community recovers ~10% of lost economic
    #     activity per year as spending is redirected.
    #   - Property values compound decline for the first 3 years, then stabilise.
    #   - Job losses partially recover as some workers find local alternatives.
    recovery_rate = 0.10
    property_decline_rate = params.property_value_impact
    home_base = params.avg_home_value * params.homes_in_service_area

    results = NamedTuple[]
    cumulative_econ_loss = 0.0
    cumulative_prop_loss = 0.0

    for yr in 1:years
        # Economic loss decays with partial recovery
        remaining_fraction = max(1.0 - recovery_rate * (yr - 1), 0.2)  # floor at 20%
        annual_econ_loss = base.total_economic_impact * remaining_fraction
        cumulative_econ_loss += annual_econ_loss

        # Property value decline compounds for first 3 years, then plateaus
        if yr <= 3
            annual_prop_decline = home_base * property_decline_rate * (1.0 - property_decline_rate) ^ (yr - 1)
        else
            annual_prop_decline = 0.0  # plateau
        end
        cumulative_prop_loss += annual_prop_decline

        # Job losses partially recover
        jobs_lost = max(round(Int, base.jobs_supported * remaining_fraction), 0)

        # Tax revenue loss
        tax_loss = annual_econ_loss * params.tax_rate + annual_prop_decline * params.tax_rate

        push!(results, (
            year                     = yr,
            cumulative_property_loss = cumulative_prop_loss,
            annual_economic_loss     = annual_econ_loss,
            cumulative_economic_loss = cumulative_econ_loss,
            jobs_lost                = jobs_lost,
            tax_revenue_loss         = tax_loss,
        ))
    end

    return results
end
