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

    # ========================================================================
    # Additional DRG Cost Model Tests
    # ========================================================================

    @testset "DRG cost MCC comorbidity" begin
        model = create_standard_drg_model()
        ep_plain = make_test_episode(secondary_diagnoses=String[])
        ep_cc    = make_test_episode(secondary_diagnoses=["CC_hypertension"])
        ep_mcc   = make_test_episode(secondary_diagnoses=["MCC_sepsis"])

        cost_plain = calculate_drg_cost(ep_plain, model)
        cost_cc    = calculate_drg_cost(ep_cc, model)
        cost_mcc   = calculate_drg_cost(ep_mcc, model)

        @test cost_cc  > cost_plain
        @test cost_mcc > cost_cc
    end

    @testset "DRG cost unknown DRG uses default" begin
        model = create_standard_drg_model()
        ep = make_test_episode(primary_drg="UNKNOWN_999")
        cost = calculate_drg_cost(ep, model)
        # Default base cost is 15_000.0 — result must be positive
        @test cost > 0.0
    end

    @testset "DRG cost zero LOS same-day episode" begin
        model = create_standard_drg_model()
        ep = make_test_episode(
            id="SAMEDAY",
            admission=Date(2026, 4, 1),
            discharge=Date(2026, 4, 1)
        )
        cost = calculate_drg_cost(ep, model)
        @test cost >= 0.0
    end

    @testset "DRG cost multiple procedures additive" begin
        model = create_standard_drg_model()
        ep_none = make_test_episode(procedures=String[])
        ep_one  = make_test_episode(procedures=["501"])
        ep_two  = make_test_episode(procedures=["501", "502"])

        cost_none = calculate_drg_cost(ep_none, model)
        cost_one  = calculate_drg_cost(ep_one, model)
        cost_two  = calculate_drg_cost(ep_two, model)

        @test cost_one > cost_none
        @test cost_two > cost_one
    end

    @testset "DRG cost extended LOS" begin
        model = create_standard_drg_model()
        ep_short  = make_test_episode(admission=Date(2026, 4, 1), discharge=Date(2026, 4, 4))   # 3 days
        ep_medium = make_test_episode(admission=Date(2026, 4, 1), discharge=Date(2026, 4, 8))   # 7 days
        ep_long   = make_test_episode(admission=Date(2026, 4, 1), discharge=Date(2026, 4, 15))  # 14 days

        cost_short  = calculate_drg_cost(ep_short,  model)
        cost_medium = calculate_drg_cost(ep_medium, model)
        cost_long   = calculate_drg_cost(ep_long,   model)

        @test cost_medium > cost_short
        @test cost_long   > cost_medium
    end

    @testset "DRG known DRG codes produce expected ranges" begin
        model = create_standard_drg_model()
        drg_codes = ["246", "247", "469", "470", "373", "374"]
        for code in drg_codes
            ep = make_test_episode(primary_drg=code)
            cost = calculate_drg_cost(ep, model)
            @test cost > 5_000.0
            @test cost < 200_000.0
        end
    end

    # ========================================================================
    # Additional RVU Cost Model Tests
    # ========================================================================

    @testset "RVU cost OR setting higher than IP" begin
        model = create_standard_rvu_model()
        ep_ip = make_test_episode(service_line="Inpatient")
        ep_or = make_test_episode(service_line="OR Suite")

        cost_ip = calculate_rvu_cost(ep_ip, model)
        cost_or = calculate_rvu_cost(ep_or, model)

        @test cost_or > cost_ip
    end

    @testset "RVU cost ED setting" begin
        model = create_standard_rvu_model()
        ep_ed = make_test_episode(service_line="ED Department")
        cost = calculate_rvu_cost(ep_ed, model)
        @test cost > 0.0
    end

    @testset "RVU cost multiple procedures" begin
        model = create_standard_rvu_model()
        ep_one   = make_test_episode(procedures=["501"])
        ep_two   = make_test_episode(procedures=["501", "502"])
        ep_three = make_test_episode(procedures=["501", "502", "503"])

        cost_one   = calculate_rvu_cost(ep_one,   model)
        cost_two   = calculate_rvu_cost(ep_two,   model)
        cost_three = calculate_rvu_cost(ep_three, model)

        @test cost_two   > cost_one
        @test cost_three > cost_two
    end

    @testset "RVU cost unknown procedure uses default RVU" begin
        model = create_standard_rvu_model()
        ep = make_test_episode(procedures=["UNKNOWN_PROC"])
        cost = calculate_rvu_cost(ep, model)
        @test cost > 0.0  # default RVU applied
    end

    @testset "RVU wage index geographic adjustment" begin
        base = create_standard_rvu_model()
        high_wage_model = RVUCostModel(
            base.specialty_rvu_base, base.conversion_factor,
            base.labor_allocation, 1.20, base.rvu_per_procedure
        )
        low_wage_model = RVUCostModel(
            base.specialty_rvu_base, base.conversion_factor,
            base.labor_allocation, 0.80, base.rvu_per_procedure
        )
        ep = make_test_episode()
        @test calculate_rvu_cost(ep, high_wage_model) > calculate_rvu_cost(ep, low_wage_model)
    end

    @testset "RVU conversion factor impact" begin
        base = create_standard_rvu_model()
        high_cf_model = RVUCostModel(
            base.specialty_rvu_base, 50.0,
            base.labor_allocation, base.hospital_wage_index, base.rvu_per_procedure
        )
        low_cf_model = RVUCostModel(
            base.specialty_rvu_base, 20.0,
            base.labor_allocation, base.hospital_wage_index, base.rvu_per_procedure
        )
        ep = make_test_episode()
        @test calculate_rvu_cost(ep, high_cf_model) > calculate_rvu_cost(ep, low_cf_model)
    end

    @testset "RVU LOS increases total cost" begin
        model = create_standard_rvu_model()
        ep_short = make_test_episode(admission=Date(2026, 4, 1), discharge=Date(2026, 4, 2))
        ep_long  = make_test_episode(admission=Date(2026, 4, 1), discharge=Date(2026, 4, 10))
        @test calculate_rvu_cost(ep_long, model) > calculate_rvu_cost(ep_short, model)
    end

    # ========================================================================
    # Additional ABC Cost Model Tests
    # ========================================================================

    @testset "ABC cost OR setting" begin
        model = create_standard_abc_model()
        ep_floor = make_test_episode(service_line="General Medicine")
        ep_or    = make_test_episode(service_line="OR Suite")

        cost_floor = calculate_abc_cost(ep_floor, model)
        cost_or    = calculate_abc_cost(ep_or, model)

        @test cost_or > cost_floor
    end

    @testset "ABC cost trauma overhead" begin
        model = create_standard_abc_model()
        ep_normal = make_test_episode()
        ep_trauma = Episode(
            episode_id="TRAUMA001",
            patient_id="PT002",
            admission_date=Date(2026, 4, 1),
            discharge_date=Date(2026, 4, 5),
            primary_diagnosis="S71.001",  # Trauma code triggers transfusion overhead
            drg_code="247",
            setting="Hospital",
            metadata=Dict{String, Any}()
        )
        cost_normal = calculate_abc_cost(ep_normal, model)
        cost_trauma = calculate_abc_cost(ep_trauma, model)

        @test cost_trauma > cost_normal
    end

    @testset "ABC cost longer stay increases cost" begin
        model = create_standard_abc_model()
        ep_2day  = make_test_episode(admission=Date(2026, 4, 1), discharge=Date(2026, 4, 3))
        ep_5day  = make_test_episode(admission=Date(2026, 4, 1), discharge=Date(2026, 4, 6))
        ep_10day = make_test_episode(admission=Date(2026, 4, 1), discharge=Date(2026, 4, 11))

        @test calculate_abc_cost(ep_5day, model)  > calculate_abc_cost(ep_2day,  model)
        @test calculate_abc_cost(ep_10day, model) > calculate_abc_cost(ep_5day,  model)
    end

    @testset "ABC cost unknown procedure uses default supply cost" begin
        model = create_standard_abc_model()
        ep = make_test_episode(procedures=["PROC_XYZ"])
        cost = calculate_abc_cost(ep, model)
        @test cost > 0.0
    end

    @testset "ABC custom overhead drivers" begin
        high_overhead = ActivityBasedCostModel(
            75.0, 800.0, 400.0,
            Dict("lab_test" => 200.0, "imaging" => 500.0, "transfusion" => 800.0),
            Dict("501" => 2_500.0)
        )
        low_overhead = ActivityBasedCostModel(
            75.0, 800.0, 400.0,
            Dict("lab_test" => 10.0, "imaging" => 50.0, "transfusion" => 100.0),
            Dict("501" => 2_500.0)
        )
        ep = make_test_episode()
        @test calculate_abc_cost(ep, high_overhead) > calculate_abc_cost(ep, low_overhead)
    end

    # ========================================================================
    # Sensitivity Analysis (±20% on key drivers)
    # ========================================================================

    @testset "DRG sensitivity: wage index ±20%" begin
        base = create_standard_drg_model()
        ep = make_test_episode()
        base_cost = calculate_drg_cost(ep, base)

        high_model = DRGCostModel(base.base_costs, base.labor_rates,
            base.comorbidity_adjusters, 1.2, base.cost_per_day, base.cost_per_OR_minute)
        low_model  = DRGCostModel(base.base_costs, base.labor_rates,
            base.comorbidity_adjusters, 0.8, base.cost_per_day, base.cost_per_OR_minute)

        @test calculate_drg_cost(ep, high_model) > base_cost
        @test calculate_drg_cost(ep, low_model)  < base_cost
    end

    @testset "DRG sensitivity: cost per day ±20%" begin
        base = create_standard_drg_model()
        ep = make_test_episode()
        base_cost = calculate_drg_cost(ep, base)

        high_model = DRGCostModel(base.base_costs, base.labor_rates,
            base.comorbidity_adjusters, base.hospital_wage_index, base.cost_per_day * 1.2, base.cost_per_OR_minute)
        low_model  = DRGCostModel(base.base_costs, base.labor_rates,
            base.comorbidity_adjusters, base.hospital_wage_index, base.cost_per_day * 0.8, base.cost_per_OR_minute)

        @test calculate_drg_cost(ep, high_model) > base_cost
        @test calculate_drg_cost(ep, low_model)  < base_cost
    end

    @testset "RVU sensitivity: conversion factor ±20%" begin
        base = create_standard_rvu_model()
        ep = make_test_episode()
        base_cost = calculate_rvu_cost(ep, base)

        high_model = RVUCostModel(base.specialty_rvu_base, base.conversion_factor * 1.2,
            base.labor_allocation, base.hospital_wage_index, base.rvu_per_procedure)
        low_model  = RVUCostModel(base.specialty_rvu_base, base.conversion_factor * 0.8,
            base.labor_allocation, base.hospital_wage_index, base.rvu_per_procedure)

        @test calculate_rvu_cost(ep, high_model) > base_cost
        @test calculate_rvu_cost(ep, low_model)  < base_cost
    end

    @testset "ABC sensitivity: labor rate ±20%" begin
        base = create_standard_abc_model()
        ep = make_test_episode()
        base_cost = calculate_abc_cost(ep, base)

        high_model = ActivityBasedCostModel(
            base.direct_labor_rate * 1.2, base.supply_cost_per_day,
            base.bed_cost_per_day, base.overhead_drivers, base.procedure_supply_cost)
        low_model  = ActivityBasedCostModel(
            base.direct_labor_rate * 0.8, base.supply_cost_per_day,
            base.bed_cost_per_day, base.overhead_drivers, base.procedure_supply_cost)

        @test calculate_abc_cost(ep, high_model) > base_cost
        @test calculate_abc_cost(ep, low_model)  < base_cost
    end

    # ========================================================================
    # Cost Accumulation Across Episodes
    # ========================================================================

    @testset "Cost accumulation multiple episodes" begin
        model = create_standard_drg_model()
        episodes = [
            make_test_episode(id="E$i", primary_drg="247") for i in 1:5
        ]
        costs = [calculate_episode_cost(ep, model) for ep in episodes]
        total = sum(costs)

        @test total > 0.0
        @test length(costs) == 5
        @test total ≈ 5 * costs[1]  # All identical episodes should have equal cost
    end

    @testset "Cost accumulation mixed DRG codes" begin
        model = create_standard_drg_model()
        episodes = [
            make_test_episode(id="CARD", primary_drg="246"),  # Expensive
            make_test_episode(id="OBSTET", primary_drg="373"),  # Less expensive
        ]
        cost_card   = calculate_episode_cost(episodes[1], model)
        cost_obstet = calculate_episode_cost(episodes[2], model)
        total = cost_card + cost_obstet

        @test total > cost_card
        @test total > cost_obstet
        @test cost_card > cost_obstet  # Cardiology base cost higher than OB
    end

    # ========================================================================
    # Validation
    # ========================================================================

    @testset "validate_cost_calculation returns true" begin
        ep = make_test_episode()
        costs = compare_costing_methods(ep)
        avg_cost = sum(values(costs)) / length(costs)
        result = validate_cost_calculation(ep, avg_cost, 1.0)  # 100% tolerance — should always pass
        @test result == true
    end

    @testset "All cost models return Float64" begin
        drg = create_standard_drg_model()
        rvu = create_standard_rvu_model()
        abc = create_standard_abc_model()
        ep  = make_test_episode()

        @test typeof(calculate_episode_cost(ep, drg)) == Float64
        @test typeof(calculate_episode_cost(ep, rvu)) == Float64
        @test typeof(calculate_episode_cost(ep, abc)) == Float64
    end

    @testset "All cost models return non-negative values" begin
        drg = create_standard_drg_model()
        rvu = create_standard_rvu_model()
        abc = create_standard_abc_model()

        test_episodes = [
            make_test_episode(id="T1", procedures=String[]),
            make_test_episode(id="T2", procedures=["501"]),
            make_test_episode(id="T3", secondary_diagnoses=["CC_001"]),
            make_test_episode(id="T4", service_line="ICU"),
        ]
        for ep in test_episodes
            @test calculate_episode_cost(ep, drg) >= 0.0
            @test calculate_episode_cost(ep, rvu) >= 0.0
            @test calculate_episode_cost(ep, abc) >= 0.0
        end
    end

end

println("\n✅ Phase 1.1: All EpisodeCostModels tests passed!")
