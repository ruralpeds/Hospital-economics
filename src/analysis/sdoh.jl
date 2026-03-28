# ============================================================================
# Social Determinants of Health Integration
# ============================================================================
#
# Models how social determinants of health (SDOH) affect hospital utilization,
# costs, and financial performance.  Uses CDC Social Vulnerability Index (SVI),
# Area Deprivation Index (ADI), and related community-level indicators.
# ============================================================================

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

"""
    SDOHProfile

Community-level social determinants of health profile describing the
hospital's primary service area.

# Fields
- `svi_score::Float64`: CDC Social Vulnerability Index (0-1, higher = more vulnerable).
- `adi_national_rank::Int`: Area Deprivation Index national percentile (1-100).
- `food_desert_pct::Float64`: fraction of population living in a food desert.
- `broadband_pct::Float64`: fraction of households with broadband internet.
- `transportation_desert::Bool`: true if area lacks adequate public transit.
- `health_literacy_score::Float64`: population health literacy (0-1, higher = better).
- `uninsured_rate::Float64`: fraction of population without health insurance.
- `poverty_rate::Float64`: fraction of population below the federal poverty line.
- `median_household_income::Float64`: median household income in the service area.

# Example
```julia
profile = SDOHProfile(svi_score=0.82, adi_national_rank=88, food_desert_pct=0.25)
```
"""
@kwdef struct SDOHProfile
    svi_score::Float64               = 0.5
    adi_national_rank::Int           = 50
    food_desert_pct::Float64         = 0.0
    broadband_pct::Float64           = 0.80
    transportation_desert::Bool      = false
    health_literacy_score::Float64   = 0.5
    uninsured_rate::Float64          = 0.10
    poverty_rate::Float64            = 0.15
    median_household_income::Float64 = 50_000.0
end

"""
    SDOHAdjustment

Multipliers and scores summarising the financial and operational impact
of social determinants on hospital performance.

# Fields
- `volume_adjustment::Float64`: multiplier on expected patient volume.
- `cost_per_case_adjustment::Float64`: multiplier on average cost per case.
- `ed_utilization_multiplier::Float64`: multiplier on ED visit rate.
- `readmission_risk_multiplier::Float64`: multiplier on 30-day readmission risk.
- `telehealth_viability_score::Float64`: 0-1 score for telehealth feasibility.
- `composite_risk_score::Float64`: weighted composite (0-1, higher = riskier).
"""
@kwdef struct SDOHAdjustment
    volume_adjustment::Float64           = 1.0
    cost_per_case_adjustment::Float64    = 1.0
    ed_utilization_multiplier::Float64   = 1.0
    readmission_risk_multiplier::Float64 = 1.0
    telehealth_viability_score::Float64  = 1.0
    composite_risk_score::Float64        = 0.0
end

function Base.show(io::IO, a::SDOHAdjustment)
    print(io, "SDOHAdjustment(composite=", round(a.composite_risk_score, digits=3),
          ", ED×", round(a.ed_utilization_multiplier, digits=2), ")")
end

# ---------------------------------------------------------------------------
# Core calculations
# ---------------------------------------------------------------------------

"""
    calculate_sdoh_adjustments(profile::SDOHProfile) -> SDOHAdjustment

Derive operational adjustment multipliers from a community SDOH profile.

Higher SVI / ADI increases cost and ED utilisation; low broadband reduces
telehealth viability; food desert prevalence increases chronic disease
burden; transportation deserts increase ED reliance.
"""
function calculate_sdoh_adjustments(profile::SDOHProfile)::SDOHAdjustment
    # Normalise ADI to 0-1
    adi_norm = clamp(profile.adi_national_rank / 100.0, 0.0, 1.0)

    # Volume adjustment: high deprivation slightly reduces elective volume
    # but increases acute volume — net effect modest
    volume_adj = 1.0 - 0.05 * profile.svi_score + 0.03 * profile.uninsured_rate

    # Cost per case: poverty and low health literacy increase complexity
    cost_adj = 1.0 + 0.15 * adi_norm + 0.10 * profile.food_desert_pct +
               0.08 * (1.0 - profile.health_literacy_score)

    # ED utilisation: transportation deserts and lack of primary care access
    ed_mult = 1.0 + 0.20 * profile.svi_score + 0.15 * profile.uninsured_rate
    if profile.transportation_desert
        ed_mult += 0.15
    end
    ed_mult += 0.10 * profile.food_desert_pct

    # Readmission risk: driven by poverty, food access, health literacy
    readmit_mult = 1.0 + 0.18 * profile.poverty_rate +
                   0.12 * profile.food_desert_pct +
                   0.10 * (1.0 - profile.health_literacy_score)

    # Telehealth viability: primarily broadband, secondarily literacy
    telehealth = clamp(profile.broadband_pct * 0.7 +
                       profile.health_literacy_score * 0.3, 0.0, 1.0)

    # Composite risk score: weighted average of key vulnerability indicators
    composite = clamp(
        0.30 * profile.svi_score +
        0.20 * adi_norm +
        0.15 * profile.uninsured_rate / 0.30 +   # normalise vs high-end rate
        0.15 * profile.poverty_rate / 0.40 +
        0.10 * profile.food_desert_pct +
        0.10 * (profile.transportation_desert ? 1.0 : 0.0),
        0.0, 1.0,
    )

    return SDOHAdjustment(
        volume_adjustment           = round(volume_adj; digits=4),
        cost_per_case_adjustment    = round(cost_adj; digits=4),
        ed_utilization_multiplier   = round(ed_mult; digits=4),
        readmission_risk_multiplier = round(readmit_mult; digits=4),
        telehealth_viability_score  = round(telehealth; digits=4),
        composite_risk_score        = round(composite; digits=4),
    )
end

"""
    sdoh_financial_impact(profile::SDOHProfile, base_revenue::Float64,
                          base_expenses::Float64) -> NamedTuple

Estimate the dollar impact of SDOH factors on a hospital's revenue and costs.

Returns a `NamedTuple` with fields `adjusted_revenue`, `adjusted_expenses`,
`revenue_impact`, `expense_impact`, and `net_margin_impact`.
"""
function sdoh_financial_impact(profile::SDOHProfile, base_revenue::Float64,
                               base_expenses::Float64)::NamedTuple
    adj = calculate_sdoh_adjustments(profile)

    # Revenue affected by volume changes and uncompensated care
    uncompensated_care_drag = base_revenue * profile.uninsured_rate * 0.40
    adjusted_revenue = base_revenue * adj.volume_adjustment - uncompensated_care_drag

    # Expenses affected by cost-per-case and ED over-utilisation
    ed_cost_premium = base_expenses * 0.10 * (adj.ed_utilization_multiplier - 1.0)
    readmit_cost    = base_expenses * 0.03 * (adj.readmission_risk_multiplier - 1.0)
    adjusted_expenses = base_expenses * adj.cost_per_case_adjustment + ed_cost_premium + readmit_cost

    return (
        adjusted_revenue  = round(adjusted_revenue; digits=2),
        adjusted_expenses = round(adjusted_expenses; digits=2),
        revenue_impact    = round(adjusted_revenue - base_revenue; digits=2),
        expense_impact    = round(adjusted_expenses - base_expenses; digits=2),
        net_margin_impact = round((adjusted_revenue - adjusted_expenses) -
                                  (base_revenue - base_expenses); digits=2),
    )
end

"""
    sdoh_risk_tier(profile::SDOHProfile) -> Symbol

Classify a community into a risk tier based on composite SDOH scoring.

Returns one of `:low`, `:moderate`, `:high`, or `:critical`.
"""
function sdoh_risk_tier(profile::SDOHProfile)::Symbol
    adj = calculate_sdoh_adjustments(profile)
    score = adj.composite_risk_score

    if score < 0.25
        return :low
    elseif score < 0.50
        return :moderate
    elseif score < 0.75
        return :high
    else
        return :critical
    end
end
