# ============================================================================
# Commercial Payer Reimbursement
# ============================================================================

"""
    calculate_commercial_reimbursement(hospital::AbstractHospital;
                                       commercial_charges::Float64=0.0,
                                       pct_of_charges::Float64=0.85,
                                       pct_of_medicare::Float64=1.50,
                                       method::Symbol=:pct_charges,
                                       commercial_days::Int=0,
                                       per_diem::Float64=0.0,
                                       drg_base_rate::Float64=0.0,
                                       case_mix_index::Float64=1.0) -> NamedTuple

Calculate commercial (private) payer reimbursement using the specified
payment methodology.

# Methods
- `:pct_charges` — percentage of billed charges (default 85%)
- `:pct_medicare` — percentage of Medicare rates (default 150%)
- `:per_diem` — negotiated per-diem rate × days
- `:drg` — DRG-based with a negotiated base rate × CMI

Returns a named tuple with:
- `method`: the reimbursement method used
- `gross_charges`: total billed charges
- `contractual_adjustment`: discount from charges
- `net_payment`: expected commercial payment
"""
function calculate_commercial_reimbursement(hospital::AbstractHospital;
                                             commercial_charges::Float64=0.0,
                                             pct_of_charges::Float64=0.85,
                                             pct_of_medicare::Float64=1.50,
                                             method::Symbol=:pct_charges,
                                             commercial_days::Int=0,
                                             per_diem::Float64=0.0,
                                             drg_base_rate::Float64=0.0,
                                             case_mix_index::Float64=1.0)
    net_payment = 0.0

    if method == :pct_charges
        net_payment = commercial_charges * pct_of_charges
    elseif method == :pct_medicare
        # Estimate Medicare-equivalent payment using CCR
        ccr = hasproperty(hospital, :cost_to_charge_ratio) ?
            getproperty(hospital, :cost_to_charge_ratio) : 0.40
        medicare_equiv = commercial_charges * ccr
        net_payment = medicare_equiv * pct_of_medicare
    elseif method == :per_diem
        net_payment = commercial_days * per_diem
    elseif method == :drg
        net_payment = drg_base_rate * case_mix_index
    else
        error("Unknown commercial payment method: $method")
    end

    contractual_adjustment = commercial_charges - net_payment

    return (
        method = method,
        gross_charges = commercial_charges,
        contractual_adjustment = max(contractual_adjustment, 0.0),
        net_payment = net_payment,
    )
end
