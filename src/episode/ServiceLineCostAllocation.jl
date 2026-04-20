# episode/ServiceLineCostAllocation.jl — Service line cost allocation methods

using Statistics

"""
    allocate_indirect_costs_proportional(
        service_lines::Vector{ServiceLine},
        total_indirect_costs::Float64
    )::Vector{ServiceLine}

Allocate indirect costs proportionally based on direct costs.
Each service line receives a share of overhead equal to its percentage of total direct costs.
"""
function allocate_indirect_costs_proportional(
    service_lines::Vector{ServiceLine},
    total_indirect_costs::Float64
)::Vector{ServiceLine}

    total_direct = sum(sl.direct_cost for sl in service_lines)

    if total_direct <= 0
        # Equal allocation if no direct costs
        allocation_per = total_indirect_costs / length(service_lines)
        return [ServiceLine(
            id=sl.id, name=sl.name, department=sl.department,
            drg_codes=sl.drg_codes, volume=sl.volume,
            revenue=sl.revenue, direct_cost=sl.direct_cost,
            allocated_indirect_cost=allocation_per
        ) for sl in service_lines]
    end

    return [ServiceLine(
        id=sl.id, name=sl.name, department=sl.department,
        drg_codes=sl.drg_codes, volume=sl.volume,
        revenue=sl.revenue, direct_cost=sl.direct_cost,
        allocated_indirect_cost=(sl.direct_cost / total_direct) * total_indirect_costs
    ) for sl in service_lines]
end

"""
    allocate_indirect_costs_activity_based(
        service_lines::Vector{ServiceLine},
        total_indirect_costs::Float64
    )::Vector{ServiceLine}

Allocate indirect costs based on volume (activity).
Each service line receives a share equal to its percentage of total volume.
"""
function allocate_indirect_costs_activity_based(
    service_lines::Vector{ServiceLine},
    total_indirect_costs::Float64
)::Vector{ServiceLine}

    total_volume = sum(sl.volume for sl in service_lines)

    if total_volume <= 0
        # Equal allocation if no volume
        allocation_per = total_indirect_costs / length(service_lines)
        return [ServiceLine(
            id=sl.id, name=sl.name, department=sl.department,
            drg_codes=sl.drg_codes, volume=sl.volume,
            revenue=sl.revenue, direct_cost=sl.direct_cost,
            allocated_indirect_cost=allocation_per
        ) for sl in service_lines]
    end

    return [ServiceLine(
        id=sl.id, name=sl.name, department=sl.department,
        drg_codes=sl.drg_codes, volume=sl.volume,
        revenue=sl.revenue, direct_cost=sl.direct_cost,
        allocated_indirect_cost=(sl.volume / total_volume) * total_indirect_costs
    ) for sl in service_lines]
end

"""
    allocate_indirect_costs_step_down(
        service_lines::Vector{ServiceLine},
        total_indirect_costs::Float64;
        support_pct::Float64 = 0.1
    )::Vector{ServiceLine}

Step-down allocation method.
First allocates a portion to support services, then allocates remaining to clinical services.
"""
function allocate_indirect_costs_step_down(
    service_lines::Vector{ServiceLine},
    total_indirect_costs::Float64;
    support_pct::Float64 = 0.1
)::Vector{ServiceLine}

    # Allocate support costs (typically 10% of overhead)
    support_cost = total_indirect_costs * support_pct
    clinical_cost = total_indirect_costs - support_cost

    # Assume "Support" department is not included in service_lines
    # Allocate remaining clinical costs proportionally
    total_direct = sum(sl.direct_cost for sl in service_lines)

    if total_direct <= 0
        allocation_per = clinical_cost / length(service_lines)
        return [ServiceLine(
            id=sl.id, name=sl.name, department=sl.department,
            drg_codes=sl.drg_codes, volume=sl.volume,
            revenue=sl.revenue, direct_cost=sl.direct_cost,
            allocated_indirect_cost=allocation_per
        ) for sl in service_lines]
    end

    return [ServiceLine(
        id=sl.id, name=sl.name, department=sl.department,
        drg_codes=sl.drg_codes, volume=sl.volume,
        revenue=sl.revenue, direct_cost=sl.direct_cost,
        allocated_indirect_cost=(sl.direct_cost / total_direct) * clinical_cost
    ) for sl in service_lines]
end

"""
    analyze_service_lines(
        service_lines::Vector{ServiceLine},
        total_indirect_costs::Float64;
        allocation_method::Symbol = :proportional
    )::ServiceLineAnalysisResult

Analyze service line profitability with cost allocation.

# Arguments
- `service_lines::Vector{ServiceLine}` — Service lines to analyze
- `total_indirect_costs::Float64` — Total overhead/indirect costs to allocate
- `allocation_method::Symbol` — One of :proportional, :activity_based, :step_down

# Returns
- `ServiceLineAnalysisResult` with complete analysis
"""
function analyze_service_lines(
    service_lines::Vector{ServiceLine},
    total_indirect_costs::Float64;
    allocation_method::Symbol = :proportional
)::ServiceLineAnalysisResult

    # Allocate indirect costs
    allocated_lines = if allocation_method == :activity_based
        allocate_indirect_costs_activity_based(service_lines, total_indirect_costs)
    elseif allocation_method == :step_down
        allocate_indirect_costs_step_down(service_lines, total_indirect_costs)
    else  # default to proportional
        allocate_indirect_costs_proportional(service_lines, total_indirect_costs)
    end

    # Calculate metrics for each service line
    metrics_dict = Dict{String, ServiceLineMetrics}()
    for sl in allocated_lines
        metrics_dict[sl.id] = calculate_service_line_metrics(sl)
    end

    # Aggregate results
    total_revenue = sum(sl.revenue for sl in allocated_lines)
    total_direct_cost = sum(sl.direct_cost for sl in allocated_lines)
    total_indirect_cost = sum(sl.allocated_indirect_cost for sl in allocated_lines)
    total_margin = total_revenue - total_direct_cost - total_indirect_cost
    total_margin_pct = total_revenue > 0 ? (total_margin / total_revenue * 100) : 0.0

    # Classify services
    profitable = String[]
    loss_making = String[]
    margin_by_service = Dict{String, Float64}()

    for (id, metrics) in metrics_dict
        margin = metrics.allocated_margin
        margin_by_service[id] = margin

        if metrics.profitability_status == :profitable
            push!(profitable, id)
        elseif metrics.profitability_status == :loss
            push!(loss_making, id)
        end
    end

    # Identify cost drivers
    cost_drivers = Dict{String, Float64}()
    cost_drivers["total_direct_cost"] = total_direct_cost
    cost_drivers["total_indirect_cost"] = total_indirect_cost

    # Top cost drivers by service line
    for sl in allocated_lines
        if sl.direct_cost > 0
            cost_drivers[sl.id] = sl.direct_cost
        end
    end

    # Generate recommendations
    recommendations = generate_recommendations(allocated_lines, metrics_dict, total_margin_pct)

    ServiceLineAnalysisResult(
        allocated_lines,
        metrics_dict,
        total_revenue,
        total_direct_cost,
        total_indirect_cost,
        total_margin,
        total_margin_pct,
        margin_by_service,
        profitable,
        loss_making,
        cost_drivers,
        allocation_method,
        recommendations
    )
end

"""
    generate_recommendations(
        service_lines::Vector{ServiceLine},
        metrics::Dict{String, ServiceLineMetrics},
        overall_margin_pct::Float64
    )::Vector{String}

Generate actionable recommendations for hospital CFO.
"""
function generate_recommendations(
    service_lines::Vector{ServiceLine},
    metrics::Dict{String, ServiceLineMetrics},
    overall_margin_pct::Float64
)::Vector{String}

    recommendations = String[]

    # Identify loss-making services
    loss_services = [sl for sl in service_lines if metrics[sl.id].profitability_status == :loss]
    if !isempty(loss_services)
        for sl in loss_services
            push!(recommendations, "SERVICE LINE '$(sl.name)' IS LOSING \$$(abs(metrics[sl.id].allocated_margin)) per year — consider restructuring or divestment")
        end
    end

    # Identify high-volume low-margin services
    for sl in service_lines
        m = metrics[sl.id]
        if sl.volume > 100 && m.allocated_margin_pct < 5
            push!(recommendations, "SERVICE LINE '$(sl.name)' has high volume ($(sl.volume)) but low margin ($(round(m.allocated_margin_pct, digits=1))%) — focus on cost reduction")
        end
    end

    # Check overall hospital margin
    if overall_margin_pct < 2
        push!(recommendations, "OVERALL HOSPITAL MARGIN IS THIN ($(round(overall_margin_pct, digits=1))%) — increase prices or reduce overhead")
    elseif overall_margin_pct > 10
        push!(recommendations, "OVERALL MARGIN IS HEALTHY ($(round(overall_margin_pct, digits=1))%) — focus on maintaining current profitability")
    end

    # Identify high-cost services
    sorted_by_cost = sort(service_lines, by=sl -> sl.direct_cost, rev=true)
    if !isempty(sorted_by_cost) && length(sorted_by_cost) > 0
        top_cost = sorted_by_cost[1]
        push!(recommendations, "TOP COST DRIVER: '$(top_cost.name)' accounts for \$$(top_cost.direct_cost) in direct costs")
    end

    if isempty(recommendations)
        push!(recommendations, "Service lines appear stable — continue monitoring profitability by service")
    end

    return recommendations
end
