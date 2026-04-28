using Test
using FinanceEngine

@testset "A-09: 340B Drug Program Savings Estimator" begin
    # Load fixture
    fixture_path = joinpath(@__DIR__, "..", "..", "..", "test", "fixtures", "drugs", "340b_sample_formulary.csv")

    # ─────────────────────────────────────────────────────────────────────
    # Test 1: Load 340B formulary
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        df = load_340b_formulary(fixture_path)
        !isempty(df) &&
        haskey(df, :ndc) &&
        haskey(df, :avg_wholesale_price) &&
        nrow(df) >= 50
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 2: Create Drug340B structs
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        df = load_340b_formulary(fixture_path)
        drugs = [
            Drug340B(
                row[:ndc],
                row[:description],
                row[:avg_wholesale_price],
                row[:ceiling_price],
                row[:hospital_acquisition_cost],
                row[:estimated_monthly_usage]
            )
            for row in eachrow(df)
        ]
        !isempty(drugs) &&
        drugs[1].ndc == "00069-1940-10" &&
        drugs[1].avg_wholesale_price > drugs[1].ceiling_price
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 3: Estimate 340B savings with default managed care cap
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        df = load_340b_formulary(fixture_path)
        drugs = [
            Drug340B(row[:ndc], row[:description], row[:avg_wholesale_price],
                    row[:ceiling_price], row[:hospital_acquisition_cost],
                    row[:estimated_monthly_usage])
            for row in eachrow(df)
        ]
        metrics = estimate_340b_savings(drugs)
        metrics isa DrugProgramMetrics &&
        metrics.total_annual_usage_units > 0 &&
        metrics.estimated_annual_savings > 0 &&
        metrics.avg_discount_pct > 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 4: Savings with different managed care cap
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        df = load_340b_formulary(fixture_path)
        drugs = [
            Drug340B(row[:ndc], row[:description], row[:avg_wholesale_price],
                    row[:ceiling_price], row[:hospital_acquisition_cost],
                    row[:estimated_monthly_usage])
            for row in eachrow(df)
        ]
        metrics_15 = estimate_340b_savings(drugs, managed_care_cap=0.15)
        metrics_20 = estimate_340b_savings(drugs, managed_care_cap=0.20)
        metrics_15.estimated_annual_savings >= 0 &&
        metrics_20.estimated_annual_savings >= 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 5: Empty drugs vector returns zero metrics
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        metrics = estimate_340b_savings(Drug340B[])
        metrics.total_annual_usage_units == 0 &&
        metrics.estimated_annual_savings == 0 &&
        metrics.avg_discount_pct == 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 6: Drug mix optimization with budget constraint
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        df = load_340b_formulary(fixture_path)
        drugs = [
            Drug340B(row[:ndc], row[:description], row[:avg_wholesale_price],
                    row[:ceiling_price], row[:hospital_acquisition_cost],
                    row[:estimated_monthly_usage])
            for row in eachrow(df)
        ]
        result = optimize_drug_mix(drugs, 500_000.0)
        result isa DrugOptimizationResult &&
        length(result.optimized_drugs) > 0 &&
        result.total_annual_savings > 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 7: Optimization respects budget constraint
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        df = load_340b_formulary(fixture_path)
        drugs = [
            Drug340B(row[:ndc], row[:description], row[:avg_wholesale_price],
                    row[:ceiling_price], row[:hospital_acquisition_cost],
                    row[:estimated_monthly_usage])
            for row in eachrow(df)
        ]
        budget = 200_000.0
        result = optimize_drug_mix(drugs, budget)
        result.budget_remaining >= 0 &&
        result.budget_remaining <= budget
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 8: Zero budget returns empty optimization
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        df = load_340b_formulary(fixture_path)
        drugs = [
            Drug340B(row[:ndc], row[:description], row[:avg_wholesale_price],
                    row[:ceiling_price], row[:hospital_acquisition_cost],
                    row[:estimated_monthly_usage])
            for row in eachrow(df)
        ]
        result = optimize_drug_mix(drugs, 0.0)
        length(result.optimized_drugs) == 0 &&
        result.budget_remaining == 0.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 9: Ceiling vs AWP ratio is reasonable
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        df = load_340b_formulary(fixture_path)
        drugs = [
            Drug340B(row[:ndc], row[:description], row[:avg_wholesale_price],
                    row[:ceiling_price], row[:hospital_acquisition_cost],
                    row[:estimated_monthly_usage])
            for row in eachrow(df)
        ]
        metrics = estimate_340b_savings(drugs)
        metrics.ceiling_vs_mac_ratio >= 0.6 &&
        metrics.ceiling_vs_mac_ratio <= 1.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 10: Managed care applicability is between 0 and 1
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        df = load_340b_formulary(fixture_path)
        drugs = [
            Drug340B(row[:ndc], row[:description], row[:avg_wholesale_price],
                    row[:ceiling_price], row[:hospital_acquisition_cost],
                    row[:estimated_monthly_usage])
            for row in eachrow(df)
        ]
        metrics = estimate_340b_savings(drugs)
        metrics.managed_care_discount_applicability >= 0.0 &&
        metrics.managed_care_discount_applicability <= 1.0
    end
end
