# test/test_policy_validation.jl
# Tests for PolicyValidation module

using Test
using Statistics
using Dates

include("../src/validation/PolicyValidation.jl")
using .PolicyValidation

@testset "PolicyValidation Tests" begin

    # ==================== Case Study Instantiation ====================
    @testset "Kentucky Medicaid Expansion" begin
        case = KentuckyMedicaidExpansion()
        @test case.year == 2014
        @test case.new_enrollees == 400000
        @test case.affected_hospitals == 100
        @test case.name == "Kentucky Medicaid Expansion (2014)"
        @test case.baseline_margin == 0.03
    end

    @testset "Kentucky Medicaid Custom Parameters" begin
        case = KentuckyMedicaidExpansion(
            year=2015,
            new_enrollees=350000,
            affected_hospitals=95
        )
        @test case.year == 2015
        @test case.new_enrollees == 350000
        @test case.affected_hospitals == 95
    end

    @testset "Maryland All-Payer Model" begin
        case = MarylandAllPayerModel()
        @test case.year_start == 2014
        @test case.year_end == 2018
        @test case.affected_hospitals == 60
        @test case.name == "Maryland All-Payer Model (2014-2018)"
        @test case.global_budget_growth_limit == 0.02
        @test case.quality_incentive_pool_pct == 0.02
    end

    @testset "Rural Hospital Closure Case" begin
        case = RuralHospitalClosureCase()
        @test case.year_start == 2010
        @test case.year_end == 2023
        @test case.name == "Rural Hospital Closures (2010-2023)"
        @test isempty(case.actual_closures)
    end

    @testset "COVID-19 Impact Case" begin
        case = COVID19ImpactCase()
        @test case.year_start == 2020
        @test case.year_end == 2021
        @test case.name == "COVID-19 Impact (2020-2021)"
        @test case.volume_shock_percent == -0.25
        @test case.elective_shock == -0.60
        @test case.inpatient_shock == -0.20
    end

    # ==================== Case Study Loading ====================
    @testset "Load Case Studies" begin
        ky = load_case_study(KentuckyMedicaidExpansion)
        @test ky isa KentuckyMedicaidExpansion
        @test ky.year == 2014

        md = load_case_study(MarylandAllPayerModel)
        @test md isa MarylandAllPayerModel
        @test md.year_start == 2014

        rural = load_case_study(RuralHospitalClosureCase)
        @test rural isa RuralHospitalClosureCase

        covid = load_case_study(COVID19ImpactCase)
        @test covid isa COVID19ImpactCase
    end

    # ==================== Validation Metrics ====================
    @testset "Calculate Metrics - Perfect Agreement" begin
        actual = [
            OutcomeRow("margin_change", 0.05, 1.0),
            OutcomeRow("margin_change", 0.03, 1.0),
        ]
        simulated = [
            OutcomeRow("margin_change", 0.05, 1.0),
            OutcomeRow("margin_change", 0.03, 1.0),
        ]

        metrics = calculate_metrics(actual, simulated)

        @test metrics.mape ≈ 0.0  # Perfect agreement
        @test metrics.directional_accuracy ≈ 1.0
        @test metrics.correlation ≈ 1.0
    end

    @testset "Calculate Metrics - Known Errors" begin
        actual = [
            OutcomeRow("margin_1", 0.10, 1.0),
            OutcomeRow("margin_2", 0.20, 1.0),
        ]
        simulated = [
            OutcomeRow("margin_1", 0.11, 1.0),
            OutcomeRow("margin_2", 0.19, 1.0),
        ]

        metrics = calculate_metrics(actual, simulated)

        # MAPE = mean(|0.01/0.10| * 100, |0.01/0.20| * 100) = mean(10, 5) = 7.5
        @test metrics.mape ≈ 7.5 atol=0.1
        @test metrics.directional_accuracy ≈ 1.0  # Both changes correct direction
    end

    @testset "Calculate Metrics - Directional Errors" begin
        actual = [
            OutcomeRow("change_1",  0.05, 1.0),
            OutcomeRow("change_2",  0.03, 1.0),
            OutcomeRow("change_3", -0.02, -1.0),
        ]
        simulated = [
            OutcomeRow("change_1",  0.05, 1.0),
            OutcomeRow("change_2", -0.01, -1.0),  # wrong direction
            OutcomeRow("change_3", -0.02, -1.0),
        ]

        metrics = calculate_metrics(actual, simulated)

        # 2 out of 3 directions correct = 2/3 ≈ 0.667
        @test metrics.directional_accuracy ≈ 2.0/3.0
    end

    @testset "Calculate Metrics - Zero Values" begin
        actual    = [OutcomeRow("change", 0.0, 0.0)]
        simulated = [OutcomeRow("change", 0.01, 1.0)]

        metrics = calculate_metrics(actual, simulated)

        # MAPE should handle zero baseline gracefully (skipped)
        @test metrics.mape >= 0.0
    end

    # ==================== Validation Results ====================
    @testset "Validate Simulation" begin
        case = KentuckyMedicaidExpansion(
            actual_margin_changes=Dict("H1" => -0.05, "H2" => -0.03)
        )

        simulated = Dict(
            "avg_margin_change"       => -0.04,
            "margin_change_direction" => -1.0,
            "hospital_H1"             => -0.048,
            "hospital_H2"             => -0.032
        )

        result = validate_simulation(case, simulated)

        @test result.case_study_name == "Kentucky Medicaid Expansion (2014)"
        @test result.simulation_name == "Simulation"
        @test result.metrics isa ValidationMetrics
        @test result.metrics.mape >= 0.0
        @test result.metrics.directional_accuracy >= 0.0 && result.metrics.directional_accuracy <= 1.0
        @test length(result.hospital_level_results) == 2
    end

    @testset "Validation Result Completeness" begin
        case = MarylandAllPayerModel(
            actual_margin_changes=Dict("H1" => 0.02)
        )

        simulated = Dict("avg_margin_change" => 0.015)

        result = validate_simulation(case, simulated)

        @test result.timestamp isa DateTime
        @test !isempty(result.summary)
        @test contains(result.summary, "MAPE")
        @test contains(result.summary, "Accuracy")
    end

    # ==================== Outcome Comparison ====================
    @testset "Compare Outcomes" begin
        actual = Dict(
            "H1" =>  0.05,
            "H2" =>  0.03,
            "H3" => -0.01
        )

        simulated = Dict(
            "H1" => 0.048,
            "H2" => 0.031,
            "H3" => 0.00
        )

        comparison = compare_outcomes(actual, simulated)

        @test length(comparison) == 3
        @test all(r.hospital_id in ["H1", "H2", "H3"] for r in comparison)

        # Check specific comparisons
        h1 = filter(r -> r.hospital_id == "H1", comparison)[1]
        @test h1.actual_margin    == 0.05
        @test h1.simulated_margin == 0.048
        @test h1.error ≈ -0.002
    end

    @testset "Compare Outcomes - Mismatched Hospitals" begin
        actual    = Dict("H1" => 0.05, "H2" => 0.03)
        simulated = Dict("H2" => 0.031, "H3" => 0.01)

        comparison = compare_outcomes(actual, simulated)

        @test length(comparison) == 3  # Union of H1, H2, H3
        @test any(r.hospital_id == "H1" for r in comparison)
        @test any(r.hospital_id == "H3" for r in comparison)
    end

    # ==================== Report Generation ====================
    @testset "Generate Validation Report" begin
        case = KentuckyMedicaidExpansion()
        simulated = Dict("avg_margin_change" => -0.04)
        result = validate_simulation(case, simulated)

        report = generate_validation_report(result)

        @test contains(report, "VALIDATION REPORT")
        @test contains(report, "Kentucky Medicaid")
        @test contains(report, "MAPE")
        @test contains(report, "Directional Accuracy")
        @test contains(report, "Correlation")
    end

    @testset "Validation Report Contains Metrics" begin
        case = RuralHospitalClosureCase(
            actual_closures=["H1", "H2"]
        )
        simulated = Dict()
        result = validate_simulation(case, simulated)

        report = generate_validation_report(result)

        @test contains(report, string(round(result.metrics.mape, digits=2)))
        @test contains(report, string(round(result.metrics.directional_accuracy*100, digits=1)))
    end

    # ==================== Edge Cases ====================
    @testset "Empty Simulated Outcomes" begin
        case = COVID19ImpactCase()
        simulated = Dict{String, Float64}()

        result = validate_simulation(case, simulated)

        @test result isa ValidationResult
        @test result.metrics isa ValidationMetrics
    end

    @testset "Large Errors" begin
        actual    = [OutcomeRow("change",  0.10, 1.0)]
        simulated = [OutcomeRow("change", -0.10, -1.0)]  # Opposite sign

        metrics = calculate_metrics(actual, simulated)

        @test metrics.mape > 100.0  # Error is 200%
        @test metrics.directional_accuracy == 0.0  # Wrong direction
    end

    # ==================== Integration Tests ====================
    @testset "Full Validation Workflow - Kentucky" begin
        # Load case study
        case = load_case_study(KentuckyMedicaidExpansion)

        # Simulate outcomes (simplified)
        simulated = Dict(
            "avg_margin_change"       => -0.048,
            "margin_change_direction" => -1.0
        )

        # Validate
        result = validate_simulation(case, simulated)

        # Generate report
        report = generate_validation_report(result)

        @test result isa ValidationResult
        @test !isempty(report)
        @test result.metrics.mape >= 0.0
    end

    @testset "All Case Studies Loadable" begin
        cases = [
            KentuckyMedicaidExpansion,
            MarylandAllPayerModel,
            RuralHospitalClosureCase,
            COVID19ImpactCase
        ]

        for case_type in cases
            case = load_case_study(case_type)
            @test case isa case_type
            @test !isempty(case.name)
        end
    end

    @testset "Validation Metrics Consistency" begin
        actual = [
            OutcomeRow("m1", 0.05, 1.0),
            OutcomeRow("m2", 0.10, 1.0),
            OutcomeRow("m3", 0.03, 1.0),
        ]

        simulated = [
            OutcomeRow("m1", 0.051, 1.0),
            OutcomeRow("m2", 0.099, 1.0),
            OutcomeRow("m3", 0.031, 1.0),
        ]

        metrics = calculate_metrics(actual, simulated)

        # Validation constraints
        @test metrics.mape >= 0.0
        @test metrics.directional_accuracy >= 0.0 && metrics.directional_accuracy <= 1.0
        @test metrics.rmse >= 0.0
        @test metrics.correlation >= -1.0 && metrics.correlation <= 1.0
        @test metrics.max_error >= 0.0
    end

end
