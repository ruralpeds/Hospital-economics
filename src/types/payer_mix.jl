# Payer mix types for Rural Hospital Economics Simulator

"""
    PayerContract

Contract terms and performance metrics for a single payer relationship.
"""
@kwdef mutable struct PayerContract
    payer_name::String
    payer_type::Symbol  # :medicare, :medicaid, :commercial, :self_pay, :tricare, :va, :other

    # Volume percentages (as fractions)
    inpatient_volume_pct::Float64 = 0.0
    outpatient_volume_pct::Float64 = 0.0
    ed_volume_pct::Float64 = 0.0
    overall_volume_pct::Float64 = 0.0

    # Payment methodology
    payment_method::Symbol = :fee_for_service  # :fee_for_service, :cost_based, :capitated, :bundled, :drg, :percent_of_charges
    payment_rate_inpatient::Float64 = 0.0
    payment_rate_outpatient::Float64 = 0.0
    payment_rate_ed::Float64 = 0.0
    percent_of_medicare::Float64 = 1.0  # for benchmarking (e.g., Medicaid at 0.70 = 70% of Medicare rates)

    # Revenue cycle performance
    denial_rate::Float64 = 0.05
    denial_recovery_rate::Float64 = 0.50
    days_in_ar::Float64 = 45.0
    bad_debt_rate::Float64 = 0.02
    contractual_adjustment_pct::Float64 = 0.40  # fraction of gross charges written off
end

function Base.show(io::IO, pc::PayerContract)
    print(io, "PayerContract(\"$(pc.payer_name)\", :$(pc.payer_type), vol=$(round(pc.overall_volume_pct * 100, digits=1))%)")
end

"""
    PayerMix

Complete payer mix for a hospital with validation that volume percentages
sum to approximately 1.0.
"""
mutable struct PayerMix
    contracts::Vector{PayerContract}
    effective_date::Date
    notes::String

    function PayerMix(contracts::Vector{PayerContract}, effective_date::Date, notes::String="")
        total_vol = sum(c.overall_volume_pct for c in contracts; init=0.0)
        if !isapprox(total_vol, 1.0; atol=0.01)
            error("PayerMix overall_volume_pct must sum to 1.0 (got $(round(total_vol, digits=4)))")
        end
        return new(contracts, effective_date, notes)
    end
end

function Base.show(io::IO, pm::PayerMix)
    n = length(pm.contracts)
    print(io, "PayerMix($(n) payers, effective=$(pm.effective_date))")
end

"""
    get_contract(pm::PayerMix, payer_type::Symbol) -> Union{PayerContract, Nothing}

Retrieve the first contract matching the given payer type.
"""
function get_contract(pm::PayerMix, payer_type::Symbol)
    idx = findfirst(c -> c.payer_type == payer_type, pm.contracts)
    return idx === nothing ? nothing : pm.contracts[idx]
end

"""
    weighted_payment_rate(pm::PayerMix, service::Symbol) -> Float64

Compute the volume-weighted average payment rate across all payers
for a given service type (:inpatient, :outpatient, or :ed).
"""
function weighted_payment_rate(pm::PayerMix, service::Symbol)
    rate_field = if service == :inpatient
        :payment_rate_inpatient
    elseif service == :outpatient
        :payment_rate_outpatient
    elseif service == :ed
        :payment_rate_ed
    else
        error("Unknown service type: $service. Expected :inpatient, :outpatient, or :ed.")
    end

    vol_field = if service == :inpatient
        :inpatient_volume_pct
    elseif service == :outpatient
        :outpatient_volume_pct
    else
        :ed_volume_pct
    end

    total_vol = sum(getfield(c, vol_field) for c in pm.contracts; init=0.0)
    total_vol == 0.0 && return 0.0

    return sum(
        getfield(c, vol_field) * getfield(c, rate_field)
        for c in pm.contracts;
        init=0.0
    ) / total_vol
end
