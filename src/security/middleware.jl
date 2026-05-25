"""
Security middleware for the Rural Hospital Economics Simulator.

Provides two Genie-compatible middleware functions:
- `auth_middleware` — session validation + RBAC enforcement
- `security_headers_middleware` — adds defensive HTTP headers to every response
"""
module SecurityMiddleware

using Genie, Genie.Requests, Genie.Responses, HTTP, JSON3, Dates

# Import sibling security modules
include("auth.jl")
include("rbac.jl")

using .Auth
using .RBAC

export auth_middleware, security_headers_middleware

# ---------------------------------------------------------------------------
# Authentication + Authorization middleware
# ---------------------------------------------------------------------------

"""
    auth_middleware(handler)

Returns a wrapped handler function that enforces authentication and
role-based access control on every incoming request.

Flow:
1. Extract the request path.
2. If the route is public, pass through to `handler`.
3. Extract the Bearer token from headers or session cookie.
4. Validate the session in `SESSION_STORE`.
5. If no valid session exists, return a **401 Unauthorized** JSON response.
6. Check RBAC permissions for the route (considering HTTP method).
7. If the user's role is insufficient, return a **403 Forbidden** JSON response.
8. Otherwise, call `handler` normally.
"""
function auth_middleware(handler)
    return function(req)
        # 1. Determine request path
        path = try
            String(req.target)
        catch
            try
                String(HTTP.URI(req.target).path)
            catch
                "/"
            end
        end

        # Strip query string if present
        query_idx = findfirst('?', path)
        if query_idx !== nothing
            path = path[1:query_idx-1]
        end

        # 2. Public routes bypass auth entirely
        if RBAC.is_public_route(path)
            return handler(req)
        end

        # 3. Extract token from Authorization header or Cookie
        headers_dict = Dict{String, String}()
        try
            for (k, v) in req.headers
                headers_dict[String(k)] = String(v)
            end
        catch
            # If headers aren't iterable, try Genie's API
            for name in ["Authorization", "authorization", "Cookie", "cookie"]
                val = Genie.Requests.getheader(req, name, "")
                if val != ""
                    headers_dict[name] = val
                end
            end
        end

        token = Auth.extract_token(headers_dict)

        # 4. Validate session
        if token === nothing
            # 5. No token → 401
            return HTTP.Response(401,
                ["Content-Type" => "application/json"],
                body = JSON3.write(Dict(
                    "status"  => "error",
                    "code"    => 401,
                    "message" => "Authentication required. Please provide a valid session token.",
                ))
            )
        end

        session = Auth.validate_session(token)
        if session === nothing
            # 5. Invalid or expired token → 401
            return HTTP.Response(401,
                ["Content-Type" => "application/json"],
                body = JSON3.write(Dict(
                    "status"  => "error",
                    "code"    => 401,
                    "message" => "Session expired or invalid. Please log in again.",
                ))
            )
        end

        # 6. Check RBAC permissions
        method = try
            String(req.method)
        catch
            "GET"
        end

        if !RBAC.check_route_access(path, method, session.role)
            # 7. Insufficient permissions → 403
            return HTTP.Response(403,
                ["Content-Type" => "application/json"],
                body = JSON3.write(Dict(
                    "status"  => "error",
                    "code"    => 403,
                    "message" => "Insufficient permissions. Your role '$(session.role)' cannot access this resource.",
                    "required_access" => path,
                ))
            )
        end

        # 8. All checks passed — call the actual handler
        return handler(req)
    end
end

# ---------------------------------------------------------------------------
# Security headers middleware
# ---------------------------------------------------------------------------

"""
    security_headers_middleware(handler)

Returns a wrapped handler that appends standard security headers to every
HTTP response. For API responses (paths starting with `/api/`), a
`Cache-Control: no-store` header is also added to prevent caching of
sensitive data.

Headers added:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Cache-Control: no-store` (API responses only)
"""
function security_headers_middleware(handler)
    return function(req)
        response = handler(req)

        # Ensure we have a mutable headers collection
        security_headers = [
            "X-Content-Type-Options"    => "nosniff",
            "X-Frame-Options"           => "DENY",
            "X-XSS-Protection"          => "1; mode=block",
            "Strict-Transport-Security" => "max-age=31536000; includeSubDomains",
            "Content-Security-Policy"   => "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'",
            "Referrer-Policy"           => "strict-origin-when-cross-origin",
        ]

        # Add Cache-Control: no-store for API responses
        path = try
            String(req.target)
        catch
            "/"
        end

        query_idx = findfirst('?', path)
        if query_idx !== nothing
            path = path[1:query_idx-1]
        end

        if startswith(path, "/api/")
            push!(security_headers, "Cache-Control" => "no-store")
        end

        # Append security headers to the response
        for (name, value) in security_headers
            push!(response.headers, name => value)
        end

        return response
    end
end

end # module SecurityMiddleware
