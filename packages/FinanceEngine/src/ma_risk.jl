"""
    ma_risk.jl — Medicare Advantage risk adjustment (CMS HCC v28)

Parses HCC diagnoses, calculates member-level RAF scores, and aggregates cohort risk.
"""

using JSON3, Statistics, DataFrames

# ═══════════════════════════════════════════════════════════════════════════
# A-06: Medicare Advantage Risk Adjustment
# ═══════════════════════════════════════════════════════════════════════════

@kwdef struct HCCDiagnosis
    icd10_code::String
    description::String
    hcc_category::Int
    risk_factor::Float64
end

@kwdef struct MARAFScore
    member_id::String
    age::Int
    sex::String  # "M" or "F"
    hcc_count::Int
    diagnoses::Vector{String}
    age_sex_factor::Float64
    hcc_risk_factors::Vector{Float64}
    combined_raf::Float64
    risk_band::String  # "low", "average", "high", "very_high"
end

"""
    parse_hcc_coefficients(fixture_path::String) -> Dict{String, Float64}

Load CMS HCC v28 coefficients from JSON fixture.

Returns Dict mapping HCC code (e.g., "HCC001") to risk factor coefficient.
"""
function parse_hcc_coefficients(fixture_path::String)::Dict{String, Float64}
    if !isfile(fixture_path)
        throw(ArgumentError("HCC fixture file not found: $fixture_path"))
    end

    json_str = read(fixture_path, String)
    data = JSON3.read(json_str)

    coefficients = Dict{String, Float64}()
    if haskey(data, "coefficients")
        for (hcc_code, coeff) in data["coefficients"]
            coefficients[String(hcc_code)] = Float64(coeff)
        end
    end

    return coefficients
end

"""
    calculate_member_raf(age::Int, sex::String, diagnoses::Vector{String};
                         hcc_coefficients::Dict) -> MARAFScore

Calculate Medicare Advantage RAF score for a member.

RAF = base(age,sex) + Σ HCC_i

Risk bands:
  - low: RAF < 0.8
  - average: 0.8 ≤ RAF ≤ 1.2
  - high: 1.2 < RAF ≤ 1.5
  - very_high: RAF > 1.5
"""
function calculate_member_raf(member_id::String, age::Int, sex::String,
                              diagnoses::Vector{String};
                              hcc_coefficients::Dict{String, Float64})::MARAFScore

    # Age-sex factor (simplified; real CMS uses detailed tables)
    age_sex_factors = Dict(
        ("M", 0) => 0.0, ("M", 1) => 0.2, ("M", 2) => 0.4, ("M", 3) => 0.6,
        ("F", 0) => 0.0, ("F", 1) => 0.15, ("F", 2) => 0.35, ("F", 3) => 0.55
    )
    age_group = min(3, div(age, 30))  # 0-29, 30-59, 60-89, 90+
    age_sex_factor = get(age_sex_factors, (sex, age_group), 0.0)

    # HCC risk factors
    hcc_risk_factors = Float64[]
    hcc_count = 0
    for diag in diagnoses
        hcc_code = "HCC" * string(lpad(parse(Int, diag[6:end]), 3, "0"))
        if haskey(hcc_coefficients, hcc_code)
            push!(hcc_risk_factors, hcc_coefficients[hcc_code])
            hcc_count += 1
        end
    end

    # Combined RAF (with interactions for certain disease pairs)
    combined_raf = age_sex_factor + sum(hcc_risk_factors; init=0.0) + 1.0  # +1.0 for baseline

    # Risk band classification
    risk_band = if combined_raf < 0.8
        "low"
    elseif combined_raf <= 1.2
        "average"
    elseif combined_raf <= 1.5
        "high"
    else
        "very_high"
    end

    return MARAFScore(
        member_id = member_id,
        age = age,
        sex = sex,
        hcc_count = hcc_count,
        diagnoses = diagnoses,
        age_sex_factor = age_sex_factor,
        hcc_risk_factors = hcc_risk_factors,
        combined_raf = combined_raf,
        risk_band = risk_band
    )
end

"""
    aggregate_cohort_raf(members::Vector{MARAFScore};
                        pop_weights::Union{Vector{Float64}, Nothing}=nothing) -> Dict

Aggregate member-level RAFs to cohort statistics.

Returns Dict with:
  - mean_raf, std_raf, percentiles, capitation_impact
  - risk_band_distribution (low/average/high/very_high counts)
"""
function aggregate_cohort_raf(members::Vector{MARAFScore};
                              pop_weights::Union{Vector{Float64}, Nothing}=nothing,
                              annual_capitation::Float64=10_000.0)::Dict

    if isempty(members)
        return Dict(
            "error" => "No members provided",
            "mean_raf" => 0.0,
            "std_raf" => 0.0,
            "percentiles" => Dict(),
            "capitation_impact" => Dict()
        )
    end

    rafs = [m.combined_raf for m in members]
    weights = isnothing(pop_weights) ? ones(length(members)) / length(members) :
              pop_weights ./ sum(pop_weights)

    mean_raf = sum(rafs .* weights)
    variance = sum(weights .* (rafs .- mean_raf).^2)
    std_raf = sqrt(variance)

    # Percentiles
    sorted_rafs = sort(rafs)
    percentiles = Dict(
        "p10" => sorted_rafs[max(1, div(length(sorted_rafs), 10))],
        "p25" => sorted_rafs[max(1, div(length(sorted_rafs), 4))],
        "p50" => sorted_rafs[max(1, div(length(sorted_rafs), 2))],
        "p75" => sorted_rafs[max(1, 3 * div(length(sorted_rafs), 4))],
        "p90" => sorted_rafs[max(1, 9 * div(length(sorted_rafs), 10))]
    )

    # Risk band distribution
    risk_band_dist = Dict(
        "low" => count(m -> m.risk_band == "low", members),
        "average" => count(m -> m.risk_band == "average", members),
        "high" => count(m -> m.risk_band == "high", members),
        "very_high" => count(m -> m.risk_band == "very_high", members)
    )

    # Capitation impact (how actual cohort revenue differs from benchmark)
    benchmark_capitation = annual_capitation * 1.0  # Benchmark RAF = 1.0
    actual_capitation = annual_capitation * mean_raf
    capitation_impact = Dict(
        "benchmark_annual" => benchmark_capitation * length(members),
        "actual_annual" => actual_capitation * length(members),
        "difference" => (actual_capitation - benchmark_capitation) * length(members),
        "pct_difference" => (mean_raf - 1.0) * 100.0
    )

    return Dict(
        "member_count" => length(members),
        "mean_raf" => mean_raf,
        "std_raf" => std_raf,
        "percentiles" => percentiles,
        "risk_band_distribution" => risk_band_dist,
        "capitation_impact" => capitation_impact
    )
end
