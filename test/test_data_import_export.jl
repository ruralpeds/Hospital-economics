# ============================================================================
# Tests for data import/export functions
# (parse_hcris_cost_report, import_hospital_from_csv/json, export_results)
# ============================================================================

using Test

# Include source
include(joinpath(@__DIR__, "..", "src", "data", "import_hcris.jl"))
include(joinpath(@__DIR__, "..", "src", "data", "import_csv.jl"))
include(joinpath(@__DIR__, "..", "src", "data", "export.jl"))

@testset "Data Import/Export" begin

    # -----------------------------------------------------------------------
    @testset "parse_hcris_cost_report - with sample data" begin
        sample_dir = joinpath(@__DIR__, "..", "data", "hcris_sample")
        if isdir(sample_dir)
            csv_files = filter(f -> endswith(f, ".csv"), readdir(sample_dir; join=true))
            if !isempty(csv_files)
                result = parse_hcris_cost_report(csv_files[1])
                @test result isa Dict{String,Any}
                @test length(result) > 0
            end
        end
    end

    # -----------------------------------------------------------------------
    @testset "parse_hcris_cost_report - nonexistent file errors" begin
        @test_throws Exception parse_hcris_cost_report("/nonexistent/path.csv")
    end

    # -----------------------------------------------------------------------
    @testset "parse_hcris_cost_report - with provider filter" begin
        sample_dir = joinpath(@__DIR__, "..", "data", "hcris_sample")
        if isdir(sample_dir)
            csv_files = filter(f -> endswith(f, ".csv"), readdir(sample_dir; join=true))
            if !isempty(csv_files)
                result = parse_hcris_cost_report(csv_files[1]; provider_filter="171301")
                @test result isa Dict{String,Any}
            end
        end
    end

    # -----------------------------------------------------------------------
    @testset "import_hospital_from_json - sample files" begin
        sample_dir = joinpath(@__DIR__, "..", "data", "sample_hospitals")
        if isdir(sample_dir)
            json_files = filter(f -> endswith(f, ".json"), readdir(sample_dir; join=true))
            for jf in json_files
                result = import_hospital_from_json(jf)
                @test result isa Dict{String,Any}
                @test length(result) > 0
                # Should contain basic hospital fields
                @test haskey(result, "name") || haskey(result, "hospital_name") ||
                      haskey(result, "hospital") || length(result) >= 3
            end
        end
    end

    # -----------------------------------------------------------------------
    @testset "import_hospital_from_json - nonexistent file errors" begin
        @test_throws Exception import_hospital_from_json("/nonexistent.json")
    end

    # -----------------------------------------------------------------------
    @testset "import_hospital_from_csv - CAH type" begin
        # Create a temp CSV with minimal hospital data
        tmp = tempname() * ".csv"
        try
            open(tmp, "w") do io
                println(io, "name,state,beds,type,revenue,expenses")
                println(io, "Test Hospital,KS,25,CAH,18500000,19200000")
                println(io, "Valley Hospital,NE,20,CAH,12000000,12500000")
            end

            results = import_hospital_from_csv(tmp; hospital_type=:cah)
            @test results isa Vector
            @test length(results) >= 1

            for h in results
                @test h isa Dict{String,Any}
                @test haskey(h, "name") || length(h) >= 3
            end
        finally
            isfile(tmp) && rm(tmp)
        end
    end

    # -----------------------------------------------------------------------
    @testset "export_results_to_csv" begin
        results = [
            Dict("year" => 2026, "revenue" => 18_500_000, "margin" => -0.038),
            Dict("year" => 2027, "revenue" => 19_200_000, "margin" => -0.015),
            Dict("year" => 2028, "revenue" => 19_800_000, "margin" => 0.005),
        ]
        tmp = tempname() * ".csv"
        try
            path = export_results_to_csv(results, tmp)
            @test isfile(path)
            @test path == tmp

            content = read(tmp, String)
            @test contains(content, "2026")
            @test contains(content, "18500000") || contains(content, "1.85")
            @test length(split(content, "\n")) >= 3  # header + 3 rows
        finally
            isfile(tmp) && rm(tmp)
        end
    end

    # -----------------------------------------------------------------------
    @testset "export_results_to_json" begin
        results = Dict(
            "scenario" => "Baseline",
            "years" => [2026, 2027, 2028],
            "margins" => [-0.038, -0.015, 0.005],
        )
        tmp = tempname() * ".json"
        try
            path = export_results_to_json(results, tmp; pretty=true)
            @test isfile(path)
            @test path == tmp

            content = read(tmp, String)
            @test contains(content, "Baseline")
            @test contains(content, "2026")
        finally
            isfile(tmp) && rm(tmp)
        end
    end

    # -----------------------------------------------------------------------
    @testset "export_results_to_json - compact format" begin
        results = Dict("key" => "value", "number" => 42)
        tmp = tempname() * ".json"
        try
            path = export_results_to_json(results, tmp; pretty=false)
            @test isfile(path)
            content = read(tmp, String)
            @test contains(content, "key")
        finally
            isfile(tmp) && rm(tmp)
        end
    end

    # -----------------------------------------------------------------------
    @testset "export_results_to_csv - with column spec" begin
        results = [
            Dict("year" => 2026, "revenue" => 18.5, "expenses" => 19.2, "extra" => "ignored"),
            Dict("year" => 2027, "revenue" => 19.0, "expenses" => 19.4, "extra" => "ignored"),
        ]
        tmp = tempname() * ".csv"
        try
            path = export_results_to_csv(results, tmp; columns=["year", "revenue"])
            @test isfile(path)
            content = read(tmp, String)
            @test contains(content, "year")
            @test contains(content, "revenue")
        finally
            isfile(tmp) && rm(tmp)
        end
    end
end
