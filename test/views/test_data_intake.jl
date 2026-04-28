# ============================================================================
# Unit tests for app/views/data_intake/data_intake.jl (E4)
# ============================================================================

using Test

const REPO_ROOT = joinpath(@__DIR__, "..", "..")
const APP_ROOT  = joinpath(REPO_ROOT, "app")

# Stub Stipple/StippleUI/Genie DSL functions
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

# Stub component functions that get loaded from includes
function app_layout(model, title, content)
    Dict(:fn => :app_layout, :title => title, :content => content)
end

include(joinpath(APP_ROOT, "components", "form_grid.jl"))
include(joinpath(APP_ROOT, "components", "result_table.jl"))
include(joinpath(APP_ROOT, "components", "export_bar.jl"))
include(joinpath(APP_ROOT, "views", "data_intake", "data_intake.jl"))

struct FakeModel end

@testset "DataIntake view" begin
    model = FakeModel()

    @testset "ui_data_intake returns non-empty result" begin
        result = ui_data_intake(model)
        @test result isa Dict
        @test !isempty(result)
    end

    @testset "ui_data_intake uses app_layout" begin
        result = ui_data_intake(model)
        @test result[:fn] == :app_layout
    end

    @testset "title is Data Intake" begin
        result = ui_data_intake(model)
        @test result[:title] == "Data Intake"
    end

    @testset "content is non-empty vector" begin
        result = ui_data_intake(model)
        @test result[:content] isa Vector
        @test length(result[:content]) > 0
    end
end
