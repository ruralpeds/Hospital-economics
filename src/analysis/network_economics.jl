# ============================================================================
# Rural Health Network Economics — shared-service savings, ACO economics,
# and joint purchasing power for rural hospital networks.
# ============================================================================

"""
    NetworkMember

Hospital or facility in a rural health network with revenue, expenses,
FTE count, and active service lines.
"""
@kwdef struct NetworkMember
    name::String
    annual_revenue::Float64
    annual_expenses::Float64
    fte_count::Int
    service_lines::Vector{String} = String[]
end

function Base.show(io::IO, m::NetworkMember)
    margin = m.annual_revenue > 0 ?
        round((m.annual_revenue - m.annual_expenses) / m.annual_revenue * 100; digits=1) : 0.0
    print(io, "NetworkMember(\"", m.name, "\", margin=", margin, "%)")
end

"""Shared service: current vs. network cost per member with implementation cost."""
@kwdef struct SharedService
    service_name::String
    current_cost_per_member::Float64
    network_cost_per_member::Float64
    implementation_cost::Float64 = 0.0
    ramp_up_years::Int           = 1
end

function Base.show(io::IO, s::SharedService)
    savings_pct = s.current_cost_per_member > 0 ?
        round((1.0 - s.network_cost_per_member / s.current_cost_per_member) * 100; digits=1) : 0.0
    print(io, "SharedService(\"", s.service_name, "\", savings=", savings_pct, "%)")
end

"""Aggregated network economics: savings, implementation cost, and breakeven."""
@kwdef struct NetworkResult
    members::Vector{NetworkMember}
    shared_services::Vector{SharedService}
    total_current_cost::Float64
    total_network_cost::Float64
    annual_savings::Float64
    implementation_cost::Float64
    breakeven_years::Float64
    per_member_savings::Vector{NamedTuple}
end

function Base.show(io::IO, r::NetworkResult)
    print(io, "NetworkResult(members=", length(r.members),
          ", annual_savings=\$", round(Int, r.annual_savings),
          ", breakeven=", round(r.breakeven_years; digits=1), "yr)")
end

"""Calculate per-member and total savings from shared services with breakeven."""
function evaluate_network(members::Vector{NetworkMember},
                          services::Vector{SharedService})::NetworkResult
    isempty(members) && error("At least one NetworkMember is required")
    isempty(services) && error("At least one SharedService is required")
    for m in members
        m.annual_revenue >= 0.0 || error("annual_revenue must be non-negative for $(m.name); got $(m.annual_revenue)")
        m.annual_expenses >= 0.0 || error("annual_expenses must be non-negative for $(m.name); got $(m.annual_expenses)")
        m.fte_count >= 0 || error("fte_count must be non-negative for $(m.name); got $(m.fte_count)")
    end
    for s in services
        s.current_cost_per_member >= 0.0 || error("current_cost_per_member must be non-negative for $(s.service_name); got $(s.current_cost_per_member)")
        s.network_cost_per_member >= 0.0 || error("network_cost_per_member must be non-negative for $(s.service_name); got $(s.network_cost_per_member)")
        s.implementation_cost >= 0.0 || error("implementation_cost must be non-negative for $(s.service_name); got $(s.implementation_cost)")
    end

    n_members = length(members)

    total_current = 0.0
    total_network = 0.0
    total_impl    = 0.0

    per_member = NamedTuple[]

    for m in members
        member_current = 0.0
        member_network = 0.0
        member_impl    = 0.0

        for s in services
            member_current += s.current_cost_per_member
            member_network += s.network_cost_per_member
            member_impl    += s.implementation_cost
        end

        member_savings = member_current - member_network

        total_current += member_current
        total_network += member_network
        total_impl    += member_impl

        push!(per_member, (
            name                = m.name,
            current_cost        = round(member_current; digits=2),
            network_cost        = round(member_network; digits=2),
            annual_savings      = round(member_savings; digits=2),
            implementation_cost = round(member_impl; digits=2),
        ))
    end

    annual_savings = total_current - total_network
    breakeven = annual_savings > 0 ? total_impl / annual_savings : Inf

    return NetworkResult(
        members            = members,
        shared_services    = services,
        total_current_cost = round(total_current; digits=2),
        total_network_cost = round(total_network; digits=2),
        annual_savings     = round(annual_savings; digits=2),
        implementation_cost = round(total_impl; digits=2),
        breakeven_years    = round(breakeven; digits=2),
        per_member_savings = per_member,
    )
end

"""Estimate combined ACO economics: benchmark, actual cost, shared savings (50/50 split)."""
function network_aco_formation(members::Vector{NetworkMember};
                               benchmark_per_beneficiary::Float64=12_000.0,
                               total_beneficiaries::Int=5000)::NamedTuple
    !isempty(members) || error("members must not be empty")
    benchmark_per_beneficiary > 0.0 || error("benchmark_per_beneficiary must be positive; got $benchmark_per_beneficiary")
    total_beneficiaries > 0 || error("total_beneficiaries must be positive; got $total_beneficiaries")

    total_revenue  = sum(m.annual_revenue for m in members)
    total_expenses = sum(m.annual_expenses for m in members)

    total_benchmark = benchmark_per_beneficiary * total_beneficiaries

    # Estimate per-beneficiary cost from combined expense base
    # Assume Medicare beneficiaries represent ~40% of expenses
    medicare_expense_share = total_expenses * 0.40
    cost_per_beneficiary = total_beneficiaries > 0 ?
        medicare_expense_share / total_beneficiaries : 0.0

    # Network efficiency discount: larger networks achieve ~2-5% savings
    efficiency_factor = clamp(1.0 - 0.005 * length(members), 0.90, 1.0)
    adjusted_cost_per_bene = cost_per_beneficiary * efficiency_factor

    total_actual_cost = adjusted_cost_per_bene * total_beneficiaries
    gross_savings = total_benchmark - total_actual_cost

    # Minimum savings rate (MSR) threshold: 2% for networks > 25k beneficiaries
    msr = total_beneficiaries >= 25_000 ? 0.02 : 0.033
    msr_threshold = total_benchmark * msr

    qualifies_for_savings = gross_savings > msr_threshold
    shared_savings_payment = qualifies_for_savings ? gross_savings * 0.50 : 0.0

    return (
        total_benchmark          = round(total_benchmark; digits=2),
        cost_per_beneficiary     = round(adjusted_cost_per_bene; digits=2),
        total_actual_cost        = round(total_actual_cost; digits=2),
        gross_savings            = round(gross_savings; digits=2),
        savings_rate             = total_benchmark > 0 ?
            round(gross_savings / total_benchmark; digits=4) : 0.0,
        msr_threshold            = round(msr_threshold; digits=2),
        qualifies_for_savings    = qualifies_for_savings,
        shared_savings_payment   = round(shared_savings_payment; digits=2),
        per_member_payment       = round(shared_savings_payment / max(length(members), 1); digits=2),
    )
end

"""Estimate GPO savings based on combined volume with tiered discounts."""
function joint_purchasing_savings(members::Vector{NetworkMember};
                                  base_discount::Float64=0.05,
                                  volume_bonus_per_million::Float64=0.01)::NamedTuple
    !isempty(members) || error("members must not be empty")
    0.0 <= base_discount <= 1.0 || error("base_discount must be between 0 and 1; got $base_discount")
    volume_bonus_per_million >= 0.0 || error("volume_bonus_per_million must be non-negative; got $volume_bonus_per_million")

    # Assume supply costs are ~30% of total expenses
    supply_pct = 0.30
    individual_savings = NamedTuple[]
    total_supply_spend = 0.0

    for m in members
        total_supply_spend += m.annual_expenses * supply_pct
    end

    # Volume bonus scales with total millions in supply spend
    millions = total_supply_spend / 1_000_000.0
    volume_bonus = clamp(millions * volume_bonus_per_million, 0.0, 0.15)
    effective_discount = base_discount + volume_bonus

    total_savings = total_supply_spend * effective_discount

    for m in members
        member_supply = m.annual_expenses * supply_pct
        member_share = total_supply_spend > 0 ? member_supply / total_supply_spend : 0.0
        member_savings = total_savings * member_share

        push!(individual_savings, (
            name           = m.name,
            supply_spend   = round(member_supply; digits=2),
            annual_savings = round(member_savings; digits=2),
        ))
    end

    return (
        combined_supply_spend = round(total_supply_spend; digits=2),
        base_discount         = base_discount,
        volume_bonus          = round(volume_bonus; digits=4),
        effective_discount    = round(effective_discount; digits=4),
        total_annual_savings  = round(total_savings; digits=2),
        per_member_detail     = individual_savings,
    )
end
