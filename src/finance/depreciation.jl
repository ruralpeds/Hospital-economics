# Asset depreciation schedules for Rural Hospital Economics Simulator
#
# Provides depreciation calculation methods and multi-year schedule generation
# for capital asset planning and replacement analysis.

using Dates

"""
    straight_line_depreciation(cost::Float64, salvage::Float64, useful_life::Int) -> Float64

Compute the annual depreciation expense under the straight-line method.
Returns `(cost - salvage) / useful_life`.
"""
function straight_line_depreciation(cost::Float64, salvage::Float64, useful_life::Int)::Float64
    useful_life <= 0 && error("Useful life must be positive; got $useful_life")
    return (cost - salvage) / useful_life
end

"""
    declining_balance_depreciation(book_value::Float64, useful_life::Int;
                                   factor::Float64=2.0) -> Float64

Compute one year of depreciation expense under the declining-balance method.
The default `factor=2.0` gives double-declining balance (DDB). The annual
expense is `book_value * (factor / useful_life)`.
"""
function declining_balance_depreciation(book_value::Float64, useful_life::Int;
                                         factor::Float64=2.0)::Float64
    useful_life <= 0 && error("Useful life must be positive; got $useful_life")
    rate = factor / useful_life
    return book_value * rate
end

"""
    depreciation_schedule(asset::CapitalAsset, years::Int) -> Vector{NamedTuple}

Generate a multi-year depreciation schedule for a single capital asset.
Returns a vector of named tuples with fields:
- `year`: schedule year (1-indexed)
- `expense`: depreciation expense for that year
- `accumulated`: total accumulated depreciation through that year
- `book_value`: remaining book value at end of year

Supports `:straight_line` and `:declining_balance` methods as specified on the asset.
For declining balance, switches to straight-line when it produces a larger deduction
(standard tax/accounting practice).
"""
function depreciation_schedule(asset::CapitalAsset, years::Int)::Vector{NamedTuple{(:year, :expense, :accumulated, :book_value), Tuple{Int, Float64, Float64, Float64}}}
    years <= 0 && error("Schedule years must be positive; got $years")

    schedule = NamedTuple{(:year, :expense, :accumulated, :book_value), Tuple{Int, Float64, Float64, Float64}}[]
    accumulated = asset.accumulated_depreciation
    book_val = asset.acquisition_cost - accumulated
    depreciable_base = asset.acquisition_cost - asset.salvage_value

    for yr in 1:years
        if book_val <= asset.salvage_value
            expense = 0.0
        elseif asset.depreciation_method == :straight_line
            expense = straight_line_depreciation(asset.acquisition_cost, asset.salvage_value,
                                                  asset.useful_life_years)
            expense = min(expense, book_val - asset.salvage_value)
        elseif asset.depreciation_method == :declining_balance
            ddb_expense = declining_balance_depreciation(book_val, asset.useful_life_years)
            # Remaining life for SL switchover
            remaining_life = asset.useful_life_years - yr + 1
            sl_expense = remaining_life > 0 ? (book_val - asset.salvage_value) / remaining_life : 0.0
            expense = max(ddb_expense, sl_expense)
            expense = min(expense, book_val - asset.salvage_value)
        else
            # Default to straight-line
            expense = straight_line_depreciation(asset.acquisition_cost, asset.salvage_value,
                                                  asset.useful_life_years)
            expense = min(expense, book_val - asset.salvage_value)
        end

        expense = max(expense, 0.0)
        accumulated += expense
        book_val -= expense

        push!(schedule, (year=yr, expense=expense, accumulated=accumulated, book_value=book_val))
    end

    return schedule
end

"""
    total_annual_depreciation(assets::Vector{CapitalAsset}) -> Float64

Sum the current-year depreciation expense across all active capital assets.
Only active assets (`is_active == true`) are included.
"""
function total_annual_depreciation(assets::Vector{CapitalAsset})::Float64
    total = 0.0
    for asset in assets
        asset.is_active || continue
        total += annual_depreciation(asset)
    end
    return total
end

"""
    replacement_needs(assets::Vector{CapitalAsset}, max_age_years::Int) -> Vector{CapitalAsset}

Identify active assets that exceed the specified maximum age threshold
and should be considered for replacement. Age is estimated from the ratio
of accumulated depreciation to annual depreciation expense.
"""
function replacement_needs(assets::Vector{CapitalAsset}, max_age_years::Int)::Vector{CapitalAsset}
    needs = CapitalAsset[]
    for asset in assets
        asset.is_active || continue
        annual_dep = annual_depreciation(asset)
        if annual_dep > 0.0
            estimated_age = asset.accumulated_depreciation / annual_dep
            if estimated_age >= max_age_years
                push!(needs, asset)
            end
        end
    end
    return needs
end
