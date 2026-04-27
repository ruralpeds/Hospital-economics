"""
    dupont.jl — DuPont decomposition for healthcare financial analysis

Classic 3-factor and 5-factor DuPont analysis adapted for nonprofit hospitals.
"""

# ─────────────────────────────────────────────────────────────────────────────
# Types
# ─────────────────────────────────────────────────────────────────────────────

"""
    DuPont3Factor

Classic three-factor DuPont decomposition.
ROA = Net Profit Margin × Asset Turnover × Equity Multiplier
"""
@kwdef struct DuPont3Factor
    net_profit_margin::Float64
    asset_turnover::Float64
    equity_multiplier::Float64
    return_on_net_assets::Float64
end

"""
    DuPont5Factor

Extended five-factor DuPont decomposition.
ROA = Operating Margin × Asset Turnover × Equity Multiplier × Interest Burden × Tax Burden
For tax-exempt hospitals, tax_burden = 1.0.
"""
@kwdef struct DuPont5Factor
    operating_margin::Float64
    asset_turnover::Float64
    equity_multiplier::Float64
    interest_burden::Float64
    tax_burden::Float64
    return_on_net_assets::Float64
end

# ─────────────────────────────────────────────────────────────────────────────
# 3-Factor DuPont
# ─────────────────────────────────────────────────────────────────────────────

"""
    dupont_3factor(
        financials::NamedTuple,
        balance_sheet::BalanceSheetSnapshot
    )::DuPont3Factor

Compute the three-factor DuPont decomposition.

# Formula
- Net Profit Margin = Net Income / Revenue
- Asset Turnover = Revenue / Total Assets
- Equity Multiplier = Total Assets / Net Assets
- ROA = NPM × ATO × EM

# Arguments
- financials: NamedTuple with net_income and total_operating_revenue
- balance_sheet: BalanceSheetSnapshot with asset and net asset totals

# Returns
DuPont3Factor with the three components and their product (ROA).
"""
function dupont_3factor(
    financials::NamedTuple,
    balance_sheet::BalanceSheetSnapshot
)::DuPont3Factor
    # Compute total assets
    current_assets = balance_sheet.cash_and_equivalents +
                     balance_sheet.short_term_investments +
                     balance_sheet.accounts_receivable_net +
                     balance_sheet.inventory +
                     balance_sheet.other_current_assets
    net_ppe = balance_sheet.gross_ppe - balance_sheet.accumulated_depreciation
    total_assets = current_assets + net_ppe +
                   balance_sheet.long_term_investments +
                   balance_sheet.other_lt_assets

    # Compute total net assets
    total_net_assets = balance_sheet.net_assets_unrestricted +
                       balance_sheet.net_assets_temp_restricted +
                       balance_sheet.net_assets_perm_restricted

    # Extract from financials
    net_income = Float64(get(financials, :net_income, 0.0))
    revenue = Float64(get(financials, :total_operating_revenue, 1.0))

    # Compute factors
    npm = revenue > 0 ? net_income / revenue : 0.0
    ato = total_assets > 0 ? revenue / total_assets : 0.0
    em = total_net_assets > 0 ? total_assets / total_net_assets : 0.0

    # Compute ROA
    rona = npm * ato * em

    return DuPont3Factor(
        net_profit_margin = npm,
        asset_turnover = ato,
        equity_multiplier = em,
        return_on_net_assets = rona
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# 5-Factor DuPont
# ─────────────────────────────────────────────────────────────────────────────

"""
    dupont_5factor(
        financials::NamedTuple,
        balance_sheet::BalanceSheetSnapshot;
        tax_exempt::Bool=true
    )::DuPont5Factor

Compute the five-factor DuPont decomposition.

# Formula
- Operating Margin = EBIT / Revenue
- Asset Turnover = Revenue / Total Assets
- Equity Multiplier = Total Assets / Net Assets
- Interest Burden = EBT / EBIT
- Tax Burden = NI / EBT (= 1.0 for tax-exempt)
- ROA = OM × ATO × EM × IB × TB

# Arguments
- financials: NamedTuple with revenue, ebit, ebt, net_income, interest_expense
- balance_sheet: BalanceSheetSnapshot with asset and net asset totals
- tax_exempt: if true, tax_burden is forced to 1.0

# Returns
DuPont5Factor with the five components and their product (ROA).
"""
function dupont_5factor(
    financials::NamedTuple,
    balance_sheet::BalanceSheetSnapshot;
    tax_exempt::Bool=true
)::DuPont5Factor
    # Compute total assets
    current_assets = balance_sheet.cash_and_equivalents +
                     balance_sheet.short_term_investments +
                     balance_sheet.accounts_receivable_net +
                     balance_sheet.inventory +
                     balance_sheet.other_current_assets
    net_ppe = balance_sheet.gross_ppe - balance_sheet.accumulated_depreciation
    total_assets = current_assets + net_ppe +
                   balance_sheet.long_term_investments +
                   balance_sheet.other_lt_assets

    # Compute total net assets
    total_net_assets = balance_sheet.net_assets_unrestricted +
                       balance_sheet.net_assets_temp_restricted +
                       balance_sheet.net_assets_perm_restricted

    # Extract from financials
    revenue = Float64(get(financials, :total_operating_revenue, 1.0))
    ebit = Float64(get(financials, :ebit, 0.0))
    ebt = Float64(get(financials, :ebt, 0.0))
    net_income = Float64(get(financials, :net_income, 0.0))
    interest_expense = Float64(get(financials, :interest_expense, 0.0))

    # Compute factors
    om = revenue > 0 ? ebit / revenue : 0.0
    ato = total_assets > 0 ? revenue / total_assets : 0.0
    em = total_net_assets > 0 ? total_assets / total_net_assets : 0.0

    # Interest burden: EBT / EBIT (measure of interest drag)
    # If EBIT <= 0, interest burden is not meaningful; set to 1.0
    ib = ebit > 0.0001 ? ebt / ebit : 1.0

    # Tax burden: NI / EBT (measure of tax drag)
    # For tax-exempt organizations, this is 1.0 by definition
    tb = if tax_exempt
        1.0
    else
        ebt > 0.0001 ? net_income / ebt : 1.0
    end

    # Compute ROA
    rona = om * ato * em * ib * tb

    return DuPont5Factor(
        operating_margin = om,
        asset_turnover = ato,
        equity_multiplier = em,
        interest_burden = ib,
        tax_burden = tb,
        return_on_net_assets = rona
    )
end
