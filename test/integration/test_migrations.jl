"""
Integration tests for database migrations (P0-3, P0-4).
Validates migration modules load and define up/down functions.
"""
using Test

@testset "Migrations — Module Structure" begin
    migrations_dir = joinpath(@__DIR__, "..", "..", "app", "db", "migrations")

    expected = [
        "001_create_organizations.jl",
        "002_create_users.jl",
        "003_create_hospitals.jl",
        "004_create_fiscal_years.jl",
        "005_create_scenarios.jl",
        "006_create_departments_and_staff.jl",
        "007_create_capital_and_risk.jl",
        "008_create_streaming_tables.jl",
        "009_create_audit_logs.jl",
        "010_create_sessions.jl",
        "011_create_hypertables.jl",
    ]

    for f in expected
        @test isfile(joinpath(migrations_dir, f)) "Missing migration: $f"
    end
end

@testset "Migrations — Audit Logs (009)" begin
    m = include(joinpath(@__DIR__, "..", "..", "app", "db", "migrations", "009_create_audit_logs.jl"))
    @test isdefined(m, :up)
    @test isdefined(m, :down)
end

@testset "Migrations — Sessions (010)" begin
    m = include(joinpath(@__DIR__, "..", "..", "app", "db", "migrations", "010_create_sessions.jl"))
    @test isdefined(m, :up)
    @test isdefined(m, :down)
end

@testset "DB Config — Initializer" begin
    db_jl = joinpath(@__DIR__, "..", "..", "app", "config", "initializers", "db.jl")
    @test isfile(db_jl)
    include(db_jl)
    config = db_config()
    @test config isa Dict
    @test config["adapter"] == "PostgreSQL"
    @test config["host"] isa String
    @test config["port"] isa Int
    @test config["pool_size"] isa Int
    @test config["pool_size"] >= 1
end
