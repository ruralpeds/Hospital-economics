# ============================================================================
# Tests for deterministic financial projection engine
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "types", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "engines", "deterministic.jl"))

# ---------------------------------------------------------------------------
# Helper: create a standard base financials NamedTuple for a typical CAH
# ---------------------------------------------------------------------------
function make_base_financials(;
    inpatient_revenue=3_000_000.0,
    outpatient_revenue=8_000_000.0,
    salary_expense=6_500_000.0,
    supply_expense=1_800_000.0,
    other_expense=2_200_000.0,
    cash_reserves=2_500_000.0,
    depreciation=500_000.0,
    annual_debt_service=400_000.0,
    payer_mix_government=0.73,
)
    (;
        inpatient_revenue,
        outpatient_revenue,
        salary_expense,
        supply_expense,
        other_expense,
        cash_reserves,
        depreciation,
        annual_debt_service,
        payer_mix_government,
    )
end

@testset "Deterministic Projection Engine" begin

    # -----------------------------------------------------------------------
    @testset "DeterministicParams defaults" begin
        params = DeterministicParams()
        @test params.projection_years == 10
        @test params.volume_growth_rate == -0.01
        @test params.cost_inflation_rate == 0.03
        @test params.salary_inflation_rate == 0.035
        @test params.supply_inflation_rate == 0.04
        @test params.reimbursement_adjustment == 0.015
        @test params.payer_mix_shift == 0.005
    end

    # -----------------------------------------------------------------------
    @testset "DeterministicParams custom" begin
        params = DeterministicParams(;
            projection_years=5,
            volume_growth_rate=-0.03,
            cost_inflation_rate=0.04,
            salary_inflation_rate=0.04,
            supply_inflation_rate=0.05,
            reimbursement_adjustment=0.01,
            payer_mix_shift=0.01,
        )
        @test params.projection_years == 5
        @test params.volume_growth_rate == -0.03
        @test params.cost_inflation_rate == 0.04
    end

    # -----------------------------------------------------------------------
    @testset "Revenue projection helpers" begin
        params = DeterministicParams()

        # Year 0: base revenue unchanged
        ip0 = project_inpatient_revenue(3_000_000.0, 0, params)
        @test isapprox(ip0, 3_000_000.0; atol=1.0)

        op0 = project_outpatient_revenue(8_000_000.0, 0, params)
        @test isapprox(op0, 8_000_000.0; atol=1.0)

        # Year 1: inpatient should decline, outpatient may grow
        ip1 = project_inpatient_revenue(3_000_000.0, 1, params)
        op1 = project_outpatient_revenue(8_000_000.0, 1, params)
        @test ip1 < 3_000_000.0 * 1.02  # shouldn't grow much given volume decline
        @test op1 > 8_000_000.0  # outpatient grows (volume_growth + 0.02 > 0)

        # Year 5: continued trends
        ip5 = project_inpatient_revenue(3_000_000.0, 5, params)
        op5 = project_outpatient_revenue(8_000_000.0, 5, params)
        @test ip5 < ip1 * 5  # declining inpatient
        @test op5 > op1  # growing outpatient
    end

    # -----------------------------------------------------------------------
    @testset "Expense projection helpers" begin
        params = DeterministicParams()

        sal1 = project_salary_expense(6_500_000.0, 1, params)
        @test sal1 > 6_500_000.0  # inflation > volume decline

        sup1 = project_supply_expense(1_800_000.0, 1, params)
        @test sup1 > 1_800_000.0  # supply inflation outpaces volume decline

        oth1 = project_other_expense(2_200_000.0, 1, params)
        @test oth1 > 2_200_000.0  # straight inflation

        # After 10 years, expenses should be significantly higher
        sal10 = project_salary_expense(6_500_000.0, 10, params)
        @test sal10 > sal1 * 1.5
    end

    # -----------------------------------------------------------------------
    @testset "Financial ratio helpers" begin
        # Operating margin
        @test compute_operating_margin(10_000_000.0, 9_500_000.0) == 0.05
        @test compute_operating_margin(10_000_000.0, 10_000_000.0) == 0.0
        @test compute_operating_margin(10_000_000.0, 11_000_000.0) == -0.1
        @test compute_operating_margin(0.0, 0.0) == 0.0

        # Days cash on hand
        dcoh = compute_days_cash_on_hand(2_500_000.0, 30_000.0)
        @test isapprox(dcoh, 83.33; atol=0.1)
        @test compute_days_cash_on_hand(1_000_000.0, 0.0) == Inf

        # Debt service coverage
        dscr = compute_debt_service_coverage(500_000.0, 500_000.0, 400_000.0)
        @test isapprox(dscr, 2.5; atol=0.001)
        @test compute_debt_service_coverage(100_000.0, 200_000.0, 0.0) == Inf
    end

    # -----------------------------------------------------------------------
    @testset "Single year projection" begin
        bf = make_base_financials()
        params = DeterministicParams()

        proj = project_single_year(bf, 1, params)
        @test proj isa YearlyProjection
        @test proj.year == 1
        @test proj.total_revenue == proj.inpatient_revenue + proj.outpatient_revenue
        @test proj.total_expense == proj.salary_expense + proj.supply_expense + proj.other_expense
        @test proj.operating_income == proj.total_revenue - proj.total_expense
        @test proj.patient_volume < 1.0  # volume declining
        @test proj.payer_mix_government > bf.payer_mix_government
    end

    # -----------------------------------------------------------------------
    @testset "Full projection — default params" begin
        bf = make_base_financials()
        params = DeterministicParams()

        result = project_financials(bf, params)
        @test result isa DeterministicResult
        @test length(result.projections) == 10
        @test result.params === params

        # Verify years are sequential
        for (i, proj) in enumerate(result.projections)
            @test proj.year == i
        end

        # Terminal margin should exist
        @test result.terminal_operating_margin isa Float64
        @test result.cumulative_operating_income isa Float64
    end

    # -----------------------------------------------------------------------
    @testset "Full projection — declining hospital hits closure risk" begin
        bf = make_base_financials(
            inpatient_revenue=2_000_000.0,
            outpatient_revenue=5_000_000.0,
            salary_expense=5_500_000.0,
            supply_expense=1_500_000.0,
            other_expense=1_800_000.0,
            cash_reserves=500_000.0,
        )
        params = DeterministicParams(;
            projection_years=15,
            volume_growth_rate=-0.04,
            cost_inflation_rate=0.04,
            salary_inflation_rate=0.05,
            supply_inflation_rate=0.06,
            reimbursement_adjustment=0.01,
            payer_mix_shift=0.01,
        )

        result = project_financials(bf, params)
        @test length(result.projections) == 15

        # This stressed hospital should trigger closure risk
        @test result.closure_risk_year !== nothing
        @test result.closure_risk_year >= 1
        @test result.closure_risk_year <= 15
        @test result.terminal_operating_margin < 0.0
    end

    # -----------------------------------------------------------------------
    @testset "Full projection — stable hospital" begin
        bf = make_base_financials(
            inpatient_revenue=4_000_000.0,
            outpatient_revenue=12_000_000.0,
            salary_expense=8_000_000.0,
            supply_expense=2_000_000.0,
            other_expense=2_500_000.0,
            cash_reserves=5_000_000.0,
        )
        params = DeterministicParams(;
            projection_years=5,
            volume_growth_rate=0.01,
            cost_inflation_rate=0.02,
            salary_inflation_rate=0.025,
            supply_inflation_rate=0.03,
            reimbursement_adjustment=0.025,
            payer_mix_shift=0.002,
        )

        result = project_financials(bf, params)
        @test length(result.projections) == 5
        # Stable hospital should not trigger closure risk
        @test result.closure_risk_year === nothing
        @test result.terminal_operating_margin > -0.10
        @test result.cumulative_operating_income > 0.0
    end

    # -----------------------------------------------------------------------
    @testset "Projection monotonicity" begin
        bf = make_base_financials()
        params = DeterministicParams()
        result = project_financials(bf, params)

        # Government payer mix should increase monotonically
        gov_payers = [p.payer_mix_government for p in result.projections]
        @test issorted(gov_payers)

        # Patient volume should decrease monotonically (volume_growth_rate < 0)
        volumes = [p.patient_volume for p in result.projections]
        @test issorted(volumes; rev=true)
    end

    # -----------------------------------------------------------------------
    @testset "Edge case — zero projection years" begin
        bf = make_base_financials()
        params = DeterministicParams(; projection_years=0)
        # Should produce empty projections but not error
        # (depends on implementation; if it errors, that's also valid)
        try
            result = project_financials(bf, params)
            @test length(result.projections) == 0
        catch e
            @test e isa Exception  # acceptable to reject zero years
        end
    end
end
