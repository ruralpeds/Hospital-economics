# ============================================================================
# Tests for ODE-based system dynamics model
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "types", "abstract.jl"))

# ---------------------------------------------------------------------------
# Stub system dynamics ODE model (until DifferentialEquations integration)
# ---------------------------------------------------------------------------

"""
System state vector for rural hospital dynamics:
  u[1] = patient_volume (normalized, 1.0 = baseline)
  u[2] = cash_reserves (dollars)
  u[3] = staff_level (FTEs)
  u[4] = community_health_index (0-1)
  u[5] = hospital_quality (0-1)
"""

struct SystemDynamicsParams
    revenue_per_patient::Float64
    cost_per_fte::Float64
    supply_cost_per_patient::Float64
    overhead_cost::Float64
    staff_hiring_rate::Float64
    staff_attrition_rate::Float64
    volume_sensitivity_to_quality::Float64
    quality_sensitivity_to_staff::Float64
    community_health_decay::Float64
    cash_burn_threshold::Float64
end

function SystemDynamicsParams(;
    revenue_per_patient=5000.0,
    cost_per_fte=85000.0,
    supply_cost_per_patient=1200.0,
    overhead_cost=2_000_000.0,
    staff_hiring_rate=0.10,
    staff_attrition_rate=0.08,
    volume_sensitivity_to_quality=0.5,
    quality_sensitivity_to_staff=0.3,
    community_health_decay=0.02,
    cash_burn_threshold=500_000.0,
)
    SystemDynamicsParams(
        revenue_per_patient, cost_per_fte, supply_cost_per_patient,
        overhead_cost, staff_hiring_rate, staff_attrition_rate,
        volume_sensitivity_to_quality, quality_sensitivity_to_staff,
        community_health_decay, cash_burn_threshold,
    )
end

"""
    hospital_ode!(du, u, p, t)

ODE system for hospital dynamics. Right-hand side function.
"""
function hospital_ode!(du, u, p::SystemDynamicsParams, t)
    volume, cash, staff, community_health, quality = u

    # Revenue and costs
    annual_patients = volume * 2000  # baseline 2000 patients/year
    revenue = annual_patients * p.revenue_per_patient
    salary_cost = staff * p.cost_per_fte
    supply_cost = annual_patients * p.supply_cost_per_patient
    total_cost = salary_cost + supply_cost + p.overhead_cost

    net_income = revenue - total_cost

    # du[1]: volume changes with quality and community health
    du[1] = p.volume_sensitivity_to_quality * (quality - 0.7) * volume +
            0.1 * (community_health - 0.5) * volume

    # du[2]: cash changes with net income
    du[2] = net_income

    # du[3]: staffing adjusts based on cash position
    hiring_signal = cash > p.cash_burn_threshold ? p.staff_hiring_rate : -p.staff_attrition_rate
    du[3] = hiring_signal * staff * 0.1

    # du[4]: community health affected by hospital presence and quality
    du[4] = 0.05 * quality - p.community_health_decay * community_health

    # du[5]: quality depends on staffing levels
    target_staff = 80.0  # target FTEs
    du[5] = p.quality_sensitivity_to_staff * (staff / target_staff - 1.0) * (1.0 - quality)

    return nothing
end

"""Simple Euler integration for testing purposes."""
function euler_integrate(f!, u0, params, tspan, dt)
    t = tspan[1]
    u = copy(u0)
    trajectory = [(t=t, u=copy(u))]

    while t < tspan[2]
        du = similar(u)
        f!(du, u, params, t)
        u .= u .+ dt .* du
        t += dt
        push!(trajectory, (t=t, u=copy(u)))
    end

    return trajectory
end

@testset "System Dynamics (ODE)" begin

    # -----------------------------------------------------------------------
    @testset "SystemDynamicsParams defaults" begin
        p = SystemDynamicsParams()
        @test p.revenue_per_patient == 5000.0
        @test p.cost_per_fte == 85000.0
        @test p.supply_cost_per_patient == 1200.0
        @test p.overhead_cost == 2_000_000.0
        @test p.staff_hiring_rate == 0.10
        @test p.staff_attrition_rate == 0.08
        @test p.volume_sensitivity_to_quality == 0.5
        @test p.quality_sensitivity_to_staff == 0.3
    end

    # -----------------------------------------------------------------------
    @testset "ODE right-hand side computation" begin
        p = SystemDynamicsParams()
        # Initial state: baseline volume, healthy cash, adequate staff, good community, decent quality
        u = [1.0, 3_000_000.0, 80.0, 0.7, 0.8]
        du = zeros(5)

        hospital_ode!(du, u, p, 0.0)

        # du should be computed (non-NaN, finite)
        @test all(isfinite, du)

        # With quality=0.8 > 0.7, volume should be increasing
        @test du[1] > 0.0

        # With adequate volume and staff, cash flow may be positive or negative
        @test isfinite(du[2])

        # With healthy cash, staffing should be growing
        @test du[3] > 0.0

        # Community health should be positive with good quality
        @test du[4] > 0.0
    end

    # -----------------------------------------------------------------------
    @testset "ODE stressed scenario" begin
        p = SystemDynamicsParams()
        # Low volume, low cash, understaffed, poor community health, low quality
        u = [0.5, 100_000.0, 40.0, 0.3, 0.4]
        du = zeros(5)

        hospital_ode!(du, u, p, 0.0)

        @test all(isfinite, du)

        # With quality=0.4 < 0.7, volume should be decreasing
        @test du[1] < 0.0

        # With low cash, staff should be declining
        @test du[3] < 0.0
    end

    # -----------------------------------------------------------------------
    @testset "Euler integration — stable scenario" begin
        p = SystemDynamicsParams()
        u0 = [1.0, 3_000_000.0, 80.0, 0.7, 0.8]
        tspan = (0.0, 5.0)
        dt = 0.1

        trajectory = euler_integrate(hospital_ode!, u0, p, tspan, dt)

        @test length(trajectory) > 1
        @test trajectory[1].t == 0.0
        @test trajectory[end].t >= 5.0

        # Volume should remain positive
        @test all(step -> step.u[1] > 0.0, trajectory)

        # Quality should remain bounded
        final_quality = trajectory[end].u[5]
        @test isfinite(final_quality)
    end

    # -----------------------------------------------------------------------
    @testset "Euler integration — declining hospital" begin
        p = SystemDynamicsParams(;
            revenue_per_patient=3500.0,  # lower revenue
            overhead_cost=3_000_000.0,   # higher overhead
        )
        u0 = [0.7, 500_000.0, 50.0, 0.4, 0.5]
        tspan = (0.0, 3.0)
        dt = 0.1

        trajectory = euler_integrate(hospital_ode!, u0, p, tspan, dt)

        # Cash should be declining in this stressed scenario
        initial_cash = trajectory[1].u[2]
        final_cash = trajectory[end].u[2]
        @test final_cash < initial_cash
    end

    # -----------------------------------------------------------------------
    @testset "Conservation of state dimensions" begin
        p = SystemDynamicsParams()
        u0 = [1.0, 2_000_000.0, 70.0, 0.6, 0.75]
        tspan = (0.0, 1.0)
        dt = 0.5

        trajectory = euler_integrate(hospital_ode!, u0, p, tspan, dt)
        for step in trajectory
            @test length(step.u) == 5
        end
    end
end
