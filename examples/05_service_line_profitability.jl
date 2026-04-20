"""
    05_service_line_profitability.jl

Service Line Profitability Analysis for a Rural Hospital

This example demonstrates how a rural hospital CFO can use the HospitalFinanceToolbox
to analyze which service lines are profitable and which need restructuring.

Scenario: Community Hospital, 250-bed rural hospital in the Midwest
Problem: Which services should we expand, maintain, or divest?
"""

using CSV
using DataFrames

# Include the modules
include("../src/episode/ServiceLineTypes.jl")
include("../src/episode/ServiceLineCostAllocation.jl")
include("../src/episode/ServiceLineMetrics.jl")
include("../src/episode/Benchmarking.jl")

println("=" ^ 80)
println("SERVICE LINE PROFITABILITY ANALYSIS")
println("Community Hospital - Rural Hospital (250 beds)")
println("=" ^ 80)
println()

# Create sample service line data for a realistic rural hospital
service_lines = [
    ServiceLine(
        id="ORTHO",
        name="Orthopedic Surgery",
        department="Surgical",
        drg_codes=["469", "470", "471"],
        volume=142,
        revenue=5_240_000.0,
        direct_cost=3_150_000.0
    ),
    ServiceLine(
        id="CARDIO",
        name="Cardiology",
        department="Medical",
        drg_codes=["246", "247", "248"],
        volume=189,
        revenue=7_140_000.0,
        direct_cost=4_280_000.0
    ),
    ServiceLine(
        id="GENSURG",
        name="General Surgery",
        department="Surgical",
        drg_codes=["164", "165", "166"],
        volume=218,
        revenue=5_890_000.0,
        direct_cost=4_120_000.0
    ),
    ServiceLine(
        id="OB",
        name="Obstetrics",
        department="Women's Services",
        drg_codes=["373", "374", "375"],
        volume=95,
        revenue=2_850_000.0,
        direct_cost=2_660_000.0
    ),
    ServiceLine(
        id="ONCO",
        name="Oncology",
        department="Medical",
        drg_codes=["844", "845"],
        volume=68,
        revenue=4_080_000.0,
        direct_cost=3_060_000.0
    ),
    ServiceLine(
        id="NEURO",
        name="Neurology",
        department="Medical",
        drg_codes=["023", "024"],
        volume=102,
        revenue=3_570_000.0,
        direct_cost=2_550_000.0
    ),
    ServiceLine(
        id="ED",
        name="Emergency Medicine",
        department="Emergency",
        drg_codes=["999"],
        volume=412,
        revenue=3_090_000.0,
        direct_cost=2_950_000.0
    ),
    ServiceLine(
        id="ICU",
        name="ICU",
        department="Critical Care",
        drg_codes=["999"],
        volume=156,
        revenue=4_680_000.0,
        direct_cost=3_510_000.0
    ),
]

println("\n1. SERVICE LINE SUMMARY")
println("-" ^ 80)
df_services = DataFrame(
    id=[sl.id for sl in service_lines],
    name=[sl.name for sl in service_lines],
    volume=[sl.volume for sl in service_lines],
    revenue=[string(Int(sl.revenue ÷ 1000)) * "K" for sl in service_lines],
    direct_cost=[string(Int(sl.direct_cost ÷ 1000)) * "K" for sl in service_lines],
)
println(df_services)

# Analyze service lines
total_indirect_costs = 8_500_000.0  # Hospital overhead

println("\n2. PROFITABILITY ANALYSIS (Proportional Cost Allocation)")
println("-" ^ 80)
result = analyze_service_lines(service_lines, total_indirect_costs, allocation_method=:proportional)

println("\nTotal Hospital Statistics:")
revenue_str = string(round(Int, result.total_revenue ÷ 1000))
direct_str = string(round(Int, result.total_direct_cost ÷ 1000))
indirect_str = string(round(Int, result.total_indirect_cost ÷ 1000))
margin_str = string(round(Int, result.total_margin ÷ 1000))
margin_pct = string(round(result.total_margin_pct, digits=2))

println("  Total Revenue:        \$" * revenue_str * "K")
println("  Total Direct Costs:   \$" * direct_str * "K")
println("  Total Indirect Costs: \$" * indirect_str * "K")
println("  Total Margin:         \$" * margin_str * "K")
println("  Margin %:             " * margin_pct * "%")

println("\nService Line Profitability:")
for sl in result.service_lines
    metrics = result.metrics[sl.id]
    status_icon = metrics.profitability_status == :profitable ? "✓" : "✗"
    margin_int = round(Int, metrics.allocated_margin ÷ 1000)
    margin_pct = round(metrics.allocated_margin_pct, digits=1)
    revenue_per_case = round(Int, metrics.revenue_per_case)

    println("  $status_icon $(sl.name)")
    println("     Margin: \$" * string(margin_int) * "K (" * string(margin_pct) * "%)")
    println("     Volume: $(sl.volume) cases @ \$" * string(revenue_per_case) * " revenue/case")
end

println("\nProfitable Services ($(length(result.profitable_services))):")
for id in result.profitable_services
    sl_name = result.service_lines[findfirst(s -> s.id == id, result.service_lines)].name
    println("  • $sl_name")
end

println("\nUnprofitable Services ($(length(result.loss_services))):")
if !isempty(result.loss_services)
    for id in result.loss_services
        sl_name = result.service_lines[findfirst(s -> s.id == id, result.service_lines)].name
        println("  • $sl_name")
    end
else
    println("  None - all services are profitable!")
end

# Benchmarking
println("\n3. BENCHMARK COMPARISON (Rural Hospital Standards)")
println("-" ^ 80)
benchmarks = get_rural_benchmarks()

comparison_results = []
for sl in result.service_lines
    metrics = result.metrics[sl.id]
    comparison = benchmark_compare(sl, metrics, benchmarks)

    if comparison !== nothing
        push!(comparison_results, comparison)
    end
end

# Sort by performance
sort!(comparison_results, by=c -> c.percentile_rank, rev=true)

for comp in comparison_results
    status = if comp.performance_rating == :excellent
        "⭐⭐⭐"
    elseif comp.performance_rating == :good
        "⭐⭐"
    elseif comp.performance_rating == :fair
        "⭐"
    else
        "!"
    end

    margin_h = round(comp.hospital_margin_pct, digits=1)
    margin_b = round(comp.benchmark_median_margin_pct, digits=1)
    cost_h = round(Int, comp.hospital_cost_per_case)
    cost_b = round(Int, comp.benchmark_cost_per_case)
    eff = round(comp.cost_efficiency, digits=2)

    println("\n$status $(comp.service_line_name)")
    println("  Margin:           $margin_h% (benchmark median: $margin_b%)")
    println("  Quartile:         $(String(comp.quartile))")
    println("  Cost/Case:        \$$cost_h (benchmark: \$$cost_b)")
    println("  Cost Efficiency:  $eff" * "x benchmark")
end

# Metrics analysis
println("\n4. EFFICIENCY METRICS")
println("-" ^ 80)
metrics = efficiency_metrics(result.service_lines)
rev_case = round(Int, metrics["avg_revenue_per_case"])
cost_case = round(Int, metrics["avg_direct_cost_per_case"])
cost_rev = round(metrics["cost_to_revenue_ratio"], digits=2)
cost_rev_pct = round(metrics["cost_to_revenue_ratio"] * 100, digits=1)
conc = round(metrics["revenue_concentration"], digits=3)

println("Average Revenue/Case:  \$$rev_case")
println("Average Cost/Case:     \$$cost_case")
println("Cost-to-Revenue Ratio: $cost_rev ($cost_rev_pct%)")
println("Revenue Concentration: $conc")

# Ranking by metrics
println("\n5. SERVICE LINE RANKINGS")
println("-" ^ 80)

println("\nBy Margin:")
rankings = rank_service_lines_by_metric(result.service_lines, :margin)
for (i, (id, value)) in enumerate(rankings)
    sl = result.service_lines[findfirst(s -> s.id == id, result.service_lines)]
    val_str = string(round(Int, value ÷ 1000))
    println("  $(i). $(sl.name): \$$val_str" * "K")
end

println("\nBy Margin %:")
rankings = rank_service_lines_by_metric(result.service_lines, :margin_pct)
for (i, (id, value)) in enumerate(rankings)
    sl = result.service_lines[findfirst(s -> s.id == id, result.service_lines)]
    val_str = string(round(value, digits=1))
    println("  $(i). $(sl.name): $val_str%")
end

println("\nBy Volume:")
rankings = rank_service_lines_by_metric(result.service_lines, :volume)
for (i, (id, value)) in enumerate(rankings)
    sl = result.service_lines[findfirst(s -> s.id == id, result.service_lines)]
    println("  $(i). $(sl.name): $(Int(value)) cases")
end

# Case mix analysis
println("\n6. CASE MIX ANALYSIS")
println("-" ^ 80)
case_mix = case_mix_analysis(result.service_lines)
total_vol = Int(case_mix["total_volume"])
n_services = Int(case_mix["n_service_lines"])
avg_vol = round(case_mix["avg_volume_per_line"], digits=0)
top3 = round(case_mix["top_3_volume_pct"], digits=1)

println("Total Volume:          $total_vol cases")
println("Number of Services:    $n_services")
println("Avg Volume/Service:    $avg_vol cases")
println("Top 3 Volume Share:    $top3%")

# Sensitivity analysis
println("\n7. SENSITIVITY ANALYSIS (5% Revenue Decline, 10% Cost Increase)")
println("-" ^ 80)
for sl in result.service_lines[1:min(3, length(result.service_lines))]
    sensitivity = sensitivity_analysis(sl, -0.05, 0.10)
    orig = string(round(Int, sensitivity["original_margin"] ÷ 1000))
    stressed = string(round(Int, sensitivity["new_margin"] ÷ 1000))
    change = string(round(sensitivity["margin_change_pct"], digits=1))

    println("\n$(sl.name):")
    println("  Original Margin: \$$orig" * "K")
    println("  Stressed Margin: \$$stressed" * "K")
    println("  Change:          $change%")
end

# Recommendations
println("\n8. CFO RECOMMENDATIONS")
println("-" ^ 80)
for (i, rec) in enumerate(result.recommendations)
    println("  $i. $rec")
end

# Cost drivers
println("\n9. TOP COST DRIVERS")
println("-" ^ 80)
sorted_costs = sort(collect(result.cost_drivers), by=x -> x[2], rev=true)[1:min(5, length(result.cost_drivers))]
for (driver, amount) in sorted_costs
    if amount > 100_000
        amt_str = string(round(Int, amount ÷ 1000))
        println("  • $driver: \$$amt_str" * "K")
    end
end

println("\n" * ("=" ^ 80))
println("ANALYSIS COMPLETE")
println("=" ^ 80)
println("\nKey Insights:")
profitable_pct = round(length(result.profitable_services) / length(result.service_lines) * 100, digits=0)
margin_val = string(round(result.total_margin_pct, digits=1))

println("• This hospital has $(length(result.profitable_services))/$(length(result.service_lines)) profitable service lines")
println("• Overall margin is $margin_val% — " * (result.total_margin_pct > 5 ? "HEALTHY" : "NEEDS IMPROVEMENT"))
println("• Focus areas: Emergency and OB services tend to be low-margin in rural hospitals")
println("• Opportunity: Leverage high-margin services (Oncology, Cardiology) to cross-subsidize essential services")
