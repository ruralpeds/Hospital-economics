"""
    test_episode_cost_models.jl

Unit tests for Episode cost calculation models (Phase 1.1)
"""

using Test
using Dates

# Include modules
include("../src/episode/Episode.jl")
include("../src/episode/EpisodeCostModels.jl")

# Helper: Create test episode
function make_test_episode(;
    id::String="EP001",
    admission=Date(2026, 4, 1),
    discharge=Date(2026, 4, 5),
    primary_drg::String="247",
    secondary_diagnoses=String[],
    procedures=String[],
    service_line::String="Cardiology",
    payer::Payer=Medicare
)
    Episode(
        episode_id=id,
        patient_id="PT001",
        admission_date=admission,
        discharge_date=discharge,
        primary_diagnosis="I21",
        drg_code=primary_drg,
        secondary_diagnoses=secondary_diagnoses,
        procedures=procedures,
        payer=payer,
        setting=service_line,
        metadata=Dict{String, Any}("service_line" => service_line)
    )
end

@testset "Phase 1.1: EpisodeCostModels" begin

    # ========================================================================
    # DRG Cost Model Tests
    # ========================================================================

    @testset "DRGCostModel construction" begin
        model = DRGCostModel(
            Dict("247" => 18_000.0),
            Dict("MD" => 200.0),
            Dict("CC" => 1.25),
            1.0,
            2_500.0,
            25.0
        )
        @test model.hospital_wage_index == 1.0
        @test model.cost_per_day == 2_500.0
    end

    @testset "DRG cost calculation" begin
        model = create_standard_drg_model()
        ep = make_test_episode(primary_drg="247")
        cost = calculate_drg_cost(ep, model)
        @test cost > 10_000.0
        @test cost < 50_000.0
    end

    @testset "DRG cost with comorbidities" begin
        model = create_standard_drg_model()
        ep_simple = make_test_episode(secondary_diagnoses=String[])
        ep_complex = make_test_episode(secondary_diagnoses=["CC_001"])

        cost_simple = calculate_drg_cost(ep_simple, model)
        cost_complex = calculate_drg_cost(ep_complex, model)

        @test cost_complex >= cost_simple
    end

    @testset "DRG cost length of stay impact" begin
        model = create_standard_drg_model()
        ep_short = make_test_episode(
            id="SHORT",
            admission=Date(2026, 4, 1),
            discharge=Date(2026, 4, 2)
        )
        ep_long = make_test_episode(
            id="LONG",
            admission=Date(2026, 4, 1),
            discharge=Date(2026, 4, 8)
        )

        cost_short = calculate_drg_cost(ep_short, model)
        cost_long = calculate_drg_cost(ep_long, model)

        @test cost_long > cost_short
    end

    @testset "DRG cost geographic adjustment" begin
        base_model = create_standard_drg_model()

        high_wage = DRGCostModel(
            base_model.base_costs,
            base_model.labor_rates,
            base_model.comorbidity_adjusters,
            1.1,
            base_model.cost_per_day,
            base_model.cost_per_OR_minute
        )

        low_wage = DRGCostModel(
            base_model.base_costs,
            base_model.labor_rates,
            base_model.comorbidity_adjusters,
            0.9,
            base_model.cost_per_day,
            base_model.cost_per_OR_minute
        )

        ep = make_test_episode()
        cost_high = calculate_drg_cost(ep, high_wage)
        cost_low = calculate_drg_cost(ep, low_wage)

        @test cost_high > cost_low
    end

    # ========================================================================
    # RVU Cost Model Tests
    # ========================================================================

    @testset "RVUCostModel construction" begin
        model = RVUCostModel(
            Dict("OR" => 40.0),
            35.0,
            Dict("MD" => 0.3),
            1.0,
            Dict("501" => 45.0)
        )
        @test model.conversion_factor == 35.0
    end

    @testset "RVU cost calculation" begin
        model = create_standard_rvu_model()
        ep = make_test_episode()
        cost = calculate_rvu_cost(ep, model)
        @test cost > 5_000.0
        @test cost < 50_000.0
    end

    @testset "RVU cost with procedures" begin
        model = create_standard_rvu_model()
        ep_no_proc = make_test_episode(procedures=String[])
        ep_with_proc = make_test_episode(procedures=["501"])

        cost_no_proc = calculate_rvu_cost(ep_no_proc, model)
        cost_with_proc = calculate_rvu_cost(ep_with_proc, model)

        @test cost_with_proc > cost_no_proc
    end

    # ========================================================================
    # ABC Cost Model Tests
    # ========================================================================

    @testset "ActivityBasedCostModel construction" begin
        model = ActivityBasedCostModel(
            75.0, 800.0, 400.0,
            Dict("lab" => 50.0),
            Dict("501" => 2_500.0)
        )
        @test model.direct_labor_rate == 75.0
    end

    @testset "ABC cost calculation" begin
        model = create_standard_abc_model()
        ep = make_test_episode()
        cost = calculate_abc_cost(ep, model)
        @test cost > 5_000.0
        @test cost < 30_000.0
    end

    @testset "ABC cost ICU vs Floor" begin
        model = create_standard_abc_model()
        ep_floor = make_test_episode(service_line="Cardiology")
        ep_icu = make_test_episode(service_line="ICU")

        cost_floor = calculate_abc_cost(ep_floor, model)
        cost_icu = calculate_abc_cost(ep_icu, model)

        @test cost_icu > cost_floor
    end

    @testset "ABC cost with procedures" begin
        model = create_standard_abc_model()
        ep_no_proc = make_test_episode(procedures=String[])
        ep_with_proc = make_test_episode(procedures=["501"])

        cost_no_proc = calculate_abc_cost(ep_no_proc, model)
        cost_with_proc = calculate_abc_cost(ep_with_proc, model)

        @test cost_with_proc > cost_no_proc
    end

    # ========================================================================
    # Unified Interface Tests
    # ========================================================================

    @testset "calculate_episode_cost dispatch" begin
        ep = make_test_episode()

        drg_model = create_standard_drg_model()
        rvu_model = create_standard_rvu_model()
        abc_model = create_standard_abc_model()

        cost_drg = calculate_episode_cost(ep, drg_model)
        cost_rvu = calculate_episode_cost(ep, rvu_model)
        cost_abc = calculate_episode_cost(ep, abc_model)

        @test cost_drg > 0
        @test cost_rvu > 0
        @test cost_abc > 0
    end

    @testset "compare_costing_methods" begin
        ep = make_test_episode()
        costs = compare_costing_methods(ep)

        @test haskey(costs, "DRG")
        @test haskey(costs, "RVU")
        @test haskey(costs, "ABC")

        for (method, cost) in costs
            @test cost > 0
        end
    end

    @testset "costing methods reasonable ranges" begin
        ep = make_test_episode()
        costs = compare_costing_methods(ep)

        for (method, cost) in costs
            @test 5_000.0 < cost < 100_000.0
        end

        values_vec = collect(values(costs))
        ratio = maximum(values_vec) / minimum(values_vec)
        @test ratio < 5.0  # Different methods can differ by 2-4×
    end

    # ========================================================================
    # Model Factories
    # ========================================================================

    @testset "Standard model factories" begin
        drg = create_standard_drg_model()
        rvu = create_standard_rvu_model()
        abc = create_standard_abc_model()

        @test !isempty(drg.base_costs)
        @test !isempty(rvu.specialty_rvu_base)
        @test abc.direct_labor_rate > 0
    end

end

println("\n✅ Phase 1.1: All EpisodeCostModels tests passed!")
