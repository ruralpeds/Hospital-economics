# Telehealth Economics & ROI for Rural Hospital Economics Simulator
#
# Models the financial return on telehealth service investments including
# direct revenue, avoided transfer savings, and multi-year ROI projections
# relevant to rural and critical access hospitals.

"""
    TelehealthService

A single telehealth service line with volume, revenue, and cost data.

# Fields
- `service_type::Symbol`: type of telehealth service
- `annual_volume::Int`: projected annual encounter volume
- `revenue_per_encounter::Float64`: average reimbursement per encounter
- `cost_per_encounter::Float64`: variable cost per encounter
- `avoided_transfers_per_year::Int`: transfers prevented by this service
- `avg_transfer_cost_avoided::Float64`: average cost of an avoided transfer
"""
@kwdef struct TelehealthService
    service_type::Symbol
    annual_volume::Int
    revenue_per_encounter::Float64
    cost_per_encounter::Float64
    avoided_transfers_per_year::Int = 0
    avg_transfer_cost_avoided::Float64 = 0.0
end

"""
    TelehealthInvestment

Capital and operating costs for a telehealth program.

# Fields
- `infrastructure_cost::Float64`: one-time equipment and setup (default 50,000)
- `annual_licensing::Float64`: annual software/platform licensing (default 24,000)
- `annual_staffing::Float64`: annual dedicated telehealth staffing (default 80,000)
- `broadband_upgrade::Float64`: one-time broadband infrastructure cost
- `training_cost::Float64`: one-time training and change management (default 5,000)
"""
@kwdef struct TelehealthInvestment
    infrastructure_cost::Float64 = 50_000.0
    annual_licensing::Float64 = 24_000.0
    annual_staffing::Float64 = 80_000.0
    broadband_upgrade::Float64 = 0.0
    training_cost::Float64 = 5_000.0
end

"""
    TelehealthROI

Comprehensive telehealth program ROI analysis.

# Fields
- `services::Vector{TelehealthService}`: services included in the analysis
- `investment::TelehealthInvestment`: investment parameters
- `direct_revenue::Float64`: total annual direct encounter revenue
- `direct_costs::Float64`: total annual variable encounter costs
- `avoided_transfer_savings::Float64`: annual value of avoided transfers
- `total_investment::Float64`: total first-year investment outlay
- `net_benefit_year1::Float64`: net financial benefit in year 1
- `net_benefit_year3::Float64`: cumulative net benefit through year 3
- `roi_pct::Float64`: return on investment as percentage
- `breakeven_months::Union{Int,Nothing}`: months to breakeven, nothing if never
"""
@kwdef struct TelehealthROI
    services::Vector{TelehealthService}
    investment::TelehealthInvestment
    direct_revenue::Float64
    direct_costs::Float64
    avoided_transfer_savings::Float64
    total_investment::Float64
    net_benefit_year1::Float64
    net_benefit_year3::Float64
    roi_pct::Float64
    breakeven_months::Union{Int,Nothing}
end

function Base.show(io::IO, r::TelehealthROI)
    be = isnothing(r.breakeven_months) ? "never" : "$(r.breakeven_months)mo"
    print(io, "TelehealthROI(roi=$(round(r.roi_pct, digits=1))%, breakeven=$(be), year1=\$$(round(Int, r.net_benefit_year1)))")
end

"""
    calculate_telehealth_roi(services::Vector{TelehealthService},
                             investment::TelehealthInvestment;
                             projection_years::Int=3) -> TelehealthROI

Calculate multi-year ROI for a telehealth program. Year 1 includes all one-time
costs; subsequent years carry only recurring costs. Volume is assumed to grow
10% per year after year 1 as adoption increases.
"""
function calculate_telehealth_roi(services::Vector{TelehealthService},
                                  investment::TelehealthInvestment;
                                  projection_years::Int = 3)::TelehealthROI
    projection_years > 0 || error("projection_years must be positive; got $projection_years")
    !isempty(services) || error("services must not be empty")
    investment.infrastructure_cost >= 0.0 || error("infrastructure_cost must be non-negative; got $(investment.infrastructure_cost)")
    investment.annual_licensing >= 0.0 || error("annual_licensing must be non-negative; got $(investment.annual_licensing)")
    investment.annual_staffing >= 0.0 || error("annual_staffing must be non-negative; got $(investment.annual_staffing)")
    investment.broadband_upgrade >= 0.0 || error("broadband_upgrade must be non-negative; got $(investment.broadband_upgrade)")
    investment.training_cost >= 0.0 || error("training_cost must be non-negative; got $(investment.training_cost)")
    for s in services
        s.annual_volume >= 0 || error("annual_volume must be non-negative; got $(s.annual_volume) for $(s.service_type)")
        s.revenue_per_encounter >= 0.0 || error("revenue_per_encounter must be non-negative; got $(s.revenue_per_encounter) for $(s.service_type)")
        s.cost_per_encounter >= 0.0 || error("cost_per_encounter must be non-negative; got $(s.cost_per_encounter) for $(s.service_type)")
        s.avoided_transfers_per_year >= 0 || error("avoided_transfers_per_year must be non-negative; got $(s.avoided_transfers_per_year) for $(s.service_type)")
        s.avg_transfer_cost_avoided >= 0.0 || error("avg_transfer_cost_avoided must be non-negative; got $(s.avg_transfer_cost_avoided) for $(s.service_type)")
    end

    # Annual direct revenue and variable costs at base volume
    annual_revenue = sum(s.annual_volume * s.revenue_per_encounter for s in services)
    annual_var_cost = sum(s.annual_volume * s.cost_per_encounter for s in services)
    annual_transfer_savings = sum(s.avoided_transfers_per_year * s.avg_transfer_cost_avoided for s in services)

    # Investment components
    one_time = investment.infrastructure_cost + investment.broadband_upgrade + investment.training_cost
    annual_fixed = investment.annual_licensing + investment.annual_staffing
    total_investment_y1 = one_time + annual_fixed

    # Year 1 net benefit
    annual_net_operating = annual_revenue - annual_var_cost + annual_transfer_savings
    net_y1 = annual_net_operating - total_investment_y1

    # Multi-year cumulative benefit with 10% annual volume growth
    cumulative_benefit = 0.0
    for yr in 1:projection_years
        growth_factor = 1.0 + 0.10 * (yr - 1)
        yr_revenue = annual_revenue * growth_factor
        yr_var_cost = annual_var_cost * growth_factor
        yr_transfer = annual_transfer_savings * growth_factor
        yr_net_operating = yr_revenue - yr_var_cost + yr_transfer
        yr_cost = yr == 1 ? total_investment_y1 : annual_fixed
        cumulative_benefit += yr_net_operating - yr_cost
    end

    # ROI percentage based on total investment over projection period
    total_invested = one_time + annual_fixed * projection_years
    roi_pct = total_invested > 0.0 ? (cumulative_benefit / total_invested) * 100.0 : 0.0

    # Breakeven month calculation
    monthly_net = annual_net_operating / 12.0
    breakeven_months = if monthly_net <= 0.0
        nothing
    else
        months_needed = ceil(Int, total_investment_y1 / monthly_net)
        months_needed <= projection_years * 12 ? months_needed : nothing
    end

    return TelehealthROI(
        services = services,
        investment = investment,
        direct_revenue = annual_revenue,
        direct_costs = annual_var_cost,
        avoided_transfer_savings = annual_transfer_savings,
        total_investment = total_investment_y1,
        net_benefit_year1 = net_y1,
        net_benefit_year3 = cumulative_benefit,
        roi_pct = roi_pct,
        breakeven_months = breakeven_months,
    )
end

"""
    telehealth_service_comparison(services::Vector{TelehealthService}) -> Vector{NamedTuple}

Rank telehealth services by contribution margin (revenue minus variable cost
plus transfer savings), sorted descending.
"""
function telehealth_service_comparison(services::Vector{TelehealthService})::Vector{NamedTuple}
    !isempty(services) || error("services must not be empty")

    rows = [(
        service_type = s.service_type,
        annual_volume = s.annual_volume,
        contribution_margin = s.annual_volume * (s.revenue_per_encounter - s.cost_per_encounter) +
                              s.avoided_transfers_per_year * s.avg_transfer_cost_avoided,
        margin_per_encounter = s.revenue_per_encounter - s.cost_per_encounter,
    ) for s in services]

    sort!(rows, by = r -> r.contribution_margin, rev = true)
    return rows
end
