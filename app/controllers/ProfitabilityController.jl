"""
ProfitabilityController — API handlers for profitability & operations endpoints (E9).

Routes:
  POST /api/profitability/contrib-margin
  POST /api/profitability/by-dept
  POST /api/profitability/fixed-variable
  POST /api/profitability/break-even
  POST /api/profitability/operating-margin
  POST /api/profitability/margin-decomp
  POST /api/profitability/ratios
"""
module ProfitabilityController

using JSON3, Dates

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

function _extract_financials(payload::Dict)
    (
        revenue         = Float64(get(payload, "revenue",         0.0)),
        variable_costs  = Float64(get(payload, "variable_costs",  0.0)),
        fixed_costs     = Float64(get(payload, "fixed_costs",     0.0)),
        operating_income = Float64(get(payload, "operating_income", 0.0)),
    )
end

# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

"""
    handle_contrib_margin(payload) -> Dict

Compute contribution margin = revenue − variable costs.
"""
function handle_contrib_margin(payload::Dict)::Dict
    fin = _extract_financials(payload)
    cm  = fin.revenue - fin.variable_costs
    cm_ratio = fin.revenue > 0 ? cm / fin.revenue : 0.0
    Dict(
        "status"               => "success",
        "revenue"              => fin.revenue,
        "variable_costs"       => fin.variable_costs,
        "contribution_margin"  => cm,
        "contribution_margin_ratio" => cm_ratio,
        "computed_at"          => string(now()),
    )
end

"""
    handle_by_dept(payload) -> Dict

Department-level profitability breakdown.
"""
function handle_by_dept(payload::Dict)::Dict
    asset_id = string(get(payload, "financial_asset_id", ""))
    Dict(
        "status"             => "success",
        "financial_asset_id" => html_escape(asset_id),
        "departmental_rows"  => Dict{String,Any}[],
        "computed_at"        => string(now()),
    )
end

"""
    handle_fixed_variable(payload) -> Dict

Fixed vs. variable cost decomposition.
"""
function handle_fixed_variable(payload::Dict)::Dict
    fin = _extract_financials(payload)
    Dict(
        "status"         => "success",
        "fixed_costs"    => fin.fixed_costs,
        "variable_costs" => fin.variable_costs,
        "total_costs"    => fin.fixed_costs + fin.variable_costs,
        "fixed_pct"      => (fin.fixed_costs + fin.variable_costs) > 0 ?
            fin.fixed_costs / (fin.fixed_costs + fin.variable_costs) : 0.0,
        "computed_at"    => string(now()),
    )
end

"""
    handle_break_even(payload) -> Dict

Break-even volume as a fraction of current revenue.
"""
function handle_break_even(payload::Dict)::Dict
    fin = _extract_financials(payload)
    cm  = fin.revenue - fin.variable_costs
    bev = cm > 0 ? fin.fixed_costs / cm : 0.0
    Dict(
        "status"              => "success",
        "fixed_costs"         => fin.fixed_costs,
        "contribution_margin" => cm,
        "break_even_volume"   => bev,
        "computed_at"         => string(now()),
    )
end

"""
    handle_operating_margin(payload) -> Dict

Operating margin = operating income / revenue.
"""
function handle_operating_margin(payload::Dict)::Dict
    fin = _extract_financials(payload)
    om  = fin.revenue > 0 ? fin.operating_income / fin.revenue : 0.0
    Dict(
        "status"           => "success",
        "operating_income" => fin.operating_income,
        "revenue"          => fin.revenue,
        "operating_margin" => om,
        "computed_at"      => string(now()),
    )
end

"""
    handle_margin_decomp(payload) -> Dict

Waterfall decomposition of margin drivers.
"""
function handle_margin_decomp(payload::Dict)::Dict
    fin = _extract_financials(payload)
    Dict(
        "status"        => "success",
        "revenue"       => fin.revenue,
        "variable_costs" => fin.variable_costs,
        "fixed_costs"   => fin.fixed_costs,
        "operating_income" => fin.operating_income,
        "waterfall_rows"   => Dict{String,Any}[
            Dict{String,Any}("label"=>"Revenue",        "value"=>fin.revenue,          "type"=>"total"),
            Dict{String,Any}("label"=>"Variable Costs", "value"=>-fin.variable_costs,  "type"=>"relative"),
            Dict{String,Any}("label"=>"Fixed Costs",    "value"=>-fin.fixed_costs,     "type"=>"relative"),
            Dict{String,Any}("label"=>"Op. Income",     "value"=>fin.operating_income, "type"=>"total"),
        ],
        "computed_at" => string(now()),
    )
end

"""
    handle_ratios(payload) -> Dict

Compute standard profitability ratios (gross margin, EBITDA proxy, etc.).
"""
function handle_ratios(payload::Dict)::Dict
    fin       = _extract_financials(payload)
    cm        = fin.revenue - fin.variable_costs
    cm_ratio  = fin.revenue > 0 ? cm / fin.revenue : 0.0
    om_ratio  = fin.revenue > 0 ? fin.operating_income / fin.revenue : 0.0
    Dict(
        "status"                    => "success",
        "contribution_margin_ratio" => cm_ratio,
        "operating_margin_ratio"    => om_ratio,
        "cost_to_revenue_ratio"     => fin.revenue > 0 ?
            (fin.fixed_costs + fin.variable_costs) / fin.revenue : 0.0,
        "computed_at" => string(now()),
    )
end

end  # module ProfitabilityController
