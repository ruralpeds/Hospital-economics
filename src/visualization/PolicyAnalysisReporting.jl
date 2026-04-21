"""
    PolicyAnalysisReporting

Module for generating publication-ready visualizations and reports for healthcare economics analysis.

# Features
- Cost-effectiveness analysis curves (CEAC, net benefit)
- Budget impact model projections
- Equity analysis by demographics
- Sensitivity analysis tornado plots
- Hospital network visualizations
- Policy scenario comparisons
- Summary tables and data exports

# Example
```julia
# Generate CEAC curve comparing policy scenarios
scenarios = [scenario1, scenario2, scenario3]
wtp_range = 25000:5000:150000  # Willingness-to-pay threshold range
ceac_data = plot_ceac_curves(scenarios, wtp_range)
```
"""

module PolicyAnalysisReporting

export CEACData, NetBenefitData, BudgetImpactData
export EquityAnalysis, SensitivityAnalysis, NetworkVisualization
export SummaryTable
export plot_ceac_curves, plot_net_benefit_curves, plot_budget_impact
export plot_equity_analysis, plot_sensitivity_tornado, plot_hospital_network
export generate_summary_table, export_analysis_data

using Statistics
using Printf

# ====================================
# Data Structures for Visualizations
# ====================================

"""
    CEACData

Data structure for Cost-Effectiveness Acceptability Curve (CEAC).
Shows probability that each intervention is cost-effective at each WTP threshold.
"""
mutable struct CEACData
    scenario_names::Vector{String}
    wtp_thresholds::Vector{Float64}
    probabilities::Matrix{Float64}  # Rows: scenarios, Columns: WTP thresholds
    metadata::Dict{String, Any}
end

"""
    NetBenefitData

Net Benefit = Benefits (QALYs × WTP) - Costs
Shows which scenario is best at each willingness-to-pay threshold.
"""
mutable struct NetBenefitData
    scenario_names::Vector{String}
    wtp_thresholds::Vector{Float64}
    net_benefits::Matrix{Float64}  # Rows: scenarios, Columns: WTP thresholds
    incremental_net_benefits::Matrix{Float64}
    metadata::Dict{String, Any}
end

"""
    BudgetImpactData

Budget impact model projections over time.
Shows cumulative cost/savings impact and annual impacts.
"""
mutable struct BudgetImpactData
    scenario_names::Vector{String}
    years::Vector{Int}
    annual_impacts::Matrix{Float64}  # Rows: scenarios, Columns: years
    cumulative_impacts::Matrix{Float64}
    affected_patients::Vector{Int}
    metadata::Dict{String, Any}
end

"""
    EquityAnalysis

Health and financial outcomes by demographic groups.
Identifies policies that increase or decrease equity.
"""
mutable struct EquityAnalysis
    scenario_name::String
    demographic_groups::Vector{String}
    health_outcomes::Dict{String, Float64}
    financial_outcomes::Dict{String, Float64}
    disparities::Dict{String, Float64}
    metadata::Dict{String, Any}
end

"""
    SensitivityAnalysis

One-way sensitivity analysis results.
Shows which parameters have largest impact on outcomes.
"""
mutable struct SensitivityAnalysis
    scenario_name::String
    parameter_names::Vector{String}
    base_case_value::Float64
    low_values::Vector{Float64}
    high_values::Vector{Float64}
    output_metric::String
    metadata::Dict{String, Any}
end

"""
    NetworkVisualization

Hospital network structure and financial metrics for visualization.
"""
mutable struct NetworkVisualization
    hospital_ids::Vector{String}
    hospital_locations::Vector{Tuple{Float64, Float64}}
    hospital_margins::Vector{Float64}
    hospital_quality::Vector{Float64}
    referral_volumes::Matrix{Float64}
    hospital_beds::Vector{Int}
    metadata::Dict{String, Any}
end

# ====================================
# CEAC Curves (Cost-Effectiveness)
# ====================================

"""
    plot_ceac_curves(
        scenario_names::Vector{String},
        qaly_gains::Matrix{Float64},
        costs::Matrix{Float64},
        wtp_range::Vector{Float64};
        num_simulations::Int=1000
    )::CEACData

Generate Cost-Effectiveness Acceptability Curve (CEAC) data.

# Arguments
- `scenario_names`: Names of policy scenarios
- `qaly_gains`: Matrix of QALY gains (rows: scenarios, cols: simulations/iterations)
- `costs`: Matrix of costs (rows: scenarios, cols: simulations/iterations)
- `wtp_range`: Range of willingness-to-pay thresholds (per QALY)
- `num_simulations`: Number of simulations for probabilistic analysis

# Returns
- CEACData with probabilities that each scenario is cost-effective at each WTP threshold
"""
function plot_ceac_curves(scenario_names::Vector{String},
                          qaly_gains::Matrix{Float64},
                          costs::Matrix{Float64},
                          wtp_range::Vector{Float64};
                          num_simulations::Int=1000)::CEACData

    n_scenarios = length(scenario_names)
    n_wtp = length(wtp_range)

    # Calculate net benefits at each WTP threshold
    probabilities = zeros(n_scenarios, n_wtp)

    for (j, wtp) in enumerate(wtp_range)
        # Net benefit = QALYs * WTP - Costs
        net_benefits = qaly_gains .* wtp .- costs

        # Probability = % of simulations where this scenario has max net benefit
        for i in 1:n_scenarios
            max_benefits = maximum(net_benefits, dims=1)[1, :]
            prob = sum(net_benefits[i, :] .>= (max_benefits .- 1e-6)) / size(net_benefits, 2)
            probabilities[i, j] = prob
        end
    end

    return CEACData(
        scenario_names,
        wtp_range,
        probabilities,
        Dict("description" => "Cost-Effectiveness Acceptability Curve",
             "num_scenarios" => n_scenarios,
             "num_wtp_thresholds" => n_wtp)
    )
end

# ====================================
# Net Benefit Curves
# ====================================

"""
    plot_net_benefit_curves(
        scenario_names::Vector{String},
        qaly_gains::Matrix{Float64},
        costs::Matrix{Float64},
        wtp_range::Vector{Float64}
    )::NetBenefitData

Generate Net Benefit curves showing which scenario is best at each WTP.
"""
function plot_net_benefit_curves(scenario_names::Vector{String},
                                 qaly_gains::Matrix{Float64},
                                 costs::Matrix{Float64},
                                 wtp_range::Vector{Float64})::NetBenefitData

    n_scenarios = length(scenario_names)
    n_wtp = length(wtp_range)

    net_benefits = zeros(n_scenarios, n_wtp)
    incremental_net_benefits = zeros(n_scenarios, n_wtp)

    baseline_qaly = mean(qaly_gains[1, :])  # Assume first scenario is baseline
    baseline_cost = mean(costs[1, :])

    for (j, wtp) in enumerate(wtp_range)
        for i in 1:n_scenarios
            mean_qaly = mean(qaly_gains[i, :])
            mean_cost = mean(costs[i, :])

            # Absolute net benefit
            net_benefits[i, j] = mean_qaly * wtp - mean_cost

            # Incremental net benefit vs baseline
            incremental_nb = (mean_qaly - baseline_qaly) * wtp - (mean_cost - baseline_cost)
            incremental_net_benefits[i, j] = incremental_nb
        end
    end

    return NetBenefitData(
        scenario_names,
        wtp_range,
        net_benefits,
        incremental_net_benefits,
        Dict("description" => "Net Benefit Curves",
             "x_axis" => "Willingness-to-Pay (per QALY)",
             "y_axis" => "Net Benefit (USD)")
    )
end

# ====================================
# Budget Impact Model
# ====================================

"""
    plot_budget_impact(
        scenario_names::Vector{String},
        annual_impacts::Matrix{Float64},
        years::Vector{Int},
        affected_patients::Vector{Int}
    )::BudgetImpactData

Generate Budget Impact Model projections showing cumulative cost/savings over time.
"""
function plot_budget_impact(scenario_names::Vector{String},
                            annual_impacts::Matrix{Float64},
                            years::Vector{Int},
                            affected_patients::Vector{Int}=Int[])::BudgetImpactData

    n_scenarios = length(scenario_names)
    cumulative = zeros(n_scenarios, length(years))

    for i in 1:n_scenarios
        cumulative[i, :] = cumsum(annual_impacts[i, :])
    end

    return BudgetImpactData(
        scenario_names,
        years,
        annual_impacts,
        cumulative,
        affected_patients,
        Dict("description" => "Budget Impact Model Projections",
             "units" => "USD",
             "time_horizon" => "$(years[1])-$(years[end])")
    )
end

# ====================================
# Equity Analysis
# ====================================

"""
    plot_equity_analysis(
        scenario_name::String,
        demographic_data::Dict{String, NamedTuple}
    )::EquityAnalysis

Analyze health and financial outcomes by demographic group to assess equity impacts.
"""
function plot_equity_analysis(scenario_name::String,
                              demographic_data::Dict)::EquityAnalysis

    demographics = keys(demographic_data)
    health_outcomes = Dict{String, Float64}()
    financial_outcomes = Dict{String, Float64}()
    disparities = Dict{String, Float64}()

    baseline_health = 0.0
    baseline_cost = 0.0

    for (i, (demo_group, data)) in enumerate(demographic_data)
        health = get(data, :health_outcome, 0.0)
        cost = get(data, :financial_outcome, 0.0)

        health_outcomes[demo_group] = health
        financial_outcomes[demo_group] = cost

        if i == 1  # Use first group as baseline
            baseline_health = health
            baseline_cost = cost
        end
    end

    # Calculate disparities (% difference from baseline)
    for (demo_group, health) in health_outcomes
        cost = financial_outcomes[demo_group]
        health_disparity = ((health - baseline_health) / baseline_health) * 100.0
        cost_disparity = ((cost - baseline_cost) / baseline_cost) * 100.0
        disparities[demo_group] = health_disparity - cost_disparity  # Higher is more equitable
    end

    return EquityAnalysis(
        scenario_name,
        collect(keys(demographic_data)),
        health_outcomes,
        financial_outcomes,
        disparities,
        Dict("description" => "Equity Analysis by Demographic Group")
    )
end

# ====================================
# Sensitivity Analysis (Tornado Plot)
# ====================================

"""
    plot_sensitivity_tornado(
        scenario_name::String,
        parameter_names::Vector{String},
        base_case_value::Float64,
        sensitivity_results::Dict{String, Tuple{Float64, Float64}},
        output_metric::String="Cost per QALY"
    )::SensitivityAnalysis

Generate one-way sensitivity analysis for tornado plot visualization.
Shows which parameters have largest impact on outcomes.

# Arguments
- `scenario_name`: Name of scenario
- `parameter_names`: Names of parameters tested
- `base_case_value`: Base case value of output metric
- `sensitivity_results`: Dict mapping param names to (low_value, high_value) tuples
- `output_metric`: Name of metric being analyzed
"""
function plot_sensitivity_tornado(scenario_name::String,
                                  parameter_names::Vector{String},
                                  base_case_value::Float64,
                                  sensitivity_results::Dict{String, Tuple{Float64, Float64}},
                                  output_metric::String="Cost per QALY")::SensitivityAnalysis

    low_values = Float64[]
    high_values = Float64[]

    for param in parameter_names
        if haskey(sensitivity_results, param)
            low, high = sensitivity_results[param]
            push!(low_values, low)
            push!(high_values, high)
        else
            push!(low_values, base_case_value)
            push!(high_values, base_case_value)
        end
    end

    return SensitivityAnalysis(
        scenario_name,
        parameter_names,
        base_case_value,
        low_values,
        high_values,
        output_metric,
        Dict("description" => "One-Way Sensitivity Analysis (Tornado Plot)")
    )
end

# ====================================
# Network Visualization
# ====================================

"""
    plot_hospital_network(
        hospital_ids::Vector{String},
        locations::Vector{Tuple{Float64, Float64}},
        margins::Vector{Float64},
        quality::Vector{Float64},
        referral_volumes::Matrix{Float64},
        beds::Vector{Int}
    )::NetworkVisualization

Generate hospital network visualization data.
Hospitals as nodes (colored by profitability), referral flows as edges (sized by volume).
"""
function plot_hospital_network(hospital_ids::Vector{String},
                               locations::Vector{Tuple{Float64, Float64}},
                               margins::Vector{Float64},
                               quality::Vector{Float64},
                               referral_volumes::Matrix{Float64},
                               beds::Vector{Int}=Int[])::NetworkVisualization

    if isempty(beds)
        beds = fill(250, length(hospital_ids))
    end

    return NetworkVisualization(
        hospital_ids,
        locations,
        margins,
        quality,
        referral_volumes,
        beds,
        Dict("description" => "Hospital Network Structure and Financial Metrics",
             "node_color_metric" => "Profit Margin",
             "edge_width_metric" => "Referral Volume")
    )
end

# ====================================
# Summary Tables & Exports
# ====================================

"""
    SummaryTable

Lightweight tabular structure for publication-ready policy outcome summaries.
Provides column-vector access and `size` compatible with common table patterns.
"""
struct SummaryTable
    Scenario::Vector{String}
    TotalCost::Vector{Float64}
    TotalQALYs::Vector{Float64}
    CostPerQALY::Vector{Float64}
    HospitalMargin::Vector{Float64}
    Quality::Vector{Float64}
    PatientAccess::Vector{Float64}
end

const SUMMARY_TABLE_COLUMNS = 7

Base.size(t::SummaryTable, d::Int) = d == 1 ? length(t.Scenario) : d == 2 ? SUMMARY_TABLE_COLUMNS : 1
Base.size(t::SummaryTable) = (length(t.Scenario), SUMMARY_TABLE_COLUMNS)

"""
    generate_summary_table(
        scenario_names::Vector{String},
        outcomes::Dict
    )::SummaryTable

Generate publication-ready summary table of policy outcomes.
"""
function generate_summary_table(scenario_names::Vector{String},
                                outcomes::Dict)::SummaryTable
    n = length(scenario_names)
    return SummaryTable(
        scenario_names,
        fill(Float64(get(outcomes, "total_cost",    0.0)), n),
        fill(Float64(get(outcomes, "total_qalys",   0.0)), n),
        fill(Float64(get(outcomes, "icer",          0.0)), n),
        fill(Float64(get(outcomes, "hospital_margin", 0.0)), n),
        fill(Float64(get(outcomes, "quality_score", 0.0)), n),
        fill(Float64(get(outcomes, "access_metric", 0.0)), n)
    )
end

"""
    export_analysis_data(
        scenario_results::Dict,
        output_filename::String;
        format::String="csv"
    )::String

Export analysis results to file for sharing and replication.

# Arguments
- `scenario_results`: Dictionary of results to export
- `output_filename`: Path to output file
- `format`: Export format ("csv" or "json")

# Returns
- Path to exported file
"""
function export_analysis_data(scenario_results::Dict,
                              output_filename::String;
                              format::String="csv")::String
    if format == "csv"
        table = nothing
        for key in (:dataframe, "dataframe", :summary_table, "summary_table")
            if haskey(scenario_results, key)
                table = scenario_results[key]
                break
            end
        end
        if table isa SummaryTable
            open(output_filename, "w") do io
                println(io, "Scenario,TotalCost,TotalQALYs,CostPerQALY,HospitalMargin,Quality,PatientAccess")
                for i in 1:length(table.Scenario)
                    println(io, join([
                        _csv_field(table.Scenario[i]),
                        table.TotalCost[i],
                        table.TotalQALYs[i],
                        table.CostPerQALY[i],
                        table.HospitalMargin[i],
                        table.Quality[i],
                        table.PatientAccess[i]
                    ], ","))
                end
            end
        end
    elseif format == "json"
        open(output_filename, "w") do io
            _write_json(io, scenario_results)
        end
    end
    return output_filename
end

# Quote a string field for CSV, escaping embedded quotes per RFC 4180.
function _csv_field(s::AbstractString)::String
    if occursin(',', s) || occursin('"', s) || occursin('\n', s) || occursin('\r', s)
        return "\"" * replace(s, "\"" => "\"\"") * "\""
    end
    return s
end

# Minimal JSON serialiser (no external deps)
function _json_escape(s::AbstractString)::String
    buf = IOBuffer()
    for c in s
        if c == '"';        write(buf, "\\\"")
        elseif c == '\\';   write(buf, "\\\\")
        elseif c == '\b';   write(buf, "\\b")
        elseif c == '\f';   write(buf, "\\f")
        elseif c == '\n';   write(buf, "\\n")
        elseif c == '\r';   write(buf, "\\r")
        elseif c == '\t';   write(buf, "\\t")
        elseif UInt32(c) < 0x20
            write(buf, @sprintf("\\u%04x", UInt32(c)))
        else
            write(buf, c)
        end
    end
    return String(take!(buf))
end

_write_json(io::IO, v::AbstractString) = print(io, "\"", _json_escape(v), "\"")
_write_json(io::IO, v::Bool) = print(io, v ? "true" : "false")
_write_json(io::IO, v::Number) = print(io, v)
_write_json(io::IO, v::Nothing) = print(io, "null")
function _write_json(io::IO, v::AbstractVector)
    print(io, "[")
    for (i, item) in enumerate(v)
        i > 1 && print(io, ",")
        _write_json(io, item)
    end
    print(io, "]")
end
function _write_json(io::IO, v::AbstractDict)
    print(io, "{")
    for (i, (k, val)) in enumerate(v)
        i > 1 && print(io, ",")
        _write_json(io, string(k))
        print(io, ":")
        _write_json(io, val)
    end
    print(io, "}")
end
_write_json(io::IO, v) = print(io, "\"", _json_escape(string(v)), "\"")

end  # module
