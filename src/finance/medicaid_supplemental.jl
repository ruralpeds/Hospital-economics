# Medicaid DSH/UPL/SDP Supplemental Payment Calculations
#
# Models Medicaid supplemental payment programs including Disproportionate
# Share Hospital (DSH), Upper Payment Limit (UPL), and State Directed
# Payments (SDP) critical to rural hospital financial viability.

"""
    MedicaidSupplementalParams

Parameters for calculating Medicaid supplemental payments.

# Fields
- `medicaid_costs::Float64`: total Medicaid-allowable costs
- `medicaid_payments::Float64`: base Medicaid fee-for-service payments received
- `uncompensated_care_costs::Float64`: costs of care for uninsured patients
- `gross_patient_revenue::Float64`: total gross charges
- `total_operating_expenses::Float64`: total hospital operating expenses
- `provider_class::Symbol`: ownership type (:state_owned, :non_state_govt, :private)
- `state_has_expansion::Bool`: whether state has expanded Medicaid (default true)
- `provider_tax_rate::Float64`: state provider tax rate as fraction (default 0.0)
"""
@kwdef struct MedicaidSupplementalParams
    medicaid_costs::Float64
    medicaid_payments::Float64
    uncompensated_care_costs::Float64
    gross_patient_revenue::Float64
    total_operating_expenses::Float64
    provider_class::Symbol = :private
    state_has_expansion::Bool = true
    provider_tax_rate::Float64 = 0.0
end

"""
    MedicaidSupplementalResult

Results of Medicaid supplemental payment calculations.

# Fields
- `dsh_limit::Float64`: maximum allowable DSH payment (uncompensated care limit)
- `dsh_payment::Float64`: estimated DSH payment
- `upl_room::Float64`: available room under upper payment limit
- `upl_payment::Float64`: estimated UPL supplemental payment
- `sdp_payment::Float64`: estimated state directed payment
- `total_supplemental::Float64`: sum of all supplemental payments
- `net_medicaid_shortfall::Float64`: remaining gap after supplemental payments
- `provider_tax_cost::Float64`: provider tax paid to the state
"""
@kwdef struct MedicaidSupplementalResult
    dsh_limit::Float64
    dsh_payment::Float64
    upl_room::Float64
    upl_payment::Float64
    sdp_payment::Float64
    total_supplemental::Float64
    net_medicaid_shortfall::Float64
    provider_tax_cost::Float64
end

function Base.show(io::IO, r::MedicaidSupplementalResult)
    print(io, "MedicaidSupplementalResult(total=\$$(round(Int, r.total_supplemental)), shortfall=\$$(round(Int, r.net_medicaid_shortfall)))")
end

"""
    calculate_medicaid_supplemental(params::MedicaidSupplementalParams) -> MedicaidSupplementalResult

Calculate Medicaid supplemental payments under DSH, UPL, and SDP programs.

- DSH limit = (medicaid_costs + uncompensated_care_costs) - medicaid_payments
- DSH payment = fraction of DSH limit based on provider class
- UPL room = estimated Medicare-equivalent cost - (medicaid base + DSH)
- SDP = state-directed payment estimated from operating expenses and provider class
"""
function calculate_medicaid_supplemental(params::MedicaidSupplementalParams)::MedicaidSupplementalResult
    params.medicaid_costs >= 0.0 || error("medicaid_costs must be non-negative")
    params.provider_class in (:state_owned, :non_state_govt, :private) ||
        error("provider_class must be :state_owned, :non_state_govt, or :private; got $(params.provider_class)")

    # --- DSH Calculation ---
    # Hospital-specific DSH limit per federal statute
    dsh_limit = max(0.0, (params.medicaid_costs + params.uncompensated_care_costs) - params.medicaid_payments)

    # DSH payment as fraction of limit varies by provider class and state factors
    dsh_pct = if params.provider_class == :state_owned
        0.70
    elseif params.provider_class == :non_state_govt
        0.55
    else  # :private
        0.40
    end
    dsh_payment = dsh_limit * dsh_pct

    # --- UPL Calculation ---
    # Medicare-equivalent cost estimate: assume Medicare pays ~92% of cost
    # UPL room = what Medicare would pay - what Medicaid actually pays (base + DSH)
    cost_to_charge = params.total_operating_expenses > 0.0 ?
        params.total_operating_expenses / max(params.gross_patient_revenue, 1.0) : 0.60
    medicare_equivalent = params.medicaid_costs / max(cost_to_charge, 0.01) * cost_to_charge * 1.00
    # UPL allows payments up to Medicare-equivalent level
    medicaid_total_before_upl = params.medicaid_payments + dsh_payment
    upl_room = max(0.0, medicare_equivalent - medicaid_total_before_upl)

    # UPL payment: states typically capture 60-80% of available room
    upl_capture_rate = params.provider_class == :state_owned ? 0.80 : 0.60
    upl_payment = upl_room * upl_capture_rate

    # --- SDP Calculation ---
    # State Directed Payments: estimated as percentage of Medicaid costs
    # Private hospitals in expansion states tend to receive larger SDPs
    sdp_base_rate = if params.state_has_expansion
        params.provider_class == :private ? 0.08 : 0.05
    else
        params.provider_class == :private ? 0.04 : 0.03
    end
    sdp_payment = params.medicaid_costs * sdp_base_rate

    # --- Provider Tax ---
    provider_tax_cost = params.gross_patient_revenue * params.provider_tax_rate

    # --- Totals ---
    total_supplemental = dsh_payment + upl_payment + sdp_payment
    total_medicaid_received = params.medicaid_payments + total_supplemental
    net_shortfall = max(0.0, params.medicaid_costs - total_medicaid_received)

    return MedicaidSupplementalResult(
        dsh_limit = dsh_limit,
        dsh_payment = dsh_payment,
        upl_room = upl_room,
        upl_payment = upl_payment,
        sdp_payment = sdp_payment,
        total_supplemental = total_supplemental,
        net_medicaid_shortfall = net_shortfall,
        provider_tax_cost = provider_tax_cost,
    )
end

"""
    medicaid_reform_scenarios(params::MedicaidSupplementalParams) -> Vector{NamedTuple}

Model three Medicaid supplemental payment reform scenarios:
1. Current law (baseline)
2. Moderate reform: 50% reduction in SDP payments
3. Significant reform: Medicaid expansion rollback + SDP elimination
"""
function medicaid_reform_scenarios(params::MedicaidSupplementalParams)::Vector{NamedTuple}
    # Scenario 1: Current law
    current = calculate_medicaid_supplemental(params)

    # Scenario 2: Moderate reform — 50% SDP reduction
    moderate = calculate_medicaid_supplemental(params)
    moderate_sdp = moderate.sdp_payment * 0.50
    moderate_total = moderate.dsh_payment + moderate.upl_payment + moderate_sdp
    moderate_shortfall = max(0.0, params.medicaid_costs - (params.medicaid_payments + moderate_total))

    # Scenario 3: Significant reform — expansion rollback + SDP elimination
    sig_params = MedicaidSupplementalParams(
        medicaid_costs = params.medicaid_costs * (params.state_has_expansion ? 0.75 : 1.0),
        medicaid_payments = params.medicaid_payments * (params.state_has_expansion ? 0.70 : 1.0),
        uncompensated_care_costs = params.uncompensated_care_costs * (params.state_has_expansion ? 1.30 : 1.0),
        gross_patient_revenue = params.gross_patient_revenue,
        total_operating_expenses = params.total_operating_expenses,
        provider_class = params.provider_class,
        state_has_expansion = false,
        provider_tax_rate = params.provider_tax_rate,
    )
    sig = calculate_medicaid_supplemental(sig_params)
    sig_total = sig.dsh_payment + sig.upl_payment  # No SDP
    sig_shortfall = max(0.0, sig_params.medicaid_costs - (sig_params.medicaid_payments + sig_total))

    return [
        (scenario = :current_law, total_supplemental = current.total_supplemental,
         dsh = current.dsh_payment, upl = current.upl_payment, sdp = current.sdp_payment,
         net_shortfall = current.net_medicaid_shortfall),
        (scenario = :moderate_reform, total_supplemental = moderate_total,
         dsh = moderate.dsh_payment, upl = moderate.upl_payment, sdp = moderate_sdp,
         net_shortfall = moderate_shortfall),
        (scenario = :significant_reform, total_supplemental = sig_total,
         dsh = sig.dsh_payment, upl = sig.upl_payment, sdp = 0.0,
         net_shortfall = sig_shortfall),
    ]
end
