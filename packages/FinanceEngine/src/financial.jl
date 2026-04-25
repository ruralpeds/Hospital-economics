"""
    financial.jl — Core healthcare financial calculations

Provides NPV, ROI, operating margin, break-even analysis, DRG revenue,
and payer mix revenue calculations for rural hospital financial modeling.
"""

using LinearAlgebra

# ── Net Present Value ────────────────────────────────────────────────────────

"""
    npv(cash_flows::Vector{<:Real}, rate::Real) -> Float64

Compute the Net Present Value of a series of cash flows.

# Arguments
- `cash_flows`: Vector of cash flows where `cash_flows[1]` is the initial
  investment (typically negative) and subsequent entries are future cash flows.
- `rate`: Discount rate per period (e.g., 0.10 for 10%).

# Returns
The present value of the cash flow stream, discounted at `rate`.

# Example
```julia
# Initial investment of \$100k, followed by 3 years of \$50k returns
npv([-100_000, 50_000, 50_000, 50_000], 0.10)
# ≈ 24,868.52
```
"""
function npv(cash_flows::Vector{<:Real}, rate::Real)
    isempty(cash_flows) && throw(
        DataValidationError("cash_flows must not be empty")
    )
    rate > -1.0 || throw(
        DomainValidationError("rate", string(rate), "rate > -1.0",
            "Discount rate must be greater than -1.0")
    )

    total = 0.0
    for (t, cf) in enumerate(cash_flows)
        total += cf / (1.0 + rate)^(t - 1)
    end
    return total
end

# ── Return on Investment ─────────────────────────────────────────────────────

"""
    roi(gain::Real, cost::Real) -> Float64

Compute Return on Investment as `(gain - cost) / cost`.

# Arguments
- `gain`: Total value received from the investment.
- `cost`: Total cost of the investment (must be positive).

# Returns
ROI as a decimal (e.g., 0.25 for 25% return).

# Example
```julia
roi(125_000, 100_000)  # => 0.25
```
"""
function roi(gain::Real, cost::Real)
    cost > 0 || throw(
        DomainValidationError("cost", string(cost), "cost > 0",
            "Investment cost must be positive")
    )
    return (gain - cost) / cost
end

# ── Operating Margin ─────────────────────────────────────────────────────────

"""
    operating_margin(revenue::Real, expenses::Real) -> Float64

Compute operating margin as `(revenue - expenses) / revenue`.

# Arguments
- `revenue`: Total operating revenue (must be positive).
- `expenses`: Total operating expenses.

# Returns
Operating margin ratio (e.g., 0.05 for 5% margin).

# Example
```julia
operating_margin(10_000_000, 9_500_000)  # => 0.05
```
"""
function operating_margin(revenue::Real, expenses::Real)
    revenue > 0 || throw(
        DomainValidationError("revenue", string(revenue), "revenue > 0",
            "Revenue must be positive to compute margin")
    )
    return (revenue - expenses) / revenue
end

# ── Cost per Patient ─────────────────────────────────────────────────────────

"""
    cost_per_patient(total_costs::Real, patient_count::Int) -> Float64

Compute average cost per patient.

# Arguments
- `total_costs`: Total operating costs (must be non-negative).
- `patient_count`: Number of patients (must be positive).

# Returns
Average cost per patient.

# Example
```julia
cost_per_patient(5_000_000, 2500)  # => 2000.0
```
"""
function cost_per_patient(total_costs::Real, patient_count::Int)
    total_costs >= 0 || throw(
        DomainValidationError("total_costs", string(total_costs), "total_costs ≥ 0",
            "Total costs cannot be negative")
    )
    patient_count > 0 || throw(
        DomainValidationError("patient_count", string(patient_count), "patient_count > 0",
            "Patient count must be positive")
    )
    return total_costs / patient_count
end

# ── Break-Even Units ─────────────────────────────────────────────────────────

"""
    break_even_units(fixed_costs::Real, price::Real, variable_cost::Real) -> Float64

Compute break-even volume as `fixed_costs / (price - variable_cost)`.

# Arguments
- `fixed_costs`: Total fixed costs per period (must be non-negative).
- `price`: Revenue per unit (must be positive).
- `variable_cost`: Variable cost per unit (must be non-negative and less than price).

# Returns
Number of units required to break even.

# Example
```julia
break_even_units(500_000, 5_000, 3_000)  # => 250.0
```
"""
function break_even_units(fixed_costs::Real, price::Real, variable_cost::Real)
    fixed_costs >= 0 || throw(
        DomainValidationError("fixed_costs", string(fixed_costs), "fixed_costs ≥ 0",
            "Fixed costs cannot be negative")
    )
    price > 0 || throw(
        DomainValidationError("price", string(price), "price > 0",
            "Price per unit must be positive")
    )
    variable_cost >= 0 || throw(
        DomainValidationError("variable_cost", string(variable_cost), "variable_cost ≥ 0",
            "Variable cost cannot be negative")
    )
    contribution = price - variable_cost
    contribution > 0 || throw(
        DomainValidationError("contribution_margin", string(contribution),
            "price > variable_cost",
            "Price must exceed variable cost to have a positive contribution margin")
    )
    return fixed_costs / contribution
end

# ── Payback Period ───────────────────────────────────────────────────────────

"""
    payback_period(cash_flows::Vector{<:Real}) -> Float64

Compute the payback period — the time (in periods) required for cumulative
cash flows to turn non-negative. Uses linear interpolation within the
crossover period.

# Arguments
- `cash_flows`: Vector of cash flows; `cash_flows[1]` is typically the initial
  investment (negative), subsequent entries are periodic returns.

# Returns
Payback period in periods. Returns `Inf` if cash flows never recover.

# Example
```julia
payback_period([-100_000, 40_000, 40_000, 40_000])  # => 2.5
```
"""
function payback_period(cash_flows::Vector{<:Real})
    isempty(cash_flows) && throw(
        DataValidationError("cash_flows must not be empty")
    )

    cumulative = 0.0
    for (t, cf) in enumerate(cash_flows)
        prev = cumulative
        cumulative += cf
        if cumulative >= 0 && t > 1
            # Linear interpolation within the crossover period
            fraction = -prev / cf
            return (t - 1) - 1 + fraction
        end
    end
    return Inf
end

# ── DRG Revenue ──────────────────────────────────────────────────────────────

"""
    drg_revenue(drg_weight::Real, base_rate::Real, wage_index::Real;
                cost_outlier_adjustment::Real=0.0,
                indirect_medical_education::Real=0.0,
                disproportionate_share::Real=0.0) -> Float64

Compute CMS DRG-based payment for an inpatient stay.

Payment = base_rate × drg_weight × wage_index × (1 + adjustments)

# Arguments
- `drg_weight`: CMS relative weight for the DRG (must be positive).
- `base_rate`: National base payment rate in dollars.
- `wage_index`: Area wage index for the hospital's CBSA (must be positive).
- `cost_outlier_adjustment`: Additional outlier payment factor (≥ 0).
- `indirect_medical_education`: IME adjustment factor (≥ 0).
- `disproportionate_share`: DSH adjustment factor (≥ 0).

# Returns
Estimated DRG payment amount in dollars.

# Example
```julia
drg_revenue(1.5, 6000.0, 0.95; disproportionate_share=0.03)
# => 6000 × 1.5 × 0.95 × 1.03 ≈ 8806.50
```
"""
function drg_revenue(drg_weight::Real, base_rate::Real, wage_index::Real;
                     cost_outlier_adjustment::Real=0.0,
                     indirect_medical_education::Real=0.0,
                     disproportionate_share::Real=0.0)
    drg_weight > 0 || throw(
        DomainValidationError("drg_weight", string(drg_weight), "drg_weight > 0",
            "DRG weight must be positive")
    )
    base_rate > 0 || throw(
        DomainValidationError("base_rate", string(base_rate), "base_rate > 0",
            "Base rate must be positive")
    )
    wage_index > 0 || throw(
        DomainValidationError("wage_index", string(wage_index), "wage_index > 0",
            "Wage index must be positive")
    )
    cost_outlier_adjustment >= 0 || throw(
        DomainValidationError("cost_outlier_adjustment",
            string(cost_outlier_adjustment), "≥ 0",
            "Cost outlier adjustment cannot be negative")
    )
    indirect_medical_education >= 0 || throw(
        DomainValidationError("indirect_medical_education",
            string(indirect_medical_education), "≥ 0",
            "IME adjustment cannot be negative")
    )
    disproportionate_share >= 0 || throw(
        DomainValidationError("disproportionate_share",
            string(disproportionate_share), "≥ 0",
            "DSH adjustment cannot be negative")
    )

    adjustment_factor = 1.0 + cost_outlier_adjustment +
                        indirect_medical_education +
                        disproportionate_share

    return base_rate * drg_weight * wage_index * adjustment_factor
end

# ── Weighted Payer Rate ──────────────────────────────────────────────────────

"""
    weighted_payer_rate(mix::PayerMix, rates::NamedTuple) -> Float64

Compute weighted average reimbursement rate from a payer mix and per-payer rates.

# Arguments
- `mix`: A `PayerMix` (from RuralCore) with proportions for each payer category.
- `rates`: A NamedTuple with fields `medicare`, `medicaid`, `commercial`,
  `self_pay`, `other`, each a per-case reimbursement rate.

# Returns
Blended reimbursement rate per case.

# Example
```julia
mix = PayerMix(0.45, 0.25, 0.20, 0.05, 0.05)
rates = (medicare=8000, medicaid=5500, commercial=12000, self_pay=3000, other=6000)
weighted_payer_rate(mix, rates)
# => 0.45×8000 + 0.25×5500 + 0.20×12000 + 0.05×3000 + 0.05×6000 = 7725.0
```
"""
function weighted_payer_rate(mix::PayerMix, rates::NamedTuple)
    haskey(rates, :medicare) || throw(
        DataValidationError("rates must contain :medicare field")
    )
    haskey(rates, :medicaid) || throw(
        DataValidationError("rates must contain :medicaid field")
    )
    haskey(rates, :commercial) || throw(
        DataValidationError("rates must contain :commercial field")
    )
    haskey(rates, :self_pay) || throw(
        DataValidationError("rates must contain :self_pay field")
    )
    haskey(rates, :other) || throw(
        DataValidationError("rates must contain :other field")
    )

    return (mix.medicare * rates.medicare +
            mix.medicaid * rates.medicaid +
            mix.commercial * rates.commercial +
            mix.self_pay * rates.self_pay +
            mix.other * rates.other)
end

# ── Net Collection Rate ──────────────────────────────────────────────────────

"""
    net_collection_rate(payments::Real, allowed_charges::Real) -> Float64

Compute net collection rate as `payments / allowed_charges`.

Measures how effectively a facility collects on what it is contractually
owed after adjustments. Industry benchmark: 95%+.

# Arguments
- `payments`: Total payments received (must be non-negative).
- `allowed_charges`: Total contractually allowed charges (must be positive).

# Returns
Collection rate as a decimal (e.g., 0.96 for 96%).

# Example
```julia
net_collection_rate(4_800_000, 5_000_000)  # => 0.96
```
"""
function net_collection_rate(payments::Real, allowed_charges::Real)
    payments >= 0 || throw(
        DomainValidationError("payments", string(payments), "payments ≥ 0",
            "Payments cannot be negative")
    )
    allowed_charges > 0 || throw(
        DomainValidationError("allowed_charges", string(allowed_charges),
            "allowed_charges > 0",
            "Allowed charges must be positive")
    )
    return payments / allowed_charges
end
