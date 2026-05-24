"""
Role-Based Access Control (RBAC) module for the Rural Hospital Economics Simulator.

Defines a role hierarchy (admin > analyst > viewer), route-level permission
mappings, and public routes that bypass authentication entirely.
"""
module RBAC

export ROLE_HIERARCHY, Permission, ROUTE_PERMISSIONS, PUBLIC_ROUTES,
       has_permission, check_route_access, is_public_route

# ---------------------------------------------------------------------------
# Role hierarchy — higher number means more privilege
# ---------------------------------------------------------------------------

"""Role hierarchy mapping: admin (3) > analyst (2) > viewer (1)."""
const ROLE_HIERARCHY = Dict{String, Int}(
    "admin"   => 3,
    "analyst" => 2,
    "viewer"  => 1,
)

# ---------------------------------------------------------------------------
# Permission struct
# ---------------------------------------------------------------------------

"""
Describes the minimum role required to access a resource.
"""
struct Permission
    resource::String
    min_role::String
end

# ---------------------------------------------------------------------------
# Route permissions — patterns mapped to minimum required roles
# ---------------------------------------------------------------------------

"""
Route permission definitions. Keys are route pattern prefixes or exact paths;
values are the `Permission` describing the minimum role.

Convention:
- API write endpoints (POST /api/*) require at least "analyst"
- Admin-only pages (/audit, /database, /systems) require "admin"
- All other page routes require at least "viewer"
"""
const ROUTE_PERMISSIONS = Dict{String, Permission}(
    # ── Admin routes ──────────────────────────────────────────────────────
    "/audit"                => Permission("/audit",    "admin"),
    "/database"             => Permission("/database", "admin"),
    "/systems"              => Permission("/systems",  "admin"),

    # ── API write endpoints (POST) — require analyst ──────────────────────
    "POST /api/simulate"    => Permission("/api/simulate",    "analyst"),
    "POST /api/optimize"    => Permission("/api/optimize",    "analyst"),
    "POST /api/risk"        => Permission("/api/risk",        "analyst"),
    "POST /api/conversion"  => Permission("/api/conversion",  "analyst"),
    "POST /api/analytics"   => Permission("/api/analytics",   "analyst"),
    "POST /api/import"      => Permission("/api/import",      "analyst"),
    "POST /api/export"      => Permission("/api/export",      "analyst"),
    "POST /api/data"        => Permission("/api/data",        "analyst"),
    "POST /api/ingest"      => Permission("/api/ingest",      "analyst"),
    "POST /api/prepare"     => Permission("/api/prepare",     "analyst"),
    "POST /api/cohorts"     => Permission("/api/cohorts",     "analyst"),
    "POST /api/cost-analysis" => Permission("/api/cost-analysis", "analyst"),
    "POST /api/revenue"     => Permission("/api/revenue",     "analyst"),
    "POST /api/profitability" => Permission("/api/profitability", "analyst"),
    "POST /api/quality"     => Permission("/api/quality",     "analyst"),
    "POST /api/stats"       => Permission("/api/stats",       "analyst"),
    "POST /api/regression"  => Permission("/api/regression",  "analyst"),
    "POST /api/causal"      => Permission("/api/causal",      "analyst"),
    "POST /api/cea"         => Permission("/api/cea",         "analyst"),
    "POST /api/cba"         => Permission("/api/cba",         "analyst"),
    "POST /api/comparative" => Permission("/api/comparative", "analyst"),
    "POST /api/visualize"   => Permission("/api/visualize",   "analyst"),
    "POST /api/reports"     => Permission("/api/reports",     "analyst"),
    "POST /api/database"    => Permission("/api/database",    "analyst"),
    "POST /api/ml"          => Permission("/api/ml",          "analyst"),
    "POST /api/systems"     => Permission("/api/systems",     "analyst"),
    "POST /api/scenario"    => Permission("/api/scenario",    "analyst"),
    "POST /api/fn"          => Permission("/api/fn",          "analyst"),
    "POST /api/audit"       => Permission("/api/audit",       "admin"),
    "POST /api/bugreport"   => Permission("/api/bugreport",   "viewer"),
)

# ---------------------------------------------------------------------------
# Public routes — no authentication required
# ---------------------------------------------------------------------------

"""Routes that are accessible without any authentication."""
const PUBLIC_ROUTES = Set{String}([
    "/login",
    "/api/auth/login",
    "/api/auth/logout",
    "/healthz",
    "/readyz",
    "/metrics",
])

# ---------------------------------------------------------------------------
# Permission checking functions
# ---------------------------------------------------------------------------

"""
    has_permission(role::String, required_role::String)::Bool

Check whether `role` has at least the privilege level of `required_role`
according to `ROLE_HIERARCHY`. Unknown roles are treated as having no privilege.
"""
function has_permission(role::String, required_role::String)::Bool
    user_level = get(ROLE_HIERARCHY, role, 0)
    required_level = get(ROLE_HIERARCHY, required_role, 0)
    return user_level >= required_level
end

"""
    check_route_access(route::String, role::String)::Bool

Determine whether a user with the given `role` can access the specified `route`.

Matching logic:
1. Public routes always return `true`.
2. Exact match in `ROUTE_PERMISSIONS` is checked first.
3. Prefix-based matching is used for API write endpoints (keyed as "POST /api/...").
4. Any route not explicitly listed defaults to requiring "viewer".
"""
function check_route_access(route::String, role::String)::Bool
    # Public routes are always accessible
    if is_public_route(route)
        return true
    end

    # Exact match (page routes like /audit, /database, /systems)
    if haskey(ROUTE_PERMISSIONS, route)
        perm = ROUTE_PERMISSIONS[route]
        return has_permission(role, perm.min_role)
    end

    # Default: page routes require at least "viewer"
    return has_permission(role, "viewer")
end

"""
    check_route_access(route::String, method::String, role::String)::Bool

Overload that also considers HTTP method for API endpoints.
POST requests to /api/* paths are matched against "POST /api/..." permission keys.
"""
function check_route_access(route::String, method::String, role::String)::Bool
    if is_public_route(route)
        return true
    end

    # For POST requests, check method-qualified permission keys
    if uppercase(method) == "POST" && startswith(route, "/api/")
        # Try prefix matching: "POST /api/simulate" matches "/api/simulate/deterministic"
        for (key, perm) in ROUTE_PERMISSIONS
            if startswith(key, "POST ")
                pattern = key[6:end]  # strip "POST " prefix
                if startswith(route, pattern)
                    return has_permission(role, perm.min_role)
                end
            end
        end
    end

    # Exact match for page routes
    if haskey(ROUTE_PERMISSIONS, route)
        perm = ROUTE_PERMISSIONS[route]
        return has_permission(role, perm.min_role)
    end

    # Default: require viewer
    return has_permission(role, "viewer")
end

"""
    is_public_route(route::String)::Bool

Check whether a route is in the `PUBLIC_ROUTES` set and thus requires no
authentication.
"""
function is_public_route(route::String)::Bool
    return route in PUBLIC_ROUTES
end

end # module RBAC
