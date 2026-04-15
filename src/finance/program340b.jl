# 340B Drug Pricing Program calculations for Rural Hospital Economics Simulator
#
# Models the financial impact of the 340B Drug Pricing Program on eligible
# rural hospitals, including contract pharmacy arrangements and policy risk
# scenario analysis for potential program reforms.

"""
    Program340BParams

Input parameters for 340B Drug Pricing Program financial impact analysis.

# Fields
- `total_drug_spend::Float64`: total annual drug expenditures at non-340B prices
- `discount_rate::Float64`: average 340B discount as a fraction of acquisition cost (default 0.40 = 40%)
- `contract_pharmacy_pct::Float64`: fraction of 340B volume dispensed through contract pharmacies (default 0.30)
- `contract_pharmacy_fee::Float64`: per-prescription fee paid to contract pharmacies in dollars (default 15.0)
- `admin_cost_pct::Float64`: 340B program administrative costs as a fraction of gross savings (default 0.05)
- `at_risk_revenue_pct::Float64`: fraction of 340B benefit considered at risk from policy changes
"""
@kwdef struct Program340BParams
    total_drug_spend::Float64
    discount_rate::Float64 = 0.40
    contract_pharmacy_pct::Float64 = 0.30
    contract_pharmacy_fee::Float64 = 15.0
    admin_cost_pct::Float64 = 0.05
    at_risk_revenue_pct::Float64 = 0.0
end

"""
    Program340BResult

Output of 340B Drug Pricing Program financial impact analysis.

# Fields
- `gross_savings::Float64`: total savings from 340B drug discounts
- `contract_pharmacy_revenue::Float64`: net revenue from contract pharmacy spread
- `admin_costs::Float64`: administrative costs of running the 340B program
- `net_benefit::Float64`: net financial benefit after all costs
- `margin_impact::Float64`: net benefit expressed as potential margin improvement
- `at_risk_amount::Float64`: dollar amount of 340B benefit at risk from policy changes
"""
@kwdef struct Program340BResult
    gross_savings::Float64
    contract_pharmacy_revenue::Float64
    admin_costs::Float64
    net_benefit::Float64
    margin_impact::Float64
    at_risk_amount::Float64
end

function Base.show(io::IO, r::Program340BResult)
    print(io, "Program340BResult(net_benefit=\$$(round(Int, r.net_benefit)), at_risk=\$$(round(Int, r.at_risk_amount)))")
end

"""
    calculate_340b_impact(params::Program340BParams) -> Program340BResult

Calculate the financial impact of 340B Drug Pricing Program participation.

The model computes:
1. **Gross savings** from purchasing drugs at 340B ceiling prices
2. **Contract pharmacy revenue** from the spread between 340B cost and reimbursement
   at contract pharmacy locations, net of per-prescription fees
3. **Administrative costs** for compliance, tracking, and program management
4. **Net benefit** as gross savings plus contract pharmacy revenue minus admin costs
5. **At-risk amount** based on the specified policy risk percentage
"""
function calculate_340b_impact(params::Program340BParams)::Program340BResult
    # Gross savings from 340B discounted purchasing (non-contract-pharmacy portion)
    gross_savings = params.total_drug_spend * (1.0 - params.contract_pharmacy_pct) * params.discount_rate

    # Contract pharmacy component
    # Revenue from spread on contract pharmacy prescriptions
    contract_pharmacy_volume = params.total_drug_spend * params.contract_pharmacy_pct
    contract_pharmacy_spread = contract_pharmacy_volume * params.discount_rate
    # Estimate number of prescriptions (assume average $100 per Rx at full price)
    avg_rx_cost = 100.0
    num_contract_rxs = contract_pharmacy_volume / avg_rx_cost
    contract_pharmacy_fees = num_contract_rxs * params.contract_pharmacy_fee
    contract_pharmacy_revenue = contract_pharmacy_spread - contract_pharmacy_fees

    # Administrative costs
    admin_costs = gross_savings * params.admin_cost_pct

    # Net benefit
    net_benefit = gross_savings + max(contract_pharmacy_revenue, 0.0) - admin_costs

    # At-risk amount from potential policy changes
    at_risk_amount = net_benefit * params.at_risk_revenue_pct

    # Margin impact (same as net benefit for use in financial projections)
    margin_impact = net_benefit

    return Program340BResult(
        gross_savings = gross_savings,
        contract_pharmacy_revenue = contract_pharmacy_revenue,
        admin_costs = admin_costs,
        net_benefit = net_benefit,
        margin_impact = margin_impact,
        at_risk_amount = at_risk_amount,
    )
end

"""
    policy_risk_scenarios(params::Program340BParams) -> Vector{NamedTuple}

Generate three policy risk scenarios for 340B program financial impact:

1. **Current**: no policy changes, full 340B benefit retained
2. **Moderate reform**: contract pharmacy restrictions reduce contract pharmacy
   revenue by 50%; discount rate reduced by 10 percentage points
3. **Significant reform**: complete loss of contract pharmacy revenue;
   discount rate reduced by 20 percentage points; added compliance costs

Returns a vector of NamedTuples with fields `scenario`, `result`, and `description`.
"""
function policy_risk_scenarios(params::Program340BParams)::Vector{NamedTuple{(:scenario, :result, :description), Tuple{Symbol, Program340BResult, String}}}
    scenarios = NamedTuple{(:scenario, :result, :description), Tuple{Symbol, Program340BResult, String}}[]

    # Scenario 1: Current policy (no changes)
    current = calculate_340b_impact(params)
    push!(scenarios, (
        scenario = :current,
        result = current,
        description = "Current 340B program rules maintained with no legislative changes",
    ))

    # Scenario 2: Moderate reform
    moderate_params = Program340BParams(
        total_drug_spend = params.total_drug_spend,
        discount_rate = max(params.discount_rate - 0.10, 0.0),
        contract_pharmacy_pct = params.contract_pharmacy_pct * 0.50,
        contract_pharmacy_fee = params.contract_pharmacy_fee,
        admin_cost_pct = params.admin_cost_pct * 1.5,  # increased compliance burden
        at_risk_revenue_pct = params.at_risk_revenue_pct,
    )
    moderate = calculate_340b_impact(moderate_params)
    push!(scenarios, (
        scenario = :moderate_reform,
        result = moderate,
        description = "Contract pharmacy restrictions (50% reduction) and 10pp discount rate decrease",
    ))

    # Scenario 3: Significant reform
    significant_params = Program340BParams(
        total_drug_spend = params.total_drug_spend,
        discount_rate = max(params.discount_rate - 0.20, 0.0),
        contract_pharmacy_pct = 0.0,  # complete loss of contract pharmacy
        contract_pharmacy_fee = params.contract_pharmacy_fee,
        admin_cost_pct = params.admin_cost_pct * 2.0,  # doubled compliance costs
        at_risk_revenue_pct = params.at_risk_revenue_pct,
    )
    significant = calculate_340b_impact(significant_params)
    push!(scenarios, (
        scenario = :significant_reform,
        result = significant,
        description = "Complete contract pharmacy elimination, 20pp discount reduction, and doubled compliance costs",
    ))

    return scenarios
end
