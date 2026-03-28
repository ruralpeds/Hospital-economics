# ============================================================================
# Tests for Flex Monitoring financial ratios (src/finance/ratios.jl)
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
include(joinpath(@__DIR__, "..", "src", "finance", "ratios.jl"))

@testset "Financial Ratios" begin

    @testset "operating_margin" begin
        fin = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31),
            operating_income=500_000.0, total_operating_revenue=10_000_000.0)
        @test operating_margin(fin) ≈ 0.05

        fin_zero = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31))
        @test operating_margin(fin_zero) == 0.0
    end

    @testset "total_margin" begin
        fin = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31),
            total_revenue=12_000_000.0, total_operating_expenses=11_400_000.0)
        @test total_margin(fin) ≈ 600_000.0 / 12_000_000.0

        fin_zero = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31))
        @test total_margin(fin_zero) == 0.0
    end

    @testset "days_cash_on_hand" begin
        fin = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31),
            cash_and_equivalents=1_000_000.0, total_operating_expenses=3_650_000.0,
            depreciation=200_000.0, amortization=50_000.0)
        expected = 1_000_000.0 / ((3_650_000.0 - 250_000.0) / 365.0)
        @test days_cash_on_hand(fin) ≈ expected
        # Zero cash expenses => Inf
        fin_zero = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31),
            cash_and_equivalents=100_000.0, total_operating_expenses=100_000.0,
            depreciation=60_000.0, amortization=40_000.0)
        @test days_cash_on_hand(fin_zero) == Inf
    end

    @testset "current_ratio" begin
        fin = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31),
            current_assets=3_000_000.0, current_liabilities=2_000_000.0)
        @test current_ratio(fin) ≈ 1.5

        fin_zero = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31),
            current_assets=1_000_000.0, current_liabilities=0.0)
        @test current_ratio(fin_zero) == Inf
    end

    @testset "debt_to_capitalization" begin
        fin = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31),
            total_liabilities=4_000_000.0, net_assets=6_000_000.0)
        @test debt_to_capitalization(fin) ≈ 0.4

        fin_zero = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31))
        @test debt_to_capitalization(fin_zero) == 0.0
    end

    @testset "average_age_of_plant" begin
        fin = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31),
            depreciation=500_000.0, average_age_of_plant=12.0)
        @test average_age_of_plant(fin) ≈ 12.0

        fin_zero = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31))
        @test average_age_of_plant(fin_zero) == 0.0
    end

    @testset "salary_to_revenue" begin
        fin = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31),
            salaries_wages=4_000_000.0, employee_benefits=1_200_000.0,
            total_operating_revenue=10_000_000.0)
        @test salary_to_revenue(fin) ≈ 0.52

        fin_zero = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31))
        @test salary_to_revenue(fin_zero) == 0.0
    end

    @testset "outpatient_revenue_share" begin
        fin = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31),
            outpatient_revenue=7_000_000.0, total_operating_revenue=10_000_000.0)
        @test outpatient_revenue_share(fin) ≈ 0.7

        fin_zero = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31))
        @test outpatient_revenue_share(fin_zero) == 0.0
    end

    @testset "medicare_cost_to_charge_ratio" begin
        fin = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31),
            medicare_cost_to_charge_ratio=0.45)
        @test medicare_cost_to_charge_ratio(fin) ≈ 0.45
    end

    @testset "fte_per_adjusted_occupied_bed" begin
        fin = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31),
            total_operating_revenue=10_000_000.0, inpatient_revenue=4_000_000.0)
        staff = StaffingModel(positions=[
            StaffPosition(title="RN", category=:nursing, fte=10.0, annual_salary=70_000.0),
            StaffPosition(title="Tech", category=:allied_health, fte=5.0, annual_salary=45_000.0),
        ])
        result = fte_per_adjusted_occupied_bed(fin, staff, 25, 8.0)
        adj_factor = 10_000_000.0 / 4_000_000.0
        expected = 15.0 / (8.0 * adj_factor)
        @test result ≈ expected

        # Zero ADC returns 0.0
        @test fte_per_adjusted_occupied_bed(fin, staff, 25, 0.0) == 0.0

        # Zero inpatient revenue returns 0.0
        fin_no_ip = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31),
            total_operating_revenue=10_000_000.0, inpatient_revenue=0.0)
        @test fte_per_adjusted_occupied_bed(fin_no_ip, staff, 25, 8.0) == 0.0
    end

    @testset "compute_all_ratios without staffing" begin
        fin = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31),
            total_operating_revenue=10_000_000.0, operating_income=300_000.0,
            total_revenue=11_000_000.0, total_operating_expenses=10_500_000.0,
            current_assets=2_000_000.0, current_liabilities=1_500_000.0,
            cash_and_equivalents=500_000.0)
        ratios = compute_all_ratios(fin)
        @test ratios.operating_margin ≈ operating_margin(fin)
        @test ismissing(ratios.fte_per_adjusted_occupied_bed)
    end

    @testset "compute_all_ratios with staffing" begin
        fin = AnnualFinancials(fiscal_year=2024, fiscal_year_end=Date(2024,12,31),
            total_operating_revenue=10_000_000.0, inpatient_revenue=4_000_000.0,
            operating_income=200_000.0, total_revenue=10_500_000.0,
            total_operating_expenses=10_000_000.0,
            current_assets=2_000_000.0, current_liabilities=1_000_000.0,
            cash_and_equivalents=400_000.0)
        staff = StaffingModel(positions=[
            StaffPosition(title="RN", category=:nursing, fte=12.0, annual_salary=70_000.0)])
        ratios = compute_all_ratios(fin, staff, 25, 6.0)
        @test !ismissing(ratios.fte_per_adjusted_occupied_bed)
        @test ratios.fte_per_adjusted_occupied_bed ≈ fte_per_adjusted_occupied_bed(fin, staff, 25, 6.0)
    end
end
