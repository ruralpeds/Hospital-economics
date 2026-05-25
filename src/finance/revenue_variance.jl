# Revenue Variance Bridge Analysis
#
# Decomposes revenue variance between periods into price, volume, and mix
# components at the service-line level. Follows the standard three-way
# variance decomposition used in healthcare finance.

"""
    ServiceLineRevenue

Revenue data for a single service line across two periods.

# Fields
- `name::String`: service line identifier (e.g. "Cardiology", "Orthopedics")
- `prior_volume::Float64`: volume (units, cases, visits) in the prior period
- `current_volume::Float64`: volume in the current period
- `prior_price::Float64`: average reimbursement per unit in the prior period
- `current_price::Float64`: average reimbursement per unit in the current period
"""
@kwdef struct ServiceLineRevenue
    name::String
    prior_volume::Float64
    current_volume::Float64
    prior_price::Float64
    current_price::Float64
end

"""
    RevenueVarianceResult

Result of three-way revenue variance decomposition.

# Fields
- `total_variance::Float64`: total revenue change = current revenue - prior revenue
- `price_variance::Float64`: variance attributable to price changes
- `volume_variance::Float64`: variance attributable to volume changes
- `mix_variance::Float64`: residual variance from service-mix shifts
- `price_pct::Float64`: price variance as percentage of prior revenue
- `volume_pct::Float64`: volume variance as percentage of prior revenue
- `mix_pct::Float64`: mix variance as percentage of prior revenue
- `service_details::Vector{NamedTuple}`: per-service-line variance breakdown
"""
@kwdef struct RevenueVarianceResult
    total_variance::Float64
    price_variance::Float64
    volume_variance::Float64
    mix_variance::Float64
    price_pct::Float64
    volume_pct::Float64
    mix_pct::Float64
    service_details::Vector{NamedTuple{(:name, :price_var, :volume_var, :mix_var), Tuple{String, Float64, Float64, Float64}}}
end

function Base.show(io::IO, r::RevenueVarianceResult)
    print(io, "RevenueVarianceResult(total=\$$(round(Int, r.total_variance)), " *
          "price=\$$(round(Int, r.price_variance)), " *
          "volume=\$$(round(Int, r.volume_variance)), " *
          "mix=\$$(round(Int, r.mix_variance)))")
end

"""
    calculate_revenue_variance(services::Vector{ServiceLineRevenue}) -> RevenueVarianceResult

Decompose total revenue variance into price, volume, and mix components.

## Three-Way Variance Decomposition

For each service line `i`:
- **Price variance** = (current_price_i - prior_price_i) × current_volume_i
- **Volume variance** = prior_price_i × (current_volume_i - prior_volume_i)
- **Mix variance** = total_variance - price_variance - volume_variance

Aggregate variances are the sums across all service lines. Per-service-line
mix variance is computed as the residual: service_total - service_price - service_volume.

Percentages are expressed relative to total prior-period revenue.

# Arguments
- `services::Vector{ServiceLineRevenue}`: revenue data for each service line

# Returns
- `RevenueVarianceResult`: decomposed variance with service-level detail
"""
function calculate_revenue_variance(services::Vector{ServiceLineRevenue})::RevenueVarianceResult
    !isempty(services) || error("services must not be empty")

    total_price_var = 0.0
    total_volume_var = 0.0
    total_prior_revenue = 0.0
    total_current_revenue = 0.0

    details = NamedTuple{(:name, :price_var, :volume_var, :mix_var), Tuple{String, Float64, Float64, Float64}}[]

    for svc in services
        prior_rev = svc.prior_price * svc.prior_volume
        current_rev = svc.current_price * svc.current_volume

        total_prior_revenue += prior_rev
        total_current_revenue += current_rev

        # Service-level price variance: effect of price change at current volume
        svc_price_var = (svc.current_price - svc.prior_price) * svc.current_volume

        # Service-level volume variance: effect of volume change at prior price
        svc_volume_var = svc.prior_price * (svc.current_volume - svc.prior_volume)

        # Service-level mix variance: residual
        svc_total = current_rev - prior_rev
        svc_mix_var = svc_total - svc_price_var - svc_volume_var

        total_price_var += svc_price_var
        total_volume_var += svc_volume_var

        push!(details, (name=svc.name, price_var=svc_price_var,
                        volume_var=svc_volume_var, mix_var=svc_mix_var))
    end

    total_variance = total_current_revenue - total_prior_revenue
    total_mix_var = total_variance - total_price_var - total_volume_var

    # Percentages relative to prior revenue
    price_pct = total_prior_revenue > 0.0 ? (total_price_var / total_prior_revenue) * 100.0 : 0.0
    volume_pct = total_prior_revenue > 0.0 ? (total_volume_var / total_prior_revenue) * 100.0 : 0.0
    mix_pct = total_prior_revenue > 0.0 ? (total_mix_var / total_prior_revenue) * 100.0 : 0.0

    return RevenueVarianceResult(
        total_variance = total_variance,
        price_variance = total_price_var,
        volume_variance = total_volume_var,
        mix_variance = total_mix_var,
        price_pct = price_pct,
        volume_pct = volume_pct,
        mix_pct = mix_pct,
        service_details = details,
    )
end
