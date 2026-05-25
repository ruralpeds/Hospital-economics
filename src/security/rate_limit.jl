"""
Rate limiting module for the Rural Hospital Economics Simulator.

Provides a sliding-window rate limiter that tracks requests per client IP
and a Genie-compatible middleware function to enforce request limits.
"""
module RateLimit

using Dates, HTTP, JSON3

export RateLimitConfig, DEFAULT_CONFIG,
       check_rate_limit, cleanup_old_entries!,
       rate_limit_middleware, REQUEST_LOG

"""
Configuration for rate limiting behaviour.

Fields:
- `max_requests::Int` — maximum number of requests allowed within the window (default 100)
- `window_seconds::Int` — sliding window duration in seconds (default 60)
- `burst_limit::Int` — maximum burst of requests in a short period (default 20)
"""
struct RateLimitConfig
    max_requests::Int
    window_seconds::Int
    burst_limit::Int
end

RateLimitConfig() = RateLimitConfig(100, 60, 20)

"""Global request log — maps client IP to a vector of request timestamps."""
const REQUEST_LOG = Dict{String, Vector{DateTime}}()

"""Default rate limit configuration: 100 requests per 60-second window, burst limit of 20."""
const DEFAULT_CONFIG = RateLimitConfig(100, 60, 20)

# ---------------------------------------------------------------------------
# Core rate limiting logic
# ---------------------------------------------------------------------------

"""
    cleanup_old_entries!(ip::String, window::Int)

Remove all request timestamps for `ip` that are older than `window` seconds
from the current time. If no entries remain, the key is deleted from
`REQUEST_LOG`.
"""
function cleanup_old_entries!(ip::String, window::Int)
    if !haskey(REQUEST_LOG, ip)
        return
    end
    cutoff = now(UTC) - Second(window)
    filter!(ts -> ts > cutoff, REQUEST_LOG[ip])
    if isempty(REQUEST_LOG[ip])
        delete!(REQUEST_LOG, ip)
    end
    return nothing
end

"""
    check_rate_limit(ip::String, config::RateLimitConfig=DEFAULT_CONFIG)::Tuple{Bool, Int}

Check whether the client at `ip` is within the configured rate limit.

Returns a tuple `(allowed, remaining)`:
- `allowed` — `true` if the request should be permitted
- `remaining` — number of requests the client may still make in the current window

The function first cleans up expired entries, then counts requests in the
current window and compares against `config.max_requests`.
"""
function check_rate_limit(ip::String, config::RateLimitConfig=DEFAULT_CONFIG)::Tuple{Bool, Int}
    # Clean up entries outside the current window
    cleanup_old_entries!(ip, config.window_seconds)

    # Initialise log for new IPs
    if !haskey(REQUEST_LOG, ip)
        REQUEST_LOG[ip] = Vector{DateTime}()
    end

    current_count = length(REQUEST_LOG[ip])

    # Check against max_requests limit
    if current_count >= config.max_requests
        remaining = 0
        return (false, remaining)
    end

    # Record this request
    push!(REQUEST_LOG[ip], now(UTC))
    remaining = config.max_requests - (current_count + 1)

    return (true, remaining)
end

# ---------------------------------------------------------------------------
# Genie middleware
# ---------------------------------------------------------------------------

"""
    rate_limit_middleware(handler)

Genie-compatible middleware that enforces per-IP rate limiting.

Flow:
1. Extract the client IP from the `X-Forwarded-For` header (first entry)
   or fall back to the request's remote address.
2. Call `check_rate_limit` to determine whether the request is allowed.
3. If the client has exceeded the limit, return an HTTP 429 (Too Many Requests)
   JSON response with a `Retry-After` header.
4. Otherwise, add `X-RateLimit-Remaining` and `X-RateLimit-Limit` headers
   to the response and pass through to the next handler.
"""
function rate_limit_middleware(handler)
    return function(req)
        # 1. Extract client IP
        ip = "unknown"
        try
            headers_dict = Dict{String, String}()
            for (k, v) in req.headers
                headers_dict[lowercase(String(k))] = String(v)
            end

            forwarded = get(headers_dict, "x-forwarded-for", "")
            if !isempty(forwarded)
                # X-Forwarded-For may contain multiple IPs; use the first one
                ip = strip(first(split(forwarded, ",")))
            else
                # Fall back to the remote address on the request
                try
                    ip = string(req.context[:ip])
                catch
                    try
                        ip = string(req.remote)
                    catch
                        ip = "127.0.0.1"
                    end
                end
            end
        catch
            ip = "127.0.0.1"
        end

        # 2. Check rate limit
        (allowed, remaining) = check_rate_limit(ip)

        # 3. If rate limited, return 429
        if !allowed
            retry_after = string(DEFAULT_CONFIG.window_seconds)
            return HTTP.Response(429,
                [
                    "Content-Type"  => "application/json",
                    "Retry-After"   => retry_after,
                    "X-RateLimit-Limit"     => string(DEFAULT_CONFIG.max_requests),
                    "X-RateLimit-Remaining" => "0",
                ],
                body = JSON3.write(Dict(
                    "status"  => "error",
                    "code"    => 429,
                    "message" => "Rate limit exceeded. Please retry after $(retry_after) seconds.",
                ))
            )
        end

        # 4. Pass through to the handler, then add rate-limit headers
        response = handler(req)

        push!(response.headers, "X-RateLimit-Remaining" => string(remaining))
        push!(response.headers, "X-RateLimit-Limit"     => string(DEFAULT_CONFIG.max_requests))

        return response
    end
end

end # module RateLimit
