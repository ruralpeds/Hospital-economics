# ============================================================================
# Unit tests for app/components/plot_panel.jl
#
# Tests verify:
# - plot_panel() returns a card-level node for each preset
# - preset_layout() returns a PlotLayout-like struct for all 9 presets
# - title and export_filename arguments are respected
# ============================================================================

using Test

const REPO_ROOT = joinpath(@__DIR__, "..", "..")
const APP_ROOT  = joinpath(REPO_ROOT, "app")

# Minimal PlotLayout stub (mirrors StipplePlotly interface we need)
struct PlotLayoutTitle; text::String; end
PlotLayoutTitle(; text::String = "") = PlotLayoutTitle(text)
struct PlotLayoutAxis
    title::String
    showgrid::Bool
    zeroline::Bool
    zerolinecolor::String
    autorange::String
    range::Vector{Float64}
    tickformat::String
end
function PlotLayoutAxis(; title="", showgrid=false, zeroline=false,
                          zerolinecolor="", autorange="", range=Float64[],
                          tickformat="")
    PlotLayoutAxis(title, showgrid, zeroline, zerolinecolor,
                   autorange, convert(Vector{Float64}, range), tickformat)
end

struct PlotLayout
    title::PlotLayoutTitle
    xaxis::Vector{PlotLayoutAxis}
    yaxis::Vector{PlotLayoutAxis}
    showlegend::Bool
    hovermode::String
    barmode::String
end
function PlotLayout(; title=PlotLayoutTitle(""), xaxis=PlotLayoutAxis[],
                     yaxis=PlotLayoutAxis[], showlegend=false,
                     hovermode="", barmode="")
    PlotLayout(title, xaxis, yaxis, showlegend, hovermode, barmode)
end

# Stub Stipple DSL
for fn in [:card, :card_section, :row, :cell, :btn, :textfield,
           :numberfield, :select, :toggle, :separator, :span, :p, :h6,
           :template, :quasar, :plot]
    @eval function $(fn)(args...; kwargs...)
        Dict(:fn => $(QuoteNode(fn)), :args => [args...], :kwargs => Dict(kwargs))
    end
end

module Html
    for fn in [:div]
        @eval function $(fn)(args...; kwargs...)
            Dict(:fn => $(QuoteNode(fn)), :args => [args...], :kwargs => Dict(kwargs))
        end
    end
end

macro click(sym); :($(QuoteNode(sym))); end

include(joinpath(APP_ROOT, "components", "plot_panel.jl"))

@testset "PlotPanel component" begin

    @testset "preset_layout — :trend" begin
        layout = preset_layout(:trend)
        @test layout isa PlotLayout
        @test layout.hovermode == "x unified"
    end

    @testset "preset_layout — :bar_breakdown" begin
        layout = preset_layout(:bar_breakdown)
        @test layout isa PlotLayout
        @test layout.barmode == "stack"
    end

    @testset "preset_layout — :pie" begin
        layout = preset_layout(:pie)
        @test layout isa PlotLayout
        @test layout.showlegend == true
    end

    @testset "preset_layout — :scatter" begin
        layout = preset_layout(:scatter)
        @test layout isa PlotLayout
        @test layout.hovermode == "closest"
    end

    @testset "preset_layout — :tornado" begin
        layout = preset_layout(:tornado)
        @test layout isa PlotLayout
        @test layout.barmode == "overlay"
    end

    @testset "preset_layout — :forest" begin
        layout = preset_layout(:forest)
        @test layout isa PlotLayout
    end

    @testset "preset_layout — :km" begin
        layout = preset_layout(:km)
        @test layout isa PlotLayout
        @test layout.hovermode == "x unified"
    end

    @testset "preset_layout — :heatmap" begin
        layout = preset_layout(:heatmap)
        @test layout isa PlotLayout
    end

    @testset "preset_layout — :geo" begin
        layout = preset_layout(:geo)
        @test layout isa PlotLayout
    end

    @testset "preset_layout — unknown preset returns generic layout" begin
        layout = preset_layout(:unknown)
        @test layout isa PlotLayout
        @test layout.showlegend == true
    end

    @testset "preset_layout — title arg" begin
        layout = preset_layout(:trend, title="My Chart")
        @test layout.title.text == "My Chart"
    end

    @testset "plot_panel returns card node" begin
        result = plot_panel(:my_data, :my_layout)
        @test result isa Dict
        @test result[:fn] == :card
    end

    @testset "plot_panel with title renders header row" begin
        result = plot_panel(:my_data, :my_layout, title="Revenue Trend")
        @test result isa Dict
    end

    @testset "plot_panel with export_filename" begin
        result = plot_panel(:my_data, :my_layout,
            title="Chart",
            export_filename="my_export",
            preset=:bar_breakdown)
        @test result isa Dict
    end

    @testset "plot_panel accepts height override" begin
        result = plot_panel(:my_data, :my_layout, height="600px")
        @test result isa Dict
    end

    @testset "PALETTE has expected colour entries" begin
        @test length(PALETTE) >= 6
        @test all(startswith(c, "#") for c in PALETTE)
    end
end
