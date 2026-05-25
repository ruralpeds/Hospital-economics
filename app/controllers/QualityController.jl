"""
QualityController — API handlers for quality & clinical outcomes endpoints (E10).

Routes:
  POST /api/quality/readmission
  POST /api/quality/mortality
  POST /api/quality/infection
  POST /api/quality/psi
  POST /api/quality/qol
  POST /api/quality/disparities
"""
module QualityController

using JSON3, Dates, DataFrames, Statistics, Random

using Biostatistics:
    control_chart_p,
    control_chart_c,
    control_chart_u,
    cusum_chart,
    ewma_chart,
    funnel_plot_data,
    standardize_outcome_rates,
    compute_quality_indicators,
    validate_data,
    detect_missing,
    detect_outliers,
    run_test,
    summarize_numeric,
    QualityResult,
    ValidationReport

include("../components/common.jl")

function handle_readmission(payload::Dict)::Dict
    try
        cohort_id   = html_escape(string(get(payload, "cohort_id",   "")))
        time_period = html_escape(string(get(payload, "time_period", "12months")))
        facility_id = html_escape(string(get(payload, "facility_id", "")))

        events = get(payload, "events", nothing)
        denominators = get(payload, "denominators", nothing)

        if events !== nothing && denominators !== nothing
            events_vec = Float64.(events)
            denom_vec  = Float64.(denominators)

            chart = control_chart_p(events_vec, denom_vec)
            rates = events_vec ./ denom_vec
            overall_rate = sum(events_vec) / sum(denom_vec)

            outcome_rows = [
                Dict(
                    "cohort"     => cohort_id,
                    "period"     => i,
                    "n_patients" => Int(denom_vec[i]),
                    "events"     => Int(events_vec[i]),
                    "rate"       => round(rates[i]; digits=4),
                    "ucl"        => round(chart.estimates.ucl[i]; digits=4),
                    "lcl"        => round(chart.estimates.lcl[i]; digits=4),
                    "center"     => round(chart.estimates.center[i]; digits=4),
                    "in_control" => chart.estimates.lcl[i] <= rates[i] <= chart.estimates.ucl[i],
                )
                for i in eachindex(events_vec)
            ]

            Dict(
                "status"           => "success",
                "cohort_id"        => cohort_id,
                "time_period"      => time_period,
                "readmission_rate" => round(overall_rate; digits=4),
                "n_periods"        => length(events_vec),
                "outcome_rows"     => outcome_rows,
                "computed_at"      => string(now()),
            )
        else
            Dict(
                "status"           => "success",
                "cohort_id"        => cohort_id,
                "time_period"      => time_period,
                "readmission_rate" => 0.0,
                "outcome_rows"     => Dict{String,Any}[],
                "message"          => "No event data provided. Supply 'events' and 'denominators' arrays.",
                "computed_at"      => string(now()),
            )
        end
    catch e
        Dict("status" => "error", "message" => sprint(showerror, e))
    end
end

function handle_mortality(payload::Dict)::Dict
    try
        cohort_id = html_escape(string(get(payload, "cohort_id", "")))

        observed = get(payload, "observed", nothing)
        expected = get(payload, "expected", nothing)

        if observed !== nothing && expected !== nothing
            obs_vec = Float64.(observed)
            exp_vec = Float64.(expected)

            fp = funnel_plot_data(obs_vec, exp_vec)
            smr = sum(obs_vec) / sum(exp_vec)

            km_data = [
                Dict(
                    "facility"  => i,
                    "observed"  => obs_vec[i],
                    "expected"  => exp_vec[i],
                    "oe_ratio"  => round(fp.estimates.oe_ratio[i]; digits=3),
                    "lower_ci"  => round(fp.estimates.lower[i]; digits=3),
                    "upper_ci"  => round(fp.estimates.upper[i]; digits=3),
                    "outlier"   => !(fp.estimates.lower[i] <= fp.estimates.oe_ratio[i] <= fp.estimates.upper[i]),
                )
                for i in eachindex(obs_vec)
            ]

            Dict(
                "status"         => "success",
                "cohort_id"      => cohort_id,
                "mortality_rate" => round(smr; digits=4),
                "smr"            => round(smr; digits=4),
                "km_data"        => km_data,
                "computed_at"    => string(now()),
            )
        else
            Dict(
                "status"         => "success",
                "cohort_id"      => cohort_id,
                "mortality_rate" => 0.0,
                "km_data"        => Dict{String,Any}[],
                "message"        => "No outcome data provided. Supply 'observed' and 'expected' arrays.",
                "computed_at"    => string(now()),
            )
        end
    catch e
        Dict("status" => "error", "message" => sprint(showerror, e))
    end
end

function handle_infection(payload::Dict)::Dict
    try
        infection_type = html_escape(string(get(payload, "infection_type", "clabsi")))

        counts = get(payload, "counts", nothing)
        line_days = get(payload, "line_days", nothing)

        if counts !== nothing && line_days !== nothing
            counts_vec = Float64.(counts)
            days_vec   = Float64.(line_days)

            chart = control_chart_u(counts_vec, days_vec)
            overall_rate = sum(counts_vec) / sum(days_vec) * 1000  # per 1000 line-days

            Dict(
                "status"         => "success",
                "infection_type" => infection_type,
                "infection_rate" => round(overall_rate; digits=4),
                "rate_unit"      => "per_1000_line_days",
                "n_periods"      => length(counts_vec),
                "chart_data"     => Dict(
                    "values" => round.(counts_vec ./ days_vec .* 1000; digits=2),
                    "ucl"    => round.(chart.estimates.ucl; digits=4),
                    "lcl"    => round.(chart.estimates.lcl; digits=4),
                    "center" => round.(chart.estimates.center; digits=4),
                ),
                "computed_at"    => string(now()),
            )
        else
            Dict(
                "status"         => "success",
                "infection_type" => infection_type,
                "infection_rate" => 0.0,
                "message"        => "No infection data provided. Supply 'counts' and 'line_days' arrays.",
                "computed_at"    => string(now()),
            )
        end
    catch e
        Dict("status" => "error", "message" => sprint(showerror, e))
    end
end

function handle_psi(payload::Dict)::Dict
    try
        psi_measure = html_escape(string(get(payload, "psi_measure", "psi_03")))

        events = get(payload, "events", nothing)
        at_risk = get(payload, "at_risk", nothing)
        std_weights = get(payload, "std_weights", nothing)

        if events !== nothing && at_risk !== nothing
            events_vec  = Float64.(events)
            risk_vec    = Float64.(at_risk)

            raw_rate = sum(events_vec) / sum(risk_vec)

            result = if std_weights !== nothing
                weights_vec = Float64.(std_weights)
                standardize_outcome_rates(events_vec, risk_vec, weights_vec; method=:direct)
            else
                nothing
            end

            Dict(
                "status"            => "success",
                "psi_measure"       => psi_measure,
                "complication_rate" => round(raw_rate; digits=6),
                "standardized_rate" => result !== nothing ? round(result.estimates.standardized_rate[1]; digits=6) : nothing,
                "n_strata"          => length(events_vec),
                "computed_at"       => string(now()),
            )
        else
            Dict(
                "status"            => "success",
                "psi_measure"       => psi_measure,
                "complication_rate" => 0.0,
                "message"           => "No PSI data provided. Supply 'events' and 'at_risk' arrays.",
                "computed_at"       => string(now()),
            )
        end
    catch e
        Dict("status" => "error", "message" => sprint(showerror, e))
    end
end

function handle_qol(payload::Dict)::Dict
    try
        qol_scale = html_escape(string(get(payload, "qol_scale", "eq5d")))

        scores = get(payload, "scores", nothing)
        groups = get(payload, "groups", nothing)

        if scores !== nothing
            scores_vec = Float64.(scores)
            stats = summarize_numeric(DataFrame(score = scores_vec), :score)

            result = Dict(
                "status"     => "success",
                "qol_scale"  => qol_scale,
                "qol_score"  => round(stats.mean; digits=3),
                "median"     => round(stats.median; digits=3),
                "std"        => round(stats.std; digits=3),
                "n"          => stats.n,
                "computed_at"=> string(now()),
            )

            if groups !== nothing && length(groups) == length(scores_vec)
                df = DataFrame(score = scores_vec, group = string.(groups))
                group_stats = combine(
                    groupby(df, :group),
                    :score => mean => :mean_score,
                    :score => std => :std_score,
                    :score => length => :n,
                )
                result["group_comparison"] = [
                    Dict("group" => r.group, "mean" => round(r.mean_score; digits=3),
                         "std" => round(r.std_score; digits=3), "n" => r.n)
                    for r in eachrow(group_stats)
                ]

                if length(unique(df.group)) == 2
                    test_result = run_test(:two_sample_t, df, Dict("column" => "score", "group" => "group"))
                    result["test_statistic"] = round(test_result.test_statistic; digits=3)
                    result["p_value"]        = round(test_result.p_value; digits=4)
                    result["effect_size"]    = round(test_result.effect_size; digits=3)
                end
            end

            result
        else
            Dict(
                "status"      => "success",
                "qol_scale"   => qol_scale,
                "qol_score"   => 0.0,
                "message"     => "No QoL scores provided. Supply 'scores' array.",
                "computed_at" => string(now()),
            )
        end
    catch e
        Dict("status" => "error", "message" => sprint(showerror, e))
    end
end

function handle_disparities(payload::Dict)::Dict
    try
        subgroup = html_escape(string(get(payload, "subgroup_variable", "race")))

        outcomes = get(payload, "outcomes", nothing)
        groups   = get(payload, "groups", nothing)

        if outcomes !== nothing && groups !== nothing
            outcomes_vec = Float64.(outcomes)
            groups_vec   = string.(groups)
            df = DataFrame(outcome = outcomes_vec, group = groups_vec)

            group_stats = combine(
                groupby(df, :group),
                :outcome => mean => :mean_rate,
                :outcome => std => :std_rate,
                :outcome => length => :n,
            )

            overall_mean = mean(outcomes_vec)
            disparities_rows = [
                Dict(
                    "group"     => r.group,
                    "mean_rate" => round(r.mean_rate; digits=4),
                    "std_rate"  => round(r.std_rate; digits=4),
                    "n"         => r.n,
                    "diff_from_mean" => round(r.mean_rate - overall_mean; digits=4),
                )
                for r in eachrow(group_stats)
            ]

            result = Dict(
                "status"            => "success",
                "subgroup_variable" => subgroup,
                "overall_rate"      => round(overall_mean; digits=4),
                "n_groups"          => nrow(group_stats),
                "disparities_rows"  => disparities_rows,
                "computed_at"       => string(now()),
            )

            if nrow(group_stats) >= 2
                test_result = if nrow(group_stats) == 2
                    run_test(:two_sample_t, df, Dict("column" => "outcome", "group" => "group"))
                else
                    run_test(:one_way_anova, df, Dict("column" => "outcome", "group" => "group"))
                end
                result["test_type"]      = nrow(group_stats) == 2 ? "two_sample_t" : "one_way_anova"
                result["test_statistic"] = round(test_result.test_statistic; digits=3)
                result["p_value"]        = round(test_result.p_value; digits=4)
                result["effect_size"]    = round(test_result.effect_size; digits=3)
            end

            result
        else
            Dict(
                "status"            => "success",
                "subgroup_variable" => subgroup,
                "disparities_rows"  => Dict{String,Any}[],
                "message"           => "No disparity data provided. Supply 'outcomes' and 'groups' arrays.",
                "computed_at"       => string(now()),
            )
        end
    catch e
        Dict("status" => "error", "message" => sprint(showerror, e))
    end
end

end  # module QualityController
