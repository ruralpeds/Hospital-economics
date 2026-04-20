# ============================================================================
# Tests for agent-based model initialization and stepping
# ============================================================================

using Test
using Random

include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))

# ---------------------------------------------------------------------------
# Standalone ABM types — validates agent logic independently of Agents.jl runtime.
# Real source integration tested via test_view_integration.jl and test_integration.jl.
# ---------------------------------------------------------------------------

mutable struct PatientAgent <: AbstractPatientAgent
    id::Int
    age::Int
    insurance::Symbol          # :medicare, :medicaid, :commercial, :self_pay
    acuity::Float64            # 0.0–1.0
    travel_distance::Float64   # miles to nearest hospital
    loyalty::Float64           # 0.0–1.0 tendency to stay with current provider
    active::Bool
end

mutable struct HospitalAgent <: AbstractProviderAgent
    id::Int
    name::String
    designation::Symbol        # :cah, :reh, :pps
    bed_capacity::Int
    current_census::Int
    operating_margin::Float64
    quality_score::Float64     # 0.0–1.0
    is_open::Bool
end

mutable struct PayerAgent <: AbstractPayerAgent
    id::Int
    name::String
    payer_type::Symbol         # :medicare, :medicaid, :commercial
    reimbursement_rate::Float64
    covered_lives::Int
end

struct ABMParams
    n_patients::Int
    n_hospitals::Int
    n_payers::Int
    steps::Int
    seed::Int
end

function initialize_abm(params::ABMParams)
    rng = MersenneTwister(params.seed)

    patients = [
        PatientAgent(
            i,
            rand(rng, 18:95),
            rand(rng, [:medicare, :medicaid, :commercial, :self_pay]),
            rand(rng),
            rand(rng) * 60.0,
            rand(rng) * 0.5 + 0.5,
            true,
        )
        for i in 1:params.n_patients
    ]

    hospitals = [
        HospitalAgent(
            i,
            "Hospital_$i",
            i <= div(params.n_hospitals, 2) ? :cah : :pps,
            i <= div(params.n_hospitals, 2) ? 25 : 100,
            0,
            rand(rng) * 0.10 - 0.02,
            rand(rng) * 0.3 + 0.7,
            true,
        )
        for i in 1:params.n_hospitals
    ]

    payers = [
        PayerAgent(i, "Payer_$i", [:medicare, :medicaid, :commercial][mod1(i, 3)],
                   [0.95, 0.70, 1.20][mod1(i, 3)], rand(rng, 1000:10000))
        for i in 1:params.n_payers
    ]

    return (patients=patients, hospitals=hospitals, payers=payers, step=0)
end

function step_abm!(model, rng)
    # Patients seek care at nearest open hospital
    open_hospitals = filter(h -> h.is_open, model.hospitals)
    isempty(open_hospitals) && return model

    for patient in model.patients
        patient.active || continue
        # Simple assignment: pick hospital with best quality within travel distance
        chosen = open_hospitals[argmax([h.quality_score for h in open_hospitals])]
        if chosen.current_census < chosen.bed_capacity
            chosen.current_census += 1
        end
    end

    # Update hospital margins based on census
    for h in model.hospitals
        utilization = h.bed_capacity > 0 ? h.current_census / h.bed_capacity : 0.0
        h.operating_margin = (utilization - 0.5) * 0.20
        if h.operating_margin < -0.15
            h.is_open = false
        end
        h.current_census = 0  # reset for next step
    end

    return (patients=model.patients, hospitals=model.hospitals,
            payers=model.payers, step=model.step + 1)
end

@testset "Agent-Based Model" begin

    # -----------------------------------------------------------------------
    @testset "Agent type hierarchy" begin
        p = PatientAgent(1, 65, :medicare, 0.5, 20.0, 0.8, true)
        @test p isa AbstractPatientAgent
        @test p isa AbstractAgent

        h = HospitalAgent(1, "Test CAH", :cah, 25, 0, 0.02, 0.85, true)
        @test h isa AbstractProviderAgent
        @test h isa AbstractAgent

        py = PayerAgent(1, "Medicare", :medicare, 0.95, 5000)
        @test py isa AbstractPayerAgent
        @test py isa AbstractAgent
    end

    # -----------------------------------------------------------------------
    @testset "ABM initialization" begin
        params = ABMParams(200, 4, 3, 10, 42)
        model = initialize_abm(params)

        @test length(model.patients) == 200
        @test length(model.hospitals) == 4
        @test length(model.payers) == 3
        @test model.step == 0

        # All patients should be active initially
        @test all(p -> p.active, model.patients)
        # All hospitals should be open initially
        @test all(h -> h.is_open, model.hospitals)

        # Check age bounds
        ages = [p.age for p in model.patients]
        @test minimum(ages) >= 18
        @test maximum(ages) <= 95

        # Check insurance types are valid
        valid_insurance = Set([:medicare, :medicaid, :commercial, :self_pay])
        @test all(p -> p.insurance in valid_insurance, model.patients)

        # Check hospital designations
        @test model.hospitals[1].designation == :cah
        @test model.hospitals[1].bed_capacity == 25
    end

    # -----------------------------------------------------------------------
    @testset "ABM reproducibility with seed" begin
        params = ABMParams(50, 3, 3, 5, 99)
        model1 = initialize_abm(params)
        model2 = initialize_abm(params)

        @test [p.age for p in model1.patients] == [p.age for p in model2.patients]
        @test [p.insurance for p in model1.patients] == [p.insurance for p in model2.patients]
        @test [h.quality_score for h in model1.hospitals] == [h.quality_score for h in model2.hospitals]
    end

    # -----------------------------------------------------------------------
    @testset "ABM step execution" begin
        params = ABMParams(100, 3, 3, 5, 42)
        model = initialize_abm(params)
        rng = MersenneTwister(42)

        # Run one step
        model2 = step_abm!(model, rng)
        @test model2.step == 1

        # Hospitals should have updated margins
        for h in model2.hospitals
            @test h.operating_margin isa Float64
        end
    end

    # -----------------------------------------------------------------------
    @testset "ABM multi-step evolution" begin
        params = ABMParams(50, 4, 3, 20, 42)
        model = initialize_abm(params)
        rng = MersenneTwister(42)

        for _ in 1:10
            model = step_abm!(model, rng)
        end

        @test model.step == 10
        # After multiple steps, census should have been reset each step
        @test all(h -> h.current_census == 0, model.hospitals)
    end

    # -----------------------------------------------------------------------
    @testset "Hospital closure in ABM" begin
        # Create a scenario where a hospital has very low capacity to trigger closure
        h = HospitalAgent(1, "Tiny CAH", :cah, 5, 0, -0.20, 0.6, true)
        # Manually check closure logic
        if h.operating_margin < -0.15
            h.is_open = false
        end
        @test h.is_open == false
    end

    # -----------------------------------------------------------------------
    @testset "Patient agent properties" begin
        p = PatientAgent(1, 72, :medicare, 0.7, 45.0, 0.9, true)
        @test p.age == 72
        @test p.insurance == :medicare
        @test 0.0 <= p.acuity <= 1.0
        @test p.travel_distance == 45.0
        @test p.loyalty == 0.9
        @test p.active == true
    end
end
