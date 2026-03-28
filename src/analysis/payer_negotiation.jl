# ============================================================================
# Payer Contract Negotiation Modeling
# ============================================================================
#
# Simulates the financial impact of payer contract rate negotiations for
# rural hospitals, identifying leverage points and optimal rate targets.
# ============================================================================

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

"""
    NegotiationCategory

A single service category within a payer negotiation, capturing current
volume, charges, and proposed rate adjustments.

# Fields
- `name::String`: category label (e.g., "Inpatient Medical", "ED Level 4").
- `current_volume::Int`: annual volume in the category.
- `current_charges::Float64`: average charges per unit.
- `current_rate::Float64`: current reimbursement as a fraction of charges (0.0-1.0).
- `proposed_rate::Float64`: proposed new rate as a fraction of charges.

# Example
```julia
cat = NegotiationCategory(
    name            = "ED Level 4-5",
    current_volume  = 3500,
    current_charges = 2800.0,
    current_rate    = 0.45,
    proposed_rate   = 0.52,
)
```
"""
@kwdef struct NegotiationCategory
    name::String
    current_volume::Int
    current_charges::Float64
    current_rate::Float64      # fraction of charges
    proposed_rate::Float64
end

function Base.show(io::IO, nc::NegotiationCategory)
    delta_pct = (nc.proposed_rate - nc.current_rate) * 100.0
    print(io, "NegotiationCategory(\"$(nc.name)\", Δ=$(round(delta_pct, digits=1))pp)")
end

"""
    NegotiationResult

Aggregated outcome of a payer contract negotiation simulation.

# Fields
- `categories::Vector{NegotiationCategory}`: the categories that were modeled.
- `current_total_revenue::Float64`: total revenue under current rates.
- `proposed_total_revenue::Float64`: projected revenue under proposed rates.
- `revenue_increase::Float64`: absolute dollar increase.
- `revenue_increase_pct::Float64`: percentage increase.
- `strongest_leverage::String`: name of the category with the highest absolute dollar impact.
"""
@kwdef struct NegotiationResult
    categories::Vector{NegotiationCategory}
    current_total_revenue::Float64
    proposed_total_revenue::Float64
    revenue_increase::Float64
    revenue_increase_pct::Float64
    strongest_leverage::String
end

function Base.show(io::IO, nr::NegotiationResult)
    print(io, "NegotiationResult(Δ=\$$(round(Int, nr.revenue_increase)) ",
          "($(round(nr.revenue_increase_pct * 100, digits=1))%), ",
          "leverage=\"$(nr.strongest_leverage)\")")
end

# ---------------------------------------------------------------------------
# Negotiation simulation
# ---------------------------------------------------------------------------

"""
    simulate_negotiation(categories::Vector{NegotiationCategory}) -> NegotiationResult

Simulate the financial outcome of proposed payer rate changes across
multiple service categories.

For each category the model computes:
- **current revenue** = volume × charges × current_rate
- **proposed revenue** = volume × charges × proposed_rate

The category with the largest absolute revenue increase is identified
as the *strongest leverage* point for negotiation strategy.

# Example
```julia
cats = [
    NegotiationCategory(name="ED Level 4-5", current_volume=3500,
                        current_charges=2800.0, current_rate=0.45, proposed_rate=0.52),
    NegotiationCategory(name="Observation", current_volume=800,
                        current_charges=4500.0, current_rate=0.40, proposed_rate=0.48),
]
result = simulate_negotiation(cats)
println("Revenue increase: \$", round(Int, result.revenue_increase))
println("Best leverage: ", result.strongest_leverage)
```
"""
function simulate_negotiation(categories::Vector{NegotiationCategory})::NegotiationResult
    isempty(categories) && error("At least one NegotiationCategory is required")

    current_total = 0.0
    proposed_total = 0.0
    best_delta = -Inf
    best_category = categories[1].name

    for cat in categories
        current_rev  = cat.current_volume * cat.current_charges * cat.current_rate
        proposed_rev = cat.current_volume * cat.current_charges * cat.proposed_rate
        delta = proposed_rev - current_rev

        current_total  += current_rev
        proposed_total += proposed_rev

        if delta > best_delta
            best_delta = delta
            best_category = cat.name
        end
    end

    revenue_increase = proposed_total - current_total
    revenue_increase_pct = current_total > 0.0 ? revenue_increase / current_total : 0.0

    return NegotiationResult(
        categories           = categories,
        current_total_revenue  = current_total,
        proposed_total_revenue = proposed_total,
        revenue_increase       = revenue_increase,
        revenue_increase_pct   = revenue_increase_pct,
        strongest_leverage     = best_category,
    )
end

# ---------------------------------------------------------------------------
# Optimal rate targeting
# ---------------------------------------------------------------------------

"""
    optimal_rate_target(hospital::AbstractHospital, payer_type::Symbol;
                        target_margin::Float64=0.0) -> Float64

Estimate the minimum payer reimbursement rate (as a fraction of charges)
required for the hospital to achieve the given operating margin target on
that payer's volume.

The calculation uses the hospital's most recent `AnnualFinancials` to
determine the cost-to-charge ratio, then solves for the rate that produces
the target margin:

    rate = CCR × (1 + target_margin)

where CCR = total_operating_expenses / gross_patient_revenue.

If the hospital has a `payer_mix` with a matching contract, the payer's
volume share is used to weight the result.  Otherwise the blended CCR is
returned directly.

# Arguments
- `hospital::AbstractHospital`: hospital entity with financial data.
- `payer_type::Symbol`: one of `:medicare`, `:medicaid`, `:commercial`, `:self_pay`, etc.
- `target_margin::Float64`: desired operating margin (0.0 = breakeven).

# Returns
The required reimbursement rate as a fraction of charges.

# Example
```julia
rate = optimal_rate_target(my_cah, :commercial; target_margin=0.03)
println("Need ", round(rate * 100, digits=1), "% of charges to hit 3% margin")
```
"""
function optimal_rate_target(hospital::AbstractHospital, payer_type::Symbol;
                             target_margin::Float64=0.0)::Float64
    # Retrieve the most recent financials
    financials = if hasfield(typeof(hospital), :historical_financials)
        hist = getfield(hospital, :historical_financials)
        isempty(hist) && error("Hospital has no historical financials for rate calculation")
        last(hist)
    else
        error("Hospital type $(typeof(hospital)) does not have historical_financials")
    end

    gross_rev = financials.gross_patient_revenue
    gross_rev > 0.0 || error("Gross patient revenue must be positive")

    total_expenses = financials.total_operating_expenses
    ccr = total_expenses / gross_rev  # cost-to-charge ratio

    # If we have payer mix, adjust for payer-specific volume/cost characteristics
    if hasfield(typeof(hospital), :payer_mix) && getfield(hospital, :payer_mix) !== nothing
        pm = getfield(hospital, :payer_mix)
        contract = get_contract(pm, payer_type)
        if contract !== nothing
            # Payer-specific adjustment: government payers typically have lower
            # cost of service due to simpler billing; commercial has higher
            payer_cost_adj = if payer_type == :medicare
                0.95   # slightly lower administrative cost
            elseif payer_type == :medicaid
                0.93
            elseif payer_type == :commercial
                1.05   # higher admin/billing cost
            else
                1.0
            end
            ccr *= payer_cost_adj
        end
    end

    # Required rate: costs * (1 + margin) expressed as fraction of charges
    required_rate = ccr * (1.0 + target_margin)

    return clamp(required_rate, 0.0, 2.0)  # sanity cap at 200% of charges
end
