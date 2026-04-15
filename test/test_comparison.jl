# ============================================================================
# Tests for scenario comparison analysis
# ============================================================================

using Test
using Dates
using Statistics

include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "scenarios.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "results.jl"))
include(joinpath(@__DIR__, "..", "src", "analysis", "comparison.jl"))

@testset "Scenario Comparison" begin

    @testset "ScenarioComparison construction" begin
        cmp = ScenarioComparison(
            ["Baseline", "Expansion"],
            ["operating_margin", "total_revenue"],
            [0.02 15e6; 0.05 12e6],
            1,
        )
        @test length(cmp.scenario_names) == 2
        @test length(cmp.metric_names) == 2
        @test cmp.base_scenario_idx == 1
        @test cmp.values[1, 1] ≈ 0.02
        @test cmp.values[2, 2] ≈ 12e6
    end

    @testset "ScenarioComparison validation" begin
        # Mismatched scenario names
        @test_throws ErrorException ScenarioComparison(
            ["A"], ["m1", "m2"], [1.0 2.0; 3.0 4.0], 1,
        )
        # Bad base index
        @test_throws ErrorException ScenarioComparison(
            ["A", "B"], ["m1"], [1.0; 2.0;;], 3,
        )
    end

    @testset "rank_scenarios equal weights" begin
        # Scenario B is better on both metrics
        cmp = ScenarioComparison(
            ["A", "B"],
            ["margin", "revenue"],
            [0.01 100.0; 0.05 200.0],
            1,
        )
        ranking = rank_scenarios(cmp)
        @test ranking[1] == 2  # B is best
        @test ranking[2] == 1
    end

    @testset "rank_scenarios with weights" begin
        # A has better margin, B has better revenue
        cmp = ScenarioComparison(
            ["A", "B"],
            ["margin", "revenue"],
            [0.10 100.0; 0.01 500.0],
            1,
        )
        # Weight margin much higher
        ranking = rank_scenarios(cmp; weights=Dict("margin" => 0.9, "revenue" => 0.1))
        @test ranking[1] == 1  # A wins on margin
    end

    @testset "rank_scenarios single scenario" begin
        cmp = ScenarioComparison(["Only"], ["m1"], [5.0;;], 1)
        @test rank_scenarios(cmp) == [1]
    end

    @testset "scenario_delta calculation" begin
        cmp = ScenarioComparison(
            ["Baseline", "Alternative"],
            ["margin", "revenue"],
            [0.02 1000.0; 0.05 1200.0],
            1,
        )
        delta = scenario_delta(cmp, 2)
        @test delta["margin"] ≈ 0.03
        @test delta["revenue"] ≈ 200.0
    end

    @testset "scenario_delta base vs itself is zero" begin
        cmp = ScenarioComparison(
            ["Base", "Other"],
            ["metric"],
            [10.0; 20.0;;],
            1,
        )
        delta = scenario_delta(cmp, 1)
        @test delta["metric"] ≈ 0.0
    end

    @testset "scenario_delta out of range" begin
        cmp = ScenarioComparison(["A"], ["m"], [1.0;;], 1)
        @test_throws ErrorException scenario_delta(cmp, 2)
    end

    @testset "compare_scenarios with MonteCarloResult" begin
        r1 = MonteCarloResult(trial_id=1, final_year_margin=0.02,
                              net_revenues=[10e6], cash_on_hand_days=[45.0])
        r2 = MonteCarloResult(trial_id=2, final_year_margin=0.05,
                              net_revenues=[12e6], cash_on_hand_days=[60.0])
        cmp = compare_scenarios([r1, r2]; names=["A", "B"])
        @test cmp.values[2, 1] ≈ 0.05  # operating_margin for B
    end
end
