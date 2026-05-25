"""
Integration tests for the authentication and RBAC system (P0-1).
Tests session management, password hashing, role checks, and middleware behavior.
"""
using Test

include(joinpath(@__DIR__, "..", "..", "src", "security", "auth.jl"))
include(joinpath(@__DIR__, "..", "..", "src", "security", "rbac.jl"))

using .Auth
using .RBAC

@testset "Auth — Password Hashing" begin
    hash = Auth.hash_password("secure_password_123")
    @test !isempty(hash)
    @test Auth.verify_password("secure_password_123", hash)
    @test !Auth.verify_password("wrong_password", hash)
    @test !Auth.verify_password("", hash)

    hash2 = Auth.hash_password("secure_password_123")
    @test hash != hash2  # different salts
    @test Auth.verify_password("secure_password_123", hash2)
end

@testset "Auth — Session Management" begin
    empty!(Auth.SESSION_STORE)

    session = Auth.create_session(1, "admin@hospital.org", "admin", 1; ttl_hours=1)
    @test session.user_id == 1
    @test session.email == "admin@hospital.org"
    @test session.role == "admin"
    @test session.organization_id == 1
    @test !isempty(session.token)
    @test session.expires_at > Dates.now()
    @test haskey(Auth.SESSION_STORE, session.token)

    validated = Auth.validate_session(session.token)
    @test validated !== nothing
    @test validated.email == "admin@hospital.org"

    @test Auth.validate_session("nonexistent_token") === nothing

    @test Auth.destroy_session(session.token)
    @test !haskey(Auth.SESSION_STORE, session.token)
    @test Auth.validate_session(session.token) === nothing
    @test !Auth.destroy_session("already_gone")

    empty!(Auth.SESSION_STORE)
end

@testset "Auth — Token Extraction" begin
    headers_bearer = Dict("Authorization" => "Bearer abc123xyz")
    @test Auth.extract_token(headers_bearer) == "abc123xyz"

    headers_cookie = Dict("Cookie" => "session_token=cookievalue; other=val")
    @test Auth.extract_token(headers_cookie) == "cookievalue"

    @test Auth.extract_token(Dict{String,String}()) === nothing
    @test Auth.extract_token(Dict("Authorization" => "Basic abc")) === nothing
end

@testset "Auth — Expired Session Cleanup" begin
    empty!(Auth.SESSION_STORE)
    expired = Auth.SessionInfo(99, "old@test.com", "viewer", 1,
                               Dates.now() - Dates.Hour(1), "expired_token")
    Auth.SESSION_STORE["expired_token"] = expired

    active = Auth.create_session(2, "new@test.com", "analyst", 1; ttl_hours=8)

    @test Auth.validate_session("expired_token") === nothing
    Auth.cleanup_expired_sessions!()
    @test !haskey(Auth.SESSION_STORE, "expired_token")
    @test haskey(Auth.SESSION_STORE, active.token)

    empty!(Auth.SESSION_STORE)
end

@testset "RBAC — Role Hierarchy" begin
    @test RBAC.has_permission("admin", "admin")
    @test RBAC.has_permission("admin", "analyst")
    @test RBAC.has_permission("admin", "viewer")
    @test RBAC.has_permission("analyst", "analyst")
    @test RBAC.has_permission("analyst", "viewer")
    @test !RBAC.has_permission("analyst", "admin")
    @test RBAC.has_permission("viewer", "viewer")
    @test !RBAC.has_permission("viewer", "analyst")
    @test !RBAC.has_permission("viewer", "admin")
end

@testset "RBAC — Public Routes" begin
    @test RBAC.is_public_route("/login")
    @test RBAC.is_public_route("/api/auth/login")
    @test RBAC.is_public_route("/api/auth/logout")
    @test RBAC.is_public_route("/healthz")
    @test RBAC.is_public_route("/readyz")
    @test RBAC.is_public_route("/metrics")
    @test !RBAC.is_public_route("/dashboard")
    @test !RBAC.is_public_route("/api/simulate/deterministic")
end

@testset "RBAC — Route Access" begin
    @test RBAC.check_route_access("/dashboard", "viewer")
    @test RBAC.check_route_access("/dashboard", "analyst")
    @test RBAC.check_route_access("/dashboard", "admin")

    @test !RBAC.check_route_access("/audit", "viewer")
    @test !RBAC.check_route_access("/audit", "analyst")
    @test RBAC.check_route_access("/audit", "admin")

    @test !RBAC.check_route_access("/database", "viewer")
    @test RBAC.check_route_access("/database", "admin")

    @test !RBAC.check_route_access("/systems", "viewer")
    @test RBAC.check_route_access("/systems", "admin")
end
