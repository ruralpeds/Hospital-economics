# ── Capital structure and debt analysis ────────────────────────────────────
#
# DSCR, WACC, leverage ratios, bond analysis, and capital budgeting.

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
