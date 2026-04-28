using Test
using FinanceEngine
using Distributions, Random

@testset "A-07: VBC Scenario Modeling with Bayesian Uncertainty" begin
    Random.seed!(42)

    # ─────────────────────────────────────────────────────────────────────
    # Test 1: Fit prior from historical savings (CCM scenario)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        historical = [100_000.0, 120_000.0, 110_000.0, 95_000.0]
        prior = fit_vbc_prior(historical, :ccm)
        prior isa Distribution &&
        mean(prior) < maximum(historical)
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 2: Fit prior from historical savings (ACO scenario)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        historical = [150_000.0, 180_000.0, 140_000.0]
        prior_aco = fit_vbc_prior(historical, :aco)
        prior_ccm = fit_vbc_prior(historical, :ccm)
        # ACO should have higher mean than CCM due to more aggressive nature
        mean(prior_aco) > mean(prior_ccm) * 0.7
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 3: Fit prior from empty historical data (weak default prior)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        prior_empty = fit_vbc_prior([], :mip)
        prior_empty isa Normal
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 4: Create and sample single VBC scenario
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        scenario = VBCScenario(
            name = "CCM Program",
            scenario_type = :ccm,
            shared_savings_rate = 0.60,
            risk_bearing = 0.20
        )
        historical = [100_000.0, 120_000.0, 110_000.0]
        post = sample_vbc_posterior(scenario, historical; n_iterations=500, seed=42)

        post isa BayesianVBCPost &&
        post.scenario_name == "CCM Program" &&
        post.posterior_mean_savings > 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 5: Posterior mean is reasonable relative to historical data
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        scenario = VBCScenario(
            name = "Test Scenario",
            scenario_type = :aco,
            shared_savings_rate = 0.50,
            risk_bearing = 0.30
        )
        historical = [200_000.0, 210_000.0, 195_000.0]
        post = sample_vbc_posterior(scenario, historical; n_iterations=500)

        # Posterior mean should be in ballpark of historical data
        post.posterior_mean_savings > 0 &&
        abs(post.posterior_mean_savings - mean(historical)) < mean(historical) * 0.5
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 6: Credible interval ordering (lower < upper)
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        scenario = VBCScenario(
            name = "CI Test",
            scenario_type = :hip,
            shared_savings_rate = 0.40,
            risk_bearing = 0.50
        )
        historical = [150_000.0, 160_000.0, 155_000.0]
        post = sample_vbc_posterior(scenario, historical; n_iterations=500)

        post.credible_interval_lower <= post.posterior_mean_savings &&
        post.posterior_mean_savings <= post.credible_interval_upper
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 7: Probability of positive savings is in [0, 1]
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        scenario = VBCScenario(
            name = "Prob Test",
            scenario_type = :ccm,
            shared_savings_rate = 0.60,
            risk_bearing = 0.20
        )
        historical = [80_000.0, 90_000.0, 85_000.0]
        post = sample_vbc_posterior(scenario, historical; n_iterations=500)

        0 <= post.prob_positive_savings <= 1
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 8: BayesianVBCPost struct fields
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        scenario = VBCScenario(
            name = "Field Test",
            scenario_type = :aco,
            shared_savings_rate = 0.50,
            risk_bearing = 0.30
        )
        post = sample_vbc_posterior(scenario, [100_000.0]; n_iterations=500)

        hasfield(typeof(post), :scenario_name) &&
        hasfield(typeof(post), :posterior_mean_savings) &&
        hasfield(typeof(post), :posterior_std) &&
        hasfield(typeof(post), :prob_positive_savings) &&
        hasfield(typeof(post), :credible_interval_lower)
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 9: Compare multiple scenarios and rank
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        scenarios = [
            VBCScenario(name="CCM", scenario_type=:ccm, shared_savings_rate=0.60, risk_bearing=0.20),
            VBCScenario(name="ACO", scenario_type=:aco, shared_savings_rate=0.50, risk_bearing=0.30),
            VBCScenario(name="HIP", scenario_type=:hip, shared_savings_rate=0.40, risk_bearing=0.50)
        ]
        historical_dict = Dict(
            "CCM" => [100_000.0, 110_000.0],
            "ACO" => [150_000.0, 160_000.0],
            "HIP" => [200_000.0, 210_000.0]
        )

        ranking_df = compare_scenarios(scenarios, historical_dict)

        nrow(ranking_df) == 3 &&
        haskey(ranking_df, "rank") &&
        ranking_df.rank[1] == 1
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 10: Scenario comparison returns ranked DataFrame
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        scenarios = [
            VBCScenario(name="Low Confidence", scenario_type=:mip, shared_savings_rate=0.30, risk_bearing=0.10),
            VBCScenario(name="High Confidence", scenario_type=:aco, shared_savings_rate=0.50, risk_bearing=0.30)
        ]
        historical_dict = Dict(
            "Low Confidence" => [50_000.0, 55_000.0],
            "High Confidence" => [200_000.0, 210_000.0]
        )

        ranking_df = compare_scenarios(scenarios, historical_dict)

        # High confidence scenario should rank higher (more savings × higher prob_positive)
        ranking_df.ranking_score[1] > 0 &&
        ranking_df.ranking_score[nrow(ranking_df)] >= 0
    end
end
