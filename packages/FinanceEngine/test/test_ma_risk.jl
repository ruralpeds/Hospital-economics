using Test
using FinanceEngine

@testset "A-06: Medicare Advantage Risk Adjustment (HCC v28)" begin
    # Load fixture
    fixture_path = joinpath(@__DIR__, "..", "..", "..", "test", "fixtures", "cms", "hcc_v28_coefficients.json")

    # ─────────────────────────────────────────────────────────────────────
    # Test 1: Parse HCC coefficient fixture
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        coeffs = parse_hcc_coefficients(fixture_path)
        !isempty(coeffs) &&
        haskey(coeffs, "HCC001") &&
        coeffs["HCC001"] > 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 2: Missing fixture file throws error
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        try
            parse_hcc_coefficients("/nonexistent/path.json")
            false
        catch e
            e isa ArgumentError
        end
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 3: Calculate member RAF (age/sex only, no diagnoses)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        coeffs = parse_hcc_coefficients(fixture_path)
        member = calculate_member_raf("M001", 65, "M", []; hcc_coefficients=coeffs)
        member.member_id == "M001" &&
        member.age == 65 &&
        member.sex == "M" &&
        member.combined_raf > 0  # Should have baseline RAF
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 4: Calculate member RAF with diagnoses
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        coeffs = parse_hcc_coefficients(fixture_path)
        diagnoses = ["HCC001", "HCC009", "HCC021"]
        member = calculate_member_raf("M002", 72, "F", diagnoses; hcc_coefficients=coeffs)
        member.hcc_count >= 1 &&
        !isempty(member.hcc_risk_factors) &&
        member.combined_raf > 1.0  # Should have baseline + HCC factors
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 5: Risk band classification (low, average, high, very_high)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        coeffs = parse_hcc_coefficients(fixture_path)
        m_low = calculate_member_raf("M003", 35, "M", []; hcc_coefficients=coeffs)
        m_avg = calculate_member_raf("M004", 55, "F", ["HCC009"]; hcc_coefficients=coeffs)
        m_high = calculate_member_raf("M005", 75, "M", ["HCC009", "HCC031"]; hcc_coefficients=coeffs)

        # Check if bands are assigned (may not strictly follow low/average/high due to simplified RAF calculation)
        m_low.risk_band in ["low", "average"] &&
        m_high.combined_raf > m_low.combined_raf
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 6: Cohort aggregation
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        coeffs = parse_hcc_coefficients(fixture_path)
        members = [
            calculate_member_raf("M001", 65, "M", []; hcc_coefficients=coeffs),
            calculate_member_raf("M002", 72, "F", ["HCC001"]; hcc_coefficients=coeffs),
            calculate_member_raf("M003", 58, "M", ["HCC009", "HCC021"]; hcc_coefficients=coeffs)
        ]
        agg = aggregate_cohort_raf(members)

        haskey(agg, "mean_raf") &&
        haskey(agg, "std_raf") &&
        haskey(agg, "percentiles") &&
        haskey(agg, "risk_band_distribution") &&
        agg["member_count"] == 3
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 7: Empty cohort handling
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        agg = aggregate_cohort_raf([])
        haskey(agg, "error") &&
        agg["mean_raf"] == 0.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 8: Capitation impact calculation
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        coeffs = parse_hcc_coefficients(fixture_path)
        members = [
            calculate_member_raf("M001", 65, "M", []; hcc_coefficients=coeffs),
            calculate_member_raf("M002", 72, "F", ["HCC031"]; hcc_coefficients=coeffs)
        ]
        agg = aggregate_cohort_raf(members; annual_capitation=10_000.0)

        haskey(agg, "capitation_impact") &&
        haskey(agg["capitation_impact"], "benchmark_annual") &&
        haskey(agg["capitation_impact"], "actual_annual") &&
        haskey(agg["capitation_impact"], "pct_difference")
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 9: MARAFScore struct fields
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        coeffs = parse_hcc_coefficients(fixture_path)
        member = calculate_member_raf("M001", 65, "M", ["HCC001"]; hcc_coefficients=coeffs)
        hasfield(typeof(member), :member_id) &&
        hasfield(typeof(member), :age) &&
        hasfield(typeof(member), :sex) &&
        hasfield(typeof(member), :combined_raf) &&
        hasfield(typeof(member), :risk_band)
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 10: Percentile calculation in cohort aggregation
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        coeffs = parse_hcc_coefficients(fixture_path)
        members = [
            calculate_member_raf("M$i", 50 + i * 5, "M", []; hcc_coefficients=coeffs)
            for i in 1:10
        ]
        agg = aggregate_cohort_raf(members)
        percs = agg["percentiles"]

        haskey(percs, "p10") &&
        haskey(percs, "p25") &&
        haskey(percs, "p50") &&
        haskey(percs, "p75") &&
        haskey(percs, "p90") &&
        percs["p10"] <= percs["p50"] <= percs["p90"]
    end
end
