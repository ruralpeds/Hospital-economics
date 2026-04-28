using Test
using FinanceEngine

@testset "A-08: RHC & CAH Reimbursement Comparison" begin
    # Load fixtures
    rhc_fixture = joinpath(@__DIR__, "..", "..", "..", "test", "fixtures", "reimbursement", "rhc_rvu_2024.json")
    cah_fixture = joinpath(@__DIR__, "..", "..", "..", "test", "fixtures", "reimbursement", "cah_ar_2024.json")

    # ─────────────────────────────────────────────────────────────────────
    # Test 1: Load RHC schedule
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        rhc = load_rhc_schedule(rhc_fixture)
        !isempty(rhc) &&
        haskey(rhc, "initial_visit") &&
        rhc["initial_visit"].rvu > 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 2: Load CAH schedule
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        cah = load_cah_schedule(cah_fixture)
        !isempty(cah) &&
        haskey(cah, "MDC01") &&
        cah["MDC01"].ar_payment > 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 3: Project RHC revenue (no mileage adjustment)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        rhc = load_rhc_schedule(rhc_fixture)
        visits = Dict("initial_visit" => 100, "established_visit" => 500)
        revenue = project_rhc_revenue(visits, rhc, 0.0)
        revenue > 0 &&
        revenue ≈ 100 * 25.09 + 500 * 13.04 atol=1.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 4: Project RHC revenue with mileage adjustment
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        rhc = load_rhc_schedule(rhc_fixture)
        visits = Dict("initial_visit" => 100)
        revenue_no_miles = project_rhc_revenue(visits, rhc, 0.0)
        revenue_with_miles = project_rhc_revenue(visits, rhc, 75.0)  # 75 miles > 50
        revenue_with_miles > revenue_no_miles
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 5: Project CAH revenue (AR DRGs)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        cah = load_cah_schedule(cah_fixture)
        ar_vols = Dict("MDC01" => 50, "MDC02" => 30)
        non_ar_vols = Dict("ed_visit" => 1000)
        revenue = project_cah_revenue(ar_vols, non_ar_vols, cah)
        revenue > 0 &&
        revenue >= 50 * 8500.0 + 30 * 12000.0  # AR contribution
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 6: Compare RHC vs CAH revenue
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        rhc = load_rhc_schedule(rhc_fixture)
        cah = load_cah_schedule(cah_fixture)
        visits = Dict("initial_visit" => 100, "established_visit" => 500)
        ar_vols = Dict("MDC01" => 50)
        non_ar_vols = Dict("ed_visit" => 500)

        comp = compare_reimbursement(visits, ar_vols, non_ar_vols, rhc, cah; mileage_miles=0.0)
        comp isa ReimburseComparison &&
        comp.rhc_annual_revenue > 0 &&
        comp.cah_annual_revenue > 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 7: Revenue difference calculation
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        rhc = load_rhc_schedule(rhc_fixture)
        cah = load_cah_schedule(cah_fixture)
        visits = Dict("initial_visit" => 200)
        ar_vols = Dict("MDC01" => 100)
        non_ar_vols = Dict()

        comp = compare_reimbursement(visits, ar_vols, non_ar_vols, rhc, cah)
        comp.revenue_difference == comp.cah_annual_revenue - comp.rhc_annual_revenue
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 8: ROI calculation
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        rhc = load_rhc_schedule(rhc_fixture)
        cah = load_cah_schedule(cah_fixture)
        visits = Dict("initial_visit" => 500)
        ar_vols = Dict("MDC01" => 200)
        non_ar_vols = Dict()

        comp = compare_reimbursement(visits, ar_vols, non_ar_vols, rhc, cah;
                                    conversion_cost_estimate=100_000.0)
        comp.conversion_roi_pct >= 0  # ROI can be negative if CAH worse
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 9: Break-even months calculation
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        rhc = load_rhc_schedule(rhc_fixture)
        cah = load_cah_schedule(cah_fixture)
        visits = Dict("initial_visit" => 1000)  # High volume
        ar_vols = Dict("MDC01" => 300)
        non_ar_vols = Dict()

        comp = compare_reimbursement(visits, ar_vols, non_ar_vols, rhc, cah;
                                    conversion_cost_estimate=50_000.0)
        # If CAH is better, break-even should be reasonable
        comp.break_even_months >= 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 10: ReimburseComparison struct fields
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        rhc = load_rhc_schedule(rhc_fixture)
        cah = load_cah_schedule(cah_fixture)
        comp = compare_reimbursement(
            Dict("initial_visit" => 100),
            Dict("MDC01" => 50),
            Dict(),
            rhc, cah;
            hospital_name="Test Hospital"
        )

        hasfield(typeof(comp), :hospital_name) &&
        hasfield(typeof(comp), :rhc_annual_revenue) &&
        hasfield(typeof(comp), :cah_annual_revenue) &&
        hasfield(typeof(comp), :revenue_difference_pct) &&
        hasfield(typeof(comp), :break_even_months) &&
        comp.hospital_name == "Test Hospital"
    end
end
