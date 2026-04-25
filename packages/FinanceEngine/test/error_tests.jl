"""
Error handling tests for FinanceEngine.

Tests that FinanceEngine properly throws and handles typed exceptions
from RuralCore when encountering invalid financial inputs or constraint violations.
"""

using Test
using FinanceEngine
using RuralCore
using DataFrames
using Dates

@testset "FinanceEngine — Error Handling" begin
    @testset "DomainValidationError for negative bed count in NPV calculation" begin
        # NPV calculation requires positive bed count
        @test_throws DomainValidationError begin
            config = Dict("beds" => -5, "payer_mix" => Dict("medicare" => 0.5, "medicaid" => 0.5))
            npv_calculation(config)
        end
    end

    @testset "DomainValidationError for invalid payer mix (not summing to 1)" begin
        # Payer mix must sum to 1.0
        @test_throws DomainValidationError begin
            config = Dict(
                "beds" => 25,
                "payer_mix" => Dict("medicare" => 0.5, "medicaid" => 0.3)  # Sums to 0.8
            )
            npv_calculation(config)
        end
    end

    @testset "DataValidationError for missing required financial parameters" begin
        # Missing critical parameters
        @test_throws DataValidationError begin
            config = Dict("beds" => 25)  # Missing payer_mix, discount_rate, etc.
            npv_calculation(config)
        end
    end

    @testset "CalculationError for negative NPV result from invalid inputs" begin
        # Malformed financial data should throw CalculationError
        @test_throws CalculationError begin
            config = Dict(
                "beds" => 25,
                "payer_mix" => Dict("medicare" => 1.0),
                "revenue_per_day" => -100.0  # Negative revenue
            )
            npv_calculation(config)
        end
    end

    @testset "ConfigurationError for unknown DRG code" begin
        # Invalid DRG code
        @test_throws ConfigurationError begin
            config = Dict("drg_code" => "INVALID_DRG_12345")
            drg_payment_calculation(config)
        end
    end

    @testset "DomainValidationError for invalid Monte Carlo parameters" begin
        # Monte Carlo iterations must be positive
        @test_throws DomainValidationError begin
            config = Dict("iterations" => 0)
            monte_carlo_sensitivity(config)
        end
    end

    @testset "RuralCore error types are accessible from FinanceEngine" begin
        # Verify that error types are available for use
        @test DomainValidationError <: RuralHealthError
        @test CalculationError <: RuralHealthError
        @test ConfigurationError <: RuralHealthError
        @test DomainValidationError <: Exception
    end

    @testset "Error messages include financial context" begin
        try
            config = Dict("beds" => -10, "payer_mix" => Dict("medicare" => 1.0))
            npv_calculation(config)
            @test false "Should have thrown DomainValidationError"
        catch e
            @test e isa DomainValidationError
            @test occursin("beds", string(e)) || occursin("negative", string(e))
        end
    end

    @testset "Error inheritance chain is correct" begin
        e1 = DomainValidationError("beds", "-10", "beds > 0", "Beds must be positive")
        e2 = CalculationError("npv", "beds=10,rate=0.05", "NaN result", "Check inputs")
        e3 = ConfigurationError("drg_code", "Unknown DRG")

        @test e1 isa RuralHealthError
        @test e2 isa RuralHealthError
        @test e3 isa RuralHealthError
        @test all(isa.([e1, e2, e3], Exception))
    end

    @testset "Financial constraint violations throw DomainValidationError" begin
        # Discount rate must be between 0 and 1
        @test_throws DomainValidationError begin
            config = Dict(
                "beds" => 25,
                "payer_mix" => Dict("medicare" => 1.0),
                "discount_rate" => 1.5  # Invalid: > 1
            )
            npv_calculation(config)
        end
    end

    @testset "showerror() output includes constraint details" begin
        e = DomainValidationError(
            "discount_rate", "1.5", "0 ≤ discount_rate ≤ 1",
            "Discount rate must be between 0% and 100%"
        )
        s = sprint(showerror, e)

        @test occursin("DomainValidationError", s)
        @test occursin("discount_rate", s)
        @test occursin("1.5", s) || occursin("constraint", s)
    end
end
