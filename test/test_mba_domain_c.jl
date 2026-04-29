"""
    test_mba_domain_c.jl — Tests for MBA Domain C Operational Analytics

Covers:
  C-01  DEA (CCR + BCC, efficiency scores, reference sets, scale efficiency)
  C-03  Revenue cycle variance (price/volume/mix bridge, payer decomposition,
        expense variance)
  C-07  Peer benchmarking (Flex Monitoring, AHA Rural, MGMA physician,
        comprehensive, text rendering)
"""

using Test
using Statistics

# ═════════════════════════════════════════════════════════════════════════════
# C-01: Data Envelopment Analysis
# ═════════════════════════════════════════════════════════════════════════════

@testset "C-01 Data Envelopment Analysis" begin

    # Reproduce the classic Charnes-Cooper-Rhodes (1978) 5-DMU example
    # (simplified with 1 input, 2 outputs — efficient frontier is known)
    function make_cah_units()
        [
            DEAUnit("A", Dict(:ftes=>100.0, :beds=>20.0),
                         Dict(:discharges=>500.0, :ed_visits=>3_000.0)),
            DEAUnit("B", Dict(:ftes=>150.0, :beds=>25.0),
                         Dict(:discharges=>800.0, :ed_visits=>4_500.0)),
            DEAUnit("C", Dict(:ftes=>80.0,  :beds=>15.0),
                         Dict(:discharges=>400.0, :ed_visits=>2_800.0)),
            DEAUnit("D", Dict(:ftes=>200.0, :beds=>30.0),
                         Dict(:discharges=>600.0, :ed_visits=>3_200.0)),  # inefficient
            DEAUnit("E", Dict(:ftes=>120.0, :beds=>22.0),
                         Dict(:discharges=>750.0, :ed_visits=>5_000.0)),  # high output
        ]
    end

    @testset "dea_ccr — returns DEAAnalysis" begin
        units = make_cah_units()
        result = dea_ccr(units)
        @test result isa DEAAnalysis
        @test result.model == :ccr
        @test result.orientation == :input
        @test length(result.results) == length(units)
    end

    @testset "dea_ccr — scores in (0,1]" begin
        result = dea_ccr(make_cah_units())
        for r in result.results
            @test 0.0 < r.score <= 1.0 + 1e-6
        end
    end

    @testset "dea_ccr — D is inefficient (high input, low output)" begin
        result = dea_ccr(make_cah_units())
        d = first(filter(r -> r.id == "D", result.results))
        @test d.score < 1.0 - 1e-4    # D should be inefficient
        @test !d.is_efficient
    end

    @testset "dea_ccr — efficient DMU has score ≈ 1.0" begin
        # Build a set where A is clearly efficient (best output/input ratio)
        units = [
            DEAUnit("Eff", Dict(:x=>1.0), Dict(:y=>1.0)),   # on frontier
            DEAUnit("Ineff", Dict(:x=>2.0), Dict(:y=>1.0)),  # uses 2x inputs for same output
        ]
        result = dea_ccr(units)
        eff = first(filter(r -> r.id == "Eff", result.results))
        @test eff.score ≈ 1.0 atol=1e-4
        @test eff.is_efficient
    end

    @testset "dea_ccr — inefficient DMU score < 1" begin
        units = [
            DEAUnit("Eff",   Dict(:x=>1.0), Dict(:y=>1.0)),
            DEAUnit("Ineff", Dict(:x=>2.0), Dict(:y=>1.0)),
        ]
        result = dea_ccr(units)
        ineff = first(filter(r -> r.id == "Ineff", result.results))
        @test ineff.score < 1.0 - 1e-4
        @test !ineff.is_efficient
        @test ineff.score ≈ 0.5 atol=0.02   # 1/2 of efficient unit's score
    end

    @testset "dea_bcc — VRS model runs" begin
        result = dea_bcc(make_cah_units())
        @test result.model == :bcc
        @test length(result.results) == 5
        for r in result.results
            @test 0.0 < r.score <= 1.0 + 1e-6
        end
    end

    @testset "dea_bcc score ≥ dea_ccr score (VRS ≥ CRS)" begin
        # BCC always produces scores ≥ CCR (less restrictive)
        units = make_cah_units()
        ccr = dea_ccr(units)
        bcc = dea_bcc(units)
        for (rc, rb) in zip(ccr.results, bcc.results)
            @test rb.score >= rc.score - 1e-4
        end
    end

    @testset "scale_efficiency" begin
        units = make_cah_units()
        ccr   = dea_ccr(units)
        bcc   = dea_bcc(units)
        for i in eachindex(units)
            se = scale_efficiency(ccr.results[i], bcc.results[i])
            @test 0.0 < se <= 1.0 + 1e-6
        end
    end

    @testset "dea — invalid model" begin
        @test_throws ArgumentError dea(make_cah_units(); model=:drs)
    end

    @testset "dea — too few DMUs" begin
        @test_throws ArgumentError dea([make_cah_units()[1]])
    end

    @testset "dea — mismatched input keys" begin
        units = [
            DEAUnit("A", Dict(:x=>1.0), Dict(:y=>1.0)),
            DEAUnit("B", Dict(:z=>1.0), Dict(:y=>1.0)),  # different key
        ]
        @test_throws ArgumentError dea(units)
    end

    @testset "dea_summary_table — sorted descending" begin
        result = dea_ccr(make_cah_units())
        tbl = dea_summary_table(result)
        scores = [row.score for row in tbl]
        @test scores == sort(scores; rev=true)
        @test all(haskey(row, :id) for row in tbl)
        @test all(haskey(row, :performance_tier) || haskey(row, :is_efficient) for row in tbl)
    end

    @testset "dea — reference set non-empty for inefficient DMU" begin
        units = make_cah_units()
        result = dea_ccr(units)
        ineff = first(filter(r -> !r.is_efficient, result.results))
        @test !isempty(ineff.lambdas)
        @test all(v > 0 for v in values(ineff.lambdas))
    end

    @testset "dea — input targets ≤ actual inputs for CCR" begin
        units = make_cah_units()
        result = dea_ccr(units)
        for (res, unit) in zip(result.results, units)
            for (inp, actual) in unit.inputs
                @test res.input_targets[inp] <= actual + 1e-4
            end
        end
    end

    @testset "dea — summary statistics" begin
        result = dea_ccr(make_cah_units())
        @test 0.0 < result.mean_score <= 1.0
        @test 0.0 < result.median_score <= 1.0
        @test result.n_efficient >= 1
        @test !isempty(result.efficient_ids)
    end

    @testset "dea — returns to scale labels (BCC)" begin
        result = dea_bcc(make_cah_units())
        for r in result.results
            @test r.returns_to_scale in (:irs, :drs, :crs)
        end
    end

end  # C-01


# ═════════════════════════════════════════════════════════════════════════════
# C-03: Revenue Cycle Variance Analysis
# ═════════════════════════════════════════════════════════════════════════════

@testset "C-03 Revenue Variance Analysis" begin

    prior   = RevenuePeriod(label="Q3 FY24", net_patient_revenue=8_500_000.0,
                            total_cases=840, case_mix_index=1.42)
    current = RevenuePeriod(label="Q4 FY24", net_patient_revenue=9_200_000.0,
                            total_cases=890, case_mix_index=1.50)

    @testset "RevenuePeriod computed fields" begin
        @test prior.net_revenue_per_case ≈ 8_500_000.0 / 840 atol=1e-4
        @test prior.rate_per_cmi_unit    ≈ (8_500_000.0 / 840) / 1.42 atol=1e-4
    end

    @testset "revenue_variance_bridge — components sum to ΔRevenue" begin
        bridge = revenue_variance_bridge(prior, current)
        @test bridge.delta_revenue ≈ 9_200_000.0 - 8_500_000.0 atol=1e-4
        # The core mathematical identity
        @test bridge.price_variance + bridge.volume_variance + bridge.mix_variance ≈
              bridge.delta_revenue atol=1.0
        @test bridge.check_sum_error < 1.0   # < $1 rounding error
    end

    @testset "revenue_variance_bridge — sign interpretation" begin
        bridge = revenue_variance_bridge(prior, current)
        # Higher CMI → positive mix variance
        @test bridge.mix_variance > 0
        # Higher volume → positive volume variance
        @test bridge.volume_variance > 0
    end

    @testset "revenue_variance_bridge — pct fields relative to prior" begin
        bridge = revenue_variance_bridge(prior, current)
        @test bridge.price_pct + bridge.volume_pct + bridge.mix_pct ≈
              bridge.delta_revenue / prior.net_patient_revenue * 100 atol=0.01
    end

    @testset "revenue_variance_bridge — no change → all zeros" begin
        same = revenue_variance_bridge(prior, prior)
        @test same.delta_revenue ≈ 0.0 atol=1e-6
        @test same.price_variance  ≈ 0.0 atol=1e-6
        @test same.volume_variance ≈ 0.0 atol=1e-6
        @test same.mix_variance    ≈ 0.0 atol=1e-6
    end

    @testset "revenue_variance_bridge — invalid inputs" begin
        bad = RevenuePeriod(label="X", net_patient_revenue=1_000_000.0, total_cases=0)
        @test_throws ArgumentError revenue_variance_bridge(bad, current)
        @test_throws ArgumentError revenue_variance_bridge(prior, bad)
    end

    @testset "payer_variance_bridge — sums to aggregate total" begin
        prior_p = [
            PayerRevenuePeriod(payer="Medicare",   net_revenue=4_000_000.0, cases=410, case_mix_index=1.85),
            PayerRevenuePeriod(payer="Medicaid",   net_revenue=2_000_000.0, cases=220, case_mix_index=0.95),
            PayerRevenuePeriod(payer="Commercial", net_revenue=2_500_000.0, cases=210, case_mix_index=1.20),
        ]
        current_p = [
            PayerRevenuePeriod(payer="Medicare",   net_revenue=4_400_000.0, cases=425, case_mix_index=1.90),
            PayerRevenuePeriod(payer="Medicaid",   net_revenue=2_100_000.0, cases=230, case_mix_index=0.98),
            PayerRevenuePeriod(payer="Commercial", net_revenue=2_700_000.0, cases=235, case_mix_index=1.25),
        ]
        bridge = payer_variance_bridge(prior_p, current_p)

        @test length(bridge.rows) == 3
        @test bridge.check_sum_error < 1.0
        total_manual = sum(p.net_revenue for p in current_p) -
                       sum(p.net_revenue for p in prior_p)
        @test bridge.total_delta_revenue ≈ total_manual atol=1.0
        @test bridge.total_price_variance + bridge.total_volume_variance +
              bridge.total_mix_variance ≈ bridge.total_delta_revenue atol=1.0
    end

    @testset "payer_variance_bridge — sorted by |delta| desc" begin
        prior_p = [
            PayerRevenuePeriod(payer="Medicare",   net_revenue=4_000_000.0, cases=400),
            PayerRevenuePeriod(payer="Commercial", net_revenue=500_000.0,   cases=50),
        ]
        current_p = [
            PayerRevenuePeriod(payer="Medicare",   net_revenue=4_800_000.0, cases=480),
            PayerRevenuePeriod(payer="Commercial", net_revenue=510_000.0,   cases=51),
        ]
        bridge = payer_variance_bridge(prior_p, current_p)
        deltas = abs.([r.delta_revenue for r in bridge.rows])
        @test deltas == sort(deltas; rev=true)
    end

    @testset "payer_variance_bridge — new payer entry (zero prior)" begin
        prior_p   = [PayerRevenuePeriod(payer="Medicare", net_revenue=5_000_000.0, cases=500)]
        current_p = [
            PayerRevenuePeriod(payer="Medicare",  net_revenue=5_100_000.0, cases=510),
            PayerRevenuePeriod(payer="New Payer", net_revenue=300_000.0,   cases=30),
        ]
        bridge = payer_variance_bridge(prior_p, current_p)
        @test length(bridge.rows) == 2
        new_row = first(filter(r -> r.payer == "New Payer", bridge.rows))
        @test new_row.prior_revenue ≈ 0.0
        @test new_row.delta_revenue ≈ 300_000.0 atol=1.0
    end

    @testset "expense_variance — formulae" begin
        v = expense_variance("Contract Labor", 45.0, 52.0, 8_000.0, 8_500.0)
        @test v.spending_variance   ≈ (52.0 - 45.0) * 8_500.0 atol=1e-4
        @test v.efficiency_variance ≈ (8_500.0 - 8_000.0) * 45.0 atol=1e-4
        @test v.total_variance      ≈ v.spending_variance + v.efficiency_variance atol=1e-4
        @test v.budgeted_total      ≈ 45.0 * 8_000.0 atol=1e-4
        @test v.actual_total        ≈ 52.0 * 8_500.0 atol=1e-4
    end

    @testset "expense_variance — favorable (lower actual cost)" begin
        v = expense_variance("Supplies", 10.0, 9.0, 5_000.0, 5_100.0)
        @test v.spending_variance < 0    # rate dropped = favorable
    end

    @testset "multi_category_variance — sorted by |total| desc" begin
        cats = [
            (category="Salaries",  budgeted_unit_cost=62.0, actual_unit_cost=65.0,
             budgeted_volume=180_000.0, actual_volume=185_000.0),
            (category="Supplies",  budgeted_unit_cost=8.50,  actual_unit_cost=9.20,
             budgeted_volume=95_000.0,  actual_volume=98_000.0),
            (category="Utilities", budgeted_unit_cost=3.20,  actual_unit_cost=3.10,
             budgeted_volume=40_000.0,  actual_volume=39_000.0),
        ]
        bridges = multi_category_variance(cats)
        @test length(bridges) == 3
        totals = abs.([b.total_variance for b in bridges])
        @test totals == sort(totals; rev=true)
    end

end  # C-03


# ═════════════════════════════════════════════════════════════════════════════
# C-07: Peer Benchmarking
# ═════════════════════════════════════════════════════════════════════════════

@testset "C-07 Peer Benchmarking" begin

    @testset "FLEX_MONITORING_2022 — complete" begin
        expected = [:operating_margin, :total_margin, :days_cash_on_hand, :current_ratio,
                    :debt_to_cap, :avg_age_of_plant, :fte_per_aob, :salary_to_revenue,
                    :outpatient_pct, :mcr_cost_to_charge]
        for k in expected
            @test haskey(FLEX_MONITORING_2022, k) "Missing key: $k"
        end
    end

    @testset "AHA_RURAL_2023 — complete" begin
        expected = [:alos_inpatient, :ed_visits_per_bed, :occupancy_rate,
                    :fte_per_adjusted_discharge, :net_revenue_per_adjusted_discharge,
                    :cost_per_adjusted_discharge, :charity_care_pct]
        for k in expected
            @test haskey(AHA_RURAL_2023, k) "Missing key: $k"
        end
    end

    @testset "MGMA_2023 — key specialties" begin
        for sp in [:family_medicine, :emergency_medicine, :hospitalist, :general_surgery]
            @test haskey(MGMA_2023, sp) "Missing specialty: $sp"
        end
    end

    @testset "benchmark_flex_monitoring — strong performer" begin
        # Hospital well above medians on all metrics
        metrics = Dict(
            :operating_margin   => 0.065,  # above P75 (0.048)
            :total_margin       => 0.080,  # above P75 (0.066)
            :days_cash_on_hand  => 150.0,  # above P75 (112.8)
            :current_ratio      => 3.50,   # above P75 (3.05)
        )
        report = benchmark_flex_monitoring("Strong CAH", metrics)
        @test report.overall_percentile > 60.0
        @test !isempty(report.strengths)
        @test isempty(report.watches)
    end

    @testset "benchmark_flex_monitoring — weak performer" begin
        metrics = Dict(
            :operating_margin   => -0.05,  # below P25 (-0.032)
            :days_cash_on_hand  => 20.0,   # below P25 (32.5)
            :current_ratio      => 1.0,    # below P25 (1.41)
            :debt_to_cap        => 0.65,   # above P75 ceiling
        )
        report = benchmark_flex_monitoring("Struggling CAH", metrics)
        @test !isempty(report.watches)
    end

    @testset "benchmark_flex_monitoring — unknown metrics ignored" begin
        metrics = Dict(
            :operating_margin => 0.03,
            :not_a_real_metric => 99.0,
        )
        report = benchmark_flex_monitoring("Test", metrics)
        @test length(report.comparisons) == 1  # only known metric
    end

    @testset "benchmark_flex_monitoring — percentile in [1,99]" begin
        metrics = Dict(
            :operating_margin   => 0.02,
            :total_margin       => 0.04,
            :days_cash_on_hand  => 70.0,
        )
        report = benchmark_flex_monitoring("Test", metrics)
        for c in report.comparisons
            @test 1.0 <= c.percentile <= 99.0
        end
    end

    @testset "BenchmarkComparison — performance tiers" begin
        metrics = Dict(
            :operating_margin  => 0.10,  # strong (>>P75)
            :days_cash_on_hand => 50.0,  # borderline
            :debt_to_cap       => 0.70,  # weak (>>P75, but lower-is-better)
        )
        report = benchmark_flex_monitoring("Tier Test", metrics)
        om = first(filter(c -> c.metric == :operating_margin, report.comparisons))
        @test om.performance_tier == :strong
    end

    @testset "benchmark_aha_rural — runs" begin
        metrics = Dict(
            :alos_inpatient          => 4.5,
            :ed_visits_per_bed       => 180.0,
            :occupancy_rate          => 0.40,
            :cost_per_adjusted_discharge => 12_000.0,
        )
        report = benchmark_aha_rural("Rural Test", metrics)
        @test !isempty(report.comparisons)
        @test report.source_counts[:aha_rural] == 4
    end

    @testset "benchmark_mgma_physician — valid specialty" begin
        r = benchmark_mgma_physician("Test Hospital", :family_medicine, 4_800.0, 50.0)
        @test r.specialty == :family_medicine
        @test 1.0 <= r.wrvu_percentile <= 99.0
        @test r.performance_tier in (:strong, :adequate, :watch)
        @test r.wrvu_median > 0
    end

    @testset "benchmark_mgma_physician — high wRVU → high percentile" begin
        # wRVU well above P75 should be ≥ P75th percentile
        bm = MGMA_2023[:emergency_medicine]
        r = benchmark_mgma_physician("Test", :emergency_medicine, bm.wrvu_p75 * 1.3, 50.0)
        @test r.wrvu_percentile > 70.0
    end

    @testset "benchmark_mgma_physician — unknown specialty" begin
        @test_throws ArgumentError benchmark_mgma_physician("X", :astrology, 5000.0, 50.0)
    end

    @testset "comprehensive_benchmark — merges sources" begin
        flex_m = Dict(:operating_margin => 0.03, :days_cash_on_hand => 70.0)
        aha_m  = Dict(:alos_inpatient => 4.0, :occupancy_rate => 0.45)
        report = comprehensive_benchmark("Combined Test", flex_m, aha_m)
        @test length(report.comparisons) == 4
        @test haskey(report.source_counts, :flex_monitoring)
        @test haskey(report.source_counts, :aha_rural)
        @test report.source_counts[:flex_monitoring] == 2
        @test report.source_counts[:aha_rural] == 2
    end

    @testset "benchmark_report_text — renders without error" begin
        metrics = Dict(
            :operating_margin  => 0.025,
            :days_cash_on_hand => 60.0,
            :debt_to_cap       => 0.35,
        )
        report = benchmark_flex_monitoring("Valley CAH", metrics)
        txt = benchmark_report_text(report)
        @test contains(txt, "Valley CAH")
        @test contains(txt, "operating_margin") || contains(txt, "Strengths")
        @test contains(txt, "P")   # percentile labels
    end

    @testset "PeerBenchmarkReport — overall_percentile in [1,99]" begin
        metrics = Dict(k => 0.03 for k in [:operating_margin, :total_margin])
        report  = benchmark_flex_monitoring("Test", metrics)
        @test 1.0 <= report.overall_percentile <= 99.0
    end

    @testset "benchmark_flex_monitoring — empty metrics" begin
        report = benchmark_flex_monitoring("Empty", Dict{Symbol,Float64}())
        @test isempty(report.comparisons)
        @test isnan(report.overall_percentile)
    end

end  # C-07

println("\n✅  MBA Domain C (C-01 DEA, C-03 Variance, C-07 Benchmarking) test suite complete.")
