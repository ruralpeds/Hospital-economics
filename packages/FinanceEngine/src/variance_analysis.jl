"""
    variance_analysis.jl — Revenue Cycle Variance Analysis (MBA Gap C-03)

Implements a three-way bridge decomposing the change in net patient revenue
between two periods (prior vs. current) into:

  ΔRevenue = Price Variance + Volume Variance + Mix Variance

This is the standard CFO-level explanation for why revenue changed: did rates
go up/down, did volume change, or did the case mix shift toward higher/lower
acuity cases? The three components sum exactly to ΔRevenue.

## Methodology
Follows the classic flex-budget variance framework adapted for healthcare
revenue (Gapenski & Pink, Healthcare Finance, 6th ed.):

  Price variance  = (Current rate − Prior rate) × Current volume × Current CMI
  Volume variance = (Current vol  − Prior vol)  × Prior rate × Prior CMI
  Mix variance    = (Current CMI  − Prior CMI)  × Current volume × Prior rate

Where CMI = Case Mix Index (average DRG weight / acuity proxy).
The three sum to ΔRevenue = Current revenue − Prior revenue.

For payer-level analysis, the decomposition runs per payer and rolls up.
"""

using Statistics
using Printf
using Dates

# ─────────────────────────────────────────────────────────────────────────────
# Core types
# ─────────────────────────────────────────────────────────────────────────────

"""
    RevenuePeriod

Financial and operational data for one period (prior or current).

# Fields
- `label::String`: Period label (e.g. "FY2024 Q3").
- `net_patient_revenue::Float64`: Total net patient revenue (USD).
- `total_cases::Int`: Discharges or encounters.
- `case_mix_index::Float64`: Average DRG weight or acuity proxy (default 1.0 if unknown).
- `net_revenue_per_case::Float64`: `net_patient_revenue / total_cases`.
- `rate_per_cmi_unit::Float64`: `net_revenue_per_case / case_mix_index` — pure rate
  excluding acuity effects.
"""
@kwdef struct RevenuePeriod
    label::String
    net_patient_revenue::Float64
    total_cases::Int
    case_mix_index::Float64          = 1.0
    net_revenue_per_case::Float64    = net_patient_revenue / total_cases
    rate_per_cmi_unit::Float64       = (net_patient_revenue / total_cases) / case_mix_index
end

"""
    PayerRevenuePeriod

Per-payer revenue data for one period.

# Fields
- `payer::String`: Payer name (e.g. "Medicare", "Medicaid", "Commercial").
- `net_revenue::Float64`
- `cases::Int`
- `case_mix_index::Float64`
"""
@kwdef struct PayerRevenuePeriod
    payer::String
    net_revenue::Float64
    cases::Int
    case_mix_index::Float64 = 1.0
end

# ─────────────────────────────────────────────────────────────────────────────
# Aggregate variance decomposition
# ─────────────────────────────────────────────────────────────────────────────

"""
    VarianceBridge

Three-way revenue variance bridge result.

# Fields
- `prior::RevenuePeriod`, `current::RevenuePeriod`
- `delta_revenue::Float64`: Total ΔRevenue = current − prior.
- `price_variance::Float64`: Rate × CMI component.
- `volume_variance::Float64`: Volume component.
- `mix_variance::Float64`: Case-mix-index component.
- `check_sum_error::Float64`: Should be < 1e-6 if decomposition is correct.
- `price_pct::Float64`, `volume_pct::Float64`, `mix_pct::Float64`:
  Each variance as % of prior revenue.
"""
struct VarianceBridge
    prior::RevenuePeriod
    current::RevenuePeriod
    delta_revenue::Float64
    price_variance::Float64
    volume_variance::Float64
    mix_variance::Float64
    check_sum_error::Float64
    price_pct::Float64
    volume_pct::Float64
    mix_pct::Float64
end

"""
    revenue_variance_bridge(prior::RevenuePeriod, current::RevenuePeriod) -> VarianceBridge

Decompose ΔRevenue into price, volume, and mix components.

## Formulae
Let:
  r₀, r₁ = rate_per_cmi_unit (prior, current)
  v₀, v₁ = total_cases (prior, current)
  c₀, c₁ = case_mix_index (prior, current)

  Price variance  = (r₁ − r₀) × v₁ × c₁
  Volume variance = (v₁ − v₀) × r₀ × c₀
  Mix variance    = (c₁ − c₀) × v₁ × r₀

  Sum = r₁v₁c₁ − r₀v₀c₀ = current_revenue − prior_revenue ✓

# Example
```julia
prior   = RevenuePeriod(label="Q3 FY24", net_patient_revenue=8_500_000,
                        total_cases=840, case_mix_index=1.42)
current = RevenuePeriod(label="Q4 FY24", net_patient_revenue=8_950_000,
                        total_cases=870, case_mix_index=1.48)
bridge  = revenue_variance_bridge(prior, current)
bridge.price_variance   # rate improvement drove \$X
bridge.volume_variance  # volume growth drove \$Y
bridge.mix_variance     # CMI shift drove \$Z
```
"""
function revenue_variance_bridge(prior::RevenuePeriod,
                                  current::RevenuePeriod)::VarianceBridge
    prior.total_cases > 0 || throw(ArgumentError("prior.total_cases must be > 0"))
    current.total_cases > 0 || throw(ArgumentError("current.total_cases must be > 0"))

    r₀ = prior.rate_per_cmi_unit
    r₁ = current.rate_per_cmi_unit
    v₀ = Float64(prior.total_cases)
    v₁ = Float64(current.total_cases)
    c₀ = prior.case_mix_index
    c₁ = current.case_mix_index

    price_var  = (r₁ - r₀) * v₁ * c₁
    volume_var = (v₁ - v₀) * r₀ * c₀
    mix_var    = (c₁ - c₀) * v₁ * r₀

    delta_rev  = current.net_patient_revenue - prior.net_patient_revenue
    check_err  = abs(price_var + volume_var + mix_var - delta_rev)
    base_rev   = prior.net_patient_revenue

    VarianceBridge(
        prior, current,
        delta_rev,
        price_var, volume_var, mix_var,
        check_err,
        base_rev > 0 ? price_var  / base_rev * 100 : NaN,
        base_rev > 0 ? volume_var / base_rev * 100 : NaN,
        base_rev > 0 ? mix_var    / base_rev * 100 : NaN,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Payer-level variance analysis
# ─────────────────────────────────────────────────────────────────────────────

"""
    PayerVarianceRow

Per-payer contribution to the total revenue variance bridge.

# Fields
- `payer::String`
- `delta_revenue::Float64`: Total ΔRevenue for this payer.
- `price_variance::Float64`
- `volume_variance::Float64`
- `mix_variance::Float64`
- `share_of_total_delta::Float64`: This payer's ΔRevenue as % of total ΔRevenue.
- `prior_revenue::Float64`, `current_revenue::Float64`
"""
struct PayerVarianceRow
    payer::String
    delta_revenue::Float64
    price_variance::Float64
    volume_variance::Float64
    mix_variance::Float64
    share_of_total_delta::Float64
    prior_revenue::Float64
    current_revenue::Float64
end

"""
    PayerVarianceBridge

Full payer-level variance decomposition.

# Fields
- `rows::Vector{PayerVarianceRow}`: One per payer, sorted by |delta_revenue| descending.
- `total_delta_revenue::Float64`
- `total_price_variance::Float64`
- `total_volume_variance::Float64`
- `total_mix_variance::Float64`
- `check_sum_error::Float64`
"""
struct PayerVarianceBridge
    rows::Vector{PayerVarianceRow}
    total_delta_revenue::Float64
    total_price_variance::Float64
    total_volume_variance::Float64
    total_mix_variance::Float64
    check_sum_error::Float64
end

"""
    payer_variance_bridge(
        prior_payers::Vector{PayerRevenuePeriod},
        current_payers::Vector{PayerRevenuePeriod}
    ) -> PayerVarianceBridge

Run per-payer revenue variance decomposition.

Payers present in one period but not the other are handled by treating the
missing period as zero revenue / zero cases (entry or exit of a payer).

# Example
```julia
prior = [
    PayerRevenuePeriod(payer="Medicare",    net_revenue=4_000_000, cases=410, case_mix_index=1.85),
    PayerRevenuePeriod(payer="Medicaid",    net_revenue=2_000_000, cases=220, case_mix_index=0.95),
    PayerRevenuePeriod(payer="Commercial",  net_revenue=2_500_000, cases=210, case_mix_index=1.20),
]
current = [
    PayerRevenuePeriod(payer="Medicare",    net_revenue=4_300_000, cases=420, case_mix_index=1.90),
    PayerRevenuePeriod(payer="Medicaid",    net_revenue=1_950_000, cases=210, case_mix_index=0.92),
    PayerRevenuePeriod(payer="Commercial",  net_revenue=2_700_000, cases=240, case_mix_index=1.22),
]
bridge = payer_variance_bridge(prior, current)
```
"""
function payer_variance_bridge(
    prior_payers::Vector{PayerRevenuePeriod},
    current_payers::Vector{PayerRevenuePeriod},
)::PayerVarianceBridge

    # Index by payer name
    prior_idx   = Dict(p.payer => p for p in prior_payers)
    current_idx = Dict(p.payer => p for p in current_payers)
    all_payers  = union(keys(prior_idx), keys(current_idx)) |> collect |> sort

    total_delta = sum(get(current_idx, payer, nothing) !== nothing ?
                      current_idx[payer].net_revenue : 0.0 for payer in all_payers) -
                  sum(get(prior_idx, payer, nothing) !== nothing ?
                      prior_idx[payer].net_revenue : 0.0 for payer in all_payers)

    rows = PayerVarianceRow[]
    for payer in all_payers
        p0 = get(prior_idx, payer, nothing)
        p1 = get(current_idx, payer, nothing)

        rev0 = isnothing(p0) ? 0.0 : p0.net_revenue
        rev1 = isnothing(p1) ? 0.0 : p1.net_revenue
        v0   = isnothing(p0) ? 0.0 : Float64(p0.cases)
        v1   = isnothing(p1) ? 0.0 : Float64(p1.cases)
        c0   = isnothing(p0) ? 1.0 : p0.case_mix_index
        c1   = isnothing(p1) ? 1.0 : p1.case_mix_index
        r0   = (v0 > 0 && c0 > 0) ? rev0 / (v0 * c0) : 0.0
        r1   = (v1 > 0 && c1 > 0) ? rev1 / (v1 * c1) : 0.0

        price_v  = (r1 - r0) * v1 * c1
        volume_v = (v1 - v0) * r0 * c0
        mix_v    = (c1 - c0) * v1 * r0
        delta    = rev1 - rev0
        share    = abs(total_delta) > 1e-6 ? delta / total_delta * 100 : NaN

        push!(rows, PayerVarianceRow(payer, delta, price_v, volume_v, mix_v,
                                     share, rev0, rev1))
    end

    sort!(rows; by=r -> -abs(r.delta_revenue))

    tot_price  = sum(r.price_variance  for r in rows)
    tot_volume = sum(r.volume_variance for r in rows)
    tot_mix    = sum(r.mix_variance    for r in rows)
    check_err  = abs(tot_price + tot_volume + tot_mix - total_delta)

    PayerVarianceBridge(rows, total_delta, tot_price, tot_volume, tot_mix, check_err)
end

# ─────────────────────────────────────────────────────────────────────────────
# Expense variance (additional C-03 coverage)
# ─────────────────────────────────────────────────────────────────────────────

"""
    ExpenseVarianceBridge

Two-way expense variance: spending variance + efficiency variance.

  ΔExpense = Spending Variance + Efficiency Variance
  Spending variance  = (actual unit cost − budgeted unit cost) × actual volume
  Efficiency variance = (actual volume − budgeted volume) × budgeted unit cost

# Fields
- `category::String`: Expense category (e.g. "Salaries", "Supplies").
- `budgeted_unit_cost::Float64`, `actual_unit_cost::Float64`
- `budgeted_volume::Float64`, `actual_volume::Float64`
- `spending_variance::Float64`: Positive = over budget on rate.
- `efficiency_variance::Float64`: Positive = used more volume than planned.
- `total_variance::Float64`: spending + efficiency.
- `budgeted_total::Float64`, `actual_total::Float64`
"""
struct ExpenseVarianceBridge
    category::String
    budgeted_unit_cost::Float64
    actual_unit_cost::Float64
    budgeted_volume::Float64
    actual_volume::Float64
    spending_variance::Float64
    efficiency_variance::Float64
    total_variance::Float64
    budgeted_total::Float64
    actual_total::Float64
end

"""
    expense_variance(category, budgeted_unit_cost, actual_unit_cost,
                     budgeted_volume, actual_volume) -> ExpenseVarianceBridge

Decompose a single expense line into spending (rate) and efficiency (volume) variances.

# Example
```julia
# Contract labor: budgeted 45/hr × 8000 hrs vs actual 52/hr × 8500 hrs
v = expense_variance("Contract Labor", 45.0, 52.0, 8000.0, 8500.0)
v.spending_variance    # (52-45) × 8500 = +\$59,500 (adverse)
v.efficiency_variance  # (8500-8000) × 45 = +\$22,500 (adverse)
```
"""
function expense_variance(
    category::String,
    budgeted_unit_cost::Float64,
    actual_unit_cost::Float64,
    budgeted_volume::Float64,
    actual_volume::Float64,
)::ExpenseVarianceBridge
    spending   = (actual_unit_cost - budgeted_unit_cost) * actual_volume
    efficiency = (actual_volume - budgeted_volume) * budgeted_unit_cost
    total      = spending + efficiency
    ExpenseVarianceBridge(
        category,
        budgeted_unit_cost, actual_unit_cost,
        budgeted_volume, actual_volume,
        spending, efficiency, total,
        budgeted_unit_cost * budgeted_volume,
        actual_unit_cost   * actual_volume,
    )
end

"""
    multi_category_variance(categories::Vector{NamedTuple}) -> Vector{ExpenseVarianceBridge}

Compute expense variances for multiple categories and sort by |total_variance| descending.

Each element of `categories` must be a NamedTuple with fields:
`(category, budgeted_unit_cost, actual_unit_cost, budgeted_volume, actual_volume)`.

# Example
```julia
cats = [
    (category="Salaries",  budgeted_unit_cost=62.0, actual_unit_cost=64.0, budgeted_volume=180_000.0, actual_volume=182_000.0),
    (category="Supplies",  budgeted_unit_cost=8.50,  actual_unit_cost=9.20,  budgeted_volume=95_000.0,  actual_volume=98_000.0),
]
bridges = multi_category_variance(cats)
```
"""
function multi_category_variance(categories::Vector{<:NamedTuple})::Vector{ExpenseVarianceBridge}
    bridges = [expense_variance(c.category, Float64(c.budgeted_unit_cost),
                Float64(c.actual_unit_cost), Float64(c.budgeted_volume),
                Float64(c.actual_volume)) for c in categories]
    sort!(bridges; by=b -> -abs(b.total_variance))
    bridges
end
