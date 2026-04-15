using Test
using HospitalFinanceToolbox
using Dates
using Distributions
using Statistics

@testset "HospitalFinanceToolbox Tests" begin
    
    # ═══════════════════════════════════════════════════════════════
    # EPISODE CONSTRUCTION AND VALIDATION
    # ═══════════════════════════════════════════════════════════════
    
    @testset "Episode Construction" begin
        ep = Episode(
            episode_id = "EP001",
            patient_id = "PT001",
            admission_date = Date(2024, 1, 1),
            discharge_date = Date(2024, 1, 8),
            primary_diagnosis = "I10",
            drg_code = "291"
        )
        
        @test ep.episode_id == "EP001"
        @test ep.patient_id == "PT001"
        @test ep.los == 7
        @test ep.payer == Medicare
    end
    
    @testset "Episode with Complications" begin
        ep = Episode(
            episode_id = "EP002",
            patient_id = "PT002",
            admission_date = Date(2024, 1, 1),
            discharge_date = Date(2024, 1, 10),
            primary_diagnosis = "E11",
            drg_code = "640",
            complications = ["E11.22", "I10"],
            procedures = ["36.15", "31.1"]
        )
        
        @test length(ep.complications) == 2
        @test length(ep.procedures) == 2
    end
    
    # ═══════════════════════════════════════════════════════════════
    # COST MODEL CALCULATIONS
    # ═══════════════════════════════════════════════════════════════
    
    @testset "DRG Cost Model - Base Case" begin
        model = DRGCostModel()
        ep = Episode(
            episode_id = "EP003",
            patient_id = "PT003",
            admission_date = Date(2024, 1, 1),
            discharge_date = Date(2024, 1, 6),
            primary_diagnosis = "I10",
            drg_code = "291"
        )
        
        cost = calculate_episode_cost(ep, model)
        @test cost > 0
        @test cost ≈ 6800.0 * 1.0  # DRG rate × payer multiplier for Medicare
    end
    
    @testset "DRG Cost Model - With Complications" begin
        model = DRGCostModel(
            complication_multiplier = 0.25
        )
        ep = Episode(
            episode_id = "EP004",
            patient_id = "PT004",
            admission_date = Date(2024, 1, 1),
            discharge_date = Date(2024, 1, 6),
            primary_diagnosis = "I10",
            drg_code = "291",
            complications = ["I11", "E11"]  # 2 complications
        )
        
        cost = calculate_episode_cost(ep, model)
        base_cost = 6800.0
        complication_cost = 2 * base_cost * 0.25
        expected_cost = (base_cost + complication_cost) * 1.0
        
        @test cost ≈ expected_cost
    end
    
    @testset "Cost Breakdown by Component" begin
        model = DRGCostModel(
            procedure_costs = Dict("36.15" => 2500.0)
        )
        ep = Episode(
            episode_id = "EP005",
            patient_id = "PT005",
            admission_date = Date(2024, 1, 1),
            discharge_date = Date(2024, 1, 6),
            primary_diagnosis = "I10",
            drg_code = "291",
            procedures = ["36.15"]
        )
        
        breakdown = episode_cost_breakdown(ep, model)
        @test breakdown["base_drg"] == 6800.0
        @test breakdown["procedures"] == 2500.0
    end
    
    # ═══════════════════════════════════════════════════════════════
    # OUTCOME CONSTRUCTION AND VALIDATION
    # ═══════════════════════════════════════════════════════════════
    
    @testset "Episode Outcomes Construction" begin
        outcomes = EpisodeOutcomes(
            episode_id = "EP006",
            survived = true,
            qaly_gained = 0.85,
            total_cost = 50_000.0
        )
        
        @test outcomes.survived == true
        @test outcomes.qaly_gained == 0.85
        @test outcomes.total_cost == 50_000.0
        @test outcomes.status == Alive
    end
    
    @testset "Episode Outcomes - Death Case" begin
        outcomes = EpisodeOutcomes(
            episode_id = "EP007",
            survived = false,
            status = Dead,
            qaly_gained = 0.1,
            total_cost = 35_000.0
        )
        
        @test outcomes.survived == false
        @test outcomes.status == Dead
    end
    
    @testset "Episode Summary Statistics" begin
        outcomes = [
            EpisodeOutcomes(episode_id="E1", survived=true, qaly_gained=0.8, total_cost=50_000.0),
            EpisodeOutcomes(episode_id="E2", survived=true, qaly_gained=0.9, total_cost=55_000.0),
            EpisodeOutcomes(episode_id="E3", survived=false, qaly_gained=0.1, total_cost=35_000.0),
        ]
        
        summary = EpisodeSummary(outcomes)
        @test summary.n_episodes == 3
        @test summary.mortality_rate ≈ 1/3
        @test summary.mean_cost ≈ (50_000 + 55_000 + 35_000) / 3
        @test summary.total_qaly ≈ (0.8 + 0.9 + 0.1)
    end
    
    # ═══════════════════════════════════════════════════════════════
    # QALY CALCULATIONS
    # ═══════════════════════════════════════════════════════════════
    
    @testset "Basic QALY Calculation" begin
        qaly = calculate_qaly(1.0, 1.0)
        @test qaly ≈ 1.0
        
        qaly = calculate_qaly(1.0, 0.7)
        @test qaly ≈ 0.7
        
        qaly = calculate_qaly(2.0, 0.5)
        @test qaly ≈ 1.0
    end
    
    @testset "QALY from Utility Change" begin
        # 5 years improving from 0.7 to 0.9
        qaly = qaly_from_utility(0.7, 0.9, 5.0)
        @test qaly ≈ 5.0 * 0.2
        @test qaly ≈ 1.0
    end
    
    @testset "QALY Gain Calculation" begin
        gain = qaly_gain(1.5, 1.0)
        @test gain ≈ 0.5
    end
    
    @testset "Quality Adjusted Survival" begin
        qalys, life_years, quality_factor = quality_adjusted_survival(
            cohort_size = 1000,
            annual_mortality = 0.05,
            annual_utility = 0.8,
            years_follow_up = 5
        )
        
        @test life_years > 0
        @test qalys < life_years  # Quality adjusted should be lower
        @test quality_factor ≈ 0.8
    end
    
    @testset "Simple Utility Weights" begin
        utility = SimpleUtility()
        @test get_utility(utility, "perfect") ≈ 1.0
        @test get_utility(utility, "mild") ≈ 0.9
        @test get_utility(utility, "death") ≈ 0.0
    end
    
    # ═══════════════════════════════════════════════════════════════
    # COST-EFFECTIVENESS ANALYSIS
    # ═══════════════════════════════════════════════════════════════
    
    @testset "ICER Calculation - Cost-Effective" begin
        result = calculate_icer(
            intervention_cost = 50_000.0,
            intervention_effect = 1.5,
            control_cost = 30_000.0,
            control_effect = 1.0,
            ce_threshold = 100_000.0
        )
        
        @test result.cost_difference ≈ 20_000.0
        @test result.effect_difference ≈ 0.5
        @test result.icer ≈ 40_000.0
        @test result.cost_effective == true
    end
    
    @testset "ICER Calculation - Not Cost-Effective" begin
        result = calculate_icer(
            intervention_cost = 150_000.0,
            intervention_effect = 1.2,
            control_cost = 100_000.0,
            control_effect = 1.0,
            ce_threshold = 100_000.0
        )
        
        @test result.icer ≈ 250_000.0
        @test result.cost_effective == false
    end
    
    @testset "ICER Calculation - Cost-Saving" begin
        result = calculate_icer(
            intervention_cost = 40_000.0,
            intervention_effect = 1.5,
            control_cost = 60_000.0,
            control_effect = 1.0,
            ce_threshold = 100_000.0
        )
        
        @test result.cost_difference ≈ -20_000.0
        @test result.icer ≈ -40_000.0  # Negative ICER = cost-saving
        @test result.cost_effective == true
    end
    
    @testset "ICER Calculation - Dominated" begin
        result = calculate_icer(
            intervention_cost = 100_000.0,
            intervention_effect = 0.5,  # Worse effect
            control_cost = 50_000.0,
            control_effect = 1.0,
            ce_threshold = 100_000.0
        )
        
        @test result.dominated == true
        @test result.cost_effective == false
    end
    
    @testset "NCE Calculation" begin
        nce = calculate_nce(cost = 100_000.0, effect = 1.0)
        @test nce ≈ 100_000.0
    end
    
    @testset "Incremental Cost Calculation" begin
        intervention_costs = [50_000.0, 55_000.0, 48_000.0]
        control_costs = [40_000.0, 42_000.0, 38_000.0]
        
        mean_diff, se_diff = calculate_incremental_cost(intervention_costs, control_costs)
        expected_mean = mean([50_000-40_000, 55_000-42_000, 48_000-38_000])
        
        @test mean_diff ≈ expected_mean
        @test se_diff > 0
    end
    
    # ═══════════════════════════════════════════════════════════════
    # UTILITY FORMATTING
    # ═══════════════════════════════════════════════════════════════
    
    @testset "Currency Formatting" begin
        @test format_currency(1_234_567.89) == "\$1.2M"
        @test format_currency(50_000.0) == "\$50.0K"
        @test format_currency(500.0) == "\$500.00"
    end
    
    @testset "Percentage Formatting" begin
        formatted = format_percentage(0.275)
        @test contains(formatted, "27")
    end
    
    @testset "Ratio Formatting" begin
        ratio = format_ratio(100.0, 50.0)
        @test ratio == "2.00"
    end
    
    # ═══════════════════════════════════════════════════════════════
    # RECOMMENDATIONS
    # ═══════════════════════════════════════════════════════════════
    
    @testset "Intervention Recommendation - Cost-Effective" begin
        result = calculate_icer(
            intervention_cost = 50_000.0,
            intervention_effect = 1.5,
            control_cost = 30_000.0,
            control_effect = 1.0,
            ce_threshold = 100_000.0
        )
        
        rec = recommend_intervention(result)
        @test contains(rec, "RECOMMEND")
        @test contains(rec, "cost-effective")
    end
    
    @testset "Intervention Recommendation - Dominated" begin
        result = calculate_icer(
            intervention_cost = 100_000.0,
            intervention_effect = 0.5,
            control_cost = 50_000.0,
            control_effect = 1.0,
            ce_threshold = 100_000.0
        )
        
        rec = recommend_intervention(result)
        @test contains(rec, "REJECT")
        @test contains(rec, "dominated")
    end
    
end

println("\n✅ All tests passed!")
