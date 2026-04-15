using Test

include(joinpath(@__DIR__, "..", "src", "finance", "team_bundled.jl"))

@testset "TEAM Bundled Payments" begin
    @testset "struct construction" begin
        ep = TEAMEpisode(episode_type=:lejr, base_drg_payment=15000.0,
                         target_price=20000.0, actual_cost=18000.0)
        @test ep.episode_type == :lejr
        @test ep.quality_score == 0.5  # default

        ep2 = TEAMEpisode(episode_type=:cabg, base_drg_payment=30000.0,
                          target_price=40000.0, actual_cost=35000.0, quality_score=0.9)
        @test ep2.quality_score == 0.9

        params = TEAMParams(episodes=[ep])
        @test params.risk_track == :track2
        @test params.discount_factor == 0.03
        @test params.low_volume_threshold == 31
    end

    @testset "calculate_team_reconciliation — savings" begin
        eps = [TEAMEpisode(episode_type=:lejr, base_drg_payment=15000.0,
                           target_price=20000.0, actual_cost=18000.0, quality_score=0.5)
               for _ in 1:40]
        params = TEAMParams(episodes=eps, risk_track=:track2)
        result = calculate_team_reconciliation(params)

        @test result.episode_count == 40
        @test !result.is_low_volume_exempt
        @test result.total_target_price == 40 * 20000.0
        @test result.total_actual_cost == 40 * 18000.0
        @test result.raw_reconciliation == 40 * 2000.0  # 80_000
        # quality_score == 0.5 => quality_mult == 1.0
        @test result.quality_adjusted_reconciliation == result.raw_reconciliation
        # stop-gain cap for track2: 5% of total_target = 0.05 * 800_000 = 40_000
        @test result.stop_gain_loss_applied == 40_000.0
        @test result.net_payment_adjustment == 40_000.0
    end

    @testset "calculate_team_reconciliation — losses and two-sided" begin
        eps = [TEAMEpisode(episode_type=:hip_fracture, base_drg_payment=12000.0,
                           target_price=15000.0, actual_cost=20000.0, quality_score=0.5)
               for _ in 1:35]
        params = TEAMParams(episodes=eps, risk_track=:track1)
        result = calculate_team_reconciliation(params)

        @test result.raw_reconciliation < 0.0
        # stop-loss cap for track1: 10% of total_target = 0.10 * 525_000 = 52_500
        cap = 0.10 * result.total_target_price
        @test result.stop_gain_loss_applied >= -cap
        @test result.net_payment_adjustment < 0.0
    end

    @testset "quality adjustments" begin
        make_eps(q) = [TEAMEpisode(episode_type=:spinal_fusion, base_drg_payment=20000.0,
                                    target_price=25000.0, actual_cost=23000.0, quality_score=q)
                       for _ in 1:35]
        r_high = calculate_team_reconciliation(TEAMParams(episodes=make_eps(0.9)))
        r_low  = calculate_team_reconciliation(TEAMParams(episodes=make_eps(0.1)))
        # Higher quality should yield higher quality-adjusted reconciliation
        @test r_high.quality_adjusted_reconciliation > r_low.quality_adjusted_reconciliation
    end

    @testset "low volume exemption" begin
        eps = [TEAMEpisode(episode_type=:cabg, base_drg_payment=30000.0,
                           target_price=40000.0, actual_cost=35000.0) for _ in 1:10]
        result = calculate_team_reconciliation(TEAMParams(episodes=eps))
        @test result.is_low_volume_exempt
        @test result.net_payment_adjustment == 0.0
    end

    @testset "team_episode_summary" begin
        eps = [TEAMEpisode(episode_type=:lejr, base_drg_payment=15000.0,
                           target_price=20000.0, actual_cost=18000.0),
               TEAMEpisode(episode_type=:cabg, base_drg_payment=30000.0,
                           target_price=40000.0, actual_cost=45000.0)]
        summary = team_episode_summary(TEAMParams(episodes=eps))
        @test length(summary) == 2
        @test summary[1].margin == 2000.0
        @test summary[2].margin == -5000.0
    end

    @testset "edge cases" begin
        # Empty episodes should error
        @test_throws ErrorException calculate_team_reconciliation(TEAMParams(episodes=TEAMEpisode[]))
        # Invalid risk track
        ep = TEAMEpisode(episode_type=:lejr, base_drg_payment=1.0,
                         target_price=1.0, actual_cost=1.0)
        @test_throws ErrorException calculate_team_reconciliation(
            TEAMParams(episodes=[ep], risk_track=:track3))
        # Zero cost episode (actual_cost == target_price => zero reconciliation)
        eps_zero = [TEAMEpisode(episode_type=:lejr, base_drg_payment=100.0,
                                target_price=100.0, actual_cost=100.0) for _ in 1:35]
        r = calculate_team_reconciliation(TEAMParams(episodes=eps_zero))
        @test r.raw_reconciliation == 0.0
        @test r.net_payment_adjustment == 0.0
    end
end
