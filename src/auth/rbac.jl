"""
    rbac.jl

Role-Based Access Control (RBAC) for healthcare data authorization.

Implements Cedar-style policy evaluation with:
- Role definitions for healthcare personas (admin, CFO, CQO, analyst, auditor, clinician, viewer)
- Permission mappings per resource type and action
- Tenant isolation enforcement for multi-tenant deployments
- Authorization decisions with deny-reason audit trail

Based on cah-modeling ABAC policy engine, adapted for Julia.
"""

using Dates

# ============================================================================
# ROLES & PERMISSIONS
# ============================================================================

"""
Valid roles for healthcare RBAC:
- `:admin` — full access to all resources and actions
- `:cfo` — read/write financial data, read quality data
- `:cqo` — read/write quality data, read financial data
- `:analyst` — read financial/quality, run simulations
- `:auditor` — read all resources, read audit logs
- `:clinician` — read quality, write clinical data
- `:viewer` — read-only access to permitted resources
"""
const VALID_ROLES = [:admin, :cfo, :cqo, :analyst, :auditor, :clinician, :viewer]

"""
    Permission

A single permission granting access to a resource type for a specific action.

# Fields
- `resource::Symbol`: Resource category (e.g. `:financial`, `:quality`, `:clinical`, `:audit`, `:simulation`, `:all`)
- `action::Symbol`: Permitted action (e.g. `:read`, `:write`, `:delete`, `:execute`, `:admin`)
"""
struct Permission
    resource::Symbol
    action::Symbol
end

"""
    Principal

Authenticated user or service principal for authorization decisions.

# Fields
- `user_id::String`: Unique user identifier
- `tenant_id::String`: Tenant/organization identifier for isolation
- `roles::Vector{Symbol}`: Assigned roles from `VALID_ROLES`
- `attributes::Dict{String,String}`: Additional attributes (email, department, etc.)
"""
struct Principal
    user_id::String
    tenant_id::String
    roles::Vector{Symbol}
    attributes::Dict{String,String}

    function Principal(user_id::String, tenant_id::String, roles::Vector{Symbol};
                       attributes::Dict{String,String} = Dict{String,String}())
        for r in roles
            if r ∉ VALID_ROLES
                error("Invalid role: $r. Valid roles: $VALID_ROLES")
            end
        end
        new(user_id, tenant_id, roles, attributes)
    end
end

"""
    AuthorizationDecision

Result of an authorization check.

# Fields
- `decision::Symbol`: `:allow` or `:deny`
- `reason::String`: Explanation (empty for allow, descriptive for deny)
"""
struct AuthorizationDecision
    decision::Symbol
    reason::String
end

"""
    AuthorizationPolicy

Maps roles to their permitted actions on resource types.

# Fields
- `role_permissions::Dict{Symbol, Vector{Permission}}`: Role-to-permissions mapping
"""
struct AuthorizationPolicy
    role_permissions::Dict{Symbol, Vector{Permission}}
end

# ============================================================================
# DEFAULT POLICY
# ============================================================================

"""
    default_policy()::AuthorizationPolicy

Return the standard healthcare RBAC policy with role-permission mappings:

| Role       | Financial | Quality   | Clinical | Audit | Simulation | Admin |
|------------|-----------|-----------|----------|-------|------------|-------|
| admin      | all       | all       | all      | all   | all        | all   |
| cfo        | r/w       | read      | —        | —     | —          | —     |
| cqo        | read      | r/w       | —        | —     | —          | —     |
| analyst    | read      | read      | —        | —     | execute    | —     |
| auditor    | read      | read      | read     | read  | —          | —     |
| clinician  | —         | read      | r/w      | —     | —          | —     |
| viewer     | read      | read      | read     | —     | —          | —     |
"""
function default_policy()::AuthorizationPolicy
    rp = Dict{Symbol, Vector{Permission}}()

    # Admin: all permissions on all resources
    rp[:admin] = [
        Permission(:all, :read),
        Permission(:all, :write),
        Permission(:all, :delete),
        Permission(:all, :execute),
        Permission(:all, :admin),
    ]

    # CFO: read/write financial, read quality
    rp[:cfo] = [
        Permission(:financial, :read),
        Permission(:financial, :write),
        Permission(:quality, :read),
    ]

    # CQO: read/write quality, read financial
    rp[:cqo] = [
        Permission(:quality, :read),
        Permission(:quality, :write),
        Permission(:financial, :read),
    ]

    # Analyst: read financial, read quality, run simulations
    rp[:analyst] = [
        Permission(:financial, :read),
        Permission(:quality, :read),
        Permission(:simulation, :execute),
    ]

    # Auditor: read all, read audit logs
    rp[:auditor] = [
        Permission(:financial, :read),
        Permission(:quality, :read),
        Permission(:clinical, :read),
        Permission(:audit, :read),
    ]

    # Clinician: read quality, write clinical
    rp[:clinician] = [
        Permission(:quality, :read),
        Permission(:clinical, :read),
        Permission(:clinical, :write),
    ]

    # Viewer: read only
    rp[:viewer] = [
        Permission(:financial, :read),
        Permission(:quality, :read),
        Permission(:clinical, :read),
    ]

    return AuthorizationPolicy(rp)
end

# ============================================================================
# AUTHORIZATION
# ============================================================================

"""
    authorize(principal::Principal, resource::Symbol, action::Symbol,
              policy::AuthorizationPolicy)::AuthorizationDecision

Check whether `principal` is permitted to perform `action` on `resource`.

Iterates through principal's roles and checks each role's permissions against
the requested resource/action pair. The `:all` resource wildcard grants access
to any resource.

Returns `AuthorizationDecision(:allow, "")` if any role grants access, otherwise
returns `AuthorizationDecision(:deny, reason)` with a descriptive denial reason.

# Arguments
- `principal::Principal`: The authenticated user
- `resource::Symbol`: Target resource type (`:financial`, `:quality`, `:clinical`, etc.)
- `action::Symbol`: Requested action (`:read`, `:write`, `:delete`, `:execute`, `:admin`)
- `policy::AuthorizationPolicy`: The RBAC policy to evaluate

# Returns
- `AuthorizationDecision`: Allow or deny with reason
"""
function authorize(principal::Principal, resource::Symbol, action::Symbol,
                   policy::AuthorizationPolicy)::AuthorizationDecision
    for role in principal.roles
        perms = get(policy.role_permissions, role, Permission[])
        for perm in perms
            # Check exact match or wildcard (:all matches any resource)
            resource_match = (perm.resource == resource) || (perm.resource == :all)
            action_match = (perm.action == action) || (perm.action == :admin)
            if resource_match && action_match
                return AuthorizationDecision(:allow, "")
            end
        end
    end

    roles_str = join(string.(principal.roles), ", ")
    return AuthorizationDecision(
        :deny,
        "Principal '$(principal.user_id)' with roles [$roles_str] " *
        "is not permitted to $(action) on $(resource)"
    )
end

"""
    check_tenant_isolation(principal::Principal, resource_tenant::String)::Bool

Verify that the principal's tenant matches the resource's tenant.

Admins bypass tenant isolation (cross-tenant access). All other roles
are restricted to their own tenant.

# Arguments
- `principal::Principal`: The authenticated user
- `resource_tenant::String`: Tenant ID of the resource being accessed

# Returns
- `true` if access is permitted (same tenant or admin), `false` otherwise
"""
function check_tenant_isolation(principal::Principal, resource_tenant::String)::Bool
    if principal.tenant_id == resource_tenant
        return true
    end
    # Admins can access across tenants
    if :admin in principal.roles
        return true
    end
    return false
end
