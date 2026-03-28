# ============================================================================
# Geographic Access Modeling
# ============================================================================
#
# Two-Step Floating Catchment Area (2SFCA) and drive-time modeling for
# rural hospital service areas.  Estimates catchment populations, market
# share, and the access impact of facility closures.
# ============================================================================

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

"""
    FacilityLocation

Healthcare facility with coordinates; `service_type` is one of
`:full_service`, `:ed_only`, `:clinic`, `:reh`; `capacity` is relative
(1.0 = typical community hospital).
"""
@kwdef struct FacilityLocation
    name::String
    latitude::Float64
    longitude::Float64
    service_type::Symbol = :full_service
    capacity::Float64    = 1.0
end

function Base.show(io::IO, f::FacilityLocation)
    print(io, "FacilityLocation(\"", f.name, "\", ", f.service_type, ")")
end

"""
    PopulationCenter

Population center (town, census tract) with total `population` and
`pct_over_65` for healthcare demand estimation.
"""
@kwdef struct PopulationCenter
    name::String
    latitude::Float64
    longitude::Float64
    population::Int
    pct_over_65::Float64 = 0.15
end

"""
    AccessResult

Catchment area calculation output: population, drive time, 2SFCA access
score, market share, and estimated annual volume.
"""
@kwdef struct AccessResult
    facility_name::String
    catchment_population::Int
    drive_time_minutes::Float64
    access_score::Float64
    market_share_estimate::Float64
    volume_estimate::Float64
end

function Base.show(io::IO, r::AccessResult)
    print(io, "AccessResult(\"", r.facility_name, "\", pop=", r.catchment_population,
          ", vol=", round(Int, r.volume_estimate), ")")
end

"""Great-circle distance in km between two WGS-84 points (Haversine)."""
function haversine_distance(lat1::Real, lon1::Real, lat2::Real, lon2::Real)::Float64
    R = 6371.0  # Earth radius in km
    dlat = deg2rad(lat2 - lat1)
    dlon = deg2rad(lon2 - lon1)
    a = sin(dlat / 2)^2 + cos(deg2rad(lat1)) * cos(deg2rad(lat2)) * sin(dlon / 2)^2
    return 2R * asin(sqrt(clamp(a, 0.0, 1.0)))
end

"""Estimate drive time in minutes with 1.3× rural winding factor."""
function estimate_drive_time(distance_km::Float64; avg_speed_kmh::Float64=80.0)::Float64
    winding_factor = 1.3
    return (distance_km * winding_factor / avg_speed_kmh) * 60.0
end

"""
    calculate_catchment(facility, populations; max_drive_minutes=30.0) -> AccessResult

Compute catchment using exponential distance-decay (`exp(-0.05 * min)`).
"""
function calculate_catchment(facility::FacilityLocation,
                             populations::Vector{PopulationCenter};
                             max_drive_minutes::Float64=30.0)::AccessResult
    -90.0 <= facility.latitude <= 90.0 || error("facility latitude must be between -90 and 90; got $(facility.latitude)")
    -180.0 <= facility.longitude <= 180.0 || error("facility longitude must be between -180 and 180; got $(facility.longitude)")
    facility.capacity > 0.0 || error("facility capacity must be positive; got $(facility.capacity)")
    !isempty(populations) || error("populations must not be empty")
    max_drive_minutes > 0.0 || error("max_drive_minutes must be positive; got $max_drive_minutes")
    for pc in populations
        -90.0 <= pc.latitude <= 90.0 || error("latitude must be between -90 and 90 for $(pc.name); got $(pc.latitude)")
        -180.0 <= pc.longitude <= 180.0 || error("longitude must be between -180 and 180 for $(pc.name); got $(pc.longitude)")
        pc.population >= 0 || error("population must be non-negative for $(pc.name); got $(pc.population)")
        0.0 <= pc.pct_over_65 <= 1.0 || error("pct_over_65 must be between 0 and 1 for $(pc.name); got $(pc.pct_over_65)")
    end

    total_pop = 0
    weighted_demand = 0.0
    weighted_time_sum = 0.0
    pop_in_range = 0

    for pc in populations
        dist_km = haversine_distance(facility.latitude, facility.longitude,
                                     pc.latitude, pc.longitude)
        minutes = estimate_drive_time(dist_km)

        if minutes <= max_drive_minutes
            decay = exp(-0.05 * minutes)
            # Older populations generate ~2× healthcare demand
            age_factor = 1.0 + pc.pct_over_65
            demand = pc.population * decay * age_factor

            total_pop += pc.population
            weighted_demand += demand
            weighted_time_sum += minutes * pc.population
            pop_in_range += pc.population
        end
    end

    avg_drive = pop_in_range > 0 ? weighted_time_sum / pop_in_range : 0.0
    access_score = weighted_demand > 0 ? facility.capacity / weighted_demand : 0.0

    # Estimate utilisation: ~100 discharges per 1000 pop per year, scaled by access
    base_utilisation_rate = 0.10
    market_share = clamp(facility.capacity * access_score * 1000.0, 0.0, 1.0)
    volume_est = total_pop * base_utilisation_rate * market_share

    return AccessResult(
        facility_name        = facility.name,
        catchment_population = total_pop,
        drive_time_minutes   = round(avg_drive; digits=1),
        access_score         = round(access_score; digits=6),
        market_share_estimate = round(market_share; digits=4),
        volume_estimate      = round(volume_est; digits=0),
    )
end

"""
    closure_access_impact(facilities, populations, closed_idx) -> NamedTuple

Assess geographic access impact of closing facility at `closed_idx`.
Returns population losing access, new average/max drive times, and
the facility absorbing most displaced patients.
"""
function closure_access_impact(facilities::Vector{FacilityLocation},
                               populations::Vector{PopulationCenter},
                               closed_idx::Int)::NamedTuple
    !isempty(facilities) || error("facilities must not be empty")
    !isempty(populations) || error("populations must not be empty")
    1 <= closed_idx <= length(facilities) ||
        error("closed_idx ($closed_idx) out of range 1:$(length(facilities))")
    for pc in populations
        pc.population >= 0 || error("population must be non-negative for $(pc.name); got $(pc.population)")
    end

    closed = facilities[closed_idx]
    remaining = [f for (i, f) in enumerate(facilities) if i != closed_idx]

    isempty(remaining) && error("Cannot close the only facility")

    pop_losing_access = 0
    total_pop = 0
    weighted_time = 0.0
    max_time = 0.0
    nearest_counts = Dict{String,Int}()

    for pc in populations
        # Find nearest remaining facility
        best_time = Inf
        best_name = ""
        for f in remaining
            dist_km = haversine_distance(f.latitude, f.longitude, pc.latitude, pc.longitude)
            t = estimate_drive_time(dist_km)
            if t < best_time
                best_time = t
                best_name = f.name
            end
        end

        total_pop += pc.population
        weighted_time += best_time * pc.population
        max_time = max(max_time, best_time)

        if best_time > 30.0
            pop_losing_access += pc.population
        end

        nearest_counts[best_name] = get(nearest_counts, best_name, 0) + pc.population
    end

    avg_time = total_pop > 0 ? weighted_time / total_pop : 0.0
    top_absorber = isempty(nearest_counts) ? "" :
                   first(sort(collect(nearest_counts); by=last, rev=true)).first

    return (
        closed_facility        = closed.name,
        population_losing_access = pop_losing_access,
        avg_new_drive_minutes  = round(avg_time; digits=1),
        max_new_drive_minutes  = round(max_time; digits=1),
        next_nearest_facility  = top_absorber,
    )
end
