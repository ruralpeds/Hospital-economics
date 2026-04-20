# episode/ServiceLineTypes.jl — Service line profitability analysis types

"""
    ServiceLine

Represents a single service line within a hospital (e.g., Orthopedics, Cardiology, Emergency).
Contains volume, revenue, and cost information for profitability analysis.

# Fields
- `id::String` — Unique service line identifier
- `name::String` — Service line name (e.g., "Orthopedic Surgery")
- `department::String` — Department code
- `drg_codes::Vector{String}` — DRG codes associated with this service line
- `volume::Int` — Number of episodes/cases
- `revenue::Float64` — Total revenue (in dollars)
- `direct_cost::Float64` — Direct costs (labor, supplies, equipment)
- `allocated_indirect_cost::Float64` — Indirect costs allocated from overhead
"""
struct ServiceLine
    id::String
    name::String
    department::String
    drg_codes::Vector{String}
    volume::Int
    revenue::Float64
    direct_cost::Float64
    allocated_indirect_cost::Float64

    function ServiceLine(;
        id::String,
        name::String,
        department::String,
        drg_codes::Vector{String},
        volume::Int,
        revenue::Float64,
        direct_cost::Float64,
        allocated_indirect_cost::Float64 = 0.0
    )
        validate_service_line(id, name, volume, revenue, direct_cost)
        new(id, name, department, drg_codes, volume, revenue, direct_cost, allocated_indirect_cost)
    end
end

function validate_service_line(id::String, name::String, volume::Int, revenue::Float64, direct_cost::Float64)
    @assert !isempty(id) "Service line ID cannot be empty"
    @assert !isempty(name) "Service line name cannot be empty"
    @assert volume >= 0 "Volume cannot be negative"
    @assert revenue >= 0.0 "Revenue cannot be negative"
    @assert direct_cost >= 0.0 "Direct cost cannot be negative"
end

"""
    ServiceLineMetrics

Financial metrics calculated for a service line.

# Fields
- `service_line_id::String` — Service line identifier
- `contribution_margin::Float64` — Revenue minus direct costs
- `contribution_margin_pct::Float64` — Contribution margin as % of revenue
- `allocated_margin::Float64` — After indirect cost allocation
- `allocated_margin_pct::Float64` — Allocated margin as % of revenue
- `revenue_per_case::Float64` — Average revenue per episode
- `direct_cost_per_case::Float64` — Average direct cost per episode
- `total_cost_per_case::Float64` — Average total cost per episode
- `profitability_status::Symbol` — :profitable, :breakeven, or :loss
"""
struct ServiceLineMetrics
    service_line_id::String
    contribution_margin::Float64
    contribution_margin_pct::Float64
    allocated_margin::Float64
    allocated_margin_pct::Float64
    revenue_per_case::Float64
    direct_cost_per_case::Float64
    total_cost_per_case::Float64
    profitability_status::Symbol
end

"""
    CostAllocationMethod

Specifies the method for allocating indirect costs.
- `:proportional` — Allocate based on direct costs
- `:activity_based` — Allocate based on volume
- `:step_down` — Sequential allocation method
"""
const CostAllocationMethod = Symbol

"""
    ServiceLineAnalysisResult

Complete analysis results for a set of service lines.

# Fields
- `service_lines::Vector{ServiceLine}` — All service lines analyzed
- `metrics::Dict{String, ServiceLineMetrics}` — Metrics by service line ID
- `total_revenue::Float64` — Sum of all revenues
- `total_direct_cost::Float64` — Sum of all direct costs
- `total_indirect_cost::Float64` — Sum of all allocated indirect costs
- `total_margin::Float64` — Total margin across all service lines
- `total_margin_pct::Float64` — Overall margin percentage
- `margin_by_service::Dict{String, Float64}` — Margin by service line ID
- `profitable_services::Vector{String}` — IDs of profitable service lines
- `loss_services::Vector{String}` — IDs of service lines with losses
- `cost_drivers::Dict{String, Float64}` — Top cost drivers and amounts
- `allocation_method::CostAllocationMethod` — Method used for allocation
- `recommendations::Vector{String}` — Action items for CFO
"""
struct ServiceLineAnalysisResult
    service_lines::Vector{ServiceLine}
    metrics::Dict{String, ServiceLineMetrics}
    total_revenue::Float64
    total_direct_cost::Float64
    total_indirect_cost::Float64
    total_margin::Float64
    total_margin_pct::Float64
    margin_by_service::Dict{String, Float64}
    profitable_services::Vector{String}
    loss_services::Vector{String}
    cost_drivers::Dict{String, Float64}
    allocation_method::CostAllocationMethod
    recommendations::Vector{String}
end

"""
    calculate_service_line_metrics(service_line::ServiceLine)::ServiceLineMetrics

Calculate financial metrics for a single service line.
"""
function calculate_service_line_metrics(sl::ServiceLine)::ServiceLineMetrics
    contribution_margin = sl.revenue - sl.direct_cost
    contribution_margin_pct = sl.volume > 0 ? (contribution_margin / sl.revenue * 100) : 0.0

    allocated_margin = contribution_margin - sl.allocated_indirect_cost
    allocated_margin_pct = sl.volume > 0 ? (allocated_margin / sl.revenue * 100) : 0.0

    revenue_per_case = sl.volume > 0 ? sl.revenue / sl.volume : 0.0
    direct_cost_per_case = sl.volume > 0 ? sl.direct_cost / sl.volume : 0.0
    total_cost_per_case = direct_cost_per_case + (sl.volume > 0 ? sl.allocated_indirect_cost / sl.volume : 0.0)

    profitability = if allocated_margin > 100
        :profitable
    elseif allocated_margin > -100
        :breakeven
    else
        :loss
    end

    ServiceLineMetrics(
        sl.id,
        contribution_margin,
        contribution_margin_pct,
        allocated_margin,
        allocated_margin_pct,
        revenue_per_case,
        direct_cost_per_case,
        total_cost_per_case,
        profitability
    )
end
