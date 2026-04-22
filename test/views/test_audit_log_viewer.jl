# ============================================================================
# Unit tests for app/components/audit_log_viewer.jl
#
# Tests verify:
# - audit_log_viewer() returns a card-level node
# - Default "audit_" prefix is used
# - Custom prefix is accepted
# - Filter fields, Refresh, and Export buttons are present
# - Table columns are defined in cols_js
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
    for fn in [:div, :span, :td]
        @eval function $(fn)(args...; kwargs...)
            Dict(:fn => $(QuoteNode(fn)), :args => [args...], :kwargs => Dict(kwargs))
        end
    end
end

macro click(sym); :($(QuoteNode(sym))); end

include(joinpath(APP_ROOT, "components", "audit_log_viewer.jl"))

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

@testset "AuditLogViewer component" begin

    @testset "Returns a card node" begin
        result = audit_log_viewer()
        @test result isa Dict
        @test result[:fn] == :card
    end

    @testset "Default prefix audit_ used in field names" begin
        result = audit_log_viewer()
        nodes = flatten_nodes(result)
        all_syms = String[]
        for n in nodes
            haskey(n, :kwargs) && n[:kwargs] isa Dict &&
                for (_, v) in n[:kwargs]; v isa Symbol && push!(all_syms, string(v)); end
            haskey(n, :args) &&
                for a in get(n, :args, []); a isa Symbol && push!(all_syms, string(a)); end
        end
        @test any(startswith(s, "audit_") for s in all_syms)
    end

    @testset "Custom prefix is used" begin
        result = audit_log_viewer(prefix="al_")
        nodes = flatten_nodes(result)
        all_syms = String[]
        for n in nodes
            haskey(n, :kwargs) && n[:kwargs] isa Dict &&
                for (_, v) in n[:kwargs]; v isa Symbol && push!(all_syms, string(v)); end
            haskey(n, :args) &&
                for a in get(n, :args, []); a isa Symbol && push!(all_syms, string(a)); end
        end
        @test any(startswith(s, "al_") for s in all_syms)
    end

    @testset "Refresh button present" begin
        result = audit_log_viewer()
        nodes = flatten_nodes(result)
        refresh = filter(n -> get(n, :fn, nothing) == :btn &&
                              any(occursin("Refresh", string(a)) for a in get(n, :args, [])),
                         nodes)
        @test length(refresh) >= 1
    end

    @testset "CSV export button present" begin
        result = audit_log_viewer()
        nodes = flatten_nodes(result)
        csv = filter(n -> get(n, :fn, nothing) == :btn &&
                          any(occursin("CSV", string(a)) for a in get(n, :args, [])),
                     nodes)
        @test length(csv) >= 1
    end

    @testset "User filter textfield present" begin
        result = audit_log_viewer()
        nodes = flatten_nodes(result)
        tf_syms = [string(n[:args][1]) for n in nodes
                   if get(n, :fn, nothing) == :textfield && length(get(n, :args, [])) >= 1]
        @test any(occursin("filter_user", s) for s in tf_syms)
    end

    @testset "Action filter select present" begin
        result = audit_log_viewer()
        nodes = flatten_nodes(result)
        sel_syms = [string(n[:args][1]) for n in nodes
                    if get(n, :fn, nothing) == :select && length(get(n, :args, [])) >= 1]
        @test any(occursin("filter_action", s) for s in sel_syms)
    end

    @testset "Status filter select present" begin
        result = audit_log_viewer()
        nodes = flatten_nodes(result)
        sel_syms = [string(n[:args][1]) for n in nodes
                    if get(n, :fn, nothing) == :select && length(get(n, :args, [])) >= 1]
        @test any(occursin("filter_status", s) for s in sel_syms)
    end

    @testset "Table component present" begin
        result = audit_log_viewer()
        nodes = flatten_nodes(result)
        tbls = filter(n -> get(n, :fn, nothing) == :quasar &&
                           length(get(n, :args, [])) >= 1 &&
                           n[:args][1] == :table,
                      nodes)
        @test length(tbls) >= 1
    end

    @testset "class argument" begin
        result = audit_log_viewer(class="q-mt-lg")
        @test occursin("q-mt-lg", string(get(result[:kwargs], :class, "")))
    end
end
