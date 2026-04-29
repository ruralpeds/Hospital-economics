"""
    nonprofit_wacc.jl — Nonprofit Hospital Cost of Capital (MBA Gap A-04, A-05)

Extends `capital_structure.jl` with analytics tailored to nonprofit and
governmental hospitals that cannot use standard for-profit CAPM assumptions:

- Tax-exempt municipal bond cost-of-debt curve (AAA→B, FY2026 MMD spreads)
- Unlevered / relevered beta using Hamada equation for nonprofit entities
- `nonprofit_wacc()` — full nonprofit WACC computation
- `mads_headroom()` — Maximum Annual Debt Service covenant calculator
- `synthetic_rating()` — model-based synthetic credit rating (Moody's-style)
- `equivalent_annual_cost()` — A-05 EAC for projects with different lives
- `covenant_dashboard()` — full covenant compliance snapshot

All rates are decimal (0.05 = 5%). Dollar figures in USD.
References: Moody's Medians (2024), S&P USPF Rating Criteria (2023),
Fitch US Not-for-Profit Hospitals (2024), MMD AAA scale (Apr 2026).
"""

using Statistics
using Dates
using Printf

# ─────────────────────────────────────────────────────────────────────────────
# Municipal bond (MMD) yield curve — CY2026 approximate rates
# These are the tax-exempt Municipal Market Data (MMD) AAA benchmark rates
# adjusted by sector spreads for non-profit hospital borrowers.
# ─────────────────────────────────────────────────────────────────────────────

"""
    MMD_AAA_CURVE

Municipal Market Data (MMD) AAA benchmark rates by maturity (approximate,
April 2026). Key: maturity in years → yield (decimal).
"""
const MMD_AAA_CURVE = Dict{Int,Float64}(
     1 => 0.0285,
     2 => 0.0295,
     3 => 0.0305,
     5 => 0.0315,
     7 => 0.0325,
    10 => 0.0330,
    15 => 0.0340,
    20 => 0.0345,
    25 => 0.0350,
    30 => 0.0355,
)

"""
    HOSPITAL_SECTOR_SPREADS

Additional spread over the MMD AAA curve for nonprofit hospital obligors,
by Moody's/S&P/Fitch credit rating (basis points converted to decimal).
"""
const HOSPITAL_SECTOR_SPREADS = Dict{String,Float64}(
    "Aaa/AAA" => 0.0010,
    "Aa1/AA+" => 0.0025,
    "Aa2/AA"  => 0.0040,
    "Aa3/AA-" => 0.0065,
    "A1/A+"   => 0.0090,
    "A2/A"    => 0.0120,
    "A3/A-"   => 0.0160,
    "Baa1/BBB+"=> 0.0220,
    "Baa2/BBB" => 0.0290,
    "Baa3/BBB-"=> 0.0370,
    "Ba1/BB+"  => 0.0500,
    "Ba2/BB"   => 0.0650,
    "B1/B+"    => 0.0850,
    "NR"       => 0.1000,   # not rated — proxy
)

"""
    mmd_yield(maturity_years::Int; rating="A2/A") -> Float64

Return the tax-exempt municipal bond yield for a nonprofit hospital at the
given maturity and credit rating (MMD AAA + sector spread).

If the exact maturity is not in the curve, interpolates linearly.

# Example
```julia
mmd_yield(10; rating="A2/A")   # ~0.0450 (4.50%)
mmd_yield(30; rating="Baa2/BBB") # ~0.0645
```
"""
function mmd_yield(maturity_years::Int; rating::String = "A2/A")::Float64
    spread = get(HOSPITAL_SECTOR_SPREADS, rating, 0.0650)

    # Interpolate MMD AAA curve
    keys_sorted = sort(collect(keys(MMD_AAA_CURVE)))
    if maturity_years <= keys_sorted[1]
        base = MMD_AAA_CURVE[keys_sorted[1]]
    elseif maturity_years >= keys_sorted[end]
        base = MMD_AAA_CURVE[keys_sorted[end]]
    else
        lo = last(filter(k -> k <= maturity_years, keys_sorted))
        hi = first(filter(k -> k >= maturity_years, keys_sorted))
        lo == hi && return MMD_AAA_CURVE[lo] + spread
        frac = (maturity_years - lo) / (hi - lo)
        base = MMD_AAA_CURVE[lo] + frac * (MMD_AAA_CURVE[hi] - MMD_AAA_CURVE[lo])
    end

    base + spread
end

# ─────────────────────────────────────────────────────────────────────────────
# Hamada levered / unlevered beta for nonprofits
# ─────────────────────────────────────────────────────────────────────────────

"""
    hamada_unlever(levered_beta, debt_ratio; tax_rate=0.0) -> Float64

Unlever an observed beta using the Hamada equation.

For nonprofit hospitals `tax_rate = 0.0` (tax-exempt), so:
  β_u = β_L / (1 + D/E)
where D/E = `debt_ratio / (1 - debt_ratio)`.
"""
function hamada_unlever(levered_beta::Float64, debt_ratio::Float64;
                        tax_rate::Float64 = 0.0)::Float64
    0.0 <= debt_ratio < 1.0 || throw(ArgumentError("debt_ratio must be in [0,1)"))
    D_E = debt_ratio / (1.0 - debt_ratio)
    levered_beta / (1.0 + (1.0 - tax_rate) * D_E)
end

"""
    hamada_relever(unlevered_beta, debt_ratio; tax_rate=0.0) -> Float64

Relever an unlevered (asset) beta for a target capital structure.

For nonprofit hospitals `tax_rate = 0.0`:
  β_L = β_u × (1 + D/E)
"""
function hamada_relever(unlevered_beta::Float64, debt_ratio::Float64;
                         tax_rate::Float64 = 0.0)::Float64
    0.0 <= debt_ratio < 1.0 || throw(ArgumentError("debt_ratio must be in [0,1)"))
    D_E = debt_ratio / (1.0 - debt_ratio)
    unlevered_beta * (1.0 + (1.0 - tax_rate) * D_E)
end

# ─────────────────────────────────────────────────────────────────────────────
# A-04 — Nonprofit WACC
# ─────────────────────────────────────────────────────────────────────────────

"""
    NonprofitWACCInputs

All inputs needed to compute a nonprofit hospital's WACC.

# Fields
- `long_term_debt::Float64`: Outstanding long-term debt (USD).
- `net_assets_unrestricted::Float64`: Unrestricted net assets (proxy for equity, USD).
- `annual_debt_service::Float64`: Annual principal + interest payments (USD).
- `bond_maturity_years::Int`: Weighted average maturity of outstanding bonds.
- `rating::String`: Current credit rating (use keys of `HOSPITAL_SECTOR_SPREADS`).
- `unlevered_beta::Float64`: Asset beta from comparable nonprofit hospital peers
  (typical range 0.3–0.7 for rural hospitals).
- `risk_free_rate::Float64`: Current 10-year Treasury yield (decimal).
- `market_risk_premium::Float64`: Equity market risk premium (decimal, default 0.055).
- `size_premium::Float64`: Small-hospital illiquidity premium (decimal, default 0.02).
"""
@kwdef struct NonprofitWACCInputs
    long_term_debt::Float64
    net_assets_unrestricted::Float64
    annual_debt_service::Float64
    bond_maturity_years::Int               = 20
    rating::String                         = "A2/A"
    unlevered_beta::Float64                = 0.50
    risk_free_rate::Float64                = 0.043    # 10-yr Treasury Apr 2026
    market_risk_premium::Float64           = 0.055
    size_premium::Float64                  = 0.020
end

"""
    NonprofitWACCResult

Decomposed WACC result for a nonprofit hospital.

# Fields
- `debt_ratio`, `equity_ratio`
- `cost_of_debt_pretax::Float64`: MMD yield at rating + maturity.
- `cost_of_debt_aftertax::Float64`: Same as pretax for nonprofits (tax rate = 0).
- `levered_beta::Float64`: Relevered beta at actual capital structure.
- `cost_of_equity::Float64`: CAPM + size premium.
- `wacc::Float64`: Blended WACC.
- `taxable_equivalent_cod::Float64`: What the COD would be for a for-profit at 21% tax.
"""
struct NonprofitWACCResult
    debt_ratio::Float64
    equity_ratio::Float64
    cost_of_debt_pretax::Float64
    cost_of_debt_aftertax::Float64
    levered_beta::Float64
    cost_of_equity::Float64
    wacc::Float64
    taxable_equivalent_cod::Float64
end

function Base.show(io::IO, r::NonprofitWACCResult)
    println(io, "NonprofitWACCResult")
    println(io, "  Capital structure:  $(round(r.debt_ratio*100,digits=1))% debt / $(round(r.equity_ratio*100,digits=1))% equity")
    println(io, "  Cost of debt:       $(round(r.cost_of_debt_pretax*100,digits=2))% (tax-exempt)")
    println(io, "  Levered beta:       $(round(r.levered_beta,digits=3))")
    println(io, "  Cost of equity:     $(round(r.cost_of_equity*100,digits=2))%")
    println(io, "  WACC:               $(round(r.wacc*100,digits=2))%")
    println(io, "  Taxable-equiv COD:  $(round(r.taxable_equivalent_cod*100,digits=2))% (for reference)")
end

"""
    nonprofit_wacc(inputs::NonprofitWACCInputs) -> NonprofitWACCResult

Compute the weighted average cost of capital for a nonprofit hospital.

Key differences from for-profit WACC:
1. **Tax rate = 0%** — tax-exempt status means no interest tax shield.
2. **Cost of debt** is the MMD municipal bond yield at the hospital's rating
   and bond maturity (not a corporate spread over Treasuries).
3. **Levered beta** is computed via Hamada relevering from a peer-based
   unlevered beta (no tax shield in denominator).
4. **Cost of equity** is CAPM + size premium — used as the hurdle rate for
   internal capital allocation, not as a literal equity return since nonprofits
   have no public equity.

# Example
```julia
inputs = NonprofitWACCInputs(
    long_term_debt            = 25_000_000.0,
    net_assets_unrestricted   = 30_000_000.0,
    annual_debt_service       = 2_100_000.0,
    bond_maturity_years       = 20,
    rating                    = "A3/A-",
    unlevered_beta            = 0.45,
)
r = nonprofit_wacc(inputs)
r.wacc   # e.g. 0.0521 (5.21%)
```
"""
function nonprofit_wacc(inputs::NonprofitWACCInputs)::NonprofitWACCResult
    total_cap = inputs.long_term_debt + inputs.net_assets_unrestricted
    total_cap > 0 || throw(ArgumentError("long_term_debt + net_assets_unrestricted must be > 0"))

    debt_ratio   = inputs.long_term_debt / total_cap
    equity_ratio = 1.0 - debt_ratio

    # Cost of debt: MMD tax-exempt yield at rating + maturity
    cod = mmd_yield(inputs.bond_maturity_years; rating = inputs.rating)

    # Relever peer unlevered beta to this hospital's capital structure (tax_rate = 0)
    lev_beta = hamada_relever(inputs.unlevered_beta, debt_ratio; tax_rate = 0.0)

    # Cost of equity: CAPM + size premium
    coe = inputs.risk_free_rate + lev_beta * inputs.market_risk_premium + inputs.size_premium

    # WACC (no tax shield for nonprofit)
    wacc_val = equity_ratio * coe + debt_ratio * cod

    # Taxable equivalent for comparison
    taxable_equiv = cod / (1.0 - 0.21)

    NonprofitWACCResult(debt_ratio, equity_ratio, cod, cod, lev_beta, coe, wacc_val, taxable_equiv)
end

# ─────────────────────────────────────────────────────────────────────────────
# A-04 — MADS headroom and covenant calculator
# ─────────────────────────────────────────────────────────────────────────────

"""
    DebtCovenantInputs

Financial inputs needed for debt covenant compliance testing.

# Key covenants modelled
- **MADS DSCR**: Net operating income / Maximum Annual Debt Service ≥ floor.
- **Days Cash on Hand (DCOH)**: Cash / (operating expenses ÷ 365) ≥ floor.
- **Debt-to-Capitalization**: Long-term debt / (debt + net assets) ≤ ceiling.
- **Operating margin**: ≥ floor.
"""
@kwdef struct DebtCovenantInputs
    # Income statement
    net_patient_revenue::Float64
    total_operating_expenses::Float64
    non_operating_income::Float64           = 0.0

    # Balance sheet
    cash_and_investments::Float64
    long_term_debt::Float64
    net_assets_unrestricted::Float64
    current_assets::Float64
    current_liabilities::Float64

    # Debt service
    max_annual_debt_service::Float64        # MADS: maximum debt service in any future year
    current_annual_debt_service::Float64

    # Covenant floors / ceilings (typical indenture language)
    mads_dscr_floor::Float64               = 1.10  # 110% MADS DSCR
    dcoh_floor_days::Float64               = 55.0  # 55 days cash
    debt_to_cap_ceiling::Float64           = 0.65   # 65% max debt/cap
    operating_margin_floor::Float64        = 0.0    # break-even minimum
end

"""
    CovenantCompliance

Per-covenant compliance status and headroom.

# Fields
- `name::String`
- `actual::Float64`: Computed metric value.
- `threshold::Float64`: Covenant floor or ceiling.
- `headroom::Float64`: Actual − threshold (positive = compliant).
- `compliant::Bool`
- `note::String`
"""
struct CovenantCompliance
    name::String
    actual::Float64
    threshold::Float64
    headroom::Float64
    compliant::Bool
    note::String
end

"""
    CovenantDashboard

Full set of covenant compliance results.

# Fields
- `covenants::Vector{CovenantCompliance}`
- `all_compliant::Bool`
- `critical_violations::Vector{String}`: Names of non-compliant covenants.
- `waiver_risk_score::Float64`: 0–100; higher = closer to covenant breach.
"""
struct CovenantDashboard
    covenants::Vector{CovenantCompliance}
    all_compliant::Bool
    critical_violations::Vector{String}
    waiver_risk_score::Float64
end

"""
    mads_headroom(inputs::DebtCovenantInputs) -> NamedTuple

Compute the Maximum Annual Debt Service (MADS) debt-service coverage ratio
and the margin of safety before a covenant breach.

# Returns
- `mads_dscr::Float64`: NOI / MADS.
- `income_at_mads_floor::Float64`: Operating income required to meet the MADS floor.
- `income_shortfall::Float64`: Current NOI − income_at_mads_floor (negative = shortfall).
- `mads_headroom_pct::Float64`: How far above the floor (percentage of MADS).
- `compliant::Bool`

MADS DSCR is the most commonly tested covenant in nonprofit hospital bond
indentures (typical floor: 1.10×). Violation triggers events of default or
acceleration of the bond.
"""
function mads_headroom(inputs::DebtCovenantInputs)::NamedTuple
    noi = (inputs.net_patient_revenue + inputs.non_operating_income
           - inputs.total_operating_expenses)
    mads_dscr = inputs.max_annual_debt_service > 0 ?
        noi / inputs.max_annual_debt_service : Inf
    required_noi = inputs.mads_dscr_floor * inputs.max_annual_debt_service
    shortfall    = noi - required_noi
    headroom_pct = inputs.max_annual_debt_service > 0 ?
        (mads_dscr - inputs.mads_dscr_floor) / inputs.mads_dscr_floor * 100 : NaN

    (
        mads_dscr            = mads_dscr,
        income_at_mads_floor = required_noi,
        income_shortfall     = shortfall,
        mads_headroom_pct    = headroom_pct,
        compliant            = mads_dscr >= inputs.mads_dscr_floor,
    )
end

"""
    covenant_dashboard(inputs::DebtCovenantInputs) -> CovenantDashboard

Compute all four standard covenant metrics and return a compliance dashboard.

Used to flag hospitals approaching covenant triggers and quantify the
distance to a waiver request or bond acceleration event.
"""
function covenant_dashboard(inputs::DebtCovenantInputs)::CovenantDashboard
    noi = inputs.net_patient_revenue + inputs.non_operating_income -
          inputs.total_operating_expenses
    rev = inputs.net_patient_revenue
    exp = inputs.total_operating_expenses

    mads_dscr_val = inputs.max_annual_debt_service > 0 ?
        noi / inputs.max_annual_debt_service : Inf
    dcoh_val = exp > 0 ?
        inputs.cash_and_investments / (exp / 365) : Inf
    total_cap = inputs.long_term_debt + inputs.net_assets_unrestricted
    d2c_val = total_cap > 0 ? inputs.long_term_debt / total_cap : 0.0
    om_val  = rev > 0 ? (rev - exp) / rev : NaN

    covenants = CovenantCompliance[
        CovenantCompliance(
            "MADS DSCR",
            mads_dscr_val, inputs.mads_dscr_floor,
            mads_dscr_val - inputs.mads_dscr_floor,
            mads_dscr_val >= inputs.mads_dscr_floor,
            @sprintf("%.2fx actual vs %.2fx floor (MADS = \$%,.0f)",
                mads_dscr_val, inputs.mads_dscr_floor, inputs.max_annual_debt_service),
        ),
        CovenantCompliance(
            "Days Cash on Hand",
            dcoh_val, inputs.dcoh_floor_days,
            dcoh_val - inputs.dcoh_floor_days,
            dcoh_val >= inputs.dcoh_floor_days,
            @sprintf("%.1f days actual vs %.0f day floor", dcoh_val, inputs.dcoh_floor_days),
        ),
        CovenantCompliance(
            "Debt-to-Capitalization",
            d2c_val, inputs.debt_to_cap_ceiling,
            inputs.debt_to_cap_ceiling - d2c_val,   # positive = below ceiling = compliant
            d2c_val <= inputs.debt_to_cap_ceiling,
            @sprintf("%.1f%% actual vs %.0f%% ceiling", d2c_val*100, inputs.debt_to_cap_ceiling*100),
        ),
        CovenantCompliance(
            "Operating Margin",
            om_val, inputs.operating_margin_floor,
            om_val - inputs.operating_margin_floor,
            isnan(om_val) ? false : om_val >= inputs.operating_margin_floor,
            @sprintf("%.2f%% actual vs %.1f%% floor", om_val*100, inputs.operating_margin_floor*100),
        ),
    ]

    violations = [c.name for c in covenants if !c.compliant]

    # Waiver risk: average of (1 - headroom_fraction) for each covenant, scaled 0-100
    risk_components = Float64[]
    for c in covenants
        range = abs(c.threshold)
        range < 1e-6 && continue
        frac = clamp(1.0 - c.headroom / range, 0.0, 1.0)
        push!(risk_components, frac)
    end
    waiver_risk = isempty(risk_components) ? 0.0 : mean(risk_components) * 100.0

    CovenantDashboard(covenants, isempty(violations), violations, waiver_risk)
end

# ─────────────────────────────────────────────────────────────────────────────
# A-04 — Synthetic credit rating model
# ─────────────────────────────────────────────────────────────────────────────

"""
    SyntheticRatingInputs

Financial ratios used to determine a synthetic credit rating.
All ratios should be trailing-twelve-month values.

Based on Moody's Public Finance Medians (2024) and Fitch Rating Criteria for
U.S. Not-for-Profit Hospitals.
"""
@kwdef struct SyntheticRatingInputs
    # Profitability
    operating_margin_pct::Float64         # Operating income / revenue (%)
    excess_margin_pct::Float64            # Excess of revenue over expenses / revenue (%)

    # Liquidity
    days_cash_on_hand::Float64            # Days
    cash_to_debt_pct::Float64             # Cash & investments / long-term debt (%)

    # Leverage / capital structure
    debt_to_cap_pct::Float64              # Long-term debt / (debt + net assets) (%)
    mads_dscr::Float64                    # NOI / MADS (times)

    # Volume / scale
    annual_revenue_millions::Float64      # Net patient revenue ($M)

    # Optional adjustments
    system_affiliation::Bool = false      # +1 notch for strong system membership
    sole_community::Bool     = false      # +0.5 notch for SCH/CAH protections
end

"""
    synthetic_rating(inputs::SyntheticRatingInputs) -> NamedTuple

Compute a model-based synthetic credit rating using Moody's median scorecard
approach. Returns:
- `rating_numeric::Float64`: Internal score (lower = better; 1=Aaa, 21=C)
- `moody_equivalent::String`: Moody's rating label
- `sp_equivalent::String`: S&P equivalent label
- `category::Symbol`: `:investment_grade`, `:non_investment_grade`, or `:distressed`
- `score_detail::NamedTuple`: Sub-scores by dimension

**Scoring methodology** (based on Moody's NFP Hospital Rating Scorecard):
Each dimension scores 1 (best) to 5 (worst). Weighted average across dimensions
maps to a rating notch.

| Dimension | Weight |
|---|---|
| Profitability (operating + excess margin) | 30% |
| Liquidity (DCOH + cash/debt) | 25% |
| Leverage (D/cap + MADS DSCR) | 30% |
| Scale (revenue) | 15% |
"""
function synthetic_rating(inputs::SyntheticRatingInputs)

    # Profitability (30%)
    op_score = inputs.operating_margin_pct >= 4.0 ? 1 :
               inputs.operating_margin_pct >= 2.0 ? 2 :
               inputs.operating_margin_pct >= 0.5 ? 3 :
               inputs.operating_margin_pct >= -1.0 ? 4 : 5
    ex_score = inputs.excess_margin_pct >= 5.0 ? 1 :
               inputs.excess_margin_pct >= 3.0 ? 2 :
               inputs.excess_margin_pct >= 1.0 ? 3 :
               inputs.excess_margin_pct >= -0.5 ? 4 : 5
    profit_score = (op_score + ex_score) / 2.0

    # Liquidity (25%)
    dcoh_score = inputs.days_cash_on_hand >= 200 ? 1 :
                 inputs.days_cash_on_hand >= 120 ? 2 :
                 inputs.days_cash_on_hand >= 65  ? 3 :
                 inputs.days_cash_on_hand >= 30  ? 4 : 5
    c2d_score  = inputs.cash_to_debt_pct >= 130 ? 1 :
                 inputs.cash_to_debt_pct >= 80  ? 2 :
                 inputs.cash_to_debt_pct >= 40  ? 3 :
                 inputs.cash_to_debt_pct >= 15  ? 4 : 5
    liq_score  = (dcoh_score + c2d_score) / 2.0

    # Leverage (30%)
    d2c_score  = inputs.debt_to_cap_pct <= 25 ? 1 :
                 inputs.debt_to_cap_pct <= 40 ? 2 :
                 inputs.debt_to_cap_pct <= 55 ? 3 :
                 inputs.debt_to_cap_pct <= 68 ? 4 : 5
    dscr_score = inputs.mads_dscr >= 3.5 ? 1 :
                 inputs.mads_dscr >= 2.5 ? 2 :
                 inputs.mads_dscr >= 1.5 ? 3 :
                 inputs.mads_dscr >= 1.0 ? 4 : 5
    lev_score  = (d2c_score + dscr_score) / 2.0

    # Scale (15%)
    rev = inputs.annual_revenue_millions
    scale_score = rev >= 500 ? 1 : rev >= 200 ? 2 : rev >= 75 ? 3 : rev >= 25 ? 4 : 5

    # Weighted composite
    composite = (0.30 * profit_score + 0.25 * liq_score +
                 0.30 * lev_score   + 0.15 * scale_score)

    # Adjustments
    adj = 0.0
    inputs.system_affiliation && (adj -= 0.5)   # better (lower) score
    inputs.sole_community     && (adj -= 0.25)

    composite = clamp(composite + adj, 1.0, 5.0)

    # Map to rating
    RATING_MAP = [
        (1.0, 1.4, "Aaa", "AAA", :investment_grade),
        (1.4, 1.7, "Aa1", "AA+", :investment_grade),
        (1.7, 2.0, "Aa2", "AA",  :investment_grade),
        (2.0, 2.3, "Aa3", "AA-", :investment_grade),
        (2.3, 2.6, "A1",  "A+",  :investment_grade),
        (2.6, 2.9, "A2",  "A",   :investment_grade),
        (2.9, 3.2, "A3",  "A-",  :investment_grade),
        (3.2, 3.5, "Baa1","BBB+",:investment_grade),
        (3.5, 3.75,"Baa2","BBB", :investment_grade),
        (3.75,4.0, "Baa3","BBB-",:investment_grade),
        (4.0, 4.3, "Ba1", "BB+", :non_investment_grade),
        (4.3, 4.6, "Ba2", "BB",  :non_investment_grade),
        (4.6, 5.0, "B1",  "B+",  :distressed),
        (5.0, 5.1, "B2",  "B",   :distressed),
    ]
    moody_eq, sp_eq, cat = "B2", "B", :distressed
    for (lo, hi, m, s, c) in RATING_MAP
        if composite < hi
            moody_eq, sp_eq, cat = m, s, c
            break
        end
    end

    (
        rating_numeric = composite,
        moody_equivalent = moody_eq,
        sp_equivalent    = sp_eq,
        category         = cat,
        score_detail     = (
            profitability_score = profit_score,
            liquidity_score     = liq_score,
            leverage_score      = lev_score,
            scale_score         = scale_score,
            adjustments         = adj,
            composite           = composite,
        ),
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# A-05 — Equivalent Annual Cost (missing piece from existing irr/mirr/pi)
# ─────────────────────────────────────────────────────────────────────────────

"""
    equivalent_annual_cost(total_npv_cost::Float64, wacc::Float64,
                           life_years::Int) -> Float64

Convert the net present value of total costs for a capital project into an
annualised cost (EAC) using the capital recovery factor. Used to compare
projects with different useful lives on a per-year basis.

EAC = NPV_cost × WACC / (1 − (1 + WACC)^−n)

When `wacc ≈ 0`, falls back to simple average: EAC = NPV_cost / n.

# Example
```julia
# A CT scanner costing \$1.2M NPV over 8 years vs an MRI at \$3M over 15 years
eac_ct  = equivalent_annual_cost(1_200_000, 0.05, 8)   # ~\$187,000/yr
eac_mri = equivalent_annual_cost(3_000_000, 0.05, 15)  # ~\$289,000/yr
# → CT scanner is cheaper per year
```
"""
function equivalent_annual_cost(total_npv_cost::Float64,
                                 wacc::Float64,
                                 life_years::Int)::Float64
    life_years >= 1 || throw(ArgumentError("life_years must be ≥ 1"))
    total_npv_cost >= 0 || throw(ArgumentError("total_npv_cost must be ≥ 0"))
    abs(wacc) < 1e-9 && return total_npv_cost / life_years
    crf = wacc / (1 - (1 + wacc)^(-life_years))
    total_npv_cost * crf
end
