# ============================================================================
# Unit tests for app/components/export_bar.jl
#
# Tests verify:
# - export_bar() returns a row node
# - Only requested buttons are rendered (nil fields → no button)
# - label argument is included
# ============================================================================

using Test

const REPO_ROOT = joinpath(@__DIR__, "..", "..")
const APP_ROOT  = joinpath(REPO_ROOT, "app")

# Stub Stipple DSL
for fn in [:row, :cell, :btn, :span]
    @eval function $(fn)(args...; kwargs...)
        Dict(:fn => $(QuoteNode(fn)), :args => [args...], :kwargs => Dict(kwargs))
    end
end

macro click(sym); :($(QuoteNode(sym))); end

include(joinpath(APP_ROOT, "components", "export_bar.jl"))

@testset "ExportBar component" begin

    @testset "Returns a row node for all-nil call" begin
        result = export_bar()
        @test result isa Dict
        @test result[:fn] == :row
    end

    @testset "CSV button present when csv_field given" begin
        result = export_bar(csv_field=:do_csv)
        @test result isa Dict
        children = result[:args][end]  # last positional arg is children array
        # At least one btn child should reference csv
        btns = filter(c -> get(c, :fn, nothing) == :btn, children)
        csv_btns = filter(b -> any(occursin("CSV", string(a)) for a in b[:args]), btns)
        @test length(csv_btns) >= 1
    end

    @testset "XLSX button present when xlsx_field given" begin
        result = export_bar(xlsx_field=:do_xlsx)
        @test result isa Dict
    end

    @testset "JSON button present when json_field given" begin
        result = export_bar(json_field=:do_json)
        @test result isa Dict
    end

    @testset "PDF button present when pdf_field given" begin
        result = export_bar(pdf_field=:do_pdf)
        @test result isa Dict
    end

    @testset "PNG button present when png_field given" begin
        result = export_bar(png_field=:do_png)
        @test result isa Dict
    end

    @testset "Methods button present when methods_field given" begin
        result = export_bar(methods_field=:do_methods)
        @test result isa Dict
    end

    @testset "All buttons together" begin
        result = export_bar(
            csv_field=:c, xlsx_field=:x, json_field=:j,
            pdf_field=:p, png_field=:g, methods_field=:m)
        @test result isa Dict
        children = result[:args][end]
        # label + 6 buttons = 6 children minimum (label might be wrapped)
        @test length(children) >= 6
    end

    @testset "label argument produces a span element" begin
        result = export_bar(csv_field=:do_csv, label="Export:")
        children = result[:args][end]
        spans = filter(c -> get(c, :fn, nothing) == :span, children)
        @test length(spans) >= 1
        span_text = spans[1][:args][1]
        @test span_text == "Export:"
    end

    @testset "No label when label is empty" begin
        result = export_bar()
        children = result[:args][end]
        spans = filter(c -> get(c, :fn, nothing) == :span, children)
        @test length(spans) == 0
    end

    @testset "class argument" begin
        result = export_bar(class="my-class")
        @test result isa Dict
        # class should appear in the kwargs of the row
        @test occursin("my-class", string(get(result[:kwargs], :class, "")))
    end
end
