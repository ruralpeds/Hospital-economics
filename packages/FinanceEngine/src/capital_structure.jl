# ── Capital structure and debt analysis ────────────────────────────────────
#
# DSCR, WACC, leverage ratios, bond analysis, capital budgeting, and nonprofit financial engineering.

using Roots: find_zero

# ═══════════════════════════════════════════════════════════════════════════
# A-04: Nonprofit WACC Calculator
# ═══════════════════════════════════════════════════════════════════════════

@kwdef struct WACCCalibration
    cost_of_equity::Float64
    cost_of_debt::Float64
    target_debt_ratio::Float64
    wacc::Float64
end

"""
    calculate_wacc(financials::NamedTuple, balance_sheet::BalanceSheetSnapshot;
                   cost_of_equity_model::Symbol=:capm,
                   tax_exempt::Bool=true,
                   risk_free_rate::Float64=0.04,
                   market_risk_premium::Float64=0.06,
                   beta::Float64=1.0,
                   rating::String="B") -> WACCCalibration

Calculate Weighted Average Cost of Capital for nonprofit hospitals.

Supports :capm, :conservative, :aggressive models for cost_of_equity.
For nonprofits, tax_exempt=true forces no tax shield on debt.
"""
function calculate_wacc(financials::NamedTuple, balance_sheet;
                       cost_of_equity_model::Symbol=:capm,
                       tax_exempt::Bool=true,
                       risk_free_rate::Float64=0.04,
                       market_risk_premium::Float64=0.06,
                       beta::Float64=1.0,
                       rating::String="B")::WACCCalibration

    # Cost of equity via CAPM or variants
    coe = if cost_of_equity_model == :capm
        risk_free_rate + beta * market_risk_premium
    elseif cost_of_equity_model == :conservative
        risk_free_rate + (beta + 0.2) * market_risk_premium
    elseif cost_of_equity_model == :aggressive
        max(risk_free_rate, (risk_free_rate + (beta - 0.2) * market_risk_premium))
    else
        throw(ArgumentError("Unknown cost_of_equity_model: $cost_of_equity_model"))
    end

    # Cost of debt: S&P rating → spread
    rating_spreads = Dict(
        "AAA" => 0.010, "AA" => 0.015, "A" => 0.020, "BBB" => 0.030,
        "BB" => 0.045, "B" => 0.065, "CCC" => 0.100, "CC" => 0.150
    )
    spread = get(rating_spreads, rating, 0.065)  # Default to B if unrecognized
    cod = risk_free_rate + spread

    # Target debt/capitalization
    total_cap = balance_sheet.long_term_debt + balance_sheet.net_assets_unrestricted
    target_debt_ratio = total_cap > 0 ? balance_sheet.long_term_debt / total_cap : 0.3

    # WACC = (E/V) * CoE + (D/V) * CoD * (1 - tax_rate)
    equity_ratio = 1.0 - target_debt_ratio
    tax_rate = tax_exempt ? 0.0 : 0.21
    wacc_val = equity_ratio * coe + target_debt_ratio * cod * (1.0 - tax_rate)

    return WACCCalibration(
        cost_of_equity = coe,
        cost_of_debt = cod,
        target_debt_ratio = target_debt_ratio,
        wacc = wacc_val
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# A-05: Capital Budgeting (IRR, NPV, Payback)
# ═══════════════════════════════════════════════════════════════════════════

@kwdef struct CapexProject
    name::String
    initial_outlay::Float64
    useful_life::Int
    annual_cf::Vector{Float64}
    salvage_value::Float64 = 0.0
    tax_rate::Float64 = 0.0
end

@kwdef struct CapexMetrics
    npv::Float64
    irr::Float64
    payback_years::Float64
    profitability_index::Float64
    pi_rank::Int = 0
end

"""
    calculate_capex_metrics(project::CapexProject, wacc::Float64) -> CapexMetrics

Calculate NPV, IRR, payback period, and profitability index for a capital project.
"""
function calculate_capex_metrics(project::CapexProject, wacc::Float64)::CapexMetrics
    initial = project.initial_outlay
    cfs = project.annual_cf

    # NPV = Σ CF_t / (1 + WACC)^t - Initial_Outlay + Salvage / (1 + WACC)^n
    npv_val = -initial + sum(cfs[t] / (1.0 + wacc)^t for t in 1:length(cfs))
    if !isnan(project.salvage_value) && project.salvage_value > 0.0
        npv_val += project.salvage_value / (1.0 + wacc)^length(cfs)
    end

    # IRR: find rate where NPV = 0
    irr_val = 0.0
    try
        irr_fn(r) = -initial + sum(cfs[t] / (1.0 + r)^t for t in 1:length(cfs)) +
                    (project.salvage_value > 0.0 ? project.salvage_value / (1.0 + r)^length(cfs) : 0.0)
        irr_val = find_zero(irr_fn, (0.0, 1.0); xatol=1e-6)
    catch
        irr_val = NaN
    end

    # Payback period: years until cumsum(CF) ≥ initial_outlay
    cumsum_cf = cumsum(cfs)
    payback = Inf
    for (t, cum) in enumerate(cumsum_cf)
        if cum ≥ initial
            payback = t - 1 + (initial - (t > 1 ? cumsum_cf[t-1] : 0.0)) / cfs[t]
            break
        end
    end
    payback = isfinite(payback) ? payback : length(cfs) + 1.0

    # Profitability Index = (NPV + Initial) / Initial = (PV of inflows) / Initial
    pi = initial > 0 ? (npv_val + initial) / initial : 0.0

    return CapexMetrics(
        npv = npv_val,
        irr = isnan(irr_val) ? 0.0 : irr_val,
        payback_years = payback,
        profitability_index = pi
    )
end

"""
    rank_projects(projects::Vector{CapexProject}, wacc::Float64;
                  budget_constraint::Union{Float64,Nothing}=nothing) -> DataFrame

Rank capital projects by profitability index; optionally solve knapsack within budget.
"""
function rank_projects(projects::Vector{CapexProject}, wacc::Float64;
                       budget_constraint::Union{Float64,Nothing}=nothing)::DataFrame

    rows = NamedTuple[]
    for (idx, p) in enumerate(projects)
        metrics = calculate_capex_metrics(p, wacc)
        push!(rows, (
            name = p.name,
            initial_outlay = p.initial_outlay,
            npv = metrics.npv,
            irr = metrics.irr,
            payback_years = metrics.payback_years,
            profitability_index = metrics.profitability_index,
            pi_rank = 0,
            selected = true
        ))
    end

    df = DataFrame(rows)
    sort!(df, :profitability_index; rev=true)
    df[!, :pi_rank] = 1:nrow(df)

    # Apply budget constraint if provided
    if !isnothing(budget_constraint)
        cumulative = cumsum(df.initial_outlay)
        df[!, :selected] = cumulative .<= budget_constraint
        df[!, :cumulative_investment] = cumulative
    else
        df[!, :cumulative_investment] = cumsum(df.initial_outlay)
    end

    return df
end

"""
    debt_service_coverage_ratio(net_operating_income::Float64,
                                debt_service::Float64) -> Float64

Compute DSCR = NOI / annual debt service.
CMS and rating agencies typically require DSCR ≥ 1.25 for hospital bonds.
"""
function debt_service_coverage_ratio(net_operating_income::Float64,
                                     debt_service::Float64)::Float64
    debt_service > 0 || throw(DomainValidationError("debt_service",
        string(debt_service), "> 0", "Annual debt service must be positive"))
    return net_operating_income / debt_service
end

"""
    days_cash_on_hand(cash_and_investments::Float64, daily_operating_expense::Float64) -> Float64

Compute days cash on hand.  Rating agencies typically want ≥ 150 days for A-rated hospitals.
"""
function days_cash_on_hand(cash_and_investments::Float64,
                           daily_operating_expense::Float64)::Float64
    daily_operating_expense > 0 || throw(DomainValidationError("daily_operating_expense",
        string(daily_operating_expense), "> 0", "Daily operating expense must be positive"))
    return cash_and_investments / daily_operating_expense
end

"""
    current_ratio(current_assets::Float64, current_liabilities::Float64) -> Float64

Current ratio = current assets / current liabilities.  Healthy hospitals target ≥ 2.0.
"""
function current_ratio(current_assets::Float64, current_liabilities::Float64)::Float64
    current_liabilities > 0 || throw(DomainValidationError("current_liabilities",
        string(current_liabilities), "> 0", "Current liabilities must be positive"))
    return current_assets / current_liabilities
end

"""
    debt_to_capitalization(long_term_debt::Float64, net_assets::Float64) -> Float64

Debt-to-capitalization ratio.  Lower is better; typical healthy hospital < 0.40.
"""
function debt_to_capitalization(long_term_debt::Float64, net_assets::Float64)::Float64
    total_cap = long_term_debt + net_assets
    total_cap > 0 || throw(DomainValidationError("total_capitalization",
        string(total_cap), "> 0", "Total capitalization must be positive"))
    return long_term_debt / total_cap
end

"""
    wacc(equity_pct::Float64, debt_pct::Float64, cost_of_equity::Float64,
         cost_of_debt::Float64, tax_rate::Float64) -> Float64

Weighted Average Cost of Capital.
For non-profit hospitals, tax_rate = 0 (tax-exempt bonds).
"""
function wacc(equity_pct::Float64, debt_pct::Float64,
              cost_of_equity::Float64, cost_of_debt::Float64,
              tax_rate::Float64)::Float64
    return equity_pct * cost_of_equity + debt_pct * cost_of_debt * (1 - tax_rate)
end

"""
    bond_price(face_value::Float64, coupon_rate::Float64, yield_rate::Float64,
               periods::Int) -> Float64

Price a fixed-rate bond (annual coupons).
"""
function bond_price(face_value::Float64, coupon_rate::Float64,
                    yield_rate::Float64, periods::Int)::Float64
    periods > 0 || throw(DomainValidationError("periods", string(periods),
        "> 0", "Bond must have at least 1 period"))
    coupon = face_value * coupon_rate
    pv_coupons = sum(coupon / (1 + yield_rate)^t for t in 1:periods)
    pv_face = face_value / (1 + yield_rate)^periods
    return pv_coupons + pv_face
end

"""
    bond_yield_to_maturity(face_value::Float64, price::Float64,
                           coupon_rate::Float64, periods::Int;
                           tol=1e-6, max_iter=100) -> Float64

Compute yield-to-maturity via Newton's method.
"""
function bond_yield_to_maturity(face_value::Float64, price::Float64,
                                coupon_rate::Float64, periods::Int;
                                tol::Float64=1e-6, max_iter::Int=100)::Float64
    coupon = face_value * coupon_rate
    ytm = coupon_rate  # initial guess
    for _ in 1:max_iter
        bp = bond_price(face_value, coupon_rate, ytm, periods)
        # Derivative (numerical)
        dy = 0.0001
        bp_up = bond_price(face_value, coupon_rate, ytm + dy, periods)
        deriv = (bp_up - bp) / dy
        abs(deriv) < 1e-12 && break
        ytm_new = ytm - (bp - price) / deriv
        abs(ytm_new - ytm) < tol && return ytm_new
        ytm = ytm_new
    end
    return ytm
end

"""
    capital_budget_ranking(projects::Vector{NamedTuple}; budget::Float64=Inf) -> DataFrame

Rank capital projects by profitability index and select within budget constraint.

Each project: `(name, initial_investment, npv)`.
"""
function capital_budget_ranking(projects::Vector; budget::Float64=Inf)::DataFrame
    rows = NamedTuple[]
    for p in projects
        pi = p.initial_investment > 0 ? (p.npv + p.initial_investment) / p.initial_investment : 0.0
        push!(rows, (name=p.name, investment=p.initial_investment,
                     npv=p.npv, profitability_index=pi))
    end
    df = DataFrame(rows)
    sort!(df, :profitability_index; rev=true)

    # Select projects within budget
    cumulative = cumsum(df.investment)
    df[!, :selected] = cumulative .<= budget
    df[!, :cumulative_investment] = cumulative
    return df
end

"""
    financial_health_scorecard(metrics::Dict{String,Float64}) -> DataFrame

Compute a financial health scorecard with letter grades.

Expected keys: "operating_margin", "dscr", "days_cash", "current_ratio",
"debt_to_cap", "age_of_plant".
"""
function financial_health_scorecard(metrics::Dict{String,Float64})::DataFrame
    benchmarks = [
        ("Operating Margin",    get(metrics, "operating_margin", 0.0),   [0.04, 0.02, 0.0, -0.02]),
        ("DSCR",                get(metrics, "dscr", 0.0),              [3.0, 2.0, 1.5, 1.0]),
        ("Days Cash on Hand",   get(metrics, "days_cash", 0.0),         [200.0, 150.0, 100.0, 60.0]),
        ("Current Ratio",       get(metrics, "current_ratio", 0.0),     [2.5, 2.0, 1.5, 1.0]),
        ("Debt-to-Cap",         get(metrics, "debt_to_cap", 0.0),       [0.25, 0.35, 0.45, 0.55]),
        ("Average Age of Plant",get(metrics, "age_of_plant", 0.0),      [8.0, 10.0, 12.0, 15.0]),
    ]
    rows = NamedTuple[]
    for (name, value, thresholds) in benchmarks
        # Lower thresholds = better for debt_to_cap and age_of_plant
        inverted = name in ("Debt-to-Cap", "Average Age of Plant")
        grade = if inverted
            value <= thresholds[1] ? "A" : value <= thresholds[2] ? "B" :
            value <= thresholds[3] ? "C" : value <= thresholds[4] ? "D" : "F"
        else
            value >= thresholds[1] ? "A" : value >= thresholds[2] ? "B" :
            value >= thresholds[3] ? "C" : value >= thresholds[4] ? "D" : "F"
        end
        push!(rows, (metric=name, value=value, grade=grade))
    end
    return DataFrame(rows)
end
