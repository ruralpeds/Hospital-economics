# ── Nonprofit Hospital Accounting ────────────────────────────────────────────
#
# Income statements, balance sheet ratios, cash flow (indirect method),
# depreciation schedules, and nonprofit fund accounting.
#
# Follows HFMA (Healthcare Financial Management Association) conventions.
# Ported from healthcare-finance-julia/src/accounting/accounting_engine.jl

"""
    income_statement(gross_revenue, contractual_adjustments, bad_debt,
                     charity_care, operating_expenses; other_income=0.0)
        -> NamedTuple

Construct a hospital income statement.
Returns gross_revenue, deductions, net_patient_revenue, total_operating_revenue,
operating_income, and total_margin.
"""
function income_statement(gross_revenue::Real,
                           contractual_adjustments::Real,
                           bad_debt::Real,
                           charity_care::Real,
                           operating_expenses::Real;
                           other_income::Real=0.0)
    gross_revenue > 0 || throw(ArgumentError("gross_revenue must be positive"))
    net_patient_revenue     = gross_revenue - contractual_adjustments - bad_debt - charity_care
    total_operating_revenue = net_patient_revenue + other_income
    operating_income        = total_operating_revenue - operating_expenses
    margin = total_operating_revenue > 0 ? operating_income / total_operating_revenue : 0.0
    return (gross_revenue=Float64(gross_revenue),
            contractual_adjustments=Float64(contractual_adjustments),
            bad_debt=Float64(bad_debt),
            charity_care=Float64(charity_care),
            net_patient_revenue=Float64(net_patient_revenue),
            other_income=Float64(other_income),
            total_operating_revenue=Float64(total_operating_revenue),
            operating_expenses=Float64(operating_expenses),
            operating_income=Float64(operating_income),
            total_margin=Float64(margin))
end

"""
    ebitda(operating_income, depreciation, amortization=0.0) -> Float64

Earnings Before Interest, Taxes, Depreciation, and Amortization.
Primary cash-flow proxy used in hospital bond covenants.
"""
function ebitda(operating_income::Real,
                depreciation::Real,
                amortization::Real=0.0)::Float64
    return Float64(operating_income + depreciation + amortization)
end

"""
    ebitda_margin(ebitda_val, total_operating_revenue) -> Float64

EBITDA as a percentage of total operating revenue.
Median community hospital: ~8–10%.
"""
function ebitda_margin(ebitda_val::Real, total_operating_revenue::Real)::Float64
    total_operating_revenue > 0 ||
        throw(ArgumentError("total_operating_revenue must be positive"))
    return ebitda_val / total_operating_revenue
end

"""
    total_margin(excess_revenue, total_revenue) -> Float64

Total margin = excess of revenues over expenses / total revenues.
Includes non-operating items (investment income, contributions).
HFMA benchmark: median ~2–3% for community hospitals.
"""
function total_margin(excess_revenue::Real, total_revenue::Real)::Float64
    total_revenue > 0 || throw(ArgumentError("total_revenue must be positive"))
    return excess_revenue / total_revenue
end

"""
    operating_margin_hfma(operating_income, total_operating_revenue) -> Float64

HFMA operating margin = operating income / total operating revenue.
Excludes non-operating gains. Median community hospital: ~1–2%.
"""
function operating_margin_hfma(operating_income::Real,
                                total_operating_revenue::Real)::Float64
    total_operating_revenue > 0 ||
        throw(ArgumentError("total_operating_revenue must be positive"))
    return operating_income / total_operating_revenue
end

"""
    operating_leverage(contribution_margin, operating_income) -> Float64

Degree of Operating Leverage = contribution margin / operating income.
Measures profit sensitivity to volume changes; higher = more risk.
"""
function operating_leverage(contribution_margin::Real,
                             operating_income::Real)::Float64
    operating_income == 0 &&
        throw(ArgumentError("operating_income cannot be zero"))
    return contribution_margin / operating_income
end

"""
    quick_ratio(cash_and_equivalents, current_liabilities) -> Float64

Acid-test ratio = cash / current liabilities.
More conservative than current ratio; target ≥ 1.0.
"""
function quick_ratio(cash_and_equivalents::Real,
                     current_liabilities::Real)::Float64
    current_liabilities > 0 ||
        throw(ArgumentError("current_liabilities must be positive"))
    return cash_and_equivalents / current_liabilities
end

"""
    debt_to_equity(total_liabilities, net_assets) -> Float64

Leverage ratio for nonprofit hospitals (net assets replace equity).
Lower is less leveraged; A-rated hospitals typically < 1.0.
"""
function debt_to_equity(total_liabilities::Real, net_assets::Real)::Float64
    net_assets == 0 && throw(ArgumentError("net_assets cannot be zero"))
    return total_liabilities / net_assets
end

"""
    equity_multiplier(total_assets, net_assets) -> Float64

DuPont equity multiplier = total assets / net assets.
Used in DuPont decomposition of return on net assets.
"""
function equity_multiplier(total_assets::Real, net_assets::Real)::Float64
    net_assets == 0 && throw(ArgumentError("net_assets cannot be zero"))
    return total_assets / net_assets
end

"""
    balance_sheet_ratios(current_assets, current_liabilities, cash,
                         total_assets, total_liabilities, net_assets,
                         long_term_debt) -> NamedTuple

Compute a full balance sheet ratio suite in one call.
"""
function balance_sheet_ratios(current_assets::Real,
                               current_liabilities::Real,
                               cash::Real,
                               total_assets::Real,
                               total_liabilities::Real,
                               net_assets::Real,
                               long_term_debt::Real)
    current_liabilities > 0 ||
        throw(ArgumentError("current_liabilities must be positive"))
    total_assets > 0 || throw(ArgumentError("total_assets must be positive"))
    return (current_ratio              = current_ratio(current_assets, current_liabilities),
            quick_ratio                = quick_ratio(cash, current_liabilities),
            debt_to_equity             = debt_to_equity(total_liabilities, net_assets),
            equity_multiplier          = equity_multiplier(total_assets, net_assets),
            debt_to_capitalization     = debt_to_capitalization(long_term_debt, net_assets))
end

"""
    cash_flow_indirect(net_income, depreciation, amortization, change_in_ar,
                       change_in_ap, change_in_inventory, capex) -> NamedTuple

Indirect-method cash flow statement.
Returns `(operating, investing, financing, net_change)`.

Positive `change_in_ar` = AR increased (uses cash); positive `change_in_ap` = AP increased (provides cash).
"""
function cash_flow_indirect(net_income::Real,
                             depreciation::Real,
                             amortization::Real,
                             change_in_ar::Real,
                             change_in_ap::Real,
                             change_in_inventory::Real,
                             capex::Real)
    operating  = net_income + depreciation + amortization -
                 change_in_ar + change_in_ap - change_in_inventory
    investing  = -capex
    financing  = 0.0
    net_change = operating + investing + financing
    return (operating=Float64(operating), investing=Float64(investing),
            financing=Float64(financing), net_change=Float64(net_change))
end

"""
    straight_line_depreciation(cost, salvage_value, useful_life_years) -> Float64

Annual straight-line depreciation = (cost − salvage) / useful life.
"""
function straight_line_depreciation(cost::Real,
                                     salvage_value::Real,
                                     useful_life_years::Integer)::Float64
    useful_life_years > 0 ||
        throw(ArgumentError("useful_life_years must be positive"))
    cost >= salvage_value ||
        throw(ArgumentError("cost must be ≥ salvage_value"))
    return (cost - salvage_value) / useful_life_years
end

"""
    macrs_depreciation_schedule(cost, property_class) -> Vector{Float64}

IRS MACRS depreciation schedule for common property classes:
5, 7, 10, 15, 27.5, 39 years.
Returns a vector of annual depreciation amounts.
"""
function macrs_depreciation_schedule(cost::Real,
                                      property_class::Real)::Vector{Float64}
    cost > 0 || throw(ArgumentError("cost must be positive"))
    tables = Dict{Real,Vector{Float64}}(
        5    => [0.2000, 0.3200, 0.1920, 0.1152, 0.1152, 0.0576],
        7    => [0.1429, 0.2449, 0.1749, 0.1249, 0.0893, 0.0892, 0.0893, 0.0446],
        10   => [0.1000, 0.1800, 0.1440, 0.1152, 0.0922, 0.0737,
                 0.0655, 0.0655, 0.0656, 0.0655, 0.0328],
        15   => [0.0500, 0.0950, 0.0855, 0.0770, 0.0693, 0.0623,
                 0.0590, 0.0590, 0.0591, 0.0590, 0.0591, 0.0590,
                 0.0591, 0.0590, 0.0591, 0.0295],
        27.5 => fill(1.0 / 27.5, 28),
        39   => fill(1.0 / 39.0, 40),
    )
    haskey(tables, property_class) ||
        throw(ArgumentError("unsupported property_class: $property_class. " *
                            "Valid: 5, 7, 10, 15, 27.5, 39"))
    return cost .* tables[property_class]
end

"""
    net_assets_change(beginning_net_assets, excess_revenue,
                      unrestricted_gifts=0.0, temporarily_restricted_releases=0.0,
                      other_changes=0.0) -> Float64

Ending net assets per nonprofit accounting standards (ASC 958).
"""
function net_assets_change(beginning_net_assets::Real,
                            excess_revenue::Real,
                            unrestricted_gifts::Real=0.0,
                            temporarily_restricted_releases::Real=0.0,
                            other_changes::Real=0.0)::Float64
    return Float64(beginning_net_assets + excess_revenue + unrestricted_gifts +
                   temporarily_restricted_releases + other_changes)
end

"""
    fund_accounting_summary(unrestricted, temporarily_restricted,
                            permanently_restricted) -> NamedTuple

Summarise the three net asset classes under ASC 958.
Returns amounts, total, and unrestricted fraction.
"""
function fund_accounting_summary(unrestricted::Real,
                                  temporarily_restricted::Real,
                                  permanently_restricted::Real)
    total = unrestricted + temporarily_restricted + permanently_restricted
    return (unrestricted=Float64(unrestricted),
            temporarily_restricted=Float64(temporarily_restricted),
            permanently_restricted=Float64(permanently_restricted),
            total_net_assets=Float64(total),
            unrestricted_fraction=total > 0 ? unrestricted / total : 0.0)
end

"""
    charitable_community_benefit_rate(community_benefit_expense,
                                      total_operating_expense) -> Float64

Community benefit expense as a share of total operating expense.
IRS Form 990 Schedule H threshold: ≥ 5% for tax-exempt justification.
"""
function charitable_community_benefit_rate(community_benefit_expense::Real,
                                            total_operating_expense::Real)::Float64
    total_operating_expense > 0 ||
        throw(ArgumentError("total_operating_expense must be positive"))
    return community_benefit_expense / total_operating_expense
end
