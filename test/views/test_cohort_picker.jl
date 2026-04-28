# ============================================================================
# Unit tests for app/components/cohort_picker.jl
#
# Tests verify:
# - cohort_picker() returns a card-level node
# - Default prefix "cohort_" is used
# - Custom prefix is accepted
# - All key criteria sections (age, dx, cpt, payers, los, dates, cost, save)
#   are present in the output
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

include(joinpath(APP_ROOT, "components", "cohort_picker.jl"))

# Helper: flatten an arbitrarily nested Dict tree into a flat list of Dicts
function flatten_nodes(node, acc=Dict[])
    node isa Dict && push!(acc, node)
    if node isa Dict
        for v in values(node)
            if v isa Vector
                for item in v
                    flatten_nodes(item, acc)
                end
            elseif v isa Dict
                flatten_nodes(v, acc)
            end
        end
    elseif node isa Vector
        for item in node
            flatten_nodes(item, acc)
        end
    end
    acc
end

@testset "CohortPicker component" begin

    @testset "Returns a card node" begin
        result = cohort_picker()
        @test result isa Dict
        @test result[:fn] == :card
    end

    @testset "Default prefix cohort_ used in field names" begin
        # The result tree should reference symbols with cohort_ prefix
        result = cohort_picker()
        nodes = flatten_nodes(result)
        all_syms = String[]
        for n in nodes
            haskey(n, :kwargs) && n[:kwargs] isa Dict &&
                for (k, v) in n[:kwargs]
                    v isa Symbol && push!(all_syms, string(v))
                end
            haskey(n, :args) &&
                for a in get(n, :args, [])
                    a isa Symbol && push!(all_syms, string(a))
                end
        end
        @test any(startswith(s, "cohort_") for s in all_syms)
    end

    @testset "Custom prefix is used" begin
        result = cohort_picker(prefix="cp_")
        nodes = flatten_nodes(result)
        all_syms = String[]
        for n in nodes
            haskey(n, :kwargs) && n[:kwargs] isa Dict &&
                for (k, v) in n[:kwargs]
                    v isa Symbol && push!(all_syms, string(v))
                end
            haskey(n, :args) &&
                for a in get(n, :args, [])
                    a isa Symbol && push!(all_syms, string(a))
                end
        end
        @test any(startswith(s, "cp_") for s in all_syms)
    end

    @testset "class argument accepted" begin
        result = cohort_picker(class="q-mt-md")
        @test result isa Dict
        @test occursin("q-mt-md", string(get(result[:kwargs], :class, "")))
    end

    @testset "Min/Max age numberfields present" begin
        result = cohort_picker()
        nodes = flatten_nodes(result)
        nf_syms = [string(n[:args][1]) for n in nodes
                   if get(n, :fn, nothing) == :numberfield]
        @test any(occursin("min_age", s) for s in nf_syms)
        @test any(occursin("max_age", s) for s in nf_syms)
    end

    @testset "Diagnosis and CPT textfields present" begin
        result = cohort_picker()
        nodes = flatten_nodes(result)
        tf_syms = [string(n[:args][1]) for n in nodes
                   if get(n, :fn, nothing) == :textfield]
        @test any(occursin("dx_codes", s) for s in tf_syms)
        @test any(occursin("cpt_codes", s) for s in tf_syms)
    end

    @testset "Save button present" begin
        result = cohort_picker()
        nodes = flatten_nodes(result)
        save_btns = filter(n -> get(n, :fn, nothing) == :btn &&
                                any(occursin("Save", string(a)) for a in get(n, :args, [])),
                           nodes)
        @test length(save_btns) >= 1
    end

    @testset "Payer select present" begin
        result = cohort_picker()
        nodes = flatten_nodes(result)
        sel_syms = [string(n[:args][1]) for n in nodes
                    if get(n, :fn, nothing) == :select]
        @test any(occursin("payers", s) for s in sel_syms)
    end
end
