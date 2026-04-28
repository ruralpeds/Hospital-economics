# ============================================================================
# Unit tests for app/views/profitability/profitability.jl (E9)
# ============================================================================

using Test

const REPO_ROOT = joinpath(@__DIR__, "..", "..")
const APP_ROOT  = joinpath(REPO_ROOT, "app")

for fn in [:card, :card_section, :row, :cell, :btn, :textfield, :numberfield,
           :select, :toggle, :separator, :span, :p, :h4, :h5, :h6, :template,
           :quasar, :slider, :plot]
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
macro app(block); nothing; end
macro in(expr); nothing; end
macro out(expr); nothing; end
macro onchange(sym, block); nothing; end
macro init(); :nothing; end

function app_layout(model, title, content)
    Dict(:fn => :app_layout, :title => title, :content => content)
end

function plot_panel(data_field, layout_field; kwargs...)
    Dict(:fn => :plot_panel, :data_field => data_field, :layout_field => layout_field)
end

include(joinpath(APP_ROOT, "components", "form_grid.jl"))
include(joinpath(APP_ROOT, "components", "result_table.jl"))
include(joinpath(APP_ROOT, "components", "export_bar.jl"))
include(joinpath(APP_ROOT, "views", "profitability", "profitability.jl"))

struct FakeModel end

@testset "Profitability view" begin
    model = FakeModel()

    @testset "ui_profitability returns non-empty result" begin
        result = ui_profitability(model)
        @test result isa Dict
        @test !isempty(result)
    end

    @testset "ui_profitability uses app_layout" begin
        result = ui_profitability(model)
        @test result[:fn] == :app_layout
    end

    @testset "title is Profitability & Operations" begin
        result = ui_profitability(model)
        @test result[:title] == "Profitability & Operations"
    end

    @testset "content is non-empty vector" begin
        result = ui_profitability(model)
        @test result[:content] isa Vector
        @test length(result[:content]) > 0
    end
end
