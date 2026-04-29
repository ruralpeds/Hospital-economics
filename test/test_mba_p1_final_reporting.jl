"""
    test_mba_p1_final_reporting.jl — Tests for P1 Final Reporting (F-02/F-04/F-05)

Covers:
  F-02  Rating agency memo (generation, structure, all sections, Typst, data dict)
  F-04  Sensitivity tornado (one-way, two-way, break-even, scenario comparison, chart data)
  F-05  Scenario diff (compare, waterfall, scenario set, ranking, Markdown table)
"""

using Test
using Statistics
using Dates

# ═════════════════════════════════════════════════════════════════════════════
# F-02: Rating Agency Memo
# ═════════════════════════════════════════════════════════════════════════════

@testset "F-02 Rating Agency Memo" begin

    function sample_inputs(; kwargs...)
        RatingMemoInputs(
            hospital_name         = "Valley Community Hospital",
            hospital_type         = "Critical Access Hospital",
            state                 = "KS",
            reporting_date        = Date(2026, 4, 15),
            analyst_name          = "Finance Department",
            net_patient_revenue   = 8_500_000.0,
            operating_margin      = -0.018,
            total_margin          = 0.005,
            days_cash_on_hand     = 52.4,
            mads_dscr             = 1.32,
            debt_to_cap           = 0.48,
            current_ratio         = 1.74,
            avg_age_of_plant      = 11.8,
            long_term_debt        = 3_100_000.0,
            max_annual_debt_service = 580_000.0,
            historical_years           = [2022, 2023, 2024, 2025, 2026],
            historical_operating_margins = [-0.008, 0.002, -0.012, -0.015, -0.018],
            historical_dcoh              = [60.2, 62.1, 58.4, 55.1, 52.4],
            historical_mads_dscr         = [1.52, 1.48, 1.42, 1.38, 1.32],
            moody_equivalent      = "Ba1/BB+",
            sp_equivalent         = "BB+",
            rating_outlook        = :stable,
            peer_operating_margin_pct = 32.0,
            peer_dcoh_pct             = 42.0,
            peer_dscr_pct             = 55.0,
            peer_debt_to_cap_pct      = 52.0,
            covenant_compliant    = true,
            kwargs...
        )
    end

    @testset "generate_rating_memo_markdown — produces non-empty string" begin
        memo = generate_rating_memo_markdown(sample_inputs())
        @test !isempty(memo)
        @test length(memo) > 2000   # substantial content
    end

    @testset "generate_rating_memo_markdown — contains hospital name" begin
        memo = generate_rating_memo_markdown(sample_inputs())
        @test contains(memo, "Valley Community Hospital")
    end

    @testset "generate_rating_memo_markdown — contains all major sections" begin
        memo = generate_rating_memo_markdown(sample_inputs())
        for section in ["Rating Summary", "Rating Rationale", "Credit Strengths",
                         "Financial Profile", "Debt Profile", "Outlook",
                         "Covenant"]
            @test contains(memo, section) "Missing section: $section"
        end
    end

    @testset "generate_rating_memo_markdown — contains key metrics" begin
        memo = generate_rating_memo_markdown(sample_inputs())
        @test contains(memo, "Ba1/BB+")   # Moody's rating
        @test contains(memo, "BB+")        # S&P rating
        @test contains(memo, "52")         # DCOH
        @test contains(memo, "1.32")       # MADS DSCR
    end

    @testset "generate_rating_memo_markdown — 5-year trend table present" begin
        memo = generate_rating_memo_markdown(sample_inputs())
        @test contains(memo, "2022")
        @test contains(memo, "2026")
        @test contains(memo, "Five-Year Financial Trend")
    end

    @testset "generate_rating_memo_markdown — custom strengths and challenges" begin
        inp  = sample_inputs(
            credit_strengths   = ["Custom strength: strong board governance"],
            credit_challenges  = ["Custom challenge: union labour contract renewal"],
        )
        memo = generate_rating_memo_markdown(inp)
        @test contains(memo, "Custom strength")
        @test contains(memo, "Custom challenge")
    end

    @testset "generate_rating_memo_markdown — negative outlook reflected" begin
        inp  = sample_inputs(rating_outlook=:negative)
        memo = generate_rating_memo_markdown(inp)
        @test contains(memo, "NEGATIVE")
    end

    @testset "generate_rating_memo_markdown — covenant non-compliance flagged" begin
        inp  = sample_inputs(covenant_compliant=false)
        memo = generate_rating_memo_markdown(inp)
        @test contains(memo, "Non-Compliant") || contains(memo, "Waiver")
    end

    @testset "generate_rating_memo_typst — starts with Typst directive" begin
        typ = generate_rating_memo_typst(sample_inputs())
        @test startswith(strip(typ), "#set document")
    end

    @testset "rating_memo_data — returns dict with key fields" begin
        data = rating_memo_data(sample_inputs())
        @test data isa Dict
        @test haskey(data, "hospital_name")
        @test haskey(data, "moody_equivalent")
        @test haskey(data, "key_ratios")
        @test haskey(data, "peer_percentiles")
        @test data["covenant_compliant"] == true
    end

end  # F-02


# ═════════════════════════════════════════════════════════════════════════════
# F-04: Sensitivity Tornado
# ═════════════════════════════════════════════════════════════════════════════

@testset "F-04 Sensitivity Tornado" begin

    # Simple Gordon-growth DCF for testing
    dcf_model(p) = p.fcf * (1 + p.growth) / max(p.wacc - p.growth, 1e-6)
    baseline = (fcf=500_000.0, wacc=0.07, growth=0.025)
    swings   = (fcf=0.10, wacc=0.20, growth=0.30)

    @testset "one_way_sensitivity — returns TornadoResult" begin
        r = one_way_sensitivity(dcf_model, baseline, swings)
        @test r isa TornadoResult
        @test r.n_parameters == 3
        @test length(r.rows) == 3
    end

    @testset "one_way_sensitivity — sorted by total_range descending" begin
        r = one_way_sensitivity(dcf_model, baseline, swings)
        ranges = [row.total_range for row in r.rows]
        @test ranges == sort(ranges; rev=true)
    end

    @testset "one_way_sensitivity — growth is top driver for DCF" begin
        r = one_way_sensitivity(dcf_model, baseline, swings)
        # Growth rate is most sensitive for Gordon growth model (denominator effect)
        @test r.top_driver == :growth
    end

    @testset "one_way_sensitivity — baseline output correct" begin
        r = one_way_sensitivity(dcf_model, baseline, swings)
        expected = dcf_model(baseline)
        @test r.output_baseline ≈ expected atol=1.0
    end

    @testset "one_way_sensitivity — output_low/high bracket baseline" begin
        r = one_way_sensitivity(dcf_model, baseline, swings)
        for row in r.rows
            @test row.output_low != row.output_high   # sensitivity exists
        end
    end

    @testset "one_way_sensitivity — invalid parameter raises error" begin
        @test_throws ArgumentError one_way_sensitivity(
            dcf_model, baseline, (nonexistent_param=0.10,))
    end

    @testset "two_way_sensitivity — correct dimensions" begin
        r = two_way_sensitivity(dcf_model, baseline,
            :wacc,   [0.055, 0.065, 0.075, 0.085, 0.095],
            :growth, [0.015, 0.020, 0.025, 0.030])
        @test size(r.table) == (4, 5)   # y × x
        @test r.x_name == :wacc
        @test r.y_name == :growth
    end

    @testset "two_way_sensitivity — monotone in WACC" begin
        r = two_way_sensitivity(dcf_model, baseline,
            :wacc,   [0.055, 0.065, 0.075, 0.085],
            :growth, [0.025])
        # Higher WACC → lower EV (Gordon growth)
        @test r.table[1,1] > r.table[1,end]
    end

    @testset "break_even_analysis — finds target within range" begin
        # At what FCF level does EV = 6,000,000?
        r = break_even_analysis(dcf_model, baseline, :fcf, 6_000_000.0;
                                 search_range_pct=0.50)
        @test !isnothing(r.break_even_value)
        @test abs(dcf_model(NamedTuple{keys(baseline)}(
            k == :fcf ? r.break_even_value : baseline[k] for k in keys(baseline)
        )) - 6_000_000.0) < 100.0
    end

    @testset "break_even_analysis — returns nothing when out of range" begin
        # Target EV = 100 billion — not achievable with ±50% FCF swing
        r = break_even_analysis(dcf_model, baseline, :fcf, 1e11;
                                 search_range_pct=0.50)
        @test isnothing(r.break_even_value)
    end

    @testset "scenario_sensitivity — sorted by output descending" begin
        scenarios = [
            (name="Base",      wacc=0.070, growth=0.025),
            (name="Adverse",   wacc=0.085, growth=0.015),
            (name="Optimistic",wacc=0.060, growth=0.030),
        ]
        r = scenario_sensitivity(dcf_model, baseline, scenarios)
        @test length(r) == 3
        outputs = [row.output for row in r]
        @test outputs == sort(outputs; rev=true)
    end

    @testset "scenario_sensitivity — adverse is lower than optimistic" begin
        scenarios = [
            (name="Adverse",    wacc=0.085, growth=0.015),
            (name="Optimistic", wacc=0.060, growth=0.030),
        ]
        r = scenario_sensitivity(dcf_model, baseline, scenarios)
        adv = first(filter(x -> x.name == "Adverse", r))
        opt = first(filter(x -> x.name == "Optimistic", r))
        @test opt.output > adv.output
    end

    @testset "tornado_chart_data — correct structure" begin
        r   = one_way_sensitivity(dcf_model, baseline, swings)
        cd  = tornado_chart_data(r)
        @test length(cd.labels) == 3
        @test length(cd.low_deltas) == 3
        @test length(cd.high_deltas) == 3
        @test cd.top_driver == "growth"
    end

end  # F-04


# ═════════════════════════════════════════════════════════════════════════════
# F-05: Scenario Diff / Compare
# ═════════════════════════════════════════════════════════════════════════════

@testset "F-05 Scenario Diff" begin

    function make_baseline()
        ScenarioSnapshot(
            id=1, name="FY2026 Budget",
            metrics=Dict(
                "operating_margin"   => 0.028,
                "days_cash_on_hand"  => 52.4,
                "mads_dscr"          => 1.32,
                "net_patient_revenue" => 8_500_000.0,
                "debt_to_cap"        => 0.48,
            ),
        )
    end

    function make_adverse()
        ScenarioSnapshot(
            id=2, name="CCAR Adverse",
            metrics=Dict(
                "operating_margin"   => -0.012,
                "days_cash_on_hand"  => 38.0,
                "mads_dscr"          => 0.98,
                "net_patient_revenue" => 7_900_000.0,
                "debt_to_cap"        => 0.52,
            ),
        )
    end

    function make_optimistic()
        ScenarioSnapshot(
            id=3, name="Growth Scenario",
            metrics=Dict(
                "operating_margin"   => 0.055,
                "days_cash_on_hand"  => 68.0,
                "mads_dscr"          => 1.65,
                "net_patient_revenue" => 9_200_000.0,
                "debt_to_cap"        => 0.42,
            ),
        )
    end

    @testset "compare_scenarios — basic run" begin
        diff = compare_scenarios(make_baseline(), [make_adverse()])
        @test diff isa ScenarioDiff
        @test diff.n_metrics == 5
        @test length(diff.rows) == 5
    end

    @testset "compare_scenarios — delta computed correctly" begin
        diff = compare_scenarios(make_baseline(), [make_adverse()])
        om_row = first(filter(r -> r.metric == "operating_margin", diff.rows))
        expected_delta = -0.012 - 0.028
        @test om_row.deltas["CCAR Adverse"] ≈ expected_delta atol=1e-6
    end

    @testset "compare_scenarios — delta_pct correct" begin
        diff = compare_scenarios(make_baseline(), [make_adverse()])
        rev_row = first(filter(r -> r.metric == "net_patient_revenue", diff.rows))
        expected_pct = (7_900_000.0 - 8_500_000.0) / 8_500_000.0 * 100
        @test rev_row.delta_pcts["CCAR Adverse"] ≈ expected_pct atol=0.01
    end

    @testset "compare_scenarios — direction from STANDARD_METRIC_DIRECTIONS" begin
        diff = compare_scenarios(make_baseline(), [make_adverse()])
        om_row = first(filter(r -> r.metric == "operating_margin", diff.rows))
        @test om_row.direction == :higher_is_better
        dtc_row = first(filter(r -> r.metric == "debt_to_cap", diff.rows))
        @test dtc_row.direction == :lower_is_better
    end

    @testset "compare_scenarios — worst/best scenario identified" begin
        diff = compare_scenarios(make_baseline(), [make_adverse(), make_optimistic()])
        om_row = first(filter(r -> r.metric == "operating_margin", diff.rows))
        @test om_row.worst_scenario == "CCAR Adverse"
        @test om_row.best_scenario  == "Growth Scenario"
    end

    @testset "compare_scenarios — include_metrics filter works" begin
        diff = compare_scenarios(make_baseline(), [make_adverse()];
                                  include_metrics=["operating_margin", "mads_dscr"])
        @test diff.n_metrics == 2
        @test all(r.metric in ["operating_margin", "mads_dscr"] for r in diff.rows)
    end

    @testset "build_waterfall — step count correct" begin
        steps = build_waterfall(
            "FY2025 Revenue", 8_500_000.0,
            [(label="Volume", value=210_000.0),
             (label="Rate",   value=185_000.0),
             (label="MA",     value=-145_000.0)],
            "FY2026 Revenue"
        )
        @test length(steps) == 5   # start + 3 contributions + total
        @test steps[1].category == :start
        @test steps[end].category == :total
    end

    @testset "build_waterfall — running total correct" begin
        steps = build_waterfall(
            "Start", 1000.0,
            [(label="A", value=200.0), (label="B", value=-100.0)],
            "End"
        )
        @test steps[end].running_total ≈ 1000.0 + 200.0 - 100.0
    end

    @testset "build_waterfall — categories correct" begin
        steps = build_waterfall(
            "S", 0.0,
            [(label="up", value=100.0), (label="down", value=-50.0)],
            "E"
        )
        @test steps[2].category == :positive
        @test steps[3].category == :negative
    end

    @testset "ScenarioSet — scenario_set_diff works" begin
        set = ScenarioSet(
            name="FY2026 Scenarios",
            scenarios=[make_baseline(), make_adverse(), make_optimistic()],
            baseline_id=1,
        )
        diff = scenario_set_diff(set)
        @test diff.baseline.name == "FY2026 Budget"
        @test length(diff.comparisons) == 2
    end

    @testset "rank_scenarios — sorted correctly" begin
        snaps = [make_baseline(), make_adverse(), make_optimistic()]
        ranked = rank_scenarios(snaps, "operating_margin"; higher_is_better=true)
        @test ranked[1].name == "Growth Scenario"
        @test ranked[end].name == "CCAR Adverse"
        @test [r.rank for r in ranked] == [1, 2, 3]
    end

    @testset "rank_scenarios — delta from baseline computed" begin
        snaps = [make_baseline(), make_adverse(), make_optimistic()]
        ranked = rank_scenarios(snaps, "operating_margin";
                                 include_baseline_id=1)
        base_row = first(filter(r -> r.name == "FY2026 Budget", ranked))
        @test base_row.delta_from_base ≈ 0.0 atol=1e-9
    end

    @testset "scenario_diff_table — produces non-empty Markdown table" begin
        diff = compare_scenarios(make_baseline(), [make_adverse()])
        tbl  = scenario_diff_table(diff)
        @test contains(tbl, "|")
        @test contains(tbl, "operating_margin")
        @test contains(tbl, "CCAR Adverse")
    end

    @testset "STANDARD_METRIC_DIRECTIONS — expected metrics present" begin
        for m in ["operating_margin", "days_cash_on_hand", "mads_dscr",
                   "debt_to_cap", "denial_rate", "readmission_rate"]
            @test haskey(STANDARD_METRIC_DIRECTIONS, m) "Missing: $m"
        end
        @test STANDARD_METRIC_DIRECTIONS["operating_margin"] == :higher_is_better
        @test STANDARD_METRIC_DIRECTIONS["debt_to_cap"] == :lower_is_better
    end

end  # F-05

println("\n✅  P1 Final Reporting (F-02 Rating Memo, F-04 Tornado, F-05 Scenario Diff) tests complete.")
