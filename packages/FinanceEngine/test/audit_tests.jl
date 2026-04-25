"""
Audit logging tests for FinanceEngine.

Tests that FinanceEngine's financial calculation functions are properly audited
using @audited_calculation macro for regulatory compliance (financial transparency).

FinanceEngine already has ~17 audit calls in place; these tests verify they work correctly.
"""

using Test
using FinanceEngine
using RuralCore
using Dates
using DataFrames

@testset "FinanceEngine — Audit Logging" begin
    @testset "@audited_calculation wraps NPV calculation" begin
        clear_audit_log()

        config = Dict(
            "beds" => 25,
            "payer_mix" => Dict("medicare" => 0.6, "medicaid" => 0.4),
            "revenue_per_day" => 5000.0,
            "operating_cost_per_bed" => 150.0,
            "years" => 5,
            "discount_rate" => 0.05
        )

        # Call NPV calculation with audit wrapper
        result = @audited_calculation npv_calculation(config)

        # Verify result is numeric
        @test result isa Number
        @test !isnan(result)
        @test !isinf(result)

        # Verify audit entry was recorded
        log = get_audit_log()
        @test length(log) == 1

        e = log[1]
        @test e.function_name == "npv_calculation"
        @test !isempty(e.input_hash)
        @test !isempty(e.output_hash)
        @test e.elapsed_ns > 0
        @test e.timestamp isa DateTime
    end

    @testset "@audited_calculation wraps ROI calculation" begin
        clear_audit_log()

        config = Dict(
            "initial_investment" => 500000.0,
            "annual_cash_flow" => 100000.0,
            "years" => 5
        )

        result = @audited_calculation roi_calculation(config)

        # Verify result
        @test result isa Number

        # Verify audit entry
        log = get_audit_log()
        @test length(log) == 1
        @test log[1].function_name == "roi_calculation"
    end

    @testset "@audited_calculation wraps DRG payment calculation" begin
        clear_audit_log()

        config = Dict(
            "drg_code" => "470",  # Valid DRG
            "base_rate" => 5000.0,
            "case_mix_index" => 1.2
        )

        result = @audited_calculation drg_payment_calculation(config)

        # Verify result
        @test result isa Number
        @test result > 0

        # Verify audit entry
        log = get_audit_log()
        @test length(log) == 1
        @test log[1].function_name == "drg_payment_calculation"
    end

    @testset "Multiple financial calculations accumulate audit entries" begin
        clear_audit_log()

        config1 = Dict("beds" => 25, "payer_mix" => Dict("medicare" => 1.0), "revenue_per_day" => 5000.0)
        config2 = Dict("initial_investment" => 500000.0, "annual_cash_flow" => 100000.0, "years" => 5)
        config3 = Dict("drg_code" => "470", "base_rate" => 5000.0, "case_mix_index" => 1.2)

        # Make 3 audited calls
        npv = @audited_calculation npv_calculation(config1)
        roi = @audited_calculation roi_calculation(config2)
        drg = @audited_calculation drg_payment_calculation(config3)

        # Verify 3 audit entries recorded
        log = get_audit_log()
        @test length(log) == 3

        # Verify function names
        @test log[1].function_name == "npv_calculation"
        @test log[2].function_name == "roi_calculation"
        @test log[3].function_name == "drg_payment_calculation"
    end

    @testset "Audit log serializes to valid JSONL" begin
        clear_audit_log()

        config = Dict(
            "beds" => 30,
            "payer_mix" => Dict("medicare" => 0.6, "medicaid" => 0.4),
            "revenue_per_day" => 6000.0
        )
        result = @audited_calculation npv_calculation(config)

        # Save to temporary JSONL file
        tmp_jsonl = tempname() * ".jsonl"
        save_audit_log(tmp_jsonl)

        # Verify file exists and is valid
        @test isfile(tmp_jsonl)

        content = read(tmp_jsonl, String)
        @test !isempty(content)
        @test startswith(strip(content), "{")
        @test endswith(strip(content), "}")

        # Verify financial calculation-related fields
        @test occursin("function_name", content)
        @test occursin("npv_calculation", content)
        @test occursin("input_hash", content)
        @test occursin("output_hash", content)

        rm(tmp_jsonl)
    end

    @testset "Audit entry preserves financial calculation result" begin
        clear_audit_log()

        config = Dict(
            "beds" => 25,
            "payer_mix" => Dict("medicare" => 0.6, "medicaid" => 0.4),
            "revenue_per_day" => 5000.0,
            "operating_cost_per_bed" => 150.0,
            "years" => 5,
            "discount_rate" => 0.05
        )

        result_audited = @audited_calculation npv_calculation(config)
        result_plain = npv_calculation(config)

        # Results should be identical (auditing doesn't change computation)
        @test result_audited ≈ result_plain

        # Verify audit entry was recorded
        log = get_audit_log()
        @test length(log) == 1
    end

    @testset "Audit entry includes all required fields for financial audits" begin
        clear_audit_log()

        config = Dict(
            "beds" => 25,
            "payer_mix" => Dict("medicare" => 1.0),
            "revenue_per_day" => 5000.0
        )

        _ = @audited_calculation npv_calculation(config)

        log = get_audit_log()
        e = log[1]

        # Verify all required audit fields
        @test haskey(e, :timestamp)
        @test haskey(e, :function_name)
        @test haskey(e, :input_hash)
        @test haskey(e, :output_hash)
        @test haskey(e, :elapsed_ns)
        @test haskey(e, :julia_version)
        @test haskey(e, :package_version)
        @test haskey(e, :git_sha)

        # Verify field types
        @test e.timestamp isa DateTime
        @test e.function_name isa String
        @test e.input_hash isa String
        @test e.output_hash isa String
        @test e.elapsed_ns isa Int
    end

    @testset "Different financial scenarios produce different audit hashes" begin
        clear_audit_log()

        # Scenario 1: Low revenue
        config1 = Dict(
            "beds" => 25,
            "payer_mix" => Dict("medicare" => 1.0),
            "revenue_per_day" => 5000.0
        )

        # Scenario 2: High revenue
        config2 = Dict(
            "beds" => 25,
            "payer_mix" => Dict("medicare" => 1.0),
            "revenue_per_day" => 10000.0
        )

        r1 = @audited_calculation npv_calculation(config1)
        r2 = @audited_calculation npv_calculation(config2)

        # Verify audit entries have different hashes (different inputs)
        log = get_audit_log()
        @test length(log) == 2
        @test log[1].input_hash != log[2].input_hash
        @test log[1].output_hash != log[2].output_hash
    end

    @testset "Financial audit trail captures payer mix sensitivity" begin
        clear_audit_log()

        # Test with different payer mixes
        configs = [
            Dict("beds" => 25, "payer_mix" => Dict("medicare" => 0.8, "medicaid" => 0.2), "revenue_per_day" => 5000.0),
            Dict("beds" => 25, "payer_mix" => Dict("medicare" => 0.6, "medicaid" => 0.4), "revenue_per_day" => 5000.0),
            Dict("beds" => 25, "payer_mix" => Dict("medicare" => 0.4, "medicaid" => 0.6), "revenue_per_day" => 5000.0)
        ]

        results = [@audited_calculation npv_calculation(config) for config in configs]

        # Verify 3 audit entries for payer mix sensitivity analysis
        log = get_audit_log()
        @test length(log) == 3

        # All should have different output hashes due to different payer mixes
        output_hashes = [e.output_hash for e in log]
        @test length(unique(output_hashes)) == 3
    end
end
