"""
    performance_optimization.jl

Performance optimization module for ABM simulations including:
- Profiling and benchmarking
- Parallel processing with pmap
- Caching for expensive computations
- Vectorization helpers
- Memory-efficient data structures
"""

using Distributed
using StatsBase
using DataFrames

export ProfileResult, CacheLayer, parallelize_sweep, benchmark_abm, setup_worker_pool

"""
    struct ProfileResult

Results from profiling an ABM simulation
"""
@kwdef struct ProfileResult
    total_time::Float64
    allocations::Float64
    gc_time::Float64
    hot_spots::Dict{String, Float64} = Dict()
    recommendations::Vector{String} = String[]
end

"""
    struct CacheLayer

LRU cache for memoizing expensive computations
"""
mutable struct CacheLayer
    cache::Dict{String, Any}
    max_size::Int
    access_count::Int

    function CacheLayer(max_size::Int = 1000)
        new(Dict(), max_size, 0)
    end
end

"""
    get_cached(cache::CacheLayer, key::String)

Retrieve value from cache if present
"""
function get_cached(cache::CacheLayer, key::String)
    if haskey(cache.cache, key)
        cache.access_count += 1
        return cache.cache[key]
    end
    return nothing
end

"""
    set_cached(cache::CacheLayer, key::String, value::Any)

Store value in cache with LRU eviction
"""
function set_cached(cache::CacheLayer, key::String, value::Any)
    if length(cache.cache) >= cache.max_size
        # Remove oldest entries (simple FIFO for now)
        pop!(cache.cache, first(keys(cache.cache)))
    end
    cache.cache[key] = value
end

"""
    clear_cache(cache::CacheLayer)

Clear all cached entries
"""
function clear_cache(cache::CacheLayer)
    empty!(cache.cache)
    cache.access_count = 0
end

"""
    setup_worker_pool(n_workers::Int = nprocs()-1)

Setup distributed worker pool for parallelization
"""
function setup_worker_pool(n_workers::Int = max(1, nprocs() - 1))
    if nworkers() < n_workers
        addprocs(n_workers - nworkers())
    end
    return nworkers()
end

"""
    parallelize_sweep(
        run_func::Function,
        param_ranges::Dict{String, Tuple{Float64, Float64, Int}},
        base_params::Dict{String, Any};
        n_workers::Int = nprocs()-1
    )

Run parameter sweep in parallel using pmap
Returns: (results::Vector, timing::Float64)
"""
function parallelize_sweep(
    run_func::Function,
    param_ranges::Dict{String, Tuple{Float64, Float64, Int}},
    base_params::Dict{String, Any};
    n_workers::Int = max(1, nprocs() - 1)
)
    # Generate parameter combinations
    param_names = collect(keys(param_ranges))
    param_lists = [
        range(param_ranges[p][1], param_ranges[p][2], length=param_ranges[p][3])
        for p in param_names
    ]

    # Create Cartesian product of parameters
    param_combinations = vec(collect(Iterators.product(param_lists...)))

    # Convert to parameter dicts
    sweep_params = [
        merge(base_params, Dict(param_names[i] => combo[i] for i in 1:length(param_names)))
        for combo in param_combinations
    ]

    @info "Running $(length(sweep_params)) simulations on $(n_workers) workers"

    start_time = time()
    results = pmap(run_func, sweep_params; batch_size=max(1, div(length(sweep_params), n_workers)))
    elapsed = time() - start_time

    @info "Parallel sweep completed in $(round(elapsed, digits=2))s"
    return results, elapsed
end

"""
    benchmark_abm(
        run_func::Function,
        params::Dict{String, Any},
        n_runs::Int = 10
    )

Benchmark ABM simulation performance
"""
function benchmark_abm(
    run_func::Function,
    params::Dict{String, Any},
    n_runs::Int = 10
)
    times = Float64[]
    allocations = Float64[]

    for _ in 1:n_runs
        # Time the function
        t = @timed run_func(params)
        push!(times, t.time)
        push!(allocations, t.bytes / 1e6)  # Convert to MB
    end

    mean_time = mean(times)
    std_time = std(times)
    mean_alloc = mean(allocations)

    recommendations = String[]
    if mean_time > 1.0
        push!(recommendations, "Consider using pmap for parameter sweeps")
    end
    if mean_alloc > 100  # >100MB
        push!(recommendations, "High memory allocation - consider vectorization")
    end

    return ProfileResult(
        total_time=sum(times),
        allocations=sum(allocations),
        gc_time=0.0,  # Would require more detailed profiling
        hot_spots=Dict("run_func" => mean_time),
        recommendations=recommendations
    )
end

"""
    vectorized_demand_forecast(
        demand_baseline::Float64,
        trend::Vector{Float64},
        seasonality::Vector{Float64}
    )

Vectorized demand forecasting (faster than per-agent iteration)
"""
function vectorized_demand_forecast(
    demand_baseline::Float64,
    trend::Vector{Float64},
    seasonality::Vector{Float64}
)
    @assert length(trend) == length(seasonality) "Trend and seasonality must be same length"
    return demand_baseline .* (1 .+ trend) .* seasonality
end

"""
    batch_compute_stockout_risk(
        current_stocks::Vector{Float64},
        reorder_points::Vector{Float64},
        lead_times::Vector{Int}
    )

Batch computation of stockout risk (vectorized)
"""
function batch_compute_stockout_risk(
    current_stocks::Vector{Float64},
    reorder_points::Vector{Float64},
    lead_times::Vector{Int}
)
    @assert length(current_stocks) == length(reorder_points) == length(lead_times)

    # Vectorized stockout check
    at_risk = current_stocks .< reorder_points
    high_risk = current_stocks .< (reorder_points ./ 2)

    return Dict(
        "at_risk" => findall(at_risk),
        "high_risk" => findall(high_risk),
        "risk_score" => sum(high_risk) / length(current_stocks)
    )
end

end  # module
