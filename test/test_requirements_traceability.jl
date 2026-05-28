using Test
using Dates
using JSON3
using CSV
using DataFrames

include(joinpath(@__DIR__, "..", "src", "validation", "requirements_traceability.jl"))
using .RequirementsTraceabilityModule

function _make_req(id::String;
                   sev::RequirementSeverity = high,
                   cat::RequirementCategory = functional)
    Requirement(id, "Title for $id", "Description for $id", sev, cat, "Source for $id")
end

@testset "RequirementsTraceability" begin

    @testset "enum values" begin
        @test Int(critical) == 0
        @test Int(low) == 3
        @test Int(functional) == 0
        @test Int(usability) == 4
    end

    @testset "add_requirement! inserts and overwrites" begin
        m = TraceabilityMatrix()
        add_requirement!(m, _make_req("REQ-FIN-001"))
        @test length(m.requirements) == 1
        # overwrite with new title
        add_requirement!(m, Requirement("REQ-FIN-001", "Updated", "d",
                                        critical, functional, "src"))
        @test m.requirements["REQ-FIN-001"].title == "Updated"
        @test m.requirements["REQ-FIN-001"].severity == critical
    end

    @testset "link_code! sets verified based on tests" begin
        m = TraceabilityMatrix()
        add_requirement!(m, _make_req("REQ-FIN-002"))
        link1 = link_code!(m, "REQ-FIN-002", "src/finance/dscr.jl", "compute_dscr")
        @test link1.verified == false
        @test isempty(link1.test_files)

        link2 = link_code!(m, "REQ-FIN-002", "src/finance/dscr.jl", "compute_dscr";
                           test_files = ["test/test_dscr.jl"])
        @test link2.verified == true
        @test link2.test_files == ["test/test_dscr.jl"]
        @test length(m.links) == 2
    end

    @testset "traceability_report" begin
        m = TraceabilityMatrix()
        add_requirement!(m, _make_req("R1"; sev = critical))
        add_requirement!(m, _make_req("R2"; sev = critical))
        add_requirement!(m, _make_req("R3"; sev = high))
        add_requirement!(m, _make_req("R4"; sev = low))
        link_code!(m, "R1", "a.jl", "fa"; test_files = ["t.jl"])
        link_code!(m, "R3", "b.jl", "fb")

        rep = traceability_report(m)
        @test rep.total_requirements == 4
        @test rep.linked_count == 2
        @test rep.coverage_pct == 50.0
        @test rep.by_severity[critical] == (total = 2, linked = 1)
        @test rep.by_severity[high]     == (total = 1, linked = 1)
        @test rep.by_severity[low]      == (total = 1, linked = 0)
        @test rep.by_severity[medium]   == (total = 0, linked = 0)

        empty_rep = traceability_report(TraceabilityMatrix())
        @test empty_rep.coverage_pct == 0.0
    end

    @testset "unlinked_requirements" begin
        m = TraceabilityMatrix()
        add_requirement!(m, _make_req("R-A"))
        add_requirement!(m, _make_req("R-B"))
        add_requirement!(m, _make_req("R-C"))
        link_code!(m, "R-B", "x.jl", "fx")

        gaps = unlinked_requirements(m)
        @test gaps == ["R-A", "R-C"]  # sorted
    end

    @testset "requirements_for_file" begin
        m = TraceabilityMatrix()
        add_requirement!(m, _make_req("R1"))
        add_requirement!(m, _make_req("R2"))
        add_requirement!(m, _make_req("R3"))
        link_code!(m, "R1", "src/a.jl", "f1")
        link_code!(m, "R2", "src/a.jl", "f2")
        link_code!(m, "R3", "src/b.jl", "f3")

        in_a = requirements_for_file(m, "src/a.jl")
        @test length(in_a) == 2
        @test Set([r.id for r in in_a]) == Set(["R1", "R2"])

        in_b = requirements_for_file(m, "src/b.jl")
        @test length(in_b) == 1
        @test in_b[1].id == "R3"

        @test isempty(requirements_for_file(m, "src/none.jl"))
    end

    @testset "export_traceability_matrix CSV" begin
        m = TraceabilityMatrix()
        add_requirement!(m, _make_req("R-LINKED"; sev = critical))
        add_requirement!(m, _make_req("R-ORPHAN"; sev = low))
        link_code!(m, "R-LINKED", "src/a.jl", "fa"; test_files = ["t1.jl", "t2.jl"])

        mktempdir() do dir
            path = joinpath(dir, "trace.csv")
            export_traceability_matrix(m, path; format = :csv)
            @test isfile(path)
            df = CSV.read(path, DataFrame)
            @test nrow(df) == 2
            linked_row = df[df.requirement_id .== "R-LINKED", :][1, :]
            @test linked_row.file_path == "src/a.jl"
            @test linked_row.function_name == "fa"
            @test linked_row.test_files == "t1.jl|t2.jl"
            @test linked_row.verified == true
            @test linked_row.severity == "critical"
            orphan_row = df[df.requirement_id .== "R-ORPHAN", :][1, :]
            @test ismissing(orphan_row.file_path) || orphan_row.file_path == ""
            @test orphan_row.verified == false
        end
    end

    @testset "export_traceability_matrix JSON" begin
        m = TraceabilityMatrix()
        add_requirement!(m, _make_req("R1"))
        link_code!(m, "R1", "src/x.jl", "fx"; test_files = ["t.jl"])
        mktempdir() do dir
            path = joinpath(dir, "subdir", "trace.json")
            export_traceability_matrix(m, path; format = :json)
            @test isfile(path)
            payload = JSON3.read(read(path, String))
            @test haskey(payload, "requirements")
            @test haskey(payload, "links")
            @test length(payload["links"]) == 1
            @test payload["links"][1]["verified"] == true
        end
    end

    @testset "export_traceability_matrix rejects unknown format" begin
        m = TraceabilityMatrix()
        mktempdir() do dir
            @test_throws ArgumentError export_traceability_matrix(
                m, joinpath(dir, "x.txt"); format = :yaml)
        end
    end

    @testset "HIPAA_REQUIREMENTS catalog" begin
        @test length(HIPAA_REQUIREMENTS) >= 8
        @test haskey(HIPAA_REQUIREMENTS, "HIPAA-164.312-b")
        audit = HIPAA_REQUIREMENTS["HIPAA-164.312-b"]
        @test audit.category == regulatory
        @test audit.severity == critical
        @test occursin("164.312", audit.source)

        encryption = HIPAA_REQUIREMENTS["HIPAA-164.312-e-2-ii"]
        @test encryption.category == security
        @test encryption.severity == critical
    end

    @testset "global TRACEABILITY_MATRIX seeded with HIPAA" begin
        for id in keys(HIPAA_REQUIREMENTS)
            @test haskey(TRACEABILITY_MATRIX.requirements, id)
        end
    end

    @testset "thread-safety" begin
        m = TraceabilityMatrix()
        for i in 1:50
            add_requirement!(m, _make_req("R$i"))
        end
        Threads.@threads for i in 1:50
            link_code!(m, "R$i", "src/file.jl", "fn$i"; test_files = ["t$i.jl"])
        end
        @test length(m.links) == 50
    end
end
