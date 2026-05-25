# Leveraged Buyout (LBO) Model for Hospital Acquisitions
#
# Projects annual financials under a leveraged acquisition structure:
# debt sizing, mandatory amortization, optional cash sweep, exit valuation.
# Computes equity IRR via Newton-Raphson and MOIC (multiple on invested capital).

"""
    DebtTerm

Terms for a single tranche of acquisition debt.
"""
@kwdef struct DebtTerm
    rate::Float64
    maturity::Int
    amortization_pct::Float64 = 0.0   # annual mandatory amortization as % of original principal
end

"""
    LBOInput

Inputs for a hospital leveraged buyout model.
"""
@kwdef struct LBOInput
    enterprise_value::Float64
    equity_pct::Float64               # sponsor equity as fraction of EV
    debt_terms::Vector{DebtTerm}      # one or more debt tranches
    revenue::Float64
    ebitda_margin::Float64            # as fraction (0.15 = 15%)
    revenue_growth::Float64           # annual growth rate
    exit_multiple::Float64            # EV/EBITDA at exit
    hold_years::Int
    cash_sweep_pct::Float64 = 0.0     # fraction of excess FCF applied to debt paydown
    capex_pct_revenue::Float64 = 0.05 # capital expenditures as % of revenue
    tax_rate::Float64 = 0.0           # effective tax rate (non-profit = 0)
end

"""
    AnnualProjection

Single-year financial projection within an LBO model.
"""
@kwdef struct AnnualProjection
    year::Int
    revenue::Float64
    ebitda::Float64
    depreciation::Float64
    interest_expense::Float64
    taxes::Float64
    net_income::Float64
    capex::Float64
    free_cash_flow::Float64
    debt_balance::Float64
    mandatory_paydown::Float64
    cash_sweep::Float64
end

"""
    LBOResult

Complete result of an LBO analysis including sources/uses, projections, and returns.
"""
@kwdef struct LBOResult
    # Sources & uses
    total_enterprise_value::Float64
    equity_contribution::Float64
    total_debt::Float64
    debt_by_tranche::Vector{Float64}

    # Projections
    annual_projections::Vector{AnnualProjection}

    # Exit
    exit_ebitda::Float64
    exit_enterprise_value::Float64
    exit_debt::Float64
    exit_equity::Float64

    # Returns
    equity_irr::Float64
    moic::Float64
end

function Base.show(io::IO, r::LBOResult)
    print(io, "LBOResult(EV=$(round(Int, r.total_enterprise_value)), IRR=$(round(r.equity_irr * 100, digits=1))%, MOIC=$(round(r.moic, digits=2))x)")
end

"""
    calculate_lbo(input::LBOInput) -> LBOResult

Run a full leveraged buyout model projection.

Steps:
1. Size debt tranches (EV * (1 - equity_pct) allocated across tranches)
2. Project annual revenue, EBITDA, interest, FCF
3. Pay down debt via mandatory amortization + optional cash sweep
4. Compute exit equity = exit EV - remaining debt
5. Equity IRR via Newton-Raphson on cash flow series [-equity, 0..0, exit_equity]
6. MOIC = exit_equity / initial_equity
"""
function calculate_lbo(input::LBOInput)::LBOResult
    input.enterprise_value > 0.0 || error("enterprise_value must be positive")
    0.0 < input.equity_pct <= 1.0 || error("equity_pct must be in (0, 1]")
    input.hold_years > 0 || error("hold_years must be positive")
    !isempty(input.debt_terms) || error("at least one debt tranche required")

    # --- Sources & Uses ---
    equity = input.enterprise_value * input.equity_pct
    total_debt = input.enterprise_value - equity

    # Allocate debt across tranches proportionally (first tranche is senior)
    n_tranches = length(input.debt_terms)
    tranche_balances = if n_tranches == 1
        [total_debt]
    else
        # Split: first tranche gets 60%, remainder split equally
        senior_share = 0.6
        remaining = (1.0 - senior_share) / (n_tranches - 1)
        [i == 1 ? total_debt * senior_share : total_debt * remaining for i in 1:n_tranches]
    end
    original_tranche = copy(tranche_balances)

    # --- Annual Projections ---
    projections = AnnualProjection[]
    current_revenue = input.revenue
    current_debt = sum(tranche_balances)

    for yr in 1:input.hold_years
        current_revenue *= (1.0 + input.revenue_growth)
        ebitda = current_revenue * input.ebitda_margin
        depreciation = current_revenue * input.capex_pct_revenue  # simplified
        capex = current_revenue * input.capex_pct_revenue

        # Interest expense across tranches
        interest = sum(tranche_balances[i] * input.debt_terms[i].rate for i in 1:n_tranches)

        ebt = ebitda - depreciation - interest
        taxes = max(0.0, ebt * input.tax_rate)
        net_income = ebt - taxes

        # Free cash flow = EBITDA - interest - taxes - capex
        fcf = ebitda - interest - taxes - capex

        # Mandatory amortization
        mandatory = 0.0
        for i in 1:n_tranches
            amort = original_tranche[i] * input.debt_terms[i].amortization_pct
            actual_amort = min(amort, tranche_balances[i])
            tranche_balances[i] -= actual_amort
            mandatory += actual_amort
        end

        # Cash sweep on remaining FCF (applied to most senior tranche first)
        sweep = 0.0
        excess = max(0.0, fcf - mandatory)
        sweep_amount = excess * input.cash_sweep_pct
        remaining_sweep = sweep_amount
        for i in 1:n_tranches
            applied = min(remaining_sweep, tranche_balances[i])
            tranche_balances[i] -= applied
            remaining_sweep -= applied
            sweep += applied
            remaining_sweep <= 0.0 && break
        end

        current_debt = sum(tranche_balances)

        push!(projections, AnnualProjection(
            year = yr,
            revenue = current_revenue,
            ebitda = ebitda,
            depreciation = depreciation,
            interest_expense = interest,
            taxes = taxes,
            net_income = net_income,
            capex = capex,
            free_cash_flow = fcf,
            debt_balance = current_debt,
            mandatory_paydown = mandatory,
            cash_sweep = sweep,
        ))
    end

    # --- Exit ---
    exit_ebitda = projections[end].ebitda
    exit_ev = exit_ebitda * input.exit_multiple
    exit_debt = sum(tranche_balances)
    exit_equity = max(0.0, exit_ev - exit_debt)

    # --- IRR (Newton-Raphson) ---
    # Cash flows: [-equity, 0, 0, ..., exit_equity]
    cf = zeros(input.hold_years + 1)
    cf[1] = -equity
    cf[end] = exit_equity
    irr = _newton_irr(cf)

    # --- MOIC ---
    moic = equity > 0.0 ? exit_equity / equity : 0.0

    return LBOResult(
        total_enterprise_value = input.enterprise_value,
        equity_contribution = equity,
        total_debt = input.enterprise_value - equity,
        debt_by_tranche = original_tranche,
        annual_projections = projections,
        exit_ebitda = exit_ebitda,
        exit_enterprise_value = exit_ev,
        exit_debt = exit_debt,
        exit_equity = exit_equity,
        equity_irr = irr,
        moic = moic,
    )
end

"""Newton-Raphson IRR solver for a vector of cash flows at annual intervals."""
function _newton_irr(cash_flows::Vector{Float64}; max_iter::Int=100, tol::Float64=1e-8)::Float64
    rate = 0.10  # initial guess

    for _ in 1:max_iter
        npv = 0.0
        dnpv = 0.0
        for (i, cf) in enumerate(cash_flows)
            t = i - 1
            discount = (1.0 + rate)^(-t)
            npv += cf * discount
            if t > 0
                dnpv -= t * cf * discount / (1.0 + rate)
            end
        end

        abs(npv) < tol && return rate

        abs(dnpv) < 1e-12 && break

        step = npv / dnpv
        # Guard against rate going below -1
        while rate - step <= -0.999
            step *= 0.5
            abs(step) < 1e-15 && return NaN
        end
        rate -= step
        isfinite(rate) || return NaN
    end

    # Fall back to bisection
    return _bisection_irr(cash_flows, -0.99, 10.0)
end

"""Bisection fallback for IRR when Newton-Raphson fails to converge."""
function _bisection_irr(cash_flows::Vector{Float64}, lo::Float64, hi::Float64;
                        max_iter::Int=200, tol::Float64=1e-8)::Float64
    npv_lo = _npv_at_rate(cash_flows, lo)
    npv_hi = _npv_at_rate(cash_flows, hi)

    (!isfinite(npv_lo) || !isfinite(npv_hi)) && return NaN
    npv_lo * npv_hi > 0.0 && return NaN

    for _ in 1:max_iter
        mid = 0.5 * (lo + hi)
        npv_mid = _npv_at_rate(cash_flows, mid)
        !isfinite(npv_mid) && return NaN

        (abs(npv_mid) < tol || abs(hi - lo) < 1e-10) && return mid

        if npv_lo * npv_mid < 0.0
            hi = mid
        else
            lo = mid
            npv_lo = npv_mid
        end
    end
    return 0.5 * (lo + hi)
end

function _npv_at_rate(cash_flows::Vector{Float64}, rate::Float64)::Float64
    total = 0.0
    for (i, cf) in enumerate(cash_flows)
        t = i - 1
        total += cf * (1.0 + rate)^(-t)
    end
    return total
end
