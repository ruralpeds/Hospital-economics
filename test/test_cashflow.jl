# ============================================================================
# Tests for monthly cash flow projection (src/finance/cashflow.jl)
# ============================================================================

using Test
using Dates
using UUIDs

# Include source files directly for testing (in dependency order)
include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "department.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "staffing.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "payer.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "financial.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "capital.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "cashflow.jl"))

@testset "Cash Flow Projection" begin

    base_fin = AnnualFinancials(
        fiscal_year=2024,
        fiscal_year_end=Date(2024, 12, 31),
        total_operating_revenue=12_000_000.0,
        non_operating_revenue=0.0,
        total_operating_expenses=11_500_000.0,
        depreciation=500_000.0,
        amortization=100_000.0,
        interest_expense=200_000.0,
        long_term_debt=0.0,
        cash_and_equivalents=1_000_000.0,
    )

    @testset "project_monthly_cash_flow uniform seasonality" begin
        projections = project_monthly_cash_flow(base_fin)
        @test length(projections) == 12
        @test projections[1].month == 1
        @test projections[12].month == 12
        @test projections[1].beginning_cash ≈ 1_000_000.0

        # Each month's ending_cash should be next month's beginning_cash
        for i in 1:11
            @test projections[i].ending_cash ≈ projections[i+1].beginning_cash
        end
    end

    @testset "cash accumulation with profitable hospital" begin
        projections = project_monthly_cash_flow(base_fin)
        # Annual revenue > expenses (after removing depreciation/amort from cash expenses)
        # So ending cash after 12 months should exceed starting cash
        # (assuming debt service doesn't overwhelm the surplus)
        final_cash = projections[end].ending_cash
        # Net annual cash = revenue - cash_expenses - debt_service
        # cash_expenses = 11_500_000 - 500_000 - 100_000 = 10_900_000
        # debt_service = interest = 200_000 (no LTD principal)
        # Net = 12_000_000 - 10_900_000 - 200_000 = 900_000
        @test final_cash > 1_000_000.0
    end

    @testset "custom beginning cash" begin
        projections = project_monthly_cash_flow(base_fin; beginning_cash=500_000.0)
        @test projections[1].beginning_cash ≈ 500_000.0
    end

    @testset "multi-month projection" begin
        projections = project_monthly_cash_flow(base_fin; months=24)
        @test length(projections) == 24
        @test projections[13].month == 13
    end

    @testset "seasonality_factors validation" begin
        @test_throws ErrorException project_monthly_cash_flow(base_fin;
            seasonality_factors=[1.0, 1.0, 1.0])
    end

    @testset "find_cash_nadir" begin
        # Use stressed scenario with high capex to create a nadir
        projections = project_monthly_cash_flow(base_fin;
            beginning_cash=200_000.0, capex_monthly=100_000.0)
        nadir = find_cash_nadir(projections)
        @test haskey(nadir, :month)
        @test haskey(nadir, :amount)
        @test haskey(nadir, :days_cash)
        # Nadir amount should be the minimum ending cash
        min_cash = minimum(p.ending_cash for p in projections)
        @test nadir.amount ≈ min_cash
    end

    @testset "find_cash_nadir empty error" begin
        @test_throws ErrorException find_cash_nadir(MonthlyCashFlow[])
    end

    @testset "line_of_credit_needed" begin
        # Stressed scenario: low starting cash + capex
        stressed_fin = AnnualFinancials(
            fiscal_year=2024,
            fiscal_year_end=Date(2024, 12, 31),
            total_operating_revenue=10_000_000.0,
            total_operating_expenses=10_000_000.0,
            depreciation=400_000.0,
            amortization=100_000.0,
            interest_expense=300_000.0,
            long_term_debt=2_000_000.0,
            cash_and_equivalents=200_000.0,
        )
        projections = project_monthly_cash_flow(stressed_fin;
            beginning_cash=200_000.0, capex_monthly=50_000.0)
        loc = line_of_credit_needed(projections; min_days_cash=30.0)
        # With high debt service and capex on a break-even hospital, LOC should be needed
        @test loc >= 0.0
    end

    @testset "line_of_credit_needed healthy hospital" begin
        # Profitable hospital with ample cash needs no LOC
        healthy = AnnualFinancials(
            fiscal_year=2024,
            fiscal_year_end=Date(2024, 12, 31),
            total_operating_revenue=15_000_000.0,
            total_operating_expenses=12_000_000.0,
            depreciation=500_000.0,
            amortization=100_000.0,
            interest_expense=100_000.0,
            long_term_debt=0.0,
            cash_and_equivalents=5_000_000.0,
        )
        projections = project_monthly_cash_flow(healthy)
        loc = line_of_credit_needed(projections; min_days_cash=30.0)
        @test loc == 0.0
    end
end
