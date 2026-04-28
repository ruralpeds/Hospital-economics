"""
A-13: Network Economics & Multi-Hospital System Valuation

Models financial interactions between hospitals in integrated delivery systems,
including patient flow, referral patterns, shared services, and network-level
economics that differ from standalone hospital analysis.
"""

struct HospitalNode
    hospital_id::String
    hospital_type::Symbol  # :anchor, :critical_access, :specialty, :urgent_care
    annual_revenue::Float64
    annual_margin_pct::Float64
    service_lines::Vector{String}
end

struct NetworkTransfer
    from_hospital::String
    to_hospital::String
    annual_patient_volume::Int
    avg_transfer_value::Float64
    coordination_cost::Float64
end

struct NetworkEconomics
    hospital_id::String
    standalone_margin::Float64
    inbound_referral_revenue::Float64
    outbound_referral_cost::Float64
    shared_service_savings::Float64
    network_discount_impact::Float64
    network_adjusted_margin::Float64
    network_margin_improvement_pct::Float64
end

struct NetworkAnalysisResult
    total_hospitals::Int
    total_network_revenue::Float64
    standalone_total_margin::Float64
    network_total_margin::Float64
    network_synergy_value::Float64
    average_margin_improvement_pct::Float64
    critical_nodes::Vector{String}
    recommended_integrations::Vector{String}
end

"""
    calculate_network_margin_impact(hospital::HospitalNode, transfers::Vector{NetworkTransfer},
                                   shared_savings_pct::Float64=0.03) -> NetworkEconomics

Calculate network-adjusted financial impact for a hospital in system.

Accounts for referral volume, transfer costs, and shared service savings.
"""
function calculate_network_margin_impact(hospital::HospitalNode, transfers::Vector{NetworkTransfer},
                                        shared_savings_pct::Float64=0.03)::NetworkEconomics
    # Calculate inbound revenue (from other hospitals referring to this hospital)
    inbound_revenue = sum(
        t.annual_patient_volume * t.avg_transfer_value
        for t in transfers if t.to_hospital == hospital.hospital_id
    )

    # Calculate outbound costs (this hospital referring to others)
    outbound_cost = sum(
        t.annual_patient_volume * t.avg_transfer_value + t.coordination_cost
        for t in transfers if t.from_hospital == hospital.hospital_id
    )

    # Shared service savings (e.g., shared labs, imaging, supply chain)
    shared_savings = hospital.annual_revenue * shared_savings_pct

    # Network discount impact (lower negotiating position for rates)
    network_discount = hospital.annual_revenue * 0.01  # Typically -1% to -2%

    # Standalone contribution
    standalone_margin = hospital.annual_revenue * (hospital.annual_margin_pct / 100.0)

    # Network-adjusted contribution
    total_revenue_adjustment = inbound_revenue - outbound_cost
    total_margin_adjustment = shared_savings - network_discount

    network_margin = standalone_margin + total_margin_adjustment + inbound_revenue
    network_margin_improvement_pct = total_margin_adjustment > 0 ?
        (total_margin_adjustment / abs(standalone_margin + 1)) * 100 : 0.0

    NetworkEconomics(
        hospital.hospital_id,
        hospital.annual_margin_pct,
        inbound_revenue,
        outbound_cost,
        shared_savings,
        network_discount,
        (network_margin / hospital.annual_revenue) * 100,  # As percentage
        network_margin_improvement_pct
    )
end

"""
    analyze_network_system(hospitals::Vector{HospitalNode}, transfers::Vector{NetworkTransfer}) -> NetworkAnalysisResult

Analyze network-level economics and identify integration opportunities.

Returns synergy value, critical nodes, and recommended integrations.
"""
function analyze_network_system(hospitals::Vector{HospitalNode}, transfers::Vector{NetworkTransfer})::NetworkAnalysisResult
    if isempty(hospitals)
        return NetworkAnalysisResult(0, 0.0, 0.0, 0.0, 0.0, 0.0, String[], String[])
    end

    # Calculate per-hospital network impact
    economics = [
        calculate_network_margin_impact(h, transfers)
        for h in hospitals
    ]

    # Totals
    standalone_total = sum(h.annual_revenue * (h.annual_margin_pct / 100) for h in hospitals)
    network_total = sum(e.network_adjusted_margin * hospitals[findfirst(x->x.hospital_id==e.hospital_id, hospitals)].annual_revenue / 100 for e in economics)
    network_synergy = network_total - standalone_total

    avg_improvement = !isempty(economics) ?
        mean(e.network_margin_improvement_pct for e in economics) : 0.0

    # Identify critical nodes (high volume transfers)
    transfer_volume = Dict{String, Int}()
    for t in transfers
        transfer_volume[t.from_hospital] = get(transfer_volume, t.from_hospital, 0) + t.annual_patient_volume
        transfer_volume[t.to_hospital] = get(transfer_volume, t.to_hospital, 0) + t.annual_patient_volume
    end
    critical_nodes = sort(collect(keys(transfer_volume)), by=k->transfer_volume[k], rev=true)[1:min(3, length(transfer_volume))]

    # Recommend integrations where margin improvement potential is high
    recommendations = [
        e.hospital_id
        for e in economics
        if e.network_margin_improvement_pct > 2.0 && e.network_margin_improvement_pct < 10.0
    ]

    NetworkAnalysisResult(
        length(hospitals),
        sum(h.annual_revenue for h in hospitals),
        standalone_total,
        network_total,
        network_synergy,
        avg_improvement,
        critical_nodes,
        recommendations
    )
end
