# ── Operational efficiency and throughput ──────────────────────────────────
#
# Length of stay analysis, bed turnover, ED throughput, surgical utilization,
# and capacity planning models for rural hospitals.

"""
    length_of_stay_analysis(los_data::Vector{Float64}; target_los=nothing) -> NamedTuple

Analyse length-of-stay distribution.

Returns `(mean_los, median_los, p75, p90, excess_days, excess_cost_per_day,
geometric_mean, outlier_count, outlier_threshold)`.
"""
function length_of_stay_analysis(los_data::Vector{Float64};
                                 target_los::Union{Nothing,Float64}=nothing)
    isempty(los_data) && throw(DataValidationError("LOS data vector is empty"))
    any(x -> x < 0, los_data) && throw(DomainValidationError("los_data", "negative values",
        "≥ 0", "Length of stay cannot be negative"))

    n = length(los_data)
    sorted = sort(los_data)
    m = mean(los_data)
    med = median(los_data)
    p75 = quantile(sorted, 0.75)
    p90 = quantile(sorted, 0.90)

    # Geometric mean (used by CMS for LOS benchmarking)
    positive_los = filter(>(0), los_data)
    gmean = isempty(positive_los) ? 0.0 : exp(mean(log.(positive_los)))

    # Outlier detection (> 3× geometric mean)
    outlier_threshold = 3.0 * gmean
    outlier_count = count(>(outlier_threshold), los_data)

    # Excess days above target
    tgt = isnothing(target_los) ? gmean : target_los
    excess_days = sum(max(0, los - tgt) for los in los_data)

    return (mean_los=m, median_los=med, geometric_mean=gmean,
            p75=p75, p90=p90, n=n,
            excess_days=excess_days, target_los=tgt,
            outlier_count=outlier_count, outlier_threshold=outlier_threshold)
end

"""
    bed_turnover_rate(discharges::Int, beds::Int, days::Int) -> NamedTuple

Compute bed utilization metrics.

Returns `(occupancy_rate, turnover_rate, avg_daily_census, beds_needed_at_target)`.
"""
function bed_turnover_rate(discharges::Int, beds::Int, days::Int;
                           avg_los::Float64=4.5, target_occupancy::Float64=0.85)
    beds > 0 || throw(DomainValidationError("beds", string(beds), "> 0", "Must have beds"))
    days > 0 || throw(DomainValidationError("days", string(days), "> 0", "Must have days"))

    patient_days = discharges * avg_los
    avg_daily_census = patient_days / days
    occupancy_rate = avg_daily_census / beds
    turnover_rate = discharges / beds
    beds_needed = ceil(Int, avg_daily_census / target_occupancy)

    return (occupancy_rate=occupancy_rate, turnover_rate=turnover_rate,
            avg_daily_census=avg_daily_census, patient_days=patient_days,
            beds_needed_at_target=beds_needed, current_beds=beds)
end

"""
    ed_throughput(arrivals::Vector{Int}, departures::Vector{Int},
                  boarding_hours::Vector{Float64}) -> NamedTuple

Compute Emergency Department throughput metrics.

Vectors are per-time-period (e.g., hourly or per-shift).
"""
function ed_throughput(arrivals::Vector{Int}, departures::Vector{Int},
                       boarding_hours::Vector{Float64})
    n = length(arrivals)
    total_arrivals = sum(arrivals)
    total_departures = sum(departures)
    avg_boarding = mean(boarding_hours)
    max_boarding = maximum(boarding_hours)

    # Left-without-being-seen estimate (crude: periods where arrivals >> departures)
    lwbs_estimate = sum(max(0, arrivals[i] - departures[i]) for i in 1:n)

    # Door-to-disposition proxy (boarding hours is a major contributor)
    # CMS ED-1 measure: median time from arrival to departure for admitted patients

    return (total_arrivals=total_arrivals, total_departures=total_departures,
            avg_boarding_hours=avg_boarding, max_boarding_hours=max_boarding,
            lwbs_estimate=lwbs_estimate, periods=n)
end

"""
    surgical_utilization(cases::Int, rooms::Int, days::Int;
                         avg_case_minutes::Float64=120.0,
                         turnover_minutes::Float64=30.0,
                         available_hours_per_room::Float64=8.0) -> NamedTuple

Compute surgical suite utilization.
"""
function surgical_utilization(cases::Int, rooms::Int, days::Int;
                              avg_case_minutes::Float64=120.0,
                              turnover_minutes::Float64=30.0,
                              available_hours_per_room::Float64=8.0)
    rooms > 0 || throw(DomainValidationError("rooms", string(rooms), "> 0", "Must have OR rooms"))
    total_available_minutes = rooms * days * available_hours_per_room * 60
    total_used_minutes = cases * (avg_case_minutes + turnover_minutes)
    utilization = total_available_minutes > 0 ? total_used_minutes / total_available_minutes : 0.0

    cases_per_room_per_day = days > 0 ? cases / (rooms * days) : 0.0
    max_cases_per_room = available_hours_per_room * 60 / (avg_case_minutes + turnover_minutes)

    return (utilization=utilization, cases_per_room_per_day=cases_per_room_per_day,
            max_cases_per_room_per_day=max_cases_per_room, total_cases=cases,
            total_available_minutes=total_available_minutes,
            total_used_minutes=total_used_minutes)
end

"""
    capacity_planning(current_demand::Float64, growth_rate::Float64,
                      current_capacity::Float64, expansion_lead_time::Int,
                      planning_horizon::Int) -> DataFrame

Project demand vs capacity over a planning horizon.
Flags years where demand exceeds capacity (trigger for expansion).
"""
function capacity_planning(current_demand::Float64, growth_rate::Float64,
                           current_capacity::Float64, expansion_lead_time::Int,
                           planning_horizon::Int)::DataFrame
    rows = NamedTuple[]
    demand = current_demand
    capacity = current_capacity
    expansion_triggered = false
    trigger_year = 0

    for year in 1:planning_horizon
        demand *= (1 + growth_rate)
        utilization = capacity > 0 ? demand / capacity : Inf
        gap = capacity - demand

        # Trigger expansion when utilization > 85%
        if utilization > 0.85 && !expansion_triggered
            expansion_triggered = true
            trigger_year = year
        end

        # Expansion completes after lead time
        if expansion_triggered && year >= trigger_year + expansion_lead_time
            capacity *= 1.25  # 25% capacity expansion
            expansion_triggered = false
        end

        push!(rows, (year=year, demand=demand, capacity=capacity,
                     utilization=utilization, gap=gap,
                     expansion_needed=utilization > 0.85))
    end
    return DataFrame(rows)
end

"""
    staffing_ratio(patient_days::Float64, fte_count::Float64;
                   hours_per_fte::Float64=2080.0, productive_pct::Float64=0.85) -> NamedTuple

Compute nurse staffing ratios and productivity metrics.
"""
function staffing_ratio(patient_days::Float64, fte_count::Float64;
                        hours_per_fte::Float64=2080.0,
                        productive_pct::Float64=0.85)
    fte_count > 0 || throw(DomainValidationError("fte_count", string(fte_count),
        "> 0", "Must have staff"))
    productive_hours = fte_count * hours_per_fte * productive_pct
    hppd = patient_days > 0 ? productive_hours / patient_days : 0.0  # hours per patient day
    patients_per_nurse = hppd > 0 ? 24.0 / hppd : 0.0  # average census per nurse

    return (hours_per_patient_day=hppd, patients_per_nurse=patients_per_nurse,
            productive_hours=productive_hours, fte_count=fte_count,
            patient_days=patient_days)
end
