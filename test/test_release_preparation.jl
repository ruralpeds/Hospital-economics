# test/test_release_preparation.jl
# Tests for ReleasePreparation module

using Test
using DataFrames
using Dates

include("../src/release/ReleasePreparation.jl")
using .ReleasePreparation

@testset "ReleasePreparation Tests" begin

    # ==================== Checklist Items ====================
    @testset "Release Checklist Item" begin
        item = ReleaseChecklistItem(
            "Testing",
            "All tests passing",
            "complete",
            Date(2026, 4, 20),
            "211 tests total"
        )
        @test item.category == "Testing"
        @test item.status == "complete"
        @test item.target_date == Date(2026, 4, 20)
    end

    # ==================== Performance Benchmarks ====================
    @testset "Performance Benchmark - Excellent" begin
        bench = PerformanceBenchmark(
            "Single-state simulation",
            2.5,
            75.0,
            50,
            3,
            "excellent"
        )
        @test bench.simulation_type == "Single-state simulation"
        @test bench.execution_time_seconds == 2.5
        @test bench.performance_grade == "excellent"
        @test bench.hospitals_simulated == 50
    end

    @testset "Performance Benchmark - Good" begin
        bench = PerformanceBenchmark(
            "Multi-state simulation",
            15.0,
            200.0,
            200,
            5,
            "good"
        )
        @test bench.performance_grade == "good"
        @test bench.memory_usage_mb == 200.0
    end

    @testset "Performance Benchmark - Needs Improvement" begin
        bench = PerformanceBenchmark(
            "Full national simulation",
            180.0,
            1500.0,
            5000,
            10,
            "needs_improvement"
        )
        @test bench.performance_grade == "needs_improvement"
        @test bench.execution_time_seconds > 120.0
    end

    # ==================== Test Coverage Analysis ====================
    @testset "Test Coverage Analysis" begin
        test_counts = Dict(
            "phase_31" => 52,
            "phase_32" => 77,
            "phase_33" => 82
        )

        coverage = validate_test_coverage(test_counts)

        @test coverage.total_tests == 211
        @test coverage.passing_tests == 211
        @test coverage.coverage_percent ≈ 100.0
        @test haskey(coverage.phase_breakdown, "Phase 3.1 (MultiLevelPolicyCoupling)")
    end

    @testset "Test Coverage - Below Target" begin
        test_counts = Dict(
            "phase_31" => 40,
            "phase_32" => 60,
            "phase_33" => 50
        )

        coverage = validate_test_coverage(test_counts)

        @test coverage.total_tests == 150
        @test coverage.coverage_percent ≈ 100.0
        @test coverage.total_tests < 211
    end

    # ==================== Performance Benchmarking ====================
    @testset "Benchmark Performance - Single State" begin
        configs = [Dict(
            "type" => "Single-state simulation",
            "num_hospitals" => 50,
            "num_years" => 3
        )]

        benchmarks = benchmark_performance(configs)

        @test length(benchmarks) == 1
        @test benchmarks[1].simulation_type == "Single-state simulation"
        @test benchmarks[1].execution_time_seconds < 5.0  # Should meet goal
        @test benchmarks[1].performance_grade == "excellent"
    end

    @testset "Benchmark Performance - Multiple Configs" begin
        configs = [
            Dict("type" => "Small state", "num_hospitals" => 30, "num_years" => 2),
            Dict("type" => "Large state", "num_hospitals" => 150, "num_years" => 5),
            Dict("type" => "Regional", "num_hospitals" => 500, "num_years" => 10)
        ]

        benchmarks = benchmark_performance(configs)

        @test length(benchmarks) == 3
        @test benchmarks[1].execution_time_seconds < benchmarks[2].execution_time_seconds
        @test benchmarks[2].execution_time_seconds < benchmarks[3].execution_time_seconds
    end

    # ==================== Release Readiness ====================
    @testset "Release Readiness - Ready Status" begin
        coverage = TestCoverageAnalysis(
            211, 211, 100.0,
            Dict("Phase 3" => Dict("tests" => 211)),
            Dict()
        )

        benchmarks = [
            PerformanceBenchmark("Single-state", 2.5, 75.0, 50, 3, "excellent")
        ]

        metrics = ReleaseMetrics(
            coverage, benchmarks,
            5.2,      # MAPE
            0.95,     # Directional accuracy
            true,     # Documentation
            true      # Reproducibility
        )

        report = check_release_readiness(metrics)

        @test report.release_version == "v1.0"
        @test report.overall_status == "ready"
        @test length(report.checklist) == 10
        @test isempty(report.critical_issues)
    end

    @testset "Release Readiness - Blocked Status" begin
        coverage = TestCoverageAnalysis(
            100, 100, 80.0,  # Below 90% target
            Dict(),
            Dict()
        )

        benchmarks = [
            PerformanceBenchmark("Test", 1.0, 50.0, 10, 1, "excellent")
        ]

        metrics = ReleaseMetrics(
            coverage, benchmarks,
            12.5,     # MAPE > 10%
            0.92,
            true,
            true
        )

        report = check_release_readiness(metrics)

        @test report.overall_status == "blocked"
        @test !isempty(report.critical_issues)
    end

    @testset "Release Readiness - Pending Status" begin
        coverage = TestCoverageAnalysis(
            211, 211, 95.0,
            Dict(),
            Dict()
        )

        benchmarks = [
            PerformanceBenchmark("Test", 1.0, 50.0, 10, 1, "acceptable")
        ]

        metrics = ReleaseMetrics(
            coverage, benchmarks,
            4.5,      # Good MAPE
            0.88,     # Below 90% accuracy
            false,    # Documentation incomplete
            false     # Reproducibility not verified
        )

        report = check_release_readiness(metrics)

        @test report.overall_status == "pending"
        @test !isempty(report.warnings)
    end

    # ==================== Release Report Generation ====================
    @testset "Generate Release Report" begin
        coverage = TestCoverageAnalysis(
            211, 211, 100.0,
            Dict(),
            Dict()
        )

        benchmarks = [
            PerformanceBenchmark("Single-state", 2.5, 75.0, 50, 3, "excellent"),
            PerformanceBenchmark("Multi-state", 12.0, 150.0, 200, 5, "good")
        ]

        metrics = ReleaseMetrics(
            coverage, benchmarks,
            5.2, 0.95, true, true
        )

        report = check_release_readiness(metrics)
        formatted = generate_release_report(report)

        @test contains(formatted, "v1.0")
        @test contains(formatted, "READY FOR v1.0 RELEASE")
        @test contains(formatted, "211")
        @test contains(formatted, "52")
        @test contains(formatted, "77")
        @test contains(formatted, "82")
    end

    @testset "Release Report - Blocked Scenario" begin
        coverage = TestCoverageAnalysis(
            100, 100, 75.0,
            Dict(),
            Dict()
        )

        benchmarks = [
            PerformanceBenchmark("Test", 1.0, 50.0, 10, 1, "excellent")
        ]

        metrics = ReleaseMetrics(
            coverage, benchmarks,
            15.0, 0.80, false, false
        )

        report = check_release_readiness(metrics)
        formatted = generate_release_report(report)

        @test contains(formatted, "BLOCKED")
        @test contains(formatted, "🚫 CRITICAL ISSUES")
    end

    # ==================== Checklist Status Tracking ====================
    @testset "Checklist Status Breakdown" begin
        items = [
            ReleaseChecklistItem("Testing", "Phase 3.1", "complete", Date(2026, 4, 20), "52 tests"),
            ReleaseChecklistItem("Testing", "Phase 3.2", "complete", Date(2026, 4, 20), "77 tests"),
            ReleaseChecklistItem("Testing", "Phase 3.3", "complete", Date(2026, 4, 20), "82 tests"),
            ReleaseChecklistItem("Performance", "Benchmarks", "in_progress", Date(2026, 4, 21), ""),
            ReleaseChecklistItem("Documentation", "User guide", "pending", Date(2026, 4, 22), "")
        ]

        completed = filter(i -> i.status == "complete", items)
        in_progress = filter(i -> i.status == "in_progress", items)
        pending = filter(i -> i.status == "pending", items)

        @test length(completed) == 3
        @test length(in_progress) == 1
        @test length(pending) == 1
    end

    # ==================== Integration Tests ====================
    @testset "Full Release Validation Workflow" begin
        # Simulate Phase 3 completion
        test_counts = Dict(
            "phase_31" => 52,
            "phase_32" => 77,
            "phase_33" => 82
        )

        coverage = validate_test_coverage(test_counts)

        # Run benchmarks
        configs = [
            Dict("type" => "Single-state", "num_hospitals" => 50, "num_years" => 3)
        ]
        benchmarks = benchmark_performance(configs)

        # Create release metrics
        metrics = ReleaseMetrics(
            coverage, benchmarks,
            5.2, 0.95, true, true
        )

        # Check readiness
        report = check_release_readiness(metrics)

        # Generate report
        formatted = generate_release_report(report)

        @test report.overall_status == "ready"
        @test !isempty(formatted)
        @test contains(formatted, "v1.0")
        @test report.metrics.test_coverage.total_tests == 211
    end

    # ==================== Edge Cases ====================
    @testset "Empty Benchmark List" begin
        coverage = TestCoverageAnalysis(100, 100, 100.0, Dict(), Dict())
        metrics = ReleaseMetrics(coverage, PerformanceBenchmark[], 0.0, 1.0, true, true)

        report = check_release_readiness(metrics)

        @test report.overall_status == "ready"
        @test isempty(report.metrics.performance)
    end

    @testset "Boundary Case - Exactly 90% Coverage" begin
        coverage = TestCoverageAnalysis(90, 81, 90.0, Dict(), Dict())
        metrics = ReleaseMetrics(coverage, PerformanceBenchmark[], 10.0, 0.90, true, true)

        report = check_release_readiness(metrics)

        # Should not trigger critical issue for exactly 90%
        @test !any(contains(i, "below 90%") for i in report.critical_issues)
    end

end
