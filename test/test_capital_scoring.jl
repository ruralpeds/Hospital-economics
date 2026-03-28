# ============================================================================
# Tests for Capital Replacement Scoring (src/optimization/capital_scoring.jl)
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "optimization", "capital_scoring.jl"))

@testset "Capital Scoring" begin

    # Reusable fixtures
    projects = [
        CapitalRequest(project_name="Roof Repair", category=:safety,
            estimated_cost=500_000.0, safety_compliance_score=0.9,
            revenue_impact_annual=0.0, failure_risk_score=0.85,
            strategic_alignment_score=0.3, efficiency_gain_annual=10_000.0,
            useful_life_years=20),
        CapitalRequest(project_name="MRI Machine", category=:revenue,
            estimated_cost=2_000_000.0, safety_compliance_score=0.2,
            revenue_impact_annual=800_000.0, failure_risk_score=0.3,
            strategic_alignment_score=0.8, efficiency_gain_annual=50_000.0,
            useful_life_years=10),
        CapitalRequest(project_name="HVAC Upgrade", category=:efficiency,
            estimated_cost=300_000.0, safety_compliance_score=0.4,
            revenue_impact_annual=0.0, failure_risk_score=0.6,
            strategic_alignment_score=0.5, efficiency_gain_annual=100_000.0,
            useful_life_years=15),
    ]

    @testset "struct construction" begin
        p = CapitalRequest(project_name="Test", estimated_cost=100.0)
        @test p.category == :maintenance
        @test p.safety_compliance_score == 0.0
        @test p.useful_life_years == 10
    end

    @testset "score_capital_projects" begin
        scored = score_capital_projects(projects)
        @test length(scored) == 3
        # Each result has the right fields
        @test haskey(scored[1], :project_name)
        @test haskey(scored[1], :weighted_score)
        @test haskey(scored[1], :rank)
        # Rank 1 should have highest score
        rank1 = filter(s -> s.rank == 1, scored)[1]
        rank3 = filter(s -> s.rank == 3, scored)[1]
        @test rank1.weighted_score >= rank3.weighted_score
        # Roof Repair has high safety score (0.9 * 0.30 weight = 0.27 from safety alone)
        roof = filter(s -> s.project_name == "Roof Repair", scored)[1]
        @test roof.weighted_score > 0.3
    end

    @testset "select_within_budget" begin
        result = select_within_budget(projects, 1_000_000.0)
        # Budget is 1M: can afford Roof (500k) + HVAC (300k) = 800k, but not MRI (2M)
        @test "MRI Machine" ∉ result.selected_projects
        @test result.total_cost_selected <= 1_000_000.0
        @test result.budget_utilization <= 1.0
        @test result.budget_utilization > 0.0
        @test length(result.scores) == 3
        @test length(result.rankings) == 3
    end

    @testset "select_within_budget — large budget selects all" begin
        result = select_within_budget(projects, 10_000_000.0)
        @test length(result.selected_projects) == 3
        @test result.total_cost_selected ≈ 2_800_000.0
    end

    @testset "select_within_budget — zero budget" begin
        result = select_within_budget(projects, 0.0)
        @test isempty(result.selected_projects)
        @test result.total_cost_selected == 0.0
        @test result.budget_utilization == 0.0
    end

    @testset "replacement_priority_report" begin
        report = replacement_priority_report(projects)
        @test length(report) == 3
        # Should be sorted by failure_risk descending
        @test report[1].failure_risk_score >= report[2].failure_risk_score
        @test report[2].failure_risk_score >= report[3].failure_risk_score
        # Roof Repair (0.85) should be critical
        @test report[1].project_name == "Roof Repair"
        @test report[1].urgency_tier == :critical
        # HVAC (0.6) should be high
        hvac = filter(r -> r.project_name == "HVAC Upgrade", report)[1]
        @test hvac.urgency_tier == :high
        # MRI (0.3) should be low
        mri = filter(r -> r.project_name == "MRI Machine", report)[1]
        @test mri.urgency_tier == :low
    end

    @testset "edge cases" begin
        # Empty projects
        @test score_capital_projects(CapitalRequest[]) == NamedTuple[]
        report = replacement_priority_report(CapitalRequest[])
        @test isempty(report)

        # Single project
        single = [projects[1]]
        scored = score_capital_projects(single)
        @test scored[1].rank == 1
    end
end
