# ============================================================================
# Performance Benchmark Script
# Rural Hospital Economics Simulator
# ============================================================================

using Dates

println("=" ^ 70)
println("Rural Hospital Economics Simulator — Performance Benchmarks")
println("Run at: $(now())")
println("=" ^ 70)
println()

# Include source files
include(joinpath(@__DIR__, "..", "src", "types", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "engines", "deterministic.jl"))

# ---------------------------------------------------------------------------
# Helper: standard base financials
# ---------------------------------------------------------------------------
function benchmark_base_financials()
    (
        inpatient_revenue=3_000_000.0,
        outpatient_revenue=8_000_000.0,
        salary_expense=6_500_000.0,
        supply_expense=1_800_000.0,
        other_expense=2_200_000.0,
        cash_reserves=2_500_000.0,
        depreciation=500_000.0,
        annual_debt_service=400_000.0,
        payer_mix_government=0.73,
    )
end

# ---------------------------------------------------------------------------
# Benchmark: Deterministic Projection
# ---------------------------------------------------------------------------
function bench_deterministic(n_runs::Int)
    bf = benchmark_base_financials()
    params = DeterministicParams()

    # Warmup
    project_financials(bf, params)

    t_start = time_ns()
    for _ in 1:n_runs
        project_financials(bf, params)
    end
    t_elapsed = (time_ns() - t_start) / 1e9

    avg_ms = (t_elapsed / n_runs) * 1000
    println("  Deterministic projection (10-year):")
    println("    Runs: $n_runs")
    println("    Total time: $(round(t_elapsed, digits=3))s")
    println("    Avg per run: $(round(avg_ms, digits=3))ms")
    println("    Throughput: $(round(n_runs / t_elapsed, digits=0)) runs/sec")
    println()
    return avg_ms
end

# ---------------------------------------------------------------------------
# Benchmark: Single-year projection
# ---------------------------------------------------------------------------
function bench_single_year(n_runs::Int)
    bf = benchmark_base_financials()
    params = DeterministicParams()

    # Warmup
    project_single_year(bf, 1, params)

    t_start = time_ns()
    for _ in 1:n_runs
        for y in 1:10
            project_single_year(bf, y, params)
        end
    end
    t_elapsed = (time_ns() - t_start) / 1e9

    total_calls = n_runs * 10
    avg_us = (t_elapsed / total_calls) * 1e6
    println("  Single-year projection:")
    println("    Total calls: $total_calls")
    println("    Total time: $(round(t_elapsed, digits=3))s")
    println("    Avg per call: $(round(avg_us, digits=2))us")
    println("    Throughput: $(round(total_calls / t_elapsed, digits=0)) calls/sec")
    println()
    return avg_us
end

# ---------------------------------------------------------------------------
# Benchmark: Monte Carlo (simplified inline version)
# ---------------------------------------------------------------------------
function bench_monte_carlo(n_simulations::Int)
    using Random
    bf = benchmark_base_financials()

    # Warmup
    rng = MersenneTwister(42)
    for _ in 1:10
        vol_growth = -0.01 + randn(rng) * 0.02
        dp = DeterministicParams(;
            projection_years=10,
            volume_growth_rate=vol_growth,
        )
        project_financials(bf, dp)
    end

    rng = MersenneTwister(42)
    t_start = time_ns()
    for _ in 1:n_simulations
        vol_growth = -0.01 + randn(rng) * 0.02
        cost_infl = 0.03 + randn(rng) * 0.01
        dp = DeterministicParams(;
            projection_years=10,
            volume_growth_rate=vol_growth,
            cost_inflation_rate=cost_infl,
            salary_inflation_rate=cost_infl + 0.005,
            supply_inflation_rate=cost_infl + 0.01,
            reimbursement_adjustment=0.015 + randn(rng) * 0.005,
            payer_mix_shift=0.005,
        )
        project_financials(bf, dp)
    end
    t_elapsed = (time_ns() - t_start) / 1e9

    avg_ms = (t_elapsed / n_simulations) * 1000
    println("  Monte Carlo simulation ($n_simulations trials):")
    println("    Total time: $(round(t_elapsed, digits=3))s")
    println("    Avg per trial: $(round(avg_ms, digits=3))ms")
    println("    Throughput: $(round(n_simulations / t_elapsed, digits=0)) trials/sec")
    println()
    return t_elapsed
end

# ---------------------------------------------------------------------------
# Benchmark: Memory allocation
# ---------------------------------------------------------------------------
function bench_allocation()
    bf = benchmark_base_financials()
    params = DeterministicParams()

    # Force GC before measurement
    GC.gc()
    mem_before = Base.gc_live_bytes()

    results = [project_financials(bf, params) for _ in 1:1000]

    GC.gc()
    mem_after = Base.gc_live_bytes()
    mem_delta_mb = (mem_after - mem_before) / (1024^2)

    println("  Memory allocation (1000 projections):")
    println("    Live bytes delta: $(round(mem_delta_mb, digits=2)) MB")
    println("    Avg per projection: $(round(mem_delta_mb * 1024 / 1000, digits=2)) KB")
    println()
end

# ---------------------------------------------------------------------------
# Run all benchmarks
# ---------------------------------------------------------------------------
println("Running benchmarks...")
println("-" ^ 40)

det_ms = bench_deterministic(10_000)
sy_us = bench_single_year(10_000)
mc_s = bench_monte_carlo(1_000)
bench_allocation()

println("=" ^ 70)
println("Summary:")
println("  Deterministic (10yr): $(round(det_ms, digits=3)) ms/run")
println("  Single-year:          $(round(sy_us, digits=2)) us/call")
println("  Monte Carlo (1K):     $(round(mc_s, digits=3)) s total")
println("=" ^ 70)

# Performance targets
println()
println("Performance targets:")
if det_ms < 1.0
    println("  [PASS] Deterministic < 1ms")
else
    println("  [WARN] Deterministic $(round(det_ms, digits=3))ms > 1ms target")
end
if mc_s < 5.0
    println("  [PASS] Monte Carlo 1K < 5s")
else
    println("  [WARN] Monte Carlo $(round(mc_s, digits=3))s > 5s target")
end
