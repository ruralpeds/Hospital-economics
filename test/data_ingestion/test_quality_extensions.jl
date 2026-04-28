"""
Tests for quality_extensions.jl: duplicate detection, outlier detection,
completeness profiling.
"""

using Test
using Dates

if !isdefined(Main, :detect_duplicates)
    include(joinpath(@__DIR__, "..", "..", "src", "data_ingestion", "types.jl"))
    include(joinpath(@__DIR__, "..", "..", "src", "data_ingestion", "quality_extensions.jl"))
end

function _enc(pid::String, eid::String; admit::Date = Date(2024,1,1),
              charges::Float64 = 1000.0, los::Int = 2)
    e = PatientEncounter(pid, eid, admit, admit + Day(los);
        total_charges = charges,
    )
    e.length_of_stay = los
    return e
end

@testset "Duplicate detection" begin
    encs = [
        _enc("P1", "E1"),
        _enc("P1", "E1"),               # duplicate of #1
        _enc("P2", "E2"),
        _enc("P3", "E3"),
        _enc("P3", "E3"),               # duplicate of #4
        _enc("P3", "E3"),               # also duplicate of #4
    ]
    rep = detect_duplicates(encs)
    @test rep.duplicate_count == 3      # 1 from group A, 2 from group B
    @test rep.group_count == 2
    @test rep.key_fields == ["patient_id", "encounter_id", "admission_date"]
    @test all(length.(rep.groups) .>= 2)

    # No duplicates path
    rep2 = detect_duplicates([_enc("X1","Y1"), _enc("X2","Y2")])
    @test rep2.duplicate_count == 0
    @test rep2.group_count == 0
end

@testset "Outlier detection (zscore)" begin
    # 9 normal points + 1 obvious outlier
    values = Float64[10, 11, 9, 10, 12, 11, 9, 10, 11, 1000]
    rep = detect_outliers(values; field = "x", method = :zscore, threshold = 2.0)
    @test rep.field == "x"
    @test rep.method == "zscore"
    @test 10 in rep.outlier_indices

    # No outliers in flat data
    flat = fill(5.0, 20)
    rep2 = detect_outliers(flat; method = :zscore, threshold = 3.0)
    @test isempty(rep2.outlier_indices)
end

@testset "Outlier detection (iqr)" begin
    values = Float64[1, 2, 3, 4, 5, 6, 7, 8, 9, 100]
    rep = detect_outliers(values; method = :iqr, threshold = 1.5)
    @test 10 in rep.outlier_indices

    # Encounter-level dispatcher
    encs = [_enc("P$i", "E$i"; charges = 1000.0 + i * 10) for i in 1:9]
    push!(encs, _enc("PX", "EX"; charges = 1_000_000.0))
    reports = detect_encounter_outliers(encs; method = :iqr, threshold = 1.5)
    @test haskey(reports, "total_charges")
    @test 10 in reports["total_charges"].outlier_indices
end

@testset "Outlier detection edge cases" begin
    @test isempty(detect_outliers(Float64[]).outlier_indices)
    @test_throws ArgumentError detect_outliers([1.0, 2.0]; method = :unknown)
end

@testset "Completeness profiling — Dict rows" begin
    rows = [
        Dict("patient_id" => "P1", "dob" => "1950-01-01", "zip" => "94110"),
        Dict("patient_id" => "P2", "dob" => "",            "zip" => "94110"),
        Dict("patient_id" => "P3", "dob" => "1980-05-05",  "zip" => nothing),
        Dict("patient_id" => "",   "dob" => "1990-09-09",  "zip" => "10001"),
    ]
    rep = profile_completeness(rows; source = "test_csv")
    @test rep.record_count == 4
    @test rep.source == "test_csv"
    @test rep.field_completeness["patient_id"] == 0.75
    @test rep.field_completeness["dob"] == 0.75
    @test rep.field_completeness["zip"] == 0.75
    @test 0.0 < rep.overall_score <= 1.0
end

@testset "Completeness profiling — encounters" begin
    encs = [_enc("P1", "E1"), _enc("P2", "E2")]
    rep = profile_completeness(encs; source = "encounters")
    @test rep.record_count == 2
    @test haskey(rep.field_completeness, "patient_id")
    @test rep.field_completeness["patient_id"] == 1.0
end

@testset "Quality summary serialization" begin
    encs = [_enc("P1", "E1"), _enc("P1", "E1"), _enc("P2", "E2")]
    dup  = detect_duplicates(encs)
    outs = detect_encounter_outliers(encs)
    comp = profile_completeness(encs; source = "demo")
    summary = quality_summary_dict(dup, outs, comp)
    @test summary["duplicates"]["count"] == 1
    @test haskey(summary["outliers"], "total_charges")
    @test summary["completeness"]["record_count"] == 3
end
