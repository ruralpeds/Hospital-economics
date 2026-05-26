using Test
using Dates

@testset "QualityController" begin

    @testset "handle_readmission — with data" begin
        payload = Dict(
            "cohort_id"   => "CAH_2024",
            "time_period" => "12months",
            "events"      => [12, 15, 8, 11, 14, 9, 13, 16, 10, 7, 12, 15],
            "denominators"=> [200, 210, 195, 205, 215, 190, 200, 220, 198, 185, 202, 208],
        )
        result = QualityController.handle_readmission(payload)
        @test result["status"] == "success"
        @test result["readmission_rate"] > 0
        @test length(result["outcome_rows"]) == 12
        row1 = result["outcome_rows"][1]
        @test haskey(row1, "rate")
        @test haskey(row1, "ucl")
        @test haskey(row1, "lcl")
        @test haskey(row1, "in_control")
    end

    @testset "handle_readmission — no data" begin
        result = QualityController.handle_readmission(Dict())
        @test result["status"] == "success"
        @test result["readmission_rate"] == 0.0
        @test haskey(result, "message")
    end

    @testset "handle_mortality — with data" begin
        payload = Dict(
            "cohort_id" => "mortality_cohort",
            "observed"  => [5, 12, 3, 8, 15, 7, 10, 4, 9, 11],
            "expected"  => [6.0, 11.5, 4.2, 7.8, 13.0, 8.0, 9.5, 5.0, 8.5, 10.0],
        )
        result = QualityController.handle_mortality(payload)
        @test result["status"] == "success"
        @test result["smr"] > 0
        @test length(result["km_data"]) == 10
        @test haskey(result["km_data"][1], "oe_ratio")
    end

    @testset "handle_mortality — no data" begin
        result = QualityController.handle_mortality(Dict("cohort_id" => "empty"))
        @test result["status"] == "success"
        @test result["mortality_rate"] == 0.0
    end

    @testset "handle_infection — with data" begin
        payload = Dict(
            "infection_type" => "clabsi",
            "counts"         => [2, 3, 1, 4, 2, 0, 3, 1, 2, 3],
            "line_days"      => [500, 520, 480, 510, 530, 490, 505, 515, 495, 500],
        )
        result = QualityController.handle_infection(payload)
        @test result["status"] == "success"
        @test result["infection_rate"] > 0
        @test result["rate_unit"] == "per_1000_line_days"
        @test haskey(result, "chart_data")
        @test length(result["chart_data"]["values"]) == 10
    end

    @testset "handle_infection — no data" begin
        result = QualityController.handle_infection(Dict("infection_type" => "cauti"))
        @test result["status"] == "success"
        @test haskey(result, "message")
    end

    @testset "handle_psi — with raw rate" begin
        payload = Dict(
            "psi_measure" => "psi_03",
            "events"      => [3.0, 5.0, 2.0, 4.0],
            "at_risk"     => [1000.0, 1200.0, 800.0, 1100.0],
        )
        result = QualityController.handle_psi(payload)
        @test result["status"] == "success"
        @test result["complication_rate"] > 0
        @test result["n_strata"] == 4
    end

    @testset "handle_psi — with standardization" begin
        payload = Dict(
            "psi_measure"  => "psi_90",
            "events"       => [10.0, 20.0, 15.0],
            "at_risk"      => [1000.0, 2000.0, 1500.0],
            "std_weights"  => [0.3, 0.4, 0.3],
        )
        result = QualityController.handle_psi(payload)
        @test result["status"] == "success"
        @test result["standardized_rate"] !== nothing
        @test result["standardized_rate"] > 0
    end

    @testset "handle_psi — no data" begin
        result = QualityController.handle_psi(Dict())
        @test result["status"] == "success"
        @test result["complication_rate"] == 0.0
    end

    @testset "handle_qol — basic scores" begin
        payload = Dict(
            "qol_scale" => "eq5d",
            "scores"    => [0.8, 0.7, 0.9, 0.85, 0.75, 0.65, 0.88, 0.72, 0.91, 0.78],
        )
        result = QualityController.handle_qol(payload)
        @test result["status"] == "success"
        @test 0.0 < result["qol_score"] < 1.0
        @test result["n"] == 10
        @test haskey(result, "median")
        @test haskey(result, "std")
    end

    @testset "handle_qol — with group comparison" begin
        payload = Dict(
            "qol_scale" => "eq5d",
            "scores"    => vcat(fill(0.8, 15), fill(0.6, 15)),
            "groups"    => vcat(fill("Pre", 15), fill("Post", 15)),
        )
        result = QualityController.handle_qol(payload)
        @test result["status"] == "success"
        @test haskey(result, "group_comparison")
        @test length(result["group_comparison"]) == 2
        @test haskey(result, "p_value")
        @test haskey(result, "effect_size")
    end

    @testset "handle_qol — no data" begin
        result = QualityController.handle_qol(Dict())
        @test result["status"] == "success"
        @test result["qol_score"] == 0.0
    end

    @testset "handle_disparities — with data" begin
        payload = Dict(
            "subgroup_variable" => "race",
            "outcomes"          => vcat(fill(0.05, 20), fill(0.08, 15), fill(0.12, 10)),
            "groups"            => vcat(fill("White", 20), fill("Black", 15), fill("Hispanic", 10)),
        )
        result = QualityController.handle_disparities(payload)
        @test result["status"] == "success"
        @test result["n_groups"] == 3
        @test length(result["disparities_rows"]) == 3
        @test haskey(result, "test_type")
        @test result["test_type"] == "one_way_anova"
        @test haskey(result, "p_value")
    end

    @testset "handle_disparities — two groups" begin
        payload = Dict(
            "subgroup_variable" => "payer",
            "outcomes"          => vcat(fill(0.06, 20), fill(0.10, 20)),
            "groups"            => vcat(fill("Medicare", 20), fill("Medicaid", 20)),
        )
        result = QualityController.handle_disparities(payload)
        @test result["status"] == "success"
        @test result["test_type"] == "two_sample_t"
    end

    @testset "handle_disparities — no data" begin
        result = QualityController.handle_disparities(Dict())
        @test result["status"] == "success"
        @test isempty(result["disparities_rows"])
    end
end
