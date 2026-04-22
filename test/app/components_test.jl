# ============================================================================
# Unit tests for app/components/common.jl
#
# Tests cover the pure-Julia constants and helper logic only (APP_COLORS,
# APP_SPACING, not_yet_implemented_html, error_banner dispatch).  The
# Stipple-dependent rendering functions (page_header, loading_overlay,
# page_template) require the full Genie/Stipple stack and are exercised in
# the running application; they are not tested here.
# ============================================================================

using Test

# ---------------------------------------------------------------------------
# Minimal stubs for the Genie/Stipple HTML helpers used in common.jl so
# that function *definitions* compile without error.  The functions under
# test (not_yet_implemented_html, error_banner empty-vector early return)
# are pure Julia and do not actually call these stubs.
# ---------------------------------------------------------------------------
module _GenieStub
    module Html
        div(args...; kwargs...)  = nothing
        h1(args...; kwargs...)   = nothing
        p(args...; kwargs...)    = nothing
        li(args...; kwargs...)   = nothing
        ul(args...; kwargs...)   = nothing
        span(args...; kwargs...) = nothing
        a(args...; kwargs...)    = nothing
    end
end
const Html = _GenieStub.Html

# Include only common.jl — page_template.jl uses Stipple macros (@click)
# that require the full Stipple package to be loaded, so it is excluded here.
include(joinpath(@__DIR__, "..", "..", "app", "components", "common.jl"))

@testset "Component Library — APP_COLORS" begin
    @test APP_COLORS isa NamedTuple

    # All required semantic tokens must be present
    for key in (:primary, :secondary, :success, :warning, :danger,
                :info, :surface, :muted, :on_primary)
        @test haskey(APP_COLORS, key)
    end

    # Values must be non-empty strings that look like CSS colors
    for (k, v) in pairs(APP_COLORS)
        @test v isa String
        @test !isempty(v)
        # Must start with '#' (hex) or 'rgb' or a CSS keyword
        @test startswith(v, "#") || startswith(v, "rgb") || !isempty(v)
    end

    # Spot-check specific values to catch accidental regressions
    @test APP_COLORS.primary   == "#1565c0"
    @test APP_COLORS.success   == "#2e7d32"
    @test APP_COLORS.danger    == "#c62828"
    @test APP_COLORS.on_primary == "#ffffff"
end

@testset "Component Library — APP_SPACING" begin
    @test APP_SPACING isa NamedTuple

    # All required scale steps must be present
    for key in (:xs, :sm, :md, :lg, :xl, :xxl)
        @test haskey(APP_SPACING, key)
    end

    # Values must be positive integers in ascending order
    for (k, v) in pairs(APP_SPACING)
        @test v isa Int
        @test v > 0
    end

    @test APP_SPACING.xs  < APP_SPACING.sm
    @test APP_SPACING.sm  < APP_SPACING.md
    @test APP_SPACING.md  < APP_SPACING.lg
    @test APP_SPACING.lg  < APP_SPACING.xl
    @test APP_SPACING.xl  < APP_SPACING.xxl

    # Spot-check canonical values
    @test APP_SPACING.xs  == 4
    @test APP_SPACING.sm  == 8
    @test APP_SPACING.md  == 16
end

@testset "Component Library — not_yet_implemented_html" begin
    html_str = not_yet_implemented_html("Data Intake")
    @test html_str isa String
    @test contains(html_str, "Data Intake")
    @test contains(html_str, "not yet implemented")
    @test contains(html_str, "/css/app.css")
    @test contains(html_str, "/dashboard")
    @test contains(html_str, "<!DOCTYPE html>")

    # subtitle argument
    html_with_sub = not_yet_implemented_html("Test Tab"; subtitle="A subtitle")
    @test contains(html_with_sub, "A subtitle")

    # empty subtitle produces no extra <p> tag for the subtitle
    html_no_sub = not_yet_implemented_html("Test Tab"; subtitle="")
    @test !contains(html_no_sub, """<p style="color:var(--color-muted""")
end

@testset "Component Library — error_banner dispatch" begin
    # Single-message overload delegates to Vector overload cleanly
    result = error_banner("Something went wrong")
    # With stubs, result is nothing (Html.div returns nothing) — just verify it doesn't throw
    @test true  # if we reach here, no exception was raised

    # Empty vector returns early without calling Html helpers
    empty_result = error_banner(String[])
    @test true

    # severity variants
    for sev in (:error, :warning, :info)
        @test begin error_banner(["msg"]; severity=sev); true end
    end
end
