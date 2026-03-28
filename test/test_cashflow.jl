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

@testset "Cash Flow Projections" begin

    # Shared base financials: revenue exceeds expenses so cash accumulates
    base_fin = AnnualFinancials(
        fiscal_year=2024, fiscal_year_end=Date(2024, 12, 31),
        total_operating_revenue=12_000_000.0,
        non_operating_revenue=0.0,
        total_operating_expenses=11_000_000.0,
        depreciation=500_000.0,
        amortization=100_000.0,
        interest_expense=200_000.0,
        long_term_debt=0.0,
        cash_and_equivalents=1_000_000.0,
    )

    @testset "project_monthly_cash_flow - uniform 12-month projection" begin
        projections = project_monthly_cash_flow(base_fin)
        @test length(projections) == 12
        @test projections[1].month == 1
        @test projections[12].month == 12
        @test projections[1].beginning_cash ≈ 1_000_000.0

        # Each month's ending cash feeds into next month's beginning cash
        for i in 1:11
            @test projections[i].ending_cash ≈ projections[i+1].beginning_cash
        end

        # Net cash flow = ending - beginning
        for p in projections
            @test p.net_cash_flow ≈ p.ending_cash - p.beginning_cash
        end
    end

    @testset "project_monthly_cash_flow - cash accumulates when profitable" begin
        projections = project_monthly_cash_flow(base_fin)
        # Revenue > cash expenses => ending cash should exceed starting
        @test projections[12].ending_cash > base_fin.cash_and_equivalents
    end

    @testset "project_monthly_cash_flow - custom beginning cash" begin
        projections = project_monthly_cash_flow(base_fin; beginning_cash=500_000.0)
        @test projections[1].beginning_cash ≈ 500_000.0
    end

    @testset "project_monthly_cash_flow - capex reduces cash" begin
        proj_no_capex = project_monthly_cash_flow(base_fin)
        proj_capex = project_monthly_cash_flow(base_fin; capex_monthly=50_000.0)
        for i in 1:12
            @test proj_capex[i].ending_cash < proj_no_capex[i].ending_cash
            @test proj_capex[i].capital_expenditures ≈ 50_000.0
        end
    end

    @testset "project_monthly_cash_flow - multi-year (24 months)" begin
        projections = project_monthly_cash_flow(base_fin; months=24)
        @test length(projections) == 24
        @test projections[13].month == 13
        # Seasonality cycles: month 13 uses same factor as month 1
    end

    @testset "project_monthly_cash_flow - days_cash_on_hand computed" begin
        projections = project_monthly_cash_flow(base_fin)
        for p in projections
            @test p.days_cash_on_hand > 0.0
        end
    end

    @testset "project_monthly_cash_flow - bad seasonality length errors" begin
        @test_throws ErrorException project_monthly_cash_flow(base_fin;
            seasonality_factors=[1.0, 1.0, 1.0])
    end

    @testset "find_cash_nadir - identifies minimum" begin
        projections = project_monthly_cash_flow(base_fin;
            beginning_cash=200_000.0, capex_monthly=100_000.0)
        nadir = find_cash_nadir(projections)
        @test haskey(pairs(nadir), :month)
        @test haskey(pairs(nadir), :amount)
        @test haskey(pairs(nadir), :days_cash)
        min_cash = minimum(p.ending_cash for p in projections)
        @test nadir.amount ≈ min_cash
    end

    @testset "find_cash_nadir - error on empty" begin
        @test_throws ErrorException find_cash_nadir(MonthlyCashFlow[])
    end

    @testset "line_of_credit_needed - healthy hospital needs none" begin
        healthy = AnnualFinancials(
            fiscal_year=2024, fiscal_year_end=Date(2024, 12, 31),
            total_operating_revenue=15_000_000.0,
            total_operating_expenses=12_000_000.0,
            depreciation=500_000.0, amortization=100_000.0,
            interest_expense=100_000.0, long_term_debt=0.0,
            cash_and_equivalents=5_000_000.0,
        )
        projections = project_monthly_cash_flow(healthy)
        loc = line_of_credit_needed(projections; min_days_cash=30.0)
        @test loc == 0.0
    end

    @testset "line_of_credit_needed - stressed hospital needs LOC" begin
        stressed = AnnualFinancials(
            fiscal_year=2024, fiscal_year_end=Date(2024, 12, 31),
            total_operating_revenue=8_000_000.0,
            total_operating_expenses=9_000_000.0,
            depreciation=200_000.0, amortization=50_000.0,
            interest_expense=100_000.0, long_term_debt=2_000_000.0,
            cash_and_equivalents=200_000.0,
        )
        projections = project_monthly_cash_flow(stressed; capex_monthly=30_000.0)
        loc = line_of_credit_needed(projections; min_days_cash=30.0)
        @test loc > 0.0
    end

    @testset "line_of_credit_needed - empty projections returns zero" begin
        @test line_of_credit_needed(MonthlyCashFlow[]) ≈ 0.0
    end
end
