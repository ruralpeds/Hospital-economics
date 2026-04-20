using Test

include(joinpath(@__DIR__, "..", "src", "finance", "telehealth.jl"))

@testset "Telehealth Economics" begin
    @testset "struct construction" begin
        svc = TelehealthService(service_type=:telestroke, annual_volume=200,
                                revenue_per_encounter=150.0, cost_per_encounter=40.0)
        @test svc.service_type == :telestroke
        @test svc.avoided_transfers_per_year == 0  # default
        @test svc.avg_transfer_cost_avoided == 0.0

        inv = TelehealthInvestment()
        @test inv.infrastructure_cost == 50_000.0
        @test inv.annual_licensing == 24_000.0
        @test inv.annual_staffing == 80_000.0
        @test inv.broadband_upgrade == 0.0
        @test inv.training_cost == 5_000.0

        svc2 = TelehealthService(service_type=:telepsych, annual_volume=100,
                                 revenue_per_encounter=120.0, cost_per_encounter=30.0,
                                 avoided_transfers_per_year=10, avg_transfer_cost_avoided=5000.0)
        @test svc2.avoided_transfers_per_year == 10
    end

    @testset "calculate_telehealth_roi — positive ROI" begin
        svcs = [
            TelehealthService(service_type=:telestroke, annual_volume=500,
                              revenue_per_encounter=200.0, cost_per_encounter=50.0,
                              avoided_transfers_per_year=20, avg_transfer_cost_avoided=8000.0),
        ]
        inv = TelehealthInvestment(infrastructure_cost=40_000.0, annual_licensing=12_000.0,
                                   annual_staffing=60_000.0, training_cost=3_000.0)
        roi = calculate_telehealth_roi(svcs, inv)

        @test roi.direct_revenue == 500 * 200.0
        @test roi.direct_costs == 500 * 50.0
        @test roi.avoided_transfer_savings == 20 * 8000.0
        @test roi.total_investment == 40_000.0 + 3_000.0 + 12_000.0 + 60_000.0
        @test roi.roi_pct > 0.0
        @test roi.breakeven_months !== nothing
        @test roi.breakeven_months > 0
    end

    @testset "calculate_telehealth_roi — negative ROI" begin
        svcs = [TelehealthService(service_type=:telecardio, annual_volume=10,
                                  revenue_per_encounter=50.0, cost_per_encounter=40.0)]
        inv = TelehealthInvestment(infrastructure_cost=200_000.0, annual_staffing=150_000.0)
        roi = calculate_telehealth_roi(svcs, inv)

        @test roi.net_benefit_year1 < 0.0
        # Low volume => breakeven may be nothing
        @test roi.breakeven_months === nothing || roi.breakeven_months > 36
    end

    @testset "telehealth_service_comparison" begin
        svcs = [
            TelehealthService(service_type=:telestroke, annual_volume=100,
                              revenue_per_encounter=200.0, cost_per_encounter=50.0),
            TelehealthService(service_type=:telepsych, annual_volume=300,
                              revenue_per_encounter=120.0, cost_per_encounter=30.0),
        ]
        comp = telehealth_service_comparison(svcs)
        @test length(comp) == 2
        # telepsych: 300*(120-30) = 27000 > telestroke: 100*(200-50) = 15000
        @test comp[1].service_type == :telepsych
        @test comp[2].service_type == :telestroke
        @test comp[1].contribution_margin > comp[2].contribution_margin
    end

    @testset "edge cases" begin
        # Zero projection years
        svcs = [TelehealthService(service_type=:tele, annual_volume=10,
                                  revenue_per_encounter=100.0, cost_per_encounter=50.0)]
        @test_throws ErrorException calculate_telehealth_roi(svcs, TelehealthInvestment(), projection_years=0)

        # Single service, no transfers
        roi = calculate_telehealth_roi(svcs, TelehealthInvestment())
        @test roi.avoided_transfer_savings == 0.0

        # Volume growth: year3 benefit should account for growth
        svcs2 = [TelehealthService(service_type=:a, annual_volume=1000,
                                   revenue_per_encounter=200.0, cost_per_encounter=20.0)]
        inv2 = TelehealthInvestment(infrastructure_cost=10_000.0, annual_licensing=1_000.0,
                                    annual_staffing=5_000.0, training_cost=1_000.0)
        roi2 = calculate_telehealth_roi(svcs2, inv2, projection_years=3)
        @test roi2.net_benefit_year3 > roi2.net_benefit_year1
    end
end
