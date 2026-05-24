"""
CSRF (Cross-Site Request Forgery) protection module for the Rural Hospital
Economics Simulator.

Provides single-use CSRF token generation/validation and a Genie-compatible
middleware that enforces CSRF checks on state-changing HTTP methods.
"""
module CSRF

using Random, SHA, Dates, HTTP, JSON3

export CSRF_TOKENS, TOKEN_TTL_HOURS,
       generate_token, validate_token, cleanup_expired_tokens!,
       csrf_middleware

"""Global store of active CSRF tokens, mapping token string to expiry DateTime."""
const CSRF_TOKENS = Dict{String, DateTime}()

"""Time-to-live for CSRF tokens, in hours."""
const TOKEN_TTL_HOURS = 4

# ---------------------------------------------------------------------------
# Routes exempt from CSRF validation
# ---------------------------------------------------------------------------

"""Routes that bypass CSRF checks entirely."""
const CSRF_EXEMPT_PREFIXES = ["/api/auth/"]
const CSRF_EXEMPT_PATHS    = ["/healthz", "/readyz", "/metrics"]

# ---------------------------------------------------------------------------
# Token management
# ---------------------------------------------------------------------------

"""
    generate_token()::String

Generate a cryptographically random 32-byte hex CSRF token and store it in
`CSRF_TOKENS` with an expiry of `TOKEN_TTL_HOURS` hours from now.
"""
function generate_token()::String
    token = bytes2hex(rand(UInt8, 32))
    CSRF_TOKENS[token] = now(UTC) + Hour(TOKEN_TTL_HOURS)
    return token
end

"""
    validate_token(token::String)::Bool

Check that `token` exists in `CSRF_TOKENS` and has not expired.
On successful validation the token is removed (single-use).
Returns `true` if valid, `false` otherwise.
"""
function validate_token(token::String)::Bool
    if isempty(token)
        return false
    end

    expiry = get(CSRF_TOKENS, token, nothing)
    if expiry === nothing
        return false
    end

    if now(UTC) > expiry
        # Expired — remove and reject
        delete!(CSRF_TOKENS, token)
        return false
    end

    # Valid — consume the token (single use)
    delete!(CSRF_TOKENS, token)
    return true
end

"""
    cleanup_expired_tokens!()

Remove all expired tokens from the global `CSRF_TOKENS` store.
Returns the number of tokens removed.
"""
function cleanup_expired_tokens!()
    current_time = now(UTC)
    expired = [t for (t, exp) in CSRF_TOKENS if current_time > exp]
    for t in expired
        delete!(CSRF_TOKENS, t)
    end
    return length(expired)
end

# ---------------------------------------------------------------------------
# Helper: check if a route is CSRF-exempt
# ---------------------------------------------------------------------------

"""
    is_csrf_exempt(path::String)::Bool

Returns `true` if the given path should skip CSRF validation.
"""
function is_csrf_exempt(path::String)::Bool
    # Exact-match exempt paths
    if path in CSRF_EXEMPT_PATHS
        return true
    end
    # Prefix-match exempt routes
    for prefix in CSRF_EXEMPT_PREFIXES
        if startswith(path, prefix)
            return true
        end
    end
    return false
end

# ---------------------------------------------------------------------------
# Genie middleware
# ---------------------------------------------------------------------------

"""
    csrf_middleware(handler)

Genie-compatible middleware that enforces CSRF protection.

Flow:
1. For **GET / HEAD / OPTIONS** (safe methods):
   - Generate a fresh CSRF token.
   - Set it as the `X-CSRF-Token` response header and a `_csrf_token` cookie.
   - Pass through to the handler.
2. For **POST / PUT / DELETE / PATCH** (state-changing methods):
   - Skip CSRF validation for exempt routes (`/api/auth/*`, `/healthz`,
     `/readyz`, `/metrics`).
   - Skip CSRF validation when the request carries an `Authorization: Bearer`
     header (API token authentication).
   - Extract the CSRF token from the `X-CSRF-Token` request header or the
     `_csrf_token` form field.
   - If the token is missing or invalid, return a 403 Forbidden JSON response.
   - Otherwise, pass through to the handler.
"""
function csrf_middleware(handler)
    return function(req)
        # Determine HTTP method
        method = try
            uppercase(String(req.method))
        catch
            "GET"
        end

        # Determine request path
        path = try
            String(req.target)
        catch
            "/"
        end
        query_idx = findfirst('?', path)
        if query_idx !== nothing
            path = path[1:query_idx-1]
        end

        # Build a headers dictionary for easy look-up
        headers_dict = Dict{String, String}()
        try
            for (k, v) in req.headers
                headers_dict[lowercase(String(k))] = String(v)
            end
        catch
            # Ignore header parsing errors
        end

        # --- Safe methods: attach a fresh CSRF token to the response ---
        if method in ("GET", "HEAD", "OPTIONS")
            response = handler(req)

            token = generate_token()
            push!(response.headers, "X-CSRF-Token" => token)
            push!(response.headers, "Set-Cookie"   => "_csrf_token=$(token); Path=/; HttpOnly; SameSite=Strict")

            return response
        end

        # --- State-changing methods: validate the CSRF token ---

        # Skip for exempt routes
        if is_csrf_exempt(path)
            return handler(req)
        end

        # Skip when Authorization: Bearer header is present (API token auth)
        auth_header = get(headers_dict, "authorization", "")
        if occursin(r"^Bearer\s+"i, auth_header)
            return handler(req)
        end

        # Extract token from X-CSRF-Token header
        token = get(headers_dict, "x-csrf-token", "")

        # Fallback: try _csrf_token from the request body / form field
        if isempty(token)
            try
                body_str = String(copy(req.body))
                # Simple form-encoded parsing
                for part in split(body_str, "&")
                    kv = split(part, "="; limit=2)
                    if length(kv) == 2 && strip(String(kv[1])) == "_csrf_token"
                        token = strip(String(kv[2]))
                        break
                    end
                end
            catch
                # Body might not be form-encoded; token stays empty
            end
        end

        # Validate
        if isempty(token) || !validate_token(token)
            return HTTP.Response(403,
                ["Content-Type" => "application/json"],
                body = JSON3.write(Dict(
                    "status"  => "error",
                    "code"    => 403,
                    "message" => "CSRF token missing or invalid. Please include a valid CSRF token with your request.",
                ))
            )
        end

        return handler(req)
    end
end

end # module CSRF
