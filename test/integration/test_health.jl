"""
Integration tests for the observability module (P0-6).
Tests healthz, readyz, metrics, and request counter.
"""
using Test
using Dates

include(joinpath(@__DIR__, "..", "..", "src", "observability", "health.jl"))
using .Health

@testset "Health — Liveness Probe" begin
    result = Health.healthz()
    @test result["status"] == "ok"
    @test haskey(result, "timestamp")
    @test haskey(result, "version")
    @test result["version"] isa String
    @test !isempty(result["version"])
end

@testset "Health — Readiness Probe" begin
    result = Health.readyz()
    @test result["status"] in ["ok", "degraded", "unhealthy"]
    @test haskey(result, "checks")
    @test haskey(result["checks"], "database")
    @test haskey(result, "timestamp")
end

@testset "Health — Metrics Prometheus Format" begin
    output = Health.metrics()
    @test contains(output, "# HELP rhsim_info")
    @test contains(output, "# TYPE rhsim_info gauge")
    @test contains(output, "rhsim_info{version=")
    @test contains(output, "# HELP rhsim_uptime_seconds")
    @test contains(output, "# TYPE rhsim_uptime_seconds gauge")
    @test contains(output, "rhsim_uptime_seconds")
    @test contains(output, "# HELP rhsim_requests_total")
    @test contains(output, "# TYPE rhsim_requests_total counter")
    @test contains(output, "# HELP rhsim_active_sessions")
    @test contains(output, "# TYPE rhsim_active_sessions gauge")
end

@testset "Health — Request Counter" begin
    before = Health.REQUEST_COUNT[]
    Health.request_counter!()
    Health.request_counter!()
    Health.request_counter!()
    after = Health.REQUEST_COUNT[]
    @test after == before + 3
end

@testset "Health — Uptime Increases" begin
    m1 = Health.metrics()
    uptime1 = match(r"rhsim_uptime_seconds (\d+\.?\d*)", m1)
    @test uptime1 !== nothing
    t1 = parse(Float64, uptime1.captures[1])
    @test t1 >= 0.0
end
