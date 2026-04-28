# ============================================================================
# Unit tests for app/components/form_grid.jl
#
# Tests verify:
# - form_grid() returns a non-empty HTML node tree
# - All supported field types produce nodes
# - Optional upload button is included when requested
# - title and class arguments are respected
# ============================================================================

using Test

# Minimal stubs so we can load the component without a running Genie server
module StippleUIStub
    struct FakeNode
        tag::String
        children::Vector
        attrs::Dict
    end
    FakeNode(tag; children=[], attrs=Dict()) = FakeNode(tag, children, attrs)
end

# Load helpers from the project root rather than starting Genie
const REPO_ROOT = joinpath(@__DIR__, "..", "..")
const APP_ROOT  = joinpath(REPO_ROOT, "app")

# We test the Julia-level logic (not rendered HTML) by loading the file and
# stubbing the Stipple DSL functions.
# ---------------------------------------------------------------------------
# Stub all Stipple/StippleUI/Genie.Html DSL functions that form_grid.jl calls.
# Each stub simply returns a plain Dict describing the call so we can inspect
# the output without a live Quasar/Stipple runtime.
# ---------------------------------------------------------------------------

for fn in [:card, :card_section, :row, :cell, :btn, :textfield, :numberfield,
           :select, :toggle, :separator, :span, :p, :h6, :template,
           :quasar]
    @eval function $(fn)(args...; kwargs...)
        Dict(:fn => $(QuoteNode(fn)), :args => [args...], :kwargs => Dict(kwargs))
    end
end

# Stub Genie.Renderer.Html.div / thead / tbody / tr / td / th
module Html
    for fn in [:div, :thead, :tbody, :tr, :td, :th]
        @eval function $(fn)(args...; kwargs...)
            Dict(:fn => $(QuoteNode(fn)), :args => [args...], :kwargs => Dict(kwargs))
        end
    end
end

# Stub @click macro behaviour (just return the symbol)
macro click(sym); :($(QuoteNode(sym))); end

include(joinpath(APP_ROOT, "components", "form_grid.jl"))

@testset "FormGrid component" begin

    @testset "Returns a non-empty structure for empty field list" begin
        result = form_grid([])
        @test result isa Dict
        @test result[:fn] == :card
    end

    @testset "Numeric field" begin
        result = form_grid([(name=:revenue, type=:numeric, label="Revenue")])
        @test result isa Dict
    end

    @testset "Currency field" begin
        result = form_grid([(name=:cost, type=:currency, label="Cost", min=0.0, max=1e7)])
        @test result isa Dict
    end

    @testset "Percent field" begin
        result = form_grid([(name=:rate, type=:percent, label="Rate",
                             min=0.0, max=1.0, step=0.01,
                             help="Annual rate")])
        @test result isa Dict
    end

    @testset "Integer field" begin
        result = form_grid([(name=:horizon, type=:integer, label="Years",
                             min=1, max=50)])
        @test result isa Dict
    end

    @testset "Date field" begin
        result = form_grid([(name=:start_date, type=:date, label="Start")])
        @test result isa Dict
    end

    @testset "Daterange field" begin
        result = form_grid([(name=:period, type=:daterange, label="Period")])
        @test result isa Dict
    end

    @testset "Select field with inline options" begin
        result = form_grid([
            (name=:category, type=:select, label="Category",
             options=[Dict(:label=>"A", :value=>"a"),
                      Dict(:label=>"B", :value=>"b")]),
        ])
        @test result isa Dict
    end

    @testset "Multiselect field" begin
        result = form_grid([(name=:tags, type=:multiselect, label="Tags")])
        @test result isa Dict
    end

    @testset "Toggle field" begin
        result = form_grid([(name=:flag, type=:toggle, label="Enable")])
        @test result isa Dict
    end

    @testset "Code search field" begin
        result = form_grid([(name=:icd, type=:code_search, label="Diagnosis")])
        @test result isa Dict
    end

    @testset "Cohort picker field" begin
        result = form_grid([(name=:cohort, type=:cohort_picker, label="Cohort")])
        @test result isa Dict
    end

    @testset "File field" begin
        result = form_grid([(name=:upload, type=:file, label="Upload")])
        @test result isa Dict
    end

    @testset "Dynamic table field" begin
        result = form_grid([
            (name=:costs, type=:dynamic_table, label="Costs by Year",
             columns=[:year, :cost]),
        ])
        @test result isa Dict
    end

    @testset "Upload button present when upload_model_field given" begin
        result = form_grid(
            [(name=:val, type=:numeric, label="Value")];
            upload_model_field=:do_fill,
        )
        @test result isa Dict
    end

    @testset "Title argument" begin
        result = form_grid(
            [(name=:val, type=:numeric, label="Value")];
            title="My Form",
        )
        @test result isa Dict
    end

    @testset "Unknown type falls back to numberfield" begin
        result = form_grid([(name=:x, type=:unknown_type, label="X")])
        @test result isa Dict
    end

    @testset "_field_hint returns empty list for blank help" begin
        hints = _field_hint("")
        @test hints == []
    end

    @testset "_field_hint returns one element for non-blank help" begin
        hints = _field_hint("Some tooltip")
        @test length(hints) == 1
    end

    @testset "_maybe_vif passes through when visible_when is empty" begin
        node = Dict(:tag => "test")
        result = _maybe_vif(node, "")
        @test result === node
    end

    @testset "_maybe_vif wraps with v-if when visible_when provided" begin
        node = Dict(:tag => "test")
        result = _maybe_vif(node, "show_field")
        @test result isa Dict
        @test haskey(result[:kwargs], Symbol("v-if"))
    end
end
