# Staffing types for Rural Hospital Economics Simulator

"""
    StaffPosition

An individual staff position within a hospital.
"""
@kwdef mutable struct StaffPosition
    title::String
    category::Symbol  # :physician, :nursing, :allied_health, :admin, :support, :executive
    department::String = ""
    fte::Float64 = 1.0
    is_permanent::Bool = true
    annual_salary::Float64 = 0.0
    benefits_pct::Float64 = 0.30  # as fraction of salary
    annual_bonus::Float64 = 0.0
    sign_on_bonus::Float64 = 0.0
    expected_tenure_years::Float64 = 3.0
    recruitment_cost::Float64 = 0.0
    is_travel_locum::Bool = false
    travel_premium_pct::Float64 = 0.0  # premium above base rate for travel/locum staff
    rvus_per_year::Float64 = 0.0  # Relative Value Units generated
end

function Base.show(io::IO, p::StaffPosition)
    label = p.is_travel_locum ? " [travel]" : ""
    print(io, "StaffPosition(\"$(p.title)\", $(p.fte) FTE, \$$(round(Int, p.annual_salary))$(label))")
end

"""
    StaffingModel

Aggregate staffing model for a hospital, containing all positions
and workforce metrics.
"""
@kwdef mutable struct StaffingModel
    positions::Vector{StaffPosition} = StaffPosition[]
    vacancy_rate::Float64 = 0.10
    turnover_rate_annual::Float64 = 0.20
    avg_time_to_fill_days::Float64 = 60.0
    travel_staff_dependency_pct::Float64 = 0.0  # fraction of FTEs filled by travel/locum
end

function Base.show(io::IO, sm::StaffingModel)
    n = length(sm.positions)
    fte = total_fte(sm)
    print(io, "StaffingModel($(n) positions, $(round(fte, digits=1)) FTE, vacancy=$(round(sm.vacancy_rate * 100, digits=1))%)")
end

# --- Computed property functions ---

"""
    total_fte(model::StaffingModel) -> Float64

Total full-time equivalents across all positions.
"""
function total_fte(model::StaffingModel)
    return sum(p.fte for p in model.positions; init=0.0)
end

"""
    total_salary_expense(model::StaffingModel) -> Float64

Total annual salary expense across all positions.
"""
function total_salary_expense(model::StaffingModel)
    return sum(p.annual_salary * p.fte for p in model.positions; init=0.0)
end

"""
    total_compensation(model::StaffingModel) -> Float64

Total annual compensation including salaries, benefits, and bonuses.
"""
function total_compensation(model::StaffingModel)
    return sum(
        p.fte * (p.annual_salary * (1.0 + p.benefits_pct) + p.annual_bonus)
        for p in model.positions;
        init=0.0
    )
end

"""
    permanent_fte(model::StaffingModel) -> Float64

Total FTEs filled by permanent (non-travel/locum) staff.
"""
function permanent_fte(model::StaffingModel)
    return sum(p.fte for p in model.positions if p.is_permanent && !p.is_travel_locum; init=0.0)
end

"""
    travel_fte(model::StaffingModel) -> Float64

Total FTEs filled by travel or locum tenens staff.
"""
function travel_fte(model::StaffingModel)
    return sum(p.fte for p in model.positions if p.is_travel_locum; init=0.0)
end

"""
    travel_premium_cost(model::StaffingModel) -> Float64

Additional cost incurred due to travel/locum staff premium rates
above what a permanent employee would cost.
"""
function travel_premium_cost(model::StaffingModel)
    return sum(
        p.fte * p.annual_salary * p.travel_premium_pct
        for p in model.positions if p.is_travel_locum;
        init=0.0
    )
end
