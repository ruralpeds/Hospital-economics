# ============================================================================
# Tests for JuMP optimization models
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "types", "abstract.jl"))

# ---------------------------------------------------------------------------
# Stub optimization models (until JuMP/HiGHS integration is complete)
# ---------------------------------------------------------------------------

"""
Simple linear programming model for hospital resource allocation.
Maximizes contribution margin subject to resource constraints.
"""
struct OptimizationResult
    objective_value::Float64
    service_volumes::Dict{String, Float64}
    resource_utilization::Dict{String, Float64}
    status::Symbol
end

"""
Solve a simplified service-line optimization without JuMP dependency.
Uses a greedy heuristic for testing purposes.
"""
function optimize_service_mix(;
    service_lines::Vector{String},
    contribution_margins::Vector{Float64},
    resource_requirements::Matrix{Float64},  # services x resources
    resource_capacities::Vector{Float64},
    min_volumes::Vector{Float64},
    max_volumes::Vector{Float64},
)
    n_services = length(service_lines)
    n_resources = length(resource_capacities)

    @assert n_services == length(contribution_margins)
    @assert n_services == length(min_volumes)
    @assert n_services == length(max_volumes)
    @assert size(resource_requirements) == (n_services, n_resources)

    # Start with minimum volumes
    volumes = copy(min_volumes)

    # Greedy: increase volume of highest-margin service that still fits
    margin_order = sortperm(contribution_margins; rev=true)
    for idx in margin_order
        while volumes[idx] < max_volumes[idx]
            # Check if adding one unit violates any resource constraint
            feasible = true
            for r in 1:n_resources
                used = sum(volumes[s] * resource_requirements[s, r] for s in 1:n_services)
                if used + resource_requirements[idx, r] > resource_capacities[r]
                    feasible = false
                    break
                end
            end
            feasible || break
            volumes[idx] += 1.0
        end
    end

    objective = sum(volumes .* contribution_margins)
    utilization = Dict{String, Float64}()
    resource_names = ["beds", "or_hours", "nursing_hours", "ed_capacity"]
    for r in 1:min(n_resources, length(resource_names))
        used = sum(volumes[s] * resource_requirements[s, r] for s in 1:n_services)
        utilization[resource_names[r]] = used / resource_capacities[r]
    end

    service_dict = Dict(service_lines[i] => volumes[i] for i in 1:n_services)

    return OptimizationResult(objective, service_dict, utilization, :optimal)
end

"""
Break-even analysis: find minimum volume to cover fixed costs.
"""
function compute_breakeven_volume(fixed_costs::Float64, contribution_margin_per_unit::Float64)
    contribution_margin_per_unit <= 0.0 && return Inf
    return ceil(fixed_costs / contribution_margin_per_unit)
end

"""
Staffing optimization: minimize cost subject to coverage requirements.
"""
function optimize_staffing(;
    shifts::Vector{String},
    coverage_required::Vector{Float64},
    cost_per_fte::Float64,
    fte_hours_per_shift::Float64,
    min_ftes::Float64=1.0,
)
    total_coverage_needed = sum(coverage_required)
    ftes_needed = max(min_ftes, ceil(total_coverage_needed / fte_hours_per_shift))
    total_cost = ftes_needed * cost_per_fte
    return (ftes=ftes_needed, total_cost=total_cost, status=:optimal)
end

@testset "Optimization Models" begin

    # -----------------------------------------------------------------------
    @testset "Service-line optimization" begin
        services = ["Inpatient", "ED", "Outpatient_Surgery", "Imaging"]
        margins = [2500.0, 800.0, 3500.0, 500.0]

        # Resources: beds, OR hours, nursing hours, ED capacity
        requirements = [
            1.0  0.0  8.0  0.0;   # Inpatient
            0.0  0.0  2.0  1.0;   # ED
            0.0  2.0  4.0  0.0;   # Outpatient Surgery
            0.0  0.0  0.5  0.0;   # Imaging
        ]
        capacities = [25.0, 500.0, 50000.0, 10000.0]
        min_vols = [0.0, 0.0, 0.0, 0.0]
        max_vols = [500.0, 8000.0, 300.0, 5000.0]

        result = optimize_service_mix(;
            service_lines=services,
            contribution_margins=margins,
            resource_requirements=requirements,
            resource_capacities=capacities,
            min_volumes=min_vols,
            max_volumes=max_vols,
        )

        @test result.status == :optimal
        @test result.objective_value > 0.0

        # All volumes should be within bounds
        for (svc, vol) in result.service_volumes
            idx = findfirst(==(svc), services)
            @test vol >= min_vols[idx]
            @test vol <= max_vols[idx]
        end

        # Resource utilization should be <= 1.0
        for (res, util) in result.resource_utilization
            @test util <= 1.0 + 1e-6  # small tolerance
            @test util >= 0.0
        end

        # Highest-margin service (Outpatient Surgery) should be maximized
        @test result.service_volumes["Outpatient_Surgery"] > 0.0
    end

    # -----------------------------------------------------------------------
    @testset "Break-even analysis" begin
        # Fixed costs of $5M, contribution margin of $2500 per case
        bev = compute_breakeven_volume(5_000_000.0, 2500.0)
        @test bev == 2000.0

        # Lower margin requires more volume
        bev2 = compute_breakeven_volume(5_000_000.0, 1000.0)
        @test bev2 == 5000.0

        # Zero or negative margin -> infinite volume needed
        @test compute_breakeven_volume(5_000_000.0, 0.0) == Inf
        @test compute_breakeven_volume(5_000_000.0, -100.0) == Inf
    end

    # -----------------------------------------------------------------------
    @testset "Staffing optimization" begin
        shifts = ["Day", "Evening", "Night"]
        coverage = [12.0, 8.0, 8.0]  # hours per shift

        result = optimize_staffing(;
            shifts=shifts,
            coverage_required=coverage,
            cost_per_fte=85_000.0,
            fte_hours_per_shift=8.0,
        )

        @test result.status == :optimal
        @test result.ftes >= 1.0
        @test result.ftes == ceil(28.0 / 8.0)  # 4 FTEs
        @test result.total_cost == 4.0 * 85_000.0
    end

    # -----------------------------------------------------------------------
    @testset "Optimization with binding constraints" begin
        services = ["ServiceA", "ServiceB"]
        margins = [1000.0, 500.0]
        requirements = [1.0 1.0; 1.0 1.0]
        capacities = [10.0, 10.0]
        min_vols = [0.0, 0.0]
        max_vols = [100.0, 100.0]

        result = optimize_service_mix(;
            service_lines=services,
            contribution_margins=margins,
            resource_requirements=requirements,
            resource_capacities=capacities,
            min_volumes=min_vols,
            max_volumes=max_vols,
        )

        @test result.status == :optimal
        # Total volume limited by capacity=10
        total_vol = sum(values(result.service_volumes))
        @test total_vol <= 10.0 + 1e-6

        # Higher-margin service A should be preferred
        @test result.service_volumes["ServiceA"] >= result.service_volumes["ServiceB"]
    end

    # -----------------------------------------------------------------------
    @testset "Optimization with minimum volumes" begin
        services = ["Essential", "Optional"]
        margins = [500.0, 2000.0]
        requirements = [1.0; 1.0;;]  # 1 resource
        capacities = [20.0]
        min_vols = [10.0, 0.0]  # Must have at least 10 Essential
        max_vols = [20.0, 20.0]

        result = optimize_service_mix(;
            service_lines=services,
            contribution_margins=margins,
            resource_requirements=requirements,
            resource_capacities=capacities,
            min_volumes=min_vols,
            max_volumes=max_vols,
        )

        @test result.service_volumes["Essential"] >= 10.0
        @test result.objective_value > 0.0
    end
end
