# ============================================================================
# Integration tests — end-to-end pipelines through multiple domain layers
# ============================================================================

using Test
using Dates

# Include source modules in dependency order
include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "department.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "staffing.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "payer.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "financial.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "capital.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "hospital.jl"))
include(joinpath(@__DIR__, "..", "src", "simulation", "deterministic.jl"))
include(joinpath(@__DIR__, "..", "src", "simulation", "montecarlo.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "ratios.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "reimbursement.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "costreport.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "breakeven.jl"))
include(joinpath(@__DIR__, "..", "src", "risk", "closure.jl"))
include(joinpath(@__DIR__, "..", "src", "risk", "conversion.jl"))
include(joinpath(@__DIR__, "..", "src", "data", "export.jl"))
include(joinpath(@__DIR__, "..", "src", "utils", "constants.jl"))
using .Constants

# ---------------------------------------------------------------------------
# Shared test fixtures
# ---------------------------------------------------------------------------
function integration_test_cah()
    CriticalAccessHospital(;
        name="Integration Test CAH",
        cms_provider_number="171301", npi="1234567890",
        cah_certification_date=Date(2006, 1, 15),
        licensed_beds=25, nearest_hospital_miles=35.0,
        location=GeoLocation(; latitude=38.5, longitude=-98.7,
            fips_code="20009", state="KS", county="Barton", zip_code="67530"),
        service_area=ServiceArea(; primary_service_area_pop=8000,
            total_service_area_pop=12000),
    )
end

function integration_test_financials()
    AnnualFinancials(;
        fiscal_year=2025,
        fiscal_year_end=Date(2025, 12, 31),
        gross_patient_revenue=30_000_000.0,
        inpatient_revenue=8_000_000.0,
        outpatient_revenue=12_000_000.0,
        emergency_revenue=3_500_000.0,
        other_operating_revenue=500_000.0,
        non_operating_revenue=200_000.0,
        contractual_adjustments=12_000_000.0,
        charity_care=400_000.0,
        bad_debt_expense=600_000.0,
        total_deductions=13_000_000.0,
        net_patient_revenue=17_000_000.0,
        total_operating_revenue=17_500_000.0,
        total_revenue=17_700_000.0,
        salaries_wages=9_000_000.0,
        employee_benefits=2_700_000.0,
        supplies=1_800_000.0,
        pharmaceuticals=600_000.0,
        utilities=400_000.0,
        depreciation=800_000.0,
        amortization=50_000.0,
        interest_expense=300_000.0,
        other_operating_expenses=2_000_000.0,
        total_operating_expenses=17_650_000.0,
        operating_income=-150_000.0,
        operating_margin=-0.0086,
        ebitda=1_000_000.0,
        total_assets=25_000_000.0,
        current_assets=5_000_000.0,
        cash_and_equivalents=2_500_000.0,
        net_accounts_receivable=2_000_000.0,
        total_liabilities=12_000_000.0,
        current_liabilities=3_000_000.0,
        long_term_debt=8_000_000.0,
        net_assets=13_000_000.0,
    )
end

@testset "Integration Tests" begin

    # -----------------------------------------------------------------------
    @testset "Pipeline: hospital → deterministic projection → ratios" begin
        hospital = integration_test_cah()
        params = DeterministicParams(; projection_years=5,
            volume_growth_rate=-0.02, cost_inflation_rate=0.03)

        result = project_financials(hospital, params)

        # Result should be a DeterministicResult with 5 yearly projections
        @test result isa DeterministicResult
        @test length(result.projections) == 5

        # Each projection has valid financial data
        for proj in result.projections
            @test proj.total_revenue > 0.0
            @test proj.total_expense > 0.0
            @test -1.0 < proj.operating_margin < 1.0
        end

        # Terminal margin should be a reasonable value
        @test -1.0 < result.terminal_operating_margin < 1.0
    end

    # -----------------------------------------------------------------------
    @testset "Pipeline: financials → ratios → closure risk assessment" begin
        hospital = integration_test_cah()
        financials = integration_test_financials()

        # Step 1: compute financial ratios
        ratios = compute_all_ratios(financials)
        @test ratios.operating_margin isa Float64
        @test ratios.days_cash_on_hand > 0.0

        # Step 2: feed ratios into closure risk assessment
        market = MarketData(true, 0.35, -0.02, 40.0, 0.18, 0.12)
        financial_data = Dict{String,Float64}(
            "operating_margin" => ratios.operating_margin,
            "days_cash_on_hand" => ratios.days_cash_on_hand,
            "current_ratio" => ratios.current_ratio,
            "debt_to_cap" => ratios.debt_to_capitalization,
        )

        assessment = assess_closure_risk(hospital, market;
            financial_data=financial_data)

        @test 0.0 <= assessment.composite_risk_score <= 1.0
        @test assessment.risk_category isa Symbol
        @test assessment.risk_category in [:low, :moderate, :high, :critical]
    end

    # -----------------------------------------------------------------------
    @testset "Pipeline: hospital → Medicare reimbursement → sequestration" begin
        hospital = integration_test_cah()

        result_with = calculate_medicare_reimbursement(hospital; sequestration=true)
        result_without = calculate_medicare_reimbursement(hospital; sequestration=false)

        # Sequestered amount should be less than unsequestered
        @test result_with.total_reimbursement <= result_without.total_reimbursement
        @test result_with.total_reimbursement > 0.0

        # Sequestration should be approximately 2%
        if result_without.total_reimbursement > 0.0
            diff = result_without.total_reimbursement - result_with.total_reimbursement
            pct = diff / result_without.total_reimbursement
            @test isapprox(pct, 0.02; atol=0.005)
        end
    end

    # -----------------------------------------------------------------------
    @testset "Pipeline: cost centers → step-down allocation → CCR" begin
        cost_centers = default_cah_cost_centers()
        @test length(cost_centers) >= 10

        # Assign realistic costs
        for (i, cc) in enumerate(cost_centers)
            cc.direct_cost = 50_000.0 + i * 10_000.0
        end

        allocated = step_down_allocation(cost_centers)
        @test allocated isa Dict{String,Float64}

        # Total allocated should match total direct
        total_direct = sum(cc.direct_cost for cc in cost_centers)
        total_allocated = sum(values(allocated))
        @test isapprox(total_allocated, total_direct; rtol=0.01)

        # Each allocation should be positive
        for (code, amount) in allocated
            @test amount >= 0.0
        end
    end

    # -----------------------------------------------------------------------
    @testset "Pipeline: projection → export → read back" begin
        results = [
            Dict("year" => 2026, "revenue" => 18_500_000.0, "margin" => -0.038),
            Dict("year" => 2027, "revenue" => 19_200_000.0, "margin" => -0.015),
            Dict("year" => 2028, "revenue" => 19_800_000.0, "margin" => 0.005),
        ]

        # Export to CSV
        csv_path = tempname() * ".csv"
        try
            path = export_results_to_csv(results, csv_path)
            @test isfile(path)

            content = read(path, String)
            lines = split(strip(content), "\n")
            @test length(lines) >= 4  # header + 3 data rows
            @test contains(lines[1], "year")
        finally
            isfile(csv_path) && rm(csv_path)
        end

        # Export to JSON
        json_path = tempname() * ".json"
        try
            json_results = Dict(
                "scenario" => "Integration Test",
                "projections" => results,
            )
            path = export_results_to_json(json_results, json_path; pretty=true)
            @test isfile(path)

            content = read(path, String)
            @test contains(content, "Integration Test")
            @test contains(content, "2026")
        finally
            isfile(json_path) && rm(json_path)
        end
    end

    # -----------------------------------------------------------------------
    @testset "Pipeline: break-even analysis on test hospital" begin
        hospital = integration_test_cah()
        results = break_even_by_payer(hospital)
        @test results isa Dict
        @test length(results) >= 1

        for (payer, be) in results
            @test payer isa Symbol
            @test be.break_even_volume >= 0.0 || be.break_even_volume == Inf
        end
    end

    # -----------------------------------------------------------------------
    @testset "Pipeline: deterministic → closure risk year detection" begin
        hospital = integration_test_cah()

        # Aggressive decline scenario
        params = DeterministicParams(;
            projection_years=10,
            volume_growth_rate=-0.05,
            cost_inflation_rate=0.05,
            reimbursement_adjustment=0.005,
        )
        result = project_financials(hospital, params)

        @test result isa DeterministicResult
        @test length(result.projections) == 10
        # With steep volume decline and high cost inflation, margin should worsen
        @test result.projections[10].operating_margin < result.projections[1].operating_margin
    end
end
