"""
Secrets management module supporting multiple providers (env, AWS Secrets Manager, Vault).
Provides caching, rotation, and validation of required application secrets.
"""
module SecretsManager

export SecretConfig, get_secret, clear_cache!, rotate_secret!
export list_required_secrets, validate_secrets

using JSON3, Dates

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

"""
    SecretConfig

Configuration for the secrets provider.

- `provider`: Backend to use — "env" (default), "aws", or "vault"
- `region`: AWS region for the AWS Secrets Manager provider (default "us-east-1")
- `cache_ttl_seconds`: How long cached secrets remain valid (default 300)
"""
struct SecretConfig
    provider::String
    region::String
    cache_ttl_seconds::Int
end

SecretConfig(;
    provider::String = "env",
    region::String = "us-east-1",
    cache_ttl_seconds::Int = 300
) = SecretConfig(provider, region, cache_ttl_seconds)

# ---------------------------------------------------------------------------
# Cache
# ---------------------------------------------------------------------------

"""In-memory cache: key → (value, fetched_at)"""
const SECRET_CACHE = Dict{String, Tuple{Any, DateTime}}()

"""
    clear_cache!()

Remove all entries from the secrets cache.
"""
function clear_cache!()
    empty!(SECRET_CACHE)
    @info "SecretsManager: cache cleared"
    nothing
end

# ---------------------------------------------------------------------------
# Provider helpers
# ---------------------------------------------------------------------------

function _fetch_from_env(key::String)::Union{String, Nothing}
    return get(ENV, key, nothing)
end

function _fetch_from_aws(key::String, region::String)::Union{String, Nothing}
    cmd = `aws secretsmanager get-secret-value --secret-id $key --region $region --query SecretString --output text`
    try
        result = strip(read(cmd, String))
        if isempty(result)
            return nothing
        end
        return result
    catch e
        @warn "SecretsManager: AWS fetch failed for '$key'" exception = e
        return nothing
    end
end

function _fetch_from_vault(key::String)::Union{String, Nothing}
    cmd = `vault kv get -field=value $key`
    try
        result = strip(read(cmd, String))
        if isempty(result)
            return nothing
        end
        return result
    catch e
        @warn "SecretsManager: Vault fetch failed for '$key'" exception = e
        return nothing
    end
end

# ---------------------------------------------------------------------------
# Core API
# ---------------------------------------------------------------------------

"""
    get_secret(key::String, config::SecretConfig=SecretConfig())::String

Retrieve a secret by key from the configured provider.

Checks the in-memory cache first (respecting `cache_ttl_seconds`), then falls
back to the provider. Results are cached on successful retrieval.

Throws an error if the secret is not found.
"""
function get_secret(key::String, config::SecretConfig = SecretConfig())::String
    # 1. Check cache
    if haskey(SECRET_CACHE, key)
        value, fetched_at = SECRET_CACHE[key]
        age_seconds = Dates.value(Dates.Second(now() - fetched_at))
        if age_seconds < config.cache_ttl_seconds
            @debug "SecretsManager: cache hit for '$key' (age=$(age_seconds)s)"
            return value
        else
            @debug "SecretsManager: cache expired for '$key' (age=$(age_seconds)s, ttl=$(config.cache_ttl_seconds)s)"
            delete!(SECRET_CACHE, key)
        end
    end

    # 2. Fetch from provider
    result = if config.provider == "env"
        _fetch_from_env(key)
    elseif config.provider == "aws"
        _fetch_from_aws(key, config.region)
    elseif config.provider == "vault"
        _fetch_from_vault(key)
    else
        error("SecretsManager: unknown provider '$(config.provider)'. Supported: env, aws, vault")
    end

    # 3. Error if not found
    if result === nothing
        error("SecretsManager: secret '$key' not found via provider '$(config.provider)'")
    end

    # 4. Cache the result
    SECRET_CACHE[key] = (result, now())
    @debug "SecretsManager: cached secret '$key'"

    return result
end

# ---------------------------------------------------------------------------
# Rotation
# ---------------------------------------------------------------------------

"""
    rotate_secret!(key::String, new_value::String, config::SecretConfig=SecretConfig())

Rotate a secret to a new value.

- For the "aws" provider, updates the secret via `aws secretsmanager put-secret-value`.
- For the "vault" provider, updates via `vault kv put`.
- For the "env" provider, logs a warning (environment variable rotation requires a process restart).

Invalidates the cached entry for the key after rotation.
"""
function rotate_secret!(key::String, new_value::String, config::SecretConfig = SecretConfig())
    if config.provider == "aws"
        cmd = `aws secretsmanager put-secret-value --secret-id $key --secret-string $new_value --region $(config.region)`
        try
            run(cmd)
            @info "SecretsManager: rotated secret '$key' via AWS Secrets Manager"
        catch e
            error("SecretsManager: failed to rotate secret '$key' via AWS: $e")
        end
    elseif config.provider == "vault"
        cmd = `vault kv put $key value=$new_value`
        try
            run(cmd)
            @info "SecretsManager: rotated secret '$key' via Vault"
        catch e
            error("SecretsManager: failed to rotate secret '$key' via Vault: $e")
        end
    elseif config.provider == "env"
        @warn "SecretsManager: environment variable rotation for '$key' requires a process restart. Update the environment variable and restart the application."
    else
        error("SecretsManager: unknown provider '$(config.provider)'. Supported: env, aws, vault")
    end

    # Invalidate cache for this key
    delete!(SECRET_CACHE, key)
    nothing
end

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

"""
    list_required_secrets()::Vector{String}

Return the list of secrets required by the application.
"""
function list_required_secrets()::Vector{String}
    return [
        "RHSIM_ENCRYPTION_KEY",
        "DB_PASSWORD",
        "JWT_SECRET",
        "RHSIM_SESSION_SECRET",
    ]
end

"""
    validate_secrets(config::SecretConfig=SecretConfig())::Dict{String, Bool}

Check whether each required secret is available via the configured provider.
Returns a dictionary mapping secret name to availability (true/false).
"""
function validate_secrets(config::SecretConfig = SecretConfig())::Dict{String, Bool}
    results = Dict{String, Bool}()
    for key in list_required_secrets()
        available = try
            get_secret(key, config)
            true
        catch
            false
        end
        results[key] = available
    end

    missing_keys = [k for (k, v) in results if !v]
    if !isempty(missing_keys)
        @warn "SecretsManager: missing secrets" missing = missing_keys
    else
        @info "SecretsManager: all required secrets are available"
    end

    return results
end

end # module
