# Deterministic Financial Projection Engine
# Projects hospital financials forward using fixed growth/inflation assumptions.

"""
    DeterministicParams <: AbstractSimulationParams

Parameters for deterministic financial projection of a rural hospital.

# Fields
- `projection_years::Int`: Number of years to project forward.
- `volume_growth_rate::Float64`: Annual patient volume growth rate (e.g., -0.02 for 2% decline).
- `cost_inflation_rate::Float64`: General cost inflation rate per year.
- `salary_inflation_rate::Float64`: Salary/wage inflation rate per year.
- `supply_inflation_rate::Float64`: Medical supply inflation rate per year.
- `reimbursement_adjustment::Float64`: Annual reimbursement rate adjustment factor.
- `payer_mix_shift::Float64`: Annual shift in payer mix toward Medicare/Medicaid (positive = more government payers).
"""
struct DeterministicParams <: AbstractSimulationParams
    projection_years::Int
    volume_growth_rate::Float64
    cost_inflation_rate::Float64
    salary_inflation_rate::Float64
    supply_inflation_rate::Float64
    reimbursement_adjustment::Float64
    payer_mix_shift::Float64
end

"""
    DeterministicParams(; kwargs...)

Construct `DeterministicParams` with keyword arguments and sensible defaults for a
typical rural hospital scenario.
"""
function DeterministicParams(;
    projection_years::Int = 10,
    volume_growth_rate::Float64 = -0.01,
    cost_inflation_rate::Float64 = 0.03,
    salary_inflation_rate::Float64 = 0.035,
    supply_inflation_rate::Float64 = 0.04,
    reimbursement_adjustment::Float64 = 0.015,
    payer_mix_shift::Float64 = 0.005,
)
    DeterministicParams(
        projection_years,
        volume_growth_rate,
        cost_inflation_rate,
        salary_inflation_rate,
        supply_inflation_rate,
        reimbursement_adjustment,
        payer_mix_shift,
    )
end

"""
    YearlyProjection

Financial projection results for a single year.

# Fields
- `year::Int`: Projection year (1-indexed from base year).
- `inpatient_revenue::Float64`: Projected inpatient revenue.
- `outpatient_revenue::Float64`: Projected outpatient revenue.
- `total_revenue::Float64`: Total projected revenue.
- `salary_expense::Float64`: Total salary and wage expenses.
- `supply_expense::Float64`: Total supply expenses.
- `other_expense::Float64`: Other operating expenses.
- `total_expense::Float64`: Total operating expenses.
- `operating_income::Float64`: Revenue minus expenses.
- `operating_margin::Float64`: Operating income / total revenue.
- `days_cash_on_hand::Float64`: Cash reserves expressed in days of operating expense.
- `debt_service_coverage::Float64`: Operating income available for debt service.
- `patient_volume::Float64`: Projected total patient volume (index, base year = 1.0).
- `payer_mix_government::Float64`: Fraction of revenue from government payers.
"""
struct YearlyProjection
    year::Int
    inpatient_revenue::Float64
    outpatient_revenue::Float64
    total_revenue::Float64
    salary_expense::Float64
    supply_expense::Float64
    other_expense::Float64
    total_expense::Float64
    operating_income::Float64
    operating_margin::Float64
    days_cash_on_hand::Float64
    debt_service_coverage::Float64
    patient_volume::Float64
    payer_mix_government::Float64
end

"""
    DeterministicResult <: AbstractSimulationResult

Complete deterministic projection output.

# Fields
- `params::DeterministicParams`: The parameters that produced this result.
- `projections::Vector{YearlyProjection}`: Year-by-year projections.
- `cumulative_operating_income::Float64`: Sum of operating income across all years.
- `terminal_operating_margin::Float64`: Operating margin in the final projected year.
- `closure_risk_year::Union{Int, Nothing}`: First year where operating margin < -0.10, or `nothing`.
"""
struct DeterministicResult <: AbstractSimulationResult
    params::DeterministicParams
    projections::Vector{YearlyProjection}
    cumulative_operating_income::Float64
    terminal_operating_margin::Float64
    closure_risk_year::Union{Int, Nothing}
end

# ---------------------------------------------------------------------------
# Revenue projection helpers
# ---------------------------------------------------------------------------

"""
    project_inpatient_revenue(base_revenue, year, params) -> Float64

Project inpatient revenue for a given year, accounting for volume decline,
reimbursement adjustments, and payer mix shifts.
"""
function project_inpatient_revenue(base_revenue::Float64, year::Int, params::DeterministicParams)::Float64
    volume_factor = (1.0 + params.volume_growth_rate)^year
    reimbursement_factor = (1.0 + params.reimbursement_adjustment)^year
    # Inpatient revenue is more sensitive to volume decline and payer-mix erosion
    payer_erosion = 1.0 - params.payer_mix_shift * year * 0.05  # government payers reimburse less
    return base_revenue * volume_factor * reimbursement_factor * max(payer_erosion, 0.70)
end

"""
    project_outpatient_revenue(base_revenue, year, params) -> Float64

Project outpatient revenue, which may grow even as inpatient volume shrinks
due to care model shifts.
"""
function project_outpatient_revenue(base_revenue::Float64, year::Int, params::DeterministicParams)::Float64
    # Outpatient volume grows slightly faster as care shifts outward
    outpatient_growth = params.volume_growth_rate + 0.02
    volume_factor = (1.0 + outpatient_growth)^year
    reimbursement_factor = (1.0 + params.reimbursement_adjustment)^year
    return base_revenue * volume_factor * reimbursement_factor
end

# ---------------------------------------------------------------------------
# Expense projection helpers
# ---------------------------------------------------------------------------

"""
    project_salary_expense(base_salary, year, params) -> Float64

Project salary expenses accounting for salary inflation and modest volume-linked
staffing adjustments.
"""
function project_salary_expense(base_salary::Float64, year::Int, params::DeterministicParams)::Float64
    inflation_factor = (1.0 + params.salary_inflation_rate)^year
    # Staffing can only be reduced partially when volume declines (fixed-cost component)
    volume_factor = (1.0 + params.volume_growth_rate)^year
    staffing_adjustment = 0.3 * volume_factor + 0.7  # 70% fixed, 30% variable
    return base_salary * inflation_factor * staffing_adjustment
end

"""
    project_supply_expense(base_supply, year, params) -> Float64

Project supply expenses accounting for supply-specific inflation and volume changes.
"""
function project_supply_expense(base_supply::Float64, year::Int, params::DeterministicParams)::Float64
    inflation_factor = (1.0 + params.supply_inflation_rate)^year
    volume_factor = (1.0 + params.volume_growth_rate)^year
    # Supplies are more variable with volume
    supply_adjustment = 0.6 * volume_factor + 0.4
    return base_supply * inflation_factor * supply_adjustment
end

"""
    project_other_expense(base_other, year, params) -> Float64

Project other operating expenses using the general cost inflation rate.
"""
function project_other_expense(base_other::Float64, year::Int, params::DeterministicParams)::Float64
    inflation_factor = (1.0 + params.cost_inflation_rate)^year
    return base_other * inflation_factor
end

# ---------------------------------------------------------------------------
# Financial ratio helpers
# ---------------------------------------------------------------------------

"""
    compute_operating_margin(revenue, expense) -> Float64

Compute operating margin as operating income divided by total revenue.
Returns 0.0 when revenue is zero.
"""
function compute_operating_margin(revenue::Float64, expense::Float64)::Float64
    revenue == 0.0 && return 0.0
    return (revenue - expense) / revenue
end

"""
    compute_days_cash_on_hand(cash_reserves, daily_expense) -> Float64

Compute the number of days a hospital can operate on its current cash reserves.
"""
function compute_days_cash_on_hand(cash_reserves::Float64, daily_expense::Float64)::Float64
    daily_expense <= 0.0 && return Inf
    return cash_reserves / daily_expense
end

"""
    compute_debt_service_coverage(operating_income, depreciation, annual_debt_service) -> Float64

Compute debt service coverage ratio (DSCR).
DSCR = (Operating Income + Depreciation) / Annual Debt Service.
"""
function compute_debt_service_coverage(operating_income::Float64, depreciation::Float64,
                                       annual_debt_service::Float64)::Float64
    annual_debt_service <= 0.0 && return Inf
    return (operating_income + depreciation) / annual_debt_service
end

# ---------------------------------------------------------------------------
# Single-year projection
# ---------------------------------------------------------------------------

"""
    project_single_year(base_financials, year, params) -> YearlyProjection

Project financial results for a single year given base-year financials.

`base_financials` is a `NamedTuple` with fields:
  `inpatient_revenue`, `outpatient_revenue`, `salary_expense`, `supply_expense`,
  `other_expense`, `cash_reserves`, `depreciation`, `annual_debt_service`,
  `payer_mix_government`.
"""
function project_single_year(base_financials::NamedTuple, year::Int,
                              params::DeterministicParams)::YearlyProjection
    ip_rev = project_inpatient_revenue(base_financials.inpatient_revenue, year, params)
    op_rev = project_outpatient_revenue(base_financials.outpatient_revenue, year, params)
    total_rev = ip_rev + op_rev

    sal_exp = project_salary_expense(base_financials.salary_expense, year, params)
    sup_exp = project_supply_expense(base_financials.supply_expense, year, params)
    oth_exp = project_other_expense(base_financials.other_expense, year, params)
    total_exp = sal_exp + sup_exp + oth_exp

    oi = total_rev - total_exp
    margin = compute_operating_margin(total_rev, total_exp)

    # Approximate cash reserves: base cash + operating income for this year (simplified)
    approx_cash = base_financials.cash_reserves + oi
    daily_exp = total_exp / 365.0
    dcoh = compute_days_cash_on_hand(max(approx_cash, 0.0), daily_exp)
    dscr = compute_debt_service_coverage(oi, base_financials.depreciation,
                                          base_financials.annual_debt_service)

    volume_index = (1.0 + params.volume_growth_rate)^year
    gov_payer = min(base_financials.payer_mix_government + params.payer_mix_shift * year, 1.0)

    return YearlyProjection(
        year, ip_rev, op_rev, total_rev,
        sal_exp, sup_exp, oth_exp, total_exp,
        oi, margin, dcoh, dscr,
        volume_index, gov_payer,
    )
end

# ---------------------------------------------------------------------------
# Full projection
# ---------------------------------------------------------------------------

"""
    project_financials(hospital, params::DeterministicParams) -> DeterministicResult

Run a deterministic financial projection for `hospital` over `params.projection_years`.

`hospital` must expose a `base_financials(hospital)` function that returns a NamedTuple
with the required base-year financial fields, or be a NamedTuple itself.
"""
function project_financials(hospital, params::DeterministicParams)::DeterministicResult
    bf = _extract_base_financials(hospital)
    projections = Vector{YearlyProjection}(undef, params.projection_years)

    closure_risk_year = nothing
    for y in 1:params.projection_years
        proj = project_single_year(bf, y, params)
        projections[y] = proj
        if isnothing(closure_risk_year) && proj.operating_margin < -0.10
            closure_risk_year = y
        end
    end

    cumulative_oi = sum(p.operating_income for p in projections)
    terminal_margin = projections[end].operating_margin

    return DeterministicResult(params, projections, cumulative_oi, terminal_margin, closure_risk_year)
end

"""
    base_financials(hospital::AbstractHospital) -> NamedTuple

Extract base-year financials from a hospital object by reading the most recent
`AnnualFinancials` record. Returns a NamedTuple with the fields required by
`project_single_year`.
"""
function base_financials(hospital::AbstractHospital)
    fin_list = getproperty(hospital, :historical_financials)
    isempty(fin_list) && error("Hospital has no historical financials")
    f = last(fin_list)  # most recent year
    supply_expense = f.supplies + f.pharmaceuticals
    other_expense = f.total_operating_expenses - (f.salaries_wages + f.employee_benefits) - supply_expense
    return (
        inpatient_revenue = f.inpatient_revenue,
        outpatient_revenue = f.outpatient_revenue,
        salary_expense = f.salaries_wages + f.employee_benefits,
        supply_expense = supply_expense,
        other_expense = max(other_expense, 0.0),
        cash_reserves = f.cash_and_equivalents,
        depreciation = f.depreciation,
        annual_debt_service = f.interest_expense,
        payer_mix_government = f.medicare_days_pct + f.medicaid_days_pct,
    )
end

"""
    _extract_base_financials(hospital) -> NamedTuple

Extract base-year financials from a hospital object. Falls back to treating
the argument as a NamedTuple if no `base_financials` method is defined.
"""
function _extract_base_financials(hospital)
    if hospital isa NamedTuple
        return hospital
    elseif hospital isa AbstractHospital
        return base_financials(hospital)
    else
        error("Cannot extract base financials from $(typeof(hospital)). " *
              "Pass an AbstractHospital or a NamedTuple.")
    end
end
