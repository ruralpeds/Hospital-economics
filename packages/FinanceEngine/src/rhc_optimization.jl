"""
A-12: RHC Service Line Optimization & Profitability Analysis

Analyzes financial performance of individual RHC service lines (visit types)
to identify high-margin opportunities, optimize staffing allocation, and guide
strategic service expansion decisions.
"""

struct RHCServiceLine
    visit_type::String
    cpt_code::String
    avg_rvu::Float64
    conversion_factor::Float64
    avg_payment::Float64
    variable_cost_per_visit::Float64
    monthly_volume::Int
    monthly_fixed_cost::Float64
    physician_fte_per_1000_visits::Float64
end

struct RHCServiceMetrics
    visit_type::String
    annual_visits::Int
    annual_revenue::Float64
    annual_variable_costs::Float64
    annual_fixed_costs::Float64
    annual_contribution_margin::Float64
    contribution_margin_pct::Float64
    breakeven_visits::Int
    roi_pct::Float64
    profit_per_visit::Float64
    physician_fte_required::Float64
end

struct RHCPortfolioOptimization
    total_annual_visits::Int
    total_annual_revenue::Float64
    total_annual_contribution::Float64
    portfolio_margin_pct::Float64
    high_margin_services::Vector{String}
    low_margin_services::Vector{String}
    total_fte_required::Float64
    recommended_action::String
end

"""
    calculate_rhc_service_metrics(service::RHCServiceLine) -> RHCServiceMetrics

Calculate comprehensive financial metrics for a single RHC service line.

Returns profitability metrics including margin %, break-even volume, and FTE requirements.
"""
function calculate_rhc_service_metrics(service::RHCServiceLine)::RHCServiceMetrics
    annual_visits = service.monthly_volume * 12
    annual_revenue = service.avg_payment * annual_visits
    annual_variable_costs = service.variable_cost_per_visit * annual_visits
    annual_fixed_costs = service.monthly_fixed_cost * 12

    contribution_margin = annual_revenue - annual_variable_costs
    contribution_margin_pct = annual_revenue > 0 ? (contribution_margin / annual_revenue) * 100 : 0.0

    # Break-even volume (monthly)
    contrib_per_visit = service.avg_payment - service.variable_cost_per_visit
    monthly_breakeven = contrib_per_visit > 0 ? Int(ceil(service.monthly_fixed_cost / contrib_per_visit)) : 0
    annual_breakeven = monthly_breakeven * 12

    # ROI: annual profit / annual fixed costs
    annual_profit = contribution_margin - annual_fixed_costs
    roi_pct = annual_fixed_costs > 0 ? (annual_profit / annual_fixed_costs) * 100 : 0.0

    # Profit per visit
    profit_per_visit = annual_visits > 0 ? annual_profit / annual_visits : 0.0

    # Physician FTE required
    physician_fte = (annual_visits / 1000.0) * service.physician_fte_per_1000_visits

    RHCServiceMetrics(
        service.visit_type,
        annual_visits,
        annual_revenue,
        annual_variable_costs,
        annual_fixed_costs,
        contribution_margin,
        contribution_margin_pct,
        annual_breakeven,
        roi_pct,
        profit_per_visit,
        physician_fte
    )
end

"""
    optimize_rhc_portfolio(services::Vector{RHCServiceLine}) -> RHCPortfolioOptimization

Analyze RHC service line portfolio to identify strategic optimization opportunities.

Identifies high-margin and low-margin services, calculates total FTE requirements,
and provides strategic recommendations.
"""
function optimize_rhc_portfolio(services::Vector{RHCServiceLine})::RHCPortfolioOptimization
    if isempty(services)
        return RHCPortfolioOptimization(0, 0.0, 0.0, 0.0, String[], String[], 0.0, "No services to analyze")
    end

    metrics = [calculate_rhc_service_metrics(s) for s in services]

    total_visits = sum(m.annual_visits for m in metrics)
    total_revenue = sum(m.annual_revenue for m in metrics)
    total_contribution = sum(m.annual_contribution_margin for m in metrics)
    portfolio_margin_pct = total_revenue > 0 ? (total_contribution / total_revenue) * 100 : 0.0
    total_fte = sum(m.physician_fte_required for m in metrics)

    # Identify high-margin (>35%) and low-margin (<15%) services
    high_margin = [m.visit_type for m in metrics if m.contribution_margin_pct > 35.0]
    low_margin = [m.visit_type for m in metrics if m.contribution_margin_pct < 15.0]

    # Strategic recommendation
    recommendation = if isempty(low_margin)
        "Portfolio is well-balanced. Focus on volume growth."
    elseif isempty(high_margin)
        "All services are low-margin. Consider operational efficiency improvements."
    else
        "Expand high-margin services ($(join(high_margin, ", "))); optimize or reduce low-margin ($(join(low_margin, ", ")))."
    end

    RHCPortfolioOptimization(
        total_visits,
        total_revenue,
        total_contribution,
        portfolio_margin_pct,
        high_margin,
        low_margin,
        total_fte,
        recommendation
    )
end

"""
    compare_service_line_scenarios(services::Vector{RHCServiceLine}, volume_adjustments::Vector{Float64}) -> DataFrame

Compare service line performance across multiple volume scenarios.

Args:
    - services: Vector of RHCServiceLine
    - volume_adjustments: Growth multipliers (1.0 = baseline, 1.5 = 50% growth, etc.)

Returns DataFrame with metrics for each service at each volume level.
"""
function compare_service_line_scenarios(services::Vector{RHCServiceLine}, volume_adjustments::Vector{Float64})::DataFrame
    results = []
    for service in services
        for adj in volume_adjustments
            adjusted_service = RHCServiceLine(
                service.visit_type,
                service.cpt_code,
                service.avg_rvu,
                service.conversion_factor,
                service.avg_payment,
                service.variable_cost_per_visit,
                Int(round(service.monthly_volume * adj)),
                service.monthly_fixed_cost,
                service.physician_fte_per_1000_visits
            )
            metrics = calculate_rhc_service_metrics(adjusted_service)
            push!(results, (
                visit_type = metrics.visit_type,
                volume_multiplier = adj,
                annual_visits = metrics.annual_visits,
                annual_revenue = metrics.annual_revenue,
                annual_profit = metrics.annual_contribution_margin - metrics.annual_fixed_costs,
                contribution_pct = metrics.contribution_margin_pct,
                profit_per_visit = metrics.profit_per_visit
            ))
        end
    end
    DataFrame(results)
end
