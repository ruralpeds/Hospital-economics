# ============================================================================
# Tests for SPC control charts (src/spc/control_charts.jl)
# ============================================================================

using Test
using Statistics

include(joinpath(@__DIR__, "..", "src", "spc", "control_charts.jl"))

@testset "SPC Control Charts" begin

    # ─── I-MR Chart ──────────────────────────────────────────────────────

    @testset "IMR chart — in-control" begin
        # Stable process: values near 50 with small variation
        values = [50.0, 51.0, 49.5, 50.5, 49.0, 51.5, 50.0, 49.5, 50.5, 51.0,
                  49.0, 50.5, 50.0, 51.0, 49.5, 50.5, 49.0, 51.0, 50.0, 50.5]
        result = calculate_imr(values)
        @test result !== nothing
        @test result.ucl > result.center_line
        @test result.lcl < result.center_line
        @test result.center_line ≈ mean(values)
        @test length(result.mr_values) == length(values) - 1
        @test result.mr_ucl > result.mr_center
        @test result.mr_lcl == 0.0
        @test isempty(result.signals)
    end

    @testset "IMR chart — out-of-control" begin
        # Spike at index 5 should signal
        values = [50.0, 50.5, 49.5, 50.0, 80.0, 50.0, 49.5, 50.5, 50.0, 49.5]
        result = calculate_imr(values)
        @test result !== nothing
        @test !isempty(result.signals)
        @test 5 in result.signals
    end

    @testset "IMR chart — too few points" begin
        @test calculate_imr(Float64[]) === nothing
        @test calculate_imr([1.0]) === nothing
    end

    @testset "IMR chart — d2 and D4 constants" begin
        # Verify constants match Montgomery Table VI (n=2)
        values = collect(1.0:20.0)
        result = calculate_imr(values)
        mr = [abs(values[i] - values[i-1]) for i in 2:length(values)]
        mr_bar = mean(mr)
        @test result.mr_center ≈ mr_bar
        # d2 = 1.128, sigma = MR_bar / 1.128
        sigma = mr_bar / 1.128
        @test result.ucl ≈ mean(values) + 3.0 * sigma
        @test result.lcl ≈ mean(values) - 3.0 * sigma
        # D4 = 3.267
        @test result.mr_ucl ≈ 3.267 * mr_bar
    end

    # ─── P-Chart ─────────────────────────────────────────────────────────

    @testset "P-chart — in-control" begin
        # 10 subgroups, ~10% defective rate, all in control
        defectives = [10, 12, 9, 11, 10, 13, 8, 11, 10, 12]
        sizes = fill(100, 10)
        result = calculate_p_chart(defectives, sizes)
        @test result !== nothing
        @test result.center_line ≈ sum(defectives) / sum(sizes)
        @test length(result.ucl) == 10
        @test length(result.lcl) == 10
        @test all(result.ucl .> result.center_line)
        @test all(result.lcl .< result.center_line)
        @test isempty(result.signals)
    end

    @testset "P-chart — out-of-control" begin
        defectives = [10, 12, 9, 11, 50, 10, 8, 11, 10, 12]
        sizes = fill(100, 10)
        result = calculate_p_chart(defectives, sizes)
        @test result !== nothing
        @test !isempty(result.signals)
        @test 5 in result.signals
    end

    @testset "P-chart — variable subgroup sizes" begin
        defectives = [5, 8, 3, 6, 7]
        sizes = [50, 100, 30, 80, 90]
        result = calculate_p_chart(defectives, sizes)
        @test result !== nothing
        # Limits should differ between subgroups
        @test result.ucl[1] != result.ucl[2]
    end

    @testset "P-chart — edge cases" begin
        @test calculate_p_chart(Int[], Int[]) === nothing
        @test calculate_p_chart([1, 2], [10]) === nothing  # mismatched lengths
    end

    # ─── U-Chart ─────────────────────────────────────────────────────────

    @testset "U-chart — in-control" begin
        defects = [3, 5, 4, 2, 6, 3, 4, 5, 3, 4]
        units = fill(10, 10)
        result = calculate_u_chart(defects, units)
        @test result !== nothing
        @test result.center_line ≈ sum(defects) / sum(units)
        @test all(result.ucl .> result.center_line)
        @test isempty(result.signals)
    end

    @testset "U-chart — out-of-control" begin
        defects = [3, 5, 4, 2, 30, 3, 4, 5, 3, 4]
        units = fill(10, 10)
        result = calculate_u_chart(defects, units)
        @test result !== nothing
        @test !isempty(result.signals)
        @test 5 in result.signals
    end

    @testset "U-chart — variable subgroup sizes" begin
        defects = [6, 10, 3, 8, 7]
        units = [5, 10, 3, 8, 7]
        result = calculate_u_chart(defects, units)
        @test result !== nothing
        @test result.ucl[1] != result.ucl[2]
    end

    # ─── C-Chart ─────────────────────────────────────────────────────────

    @testset "C-chart — in-control" begin
        defects = [5, 7, 4, 6, 8, 5, 6, 7, 4, 5]
        result = calculate_c_chart(defects)
        @test result !== nothing
        c_bar = mean(Float64.(defects))
        @test result.center_line ≈ c_bar
        @test result.ucl ≈ c_bar + 3.0 * sqrt(c_bar)
        @test result.lcl ≈ max(0.0, c_bar - 3.0 * sqrt(c_bar))
        @test isempty(result.signals)
    end

    @testset "C-chart — out-of-control" begin
        defects = [5, 7, 4, 6, 40, 5, 6, 7, 4, 5]
        result = calculate_c_chart(defects)
        @test result !== nothing
        @test !isempty(result.signals)
        @test 5 in result.signals
    end

    @testset "C-chart — empty input" begin
        @test calculate_c_chart(Int[]) === nothing
    end

    # ─── NP-Chart ────────────────────────────────────────────────────────

    @testset "NP-chart — in-control" begin
        defectives = [8, 10, 7, 9, 11, 8, 10, 7, 9, 8]
        n = 100
        result = calculate_np_chart(defectives, n)
        @test result !== nothing
        np_bar = mean(Float64.(defectives))
        p_bar = np_bar / n
        @test result.center_line ≈ np_bar
        @test result.ucl ≈ np_bar + 3.0 * sqrt(np_bar * (1.0 - p_bar))
        @test result.lcl ≈ max(0.0, np_bar - 3.0 * sqrt(np_bar * (1.0 - p_bar)))
        @test isempty(result.signals)
    end

    @testset "NP-chart — out-of-control" begin
        defectives = [8, 10, 7, 9, 50, 8, 10, 7, 9, 8]
        result = calculate_np_chart(defectives, 100)
        @test result !== nothing
        @test !isempty(result.signals)
        @test 5 in result.signals
    end

    @testset "NP-chart — edge cases" begin
        @test calculate_np_chart(Int[], 100) === nothing
        @test calculate_np_chart([1, 2, 3], 0) === nothing
    end

    # ─── Laney p' Chart ──────────────────────────────────────────────────

    @testset "Laney p-prime — in-control" begin
        defectives = [100, 110, 95, 105, 98, 102, 107, 93, 100, 104]
        sizes = fill(1000, 10)
        result = calculate_laney_p_prime(defectives, sizes)
        @test result !== nothing
        @test result.center_line ≈ sum(defectives) / sum(sizes)
        @test result.sigma_z > 0.0
        @test length(result.ucl) == 10
        @test length(result.lcl) == 10
    end

    @testset "Laney p-prime — overdispersion widens limits" begin
        # With overdispersion (sigma_z > 1), Laney limits should be wider
        # than standard p-chart limits
        defectives = [80, 120, 75, 130, 85, 115, 90, 110, 70, 125]
        sizes = fill(1000, 10)
        laney = calculate_laney_p_prime(defectives, sizes)
        pchart = calculate_p_chart(defectives, sizes)
        @test laney !== nothing
        @test pchart !== nothing
        # If overdispersed (sigma_z > 1), Laney limits wider
        if laney.sigma_z > 1.0
            @test laney.ucl[1] > pchart.ucl[1]
        end
    end

    @testset "Laney p-prime — edge cases" begin
        @test calculate_laney_p_prime(Int[], Int[]) === nothing
        @test calculate_laney_p_prime([1], [10]) === nothing  # need >= 2
    end

    # ─── Laney u' Chart ──────────────────────────────────────────────────

    @testset "Laney u-prime — in-control" begin
        defects = [30, 35, 28, 32, 31, 29, 33, 27, 34, 30]
        units = fill(10, 10)
        result = calculate_laney_u_prime(defects, units)
        @test result !== nothing
        @test result.center_line ≈ sum(defects) / sum(units)
        @test result.sigma_z > 0.0
        @test length(result.ucl) == 10
    end

    @testset "Laney u-prime — overdispersion" begin
        # Wider variation should yield sigma_z > 1
        defects = [10, 50, 8, 55, 12, 48, 15, 52, 9, 45]
        units = fill(10, 10)
        result = calculate_laney_u_prime(defects, units)
        @test result !== nothing
        @test result.sigma_z > 1.0  # overdispersed
    end

    # ─── G-Chart ─────────────────────────────────────────────────────────

    @testset "G-chart — in-control" begin
        counts = [15, 20, 12, 18, 22, 14, 19, 16, 21, 17]
        result = calculate_g_chart(counts)
        @test result !== nothing
        g_bar = mean(Float64.(counts))
        @test result.center_line ≈ g_bar
        @test result.ucl ≈ g_bar + 3.0 * sqrt(g_bar * (g_bar + 1.0))
        @test result.lcl ≈ max(0.0, g_bar - 3.0 * sqrt(g_bar * (g_bar + 1.0)))
        @test isempty(result.signals)
    end

    @testset "G-chart — out-of-control" begin
        counts = [15, 20, 12, 18, 500, 14, 19, 16, 21, 17]
        result = calculate_g_chart(counts)
        @test result !== nothing
        @test !isempty(result.signals)
        @test 5 in result.signals
    end

    @testset "G-chart — empty input" begin
        @test calculate_g_chart(Int[]) === nothing
    end

    # ─── T-Chart ─────────────────────────────────────────────────────────

    @testset "T-chart — in-control" begin
        times = [2.5, 3.1, 2.8, 3.0, 2.7, 3.2, 2.9, 3.1, 2.6, 3.0,
                 2.8, 3.1, 2.9, 2.7, 3.0, 2.8, 3.2, 2.9, 3.1, 2.7]
        result = calculate_t_chart(times)
        @test result !== nothing
        @test result.ucl > result.center_line
        @test result.lcl < result.center_line
        @test result.lcl > 0.0  # back-transformed from log scale
        @test length(result.transformed) == length(times)
        @test isempty(result.signals)
    end

    @testset "T-chart — out-of-control" begin
        times = [3.0, 3.1, 2.9, 3.0, 50.0, 3.0, 2.9, 3.1, 3.0, 2.9]
        result = calculate_t_chart(times)
        @test result !== nothing
        @test !isempty(result.signals)
        @test 5 in result.signals
    end

    @testset "T-chart — too few positive values" begin
        @test calculate_t_chart(Float64[]) === nothing
        @test calculate_t_chart([1.0]) === nothing
        @test calculate_t_chart([-1.0, -2.0]) === nothing  # all non-positive
    end

    @testset "T-chart — log transformation" begin
        times = [1.0, exp(1.0), exp(2.0)]
        result = calculate_t_chart(times)
        @test result !== nothing
        @test result.transformed ≈ [0.0, 1.0, 2.0]
    end

    # ─── CUSUM ───────────────────────────────────────────────────────────

    @testset "CUSUM — in-control" begin
        values = [10.0, 10.2, 9.8, 10.1, 9.9, 10.3, 9.7, 10.0, 10.1, 9.9,
                  10.2, 9.8, 10.0, 10.1, 9.9, 10.2, 9.8, 10.0, 10.1, 9.9]
        result = calculate_cusum(values; target=10.0)
        @test result !== nothing
        @test result.center_line == 10.0
        @test length(result.upper_cusum) == length(values)
        @test length(result.lower_cusum) == length(values)
        @test all(result.upper_cusum .>= 0.0)
        @test all(result.lower_cusum .>= 0.0)
        @test isempty(result.signals)
    end

    @testset "CUSUM — out-of-control (sustained shift)" begin
        # Start in control, then sustained upward shift
        values = [10.0, 10.1, 9.9, 10.0, 10.2,
                  13.0, 13.1, 13.2, 12.9, 13.0,
                  13.1, 13.2, 12.8, 13.0, 13.1]
        result = calculate_cusum(values; target=10.0, k=0.5, h=4.0)
        @test result !== nothing
        @test !isempty(result.signals)
        # Signals should be in the shifted region (indices > 5)
        @test any(s -> s > 5, result.signals)
    end

    @testset "CUSUM — edge cases" begin
        @test calculate_cusum(Float64[]; target=0.0) === nothing
        @test calculate_cusum([1.0]; target=1.0) === nothing
    end

    # ─── EWMA ────────────────────────────────────────────────────────────

    @testset "EWMA — in-control" begin
        values = [10.0, 10.2, 9.8, 10.1, 9.9, 10.3, 9.7, 10.0, 10.1, 9.9,
                  10.2, 9.8, 10.0, 10.1, 9.9, 10.2, 9.8, 10.0, 10.1, 9.9]
        result = calculate_ewma(values; lambda=0.2, L=3.0)
        @test result !== nothing
        @test result.center_line ≈ mean(values)
        @test length(result.ewma) == length(values)
        @test length(result.ucl) == length(values)
        @test length(result.lcl) == length(values)
        # Limits should expand then converge
        @test result.ucl[1] < result.ucl[end]  # early limits are tighter
        @test isempty(result.signals)
    end

    @testset "EWMA — out-of-control" begin
        # Sustained shift should accumulate in EWMA
        values = [10.0, 10.1, 9.9, 10.0, 10.2,
                  15.0, 15.1, 15.2, 14.9, 15.0,
                  15.1, 15.2, 14.8, 15.0, 15.1]
        result = calculate_ewma(values; lambda=0.2, L=3.0)
        @test result !== nothing
        @test !isempty(result.signals)
    end

    @testset "EWMA — lambda sensitivity" begin
        values = [10.0, 10.5, 11.0, 11.5, 12.0, 12.5, 13.0, 13.5, 14.0, 14.5]
        # Higher lambda = more weight on recent data = faster response
        result_fast = calculate_ewma(values; lambda=0.4, L=3.0)
        result_slow = calculate_ewma(values; lambda=0.1, L=3.0)
        @test result_fast !== nothing
        @test result_slow !== nothing
        # Fast EWMA at the end should be closer to the latest value
        @test abs(result_fast.ewma[end] - values[end]) < abs(result_slow.ewma[end] - values[end])
    end

    @testset "EWMA — edge cases" begin
        @test calculate_ewma(Float64[]; lambda=0.2, L=3.0) === nothing
        @test calculate_ewma([1.0]; lambda=0.2, L=3.0) === nothing
    end

    # ─── Funnel Proportion ───────────────────────────────────────────────

    @testset "Funnel proportion — in-control" begin
        events = [10, 20, 15, 25, 30]
        denoms = [100, 200, 150, 250, 300]
        result = calculate_funnel_proportion(events, denoms)
        @test result !== nothing
        @test result.center_line ≈ sum(events) / sum(denoms)
        @test length(result.ucl) == 5
        # Larger denominators should have tighter limits
        @test result.ucl[5] - result.center_line < result.ucl[1] - result.center_line
        @test isempty(result.signals)
    end

    @testset "Funnel proportion — with outlier" begin
        events = [10, 20, 15, 80, 30]
        denoms = [100, 200, 150, 100, 300]
        result = calculate_funnel_proportion(events, denoms)
        @test result !== nothing
        @test !isempty(result.signals)
        @test 4 in result.signals  # 80/100 = 0.80, way above average
    end

    @testset "Funnel proportion — custom target" begin
        events = [10, 20, 15, 25, 30]
        denoms = [100, 200, 150, 250, 300]
        result = calculate_funnel_proportion(events, denoms; target=0.15)
        @test result !== nothing
        @test result.center_line == 0.15
    end

    @testset "Funnel proportion — limits narrow with volume" begin
        events = [5, 50, 500]
        denoms = [50, 500, 5000]
        result = calculate_funnel_proportion(events, denoms)
        @test result !== nothing
        # Width of limits should decrease with denominator
        widths = result.ucl .- result.lcl
        @test widths[1] > widths[2] > widths[3]
    end

    # ─── Funnel Rate ─────────────────────────────────────────────────────

    @testset "Funnel rate — in-control" begin
        events = [5, 10, 15, 20, 25]
        denoms = [100.0, 200.0, 300.0, 400.0, 500.0]
        result = calculate_funnel_rate(events, denoms)
        @test result !== nothing
        @test result.center_line ≈ sum(events) / sum(denoms)
        @test length(result.ucl) == 5
        @test isempty(result.signals)
    end

    @testset "Funnel rate — with outlier" begin
        events = [5, 10, 15, 100, 25]
        denoms = [100.0, 200.0, 300.0, 100.0, 500.0]
        result = calculate_funnel_rate(events, denoms)
        @test result !== nothing
        @test !isempty(result.signals)
        @test 4 in result.signals
    end

    @testset "Funnel rate — custom target" begin
        events = [5, 10, 15]
        denoms = [100.0, 200.0, 300.0]
        result = calculate_funnel_rate(events, denoms; target=0.1)
        @test result !== nothing
        @test result.center_line == 0.1
    end

    # ─── Western Electric Run Rules ──────────────────────────────────────

    @testset "Run rules — Rule 1 (beyond 3σ)" begin
        # Put a point at 4σ above center
        values = [0.0, 0.1, -0.1, 0.0, 4.0, 0.0, -0.1, 0.1]
        violations = detect_western_electric_rules(values, 0.0, 1.0)
        rule1 = filter(v -> v.rule == 1, violations)
        @test !isempty(rule1)
        @test any(v -> v.index == 5, rule1)
    end

    @testset "Run rules — Rule 2 (2 of 3 beyond 2σ)" begin
        # Place 2 of 3 consecutive points beyond 2σ above
        values = [0.0, 0.0, 0.0, 2.5, 0.5, 2.5, 0.0, 0.0]
        violations = detect_western_electric_rules(values, 0.0, 1.0)
        rule2 = filter(v -> v.rule == 2, violations)
        @test !isempty(rule2)
    end

    @testset "Run rules — Rule 3 (4 of 5 beyond 1σ)" begin
        # Place 4 of 5 consecutive points beyond 1σ above
        values = [0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 0.5, 1.5, 1.5]
        violations = detect_western_electric_rules(values, 0.0, 1.0)
        rule3 = filter(v -> v.rule == 3, violations)
        @test !isempty(rule3)
    end

    @testset "Run rules — Rule 4 (8 consecutive same side)" begin
        # 8 consecutive points above center
        values = [0.1, 0.2, 0.3, 0.1, 0.2, 0.1, 0.3, 0.2, -0.1, 0.0]
        violations = detect_western_electric_rules(values, 0.0, 1.0)
        rule4 = filter(v -> v.rule == 4, violations)
        @test !isempty(rule4)
        @test any(v -> v.index == 8, rule4)
    end

    @testset "Run rules — no violations for stable data" begin
        # Data centered around 0 with alternating sides
        values = [0.5, -0.3, 0.4, -0.2, 0.3, -0.4, 0.2, -0.5, 0.3, -0.3]
        violations = detect_western_electric_rules(values, 0.0, 1.0)
        @test isempty(violations)
    end

    @testset "Run rules — zero sigma returns empty" begin
        values = [1.0, 2.0, 3.0]
        violations = detect_western_electric_rules(values, 0.0, 0.0)
        @test isempty(violations)
    end

    @testset "Run rules — struct fields" begin
        values = [0.0, 0.0, 0.0, 5.0]
        violations = detect_western_electric_rules(values, 0.0, 1.0)
        @test !isempty(violations)
        v = violations[1]
        @test v.index isa Int
        @test v.rule isa Int
        @test v.description isa String
    end

end
