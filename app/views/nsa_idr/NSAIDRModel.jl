"""NSA-IDR claim evaluator model (E-09)."""
using Stipple, StippleUI, StipplePlotly
using ...FinanceEngine: IDRClaimInputs, analyze_idr_claim, idr_portfolio_opportunity

@app begin
    @in billed_amount::Float64    = 28_000.0
    @in qpa::Float64              = 12_500.0
    @in our_offer::Float64        = 22_000.0
    @in payer_offer::Float64      = 12_500.0
    @in win_probability::Float64  = 60.0   # shown as %
    @in is_complex::Bool          = false
    @in batch_size::Int           = 1
    @in evaluate_claim::Bool      = false

    @out expected_payment::Float64  = 0.0
    @out admin_fee::Float64         = 0.0
    @out net_gain_vs_qpa::Float64   = 0.0
    @out break_even_offer::Float64  = 0.0
    @out recommend_idr::Bool        = false
    @out recommendation_text::String = "Enter claim details and click Evaluate"

    # Portfolio estimator
    @in annual_oon_claims::Int      = 150
    @in avg_billed::Float64         = 25_000.0
    @in qpa_ratio::Float64          = 65.0
    @in offer_ratio::Float64        = 85.0
    @in run_portfolio::Bool         = false

    @out portfolio_annual_opportunity::Float64 = 0.0
    @out portfolio_viable::Bool     = false
    @out per_claim_net_gain::Float64 = 0.0
    @out n_viable_claims::Int       = 0

    @in errors::Vector{String} = String[]

    @onchange evaluate_claim begin
        if evaluate_claim
            evaluate_claim = false
            errors = String[]
            try
                inp = IDRClaimInputs(
                    claim_id=1, billed_amount=billed_amount, qpa=qpa,
                    our_offer=our_offer, payer_offer=payer_offer,
                    win_probability=win_probability/100.0,
                    is_complex=is_complex, batched_with_n=batch_size,
                )
                r = analyze_idr_claim(inp)
                expected_payment  = r.expected_payment
                admin_fee         = r.admin_fee_our_share
                net_gain_vs_qpa   = r.expected_net_gain_vs_qpa
                break_even_offer  = isnothing(r.break_even_amount) ? 0.0 : r.break_even_amount
                recommend_idr     = r.recommend_idr
                recommendation_text = r.reason
            catch e; errors = ["$(sprint(showerror, e))"]; end
        end
    end

    @onchange run_portfolio begin
        if run_portfolio
            run_portfolio = false
            try
                r = idr_portfolio_opportunity(
                    annual_oon_claims=annual_oon_claims,
                    avg_billed_per_claim=avg_billed,
                    avg_qpa_ratio=qpa_ratio/100, avg_our_offer_ratio=offer_ratio/100,
                    win_probability=win_probability/100,
                )
                portfolio_annual_opportunity = r.annual_idr_revenue_opportunity
                portfolio_viable = r.viable_for_idr
                per_claim_net_gain = r.per_claim_expected_net_gain
                n_viable_claims = r.n_viable_claims
            catch e; errors = ["$(sprint(showerror, e))"]; end
        end
    end
end
const nsa_idr_model = @init
