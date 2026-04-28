# test/test_value_based_optimization.jl
# Comprehensive tests for ValueBasedOptimization.jl (Phase 2.2)
#
# Run with:
#   julia --compiled-modules=no --startup-file=no --project=. \
#         test/test_value_based_optimization.jl

using Test
using Random
using JuMP
using HiGHS

Random.seed!(42)

include(joinpath(@__DIR__, "..", "src", "optimization", "ValueBasedOptimization.jl"))

@testset "ValueBasedOptimization — Phase 2.2" begin

    # =========================================================================
    # 1. optimize_service_allocation
    # =========================================================================
    @testset "Service Allocation — basic feasibility" begin
        service_lines = ["Cardiology", "Orthopedics", "General Surgery"]
        margin  = Dict("Cardiology" => 1200.0,  "Orthopedics" => 900.0,  "General Surgery" => 600.0)
        cost    = Dict("Cardiology" => 3000.0,  "Orthopedics" => 2500.0, "General Surgery" => 2000.0)
        cap     = Dict("Cardiology" => 500.0,   "Orthopedics" => 400.0,  "General Surgery" => 600.0)
        quality = Dict("Cardiology" => 0.85,    "Orthopedics" => 0.80,   "General Surgery" => 0.75)
        budget  = 2_000_000.0

        result = optimize_service_allocation(service_lines, margin, cost, cap, quality, budget)

        @test result.status == :OPTIMAL
        @test result.objective_value > 0.0
        @test length(result.volumes) == length(service_lines)
        @test all(v >= 0.0 for v in values(result.volumes))
    end

    @testset "Service Allocation — budget constraint respected" begin
        service_lines = ["A", "B", "C"]
        margin  = Dict("A" => 500.0, "B" => 400.0, "C" => 300.0)
        cost    = Dict("A" => 1000.0, "B" => 800.0, "C" => 600.0)
        cap     = Dict("A" => 300.0,  "B" => 300.0, "C" => 300.0)
        quality = Dict("A" => 0.9, "B" => 0.8, "C" => 0.7)
        budget  = 500_000.0

        result = optimize_service_allocation(service_lines, margin, cost, cap, quality, budget)

        @test result.status == :OPTIMAL
        @test result.budget_used <= budget + 1.0   # 1-unit floating-point tolerance
    end

    @testset "Service Allocation — capacity constraints respected" begin
        service_lines = ["X", "Y"]
        margin  = Dict("X" => 2000.0, "Y" => 2000.0)
        cost    = Dict("X" => 100.0,  "Y" => 100.0)
        cap     = Dict("X" => 50.0,   "Y" => 80.0)
        quality = Dict("X" => 0.9, "Y" => 0.9)
        budget  = 100_000_000.0   # non-binding

        result = optimize_service_allocation(service_lines, margin, cost, cap, quality, budget)

        @test result.status == :OPTIMAL
        @test result.volumes["X"] <= cap["X"] + 1e-6
        @test result.volumes["Y"] <= cap["Y"] + 1e-6
    end

    @testset "Service Allocation — quality weight influence" begin
        service_lines = ["HighMargin", "HighQuality"]
        margin  = Dict("HighMargin" => 5000.0, "HighQuality" => 500.0)
        cost    = Dict("HighMargin" => 1000.0, "HighQuality" => 200.0)
        cap     = Dict("HighMargin" => 200.0,  "HighQuality" => 200.0)
        quality = Dict("HighMargin" => 0.50,   "HighQuality" => 0.99)
        budget  = 5_000_000.0

        result_low_q  = optimize_service_allocation(
            service_lines, margin, cost, cap, quality, budget; quality_weight=0.01
        )
        result_high_q = optimize_service_allocation(
            service_lines, margin, cost, cap, quality, budget; quality_weight=0.99
        )

        # With high quality weight, HighQuality service should get relatively more volume
        ratio_low  = result_low_q.volumes["HighQuality"]  / max(result_low_q.volumes["HighMargin"],  1.0)
        ratio_high = result_high_q.volumes["HighQuality"] / max(result_high_q.volumes["HighMargin"], 1.0)
        @test ratio_high >= ratio_low
    end

    @testset "Service Allocation — zero budget yields zero volumes" begin
        service_lines = ["A", "B"]
        margin  = Dict("A" => 100.0, "B" => 100.0)
        cost    = Dict("A" => 100.0, "B" => 100.0)
        cap     = Dict("A" => 200.0, "B" => 200.0)
        quality = Dict("A" => 0.8,   "B" => 0.8)

        result = optimize_service_allocation(service_lines, margin, cost, cap, quality, 0.0)

        @test result.status == :OPTIMAL
        @test all(v <= 1e-6 for v in values(result.volumes))
    end

    # =========================================================================
    # 2. optimize_resource_allocation
    # =========================================================================
    @testset "Resource Allocation — basic feasibility" begin
        departments = ["ED", "Cardiology", "Oncology", "Orthopedics"]
        budget = 1_000_000.0
        outcome_per_dollar = Dict("ED" => 0.0012, "Cardiology" => 0.0010,
                                  "Oncology" => 0.0015, "Orthopedics" => 0.0008)
        min_alloc = Dict(d => 50_000.0 for d in departments)
        max_alloc = Dict(d => 400_000.0 for d in departments)

        result = optimize_resource_allocation(departments, budget, outcome_per_dollar,
                                              min_alloc, max_alloc)

        @test result.status == :OPTIMAL
        @test result.budget_used <= budget + 10.0
        @test all(result.allocations[d] >= min_alloc[d] - 1.0 for d in departments)
        @test all(result.allocations[d] <= max_alloc[d] + 1.0 for d in departments)
    end

    @testset "Resource Allocation — allocations sum to budget" begin
        departments = ["A", "B", "C"]
        budget = 1_000_000.0
        outcome_per_dollar = Dict("A" => 0.001, "B" => 0.002, "C" => 0.003)
        min_alloc = Dict("A" => 100_000.0, "B" => 100_000.0, "C" => 100_000.0)
        max_alloc = Dict("A" => 500_000.0, "B" => 500_000.0, "C" => 500_000.0)

        result = optimize_resource_allocation(departments, budget, outcome_per_dollar,
                                              min_alloc, max_alloc)

        @test result.status == :OPTIMAL
        @test abs(result.budget_used - budget) <= budget * 0.01 + 1.0
    end

    @testset "Resource Allocation — higher outcome rate receives more funds" begin
        departments = ["Low", "High"]
        budget = 1_000_000.0
        outcome_per_dollar = Dict("Low" => 0.0005, "High" => 0.005)
        min_alloc = Dict("Low" => 50_000.0, "High" => 50_000.0)
        max_alloc = Dict("Low" => 800_000.0, "High" => 800_000.0)

        result = optimize_resource_allocation(departments, budget, outcome_per_dollar,
                                              min_alloc, max_alloc)

        @test result.status == :OPTIMAL
        @test result.allocations["High"] >= result.allocations["Low"] - 1.0
    end

    # =========================================================================
    # 3. optimize_network_services
    # =========================================================================
    @testset "Network Optimization — basic feasibility" begin
        hospitals = ["Hospital_1", "Hospital_2", "Hospital_3"]
        services  = ["Cardiology", "Oncology", "Orthopedics"]
        revenue   = Dict("Cardiology" => 8000.0, "Oncology" => 10000.0, "Orthopedics" => 6000.0)
        cost_svc  = Dict("Cardiology" => 5000.0, "Oncology" =>  7000.0, "Orthopedics" => 4000.0)
        demand    = Dict{Tuple{String,String}, Float64}()
        for h in hospitals, s in services
            demand[(h, s)] = rand(50.0:200.0)
        end
        hosp_cap  = Dict(h => 2000.0 for h in hospitals)
        setup     = Dict("Cardiology" => 500_000.0, "Oncology" => 800_000.0,
                         "Orthopedics" => 400_000.0)
        net_budget = 5_000_000.0

        result = optimize_network_services(
            hospitals, services, revenue, cost_svc, demand, hosp_cap, setup, net_budget
        )

        @test result.status == :OPTIMAL
        @test length(result.assignments) == length(hospitals) * length(services)
    end

    @testset "Network Optimization — setup budget constraint respected" begin
        hospitals = ["H1", "H2"]
        services  = ["S1"]
        revenue   = Dict("S1" => 5000.0)
        cost_svc  = Dict("S1" => 3000.0)
        demand    = Dict(("H1","S1") => 100.0,
                         ("H2","S1") => 100.0)
        hosp_cap  = Dict("H1" => 1000.0, "H2" => 1000.0)
        setup     = Dict("S1" => 300_000.0)
        net_budget = 300_000.0   # exactly one hospital can set up S1

        # 40% of 200 total demand = 80 cases needed; 1 hospital can serve 100 ≥ 80
        result = optimize_network_services(
            hospitals, services, revenue, cost_svc, demand, hosp_cap, setup, net_budget;
            min_access_coverage = 0.4
        )

        @test result.status == :OPTIMAL
        total_setup = sum(
            (setup[s] for (h, s) in keys(result.assignments) if result.assignments[(h, s)]);
            init = 0.0
        )
        @test total_setup <= net_budget + 1.0
    end

    @testset "Network Optimization — 20-hospital network solves in <10s" begin
        n_h = 20
        n_s = 5
        hospitals = ["Hospital_$i" for i in 1:n_h]
        services  = ["Service_$j" for j in 1:n_s]
        revenue   = Dict(s => rand(4000.0:12000.0) for s in services)
        cost_svc  = Dict(s => revenue[s] * 0.65    for s in services)
        demand    = Dict{Tuple{String,String}, Float64}(
            (h, s) => rand(20.0:150.0) for h in hospitals for s in services
        )
        hosp_cap  = Dict(h => 3000.0 for h in hospitals)
        setup     = Dict(s => rand(200_000.0:600_000.0) for s in services)
        net_budget = 20_000_000.0

        t = @elapsed begin
            result = optimize_network_services(
                hospitals, services, revenue, cost_svc, demand, hosp_cap, setup, net_budget
            )
        end

        @test result.status == :OPTIMAL
        @test t < 10.0   # must solve in <10 seconds
    end

    # =========================================================================
    # 4. optimize_staffing_ratios
    # =========================================================================
    @testset "Staffing Ratios — basic feasibility" begin
        units   = ["ICU", "MedSurg", "ED", "OB"]
        volumes = Dict("ICU" => 20.0, "MedSurg" => 40.0, "ED" => 30.0, "OB" => 15.0)
        salary  = Dict("ICU" => 95_000.0, "MedSurg" => 75_000.0,
                       "ED" => 85_000.0,  "OB" => 78_000.0)
        min_r   = Dict("ICU" => 0.50, "MedSurg" => 0.20, "ED" => 0.33, "OB" => 0.25)
        max_r   = Dict("ICU" => 1.00, "MedSurg" => 0.50, "ED" => 0.75, "OB" => 0.60)
        budget  = 15_000_000.0

        result = optimize_staffing_ratios(units, volumes, salary, min_r, max_r, budget)

        @test result.status == :OPTIMAL
        @test all(result.ratios[u] >= min_r[u] - 1e-6 for u in units)
        @test all(result.ratios[u] <= max_r[u] + 1e-6 for u in units)
        @test result.total_cost <= budget + 1.0
    end

    @testset "Staffing Ratios — budget constraint binding" begin
        units   = ["ICU"]
        volumes = Dict("ICU" => 20.0)
        salary  = Dict("ICU" => 100_000.0)
        min_r   = Dict("ICU" => 0.5)
        max_r   = Dict("ICU" => 1.0)
        # Budget = min_ratio × patient_volume × coverage_factor × salary
        #        = 0.5 × 20.0 × 4.2 × 100_000 = 4_200_000 (exactly minimum staffing cost)
        min_ratio_value   = 0.5
        patient_volume    = 20.0
        coverage_factor   = 4.2
        annual_salary     = 100_000.0
        tight_budget = min_ratio_value * patient_volume * coverage_factor * annual_salary

        result = optimize_staffing_ratios(units, volumes, salary, min_r, max_r, tight_budget)

        @test result.status == :OPTIMAL
        @test result.total_cost <= tight_budget + 1.0
    end

    @testset "Staffing Ratios — quality_score increases with quality_weight" begin
        units   = ["MedSurg"]
        volumes = Dict("MedSurg" => 30.0)
        salary  = Dict("MedSurg" => 75_000.0)
        min_r   = Dict("MedSurg" => 0.20)
        max_r   = Dict("MedSurg" => 0.60)
        budget  = 5_000_000.0

        r_low  = optimize_staffing_ratios(units, volumes, salary, min_r, max_r, budget;
                                          quality_weight=0.01)
        r_high = optimize_staffing_ratios(units, volumes, salary, min_r, max_r, budget;
                                          quality_weight=0.99)

        @test r_high.quality_score >= r_low.quality_score - 1e-6
    end

    # =========================================================================
    # 5. optimize_multi_objective
    # =========================================================================
    @testset "Multi-Objective — basic feasibility" begin
        service_lines = ["Cardiology", "Oncology", "Orthopedics", "Neurology"]
        margin  = Dict("Cardiology" => 1500.0, "Oncology" => 2000.0,
                       "Orthopedics" => 1200.0, "Neurology" => 1800.0)
        cost    = Dict("Cardiology" => 3000.0, "Oncology" => 4000.0,
                       "Orthopedics" => 2500.0, "Neurology" => 3500.0)
        cap     = Dict("Cardiology" => 300.0, "Oncology" => 200.0,
                       "Orthopedics" => 400.0, "Neurology" => 250.0)
        quality = Dict("Cardiology" => 0.85, "Oncology" => 0.80,
                       "Orthopedics" => 0.78, "Neurology" => 0.82)
        access  = Dict("Cardiology" => 0.60, "Oncology" => 0.75,
                       "Orthopedics" => 0.55, "Neurology" => 0.70)
        budget  = 3_000_000.0

        result = optimize_multi_objective(service_lines, margin, cost, cap, quality, access, budget)

        @test result.status == :OPTIMAL
        @test result.objective_value > 0.0
        @test result.budget_used <= budget + 1.0
    end

    @testset "Multi-Objective — budget constraint respected" begin
        service_lines = ["A", "B"]
        margin  = Dict("A" => 1000.0, "B" => 1000.0)
        cost    = Dict("A" =>  500.0, "B" =>  500.0)
        cap     = Dict("A" => 1000.0, "B" => 1000.0)
        quality = Dict("A" => 0.9, "B" => 0.9)
        access  = Dict("A" => 0.8, "B" => 0.8)
        budget  = 250_000.0

        result = optimize_multi_objective(service_lines, margin, cost, cap, quality, access, budget)

        @test result.status == :OPTIMAL
        @test result.budget_used <= budget + 1.0
    end

    @testset "Multi-Objective — margin-only weights match service allocation" begin
        service_lines = ["P", "Q"]
        margin  = Dict("P" => 2000.0, "Q" =>  500.0)
        cost    = Dict("P" =>  200.0, "Q" =>  200.0)
        cap     = Dict("P" => 100.0,  "Q" => 100.0)
        quality = Dict("P" => 0.7,   "Q" => 0.7)
        access  = Dict("P" => 0.7,   "Q" => 0.7)
        budget  = 5_000_000.0

        multi_result  = optimize_multi_objective(
            service_lines, margin, cost, cap, quality, access, budget;
            margin_weight=1.0, access_weight=0.0, quality_weight=0.0
        )
        single_result = optimize_service_allocation(
            service_lines, margin, cost, cap, quality, budget; quality_weight=0.0
        )

        # When only margin matters and quality weights are equal, volumes should agree
        @test abs(multi_result.volumes["P"] - single_result.volumes["P"]) < 1.0
        @test abs(multi_result.volumes["Q"] - single_result.volumes["Q"]) < 1.0
    end

    # =========================================================================
    # 6. Robustness: ±10 % constraint perturbation
    # =========================================================================
    @testset "Robustness — ±10% budget perturbation maintains feasibility" begin
        service_lines = ["A", "B", "C"]
        margin  = Dict("A" => 800.0, "B" => 600.0, "C" => 400.0)
        cost    = Dict("A" => 500.0, "B" => 400.0, "C" => 300.0)
        cap     = Dict("A" => 200.0, "B" => 200.0, "C" => 200.0)
        quality = Dict("A" => 0.85, "B" => 0.80, "C" => 0.75)
        budget  = 200_000.0

        for pct in [-0.10, -0.05, 0.0, 0.05, 0.10]
            perturbed_budget = budget * (1.0 + pct)
            result = optimize_service_allocation(
                service_lines, margin, cost, cap, quality, perturbed_budget
            )
            @test result.status == :OPTIMAL
            @test result.budget_used <= perturbed_budget + 1.0
        end
    end

    @testset "Robustness — ±10% demand perturbation for network optimization" begin
        hospitals = ["H1", "H2"]
        services  = ["S1"]
        revenue   = Dict("S1" => 5000.0)
        cost_svc  = Dict("S1" => 3000.0)
        base_demand = 100.0
        hosp_cap  = Dict("H1" => 500.0, "H2" => 500.0)
        setup     = Dict("S1" => 50_000.0)
        net_budget = 200_000.0

        for pct in [-0.10, -0.05, 0.0, 0.05, 0.10]
            demand = Dict(
                ("H1","S1") => base_demand * (1.0 + pct),
                ("H2","S1") => base_demand * (1.0 + pct)
            )
            result = optimize_network_services(
                hospitals, services, revenue, cost_svc, demand, hosp_cap, setup, net_budget
            )
            @test result.status == :OPTIMAL
        end
    end

    # =========================================================================
    # 7. Legacy stub
    # =========================================================================
    @testset "Legacy stub — optimize_outcome_allocation returns nothing" begin
        result = optimize_outcome_allocation(1_000_000.0, ["intervention_a", "intervention_b"])
        @test isnothing(result)
    end

end  # @testset "ValueBasedOptimization — Phase 2.2"

println("\n✓ All ValueBasedOptimization tests completed!")
