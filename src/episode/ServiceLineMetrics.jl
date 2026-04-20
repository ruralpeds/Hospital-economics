# episode/ServiceLineMetrics.jl — Advanced service line metrics and analysis

using Statistics

"""
    calculate_margin(service_line::ServiceLine)::Float64

Calculate gross margin (revenue - direct cost) for a service line.
"""
function calculate_margin(sl::ServiceLine)::Float64
    return sl.revenue - sl.direct_cost
end

"""
    calculate_contribution_margin(service_line::ServiceLine)::Float64

Calculate contribution margin percentage.
Contribution margin = (Revenue - Direct Cost) / Revenue * 100
"""
function calculate_contribution_margin(sl::ServiceLine)::Float64
    if sl.revenue <= 0
        return 0.0
    end
    return (sl.revenue - sl.direct_cost) / sl.revenue * 100
end

"""
    calculate_profitability_index(service_line::ServiceLine)::Float64

Calculate profitability index (ratio of profit to revenue).
Higher values indicate better profitability.
"""
function calculate_profitability_index(sl::ServiceLine)::Float64
    if sl.revenue <= 0
        return 0.0
    end
    profit = sl.revenue - sl.direct_cost - sl.allocated_indirect_cost
    return profit / sl.revenue
end

"""
    efficiency_metrics(service_lines::Vector{ServiceLine})::Dict{String, Float64}

Calculate efficiency metrics across service lines.

Returns a dictionary with:
- `avg_revenue_per_case` — Average revenue per episode
- `avg_direct_cost_per_case` — Average direct cost per episode
- `avg_volume` — Average volume across service lines
- `cost_to_revenue_ratio` — Average proportion of costs to revenue
- `revenue_concentration` — Herfindahl index (concentration of revenue)
"""
function efficiency_metrics(service_lines::Vector{ServiceLine})::Dict{String, Float64}

    total_cases = sum(sl.volume for sl in service_lines)
    total_revenue = sum(sl.revenue for sl in service_lines)
    total_cost = sum(sl.direct_cost for sl in service_lines)

    metrics = Dict{String, Float64}()

    metrics["avg_revenue_per_case"] = total_cases > 0 ? total_revenue / total_cases : 0.0
    metrics["avg_direct_cost_per_case"] = total_cases > 0 ? total_cost / total_cases : 0.0
    metrics["avg_volume"] = length(service_lines) > 0 ? total_cases / length(service_lines) : 0.0
    metrics["cost_to_revenue_ratio"] = total_revenue > 0 ? total_cost / total_revenue : 0.0

    # Revenue concentration (Herfindahl index)
    hhi = 0.0
    if total_revenue > 0
        for sl in service_lines
            pct = (sl.revenue / total_revenue)^2
            hhi += pct
        end
    end
    metrics["revenue_concentration"] = hhi

    return metrics
end

"""
    rank_service_lines_by_metric(
        service_lines::Vector{ServiceLine},
        metric::Symbol
    )::Vector{Tuple{String, Float64}}

Rank service lines by a specified metric.

Supported metrics:
- `:margin` — Gross margin (revenue - direct cost)
- `:margin_pct` — Margin percentage
- `:volume` — Case volume
- `:revenue` — Total revenue
- `:cost` — Total direct cost
- `:revenue_per_case` — Revenue per episode
"""
function rank_service_lines_by_metric(
    service_lines::Vector{ServiceLine},
    metric::Symbol
)::Vector{Tuple{String, Float64}}

    rankings = if metric == :margin
        [(sl.id, calculate_margin(sl)) for sl in service_lines]
    elseif metric == :margin_pct
        [(sl.id, calculate_contribution_margin(sl)) for sl in service_lines]
    elseif metric == :volume
        [(sl.id, Float64(sl.volume)) for sl in service_lines]
    elseif metric == :revenue
        [(sl.id, sl.revenue) for sl in service_lines]
    elseif metric == :cost
        [(sl.id, sl.direct_cost) for sl in service_lines]
    elseif metric == :revenue_per_case
        [(sl.id, sl.volume > 0 ? sl.revenue / sl.volume : 0.0) for sl in service_lines]
    else
        error("Unknown metric: $metric")
    end

    # Sort in descending order
    return sort(rankings, by=x -> x[2], rev=true)
end

"""
    case_mix_analysis(service_lines::Vector{ServiceLine})::Dict{String, Any}

Analyze case mix (distribution of service volumes and complexity).

Returns metrics on:
- Distribution of cases across service lines
- Coefficient of variation (volatility)
- Concentration metrics
"""
function case_mix_analysis(service_lines::Vector{ServiceLine})::Dict{String, Any}

    if isempty(service_lines)
        return Dict()
    end

    volumes = [Float64(sl.volume) for sl in service_lines]
    total_volume = sum(volumes)

    analysis = Dict{String, Any}()
    analysis["total_volume"] = total_volume
    analysis["n_service_lines"] = length(service_lines)
    analysis["avg_volume_per_line"] = total_volume / length(service_lines)
    analysis["max_volume"] = maximum(volumes)
    analysis["min_volume"] = minimum(volumes)
    analysis["median_volume"] = median(volumes)

    # Coefficient of variation (measure of relative variability)
    if length(volumes) > 1
        cv = std(volumes) / mean(volumes)
        analysis["coefficient_of_variation"] = cv
    end

    # Concentration: percentage of volume in top service lines
    sorted_volumes = sort(volumes, rev=true)
    analysis["top_3_volume_pct"] = min(3, length(sorted_volumes)) > 0 ?
        sum(sorted_volumes[1:min(3, length(sorted_volumes))]) / total_volume * 100 : 0.0

    return analysis
end

"""
    sensitivity_analysis(
        service_line::ServiceLine,
        revenue_change::Float64,
        cost_change::Float64
    )::Dict{String, Float64}

Perform sensitivity analysis on a service line.
Shows impact of revenue and cost changes on profitability.

# Arguments
- `revenue_change` — Percentage change in revenue (e.g., -0.05 for -5%)
- `cost_change` — Percentage change in direct cost (e.g., 0.10 for +10%)
"""
function sensitivity_analysis(
    sl::ServiceLine,
    revenue_change::Float64,
    cost_change::Float64
)::Dict{String, Float64}

    new_revenue = sl.revenue * (1 + revenue_change)
    new_cost = sl.direct_cost * (1 + cost_change)
    original_margin = sl.revenue - sl.direct_cost

    new_margin = new_revenue - new_cost
    margin_change = new_margin - original_margin
    margin_change_pct = original_margin > 0 ? (margin_change / original_margin * 100) : 0.0

    return Dict(
        "original_margin" => original_margin,
        "new_margin" => new_margin,
        "margin_change" => margin_change,
        "margin_change_pct" => margin_change_pct,
        "breakeven_volume" => new_cost > 0 ? new_cost / (new_revenue / sl.volume) : 0.0
    )
end

"""
    profitability_summary(service_lines::Vector{ServiceLine})::Dict{String, Any}

Generate comprehensive profitability summary.
"""
function profitability_summary(service_lines::Vector{ServiceLine})::Dict{String, Any}

    if isempty(service_lines)
        return Dict()
    end

    margins = [calculate_margin(sl) for sl in service_lines]
    margin_pcts = [calculate_contribution_margin(sl) for sl in service_lines]

    summary = Dict{String, Any}()
    summary["total_margin"] = sum(margins)
    summary["avg_margin"] = mean(margins)
    summary["avg_margin_pct"] = mean(margin_pcts)
    summary["max_margin"] = maximum(margins)
    summary["min_margin"] = minimum(margins)
    summary["profitable_count"] = sum(m > 0 for m in margins)
    summary["unprofitable_count"] = sum(m <= 0 for m in margins)
    summary["profitability_ratio"] = sum(m > 0 for m in margins) / length(service_lines)

    return summary
end
