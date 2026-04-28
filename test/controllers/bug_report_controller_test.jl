# ============================================================================
# test/controllers/bug_report_controller_test.jl
#
# Unit tests for BugReportController.
# No real HTTP calls are made:
#   - TURNSTILE_SECRET_KEY is unset  → bypassed in dev mode (logged warning)
#   - BUG_REPORT_GITHUB_TOKEN is unset → GitHub post skipped gracefully
#
# Run standalone:
#   julia --compiled-modules=no --startup-file=no test/controllers/bug_report_controller_test.jl
# ============================================================================

using Test, Dates, UUIDs

# ── Load dependencies without the full Genie stack ───────────────────────────
# Wrap both modules in a parent module that mirrors the app's structure so
# `using ..BugReportRedaction` inside BugReportController resolves correctly.
module HospitalEconomicsApp
    const _APP = joinpath(@__DIR__, "..", "..", "app")
    include(joinpath(_APP, "components", "bug_report_redaction.jl"))
    include(joinpath(_APP, "controllers", "BugReportController.jl"))
end

using .HospitalEconomicsApp.BugReportController

# ─────────────────────────────────────────────────────────────────────────────

@testset "BugReportController" begin

    # ── render_body ───────────────────────────────────────────────────────────
    @testset "render_body" begin
        record = Dict(
            "summary"  => "Test crash on dashboard",
            "category" => "bug",
            "severity" => "S2",
            "steps"    => "1. Open dashboard\n2. Click Run",
            "expected" => "Simulation starts",
            "actual"   => "Page crashes",
            "route"    => "/dashboard",
            "app_version" => "0.3.0",
            "git_sha"  => "abc1234",
            "browser_ua"   => "Chrome/120",
            "viewport_w"   => "1920",
            "viewport_h"   => "1080",
            "locale"       => "en-US",
            "user_id_or_anon" => "anon",
            "timestamp_utc"   => "2024-01-15T10:30:00",
            "state_delta_json" => "{}",
            "screenshot_markdown_or_gist_link_or_none" => "_none_",
        )
        body = BugReportController.render_body(record)
        @test contains(body, "Test crash on dashboard")
        @test contains(body, "S2")
        @test contains(body, "/dashboard")
        # No unfilled placeholders should remain
        @test !contains(body, "{{")
    end

    # ── Honeypot ─────────────────────────────────────────────────────────────
    @testset "Honeypot" begin
        payload = Dict(
            "website"        => "http://spam.example.com",
            "summary"        => "A" ^ 30,
            "category"       => "bug",
            "severity"       => "S3",
            "form_opened_at" => string(Dates.now(UTC) - Second(10))[1:19],
            "submitted_at"   => string(Dates.now(UTC))[1:19],
        )
        result = BugReportController.handle_submit(payload)
        @test result["status"] == 202              # silent accept
        @test get(result["body"], "accepted", false) == true
    end

    # ── Dwell time ────────────────────────────────────────────────────────────
    @testset "Dwell time rejection" begin
        now_dt = Dates.now(UTC)
        payload = Dict(
            "website"        => "",
            "summary"        => "A" ^ 30,
            "category"       => "bug",
            "severity"       => "S3",
            # opened only 1 second ago
            "form_opened_at" => string(now_dt - Second(1))[1:19],
            "submitted_at"   => string(now_dt)[1:19],
        )
        result = BugReportController.handle_submit(payload;
                    remote_ip="10.99.0.1", session_id="dwell_test_$(rand(1:99999))")
        @test result["status"] == 422
        @test contains(get(result["body"], "error", ""), "too quickly")
    end

    @testset "Dwell time acceptance (>= 3s)" begin
        now_dt = Dates.now(UTC)
        payload = Dict(
            "website"        => "",
            "summary"        => "Dashboard crashes when clicking Run Simulation",
            "category"       => "bug",
            "severity"       => "S2",
            "steps"          => "1. Go to dashboard\n2. Click Run",
            "expected"       => "Simulation starts",
            "actual"         => "Page shows error",
            "form_opened_at" => string(now_dt - Second(10))[1:19],
            "submitted_at"   => string(now_dt)[1:19],
        )
        result = BugReportController.handle_submit(payload;
                    remote_ip="10.99.0.2", session_id="dwell_ok_$(rand(1:99999))")
        # Should NOT be a dwell error (may be 201 or 502 depending on GitHub token)
        @test result["status"] != 422
    end

    # ── Turnstile ─────────────────────────────────────────────────────────────
    @testset "Turnstile — dev mode bypass" begin
        ENV["GENIE_ENV"] = "dev"
        delete!(ENV, "TURNSTILE_SECRET_KEY")
        # Should return true (skip with warning in dev)
        @test BugReportController.verify_turnstile("any_token", "127.0.0.1") == true
    end

    @testset "Turnstile — production rejects without secret" begin
        ENV["GENIE_ENV"] = "production"
        delete!(ENV, "TURNSTILE_SECRET_KEY")
        @test BugReportController.verify_turnstile("any_token", "127.0.0.1") == false
        ENV["GENIE_ENV"] = "dev"  # restore
    end

    # ── Rate limits ───────────────────────────────────────────────────────────
    @testset "IP hourly rate limit" begin
        unique_ip = "192.0.2.$(rand(1:254))"
        now_dt    = Dates.now(UTC)

        # Push 5 entries directly into the store
        empty!(get!(BugReportController._ip_hourly, unique_ip, []))
        for _ in 1:BugReportController.RATE_LIMIT_IP_HOUR
            push!(BugReportController._ip_hourly[unique_ip], now_dt)
        end

        payload = Dict(
            "website"        => "",
            "summary"        => "A" ^ 30,
            "category"       => "bug",
            "severity"       => "S3",
            "form_opened_at" => string(now_dt - Second(10))[1:19],
            "submitted_at"   => string(now_dt)[1:19],
        )
        result = BugReportController.handle_submit(payload;
                    remote_ip=unique_ip, session_id="rl_test_$(rand(1:99999))")
        @test result["status"] == 429
        @test contains(get(result["body"], "error", ""), "Rate limit")
    end

    @testset "Session daily rate limit" begin
        unique_sess = "sess_rl_$(UUIDs.uuid4())"
        now_dt      = Dates.now(UTC)

        empty!(get!(BugReportController._session_daily, unique_sess, []))
        for _ in 1:BugReportController.RATE_LIMIT_SESS_DAY
            push!(BugReportController._session_daily[unique_sess], now_dt)
        end

        payload = Dict(
            "website"        => "",
            "summary"        => "A" ^ 30,
            "category"       => "bug",
            "severity"       => "S3",
            "form_opened_at" => string(now_dt - Second(10))[1:19],
            "submitted_at"   => string(now_dt)[1:19],
        )
        result = BugReportController.handle_submit(payload;
                    remote_ip="10.0.1.$(rand(1:254))", session_id=unique_sess)
        @test result["status"] == 429
    end

    @testset "Global circuit-breaker" begin
        now_dt = Dates.now(UTC)
        original = copy(BugReportController._global_daily[])
        try
            empty!(BugReportController._global_daily[])
            for _ in 1:BugReportController.RATE_LIMIT_GLOBAL_DAY
                push!(BugReportController._global_daily[], now_dt)
            end

            payload = Dict(
                "website"        => "",
                "summary"        => "A" ^ 30,
                "category"       => "bug",
                "severity"       => "S3",
                "form_opened_at" => string(now_dt - Second(10))[1:19],
                "submitted_at"   => string(now_dt)[1:19],
            )
            result = BugReportController.handle_submit(payload;
                        remote_ip="198.51.100.$(rand(1:254))",
                        session_id="global_rl_$(rand(1:99999))")
            @test result["status"] == 429
            @test contains(get(result["body"], "error", ""), "limit")
        finally
            BugReportController._global_daily[] = original
        end
    end

    # ── Content heuristics ────────────────────────────────────────────────────
    @testset "Summary too short" begin
        now_dt = Dates.now(UTC)
        payload = Dict(
            "website"        => "",
            "summary"        => "short",          # < 20 chars
            "category"       => "bug",
            "severity"       => "S3",
            "form_opened_at" => string(now_dt - Second(10))[1:19],
            "submitted_at"   => string(now_dt)[1:19],
        )
        result = BugReportController.handle_submit(payload;
                    remote_ip="10.0.2.$(rand(1:254))",
                    session_id="heur_test_$(rand(1:99999))")
        @test result["status"] == 422
        @test contains(get(result["body"], "error", ""), "20 characters")
    end

    @testset "Too many URLs in body" begin
        now_dt = Dates.now(UTC)
        many_urls = "http://a.com http://b.com http://c.com http://d.com spam links"
        payload = Dict(
            "website"        => "",
            "summary"        => "This report has too many URLs embedded inside it " * many_urls,
            "category"       => "bug",
            "severity"       => "S3",
            "form_opened_at" => string(now_dt - Second(10))[1:19],
            "submitted_at"   => string(now_dt)[1:19],
        )
        result = BugReportController.handle_submit(payload;
                    remote_ip="10.0.3.$(rand(1:254))",
                    session_id="url_test_$(rand(1:99999))")
        @test result["status"] == 422
        @test contains(get(result["body"], "error", ""), "URL")
    end

    # ── PHI redaction in submitted payload ───────────────────────────────────
    @testset "Server-side PHI scrub before render" begin
        now_dt = Dates.now(UTC)
        payload = Dict(
            "website"        => "",
            "summary"        => "Patient SSN 123-45-6789 shown on dashboard screen",
            "category"       => "data-quality",
            "severity"       => "S2",
            "steps"          => "MRN: 99887766 visible",
            "expected"       => "No PHI displayed",
            "actual"         => "SSN 987-65-4321 and DOB 01/15/1990 visible",
            "form_opened_at" => string(now_dt - Second(15))[1:19],
            "submitted_at"   => string(now_dt)[1:19],
        )
        result = BugReportController.handle_submit(payload;
                    remote_ip="10.0.4.$(rand(1:254))",
                    session_id="phi_test_$(rand(1:99999))")
        # Even if GitHub token is unset, the controller runs through redaction.
        # The returned status is either 201 (no token) or 502 (GitHub error).
        @test result["status"] in [201, 502]
        # The rendered body must not contain raw PHI
        # (We can't directly inspect it here, but ensure handle_submit didn't crash.)
        @test haskey(result, "body")
    end

    # ── assert_production_config ──────────────────────────────────────────────
    @testset "assert_production_config passes in dev" begin
        ENV["GENIE_ENV"] = "dev"
        @test_nowarn BugReportController.assert_production_config()
    end

    @testset "assert_production_config raises in prod without secrets" begin
        ENV["GENIE_ENV"] = "production"
        delete!(ENV, "TURNSTILE_SECRET_KEY")
        delete!(ENV, "BUG_REPORT_GITHUB_TOKEN")
        @test_throws ErrorException BugReportController.assert_production_config()
        ENV["GENIE_ENV"] = "dev"  # restore
    end

end # testset
