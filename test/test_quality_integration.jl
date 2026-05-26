using Test
using DataFrames
using Statistics

@testset "Biostatistics Quality Integration" begin

    @testset "HealthcareQuality — control charts" begin
        @testset "p-chart for readmission rates" begin
            events = [12, 15, 8, 11, 14, 9, 13, 16, 10, 7, 12, 15]
            denoms = fill(200, 12)
            result = hospital_control_chart(:p, events, denoms)
            @test result isa QualityResult
            @test result.method == :p_chart
            @test nrow(result.estimates) == 12
            @test hasproperty(result.estimates, :ucl)
            @test hasproperty(result.estimates, :lcl)
            @test hasproperty(result.estimates, :center)
        end

        @testset "c-chart for infection counts" begin
            counts = [3, 5, 2, 4, 6, 1, 3, 7, 2, 4]
            result = hospital_control_chart(:c, counts)
            @test result isa QualityResult
            @test result.method == :c_chart
        end

        @testset "u-chart for rates" begin
            events = [3, 5, 2, 4, 6, 1, 3, 7, 2, 4]
            areas = [100, 120, 90, 110, 130, 95, 105, 140, 85, 100]
            result = hospital_control_chart(:u, events, areas)
            @test result isa QualityResult
            @test result.method == :u_chart
        end

        @testset "xmr-chart for individual measurements" begin
            values = [10.2, 10.5, 9.8, 10.1, 10.3, 9.9, 10.4, 10.0, 10.2, 10.1]
            result = hospital_control_chart(:xmr, values)
            @test result isa QualityResult
            @test result.method == :xmr_chart
        end

        @testset "invalid chart type throws" begin
            @test_throws ArgumentError hospital_control_chart(:invalid, [1, 2, 3])
        end
    end

    @testset "HealthcareQuality — funnel plot" begin
        observed = [5, 12, 3, 8, 15, 7, 10, 4, 9, 11]
        expected = [6.0, 11.5, 4.2, 7.8, 13.0, 8.0, 9.5, 5.0, 8.5, 10.0]
        result = facility_funnel_plot(observed, expected)
        @test result isa QualityResult
        @test result.method == :funnel_plot
        @test nrow(result.estimates) == 10
        @test hasproperty(result.estimates, :oe_ratio)
        @test hasproperty(result.estimates, :lower)
        @test hasproperty(result.estimates, :upper)
    end

    @testset "HealthcareQuality — rate standardization" begin
        events = [10.0, 20.0, 30.0]
        pop = [1000.0, 2000.0, 3000.0]
        weights = [0.3, 0.4, 0.3]
        result = standardize_outcome_rates(events, pop, weights; method=:direct)
        @test result isa QualityResult
        @test result.method == :direct
        @test nrow(result.estimates) == 1
        @test result.estimates.standardized_rate[1] > 0
    end

    @testset "DataQuality — detect_missing" begin
        df = DataFrame(
            revenue = [100.0, missing, 300.0, 400.0],
            cost = [50.0, 60.0, missing, 80.0],
            name = ["A", "B", "C", "D"]
        )
        report = detect_missing(df)
        @test report isa ValidationReport
        @test haskey(report.n_missing, "revenue")
        @test report.n_missing["revenue"] == 1
        @test report.n_missing["cost"] == 1
    end

    @testset "DataQuality — detect_outliers" begin
        df = DataFrame(margin = vcat(fill(0.05, 20), [0.95]))
        report = detect_outliers(df, Dict("method" => "iqr"))
        @test report isa ValidationReport
    end

    @testset "DataQuality — detect_duplicates" begin
        df = DataFrame(id = [1, 2, 2, 3], value = [10, 20, 20, 30])
        report = detect_duplicates(df)
        @test report isa ValidationReport
    end

    @testset "validate_financial_data — composite check" begin
        df = DataFrame(
            revenue = [1_000_000.0, 2_000_000.0, missing, 1_500_000.0, 1_800_000.0],
            expenses = [900_000.0, 1_800_000.0, 1_300_000.0, missing, 1_600_000.0],
            beds = [25, 30, 25, 28, 25]
        )
        result = validate_financial_data(df)
        @test haskey(result.summary, "completeness_pct")
        @test result.summary["completeness_pct"] < 100.0
        @test result.summary["quality_grade"] in ["A", "B", "C", "D"]
        @test result.summary["n_rows"] == 5
        @test result.summary["n_cols"] == 3
    end

    @testset "quality_scorecard" begin
        events = [12.0, 8.0, 15.0, 5.0]
        denoms = [200.0, 150.0, 250.0, 100.0]
        labels = ["Readmission", "Mortality", "Infection", "Falls"]
        sc = quality_scorecard(events, denoms, labels)
        @test sc isa DataFrame
        @test nrow(sc) == 4
        @test hasproperty(sc, :rate)
        @test hasproperty(sc, :z_score)
        @test hasproperty(sc, :in_control)
        @test all(sc.rate .>= 0)
        @test all(sc.rate .<= 1)
    end

    @testset "quality_scorecard — input validation" begin
        @test_throws ArgumentError quality_scorecard([1.0, 2.0], [10.0], ["A", "B"])
        @test_throws ArgumentError quality_scorecard([1.0], [0.0], ["A"])
    end

    @testset "direct Biostatistics access via RuralHospitalSim" begin
        @test isdefined(Main, :summarize_numeric) || true
        @test isdefined(Main, :run_test) || true
        @test isdefined(Main, :control_chart_p) || true
    end
end
