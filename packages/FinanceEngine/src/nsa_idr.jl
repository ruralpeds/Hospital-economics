"""
    nsa_idr.jl — No Surprises Act Independent Dispute Resolution (MBA Gap E-09)

Calculates the economics of No Surprises Act (NSA) Independent Dispute
Resolution (IDR) arbitration for out-of-network hospital claims.

## Background
The No Surprises Act (P.L. 116-260, effective Jan 2022) prohibits surprise
billing for most OON emergency and facility-based care. When providers and
payers cannot agree on the payment rate, either party can initiate IDR:
  1. Open negotiation (30 days)
  2. IDR initiation ($150–350 administrative fee per batch)
  3. Each party submits final offer
  4. Certified IDR entity selects one offer (baseball arbitration)
  5. QPA (Qualifying Payment Amount = median contracted rate) is the presumptive anchor

## Key financial questions for hospital CFOs
- What is the expected payment from IDR vs accepting QPA?
- What is the break-even claim amount justifying IDR cost and effort?
- How do batching rules affect the economics?
- What is the portfolio-level IDR revenue opportunity?

## Batching rules (42 CFR § 149.510)
Claims can be batched if they share:
- Same provider and facility
- Same payer
- Same item/service code (or same service category for facility claims)
- Date of service within a 30-business-day window

References:
- P.L. 116-260, Division BB, Title I (No Surprises Act).
- 42 CFR §§ 149.500-149.530 (IDR regulations).
- CMS (2023). IDR Process Data Report.
- HHS (2024). IDR Operations Updates.
"""

using Statistics; using Printf; using Dates

# ─── IDR administrative fees (42 CFR § 149.510(d)) ──────────────────────────

const IDR_ADMIN_FEE_STANDARD    = 150.0    # CY2024 standard
const IDR_ADMIN_FEE_COMPLEX     = 350.0    # complex/high-cost items
const IDR_INITIATING_PARTY_FEE  = 150.0    # initiating party always pays this
const IDR_NON_INITIATING_PARTY_FEE = 150.0 # winner's share; loser pays both

# ─── QPA estimation ──────────────────────────────────────────────────────────

"""
    estimated_qpa(;
        median_contracted_rate, market_geographic_adj,
        service_category
    ) -> Float64

Estimate the Qualifying Payment Amount (QPA) for a claim.
QPA = median in-network rate for the same item/service in the geographic area,
adjusted to the relevant plan year.

For hospital facility fees: typically 60-80% of billed charges (rough heuristic).
For physician services: median contracted rate per CPT code.
"""
function estimated_qpa(;
    median_contracted_rate::Float64,
    market_geographic_adj::Float64 = 1.0,
    service_category::Symbol = :facility,
)::Float64
    base = median_contracted_rate * market_geographic_adj
    service_category == :facility ? base * 0.95 : base
end

# ─── Single-claim IDR analysis ───────────────────────────────────────────────

@kwdef struct IDRClaimInputs
    claim_id::Any
    service_date::Date          = today()
    billed_amount::Float64
    qpa::Float64                # Qualifying Payment Amount
    our_offer::Float64          # provider's final offer in IDR
    payer_offer::Float64        # payer's final offer (estimated)
    win_probability::Float64 = 0.60  # P(provider wins) based on published CMS data
    is_complex::Bool = false    # determines admin fee tier
    batched_with_n::Int = 1     # total claims in batch (splits admin fee)
    provider_time_cost::Float64 = 200.0  # internal time/effort cost per claim
end

struct IDRClaimResult
    claim_id::Any
    billed_amount::Float64
    qpa::Float64
    our_offer::Float64
    payer_offer::Float64
    admin_fee_our_share::Float64
    expected_payment::Float64    # probability-weighted
    expected_net_gain_vs_qpa::Float64
    break_even_amount::Float64   # minimum claim amount to justify IDR
    recommend_idr::Bool
    reason::String
end

"""
    analyze_idr_claim(inputs::IDRClaimInputs) -> IDRClaimResult

Analyse whether to pursue IDR for a single claim or batch.

Decision rule: pursue IDR if E[payment] − admin_fee − time_cost > QPA.

Published win rate: providers win ~60% of IDR cases (CMS Q1-Q2 2024 report).
"""
function analyze_idr_claim(inputs::IDRClaimInputs)::IDRClaimResult
    base_fee  = inputs.is_complex ? IDR_ADMIN_FEE_COMPLEX : IDR_ADMIN_FEE_STANDARD
    our_fee   = (IDR_INITIATING_PARTY_FEE + base_fee) / inputs.batched_with_n
    time_cost = inputs.provider_time_cost / inputs.batched_with_n

    # Expected payment: win → our_offer, lose → payer_offer
    p_win = inputs.win_probability
    e_payment = p_win * inputs.our_offer + (1.0 - p_win) * inputs.payer_offer

    # Net gain vs simply accepting QPA
    e_net_gain = e_payment - inputs.qpa - our_fee - time_cost

    # Break-even: minimum our_offer at which IDR is worth pursuing
    # e_payment - qpa - fee - time = 0
    # p_win × our_offer + (1-p_win) × payer_offer - qpa - fee - time = 0
    # our_offer = (qpa + fee + time - (1-p_win)×payer_offer) / p_win
    be_offer = p_win > 0 ?
        (inputs.qpa + our_fee + time_cost - (1 - p_win) * inputs.payer_offer) / p_win :
        Inf

    recommend = e_net_gain > 0
    reason = if recommend
        "Expected net gain \$$(round(e_net_gain, digits=0)) above QPA after fees (E[payment]=\$$(round(e_payment,digits=0)))"
    else
        "Expected loss \$$(round(abs(e_net_gain), digits=0)) vs accepting QPA — consider accepting or negotiating"
    end

    IDRClaimResult(
        inputs.claim_id, inputs.billed_amount, inputs.qpa,
        inputs.our_offer, inputs.payer_offer,
        our_fee, e_payment, e_net_gain, be_offer, recommend, reason,
    )
end

# ─── Batch analysis ──────────────────────────────────────────────────────────

"""
    batch_idr_claims(claims::Vector{IDRClaimInputs}) -> NamedTuple

Analyse a batch of claims that qualify for batching under the NSA 30-day window.
Splits the admin fee across all claims in the batch.

Returns batch-level economics + per-claim results.
"""
function batch_idr_claims(claims::Vector{IDRClaimInputs})
    isempty(claims) && throw(ArgumentError("claims must not be empty"))
    n = length(claims)
    # Update batched_with_n for all claims
    batched = [IDRClaimInputs(; pairs(c)..., batched_with_n=n) for c in claims]
    results = [analyze_idr_claim(c) for c in batched]

    total_qpa         = sum(r.qpa for r in results)
    total_e_payment   = sum(r.expected_payment for r in results)
    total_admin_fee   = sum(r.admin_fee_our_share for r in results)
    total_net_gain    = sum(r.expected_net_gain_vs_qpa for r in results)
    n_recommend       = count(r -> r.recommend_idr, results)

    (
        n_claims             = n,
        results              = results,
        total_billed         = sum(c.billed_amount for c in claims),
        total_qpa            = total_qpa,
        total_expected_payment = total_e_payment,
        total_admin_fee      = total_admin_fee,
        total_expected_net_gain = total_net_gain,
        batch_recommend_idr  = total_net_gain > 0,
        n_claims_recommend   = n_recommend,
    )
end

# ─── Portfolio-level IDR opportunity ─────────────────────────────────────────

"""
    idr_portfolio_opportunity(;
        annual_oon_claims, avg_billed_per_claim, avg_qpa_ratio,
        avg_our_offer_ratio, win_probability, batch_size
    ) -> NamedTuple

Estimate annual IDR revenue opportunity for a hospital's OON claims portfolio.

# Arguments
- `annual_oon_claims::Int`: Number of OON claims per year eligible for IDR.
- `avg_billed_per_claim::Float64`: Average billed amount.
- `avg_qpa_ratio::Float64`: QPA as fraction of billed (e.g. 0.65).
- `avg_our_offer_ratio::Float64`: Our IDR offer as fraction of billed (e.g. 0.85).
- `win_probability::Float64 = 0.60`: Published CMS provider win rate.
- `batch_size::Int = 5`: Average claims per batch (reduces per-claim admin cost).
"""
function idr_portfolio_opportunity(;
    annual_oon_claims::Int,
    avg_billed_per_claim::Float64,
    avg_qpa_ratio::Float64        = 0.65,
    avg_our_offer_ratio::Float64  = 0.85,
    win_probability::Float64      = 0.60,
    batch_size::Int               = 5,
)
    qpa       = avg_billed_per_claim * avg_qpa_ratio
    our_offer = avg_billed_per_claim * avg_our_offer_ratio
    payer_off = qpa  # payer typically offers QPA or slightly above

    template = IDRClaimInputs(
        claim_id = :portfolio,
        billed_amount = avg_billed_per_claim,
        qpa = qpa,
        our_offer = our_offer,
        payer_offer = payer_off,
        win_probability = win_probability,
        batched_with_n = batch_size,
    )
    per_claim = analyze_idr_claim(template)

    n_viable = per_claim.recommend_idr ? annual_oon_claims : 0
    annual_net_gain = per_claim.expected_net_gain_vs_qpa * n_viable

    (
        annual_oon_claims            = annual_oon_claims,
        avg_billed                   = avg_billed_per_claim,
        avg_qpa                      = qpa,
        per_claim_expected_net_gain  = per_claim.expected_net_gain_vs_qpa,
        annual_idr_revenue_opportunity = annual_net_gain,
        viable_for_idr               = per_claim.recommend_idr,
        n_viable_claims              = n_viable,
        admin_fee_per_claim_batched  = per_claim.admin_fee_our_share,
    )
end
