module Metrics

using Dates
using Threads
using SearchLight

export record_request, record_error, record_latency, increment_inflight, decrement_inflight
export get_metrics_exposition, check_db_ready

# Metrics storage
const REQUESTS_TOTAL = Atomic{Int}(0)
const ERRORS_TOTAL = Atomic{Int}(0)
const REQUESTS_INFLIGHT = Atomic{Int}(0)
const LATENCY_SUM = Atomic{Float64}(0.0)

"""
    increment_inflight()
"""
function increment_inflight()
    Threads.atomic_add!(REQUESTS_INFLIGHT, 1)
end

"""
    decrement_inflight()
"""
function decrement_inflight()
    Threads.atomic_sub!(REQUESTS_INFLIGHT, 1)
end

"""
    record_request()
"""
function record_request()
    Threads.atomic_add!(REQUESTS_TOTAL, 1)
end

"""
    record_error()
"""
function record_error()
    Threads.atomic_add!(ERRORS_TOTAL, 1)
end

"""
    record_latency(latency_seconds::Float64)
"""
function record_latency(latency_seconds::Float64)
    Threads.atomic_add!(LATENCY_SUM, latency_seconds)
end

"""
    get_metrics_exposition()

Returns Prometheus formatted metrics.
"""
function get_metrics_exposition()
    io = IOBuffer()
    
    println(io, "# HELP http_requests_total Total number of HTTP requests")
    println(io, "# TYPE http_requests_total counter")
    println(io, "http_requests_total ", REQUESTS_TOTAL[])
    
    println(io, "# HELP http_errors_total Total number of HTTP errors")
    println(io, "# TYPE http_errors_total counter")
    println(io, "http_errors_total ", ERRORS_TOTAL[])
    
    println(io, "# HELP http_requests_inflight Number of in-flight HTTP requests")
    println(io, "# TYPE http_requests_inflight gauge")
    println(io, "http_requests_inflight ", REQUESTS_INFLIGHT[])
    
    println(io, "# HELP http_request_duration_seconds_sum Total latency of HTTP requests in seconds")
    println(io, "# TYPE http_request_duration_seconds_sum counter")
    println(io, "http_request_duration_seconds_sum ", LATENCY_SUM[])
    
    return String(take!(io))
end

"""
    check_db_ready()

Checks if the database is reachable.
"""
function check_db_ready()
    try
        # Attempt to run a simple query or check connection
        if !SearchLight.isconnected()
            # Try to connect if not connected? 
            # Usually SearchLight handles this, but let's check if we can query.
            return false
        end
        # Simple ping
        SearchLight.query("SELECT 1")
        return true
    catch e
        @error "Database readiness check failed" exception=e
        return false
    end
end

end # module
