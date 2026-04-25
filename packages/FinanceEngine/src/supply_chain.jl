# ── Supply chain economics ─────────────────────────────────────────────────
#
# Economic Order Quantity (EOQ), safety stock, pharmaceutical cost tracking,
# and inventory optimization for hospital supply chains.

"""
    economic_order_quantity(annual_demand::Float64, order_cost::Float64,
                           holding_cost_per_unit::Float64) -> NamedTuple

Classic EOQ (Harris-Wilson) model for inventory management.

# Returns
`(eoq, orders_per_year, total_annual_cost, reorder_interval_days)`
"""
function economic_order_quantity(annual_demand::Float64, order_cost::Float64,
                                holding_cost_per_unit::Float64)
    annual_demand > 0 || throw(DomainValidationError("annual_demand",
        string(annual_demand), "> 0", "Annual demand must be positive"))
    order_cost > 0 || throw(DomainValidationError("order_cost",
        string(order_cost), "> 0", "Order cost must be positive"))
    holding_cost_per_unit > 0 || throw(DomainValidationError("holding_cost",
        string(holding_cost_per_unit), "> 0", "Holding cost must be positive"))

    eoq = sqrt(2 * annual_demand * order_cost / holding_cost_per_unit)
    orders_per_year = annual_demand / eoq
    total_cost = orders_per_year * order_cost + (eoq / 2) * holding_cost_per_unit
    reorder_interval = 365.0 / orders_per_year

    return (eoq=eoq, orders_per_year=orders_per_year,
            total_annual_cost=total_cost, reorder_interval_days=reorder_interval)
end

"""
    safety_stock(avg_daily_demand::Float64, demand_std::Float64,
                 lead_time_days::Float64, lead_time_std::Float64;
                 service_level::Float64=0.95) -> NamedTuple

Compute safety stock using the combined demand and lead-time variability formula.

Safety Stock = z × √(LT × σ_d² + d̄² × σ_LT²)
"""
function safety_stock(avg_daily_demand::Float64, demand_std::Float64,
                      lead_time_days::Float64, lead_time_std::Float64;
                      service_level::Float64=0.95)
    0 < service_level < 1 || throw(DomainValidationError("service_level",
        string(service_level), "(0, 1)", "Service level must be between 0 and 1"))

    z = _z_for_service_level(service_level)
    ss = z * sqrt(lead_time_days * demand_std^2 + avg_daily_demand^2 * lead_time_std^2)
    reorder_point = avg_daily_demand * lead_time_days + ss

    return (safety_stock=ss, reorder_point=reorder_point, z_score=z,
            service_level=service_level)
end

"""
    inventory_turnover(cogs::Float64, avg_inventory::Float64) -> NamedTuple

Compute inventory turnover ratio and days inventory outstanding.
"""
function inventory_turnover(cogs::Float64, avg_inventory::Float64)
    avg_inventory > 0 || throw(DomainValidationError("avg_inventory",
        string(avg_inventory), "> 0", "Average inventory must be positive"))
    turnover = cogs / avg_inventory
    days_outstanding = 365.0 / turnover
    return (turnover_ratio=turnover, days_outstanding=days_outstanding)
end

"""
    pharmaceutical_cost_analysis(drugs::Vector{NamedTuple}) -> DataFrame

Analyse pharmaceutical spending patterns.

Each drug: `(name, unit_cost, monthly_volume, therapeutic_class, generic_available)`.
Returns DataFrame with cost metrics, ABC classification, and generic savings opportunity.
"""
function pharmaceutical_cost_analysis(drugs::Vector)::DataFrame
    rows = NamedTuple[]
    total_spend = sum(d.unit_cost * d.monthly_volume * 12 for d in drugs)

    for d in drugs
        annual_cost = d.unit_cost * d.monthly_volume * 12
        pct_of_total = total_spend > 0 ? annual_cost / total_spend : 0.0
        generic_savings = d.generic_available ? annual_cost * 0.40 : 0.0  # ~40% savings typical

        push!(rows, (
            drug=d.name,
            unit_cost=d.unit_cost,
            monthly_volume=d.monthly_volume,
            annual_cost=annual_cost,
            pct_of_total=pct_of_total,
            therapeutic_class=d.therapeutic_class,
            generic_available=d.generic_available,
            generic_savings_opportunity=generic_savings,
        ))
    end
    df = DataFrame(rows)
    sort!(df, :annual_cost; rev=true)

    # ABC classification (Pareto)
    cumulative_pct = cumsum(df.pct_of_total)
    df[!, :abc_class] = map(cumulative_pct) do cp
        cp <= 0.80 ? "A" : cp <= 0.95 ? "B" : "C"
    end

    return df
end

"""
    stockout_cost(lost_revenue_per_day::Float64, days_out::Float64;
                  patient_diversion_cost::Float64=0.0,
                  reputation_factor::Float64=1.0) -> Float64

Estimate the total cost of a supply stockout.
"""
function stockout_cost(lost_revenue_per_day::Float64, days_out::Float64;
                       patient_diversion_cost::Float64=0.0,
                       reputation_factor::Float64=1.0)::Float64
    direct = lost_revenue_per_day * days_out
    diversion = patient_diversion_cost * days_out
    return (direct + diversion) * reputation_factor
end

"""
    vendor_scorecard(vendors::Vector{NamedTuple}) -> DataFrame

Score supply chain vendors on quality, cost, delivery, and service.

Each vendor: `(name, quality_score, cost_score, delivery_score, service_score)`.
Scores are 0-100. Returns ranked DataFrame with weighted composite.
"""
function vendor_scorecard(vendors::Vector;
                          weights::NamedTuple=(quality=0.30, cost=0.30,
                                               delivery=0.25, service=0.15))::DataFrame
    rows = NamedTuple[]
    for v in vendors
        composite = v.quality_score * weights.quality +
                    v.cost_score * weights.cost +
                    v.delivery_score * weights.delivery +
                    v.service_score * weights.service
        push!(rows, (vendor=v.name, quality=v.quality_score, cost=v.cost_score,
                     delivery=v.delivery_score, service=v.service_score,
                     composite_score=composite))
    end
    df = DataFrame(rows)
    sort!(df, :composite_score; rev=true)
    df[!, :rank] = 1:nrow(df)
    return df
end

# ── Helper ────────────────────────────────────────────────────────────────

"""Z-score for a given service level (normal distribution)."""
function _z_for_service_level(sl::Float64)::Float64
    # Common service levels
    sl >= 0.99 && return 2.326
    sl >= 0.975 && return 1.960
    sl >= 0.95 && return 1.645
    sl >= 0.90 && return 1.282
    sl >= 0.85 && return 1.036
    sl >= 0.80 && return 0.842
    return 0.674  # 75%
end
