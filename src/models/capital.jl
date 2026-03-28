# Capital asset types for Rural Hospital Economics Simulator
# Extracted from financial.jl

using Dates

"""
    CapitalAsset

An individual capital asset with depreciation tracking.
"""
@kwdef mutable struct CapitalAsset
    asset_id::String
    description::String
    category::Symbol  # :building, :equipment, :land, :it_system, :vehicle
    acquisition_date::Date
    acquisition_cost::Float64
    useful_life_years::Int
    salvage_value::Float64 = 0.0
    depreciation_method::Symbol = :straight_line  # :straight_line, :declining_balance
    accumulated_depreciation::Float64 = 0.0
    is_active::Bool = true
    funding_source::Symbol = :operating  # :operating, :bond, :grant, :usda_loan, :lease
end

"""
    current_book_value(asset::CapitalAsset) -> Float64

Compute the current book value of a capital asset.
"""
function current_book_value(asset::CapitalAsset)
    return asset.acquisition_cost - asset.accumulated_depreciation
end

"""
    annual_depreciation(asset::CapitalAsset) -> Float64

Compute the annual straight-line depreciation expense for a capital asset.
Falls back to straight-line for unsupported methods.
"""
function annual_depreciation(asset::CapitalAsset)
    if asset.depreciation_method == :straight_line
        return (asset.acquisition_cost - asset.salvage_value) / asset.useful_life_years
    elseif asset.depreciation_method == :declining_balance
        book = current_book_value(asset)
        rate = 2.0 / asset.useful_life_years
        return max(book * rate, 0.0)
    else
        # Default to straight-line
        return (asset.acquisition_cost - asset.salvage_value) / asset.useful_life_years
    end
end

"""
    CapitalProject

A planned or in-progress capital project.
"""
@kwdef mutable struct CapitalProject
    project_id::String
    name::String
    description::String = ""
    category::Symbol  # :facility, :equipment, :it, :renovation, :expansion
    estimated_cost::Float64
    approved_budget::Float64 = 0.0
    spent_to_date::Float64 = 0.0
    start_date::Union{Date, Nothing} = nothing
    expected_completion::Union{Date, Nothing} = nothing
    status::Symbol = :proposed  # :proposed, :approved, :in_progress, :completed, :deferred
    funding_sources::Dict{Symbol, Float64} = Dict{Symbol, Float64}()
    expected_useful_life_years::Int = 10
    priority_rank::Int = 0
end

"""
    CapitalPlan

Multi-year capital expenditure plan for a hospital.
"""
@kwdef mutable struct CapitalPlan
    plan_year_start::Int
    plan_year_end::Int
    existing_assets::Vector{CapitalAsset} = CapitalAsset[]
    planned_projects::Vector{CapitalProject} = CapitalProject[]
    annual_depreciation_budget::Float64 = 0.0
    annual_capex_budget::Float64 = 0.0
    deferred_maintenance_backlog::Float64 = 0.0
    average_age_of_plant_years::Float64 = 0.0
    target_age_of_plant_years::Float64 = 10.0
end
