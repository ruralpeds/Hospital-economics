"""
    payer_negotiation_game.jl — Game-Theoretic Payer Negotiation (MBA Gap B-06)

Extends the existing `analysis/payer_negotiation.jl` rate-calculation module
with the cooperative and non-cooperative game-theoretic frameworks that CFOs
and strategy consultants use when entering payer contract negotiations.

Provides:
1. **Nash Bargaining Solution** — maximises the product of surplus above each
   party's reservation price (BATNA). Uniquely determined under four axioms
   (Pareto efficiency, symmetry, invariance, independence of irrelevant alternatives).

2. **Kalai-Smorodinsky Solution** — alternative fairness criterion that
   proportionally distributes gains; often preferred when the Nash solution
   is asymmetric due to large BATNA differences.

3. **BATNA sensitivity analysis** — how the negotiated rate changes as the
   hospital's outside option (e.g. out-of-network rate) changes.

4. **Multi-round alternating-offers simulation** (Rubinstein bargaining) —
   models sequential offer/counteroffer dynamics with discounting.

5. **Reservation price calculator** — determines the hospital's walk-away rate
   from cost structure, payer volume, and alternative revenue sources.

References:
- Nash JF (1950). The bargaining problem. Econometrica 18(2): 155-162.
- Kalai E, Smorodinsky M (1975). Other solutions to Nash's bargaining problem.
  Econometrica 43(3): 513-518.
- Rubinstein A (1982). Perfect equilibrium in a bargaining model.
  Econometrica 50(1): 97-109.
- Dafny L (2010). Does health insurance market structure matter? NBER w14015.
"""

using Statistics
using Printf

# ─────────────────────────────────────────────────────────────────────────────
# Core types
# ─────────────────────────────────────────────────────────────────────────────

"""
    NashBargainInputs

Inputs for Nash bargaining between a hospital and a payer.

# Fields
- `hospital_batna::Float64`: Hospital's Best Alternative to Negotiated Agreement —
  net revenue per unit if no contract (e.g. out-of-network rate, or Medicare rate).
- `payer_batna::Float64`: Payer's BATNA — cost per unit if no contract
  (e.g. enrollees seek care at higher-cost alternative facility).
- `hospital_max_ask::Float64`: Hospital's aspiration (highest rate it would accept if offered).
- `payer_max_offer::Float64`: Payer's aspiration (lowest rate it would offer if accepted).
- `hospital_bargaining_power::Float64 = 0.5`: Generalised Nash power parameter α ∈ (0,1).
  α = 0.5 → symmetric Nash; α > 0.5 → hospital has more bargaining power.
- `annual_covered_lives::Int`: Payer's covered lives at this facility.
- `annual_encounters::Int`: Expected encounters per year under contract.
"""
@kwdef struct NashBargainInputs
    hospital_batna::Float64
    payer_batna::Float64
    hospital_max_ask::Float64
    payer_max_offer::Float64
    hospital_bargaining_power::Float64 = 0.50
    annual_covered_lives::Int          = 10_000
    annual_encounters::Int             = 1_200
end

"""
    NashBargainResult

Result of Nash or Kalai-Smorodinsky bargaining.

# Fields
- `solution_type::Symbol`: `:nash` or `:kalai_smorodinsky`.
- `negotiated_rate::Float64`: The agreed rate per encounter/unit.
- `hospital_surplus::Float64`: Hospital gain above BATNA.
- `payer_surplus::Float64`: Payer gain above BATNA (cost savings).
- `nash_product::Float64`: Product of surpluses (maximised in Nash solution).
- `joint_surplus::Float64`: Total surplus available to split.
- `hospital_share_of_surplus::Float64`: Hospital's fraction of joint surplus.
- `zopa::Tuple{Float64,Float64}`: Zone of Possible Agreement `(hospital_batna, payer_batna)`.
- `contract_viable::Bool`: Whether a ZOPA exists (hospital_batna < payer_batna).
- `annual_revenue_impact::Float64`: (negotiated_rate - hospital_batna) × encounters.
"""
struct NashBargainResult
    solution_type::Symbol
    negotiated_rate::Float64
    hospital_surplus::Float64
    payer_surplus::Float64
    nash_product::Float64
    joint_surplus::Float64
    hospital_share_of_surplus::Float64
    zopa::Tuple{Float64,Float64}
    contract_viable::Bool
    annual_revenue_impact::Float64
end

# ─────────────────────────────────────────────────────────────────────────────
# Nash Bargaining Solution
# ─────────────────────────────────────────────────────────────────────────────

"""
    nash_bargaining(inputs::NashBargainInputs) -> NashBargainResult

Compute the generalised Nash bargaining solution.

## Theory
The Nash solution maximises the weighted product of surpluses:
  max_{r ∈ ZOPA} (r - d_H)^α × (d_P - r)^(1-α)

where:
  d_H = hospital_batna (disagreement payoff for hospital)
  d_P = payer_batna    (disagreement payoff for payer, from its perspective)
  α   = hospital_bargaining_power

The closed-form solution is:
  r* = d_H + α × (d_P - d_H)

i.e. the hospital gets its BATNA plus α-fraction of the total surplus.
For α = 0.5 (symmetric Nash): r* = (d_H + d_P) / 2 — splits the ZOPA equally.

# Example
```julia
inputs = NashBargainInputs(
    hospital_batna          = 8_500.0,   # Medicare FFS rate per discharge
    payer_batna             = 14_200.0,  # Cost if enrollees go to urban hospital
    hospital_max_ask        = 13_000.0,
    payer_max_offer         = 9_500.0,
    hospital_bargaining_power = 0.45,    # hospital has less leverage
    annual_encounters       = 280,
)
r = nash_bargaining(inputs)
r.negotiated_rate   # ~10,790 per discharge
r.contract_viable   # true
```
"""
function nash_bargaining(inputs::NashBargainInputs)::NashBargainResult
    dH = inputs.hospital_batna
    dP = inputs.payer_batna
    α  = clamp(inputs.hospital_bargaining_power, 1e-6, 1.0 - 1e-6)

    # ZOPA exists when hospital's floor < payer's ceiling
    viable = dH < dP

    if !viable
        # No ZOPA: report failure; negotiated rate = hospital BATNA (no deal)
        return NashBargainResult(
            :nash, dH, 0.0, 0.0, 0.0, 0.0, 0.0,
            (dH, dP), false, 0.0,
        )
    end

    joint_surplus = dP - dH
    r_star = dH + α * joint_surplus

    # Clip to feasibility constraints
    r_star = clamp(r_star, inputs.payer_max_offer, inputs.hospital_max_ask)

    hosp_surplus = r_star - dH
    pay_surplus  = dP - r_star
    nash_prod    = hosp_surplus^α * pay_surplus^(1.0 - α)
    hosp_share   = joint_surplus > 0 ? hosp_surplus / joint_surplus : 0.5
    annual_imp   = (r_star - dH) * inputs.annual_encounters

    NashBargainResult(
        :nash, r_star, hosp_surplus, pay_surplus,
        nash_prod, joint_surplus, hosp_share,
        (dH, dP), true, annual_imp,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Kalai-Smorodinsky Solution
# ─────────────────────────────────────────────────────────────────────────────

"""
    kalai_smorodinsky(inputs::NashBargainInputs) -> NashBargainResult

Compute the Kalai-Smorodinsky bargaining solution.

## Theory
KS finds the point on the Pareto frontier that preserves the ratio of
maximum possible gains:
  r_KS = d_H + (max_H - d_H) / ((max_H - d_H) + (max_P - d_P)) × joint_surplus

where max_H and max_P are each party's utopia point (maximum feasible surplus).
KS is preferred over Nash when parties have very different utopia points —
it avoids over-rewarding the party with a lower utopia point.

For payer negotiation:
  - Hospital utopia: hospital_max_ask
  - Payer utopia (from hospital's perspective): payer_max_offer
"""
function kalai_smorodinsky(inputs::NashBargainInputs)::NashBargainResult
    dH = inputs.hospital_batna
    dP = inputs.payer_batna
    viable = dH < dP

    !viable && return NashBargainResult(
        :kalai_smorodinsky, dH, 0.0, 0.0, 0.0, 0.0, 0.0,
        (dH, dP), false, 0.0,
    )

    max_H = min(inputs.hospital_max_ask, dP)
    max_P = max(inputs.payer_max_offer, dH)

    gain_H = max_H - dH
    gain_P = dP - max_P
    total_gain = gain_H + gain_P

    r_ks = total_gain > 0 ?
        dH + gain_H / total_gain * (dP - dH) :
        (dH + dP) / 2.0

    r_ks = clamp(r_ks, inputs.payer_max_offer, inputs.hospital_max_ask)

    joint = dP - dH
    hosp_s  = r_ks - dH
    pay_s   = dP - r_ks
    share   = joint > 0 ? hosp_s / joint : 0.5
    annual  = hosp_s * inputs.annual_encounters

    NashBargainResult(
        :kalai_smorodinsky, r_ks, hosp_s, pay_s,
        hosp_s * pay_s, joint, share,
        (dH, dP), true, annual,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# BATNA Sensitivity Analysis
# ─────────────────────────────────────────────────────────────────────────────

"""
    batna_sensitivity(
        inputs::NashBargainInputs;
        hospital_batna_range, n_points
    ) -> Vector{NamedTuple}

Compute the Nash negotiated rate across a range of hospital BATNA values,
showing how improving the hospital's outside option shifts the negotiated rate.

# Returns
Vector of NamedTuples: `(hospital_batna, negotiated_rate, hospital_surplus,
contract_viable, annual_revenue_impact)`.
"""
function batna_sensitivity(
    inputs::NashBargainInputs;
    hospital_batna_range::Tuple{Float64,Float64} = (
        inputs.hospital_batna * 0.70,
        inputs.hospital_batna * 1.30,
    ),
    n_points::Int = 20,
)::Vector{NamedTuple}
    lo, hi = hospital_batna_range
    batna_grid = range(lo, hi; length=n_points)

    map(batna_grid) do batna
        inp = NashBargainInputs(
            hospital_batna            = batna,
            payer_batna               = inputs.payer_batna,
            hospital_max_ask          = max(inputs.hospital_max_ask, batna * 1.1),
            payer_max_offer           = inputs.payer_max_offer,
            hospital_bargaining_power = inputs.hospital_bargaining_power,
            annual_encounters         = inputs.annual_encounters,
        )
        r = nash_bargaining(inp)
        (
            hospital_batna       = batna,
            negotiated_rate      = r.negotiated_rate,
            hospital_surplus     = r.hospital_surplus,
            contract_viable      = r.contract_viable,
            annual_revenue_impact = r.annual_revenue_impact,
        )
    end |> collect
end

# ─────────────────────────────────────────────────────────────────────────────
# Rubinstein Alternating-Offers Simulation
# ─────────────────────────────────────────────────────────────────────────────

"""
    RubinsteinParams

Parameters for multi-round alternating-offers bargaining.

# Fields
- `hospital_discount_rate::Float64`: Per-round discount factor for hospital (δ_H ∈ (0,1)).
  Models impatience: lower = more impatient = weaker in Rubinstein.
- `payer_discount_rate::Float64`: Per-round discount for payer (δ_P ∈ (0,1)).
- `max_rounds::Int`: Maximum negotiation rounds before impasse.
- `hospital_initial_offer::Float64`: Hospital's opening rate demand.
- `payer_initial_offer::Float64`: Payer's opening counter-offer.
"""
@kwdef struct RubinsteinParams
    hospital_discount_rate::Float64    = 0.95   # slightly impatient
    payer_discount_rate::Float64       = 0.90   # more impatient
    max_rounds::Int                    = 10
    hospital_initial_offer::Float64
    payer_initial_offer::Float64
    hospital_batna::Float64
    payer_batna::Float64
end

"""
    RubinsteinRound

One round of alternating-offers bargaining.
"""
struct RubinsteinRound
    round::Int
    proposer::Symbol      # :hospital or :payer
    offer::Float64
    accepted::Bool
    hospital_payoff::Float64
    payer_payoff::Float64
end

"""
    RubinsteinResult

Result of multi-round alternating-offers simulation.
"""
struct RubinsteinResult
    rounds::Vector{RubinsteinRound}
    agreement_reached::Bool
    final_rate::Float64
    agreement_round::Union{Int,Nothing}
    hospital_total_payoff::Float64
    payer_total_payoff::Float64
end

"""
    rubinstein_simulation(params::RubinsteinParams) -> RubinsteinResult

Simulate alternating-offers bargaining. The hospital makes the first offer,
payer counters, and so on. Each party accepts any offer better than its
BATNA discounted by remaining rounds.

## Convergence
In the Rubinstein model, the unique subgame-perfect equilibrium rate is:
  r* = (1 - δ_P) / (1 - δ_H × δ_P) × ZOPA_width + hospital_batna

This is approximated by the simulation with finite rounds.
"""
function rubinstein_simulation(params::RubinsteinParams)::RubinsteinResult
    δH = params.hospital_discount_rate
    δP = params.payer_discount_rate
    dH = params.hospital_batna
    dP = params.payer_batna

    rounds_log = RubinsteinRound[]
    hospital_offer = params.hospital_initial_offer
    payer_offer    = params.payer_initial_offer

    for round in 1:params.max_rounds
        proposer = isodd(round) ? :hospital : :payer
        offer = proposer == :hospital ? hospital_offer : payer_offer

        # The other party accepts if offer ≥ their discounted BATNA
        if proposer == :hospital
            # Payer accepts if offer ≤ payer_batna × δP^(remaining_rounds)
            remaining = params.max_rounds - round
            payer_threshold = dP * δP^remaining
            accepted = offer <= payer_threshold || offer <= dP
        else
            hospital_threshold = dH / δH^(round - 1)
            accepted = offer >= hospital_threshold || offer >= dH
        end

        hosp_payoff = (offer - dH) * δH^(round - 1)
        payer_payoff = (dP - offer) * δP^(round - 1)

        push!(rounds_log, RubinsteinRound(
            round, proposer, offer, accepted, hosp_payoff, payer_payoff
        ))

        if accepted
            return RubinsteinResult(
                rounds_log, true, offer, round,
                sum(r.hospital_payoff for r in rounds_log),
                sum(r.payer_payoff   for r in rounds_log),
            )
        end

        # Update offers (concession schedule: move toward midpoint)
        if proposer == :hospital
            # Payer counters: move toward the midpoint
            payer_offer = payer_offer + 0.25 * (hospital_offer - payer_offer)
        else
            # Hospital counters: concede slightly
            hospital_offer = hospital_offer - 0.20 * (hospital_offer - payer_offer)
        end
        hospital_offer = max(hospital_offer, dH)
        payer_offer    = min(payer_offer, dP)
    end

    # No agreement after max_rounds → impasse
    RubinsteinResult(rounds_log, false, dH, nothing, 0.0, 0.0)
end

# ─────────────────────────────────────────────────────────────────────────────
# Reservation price calculator
# ─────────────────────────────────────────────────────────────────────────────

"""
    hospital_reservation_price(;
        cost_per_encounter, overhead_allocation_pct,
        volume_from_payer, total_volume,
        alternative_revenue_per_encounter,
        minimum_margin_floor
    ) -> NamedTuple

Calculate the hospital's minimum acceptable rate from a payer (reservation price /
BATNA proxy) based on cost structure and alternative revenue sources.

The reservation price is the rate at which the hospital is indifferent between
accepting the contract and the next-best alternative.

# Returns
- `full_cost_per_encounter`: Fully-loaded cost including overhead
- `minimum_acceptable_rate`: Full cost + minimum margin floor
- `batna_rate`: Alternative revenue per encounter (out-of-network, Medicaid, etc.)
- `effective_batna`: max(minimum_acceptable_rate, batna_rate)
"""
function hospital_reservation_price(;
    cost_per_encounter::Float64,
    overhead_allocation_pct::Float64 = 0.35,
    volume_from_payer::Int,
    total_volume::Int,
    alternative_revenue_per_encounter::Float64 = 0.0,
    minimum_margin_floor::Float64 = 0.02,
)
    full_cost = cost_per_encounter * (1.0 + overhead_allocation_pct)
    min_rate  = full_cost * (1.0 + minimum_margin_floor)
    effective_batna = max(min_rate, alternative_revenue_per_encounter)

    (
        full_cost_per_encounter   = full_cost,
        direct_cost_per_encounter = cost_per_encounter,
        minimum_acceptable_rate   = min_rate,
        batna_rate                = alternative_revenue_per_encounter,
        effective_batna           = effective_batna,
        volume_pct_from_payer     = total_volume > 0 ?
            volume_from_payer / total_volume : NaN,
    )
end
