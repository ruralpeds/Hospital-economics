# ============================================================================
# Tests for scenario comparison framework (simulation/scenarios.jl)
# ============================================================================

using Test
using Dates

include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "department.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "staffing.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "payer.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "financial.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "capital.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "hospital.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "scenarios.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "results.jl"))
include(joinpath(@__DIR__, "..", "src", "simulation", "deterministic.jl"))
include(joinpath(@__DIR__, "..", "src", "simulation", "des.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "sensitivity.jl"))
include(joinpath(@__DIR__, "..", "src", "analysis", "comparison.jl"))
include(joinpath(@__DIR__, "..", "src", "simulation", "scenarios.jl"))

@testset "Scenario Framework" begin

    @testset "SimulationScenario construction" begin
        des_params = DESParams()
        scenario = SimulationScenario(
            name        = "Test Scenario",
            description = "A test",
            hospital    = nothing,
            params      = des_params,
        )
        @test scenario.name == "Test Scenario"
        @test scenario.description == "A test"
        @test scenario.params isa DESParams
        @test scenario.policy === nothing
    end

    @testset "SimulationScenario with policy" begin
        pol = PolicyScenario(scenario_name="Test Policy")
        scenario = SimulationScenario(
            name     = "With Policy",
            hospital = nothing,
            params   = DESParams(),
            policy   = pol,
        )
        @test scenario.policy !== nothing
        @test scenario.policy.scenario_name == "Test Policy"
    end

    @testset "ScenarioSet validation - empty errors" begin
        @test_throws ErrorException ScenarioSet(SimulationScenario[])
    end

    @testset "ScenarioSet validation - bad index errors" begin
        s1 = SimulationScenario(name="S1", hospital=nothing, params=DESParams())
        @test_throws ErrorException ScenarioSet([s1], 0)
        @test_throws ErrorException ScenarioSet([s1], 2)
    end

    @testset "ScenarioSet length and iteration" begin
        s1 = SimulationScenario(name="S1", hospital=nothing, params=DESParams())
        s2 = SimulationScenario(name="S2", hospital=nothing, params=DESParams())
        ss = ScenarioSet([s1, s2], 1)
        @test length(ss) == 2
        @test ss[1].name == "S1"
        @test ss[2].name == "S2"
        names = [s.name for s in ss]
        @test names == ["S1", "S2"]
    end

    @testset "ScenarioSet default base index" begin
        s1 = SimulationScenario(name="S1", hospital=nothing, params=DESParams())
        ss = ScenarioSet([s1])
        @test ss.base_scenario_idx == 1
    end

    @testset "run_scenario_set with DES engine" begin
        s1 = SimulationScenario(name="Low", hospital=nothing, params=DESParams(mean_arrival_rate=1.0))
        s2 = SimulationScenario(name="High", hospital=nothing, params=DESParams(mean_arrival_rate=4.0))
        ss = ScenarioSet([s1, s2], 1)
        results = run_scenario_set(ss; engine=:des)
        @test length(results) == 2
        @test results[1] isa DESResult
        @test results[2] isa DESResult
    end
end
