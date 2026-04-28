using Test
using FinanceEngine

@testset "A-12: RHC Service Line Optimization & Profitability" begin
    # ─────────────────────────────────────────────────────────────────────
    # Test 1: Create RHCServiceLine struct
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        service = RHCServiceLine(
            "Initial Visit", "99201", 1.50, 33.45, 45.50, 8.50, 150, 5000.0, 0.5
        )
        service.visit_type == "Initial Visit" &&
        service.monthly_volume == 150 &&
        service.avg_rvu == 1.50
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 2: Calculate service line metrics with positive margin
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        service = RHCServiceLine(
            "Initial Visit", "99201", 1.50, 33.45, 45.50, 8.50, 150, 5000.0, 0.5
        )
        metrics = calculate_rhc_service_metrics(service)
        metrics isa RHCServiceMetrics &&
        metrics.annual_visits > 0 &&
        metrics.annual_revenue > 0 &&
        metrics.contribution_margin_pct > 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 3: Break-even visit calculation
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        service = RHCServiceLine(
            "Visit", "99201", 1.50, 33.45, 50.0, 10.0, 100, 4000.0, 0.5
        )
        metrics = calculate_rhc_service_metrics(service)
        # Contribution margin = 50 - 10 = 40/visit
        # Monthly breakeven = 4000 / 40 = 100 visits
        metrics.breakeven_visits == 1200  # 100 * 12 months
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 4: ROI calculation
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        service = RHCServiceLine(
            "Visit", "99201", 1.50, 33.45, 50.0, 10.0, 200, 4000.0, 0.5
        )
        metrics = calculate_rhc_service_metrics(service)
        # Annual profit = (50-10)*200*12 - 4000*12 = 96000 - 48000 = 48000
        # ROI = 48000 / 48000 = 100%
        metrics.roi_pct >= 90.0 && metrics.roi_pct <= 110.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 5: Physician FTE requirement
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        service = RHCServiceLine(
            "Visit", "99201", 1.50, 33.45, 50.0, 10.0, 100, 4000.0, 0.5
        )
        metrics = calculate_rhc_service_metrics(service)
        # 100 visits/month * 12 = 1200 visits/year
        # FTE = (1200 / 1000) * 0.5 = 0.6
        metrics.physician_fte_required ≈ 0.6 atol=0.1
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 6: Portfolio optimization with multiple services
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        services = [
            RHCServiceLine("Initial", "99201", 1.5, 33.45, 50.0, 8.0, 100, 5000.0, 0.5),
            RHCServiceLine("Established", "99211", 0.8, 33.45, 30.0, 6.0, 200, 3000.0, 0.3),
            RHCServiceLine("Complex", "99213", 1.3, 33.45, 45.0, 10.0, 50, 4000.0, 0.4)
        ]
        portfolio = optimize_rhc_portfolio(services)
        portfolio isa RHCPortfolioOptimization &&
        portfolio.total_annual_visits > 0 &&
        portfolio.total_annual_revenue > 0 &&
        portfolio.total_fte_required > 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 7: High-margin vs low-margin service identification
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        services = [
            RHCServiceLine("High Margin", "99201", 1.5, 33.45, 100.0, 10.0, 100, 2000.0, 0.3),
            RHCServiceLine("Low Margin", "99211", 0.8, 33.45, 20.0, 18.0, 200, 3000.0, 0.3)
        ]
        portfolio = optimize_rhc_portfolio(services)
        !isempty(portfolio.high_margin_services) || !isempty(portfolio.low_margin_services)
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 8: Strategic recommendation generation
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        services = [
            RHCServiceLine("Service A", "99201", 1.5, 33.45, 50.0, 8.0, 100, 5000.0, 0.5)
        ]
        portfolio = optimize_rhc_portfolio(services)
        !isempty(portfolio.recommended_action) &&
        isa(portfolio.recommended_action, String)
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 9: Volume scenario comparison
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        services = [
            RHCServiceLine("Visit", "99201", 1.5, 33.45, 50.0, 10.0, 100, 4000.0, 0.5)
        ]
        adjustments = [1.0, 1.5, 2.0]
        df = compare_service_line_scenarios(services, adjustments)
        nrow(df) == 3 &&
        df[1, :volume_multiplier] == 1.0 &&
        df[3, :volume_multiplier] == 2.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 10: Portfolio margin percentage is realistic
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        services = [
            RHCServiceLine("Visit A", "99201", 1.5, 33.45, 50.0, 12.0, 150, 5000.0, 0.5),
            RHCServiceLine("Visit B", "99211", 0.8, 33.45, 32.0, 10.0, 200, 3000.0, 0.3)
        ]
        portfolio = optimize_rhc_portfolio(services)
        portfolio.portfolio_margin_pct >= 0.0 &&
        portfolio.portfolio_margin_pct <= 100.0
    end
end
