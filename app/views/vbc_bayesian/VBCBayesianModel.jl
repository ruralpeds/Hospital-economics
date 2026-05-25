"""
    VBCBayesianModel — A-07 VBC Bayesian Scenario Modeling

Stipple reactive model for fitting priors, sampling posteriors, and comparing scenarios.
"""
@app begin
    # ──────── UI state ────────
    @in left_drawer_open::Bool = true

    # ──────── Export ────────
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false

    # ──────── Inputs ────────
    @in scenario_name::String = "Test VBC Scenario"
    @in scenario_type::String = "aco"
    @in shared_savings_rate::Float64 = 0.50
    @in risk_bearing::Float64 = 0.30
    @in historical_savings_json::String = "[]"

    @in compare_mode::Bool = false
    @in scenarios_json::String = "[]"

    # ──────── State ────────
    @in is_loading::Bool = false
    @in is_calculating::Bool = false
    @in error_message::String = ""

    # ──────── Outputs ────────
    @out posterior_mean::Float64 = 0.0
    @out posterior_std::Float64 = 0.0
    @out ci_lower::Float64 = 0.0
    @out ci_upper::Float64 = 0.0
    @out prob_positive::Float64 = 0.0
    @out prior_mean::Float64 = 0.0
    @out prior_std::Float64 = 0.0

    @out prob_positive_badge_color::String = "grey"
    @out prob_positive_badge_text::String = "Calculating..."

    @out prior_vs_posterior_x::Vector{Float64} = []
    @out prior_vs_posterior_prior::Vector{Float64} = []
    @out prior_vs_posterior_posterior::Vector{Float64} = []

    @out comparison_results::Vector{NamedTuple} = []
    @out comparison_chart_names::Vector{String} = []
    @out comparison_chart_savings::Vector{Float64} = []
    @out comparison_chart_ci_lower::Vector{Float64} = []
    @out comparison_chart_ci_upper::Vector{Float64} = []

    # ──────── Handlers ────────
    @onbutton add_historical_datapoint_btn begin
        try
            new_value = Float64(get_input("new_historical_value", 100_000.0))
            existing = isempty(historical_savings_json) ? [] : JSON.parse(historical_savings_json)
            push!(existing, new_value)
            historical_savings_json = JSON.json(existing)
            error_message = ""
        catch e
            error_message = "Error adding data point: $(sprint(showerror, e))"
        end
    end

    @onbutton sample_posterior_btn begin
        is_calculating = true
        error_message = ""

        try
            hist_data = isempty(historical_savings_json) ? [100_000.0] : JSON.parse(historical_savings_json)
            hist_data = Float64.(hist_data)

            # Build scenario
            scenario = Dict(
                "name" => scenario_name,
                "scenario_type" => scenario_type,
                "shared_savings_rate" => shared_savings_rate,
                "risk_bearing" => risk_bearing
            )

            # Call API
            payload = Dict(
                "scenario" => scenario,
                "historical_savings" => hist_data
            )

            result = request(:post, "/api/analytics/vbc-bayesian", payload)
            if haskey(result, "error")
                error_message = get(result, "error", "Unknown error")
            else
                posterior_mean = Float64(get(result, "posterior_mean_savings", 0.0))
                posterior_std = Float64(get(result, "posterior_std", 0.0))
                ci_lower = Float64(get(result, "ci_lower", 0.0))
                ci_upper = Float64(get(result, "ci_upper", 0.0))
                prob_positive = Float64(get(result, "prob_positive", 0.0))
                prior_mean = Float64(get(result, "prior_mean", 0.0))
                prior_std = Float64(get(result, "prior_std", 0.0))

                # Badge color based on prob_positive
                if prob_positive > 0.7
                    prob_positive_badge_color = "green"
                    prob_positive_badge_text = "High confidence"
                elseif prob_positive > 0.4
                    prob_positive_badge_color = "yellow"
                    prob_positive_badge_text = "Moderate confidence"
                else
                    prob_positive_badge_color = "red"
                    prob_positive_badge_text = "Low confidence"
                end

                # Populate prior vs posterior visualization
                x_min = min(prior_mean - 3 * prior_std, posterior_mean - 3 * posterior_std)
                x_max = max(prior_mean + 3 * prior_std, posterior_mean + 3 * posterior_std)
                x_range = range(x_min, x_max, length=100)

                prior_density = [pdf(Normal(prior_mean, prior_std), x) for x in x_range]
                posterior_density = [pdf(Normal(posterior_mean, posterior_std), x) for x in x_range]

                prior_vs_posterior_x = collect(x_range)
                prior_vs_posterior_prior = prior_density
                prior_vs_posterior_posterior = posterior_density
            end
        catch e
            error_message = "Error sampling posterior: $(sprint(showerror, e))"
        finally
            is_calculating = false
        end
    end

    @onbutton compare_scenarios_btn begin
        is_calculating = true
        error_message = ""

        try
            scenarios_data = JSON.parse(scenarios_json)
            if isempty(scenarios_data)
                error_message = "No scenarios to compare"
                return
            end

            # Call API
            payload = Dict(
                "scenarios" => scenarios_data
            )

            result = request(:post, "/api/analytics/vbc-compare-scenarios", payload)
            if haskey(result, "error")
                error_message = get(result, "error", "Unknown error")
            else
                comparison_results = [
                    NamedTuple(Dict(
                        :scenario_name => r["scenario_name"],
                        :posterior_mean => Float64(r["posterior_mean_savings"]),
                        :posterior_std => Float64(r["posterior_std"]),
                        :prob_positive => Float64(r["prob_positive"]),
                        :rank => r["rank"]
                    ))
                    for r in get(result, "ranked_scenarios", [])
                ]

                comparison_chart_names = [r["scenario_name"] for r in get(result, "ranked_scenarios", [])]
                comparison_chart_savings = [Float64(r["posterior_mean_savings"]) for r in get(result, "ranked_scenarios", [])]
                comparison_chart_ci_lower = [Float64(r["ci_lower"]) for r in get(result, "ranked_scenarios", [])]
                comparison_chart_ci_upper = [Float64(r["ci_upper"]) for r in get(result, "ranked_scenarios", [])]
            end
        catch e
            error_message = "Error comparing scenarios: $(sprint(showerror, e))"
        finally
            is_calculating = false
        end
    end

    @onbutton clear_data_btn begin
        historical_savings_json = "[]"
        posterior_mean = 0.0
        posterior_std = 0.0
        ci_lower = 0.0
        ci_upper = 0.0
        prob_positive = 0.0
        error_message = ""
    end
end
