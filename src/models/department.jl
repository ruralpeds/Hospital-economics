# Service line and department types for Rural Hospital Economics Simulator

"""
    Department

A clinical or operational department within a hospital.
"""
@kwdef mutable struct Department
    name::String
    department_code::String
    is_revenue_producing::Bool = true
    is_ancillary::Bool = false

    # Volume metrics
    annual_visits::Int = 0
    annual_procedures::Int = 0
    annual_patient_days::Int = 0
    annual_observation_hours::Float64 = 0.0

    # Financial metrics
    gross_revenue::Float64 = 0.0
    net_revenue::Float64 = 0.0
    direct_costs::Float64 = 0.0
    allocated_overhead::Float64 = 0.0
    total_costs::Float64 = 0.0
    contribution_margin::Float64 = 0.0
    cost_to_charge_ratio::Float64 = 0.0

    # Staffing
    budgeted_fte::Float64 = 0.0
    actual_fte::Float64 = 0.0
    productivity_benchmark::Float64 = 0.0  # units of service per FTE
    actual_productivity::Float64 = 0.0

    # Physical plant
    square_footage::Float64 = 0.0
    num_exam_rooms::Int = 0
    num_treatment_bays::Int = 0
    major_equipment_count::Int = 0
end

function Base.show(io::IO, d::Department)
    print(io, "Department(\"$(d.name)\", code=$(d.department_code), rev_producing=$(d.is_revenue_producing))")
end

"""
    ServiceLine

A strategic service line that may span multiple departments.
"""
@kwdef mutable struct ServiceLine
    name::String
    departments::Vector{Department} = Department[]
    is_active::Bool = true

    # Volume
    annual_volume::Int = 0

    # Financial summary
    total_gross_revenue::Float64 = 0.0
    total_net_revenue::Float64 = 0.0
    total_direct_costs::Float64 = 0.0
    total_costs::Float64 = 0.0
    contribution_margin::Float64 = 0.0
    operating_margin::Float64 = 0.0

    # Strategic attributes
    is_essential_service::Bool = false   # required for community health
    is_growing::Bool = false
    market_share::Float64 = 0.0         # estimated share of service area demand
    strategic_priority::Symbol = :maintain  # :grow, :maintain, :evaluate, :exit
    community_benefit_value::Float64 = 0.0
    referral_dependency::Float64 = 0.0  # fraction of volume requiring referral relationships
end

function Base.show(io::IO, sl::ServiceLine)
    ndepts = length(sl.departments)
    print(io, "ServiceLine(\"$(sl.name)\", $(ndepts) depts, priority=:$(sl.strategic_priority))")
end

"""
    service_line_margin(sl::ServiceLine) -> Float64

Compute operating margin for a service line. Returns 0.0 if no revenue.
"""
function service_line_margin(sl::ServiceLine)
    sl.total_net_revenue == 0.0 && return 0.0
    return (sl.total_net_revenue - sl.total_costs) / sl.total_net_revenue
end

"""
    aggregate_service_line!(sl::ServiceLine)

Recompute service line financial totals from underlying departments.
"""
function aggregate_service_line!(sl::ServiceLine)
    sl.total_gross_revenue = sum(d.gross_revenue for d in sl.departments; init=0.0)
    sl.total_net_revenue = sum(d.net_revenue for d in sl.departments; init=0.0)
    sl.total_direct_costs = sum(d.direct_costs for d in sl.departments; init=0.0)
    sl.total_costs = sum(d.total_costs for d in sl.departments; init=0.0)
    sl.contribution_margin = sl.total_net_revenue - sl.total_direct_costs
    sl.operating_margin = service_line_margin(sl)
    sl.annual_volume = sum(d.annual_visits + d.annual_procedures for d in sl.departments; init=0)
    return sl
end
