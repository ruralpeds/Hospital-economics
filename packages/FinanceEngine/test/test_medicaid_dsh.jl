using Test
using FinanceEngine

@testset "A-11: Medicaid Supplemental Payment & DSH Analysis" begin
    # ─────────────────────────────────────────────────────────────────────
    # Test 1: Create HospitalCharacteristics struct
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        hosp = HospitalCharacteristics(
            "Rural Hospital X",
            1000,  # Medicare cases
            1500,  # Medicaid cases
            800,   # Uninsured cases
            0.45,  # 45% low-income
            365.0 * 1500,  # Medicaid bed days
            365.0 * 3300   # Total bed days
        )
        hosp.hospital_name == "Rural Hospital X" &&
        hosp.medicaid_cases == 1500 &&
        hosp.low_income_pct == 0.45
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 2: Calculate Medicaid caseload percentage
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        hosp = HospitalCharacteristics(
            "Test Hospital",
            1000, 1500, 800, 0.45, 547500.0, 1204500.0
        )
        medicaid_pct = calculate_medicaid_caseload_percentage(hosp)
        # 1500 / (1000 + 1500 + 800) = 1500/3300 ≈ 45.45%
        medicaid_pct >= 45.0 && medicaid_pct <= 46.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 3: Calculate low-income percentage
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        hosp = HospitalCharacteristics(
            "Test Hospital",
            1000, 1500, 800, 0.50, 547500.0, 1204500.0
        )
        low_income_pct = calculate_low_income_percentage(hosp)
        # Medicaid (1500) + Low-income uninsured (800 * 0.50 = 400) = 1900
        # 1900 / 3300 ≈ 57.6%
        low_income_pct >= 57.0 && low_income_pct <= 58.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 4: DSH index increases with disproportionality
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        idx_low = calculate_dsh_index(10.0, 15.0)
        idx_high = calculate_dsh_index(25.0, 35.0)
        idx_low < idx_high &&
        idx_low >= 0.0 &&
        idx_high >= 0.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 5: DSH index is bounded [0, 1]
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        idx = calculate_dsh_index(50.0, 60.0)
        idx >= 0.0 && idx <= 1.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 6: Calculate DSH payment
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        hosp = HospitalCharacteristics(
            "DSH Eligible Hospital",
            800, 1200, 600, 0.50, 438000.0, 876000.0
        )
        dsh = calculate_dsh_payment(hosp)
        dsh isa DSHCalculation &&
        dsh.estimated_dsh_payment >= 0 &&
        dsh.dsh_payment_floor >= 0 &&
        dsh.dsh_payment_ceiling >= 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 7: DSH payment respects floor and ceiling
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        hosp = HospitalCharacteristics(
            "Hospital",
            1000, 1500, 800, 0.45, 547500.0, 1204500.0
        )
        dsh = calculate_dsh_payment(hosp)
        dsh.estimated_dsh_payment >= dsh.dsh_payment_floor &&
        dsh.estimated_dsh_payment <= dsh.dsh_payment_ceiling
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 8: Low disproportionality hospital has zero DSH
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        hosp = HospitalCharacteristics(
            "Medicare Heavy Hospital",
            3000, 200, 100, 0.05, 73000.0, 1095000.0
        )
        dsh = calculate_dsh_payment(hosp)
        dsh.estimated_dsh_payment == 0.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 9: Supplemental impacts include DSH and UPL
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        hosp = HospitalCharacteristics(
            "Hospital",
            800, 1200, 600, 0.50, 438000.0, 876000.0
        )
        impact = calculate_supplemental_impacts(hosp, 10_000_000.0, include_dsh=true, include_upl=true)
        impact isa SupplementalPaymentImpact &&
        impact.total_medicaid_revenue >= impact.base_medicaid_payment &&
        haskey(impact.supplemental_programs, "DSH")
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 10: Supplemental as percentage is reasonable
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        hosp = HospitalCharacteristics(
            "Hospital",
            800, 1200, 600, 0.50, 438000.0, 876000.0
        )
        impact = calculate_supplemental_impacts(hosp, 10_000_000.0)
        # Supplementals typically 5-15% of base
        impact.supplemental_as_pct_base >= 0.0 &&
        impact.supplemental_as_pct_base <= 30.0
    end
end
