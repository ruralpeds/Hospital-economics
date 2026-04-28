"""
Tests for cms_api_connectors.jl that exercise pure-logic surfaces
(cache hits, column normalization, CCN-based join). The network code path
itself is exercised live in integration tests, not here.
"""

using Test
using Dates
using DataFrames
using CSV

if !isdefined(Main, :fetch_cms_dataset)
    include(joinpath(@__DIR__, "..", "..", "src", "data_ingestion", "types.jl"))
    include(joinpath(@__DIR__, "..", "..", "src", "data_ingestion", "audit_logger.jl"))
    include(joinpath(@__DIR__, "..", "..", "src", "data_ingestion", "cms_api_connectors.jl"))
end

@testset "CMS cache hit returns cached DataFrame" begin
    mktempdir() do dir
        # Pre-seed the cache so no HTTP call happens.
        df = DataFrame(
            CCN = ["011300", "012345"],
            Hospital_Name = ["Test A", "Test B"],
            Hospital_Overall_Rating = [4, 5],
        )
        cache_file = joinpath(dir, "hospital_general_info.csv")
        CSV.write(cache_file, df)

        result = fetch_cms_dataset("hospital_general_info"; cache_dir = dir)
        @test result.cached == true
        @test result.cache_path == cache_file
        @test nrow(result.rows) == 2
        @test result.audit.event_type == "CMS_FETCH_CACHED"
        @test result.audit.record_count == 2
    end
end

@testset "join_pos_to_general_info on CCN" begin
    general = DataFrame(
        ccn = ["11300", "012345"],
        rating = [4, 5],
    )
    pos = DataFrame(
        provider_number = ["011300", "012345", "999999"],
        beds = [25, 100, 50],
    )
    joined = join_pos_to_general_info(general, pos)
    @test nrow(joined) == 2
    @test sort(joined.ccn) == ["011300", "012345"]
    @test "beds" in lowercase.(string.(names(joined)))
end

@testset "CCN missing column raises" begin
    a = DataFrame(name = ["x"])
    b = DataFrame(provider_number = ["011300"])
    @test_throws ErrorException join_pos_to_general_info(a, b)
end
