# ============================================================================
# Unit tests for app/components/scenario_picker.jl
#
# Tests verify:
# - scenario_picker() returns a card-level node
# - Default field symbols are used
# - Custom field names are respected
# - Load, Delete, and New buttons are present
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
    for fn in [:div, :span]
        @eval function $(fn)(args...; kwargs...)
            Dict(:fn => $(QuoteNode(fn)), :args => [args...], :kwargs => Dict(kwargs))
        end
    end
end

macro click(sym); :($(QuoteNode(sym))); end

include(joinpath(APP_ROOT, "components", "scenario_picker.jl"))

# Flatten helper
function flatten_nodes(node, acc=Dict[])
    node isa Dict && push!(acc, node)
    if node isa Dict
        for v in values(node)
            if v isa Vector
                for item in v; flatten_nodes(item, acc); end
            elseif v isa Dict
                flatten_nodes(v, acc)
            end
        end
    elseif node isa Vector
        for item in node; flatten_nodes(item, acc); end
    end
    acc
end

@testset "ScenarioPicker component" begin

    @testset "Returns a card node" begin
        result = scenario_picker()
        @test result isa Dict
        @test result[:fn] == :card
    end

    @testset "Default field :selected_scenario_id is referenced" begin
        result = scenario_picker()
        nodes = flatten_nodes(result)
        all_syms = String[]
        for n in nodes
            haskey(n, :kwargs) && n[:kwargs] isa Dict &&
                for (_, v) in n[:kwargs]; v isa Symbol && push!(all_syms, string(v)); end
            haskey(n, :args) &&
                for a in get(n, :args, []); a isa Symbol && push!(all_syms, string(a)); end
        end
        @test any(occursin("selected_scenario_id", s) for s in all_syms)
    end

    @testset "Custom field kwarg respected" begin
        result = scenario_picker(field=:my_scenario)
        nodes = flatten_nodes(result)
        all_syms = String[]
        for n in nodes
            haskey(n, :kwargs) && n[:kwargs] isa Dict &&
                for (_, v) in n[:kwargs]; v isa Symbol && push!(all_syms, string(v)); end
            haskey(n, :args) &&
                for a in get(n, :args, []); a isa Symbol && push!(all_syms, string(a)); end
        end
        @test any(occursin("my_scenario", s) for s in all_syms)
    end

    @testset "Load button present" begin
        result = scenario_picker()
        nodes = flatten_nodes(result)
        load_btns = filter(n -> get(n, :fn, nothing) == :btn &&
                                any(occursin("Load", string(a)) for a in get(n, :args, [])),
                           nodes)
        @test length(load_btns) >= 1
    end

    @testset "Delete button present" begin
        result = scenario_picker()
        nodes = flatten_nodes(result)
        del_btns = filter(n -> get(n, :fn, nothing) == :btn &&
                               any(occursin("Delete", string(a)) for a in get(n, :args, [])),
                          nodes)
        @test length(del_btns) >= 1
    end

    @testset "New scenario button present" begin
        result = scenario_picker()
        nodes = flatten_nodes(result)
        new_btns = filter(n -> get(n, :fn, nothing) == :btn &&
                               any(occursin("New", string(a)) for a in get(n, :args, [])),
                          nodes)
        @test length(new_btns) >= 1
    end

    @testset "class argument" begin
        result = scenario_picker(class="q-mb-lg")
        @test occursin("q-mb-lg", string(get(result[:kwargs], :class, "")))
    end
end
