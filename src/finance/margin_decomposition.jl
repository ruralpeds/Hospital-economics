# Payer-Level Margin Decomposition — CHQPR Methodology
#
# Decomposes total hospital margin into per-payer contributions, enabling
# identification of which payer classes drive or erode profitability.
# Includes DuPont analysis and waterfall chart data generation.

"""
    PayerMarginComponent

Per-payer contribution to overall hospital margin. Fields: payer_name, payer_type,
revenue, allocated_costs, margin_dollars, margin_pct, volume_share, margin_contribution.
"""
@kwdef struct PayerMarginComponent
    payer_name::String
    payer_type::Symbol
    revenue::Float64
    allocated_costs::Float64
    margin_dollars::Float64
    margin_pct::Float64
    volume_share::Float64
    margin_contribution::Float64
end

function Base.show(io::IO, c::PayerMarginComponent)
    sign_str = c.margin_contribution >= 0 ? "+" : ""
    print(io, "PayerMarginComponent($(c.payer_name): margin=$(round(c.margin_pct * 100, digits=1))%, contribution=$(sign_str)$(round(c.margin_contribution * 100, digits=2))%)")
end

"""
    MarginDecomposition

Complete decomposition of hospital margin into payer-level components,
including non-patient revenue sources (grants, 340B, investments).
"""
@kwdef struct MarginDecomposition
    components::Vector{PayerMarginComponent}
    total_revenue::Float64
    total_costs::Float64
    total_margin_pct::Float64
    non_patient_revenue::Float64 = 0.0
    non_patient_contribution::Float64 = 0.0
end

function Base.show(io::IO, d::MarginDecomposition)
    n = length(d.components)
    print(io, "MarginDecomposition($(n) payers, margin=$(round(d.total_margin_pct * 100, digits=1))%)")
end

"""
    decompose_margin(payer_data::Vector{NamedTuple}, total_expenses::Float64;
                     non_patient_revenue::Float64=0.0) -> MarginDecomposition

Decompose total margin into per-payer contributions using the CHQPR methodology.

Each element of `payer_data` must be a NamedTuple with fields:
- `:payer_name` (String)
- `:payer_type` (Symbol)
- `:revenue` (Float64) — net patient revenue from this payer
- `:volume_share` (Float64) — fraction of total volume (should sum to ~1.0)

Costs are allocated to each payer proportionally by `volume_share`. The margin
contribution for each payer equals its margin dollars divided by `total_expenses`,
so the sum of all contributions plus the non-patient contribution equals the
overall margin percentage.
"""
function decompose_margin(payer_data::Vector{<:NamedTuple}, total_expenses::Float64;
                          non_patient_revenue::Float64=0.0)::MarginDecomposition
    total_expenses <= 0.0 && error("total_expenses must be positive")
    !isempty(payer_data) || error("payer_data must not be empty")
    non_patient_revenue >= 0.0 || error("non_patient_revenue must be non-negative; got $non_patient_revenue")
    for pd in payer_data
        pd.revenue >= 0.0 || error("revenue must be non-negative for payer $(pd.payer_name); got $(pd.revenue)")
        0.0 <= pd.volume_share <= 1.0 || error("volume_share must be between 0 and 1 for payer $(pd.payer_name); got $(pd.volume_share)")
    end

    components = PayerMarginComponent[]
    total_patient_revenue = 0.0

    for pd in payer_data
        allocated_costs = total_expenses * pd.volume_share
        margin_dollars = pd.revenue - allocated_costs
        margin_pct = pd.revenue != 0.0 ? margin_dollars / pd.revenue : 0.0
        margin_contribution = margin_dollars / total_expenses

        push!(components, PayerMarginComponent(
            payer_name = pd.payer_name,
            payer_type = pd.payer_type,
            revenue = pd.revenue,
            allocated_costs = allocated_costs,
            margin_dollars = margin_dollars,
            margin_pct = margin_pct,
            volume_share = pd.volume_share,
            margin_contribution = margin_contribution,
        ))

        total_patient_revenue += pd.revenue
    end

    total_revenue = total_patient_revenue + non_patient_revenue
    np_contribution = non_patient_revenue / total_expenses
    total_margin_pct = total_revenue != 0.0 ? (total_revenue - total_expenses) / total_revenue : 0.0

    return MarginDecomposition(
        components = components,
        total_revenue = total_revenue,
        total_costs = total_expenses,
        total_margin_pct = total_margin_pct,
        non_patient_revenue = non_patient_revenue,
        non_patient_contribution = np_contribution,
    )
end

"""
    dupont_analysis(total_revenue::Float64, total_expenses::Float64,
                    total_assets::Float64, net_assets::Float64) -> NamedTuple

Perform a DuPont decomposition of return on equity (ROE) for a hospital.

Returns a NamedTuple with:
- `profit_margin`: net income / total revenue
- `asset_turnover`: total revenue / total assets
- `equity_multiplier`: total assets / net assets
- `roe`: product of the three components (return on equity)

For non-profit hospitals, net assets (equity) replaces shareholder equity.
"""
function dupont_analysis(total_revenue::Float64, total_expenses::Float64,
                         total_assets::Float64, net_assets::Float64)
    total_revenue <= 0.0 && error("total_revenue must be positive for DuPont analysis")
    total_assets <= 0.0 && error("total_assets must be positive for DuPont analysis")
    net_assets <= 0.0 && error("net_assets must be positive for DuPont analysis")

    net_income = total_revenue - total_expenses
    profit_margin = net_income / total_revenue
    asset_turnover = total_revenue / total_assets
    equity_multiplier = total_assets / net_assets
    roe = profit_margin * asset_turnover * equity_multiplier

    return (
        profit_margin = profit_margin,
        asset_turnover = asset_turnover,
        equity_multiplier = equity_multiplier,
        roe = roe,
    )
end

"""
    margin_waterfall(decomp::MarginDecomposition) -> Vector{NamedTuple}

Generate an ordered list of waterfall chart segments from a margin decomposition.

Each element is a NamedTuple with:
- `:label` (String) — segment label
- `:value` (Float64) — this segment's margin contribution (fraction of expenses)
- `:cumulative` (Float64) — running total after this segment

The waterfall starts from the most-positive payer contribution, proceeds through
less-positive and then negative contributions, and ends with the non-patient
revenue contribution and a total bar.
"""
function margin_waterfall(decomp::MarginDecomposition)::Vector{NamedTuple}
    # Sort components: positive contributions first (descending), then negative (descending)
    sorted = sort(decomp.components, by=c -> -c.margin_contribution)

    waterfall = NamedTuple[]
    cumulative = 0.0

    for comp in sorted
        cumulative += comp.margin_contribution
        push!(waterfall, (
            label = comp.payer_name,
            value = comp.margin_contribution,
            cumulative = cumulative,
        ))
    end

    # Non-patient revenue contribution
    if decomp.non_patient_revenue > 0.0
        cumulative += decomp.non_patient_contribution
        push!(waterfall, (
            label = "Non-Patient Revenue",
            value = decomp.non_patient_contribution,
            cumulative = cumulative,
        ))
    end

    # Total bar
    push!(waterfall, (
        label = "Total Margin",
        value = decomp.total_margin_pct,
        cumulative = cumulative,
    ))

    return waterfall
end
