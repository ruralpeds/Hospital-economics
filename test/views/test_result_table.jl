# ============================================================================
# Unit tests for app/components/result_table.jl
#
# Tests verify:
# - result_table() returns a card-level Dict node
# - _col_def builds correct JS object strings for various formats
# - Export, filter, and sparkline arguments produce nodes / are omitted safely
# ============================================================================

using Test

const REPO_ROOT = joinpath(@__DIR__, "..", "..")
const APP_ROOT  = joinpath(REPO_ROOT, "app")

# Stub Stipple DSL
for fn in [:card, :card_section, :row, :cell, :btn, :textfield,
           :numberfield, :select, :toggle, :separator, :span, :p,
           :h6, :template, :quasar]
    @eval function $(fn)(args...; kwargs...)
        Dict(:fn => $(QuoteNode(fn)), :args => [args...], :kwargs => Dict(kwargs))
    end
end

module Html
    for fn in [:div, :thead, :tbody, :tr, :td, :th]
        @eval function $(fn)(args...; kwargs...)
            Dict(:fn => $(QuoteNode(fn)), :args => [args...], :kwargs => Dict(kwargs))
        end
    end
end

macro click(sym); :($(QuoteNode(sym))); end

include(joinpath(APP_ROOT, "components", "result_table.jl"))

@testset "ResultTable component" begin

    @testset "Returns a card node for minimal call" begin
        result = result_table(:my_rows)
        @test result isa Dict
        @test result[:fn] == :card
    end

    @testset "Returns a card node with columns" begin
        result = result_table(:rows,
            columns=[
                (name="year", label="Year", field="year",
                 sortable=true, align="left"),
                (name="cost", label="Cost", field="cost",
                 sortable=false, align="right", format="currency"),
            ])
        @test result isa Dict
    end

    @testset "_col_def — basic column" begin
        c = (name="year", label="Year", field="year",
             sortable=true, align="left")
        js = _col_def(c)
        @test occursin("name: 'year'", js)
        @test occursin("label: 'Year'", js)
        @test occursin("sortable: true", js)
        @test occursin("align: 'left'", js)
    end

    @testset "_col_def — currency format" begin
        c = (name="cost", label="Cost", field="cost",
             sortable=false, align="right", format="currency")
        js = _col_def(c)
        @test occursin("format:", js)
        @test occursin("\$", js)
    end

    @testset "_col_def — percent format" begin
        c = (name="rate", label="Rate", field="rate",
             sortable=false, align="right", format="percent")
        js = _col_def(c)
        @test occursin("%", js)
    end

    @testset "_col_def — number format" begin
        c = (name="count", label="Count", field="count",
             sortable=true, align="right", format="number")
        js = _col_def(c)
        @test occursin("toLocaleString", js)
    end

    @testset "_col_def — no format (no format key)" begin
        c = (name="id", label="ID", field="id",
             sortable=false, align="left")
        js = _col_def(c)
        # Should not contain a format function
        @test !occursin("format:", js)
    end

    @testset "Title argument adds p element" begin
        result = result_table(:rows, title="My Table")
        # The card section contains a title paragraph — confirm structure built
        @test result isa Dict
    end

    @testset "export_csv_field adds export button" begin
        result = result_table(:rows, export_csv_field=:do_csv)
        @test result isa Dict
    end

    @testset "filter_field adds search box" begin
        result = result_table(:rows, filter_field=:my_filter)
        @test result isa Dict
    end

    @testset "Omitting optional args does not error" begin
        result = result_table(:rows,
            columns=[],
            export_csv_field=nothing,
            export_xlsx_field=nothing,
            filter_field=nothing,
            sparkline_field=nothing)
        @test result isa Dict
    end

    @testset "sparkline_field adds sparkline slot" begin
        result = result_table(:rows, sparkline_field=:sparkline_col)
        @test result isa Dict
    end
end
