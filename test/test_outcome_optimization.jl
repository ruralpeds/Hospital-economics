# test/test_outcome_optimization.jl
# Comprehensive tests for OutcomeOptimization.jl

using Test
using Random
using JuMP
using HiGHS

# Set seed for reproducibility
Random.seed!(42)

# Include necessary modules
include("../src/optimization/OutcomeOptimization.jl")

@testset "OutcomeOptimization Tests" begin

    # ================== Cost Minimization Tests ==================
    @testset "Cost Minimization Model Creation" begin
        service_lines = ["Cardiology", "Orthopedics", "General"]
        volumes = Dict("Cardiology" => 100, "Orthopedics" => 80, "General" => 120)
        costs = Dict("Cardiology" => 5000.0, "Orthopedics" => 4500.0, "General" => 3000.0)
        quality_scores = Dict("Cardiology" => 0.85, "Orthopedics" => 0.80, "General" => 0.75)
        quality_threshold = 0.70

        problem = create_cost_minimization_model(
            service_lines, volumes, costs, quality_scores, quality_threshold
        )

        @test !isempty(problem.model)
        @test problem.quality_threshold == quality_threshold
        @test length(problem.service_lines) == 3
    end

    @testset "Cost Minimization Solving" begin
        service_lines = ["Cardiology", "Orthopedics", "General"]
        volumes = Dict("Cardiology" => 100, "Orthopedics" => 80, "General" => 120)
        costs = Dict("Cardiology" => 5000.0, "Orthopedics" => 4500.0, "General" => 3000.0)
        quality_scores = Dict("Cardiology" => 0.85, "Orthopedics" => 0.80, "General" => 0.75)

        problem = create_cost_minimization_model(
            service_lines, volumes, costs, quality_scores, 0.70
        )
        solution = solve_cost_minimization(problem)

        @test solution["status"] == JuMP.OPTIMAL
        @test !isempty(solution["cost_multipliers"])
        @test all(0.5 <= v <= 1.0 for v in values(solution["cost_multipliers"]))
        @test solution["objective_value"] < sum(volumes[sl] * costs[sl] for sl in service_lines)
    end

    @testset "Cost Minimization Quality Constraints" begin
        service_lines = ["A", "B"]
        volumes = Dict("A" => 50, "B" => 50)
        costs = Dict("A" => 5000.0, "B" => 4000.0)
        quality_scores = Dict("A" => 0.80, "B" => 0.75)
        quality_threshold = 0.70

        problem = create_cost_minimization_model(
            service_lines, volumes, costs, quality_scores, quality_threshold
        )
        solution = solve_cost_minimization(problem)

        # Verify quality constraints are satisfied
        for sl in service_lines
            new_quality = quality_scores[sl] * solution["quality_factors"][sl]
            @test new_quality >= quality_threshold - 0.001  # Small tolerance for floating point
        end
    end

    # ================== Quality Maximization Tests ==================
    @testset "Quality Maximization Model Creation" begin
        service_lines = ["Cardiology", "Orthopedics", "General"]
        volumes = Dict("Cardiology" => 100, "Orthopedics" => 80, "General" => 120)
        quality_improvement_cost = Dict(
            "Cardiology" => 100.0, "Orthopedics" => 80.0, "General" => 50.0
        )
        current_quality = Dict("Cardiology" => 0.80, "Orthopedics" => 0.75, "General" => 0.70)
        budget = 50000.0

        problem = create_quality_maximization_model(
            service_lines, volumes, quality_improvement_cost, current_quality, budget
        )

        @test !isempty(problem.model)
        @test problem.budget == budget
        @test length(problem.service_lines) == 3
    end

    @testset "Quality Maximization Solving" begin
        service_lines = ["Cardiology", "Orthopedics", "General"]
        volumes = Dict("Cardiology" => 100, "Orthopedics" => 80, "General" => 120)
        quality_improvement_cost = Dict(
            "Cardiology" => 100.0, "Orthopedics" => 80.0, "General" => 50.0
        )
        current_quality = Dict("Cardiology" => 0.80, "Orthopedics" => 0.75, "General" => 0.70)
        budget = 50000.0

        problem = create_quality_maximization_model(
            service_lines, volumes, quality_improvement_cost, current_quality, budget
        )
        solution = solve_quality_maximization(problem)

        @test solution["status"] == JuMP.OPTIMAL
        @test !isempty(solution["quality_improvements"])
        @test solution["budget_used"] <= budget + 0.01
        @test all(v >= current_quality[sl] for (sl, v) in solution["new_quality_scores"])
    end

    @testset "Quality Maximization Budget Constraint" begin
        service_lines = ["A", "B"]
        volumes = Dict("A" => 100, "B" => 100)
        quality_improvement_cost = Dict("A" => 50.0, "B" => 50.0)
        current_quality = Dict("A" => 0.70, "B" => 0.70)
        budget = 10000.0

        problem = create_quality_maximization_model(
            service_lines, volumes, quality_improvement_cost, current_quality, budget
        )
        solution = solve_quality_maximization(problem)

        # Verify budget constraint is satisfied
        total_spent = sum(values(solution["investment_amounts"]))
        @test total_spent <= budget + 0.01  # Small tolerance for floating point
    end

    @testset "Quality Maximization Quality Bounds" begin
        service_lines = ["A", "B"]
        volumes = Dict("A" => 50, "B" => 50)
        quality_improvement_cost = Dict("A" => 10.0, "B" => 10.0)
        current_quality = Dict("A" => 0.95, "B" => 0.90)
        budget = 100000.0

        problem = create_quality_maximization_model(
            service_lines, volumes, quality_improvement_cost, current_quality, budget
        )
        solution = solve_quality_maximization(problem)

        # Quality cannot exceed 1.0
        for (sl, q) in solution["new_quality_scores"]
            @test q <= 1.001  # Small tolerance
        end
    end

    # ================== Service Line Portfolio Tests ==================
    @testset "Service Line Portfolio Model Creation" begin
        service_lines = ["Cardiology", "Orthopedics", "Neurology", "Gastroenterology"]
        investment_costs = Dict(
            "Cardiology" => 500000.0,
            "Orthopedics" => 300000.0,
            "Neurology" => 400000.0,
            "Gastroenterology" => 250000.0
        )
        revenue_per_volume = Dict(
            "Cardiology" => 3500.0,
            "Orthopedics" => 3000.0,
            "Neurology" => 3200.0,
            "Gastroenterology" => 2800.0
        )
        quality_potential = Dict(
            "Cardiology" => 0.85,
            "Orthopedics" => 0.80,
            "Neurology" => 0.82,
            "Gastroenterology" => 0.78
        )
        volume_constraints = Dict(
            "Cardiology" => (50, 200),
            "Orthopedics" => (40, 150),
            "Neurology" => (30, 120),
            "Gastroenterology" => (20, 100)
        )
        total_budget = 800000.0

        problem = create_service_line_portfolio_model(
            service_lines, investment_costs, revenue_per_volume, quality_potential,
            volume_constraints, total_budget
        )

        @test !isempty(problem.model)
        @test problem.total_budget == total_budget
        @test length(problem.service_lines) == 4
    end

    @testset "Service Line Portfolio Solving" begin
        service_lines = ["Cardiology", "Orthopedics"]
        investment_costs = Dict("Cardiology" => 500000.0, "Orthopedics" => 300000.0)
        revenue_per_volume = Dict("Cardiology" => 3500.0, "Orthopedics" => 3000.0)
        quality_potential = Dict("Cardiology" => 0.85, "Orthopedics" => 0.80)
        volume_constraints = Dict("Cardiology" => (50, 200), "Orthopedics" => (40, 150))
        total_budget = 800000.0

        problem = create_service_line_portfolio_model(
            service_lines, investment_costs, revenue_per_volume, quality_potential,
            volume_constraints, total_budget
        )
        solution = solve_service_line_portfolio(problem)

        @test solution["status"] == JuMP.OPTIMAL
        @test !isempty(solution["selected_services"])
        @test solution["total_investment"] <= total_budget + 0.01
    end

    @testset "Service Line Portfolio Binary Selection" begin
        service_lines = ["A", "B", "C"]
        investment_costs = Dict("A" => 200000.0, "B" => 150000.0, "C" => 100000.0)
        revenue_per_volume = Dict("A" => 2000.0, "B" => 1800.0, "C" => 1500.0)
        quality_potential = Dict("A" => 0.80, "B" => 0.75, "C" => 0.70)
        volume_constraints = Dict("A" => (50, 200), "B" => (40, 150), "C" => (30, 100))
        total_budget = 250000.0

        problem = create_service_line_portfolio_model(
            service_lines, investment_costs, revenue_per_volume, quality_potential,
            volume_constraints, total_budget
        )
        solution = solve_service_line_portfolio(problem)

        # Each selected service should have volumes within constraints
        for sl in solution["selected_services"]
            vol = solution["volumes"][sl]
            min_vol, max_vol = volume_constraints[sl]
            @test vol >= min_vol * 0.99
            @test vol <= max_vol * 1.01
        end
    end

    # ================== Capacity Allocation Tests ==================
    @testset "Capacity Allocation Model Creation" begin
        hospitals = ["Hospital A", "Hospital B"]
        departments = ["Cardiology", "Orthopedics"]
        total_beds = Dict("Hospital A" => 100, "Hospital B" => 80)
        demand = Dict(
            ("Hospital A", "Cardiology") => 30,
            ("Hospital A", "Orthopedics") => 20,
            ("Hospital B", "Cardiology") => 25,
            ("Hospital B", "Orthopedics") => 15
        )
        cost_per_bed = Dict("cost_Cardiology" => 2000.0, "cost_Orthopedics" => 1500.0)
        revenue_per_case = Dict("revenue_Cardiology" => 3500.0, "revenue_Orthopedics" => 3000.0)
        quality_per_bed = Dict("quality_Cardiology" => 0.1, "quality_Orthopedics" => 0.08)

        problem = create_capacity_allocation_model(
            hospitals, departments, total_beds, demand, cost_per_bed, revenue_per_case,
            quality_per_bed
        )

        @test !isempty(problem.model)
        @test length(problem.hospitals) == 2
        @test length(problem.departments) == 2
    end

    @testset "Capacity Allocation Solving" begin
        hospitals = ["Hospital A", "Hospital B"]
        departments = ["Cardiology", "Orthopedics"]
        total_beds = Dict("Hospital A" => 100, "Hospital B" => 80)
        demand = Dict(
            ("Hospital A", "Cardiology") => 30,
            ("Hospital A", "Orthopedics") => 20,
            ("Hospital B", "Cardiology") => 25,
            ("Hospital B", "Orthopedics") => 15
        )
        cost_per_bed = Dict("cost_Cardiology" => 2000.0, "cost_Orthopedics" => 1500.0)
        revenue_per_case = Dict("revenue_Cardiology" => 3500.0, "revenue_Orthopedics" => 3000.0)
        quality_per_bed = Dict("quality_Cardiology" => 0.1, "quality_Orthopedics" => 0.08)

        problem = create_capacity_allocation_model(
            hospitals, departments, total_beds, demand, cost_per_bed, revenue_per_case,
            quality_per_bed
        )
        solution = solve_capacity_allocation(problem)

        @test solution["status"] == JuMP.OPTIMAL
        @test !isempty(solution["allocations"])
        @test !isempty(solution["utilization_rates"])
    end

    @testset "Capacity Allocation Bed Constraints" begin
        hospitals = ["Hospital A"]
        departments = ["Cardiology", "Orthopedics"]
        total_beds = Dict("Hospital A" => 50)
        demand = Dict(
            ("Hospital A", "Cardiology") => 30,
            ("Hospital A", "Orthopedics") => 20
        )
        cost_per_bed = Dict("cost_Cardiology" => 2000.0, "cost_Orthopedics" => 1500.0)
        revenue_per_case = Dict("revenue_Cardiology" => 3500.0, "revenue_Orthopedics" => 3000.0)
        quality_per_bed = Dict("quality_Cardiology" => 0.1, "quality_Orthopedics" => 0.08)

        problem = create_capacity_allocation_model(
            hospitals, departments, total_beds, demand, cost_per_bed, revenue_per_case,
            quality_per_bed
        )
        solution = solve_capacity_allocation(problem)

        # Total allocated beds should not exceed total available
        for h in hospitals
            total_allocated = sum(values(solution["allocations"][h]))
            @test total_allocated <= total_beds[h]
        end
    end

    @testset "Capacity Allocation Utilization Rates" begin
        hospitals = ["Hospital A", "Hospital B"]
        departments = ["Cardiology"]
        total_beds = Dict("Hospital A" => 100, "Hospital B" => 80)
        demand = Dict(("Hospital A", "Cardiology") => 60, ("Hospital B", "Cardiology") => 40)
        cost_per_bed = Dict("cost_Cardiology" => 2000.0)
        revenue_per_case = Dict("revenue_Cardiology" => 3500.0)
        quality_per_bed = Dict("quality_Cardiology" => 0.1)

        problem = create_capacity_allocation_model(
            hospitals, departments, total_beds, demand, cost_per_bed, revenue_per_case,
            quality_per_bed
        )
        solution = solve_capacity_allocation(problem)

        # Utilization rates should be between 0 and 1
        for h in hospitals
            @test 0.0 <= solution["utilization_rates"][h] <= 1.001
        end
    end

    # ================== Summary Generation Tests ==================
    @testset "Cost Minimization Summary" begin
        service_lines = ["A", "B"]
        volumes = Dict("A" => 50, "B" => 50)
        costs = Dict("A" => 5000.0, "B" => 4000.0)
        quality_scores = Dict("A" => 0.80, "B" => 0.75)

        problem = create_cost_minimization_model(service_lines, volumes, costs, quality_scores, 0.70)
        solve_cost_minimization(problem)
        summary = get_optimization_summary(problem)

        @test haskey(summary, "optimization_status")
        @test summary["is_optimal"] == true
        @test !isnothing(summary["objective_value"])
    end

    @testset "Quality Maximization Summary" begin
        service_lines = ["A", "B"]
        volumes = Dict("A" => 50, "B" => 50)
        quality_improvement_cost = Dict("A" => 50.0, "B" => 50.0)
        current_quality = Dict("A" => 0.70, "B" => 0.70)

        problem = create_quality_maximization_model(
            service_lines, volumes, quality_improvement_cost, current_quality, 50000.0
        )
        solve_quality_maximization(problem)
        summary = get_optimization_summary(problem)

        @test haskey(summary, "optimization_status")
        @test summary["is_optimal"] == true
    end

    # ================== Integration Tests ==================
    @testset "Multi-Problem Optimization Workflow" begin
        # Define common data
        service_lines = ["Cardiology", "Orthopedics"]
        volumes = Dict("Cardiology" => 100, "Orthopedics" => 80)
        costs = Dict("Cardiology" => 5000.0, "Orthopedics" => 4000.0)
        quality_scores = Dict("Cardiology" => 0.80, "Orthopedics" => 0.75)

        # Problem 1: Minimize costs
        cost_problem = create_cost_minimization_model(
            service_lines, volumes, costs, quality_scores, 0.70
        )
        cost_solution = solve_cost_minimization(cost_problem)

        @test cost_solution["status"] == JuMP.OPTIMAL

        # Problem 2: Maximize quality with budget from cost savings
        quality_improvement_cost = Dict("Cardiology" => 100.0, "Orthopedics" => 80.0)
        budget = cost_solution["total_cost_reduction"] * 0.5  # Use 50% of savings

        quality_problem = create_quality_maximization_model(
            service_lines, volumes, quality_improvement_cost, quality_scores, budget
        )
        quality_solution = solve_quality_maximization(quality_problem)

        @test quality_solution["status"] == JuMP.OPTIMAL
        @test quality_solution["budget_used"] <= budget + 0.01
    end

    @testset "Scalability: Large Number of Service Lines" begin
        n_services = 20
        service_lines = ["Service_$i" for i in 1:n_services]
        volumes = Dict(sl => rand(50:200) for sl in service_lines)
        costs = Dict(sl => rand(3000.0:6000.0) for sl in service_lines)
        quality_scores = Dict(sl => rand(0.65:0.95) for sl in service_lines)

        problem = create_cost_minimization_model(
            service_lines, volumes, costs, quality_scores, 0.70
        )
        solution = solve_cost_minimization(problem)

        @test solution["status"] == JuMP.OPTIMAL
        @test length(solution["cost_multipliers"]) == n_services
    end

    @testset "Sensitivity: Tight Quality Constraint" begin
        service_lines = ["A", "B"]
        volumes = Dict("A" => 50, "B" => 50)
        costs = Dict("A" => 5000.0, "B" => 4000.0)
        quality_scores = Dict("A" => 0.75, "B" => 0.70)
        tight_threshold = 0.72  # Tighter constraint

        problem = create_cost_minimization_model(
            service_lines, volumes, costs, quality_scores, tight_threshold
        )
        solution = solve_cost_minimization(problem)

        # Tight constraint means less cost reduction possible
        @test solution["status"] == JuMP.OPTIMAL
        # Cost multipliers should be within feasible range
        @test all(0.5 <= v <= 1.0 for v in values(solution["cost_multipliers"]))
        # Verify quality constraints are still met
        for sl in service_lines
            new_quality = quality_scores[sl] * solution["quality_factors"][sl]
            @test new_quality >= tight_threshold - 0.001
        end
    end

    @testset "Sensitivity: Large Budget Impact" begin
        service_lines = ["A", "B", "C"]
        volumes = Dict("A" => 100, "B" => 80, "C" => 60)
        quality_improvement_cost = Dict("A" => 100.0, "B" => 80.0, "C" => 60.0)
        current_quality = Dict("A" => 0.70, "B" => 0.70, "C" => 0.70)

        # Small budget
        small_budget = 5000.0
        small_problem = create_quality_maximization_model(
            service_lines, volumes, quality_improvement_cost, current_quality, small_budget
        )
        small_solution = solve_quality_maximization(small_problem)

        # Large budget
        large_budget = 50000.0
        large_problem = create_quality_maximization_model(
            service_lines, volumes, quality_improvement_cost, current_quality, large_budget
        )
        large_solution = solve_quality_maximization(large_problem)

        # Larger budget should achieve higher objective value
        @test large_solution["objective_value"] > small_solution["objective_value"]
    end

end  # End of main testset

println("\n✓ All OutcomeOptimization tests completed!")
