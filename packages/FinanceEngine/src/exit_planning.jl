"""
    exit_planning.jl — Hospital Exit / Closure Transition Planning (MBA Gap D-02)

Comprehensive transition planning framework for rural hospital exit scenarios,
including full closure, REH conversion, merger/acquisition, selective service
line reduction, freestanding ED conversion, and telehealth hub transition.

The module provides:
1. **Viability assessment** — multi-factor scoring of current financial health.
2. **Community impact modelling** — patient migration, job loss, economic
   ripple effects, maternal care desert and trauma access analysis.
3. **Asset liquidation analysis** — wind-down cost estimation including
   severance, WARN Act compliance, contract penalties, and environmental
   remediation.
4. **REH conversion analysis** — detailed Rural Emergency Hospital conversion
   revenue/cost model with CMS eligibility check and 5-year NPV.
5. **Merger/acquisition analysis** — enterprise valuation, synergy ID,
   integration costs, and regulatory review timeline.
6. **Service line reduction** — selective closure modelling with per-line
   revenue, cost, staff, and community impact.
7. **Regulatory requirements** — comprehensive checklists by exit type
   (CMS notification, state licensure, WARN Act, 340B, EMTALA, Hill-Burton,
   bond covenants, pension/OPEB).
8. **Transition timeline** — month-by-month execution plan.
9. **Patient migration model** — gravity-model-based volume redistribution
   to nearby facilities with capacity constraint analysis.

References:
- CMS Medicare Provider Termination Rules, 42 CFR § 489.52.
- WARN Act, 29 U.S.C. § 2101-2109 (60-day notice for 100+ employees).
- CAA 2021 § 125, REH designation (42 U.S.C. § 1395x(kkk)).
- BEA RIMS II multipliers for healthcare sector (~1.6x).
- Kaufman B et al (2016). Rural hospital closures. Health Affairs.
- Chartis Center for Rural Health (2024). Rural Hospital Closure Tracker.
- Holmes M et al (2020). Financial distress predictors. UNC Sheps Center.
- GAO (2020). Rural Hospital Closures: Affected Residents Had Reduced
  Access to Health Care Services. GAO-21-93.
"""

using Statistics
using Printf

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────

"""Rural healthcare BEA RIMS II economic multiplier (~1.6x direct employment)."""
const BEA_RIMS_II_HEALTHCARE_MULTIPLIER = 1.6

"""Healthcare share of rural employment (Bureau of Labor Statistics)."""
const HEALTHCARE_RURAL_EMPLOYMENT_PCT = 0.125  # 10-15%, use midpoint

"""REH monthly facility payment for FY2026 (CMS-1765-F)."""
const REH_FACILITY_PAYMENT_MONTHLY_FY2026 = 295_135.0

"""REH OPPS payment premium (5% above standard OPPS rates)."""
const REH_OPPS_PREMIUM = 0.05

"""Average OPPS payment per ED visit (CMS OPPS Final Rule FY2026)."""
const AVG_OPPS_PER_ED_VISIT = 185.0

"""Rural hospital revenue multiples for M&A (low / mid / high)."""
const RURAL_REVENUE_MULTIPLE = (low = 0.5, mid = 0.85, high = 1.5)

"""Average EMS transport cost per loaded mile (GAO 2023)."""
const EMS_COST_PER_LOADED_MILE = 32.50

"""Discount rate for NPV calculations (rural hospital WACC)."""
const DEFAULT_WACC = 0.07

# ─────────────────────────────────────────────────────────────────────────────
# Types
# ─────────────────────────────────────────────────────────────────────────────

"""
    HospitalProfile

Comprehensive profile of a rural hospital for exit/transition planning.

# Fields
- `name::String`: Hospital name or identifier.
- `bed_count::Int`: Licensed inpatient bed count.
- `annual_revenue::Float64`: Total annual operating revenue (USD).
- `annual_expenses::Float64`: Total annual operating expenses (USD).
- `total_assets::Float64`: Total assets on balance sheet (USD).
- `total_liabilities::Float64`: Total liabilities (USD).
- `employees::Int`: Total full-time equivalent employees.
- `annual_ed_visits::Int`: Annual emergency department visits.
- `annual_inpatient_days::Int`: Annual inpatient days (not discharges).
- `annual_outpatient_visits::Int`: Annual outpatient visits.
- `service_area_population::Int`: Primary service area population.
- `nearest_hospital_miles::Float64`: Distance to nearest alternative hospital.
- `cah_status::Bool`: Whether hospital holds CAH designation.
"""
@kwdef struct HospitalProfile
    name::String
    bed_count::Int
    annual_revenue::Float64
    annual_expenses::Float64
    total_assets::Float64
    total_liabilities::Float64
    employees::Int
    annual_ed_visits::Int
    annual_inpatient_days::Int
    annual_outpatient_visits::Int
    service_area_population::Int
    nearest_hospital_miles::Float64
    cah_status::Bool
end

"""
    ExitScenario

Defines a specific exit/transition scenario for the hospital.

# Fields
- `scenario_type::Symbol`: One of `:full_closure`, `:reh_conversion`,
  `:merger`, `:service_reduction`, `:freestanding_ed`, `:telehealth_hub`.
- `timeline_months::Int`: Estimated months from decision to completion.
- `estimated_cost::Float64`: Total transition/wind-down costs (USD).
- `estimated_savings::Float64`: Annual savings or proceeds from exit (USD).
"""
@kwdef struct ExitScenario
    scenario_type::Symbol
    timeline_months::Int
    estimated_cost::Float64
    estimated_savings::Float64
end

"""
    CommunityImpactAssessment

Quantified impact of hospital closure or service reduction on the community.

# Fields
- `affected_population::Int`: Total population losing proximate access.
- `travel_time_increase_minutes::Float64`: Mean additional travel to next facility.
- `ed_diversion_volume::Int`: Annual ED visits diverted to other facilities.
- `job_losses::Int`: Direct hospital job losses.
- `economic_multiplier_loss::Float64`: Total economic impact including
  indirect/induced effects (USD, annual).
- `vulnerable_populations_affected::Int`: Elderly, uninsured, Medicaid
  enrollees in service area.
- `maternal_care_desert::Bool`: Whether closure creates an OB desert
  (no OB services within 30 miles).
- `trauma_access_impact::String`: Narrative assessment of trauma access change.
"""
@kwdef struct CommunityImpactAssessment
    affected_population::Int
    travel_time_increase_minutes::Float64
    ed_diversion_volume::Int
    job_losses::Int
    economic_multiplier_loss::Float64
    vulnerable_populations_affected::Int
    maternal_care_desert::Bool
    trauma_access_impact::String
end

"""
    TransitionPlan

Complete transition plan combining scenario, community impact, financials,
timeline, regulatory requirements, and stakeholder actions.

# Fields
- `scenario::ExitScenario`: The chosen exit scenario.
- `community_impact::CommunityImpactAssessment`: Quantified community impact.
- `financial_summary::Dict{String,Float64}`: Key financial metrics and totals.
- `timeline::Vector{Tuple{Int,String}}`: Month-by-month milestones.
- `regulatory_requirements::Vector{String}`: Regulatory compliance checklist.
- `stakeholder_actions::Vector{String}`: Required stakeholder communications
  and actions.
"""
@kwdef struct TransitionPlan
    scenario::ExitScenario
    community_impact::CommunityImpactAssessment
    financial_summary::Dict{String,Float64}
    timeline::Vector{Tuple{Int,String}}
    regulatory_requirements::Vector{String}
    stakeholder_actions::Vector{String}
end

# ─────────────────────────────────────────────────────────────────────────────
# Viability Assessment
# ─────────────────────────────────────────────────────────────────────────────

"""
    assess_viability(profile::HospitalProfile; years::Int=5) -> Dict{String,Any}

Multi-factor viability assessment for a rural hospital.

Evaluates:
- Operating margin and trend
- Days cash on hand (estimated from balance sheet)
- Debt service coverage ratio
- Occupancy rate
- Break-even census

Returns a Dict containing:
- `viability_score::Float64` — composite 1-10 score
- `classification::Symbol` — `:viable`, `:at_risk`, `:critical`, `:non_viable`
- Individual metric scores and narratives

# Example
```julia
p = HospitalProfile(name="Prairie View", bed_count=25, annual_revenue=18e6,
    annual_expenses=19.5e6, total_assets=22e6, total_liabilities=14e6,
    employees=180, annual_ed_visits=4500, annual_inpatient_days=3200,
    annual_outpatient_visits=15000, service_area_population=12000,
    nearest_hospital_miles=35.0, cah_status=true)
v = assess_viability(p)
v["classification"]  # :critical
```
"""
function assess_viability(profile::HospitalProfile; years::Int = 5)::Dict{String,Any}
    result = Dict{String,Any}()

    # Operating margin
    op_margin = (profile.annual_revenue - profile.annual_expenses) / profile.annual_revenue
    result["operating_margin"] = op_margin

    # Score operating margin (0-10 scale)
    margin_score = if op_margin >= 0.04
        10.0
    elseif op_margin >= 0.02
        8.0 + (op_margin - 0.02) / 0.02 * 2.0
    elseif op_margin >= 0.0
        6.0 + op_margin / 0.02 * 2.0
    elseif op_margin >= -0.03
        3.0 + (op_margin + 0.03) / 0.03 * 3.0
    elseif op_margin >= -0.08
        1.0 + (op_margin + 0.08) / 0.05 * 2.0
    else
        max(0.0, 1.0 + (op_margin + 0.08) / 0.10 * 1.0)
    end
    result["margin_score"] = margin_score

    # Days cash on hand (estimate: unrestricted cash ≈ 15% of assets minus liabilities)
    net_assets = profile.total_assets - profile.total_liabilities
    estimated_cash = max(0.0, net_assets * 0.30)  # rough: 30% of net assets is liquid
    daily_expenses = profile.annual_expenses / 365.0
    days_cash = estimated_cash / daily_expenses
    result["days_cash_on_hand"] = days_cash

    cash_score = if days_cash >= 180.0
        10.0
    elseif days_cash >= 90.0
        7.0 + (days_cash - 90.0) / 90.0 * 3.0
    elseif days_cash >= 45.0
        4.0 + (days_cash - 45.0) / 45.0 * 3.0
    elseif days_cash >= 15.0
        1.0 + (days_cash - 15.0) / 30.0 * 3.0
    else
        max(0.0, days_cash / 15.0)
    end
    result["cash_score"] = cash_score

    # Debt service coverage ratio (estimate annual debt service as 8% of liabilities)
    annual_debt_service = profile.total_liabilities * 0.08
    net_operating_income = profile.annual_revenue - profile.annual_expenses
    depreciation_estimate = profile.total_assets * 0.04  # ~4% of assets
    ebitda = net_operating_income + depreciation_estimate
    dscr = annual_debt_service > 0 ? ebitda / annual_debt_service : 99.0
    result["debt_service_coverage"] = dscr

    dscr_score = if dscr >= 3.0
        10.0
    elseif dscr >= 2.0
        8.0 + (dscr - 2.0) * 2.0
    elseif dscr >= 1.25
        5.0 + (dscr - 1.25) / 0.75 * 3.0
    elseif dscr >= 1.0
        3.0 + (dscr - 1.0) / 0.25 * 2.0
    elseif dscr >= 0.5
        1.0 + (dscr - 0.5) / 0.5 * 2.0
    else
        max(0.0, dscr / 0.5)
    end
    result["dscr_score"] = dscr_score

    # Occupancy rate
    available_days = profile.bed_count * 365
    occupancy = available_days > 0 ? profile.annual_inpatient_days / available_days : 0.0
    result["occupancy_rate"] = occupancy

    # For rural hospitals, very low occupancy is concerning but moderate is fine
    occ_score = if occupancy >= 0.50
        9.0 + min(1.0, (occupancy - 0.50) / 0.20)  # 50-70% is ideal for rural
    elseif occupancy >= 0.35
        7.0 + (occupancy - 0.35) / 0.15 * 2.0
    elseif occupancy >= 0.20
        4.0 + (occupancy - 0.20) / 0.15 * 3.0
    elseif occupancy >= 0.10
        2.0 + (occupancy - 0.10) / 0.10 * 2.0
    else
        max(0.0, occupancy / 0.10 * 2.0)
    end
    result["occupancy_score"] = occ_score

    # Break-even census (daily inpatient census needed to break even)
    # Approximate: revenue per inpatient day
    ip_rev_per_day = profile.annual_inpatient_days > 0 ?
        (profile.annual_revenue * 0.40) / profile.annual_inpatient_days : 0.0
    # Fixed vs variable cost split (typical rural: 75% fixed, 25% variable)
    fixed_costs = profile.annual_expenses * 0.75
    variable_cost_per_day = profile.annual_inpatient_days > 0 ?
        (profile.annual_expenses * 0.25 * 0.40) / profile.annual_inpatient_days : 0.0
    # Outpatient contribution to fixed costs
    op_contribution = profile.annual_revenue * 0.60 - profile.annual_expenses * 0.25 * 0.60
    remaining_fixed = max(0.0, fixed_costs - op_contribution)
    breakeven_census = (ip_rev_per_day - variable_cost_per_day) > 0 ?
        remaining_fixed / ((ip_rev_per_day - variable_cost_per_day) * 365) : Inf
    result["breakeven_census"] = breakeven_census
    result["current_avg_census"] = profile.annual_inpatient_days / 365.0

    # Composite viability score (weighted average)
    composite = (
        margin_score * 0.35 +
        cash_score   * 0.25 +
        dscr_score   * 0.20 +
        occ_score    * 0.20
    )
    result["viability_score"] = round(composite; digits = 1)

    # Classification
    result["classification"] = if composite >= 7.0
        :viable
    elseif composite >= 5.0
        :at_risk
    elseif composite >= 3.0
        :critical
    else
        :non_viable
    end

    # Projected deficit over planning horizon
    annual_deficit = min(0.0, net_operating_income)
    result["projected_cumulative_deficit"] = annual_deficit * years
    result["years_until_insolvency"] = if net_operating_income >= 0
        Inf
    elseif net_assets > 0
        net_assets / abs(net_operating_income)
    else
        0.0
    end

    result
end

# ─────────────────────────────────────────────────────────────────────────────
# Community Impact Assessment
# ─────────────────────────────────────────────────────────────────────────────

"""
    community_impact(profile::HospitalProfile) -> CommunityImpactAssessment

Model the community impact of a full hospital closure.

Estimates:
- Patient migration distances and travel time increases
- ED diversion volume (gravity model)
- Job losses: direct + indirect (BEA RIMS II multiplier ~1.6x)
- Economic impact (healthcare = 10-15% of rural employment)
- Maternal care desert assessment (no OB within 30 miles)
- Trauma access impact

# Example
```julia
impact = community_impact(profile)
impact.job_losses           # 288 (180 direct × 1.6 multiplier)
impact.maternal_care_desert # true
```
"""
function community_impact(profile::HospitalProfile)::CommunityImpactAssessment
    # Affected population: service area population
    affected_pop = profile.service_area_population

    # Travel time increase: rough estimate at 45 mph average rural speed
    additional_miles = profile.nearest_hospital_miles
    travel_time_increase = (additional_miles / 45.0) * 60.0  # minutes

    # ED diversion: all current ED visits must go elsewhere
    ed_diversion = profile.annual_ed_visits

    # Job losses: direct employees + indirect/induced via RIMS II multiplier
    direct_jobs = profile.employees
    total_jobs = round(Int, direct_jobs * BEA_RIMS_II_HEALTHCARE_MULTIPLIER)

    # Economic multiplier loss: annual payroll impact
    # Average rural hospital employee salary ~$52,000 (BLS 2024)
    avg_salary = 52_000.0
    direct_payroll = direct_jobs * avg_salary
    total_economic_loss = direct_payroll * BEA_RIMS_II_HEALTHCARE_MULTIPLIER

    # Vulnerable populations: estimate ~35% of rural service area
    # (elderly 20%, Medicaid 10%, uninsured 5%)
    vulnerable = round(Int, affected_pop * 0.35)

    # Maternal care desert: if nearest hospital > 30 miles, OB access is lost
    # (assumes closing hospital provides OB; most rural hospitals with >15 beds do)
    maternal_desert = profile.nearest_hospital_miles > 30.0 && profile.bed_count >= 15

    # Trauma access impact
    trauma_impact = if profile.nearest_hospital_miles > 45.0
        "CRITICAL: Nearest trauma-capable facility >45 miles. EMS transport times " *
        "will exceed golden hour for major trauma. Expected increase in " *
        "preventable trauma mortality."
    elseif profile.nearest_hospital_miles > 30.0
        "SEVERE: Nearest facility 30-45 miles. EMS transport times will significantly " *
        "increase. Trauma stabilization capacity lost; time-sensitive conditions " *
        "(STEMI, stroke, trauma) outcomes will worsen."
    elseif profile.nearest_hospital_miles > 15.0
        "MODERATE: Nearest facility 15-30 miles. Some increase in transport times. " *
        "ED stabilization capacity lost but trauma access partially maintained."
    else
        "LIMITED: Nearest facility <15 miles. Minimal trauma access impact expected, " *
        "though ED capacity strain at receiving facility is likely."
    end

    CommunityImpactAssessment(
        affected_population           = affected_pop,
        travel_time_increase_minutes  = round(travel_time_increase; digits = 1),
        ed_diversion_volume           = ed_diversion,
        job_losses                    = total_jobs,
        economic_multiplier_loss      = total_economic_loss,
        vulnerable_populations_affected = vulnerable,
        maternal_care_desert          = maternal_desert,
        trauma_access_impact          = trauma_impact,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Asset Liquidation Analysis
# ─────────────────────────────────────────────────────────────────────────────

"""
    asset_liquidation(profile::HospitalProfile;
                      fair_market_value_pct::Float64=0.40) -> Dict{String,Any}

Estimate net liquidation value for a hospital closure scenario.

Components:
- Building/land: FMV × discount factor (rural hospital buildings trade at
  significant discounts due to limited alternative uses)
- Equipment: book value × 20-40% recovery
- Accounts receivable: collectible at 60-80% of face value
- Pharmacy/supplies inventory: estimated at 2-3% of revenue
- Wind-down costs: employee severance, WARN Act compliance, contract
  termination penalties, environmental remediation

Returns Dict with itemised values and net liquidation proceeds.

# Example
```julia
liq = asset_liquidation(profile; fair_market_value_pct=0.35)
liq["net_liquidation_value"]  # after subtracting liabilities and wind-down costs
```
"""
function asset_liquidation(
    profile::HospitalProfile;
    fair_market_value_pct::Float64 = 0.40,
)::Dict{String,Any}
    result = Dict{String,Any}()

    # ── Asset recovery estimates ──

    # Building and land: typically 30-50% of book value for rural hospitals
    # (limited buyer pool, specialized construction, rural location)
    building_land_book = profile.total_assets * 0.55  # ~55% of assets are PP&E
    building_land_value = building_land_book * fair_market_value_pct
    result["building_land_recovery"] = building_land_value

    # Equipment: medical equipment depreciates rapidly; recovery 20-40%
    equipment_book = profile.total_assets * 0.20  # ~20% of assets
    equipment_recovery_rate = 0.30  # midpoint of 20-40%
    equipment_value = equipment_book * equipment_recovery_rate
    result["equipment_recovery"] = equipment_value

    # Accounts receivable: collectible at 60-80% (aged AR, payer disputes)
    ar_book = profile.annual_revenue * 0.12  # ~45 days of revenue
    ar_collection_rate = 0.70  # midpoint of 60-80%
    ar_value = ar_book * ar_collection_rate
    result["accounts_receivable_recovery"] = ar_value

    # Pharmacy and supplies inventory
    inventory = profile.annual_revenue * 0.025  # 2-3% of revenue
    inventory_recovery = inventory * 0.50  # 50% recovery on pharma/supplies
    result["inventory_recovery"] = inventory_recovery

    total_recovery = building_land_value + equipment_value + ar_value + inventory_recovery
    result["gross_asset_recovery"] = total_recovery

    # ── Wind-down costs ──

    # Employee severance: WARN Act requires 60 days notice for 100+ employees
    # Typical severance: 2 weeks per year of service, assume avg 5 years tenure
    avg_salary = 52_000.0
    weeks_severance = 10.0  # 2 weeks × 5 years avg tenure
    severance_total = profile.employees * avg_salary * (weeks_severance / 52.0)
    result["employee_severance"] = severance_total

    # WARN Act compliance costs (legal, notification, admin)
    warn_act_cost = profile.employees >= 100 ? 75_000.0 : 15_000.0
    result["warn_act_compliance"] = warn_act_cost

    # Accrued PTO/benefits payout: ~3% of annual payroll
    pto_payout = profile.employees * avg_salary * 0.03
    result["accrued_benefits_payout"] = pto_payout

    # Contract termination penalties (physician contracts, vendor agreements,
    # IT systems, managed care contracts)
    contract_penalties = profile.annual_revenue * 0.03  # ~3% of revenue
    result["contract_termination_penalties"] = contract_penalties

    # Environmental remediation (underground storage tanks, hazmat, asbestos)
    environmental = 150_000.0  # typical range $75K-$300K for rural hospitals
    result["environmental_remediation"] = environmental

    # Legal, accounting, and consulting fees for wind-down
    professional_fees = 250_000.0
    result["professional_fees"] = professional_fees

    # Patient record transfer and storage (HIPAA requires retention)
    records_cost = 50_000.0 + profile.service_area_population * 2.0
    result["records_transfer_storage"] = records_cost

    total_winddown = (severance_total + warn_act_cost + pto_payout +
                      contract_penalties + environmental + professional_fees +
                      records_cost)
    result["total_winddown_costs"] = total_winddown

    # ── Net liquidation value ──
    result["total_liabilities"] = profile.total_liabilities
    net_value = total_recovery - total_winddown - profile.total_liabilities
    result["net_liquidation_value"] = net_value

    result["liquidation_viable"] = net_value > 0
    result["summary"] = @sprintf(
        "Gross recovery: \$%.1fM | Wind-down costs: \$%.1fM | Liabilities: \$%.1fM | Net: \$%.1fM",
        total_recovery / 1e6, total_winddown / 1e6,
        profile.total_liabilities / 1e6, net_value / 1e6
    )

    result
end

# ─────────────────────────────────────────────────────────────────────────────
# REH Conversion Analysis
# ─────────────────────────────────────────────────────────────────────────────

"""
    reh_conversion_analysis(profile::HospitalProfile) -> Dict{String,Any}

Detailed Rural Emergency Hospital (REH) conversion analysis.

REH designation (CAA 2021 § 125, effective Jan 2023):
- Must be CAH or small rural hospital (<50 beds)
- Must close inpatient beds (observation ≤24h only)
- Must maintain 24/7 ED
- Payment: OPPS × 1.05 + monthly facility payment (\$295,135 FY2026)

Returns:
- CMS eligibility determination
- Revenue model (OPPS premium + facility payment)
- Cost savings from closing inpatient
- Capital requirements for conversion
- Staffing changes
- 5-year NPV of conversion
- Break-even ED visit volume

# Example
```julia
reh = reh_conversion_analysis(profile)
reh["eligible"]           # true
reh["npv_5yr"]            # \$2.1M
reh["breakeven_ed_visits"] # 3,200
```
"""
function reh_conversion_analysis(profile::HospitalProfile)::Dict{String,Any}
    result = Dict{String,Any}()

    # ── CMS eligibility check ──
    eligible = profile.cah_status || profile.bed_count < 50
    result["eligible"] = eligible
    result["eligibility_reason"] = if profile.cah_status
        "Eligible: Critical Access Hospital designation"
    elseif profile.bed_count < 50
        "Eligible: Rural hospital with <50 licensed beds"
    else
        "NOT ELIGIBLE: Must be CAH or rural hospital with <50 beds"
    end

    if !eligible
        result["recommendation"] = :not_eligible
        return result
    end

    # ── Current (pre-conversion) financials ──
    current_revenue = profile.annual_revenue
    current_expenses = profile.annual_expenses
    current_margin = (current_revenue - current_expenses) / current_revenue
    result["current_operating_margin"] = current_margin

    # ── REH revenue model ──
    # ED revenue under OPPS + 5% premium
    reh_ed_revenue = profile.annual_ed_visits * AVG_OPPS_PER_ED_VISIT * (1.0 + REH_OPPS_PREMIUM)
    # Annual facility payment
    facility_payment_annual = REH_FACILITY_PAYMENT_MONTHLY_FY2026 * 12.0
    # Outpatient services retained (clinic, imaging, lab)
    # Estimate outpatient revenue as proportion of total minus inpatient
    inpatient_revenue_share = profile.annual_inpatient_days > 0 ?
        min(0.45, profile.annual_inpatient_days * 1800.0 / profile.annual_revenue) : 0.0
    retained_outpatient_revenue = current_revenue * (1.0 - inpatient_revenue_share) * 0.85
    reh_total_revenue = reh_ed_revenue + facility_payment_annual + retained_outpatient_revenue

    result["reh_ed_revenue"] = reh_ed_revenue
    result["reh_facility_payment"] = facility_payment_annual
    result["reh_retained_outpatient"] = retained_outpatient_revenue
    result["reh_total_revenue"] = reh_total_revenue

    # ── REH cost savings ──
    # Closing inpatient eliminates: nursing staff (variable), dietary, housekeeping
    # (partial), pharmacy (partial), medical records (partial)
    inpatient_cost_share = inpatient_revenue_share * 0.90  # costs roughly track revenue
    variable_inpatient_pct = 0.60  # 60% of inpatient costs are variable
    saved_inpatient_costs = current_expenses * inpatient_cost_share * variable_inpatient_pct

    reh_expenses = current_expenses - saved_inpatient_costs
    reh_margin = reh_total_revenue > 0 ?
        (reh_total_revenue - reh_expenses) / reh_total_revenue : -1.0

    result["saved_inpatient_costs"] = saved_inpatient_costs
    result["reh_operating_expenses"] = reh_expenses
    result["reh_operating_margin"] = reh_margin
    result["annual_margin_delta"] = (reh_total_revenue - reh_expenses) -
                                     (current_revenue - current_expenses)

    # ── Capital requirements for conversion ──
    # Physical plant modifications, signage, IT/billing system changes
    conversion_capital = 500_000.0 + profile.bed_count * 5_000.0
    result["conversion_capital_cost"] = conversion_capital

    # ── Staffing changes ──
    # Inpatient nursing, dietary, some support staff eliminated
    inpatient_staff_reduction = round(Int, profile.employees * inpatient_cost_share * 0.55)
    result["staff_reduction"] = inpatient_staff_reduction
    result["retained_employees"] = profile.employees - inpatient_staff_reduction

    # ── 5-year NPV ──
    annual_benefit = result["annual_margin_delta"]
    npv = -conversion_capital  # initial investment
    for yr in 1:5
        npv += annual_benefit / (1.0 + DEFAULT_WACC)^yr
    end
    result["npv_5yr"] = npv

    # ── Break-even ED volume ──
    # What ED volume makes REH revenue = current revenue?
    # reh_rev = ed_visits × OPPS × 1.05 + facility + retained_OP
    # Solve for ed_visits when reh_rev = current_revenue:
    needed_ed_rev = current_revenue - facility_payment_annual - retained_outpatient_revenue
    opps_per_visit = AVG_OPPS_PER_ED_VISIT * (1.0 + REH_OPPS_PREMIUM)
    breakeven_visits = opps_per_visit > 0 ?
        max(0, round(Int, needed_ed_rev / opps_per_visit)) : 0
    result["breakeven_ed_visits"] = breakeven_visits
    result["current_ed_visits"] = profile.annual_ed_visits
    result["ed_volume_surplus_deficit"] = profile.annual_ed_visits - breakeven_visits

    # ── Recommendation ──
    result["recommendation"] = if npv > 500_000.0 && profile.annual_inpatient_days < 2500
        :convert_now
    elseif npv > 0 && profile.annual_inpatient_days < 4000
        :convert_now
    elseif npv > -250_000.0 && current_margin < -0.02
        :evaluate_further   # marginal NPV but currently losing money
    elseif current_margin < -0.08
        :convert_or_close   # deeply distressed — REH may be last option
    else
        :stay_current
    end

    result["summary"] = @sprintf(
        "REH conversion: Revenue \$%.1fM → \$%.1fM | Margin %.1f%% → %.1f%% | 5yr NPV \$%.1fM | BE ED visits %d vs current %d",
        current_revenue / 1e6, reh_total_revenue / 1e6,
        current_margin * 100, reh_margin * 100,
        npv / 1e6, breakeven_visits, profile.annual_ed_visits
    )

    result
end

# ─────────────────────────────────────────────────────────────────────────────
# Merger / Acquisition Analysis
# ─────────────────────────────────────────────────────────────────────────────

"""
    merger_analysis(profile::HospitalProfile, acquirer_revenue::Float64;
                    premium_pct::Float64=0.15) -> Dict{String,Any}

Merger/acquisition analysis for a rural hospital.

Estimates:
- Enterprise value (revenue multiple 0.5-1.5× for rural hospitals)
- Acquisition premium
- Synergy identification (shared services, supply chain, revenue cycle)
- Integration costs
- Regulatory considerations (FTC/state AG review thresholds)
- Expected timeline

# Example
```julia
m = merger_analysis(profile, 500e6; premium_pct=0.20)
m["enterprise_value_mid"]  # \$15.3M
m["total_synergies"]       # \$2.8M
```
"""
function merger_analysis(
    profile::HospitalProfile,
    acquirer_revenue::Float64;
    premium_pct::Float64 = 0.15,
)::Dict{String,Any}
    result = Dict{String,Any}()

    # ── Enterprise value estimation ──
    rev = profile.annual_revenue
    ev_low  = rev * RURAL_REVENUE_MULTIPLE.low
    ev_mid  = rev * RURAL_REVENUE_MULTIPLE.mid
    ev_high = rev * RURAL_REVENUE_MULTIPLE.high

    # Adjust for profitability
    op_margin = (rev - profile.annual_expenses) / rev
    margin_adj = if op_margin > 0.03
        1.15  # profitable → premium
    elseif op_margin > 0.0
        1.0
    elseif op_margin > -0.05
        0.85  # slight losses → discount
    else
        0.65  # deep losses → significant discount
    end

    ev_low  *= margin_adj
    ev_mid  *= margin_adj
    ev_high *= margin_adj

    result["enterprise_value_low"]  = ev_low
    result["enterprise_value_mid"]  = ev_mid
    result["enterprise_value_high"] = ev_high

    # Acquisition price with premium
    result["acquisition_premium_pct"] = premium_pct
    result["acquisition_price_mid"] = ev_mid * (1.0 + premium_pct)

    # ── Synergy identification ──
    # Shared services (IT, HR, finance, legal): 3-5% of target expenses
    shared_services = profile.annual_expenses * 0.04
    # Supply chain consolidation (GPO leverage, pharmacy): 2-4%
    supply_chain = profile.annual_expenses * 0.03
    # Revenue cycle (centralized billing, coding, collections): 1-2%
    revenue_cycle = profile.annual_expenses * 0.015
    # Clinical integration (telemedicine, specialist access): revenue upside
    clinical_integration = rev * 0.02
    # Insurance/risk pooling
    risk_pooling = profile.annual_expenses * 0.005

    total_synergies = shared_services + supply_chain + revenue_cycle +
                      clinical_integration + risk_pooling
    result["synergies"] = Dict{String,Float64}(
        "shared_services"      => shared_services,
        "supply_chain"         => supply_chain,
        "revenue_cycle"        => revenue_cycle,
        "clinical_integration" => clinical_integration,
        "risk_pooling"         => risk_pooling,
    )
    result["total_synergies"] = total_synergies

    # ── Integration costs (one-time) ──
    it_integration = 750_000.0 + rev * 0.01       # EHR, billing systems
    branding_signage = 150_000.0
    legal_regulatory = 350_000.0
    severance_overlap = profile.employees * 52_000.0 * 0.05  # ~5% staff overlap
    training = profile.employees * 2_000.0

    total_integration = it_integration + branding_signage + legal_regulatory +
                        severance_overlap + training
    result["integration_costs"] = Dict{String,Float64}(
        "it_systems"        => it_integration,
        "branding_signage"  => branding_signage,
        "legal_regulatory"  => legal_regulatory,
        "severance_overlap" => severance_overlap,
        "training"          => training,
    )
    result["total_integration_costs"] = total_integration

    # ── Payback period ──
    result["synergy_payback_years"] = total_integration / total_synergies

    # ── Regulatory considerations ──
    combined_revenue = acquirer_revenue + rev
    regulatory = String[]
    push!(regulatory, "Hart-Scott-Rodino (HSR) Act pre-merger notification " *
          (combined_revenue > 111_400_000 ? "REQUIRED" : "may not be required") *
          " (2024 threshold: \$111.4M)")
    push!(regulatory, "FTC/DOJ antitrust review — assess market concentration (HHI)")
    push!(regulatory, "State Attorney General review — most states require " *
          "notification for nonprofit hospital acquisitions")
    push!(regulatory, "State Certificate of Need (CON) — check state requirements " *
          "for change of ownership")
    push!(regulatory, "CMS Medicare provider agreement transfer (Form CMS-855A)")
    push!(regulatory, "State licensure transfer or new application")
    if profile.cah_status
        push!(regulatory, "CAH designation: Verify continued eligibility under " *
              "new ownership (35-mile distance requirement, state designation)")
    end
    push!(regulatory, "Tax-exempt bond covenants — review change-of-control provisions")
    push!(regulatory, "340B program: New registration if ownership changes")
    result["regulatory_considerations"] = regulatory

    # ── Timeline ──
    result["expected_timeline_months"] = 12  # typical rural hospital M&A
    result["timeline"] = [
        (1, "Letter of intent / term sheet"),
        (2, "Due diligence begins (financial, legal, clinical, environmental)"),
        (3, "Due diligence completed; definitive agreement negotiation"),
        (4, "Definitive agreement signed; HSR filing if required"),
        (5, "State AG / regulatory notifications filed"),
        (6, "Community input period / public hearings (if required)"),
        (8, "Regulatory approvals received"),
        (9, "CMS provider agreement transfer; state licensure"),
        (10, "Integration planning finalized"),
        (11, "Closing; operational integration begins"),
        (12, "Post-close integration: IT, branding, staffing"),
    ]

    result["summary"] = @sprintf(
        "EV range: \$%.1fM–\$%.1fM | Synergies: \$%.1fM/yr | Integration: \$%.1fM | Payback: %.1f yrs",
        ev_low / 1e6, ev_high / 1e6,
        total_synergies / 1e6, total_integration / 1e6,
        total_integration / total_synergies
    )

    result
end

# ─────────────────────────────────────────────────────────────────────────────
# Service Line Reduction
# ─────────────────────────────────────────────────────────────────────────────

"""
    service_line_reduction(profile::HospitalProfile,
                           lines_to_close::Vector{String}) -> Dict{String,Any}

Model selective service line closure for a rural hospital.

For each service line, estimates:
- Revenue impact
- Cost savings
- Staff reductions
- Community impact
- Regulatory implications (EMTALA, state CON)

Supported service lines:
`"obstetrics"`, `"surgery"`, `"inpatient_psychiatry"`, `"rehabilitation"`,
`"home_health"`, `"skilled_nursing"`, `"cardiac_cath"`, `"oncology"`,
`"pediatrics"`, `"dialysis"`

# Example
```julia
r = service_line_reduction(profile, ["obstetrics", "surgery"])
r["net_financial_impact"]  # annual savings net of lost revenue
```
"""
function service_line_reduction(
    profile::HospitalProfile,
    lines_to_close::Vector{String},
)::Dict{String,Any}
    result = Dict{String,Any}()

    # Service line financial profiles (as % of total hospital metrics)
    # Source: AHA/Optum Service Line benchmarks for rural hospitals
    service_profiles = Dict{String,NamedTuple{
        (:revenue_pct, :cost_pct, :staff_pct, :margin, :description),
        Tuple{Float64, Float64, Float64, Float64, String}}}(
        "obstetrics" => (
            revenue_pct = 0.08, cost_pct = 0.10, staff_pct = 0.08,
            margin = -0.15,
            description = "Labor & delivery, prenatal, postpartum"),
        "surgery" => (
            revenue_pct = 0.15, cost_pct = 0.12, staff_pct = 0.10,
            margin = 0.10,
            description = "Inpatient and outpatient surgical services"),
        "inpatient_psychiatry" => (
            revenue_pct = 0.05, cost_pct = 0.06, staff_pct = 0.05,
            margin = -0.12,
            description = "Inpatient behavioral health"),
        "rehabilitation" => (
            revenue_pct = 0.04, cost_pct = 0.04, staff_pct = 0.04,
            margin = -0.02,
            description = "Physical, occupational, speech therapy (inpatient)"),
        "home_health" => (
            revenue_pct = 0.03, cost_pct = 0.03, staff_pct = 0.03,
            margin = 0.02,
            description = "Home health agency services"),
        "skilled_nursing" => (
            revenue_pct = 0.06, cost_pct = 0.07, staff_pct = 0.06,
            margin = -0.08,
            description = "Swing bed / SNF services"),
        "cardiac_cath" => (
            revenue_pct = 0.05, cost_pct = 0.04, staff_pct = 0.03,
            margin = 0.15,
            description = "Cardiac catheterization lab"),
        "oncology" => (
            revenue_pct = 0.04, cost_pct = 0.04, staff_pct = 0.03,
            margin = 0.05,
            description = "Medical and radiation oncology"),
        "pediatrics" => (
            revenue_pct = 0.03, cost_pct = 0.04, staff_pct = 0.03,
            margin = -0.20,
            description = "Pediatric inpatient and outpatient"),
        "dialysis" => (
            revenue_pct = 0.03, cost_pct = 0.03, staff_pct = 0.02,
            margin = 0.03,
            description = "Outpatient dialysis center"),
    )

    total_revenue_impact = 0.0
    total_cost_savings = 0.0
    total_staff_reduction = 0
    line_details = Dict{String,Dict{String,Any}}()

    for line in lines_to_close
        lkey = lowercase(strip(line))
        if !haskey(service_profiles, lkey)
            line_details[line] = Dict{String,Any}(
                "error" => "Unknown service line: $line"
            )
            continue
        end

        sp = service_profiles[lkey]
        rev_impact = profile.annual_revenue * sp.revenue_pct
        cost_savings = profile.annual_expenses * sp.cost_pct
        staff_impact = round(Int, profile.employees * sp.staff_pct)
        net_impact = cost_savings - rev_impact  # positive = net savings

        total_revenue_impact += rev_impact
        total_cost_savings += cost_savings
        total_staff_reduction += staff_impact

        # Community impact for this service line
        community_note = if lkey == "obstetrics"
            "CRITICAL: Closure creates maternal care desert if no OB within 30 miles. " *
            "$(round(Int, profile.service_area_population * 0.012)) annual births affected."
        elseif lkey == "surgery"
            "SIGNIFICANT: $(round(Int, profile.service_area_population * 0.02)) annual " *
            "surgical cases must travel to $(profile.nearest_hospital_miles) miles."
        elseif lkey == "inpatient_psychiatry"
            "SEVERE: Rural behavioral health access already critically limited. " *
            "Nearest inpatient psych may be 60+ miles."
        elseif lkey == "dialysis"
            "CRITICAL: Dialysis patients require 3×/week treatment. Travel burden " *
            "of $(profile.nearest_hospital_miles) miles each way is unsustainable."
        else
            "MODERATE: Patients must seek $(sp.description) at alternative facilities " *
            "$(profile.nearest_hospital_miles) miles away."
        end

        # Regulatory implications
        reg_notes = String[]
        if lkey in ("obstetrics", "surgery")
            push!(reg_notes, "State CON may require approval for service discontinuation")
        end
        push!(reg_notes, "EMTALA: Must maintain ED stabilization capability; " *
              "transfer agreements required for $(sp.description)")
        if lkey == "obstetrics"
            push!(reg_notes, "EMTALA: Hospital must still stabilize OB emergencies " *
                  "presenting to ED, including imminent delivery")
        end
        if profile.cah_status
            push!(reg_notes, "CAH Conditions of Participation: Verify $(sp.description) " *
                  "not required under 42 CFR § 485.618")
        end

        line_details[lkey] = Dict{String,Any}(
            "description"       => sp.description,
            "revenue_impact"    => rev_impact,
            "cost_savings"      => cost_savings,
            "net_financial_impact" => net_impact,
            "staff_reduction"   => staff_impact,
            "current_margin"    => sp.margin,
            "community_impact"  => community_note,
            "regulatory_notes"  => reg_notes,
        )
    end

    result["line_details"] = line_details
    result["total_revenue_impact"] = total_revenue_impact
    result["total_cost_savings"] = total_cost_savings
    result["net_financial_impact"] = total_cost_savings - total_revenue_impact
    result["total_staff_reduction"] = total_staff_reduction

    # Remaining hospital profile
    result["remaining_revenue"] = profile.annual_revenue - total_revenue_impact
    result["remaining_expenses"] = profile.annual_expenses - total_cost_savings
    result["remaining_margin"] = (result["remaining_revenue"] - result["remaining_expenses"]) /
                                  result["remaining_revenue"]
    result["remaining_employees"] = profile.employees - total_staff_reduction

    result["summary"] = @sprintf(
        "Closing %d service lines: Revenue -\$%.1fM, Costs -\$%.1fM, Net %s\$%.1fM, -%d staff",
        length(lines_to_close),
        total_revenue_impact / 1e6, total_cost_savings / 1e6,
        total_cost_savings >= total_revenue_impact ? "+" : "-",
        abs(total_cost_savings - total_revenue_impact) / 1e6,
        total_staff_reduction
    )

    result
end

# ─────────────────────────────────────────────────────────────────────────────
# Regulatory Requirements
# ─────────────────────────────────────────────────────────────────────────────

"""
    regulatory_requirements(scenario_type::Symbol,
                            state::String="generic") -> Vector{String}

Return a checklist of regulatory requirements for the given exit scenario type.

Covers federal requirements for all scenarios, with generic state-level items.
Scenario types: `:full_closure`, `:reh_conversion`, `:merger`,
`:service_reduction`, `:freestanding_ed`, `:telehealth_hub`.

# Example
```julia
reqs = regulatory_requirements(:full_closure)
length(reqs)  # 18 items
```
"""
function regulatory_requirements(
    scenario_type::Symbol,
    state::String = "generic",
)::Vector{String}
    reqs = String[]

    # ── Universal requirements (all scenarios) ──
    push!(reqs, "Board of Directors/Trustees: Formal resolution authorizing " *
          "the transition (requires quorum vote per bylaws)")
    push!(reqs, "Legal counsel: Engage healthcare regulatory attorney for " *
          "compliance oversight")

    # ── Scenario-specific requirements ──
    if scenario_type == :full_closure
        # CMS / Medicare
        push!(reqs, "CMS: Submit Medicare provider agreement termination " *
              "(Form CMS-855A) — 90 days advance notice required per 42 CFR § 489.52")
        push!(reqs, "CMS: Notify Medicare Administrative Contractor (MAC) of " *
              "closure date and final cost report timeline")
        push!(reqs, "CMS: File final Medicare cost report within 5 months of " *
              "closure (per 42 CFR § 413.24(f))")

        # State
        push!(reqs, "State: Notify state health department / licensure board " *
              "(typically 90 days; varies by state — check $(state) requirements)")
        push!(reqs, "State: Surrender hospital license upon closure")
        push!(reqs, "State: Certificate of Need (CON) closure notification " *
              "(if applicable in $(state) — 35 states + DC have CON programs)")

        # Employees
        push!(reqs, "WARN Act: If ≥100 employees, provide 60-day written notice " *
              "to employees AND state dislocated worker unit (29 U.S.C. § 2101)")
        push!(reqs, "COBRA: Notify employees of COBRA continuation coverage " *
              "rights within 14 days of qualifying event")
        push!(reqs, "ERISA: Address pension plan obligations; file IRS Form 5500 " *
              "for final plan year; satisfy PBGC requirements if DB plan exists")
        push!(reqs, "OPEB: Address retiree health benefit obligations per " *
              "GASB 75 / FASB ASC 715")

        # Patients
        push!(reqs, "EMTALA: Maintain ED stabilization and transfer capability " *
              "until final closure date (42 U.S.C. § 1395dd)")
        push!(reqs, "Patient notification: Notify all active patients of closure " *
              "and arrange care transitions (minimum 30 days)")
        push!(reqs, "Medical records: Arrange for HIPAA-compliant record storage " *
              "(retention: 6-10 years adults, until age 21 for minors; state law " *
              "may require longer)")
        push!(reqs, "Transfer agreements: Execute patient transfer agreements " *
              "with receiving hospitals per EMTALA requirements")

        # Financial
        push!(reqs, "Bond covenants: Review and comply with tax-exempt bond " *
              "indenture change-of-use and closure provisions")
        push!(reqs, "Hill-Burton: If facility received Hill-Burton funds, " *
              "satisfy community service and uncompensated care obligations " *
              "(42 CFR Part 124)")
        push!(reqs, "340B: Terminate 340B Drug Pricing Program registration " *
              "with HRSA; comply with manufacturer contract terms")

        # Medicaid
        push!(reqs, "Medicaid: Notify state Medicaid agency of termination; " *
              "file final Medicaid cost report")

        # Environmental
        push!(reqs, "Environmental: Conduct Phase I/II environmental assessment; " *
              "address hazardous materials (DEA-controlled substances disposal, " *
              "radioactive materials, underground storage tanks)")

    elseif scenario_type == :reh_conversion
        push!(reqs, "CMS: Submit REH enrollment application (Form CMS-855A " *
              "change of information) — must attest to 24/7 ED staffing")
        push!(reqs, "CMS: Certify compliance with REH Conditions of Participation " *
              "(42 CFR Part 485 Subpart F)")
        push!(reqs, "CMS: Notify MAC of conversion date for payment system change " *
              "(cost-based → OPPS + 5% + facility payment)")
        push!(reqs, "State: Obtain state REH licensure (or modify existing license) " *
              "— check $(state) REH licensing requirements")
        push!(reqs, "State: File CON application for change of service if required")
        push!(reqs, "Inpatient closure: Formally close inpatient beds; may not " *
              "provide inpatient services (observation ≤24h permitted)")
        push!(reqs, "EMTALA: Maintain 24/7 ED with physician or qualified provider " *
              "on-site or immediately available")
        push!(reqs, "WARN Act: If staffing reductions affect ≥50 employees at " *
              "a single site, 60-day notice required")
        push!(reqs, "340B: Re-register under REH designation if eligible " *
              "(REH eligibility for 340B confirmed by HRSA 2023)")
        push!(reqs, "Bond covenants: Review change-of-use provisions; REH " *
              "conversion may trigger acceleration clauses")
        push!(reqs, "Patient transfers: Arrange transfer of all inpatients before " *
              "conversion effective date")

    elseif scenario_type == :merger
        push!(reqs, "HSR Act: File Hart-Scott-Rodino pre-merger notification if " *
              "transaction exceeds size-of-transaction threshold (\$111.4M in 2024)")
        push!(reqs, "FTC/DOJ: Prepare for antitrust review; assess market " *
              "concentration (HHI analysis) in relevant geographic/service markets")
        push!(reqs, "State AG: File notice with state Attorney General — most states " *
              "require review of nonprofit hospital transactions")
        push!(reqs, "State: CON approval for change of ownership (if applicable " *
              "in $(state))")
        push!(reqs, "CMS: File Form CMS-855A change of information for ownership " *
              "change; obtain new Medicare provider agreement or assignment")
        push!(reqs, "State: Hospital license transfer or new license application")
        push!(reqs, "IRS: If tax-exempt, file Form 990 disclosing significant " *
              "disposition of assets (Schedule N if applicable)")
        push!(reqs, "Bond covenants: Obtain bondholder consent for change of " *
              "control if required by indenture")
        push!(reqs, "Employee: WARN Act notification if transaction involves " *
              "staffing reductions ≥50 employees")
        push!(reqs, "340B: Re-register under new ownership; verify continued " *
              "eligibility for 340B participation")
        push!(reqs, "Contracts: Assign or renegotiate managed care, physician, " *
              "and vendor contracts (many have change-of-control provisions)")

    elseif scenario_type == :service_reduction
        push!(reqs, "State: CON notification for service line discontinuation " *
              "(if applicable in $(state))")
        push!(reqs, "CMS: Update Medicare provider enrollment (Form CMS-855A) " *
              "to reflect service changes")
        push!(reqs, "EMTALA: Maintain ED stabilization capability for conditions " *
              "related to discontinued services")
        push!(reqs, "State: Notify state health department of service reductions")
        push!(reqs, "Community notice: Public notification of service changes " *
              "(minimum 90 days recommended; some states mandate public hearings)")
        push!(reqs, "WARN Act: If service reduction affects ≥50 employees, " *
              "60-day written notice required")
        push!(reqs, "Transfer agreements: Execute transfer agreements for services " *
              "no longer provided")
        if state == "generic"
            push!(reqs, "State-specific: Some states restrict OB/surgical service " *
                  "closures in underserved areas (check $(state) regulations)")
        end

    elseif scenario_type == :freestanding_ed
        push!(reqs, "State: Verify freestanding ED licensure pathway exists in " *
              "$(state) (not all states license independent freestanding EDs)")
        push!(reqs, "CMS: Provider-based freestanding ED retains hospital's " *
              "Medicare provider number; independent FSED may not bill as hospital")
        push!(reqs, "EMTALA: Full EMTALA obligations apply to freestanding EDs")
        push!(reqs, "State: Close inpatient beds and surrender hospital license " *
              "(or reclassify)")
        push!(reqs, "CMS: File final hospital cost report; enroll FSED under " *
              "appropriate provider type")
        push!(reqs, "WARN Act: Notification required if ≥50 employees affected")
        push!(reqs, "Transfer agreements: Required with receiving hospitals for " *
              "patients requiring inpatient admission")
        push!(reqs, "Bond covenants: Change-of-use review required")
        push!(reqs, "340B: Freestanding ED 340B eligibility depends on " *
              "provider-based vs independent status")

    elseif scenario_type == :telehealth_hub
        push!(reqs, "State: Telemedicine practice act compliance — verify " *
              "originating site and distant site requirements in $(state)")
        push!(reqs, "CMS: Telehealth provider enrollment; verify rural HPSA/MUA " *
              "designation for Medicare telehealth originating site eligibility")
        push!(reqs, "State: Surrender hospital license; obtain appropriate " *
              "facility license for telehealth operations")
        push!(reqs, "CMS: File final hospital cost report")
        push!(reqs, "State: Pharmacy license modifications if dispensing changes")
        push!(reqs, "WARN Act: Notification required if ≥50 employees affected")
        push!(reqs, "DEA: Modify controlled substance registrations for " *
              "telehealth prescribing")
        push!(reqs, "HIPAA: Ensure telehealth platform BAA compliance and " *
              "security risk assessment")
        push!(reqs, "Credentialing: Establish credentialing-by-proxy agreements " *
              "with distant site providers (42 CFR § 482.12(a)(8))")
    end

    reqs
end

# ─────────────────────────────────────────────────────────────────────────────
# Transition Timeline
# ─────────────────────────────────────────────────────────────────────────────

"""
    transition_timeline(scenario::ExitScenario) -> Vector{Tuple{Int,String}}

Generate a month-by-month transition timeline for the given exit scenario.

Returns a vector of (month_number, milestone_description) tuples.

# Example
```julia
s = ExitScenario(scenario_type=:full_closure, timeline_months=12,
                 estimated_cost=2.5e6, estimated_savings=0.0)
tl = transition_timeline(s)
tl[1]  # (1, "Board resolution: Formal decision to close...")
```
"""
function transition_timeline(scenario::ExitScenario)::Vector{Tuple{Int,String}}
    t = scenario.timeline_months

    if scenario.scenario_type == :full_closure
        return [
            (1,  "Board resolution: Formal decision to close; engage legal counsel " *
                 "and transition consultant"),
            (1,  "Confidential notification to state health department and CMS regional office"),
            (2,  "WARN Act: Issue 60-day written notice to all employees (if ≥100 FTEs)"),
            (2,  "Community notification: Public announcement; town hall meetings; " *
                 "media communications"),
            (2,  "CMS: Submit Medicare termination notice (90-day requirement)"),
            (3,  "Patient notification: Individual letters to all active patients; " *
                 "arrange care transitions"),
            (3,  "Physician notification: Formal notice to medical staff; " *
                 "credential transfer assistance"),
            (3,  "Execute transfer agreements with receiving hospitals"),
            (4,  "Begin service wind-down: Reduce elective admissions; " *
                 "transfer long-term patients"),
            (4,  "State Medicaid agency notification; Medicaid managed care plan updates"),
            (5,  "340B program: Notify HRSA of termination; deplete 340B inventory"),
            (5,  "Employee transition: Career counseling, job placement assistance, " *
                 "benefits information"),
            (max(1, t - 4), "Vendor contract termination notices; equipment lease returns"),
            (max(1, t - 3), "Pharmacy: Transfer or dispose of pharmaceutical inventory " *
                             "including DEA-controlled substances"),
            (max(1, t - 2), "Final inpatient discharges; all patients transferred or discharged"),
            (max(1, t - 1), "ED closure: Final emergency department operations; " *
                             "EMS system rerouting activated"),
            (t,  "Facility closure: Final day of operations; secure facility"),
            (t,  "Surrender state hospital license"),
            (t + 1, "Post-closure: File final Medicare cost report (due within 5 months)"),
            (t + 1, "Post-closure: File final Medicaid cost report"),
            (t + 2, "Post-closure: Medical records transferred to designated custodian"),
            (t + 3, "Post-closure: Environmental assessment and remediation initiated"),
            (t + 5, "Post-closure: Final cost report settlements; outstanding AR collection"),
        ]

    elseif scenario.scenario_type == :reh_conversion
        return [
            (1,  "Board resolution: Approve CAH-to-REH conversion"),
            (1,  "Engage CMS regional office; confirm REH eligibility"),
            (2,  "State: Apply for REH licensure; CON filing if required"),
            (2,  "Begin inpatient census reduction: Transfer/discharge planning"),
            (3,  "CMS: Submit REH enrollment application (Form CMS-855A update)"),
            (3,  "Notify employees of staffing changes; WARN Act notice if applicable"),
            (4,  "Community notification: Public meetings on transition to REH model"),
            (4,  "Capital improvements: ED upgrades, observation unit preparation"),
            (5,  "Physician credentialing: Update privileges for REH scope of services"),
            (5,  "Payer notification: Update managed care contracts for REH services"),
            (max(1, t - 2), "Transfer remaining inpatients to partner facilities"),
            (max(1, t - 1), "CMS survey: REH Conditions of Participation verification"),
            (t,  "Conversion effective date: Begin REH operations; " *
                 "OPPS + 5% + facility payment begins"),
            (t + 1, "Post-conversion: File final CAH cost report"),
            (t + 3, "Post-conversion: 90-day operational assessment and adjustment"),
        ]

    elseif scenario.scenario_type == :merger
        return [
            (1,  "Board authorization: Approve exploration of merger/acquisition"),
            (2,  "Engage investment banker / financial advisor; prepare CIM"),
            (3,  "Solicit and evaluate Letters of Intent from potential acquirers"),
            (4,  "Select preferred acquirer; execute LOI with exclusivity period"),
            (5,  "Due diligence: Financial, legal, clinical, environmental, IT review"),
            (6,  "Negotiate definitive agreement; board approval"),
            (7,  "HSR filing (if required); state AG notification"),
            (8,  "Regulatory review period; community input / public hearings"),
            (9,  "Regulatory approvals received; closing conditions satisfied"),
            (10, "CMS: Provider agreement transfer; state licensure transfer"),
            (11, "Transaction closing: Ownership transfer effective"),
            (12, "Post-close: Integration — IT systems, branding, staffing alignment"),
        ]

    elseif scenario.scenario_type == :service_reduction
        return [
            (1,  "Board resolution: Approve service line closure(s)"),
            (1,  "Legal review: EMTALA, CON, contractual obligations"),
            (2,  "Notify state health department; CON filing if required"),
            (2,  "Community notification: Public announcement; patient notification"),
            (3,  "Employee notification: Affected staff informed; transition support"),
            (3,  "Execute transfer agreements for discontinued services"),
            (4,  "Begin service wind-down: Reduce referrals; transfer active patients"),
            (max(1, t - 1), "Final day of discontinued service operations"),
            (t,  "Service closure effective; update CMS enrollment"),
            (t + 1, "Post-closure: Monitor patient access; adjust referral pathways"),
        ]

    elseif scenario.scenario_type == :freestanding_ed
        return [
            (1,  "Board resolution: Approve conversion to freestanding ED"),
            (2,  "State: Verify FSED licensure pathway; file application"),
            (2,  "Begin inpatient census wind-down"),
            (3,  "CMS: File enrollment changes; negotiate provider-based status"),
            (4,  "Employee notification: Staffing plan for FSED operations"),
            (5,  "Capital improvements: ED facility modifications"),
            (max(1, t - 2), "Transfer remaining inpatients"),
            (max(1, t - 1), "State survey for FSED licensure"),
            (t,  "Conversion effective: Freestanding ED opens; hospital beds closed"),
            (t + 1, "File final hospital cost report"),
        ]

    elseif scenario.scenario_type == :telehealth_hub
        return [
            (1,  "Board resolution: Approve conversion to telehealth hub"),
            (2,  "Technology assessment: Telehealth platform selection and procurement"),
            (2,  "Begin clinical service wind-down planning"),
            (3,  "State: Apply for telehealth facility license; pharmacy modifications"),
            (3,  "Credential telehealth providers; establish distant-site agreements"),
            (4,  "Employee notification: Transition/separation plans"),
            (5,  "Technology installation: Broadband, equipment, EHR integration"),
            (max(1, t - 2), "Transfer remaining patients; close inpatient/ED services"),
            (max(1, t - 1), "Staff training on telehealth operations"),
            (t,  "Telehealth hub operational: Virtual care services begin"),
            (t + 1, "File final hospital cost report; surrender hospital license"),
            (t + 2, "Post-transition: Community utilization assessment"),
        ]

    else
        return [(1, "Unknown scenario type: $(scenario.scenario_type)")]
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Patient Migration Model
# ─────────────────────────────────────────────────────────────────────────────

"""
    patient_migration_model(profile::HospitalProfile,
        nearby_hospitals::Vector{Tuple{String,Float64,Int}}) -> Dict{String,Any}

Model patient redistribution after hospital closure using a gravity model.

For each nearby hospital (name, distance_miles, bed_count), estimates:
- Volume absorption (inverse-distance-weighted gravity model)
- Capacity constraints at receiving facilities
- Travel time increase
- EMS transport cost increase

The gravity model allocates patients proportional to:
    weight_j = bed_count_j / distance_j²

This follows the Huff model (1963) commonly used in healthcare access research.

# Arguments
- `profile::HospitalProfile`: The closing hospital.
- `nearby_hospitals::Vector{Tuple{String,Float64,Int}}`: Each tuple is
  `(hospital_name, distance_miles, bed_count)`.

# Example
```julia
nearby = [
    ("Regional Medical Center", 35.0, 120),
    ("Community Hospital",      28.0,  45),
    ("University Health",        55.0, 400),
]
m = patient_migration_model(profile, nearby)
m["hospital_allocations"]  # Dict with volume allocation per hospital
```
"""
function patient_migration_model(
    profile::HospitalProfile,
    nearby_hospitals::Vector{Tuple{String,Float64,Int}},
)::Dict{String,Any}
    result = Dict{String,Any}()

    if isempty(nearby_hospitals)
        result["error"] = "No nearby hospitals provided"
        return result
    end

    # ── Gravity model weights (Huff model: attractiveness / distance²) ──
    weights = Float64[]
    for (_, dist, beds) in nearby_hospitals
        d = max(dist, 1.0)  # avoid division by zero
        push!(weights, beds / d^2)
    end
    total_weight = sum(weights)
    shares = total_weight > 0 ? weights ./ total_weight : fill(1.0 / length(weights), length(weights))

    # ── Volume allocation ──
    total_ed = profile.annual_ed_visits
    total_ip_days = profile.annual_inpatient_days
    total_op = profile.annual_outpatient_visits

    allocations = Dict{String,Dict{String,Any}}()
    capacity_warnings = String[]

    for (i, (name, dist, beds)) in enumerate(nearby_hospitals)
        share = shares[i]
        allocated_ed = round(Int, total_ed * share)
        allocated_ip = round(Int, total_ip_days * share)
        allocated_op = round(Int, total_op * share)

        # Capacity assessment: assume receiving hospital operates at 60% occupancy
        # (national rural average)
        available_bed_days = beds * 365
        current_utilization = 0.60
        current_ip_days = round(Int, available_bed_days * current_utilization)
        new_ip_days = current_ip_days + allocated_ip
        new_occupancy = new_ip_days / available_bed_days

        capacity_ok = new_occupancy < 0.85  # 85% is generally considered max safe
        if !capacity_ok
            push!(capacity_warnings,
                "$(name): Projected occupancy $(round(new_occupancy * 100; digits=1))% " *
                "exceeds safe capacity (85%). May need to redistribute " *
                "$(round(Int, (new_occupancy - 0.85) * available_bed_days)) patient-days.")
        end

        # Travel time and EMS cost
        travel_minutes = (dist / 45.0) * 60.0  # 45 mph average rural
        ems_cost_per_transport = dist * EMS_COST_PER_LOADED_MILE * 2.0  # round trip
        annual_ems_cost = allocated_ed * 0.30 * ems_cost_per_transport  # ~30% arrive by EMS

        allocations[name] = Dict{String,Any}(
            "distance_miles"         => dist,
            "bed_count"              => beds,
            "gravity_share"          => round(share; digits = 3),
            "allocated_ed_visits"    => allocated_ed,
            "allocated_ip_days"      => allocated_ip,
            "allocated_op_visits"    => allocated_op,
            "travel_time_minutes"    => round(travel_minutes; digits = 1),
            "new_occupancy_pct"      => round(new_occupancy * 100; digits = 1),
            "capacity_adequate"      => capacity_ok,
            "annual_ems_cost_increase" => round(annual_ems_cost; digits = 0),
        )
    end

    result["hospital_allocations"] = allocations
    result["capacity_warnings"] = capacity_warnings
    result["total_ed_redistributed"] = total_ed
    result["total_ip_days_redistributed"] = total_ip_days
    result["total_op_redistributed"] = total_op

    # Weighted average travel time increase
    avg_travel = sum(shares[i] * (nearby_hospitals[i][2] / 45.0 * 60.0)
                     for i in eachindex(nearby_hospitals))
    result["weighted_avg_travel_time_minutes"] = round(avg_travel; digits = 1)

    # Total additional EMS costs
    total_ems_cost = sum(
        let dist = nearby_hospitals[i][2]
            shares[i] * total_ed * 0.30 * dist * EMS_COST_PER_LOADED_MILE * 2.0
        end
        for i in eachindex(nearby_hospitals)
    )
    result["total_annual_ems_cost_increase"] = round(total_ems_cost; digits = 0)

    # Summary
    receiving_names = join([h[1] for h in nearby_hospitals], ", ")
    result["summary"] = @sprintf(
        "Patient migration to %d facilities (%s): Avg travel +%.0f min | " *
        "EMS cost +\$%.0fK/yr | %d capacity warnings",
        length(nearby_hospitals), receiving_names,
        avg_travel, total_ems_cost / 1e3,
        length(capacity_warnings)
    )

    result
end

# ─────────────────────────────────────────────────────────────────────────────
# Comprehensive Transition Plan Builder
# ─────────────────────────────────────────────────────────────────────────────

"""
    build_transition_plan(profile::HospitalProfile,
                          scenario_type::Symbol;
                          state::String="generic") -> TransitionPlan

Build a comprehensive transition plan combining all analysis components.

Orchestrates: viability assessment, community impact, financial analysis,
regulatory requirements, timeline generation, and stakeholder actions.

# Example
```julia
plan = build_transition_plan(profile, :full_closure; state="TX")
plan.scenario.estimated_cost
plan.community_impact.job_losses
plan.regulatory_requirements
```
"""
function build_transition_plan(
    profile::HospitalProfile,
    scenario_type::Symbol;
    state::String = "generic",
)::TransitionPlan
    # Determine timeline and costs by scenario type
    timeline_months, est_cost, est_savings = if scenario_type == :full_closure
        liq = asset_liquidation(profile)
        (12, liq["total_winddown_costs"], 0.0)
    elseif scenario_type == :reh_conversion
        reh = reh_conversion_analysis(profile)
        conv_cost = get(reh, "conversion_capital_cost", 500_000.0)
        annual_delta = get(reh, "annual_margin_delta", 0.0)
        (8, conv_cost, max(0.0, annual_delta))
    elseif scenario_type == :merger
        (12, profile.annual_revenue * 0.02, 0.0)  # ~2% transaction costs
    elseif scenario_type == :service_reduction
        (6, profile.annual_expenses * 0.01, profile.annual_expenses * 0.05)
    elseif scenario_type == :freestanding_ed
        (9, 750_000.0, profile.annual_expenses * 0.15)
    elseif scenario_type == :telehealth_hub
        (10, 1_200_000.0, profile.annual_expenses * 0.25)
    else
        (12, 0.0, 0.0)
    end

    scenario = ExitScenario(
        scenario_type   = scenario_type,
        timeline_months = timeline_months,
        estimated_cost  = est_cost,
        estimated_savings = est_savings,
    )

    # Community impact
    impact = community_impact(profile)

    # Financial summary
    viability = assess_viability(profile)
    financial_summary = Dict{String,Float64}(
        "current_operating_margin"  => viability["operating_margin"],
        "viability_score"           => viability["viability_score"],
        "days_cash_on_hand"         => viability["days_cash_on_hand"],
        "transition_cost"           => est_cost,
        "annual_savings"            => est_savings,
        "community_economic_loss"   => impact.economic_multiplier_loss,
    )

    # Timeline
    timeline = transition_timeline(scenario)

    # Regulatory
    regs = regulatory_requirements(scenario_type, state)

    # Stakeholder actions
    stakeholders = [
        "Board of Directors: Approve transition; fiduciary oversight of process",
        "CEO/Administration: Execute transition plan; coordinate all workstreams",
        "Medical staff: Patient transition planning; credential transfers",
        "Employees: WARN Act notification; transition support; benefits counseling",
        "Patients: Individual notification; care continuity arrangements",
        "Community: Town halls; media communications; elected official briefings",
        "State legislators: Brief on closure impact; advocate for transition support",
        "CMS regional office: Regulatory compliance; enrollment changes",
        "State health department: Licensure changes; community health assessment",
        "EMS/first responders: Update transport protocols and destination plans",
        "Managed care plans: Network adequacy notification; member communications",
        "Bondholders/lenders: Covenant compliance; consent solicitation if needed",
        "Vendors/contractors: Contract termination or assignment notices",
        "Community health centers (FQHCs): Coordinate expanded primary care access",
    ]

    TransitionPlan(
        scenario                = scenario,
        community_impact        = impact,
        financial_summary       = financial_summary,
        timeline                = timeline,
        regulatory_requirements = regs,
        stakeholder_actions     = stakeholders,
    )
end
