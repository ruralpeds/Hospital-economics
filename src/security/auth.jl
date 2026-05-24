"""
Authentication module for the Rural Hospital Economics Simulator.

Provides session-based authentication with SHA-256 password hashing,
token management, and session lifecycle operations.
"""
module Auth

using Dates, Random, SHA

export SessionInfo, SESSION_STORE,
       hash_password, verify_password,
       create_session, validate_session, destroy_session,
       cleanup_expired_sessions!, extract_token

"""
Represents an active user session with role and organization context.
"""
struct SessionInfo
    user_id::Int
    email::String
    role::String
    organization_id::Int
    expires_at::DateTime
    token::String
end

"""Global store of active sessions, keyed by token string."""
const SESSION_STORE = Dict{String, SessionInfo}()

# ---------------------------------------------------------------------------
# Password hashing
# ---------------------------------------------------------------------------

"""Salt prefix used for password hashing. In production, use a per-user random salt."""
const _SALT_PREFIX = "HospEcon2024_"

"""
    hash_password(password::String)::String

Hash a password using SHA-256 with a fixed salt prefix.
Returns the hex-encoded digest string.
"""
function hash_password(password::String)::String
    salted = _SALT_PREFIX * password
    return bytes2hex(sha256(salted))
end

"""
    verify_password(password::String, hash::String)::Bool

Verify that a plaintext password matches the given SHA-256 hash.
"""
function verify_password(password::String, hash::String)::Bool
    return hash_password(password) == hash
end

# ---------------------------------------------------------------------------
# Session management
# ---------------------------------------------------------------------------

"""
    create_session(user_id::Int, email::String, role::String, org_id::Int;
                   ttl_hours::Int=8)::SessionInfo

Create a new authenticated session with a cryptographically random token.
The session is stored in `SESSION_STORE` and expires after `ttl_hours`.
"""
function create_session(user_id::Int, email::String, role::String, org_id::Int;
                        ttl_hours::Int=8)::SessionInfo
    token = bytes2hex(rand(UInt8, 32))  # 256-bit random token
    expires_at = now(UTC) + Hour(ttl_hours)
    session = SessionInfo(user_id, email, role, org_id, expires_at, token)
    SESSION_STORE[token] = session
    return session
end

"""
    validate_session(token::String)::Union{SessionInfo, Nothing}

Look up a session by token. Returns the `SessionInfo` if the token exists and
has not expired; otherwise removes any expired entry and returns `nothing`.
"""
function validate_session(token::String)::Union{SessionInfo, Nothing}
    session = get(SESSION_STORE, token, nothing)
    if session === nothing
        return nothing
    end
    if now(UTC) > session.expires_at
        delete!(SESSION_STORE, token)
        return nothing
    end
    return session
end

"""
    destroy_session(token::String)::Bool

Remove a session from the store. Returns `true` if the session existed
and was removed, `false` otherwise.
"""
function destroy_session(token::String)::Bool
    if haskey(SESSION_STORE, token)
        delete!(SESSION_STORE, token)
        return true
    end
    return false
end

"""
    cleanup_expired_sessions!()

Remove all expired sessions from the global `SESSION_STORE`.
"""
function cleanup_expired_sessions!()
    current_time = now(UTC)
    expired_tokens = [token for (token, session) in SESSION_STORE
                      if current_time > session.expires_at]
    for token in expired_tokens
        delete!(SESSION_STORE, token)
    end
    return length(expired_tokens)
end

# ---------------------------------------------------------------------------
# Token extraction from HTTP headers
# ---------------------------------------------------------------------------

"""
    extract_token(headers::Dict)::Union{String, Nothing}

Extract an authentication token from HTTP headers. Checks for:
1. A Bearer token in the `Authorization` header
2. A session token in the `Cookie` header (key: `session_token`)

Returns the token string or `nothing` if no valid token is found.
"""
function extract_token(headers::Dict)::Union{String, Nothing}
    # Check Authorization header for Bearer token
    auth_header = get(headers, "Authorization", get(headers, "authorization", nothing))
    if auth_header !== nothing
        m = match(r"^Bearer\s+(.+)$"i, strip(String(auth_header)))
        if m !== nothing
            return strip(String(m.captures[1]))
        end
    end

    # Fallback: check Cookie header for session_token
    cookie_header = get(headers, "Cookie", get(headers, "cookie", nothing))
    if cookie_header !== nothing
        cookie_str = String(cookie_header)
        for part in split(cookie_str, ";")
            kv = strip(part)
            if startswith(kv, "session_token=")
                return strip(replace(kv, "session_token=" => ""; count=1))
            end
        end
    end

    return nothing
end

end # module Auth
