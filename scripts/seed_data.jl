# ============================================================================
# Seed Reference and Benchmark Data
# Rural Hospital Economics Simulator
# ============================================================================

using Dates

println("=" ^ 70)
println("Rural Hospital Economics Simulator — Data Seeder")
println("=" ^ 70)
println()

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
const DATA_DIR = joinpath(@__DIR__, "..", "data")
const REF_DIR = joinpath(DATA_DIR, "reference")
const SAMPLE_DIR = joinpath(DATA_DIR, "sample")

for dir in [REF_DIR, SAMPLE_DIR]
    mkpath(dir)
end

# ---------------------------------------------------------------------------
# National CAH Benchmark Data (sourced from Flex Monitoring Team reports)
# ---------------------------------------------------------------------------
const CAH_BENCHMARKS = Dict(
    "operating_margin" => Dict(
        "p25" => -0.065,
        "median" => -0.005,
        "p75" => 0.042,
        "mean" => -0.012,
    ),
    "total_margin" => Dict(
        "p25" => -0.008,
        "median" => 0.024,
        "p75" => 0.058,
        "mean" => 0.022,
    ),
    "days_cash_on_hand" => Dict(
        "p25" => 42.0,
        "median" => 95.0,
        "p75" => 185.0,
        "mean" => 128.0,
    ),
    "current_ratio" => Dict(
        "p25" => 1.55,
        "median" => 2.45,
        "p75" => 4.10,
        "mean" => 3.20,
    ),
    "debt_to_capitalization" => Dict(
        "p25" => 0.12,
        "median" => 0.32,
        "p75" => 0.52,
        "mean" => 0.33,
    ),
    "average_age_of_plant" => Dict(
        "p25" => 8.5,
        "median" => 12.8,
        "p75" => 18.2,
        "mean" => 13.5,
    ),
    "fte_per_adjusted_occupied_bed" => Dict(
        "p25" => 4.8,
        "median" => 6.2,
        "p75" => 8.1,
        "mean" => 6.5,
    ),
    "salary_to_revenue" => Dict(
        "p25" => 0.46,
        "median" => 0.52,
        "p75" => 0.59,
        "mean" => 0.52,
    ),
    "outpatient_revenue_share" => Dict(
        "p25" => 0.62,
        "median" => 0.72,
        "p75" => 0.82,
        "mean" => 0.72,
    ),
    "medicare_cost_to_charge" => Dict(
        "p25" => 0.34,
        "median" => 0.42,
        "p75" => 0.52,
        "mean" => 0.43,
    ),
)

# ---------------------------------------------------------------------------
# CMS Payment Parameters (FY/CY 2024)
# ---------------------------------------------------------------------------
const CMS_PARAMS = Dict(
    "ffy" => 2024,
    "ipps_base_rate" => 6378.76,
    "opps_conversion_factor" => 89.93,
    "cah_cost_reimbursement_rate" => 1.01,
    "reh_monthly_facility_payment" => 272866.30,
    "reh_opps_addon" => 0.05,
    "sequestration_rate" => 0.02,
    "bad_debt_reimbursement_rate" => 0.65,
    "outlier_threshold" => 33166.00,
    "cola_cap" => 1.25,
    "market_basket_update" => 0.032,
    "productivity_adjustment" => -0.004,
    "net_update_factor" => 0.028,
)

# ---------------------------------------------------------------------------
# State-level Rural Hospital Statistics
# ---------------------------------------------------------------------------
const STATE_STATS = Dict(
    "KS" => Dict("total_cahs" => 83, "closures_since_2010" => 4, "avg_beds" => 20, "avg_margin" => -0.01),
    "TX" => Dict("total_cahs" => 86, "closures_since_2010" => 21, "avg_beds" => 22, "avg_margin" => -0.03),
    "NE" => Dict("total_cahs" => 64, "closures_since_2010" => 2, "avg_beds" => 18, "avg_margin" => 0.01),
    "IA" => Dict("total_cahs" => 82, "closures_since_2010" => 1, "avg_beds" => 20, "avg_margin" => 0.02),
    "OK" => Dict("total_cahs" => 41, "closures_since_2010" => 7, "avg_beds" => 21, "avg_margin" => -0.04),
    "MO" => Dict("total_cahs" => 36, "closures_since_2010" => 5, "avg_beds" => 22, "avg_margin" => -0.02),
    "GA" => Dict("total_cahs" => 31, "closures_since_2010" => 9, "avg_beds" => 23, "avg_margin" => -0.05),
    "TN" => Dict("total_cahs" => 22, "closures_since_2010" => 6, "avg_beds" => 24, "avg_margin" => -0.03),
    "AL" => Dict("total_cahs" => 20, "closures_since_2010" => 5, "avg_beds" => 22, "avg_margin" => -0.04),
    "MS" => Dict("total_cahs" => 28, "closures_since_2010" => 6, "avg_beds" => 21, "avg_margin" => -0.06),
)

# ---------------------------------------------------------------------------
# Write benchmark JSON
# ---------------------------------------------------------------------------
println("[1/3] Writing benchmark data...")

benchmarks_path = joinpath(REF_DIR, "cah_benchmarks.json")
open(benchmarks_path, "w") do io
    println(io, "{")
    println(io, "  \"source\": \"Flex Monitoring Team / Chartis Center for Rural Health\",")
    println(io, "  \"year\": 2023,")
    println(io, "  \"benchmarks\": {")
    items = collect(CAH_BENCHMARKS)
    for (i, (key, vals)) in enumerate(items)
        comma = i < length(items) ? "," : ""
        println(io, "    \"$key\": {\"p25\": $(vals["p25"]), \"median\": $(vals["median"]), \"p75\": $(vals["p75"]), \"mean\": $(vals["mean"])}$comma")
    end
    println(io, "  }")
    println(io, "}")
end
println("  -> $benchmarks_path")

# ---------------------------------------------------------------------------
# Write CMS parameters
# ---------------------------------------------------------------------------
println("[2/3] Writing CMS payment parameters...")

cms_path = joinpath(REF_DIR, "cms_payment_params.json")
open(cms_path, "w") do io
    println(io, "{")
    items = collect(CMS_PARAMS)
    for (i, (key, val)) in enumerate(items)
        comma = i < length(items) ? "," : ""
        if val isa String
            println(io, "  \"$key\": \"$val\"$comma")
        else
            println(io, "  \"$key\": $val$comma")
        end
    end
    println(io, "}")
end
println("  -> $cms_path")

# ---------------------------------------------------------------------------
# Write state statistics
# ---------------------------------------------------------------------------
println("[3/3] Writing state-level rural hospital statistics...")

states_path = joinpath(REF_DIR, "state_rural_hospital_stats.json")
open(states_path, "w") do io
    println(io, "{")
    items = collect(STATE_STATS)
    for (i, (state, stats)) in enumerate(items)
        comma = i < length(items) ? "," : ""
        println(io, "  \"$state\": {\"total_cahs\": $(stats["total_cahs"]), \"closures_since_2010\": $(stats["closures_since_2010"]), \"avg_beds\": $(stats["avg_beds"]), \"avg_margin\": $(stats["avg_margin"])}$comma")
    end
    println(io, "}")
end
println("  -> $states_path")

println()
println("Seed data written successfully.")
println("=" ^ 70)
