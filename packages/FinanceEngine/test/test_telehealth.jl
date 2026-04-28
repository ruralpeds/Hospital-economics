using Test
using FinanceEngine

@testset "A-10: Telehealth & Remote Patient Monitoring Financial Valuation" begin
    # ─────────────────────────────────────────────────────────────────────
    # Test 1: Create TelehealthService struct
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        service = TelehealthService(
            "99456",
            "Established patient telehealth",
            :telehealth,
            45.50,
            Dict("medicare" => 35.0, "commercial" => 65.0),
            150,
            8.50,
            12000.0
        )
        service.service_code == "99456" &&
        service.avg_reimbursement == 45.50 &&
        service.estimated_monthly_volume == 150
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 2: Calculate telehealth metrics with positive ROI
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        service = TelehealthService(
            "99456", "Telehealth visit", :telehealth,
            45.50, Dict("commercial" => 100.0), 150, 8.50, 12000.0
        )
        metrics = calculate_telehealth_metrics(service, 100)
        metrics isa TelehealthMetrics &&
        metrics.annual_visits > 0 &&
        metrics.annual_revenue > 0 &&
        metrics.gross_margin_pct > 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 3: Volume adjustment scaling
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        service = TelehealthService(
            "99456", "Telehealth", :telehealth,
            45.50, Dict("commercial" => 100.0), 150, 8.50, 12000.0
        )
        metrics_1x = calculate_telehealth_metrics(service, 100)
        metrics_2x = calculate_telehealth_metrics(service, 100, volume_adjustment=2.0)
        metrics_2x.annual_visits ≈ 2 * metrics_1x.annual_visits atol=10
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 4: Break-even volume calculation
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        service = TelehealthService(
            "99456", "Telehealth", :telehealth,
            50.0, Dict("commercial" => 100.0), 100, 10.0, 12000.0
        )
        metrics = calculate_telehealth_metrics(service, 100)
        # Break-even should be reasonable (contribution margin = 50-10 = 40/visit)
        metrics.break_even_volume > 0 &&
        metrics.break_even_volume <= 500
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 5: Payback period calculation
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        service = TelehealthService(
            "99456", "Telehealth", :telehealth,
            50.0, Dict("commercial" => 100.0), 200, 10.0, 12000.0
        )
        metrics = calculate_telehealth_metrics(service, 200)
        # High-volume telehealth should have reasonable payback (months > 0)
        metrics.payback_months >= 0 &&
        metrics.payback_months < 999.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 6: RPM financial impact with readmission reduction
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        impact = calculate_rpm_financial_impact(
            200, 45.0, 55.0,
            readmission_reduction_pct=0.15,
            avg_readmission_cost=15_000.0
        )
        impact isa RPMFinancialImpact &&
        impact.enrolled_patients == 200 &&
        impact.monthly_net_benefit > 0 &&
        impact.cost_avoidance_from_readmissions > 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 7: RPM total annual value includes direct + avoidance
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        impact = calculate_rpm_financial_impact(
            200, 45.0, 55.0,
            readmission_reduction_pct=0.15
        )
        expected_direct = (55.0 - 45.0) * 200 * 12
        expected_total = expected_direct + impact.cost_avoidance_from_readmissions
        impact.annual_net_benefit ≈ expected_direct atol=100 &&
        impact.total_annual_value ≈ expected_total atol=1000
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 8: Patient lifetime value (3-year window)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        impact = calculate_rpm_financial_impact(100, 40.0, 50.0)
        expected_ltv = (50.0 - 40.0) * 100 * 36
        impact.patient_lifetime_value ≈ expected_ltv atol=100
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 9: Zero or negative readmission reduction
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        impact_zero = calculate_rpm_financial_impact(100, 40.0, 50.0, readmission_reduction_pct=0.0)
        impact_zero.cost_avoidance_from_readmissions == 0.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 10: Payer mix weighted reimbursement
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        service = TelehealthService(
            "99456", "Mixed payer", :telehealth,
            50.0,
            Dict("medicare" => 35.0, "medicaid" => 20.0, "commercial" => 45.0),
            100, 10.0, 12000.0
        )
        metrics = calculate_telehealth_metrics(service, 50)
        # Revenue should reflect payer mix (weighted blend)
        metrics.annual_revenue > 0 &&
        metrics.annual_revenue <= 100 * 12 * 50.0  # Max at full reimbursement
    end
end
