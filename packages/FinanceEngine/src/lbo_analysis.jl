"""
    lbo_analysis.jl — Hospital Leveraged Buyout Analysis (MBA Gap A-08)

Models private equity leveraged buyout economics for hospital acquisitions,
relevant for for-profit conversions and PE-backed rural health consolidation.

Provides:
1. Debt capacity from EBITDA leverage multiples
2. Sources-and-uses table (how the deal is financed)
3. Annual debt paydown schedule with amortisation and cash sweep
4. Exit scenario analysis (IRR at various multiples and hold periods)
5. Management equity pool and preferred return hurdle

References:
- Rosenbaum J, Pearl J (2023). Investment Banking, 4e. Wiley.
- Kaufman Hall (2024). Hospital M&A: PE Activity in Healthcare.
- Irving Levin (2023). The Hospital Acquisition Report.
"""

using Statistics; using Printf

const LBO_SENIOR_RATE_DEFAULT    = 0.075  # SOFR + spread, FY2026
const LBO_MEZZ_RATE_DEFAULT      = 0.125  # mezzanine / subordinated
const LBO_MGMT_EQUITY_POOL_PCT   = 0.10   # management carve-out
const LBO_PREFERRED_HURDLE       = 0.08   # preferred return before common upside

@kwdef struct LBOInputs
    hospital_name::String
    purchase_price::Float64           # Enterprise value paid
    ebitda_entry::Float64             # Current year EBITDA
    ebitda_growth_rate::Float64 = 0.03
    senior_leverage_multiple::Float64 = 4.0   # × EBITDA
    mezz_leverage_multiple::Float64   = 1.5   # × EBITDA (on top of senior)
    senior_interest_rate::Float64     = LBO_SENIOR_RATE_DEFAULT
    mezz_interest_rate::Float64       = LBO_MEZZ_RATE_DEFAULT
    senior_amort_pct::Float64 = 0.05  # annual principal paydown % of original balance
    cash_sweep_pct::Float64   = 0.50  # % of free cash flow swept to senior debt
    hold_years::Int           = 5
    exit_multiple_range::Vector{Float64} = [5.0, 6.0, 7.0, 8.0]
    capex_pct_revenue::Float64 = 0.04
    revenue_to_ebitda_ratio::Float64 = 8.0   # implicit revenue = EBITDA × this
    mgmt_equity_pool_pct::Float64 = LBO_MGMT_EQUITY_POOL_PCT
end

struct LBOSourcesUses
    purchase_price::Float64
    senior_debt::Float64
    mezz_debt::Float64
    total_debt::Float64
    equity_contribution::Float64
    equity_pct::Float64
    debt_to_ebitda::Float64
    entry_multiple::Float64
end

struct LBOYearResult
    year::Int
    ebitda::Float64
    interest_senior::Float64
    interest_mezz::Float64
    amort_senior::Float64
    cash_sweep::Float64
    senior_balance_eoy::Float64
    mezz_balance_eoy::Float64
    free_cash_flow::Float64
end

struct LBOExitScenario
    exit_year::Int
    exit_multiple::Float64
    exit_ev::Float64
    total_debt_remaining::Float64
    equity_proceeds::Float64
    mgmt_equity_proceeds::Float64
    sponsor_equity_proceeds::Float64
    moic::Float64
    irr::Float64
end

struct LBOResult
    inputs::LBOInputs
    sources_uses::LBOSourcesUses
    annual_results::Vector{LBOYearResult}
    exit_scenarios::Vector{LBOExitScenario}
    base_irr::Float64       # at median exit multiple, hold_years
    base_moic::Float64
end

function _xirr(cash_flows::Vector{Float64}; guess=0.20, tol=1e-8, max_iter=200)
    f(r) = sum(cash_flows[i] / (1+r)^(i-1) for i in 1:length(cash_flows))
    lo, hi = -0.999, 10.0
    for _ in 1:max_iter
        mid = (lo + hi) / 2
        abs(hi - lo) < tol && return mid
        f(lo) * f(mid) < 0 ? (hi = mid) : (lo = mid)
    end
    (lo + hi) / 2
end

"""
    hospital_lbo(inputs::LBOInputs) -> LBOResult

Run a full LBO analysis for a hospital acquisition.
"""
function hospital_lbo(inputs::LBOInputs)::LBOResult
    pp = inputs.purchase_price
    e0 = inputs.ebitda_entry

    senior_debt = min(inputs.senior_leverage_multiple * e0, pp * 0.55)
    mezz_debt   = min(inputs.mezz_leverage_multiple   * e0, pp * 0.20)
    total_debt  = senior_debt + mezz_debt
    equity      = pp - total_debt

    su = LBOSourcesUses(pp, senior_debt, mezz_debt, total_debt,
        equity, equity/pp, total_debt/e0, pp/e0)

    # Annual debt model
    annual = LBOYearResult[]
    s_bal  = senior_debt
    m_bal  = mezz_debt
    revenue = e0 * inputs.revenue_to_ebitda_ratio

    for yr in 1:inputs.hold_years
        ebitda = e0 * (1 + inputs.ebitda_growth_rate)^yr
        rev_yr = revenue * (1 + inputs.ebitda_growth_rate)^yr
        capex  = rev_yr * inputs.capex_pct_revenue
        int_s  = s_bal * inputs.senior_interest_rate
        int_m  = m_bal * inputs.mezz_interest_rate
        amort  = senior_debt * inputs.senior_amort_pct
        amort  = min(amort, s_bal)
        fcf    = ebitda - int_s - int_m - amort - capex
        sweep  = max(0.0, fcf * inputs.cash_sweep_pct)
        sweep  = min(sweep, max(0.0, s_bal - amort))
        s_bal  = max(0.0, s_bal - amort - sweep)
        fcf_after = max(0.0, fcf - sweep)
        push!(annual, LBOYearResult(yr, ebitda, int_s, int_m,
            amort, sweep, s_bal, m_bal, fcf_after))
    end

    # Exit scenarios
    exits = LBOExitScenario[]
    for exit_mult in inputs.exit_multiple_range
        exit_ebitda = e0 * (1 + inputs.ebitda_growth_rate)^inputs.hold_years
        exit_ev     = exit_ebitda * exit_mult
        debt_rem    = annual[end].senior_balance_eoy + annual[end].mezz_balance_eoy
        eq_proc     = max(0.0, exit_ev - debt_rem)
        mgmt_proc   = eq_proc * inputs.mgmt_equity_pool_pct
        sponsor_proc= eq_proc * (1 - inputs.mgmt_equity_pool_pct)
        moic        = equity > 0 ? sponsor_proc / equity : 0.0
        cfs         = [-equity; zeros(inputs.hold_years - 1); sponsor_proc]
        irr         = _xirr(cfs)
        push!(exits, LBOExitScenario(inputs.hold_years, exit_mult, exit_ev,
            debt_rem, eq_proc, mgmt_proc, sponsor_proc, moic, irr))
    end

    mid_exit = exits[length(exits) ÷ 2 + 1]
    LBOResult(inputs, su, annual, exits, mid_exit.irr, mid_exit.moic)
end
