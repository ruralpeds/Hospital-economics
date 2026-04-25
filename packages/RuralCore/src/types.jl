"""
    CountyKey

Wrapper around a 5-digit FIPS code string for type safety.
"""
struct CountyKey
    fips::String

    function CountyKey(fips::String)
        length(fips) == 5 || throw(DataValidationError("FIPS code must be 5 digits, got $(length(fips))"))
        all(isdigit, fips) || throw(DataValidationError("FIPS code must contain only digits"))
        new(fips)
    end
end

Base.show(io::IO, k::CountyKey) = print(io, "CountyKey(\"$(k.fips)\")")

"""
    TimeKey

Wrapper for a specific time period (typically a year).
"""
struct TimeKey
    year::Int

    function TimeKey(year::Int)
        1900 <= year <= 2100 || throw(DomainValidationError("year", string(year), "1900 ≤ year ≤ 2100", "Invalid year"))
        new(year)
    end
end

Base.show(io::IO, k::TimeKey) = print(io, "TimeKey($(k.year))")

"""
    CountyYearKey

Combined geographic and temporal identifier.
"""
struct CountyYearKey
    county::CountyKey
    time::TimeKey
end

Base.show(io::IO, k::CountyYearKey) = print(io, "CountyYearKey(\"$(k.county.fips)\", $(k.time.year))")

# Helper functions
function state_fips(county_key::CountyKey)::String
    first(county_key.fips, 2)
end

function county_fips(county_key::CountyKey)::String
    last(county_key.fips, 3)
end

# Enums for hospital types and sizes
@enum HospitalType begin
    CRITICAL_ACCESS
    RURAL_CLINIC
    REGIONAL_MEDICAL_CENTER
    SPECIALTY_HOSPITAL
end

@enum FacilitySize begin
    VERY_SMALL    # < 50 beds
    SMALL         # 50-99 beds
    MEDIUM        # 100-249 beds
    LARGE         # 250-399 beds
    VERY_LARGE    # 400+ beds
end

"""
    PayerCategory

Categories of insurance payers in payer mix.
"""
@enum PayerCategory begin
    MEDICARE
    MEDICAID
    COMMERCIAL
    SELF_PAY
    OTHER
end

"""
    PayerMix

Distribution of patient payers.
Proportions must sum to 1.0 ± 0.01 (allowing for rounding).
"""
struct PayerMix
    medicare::Float64
    medicaid::Float64
    commercial::Float64
    self_pay::Float64
    other::Float64

    function PayerMix(m::Number, md::Number, c::Number, s::Number, o::Number)
        total = m + md + c + s + o
        0.99 <= total <= 1.01 || throw(
            DomainValidationError("payer_mix", string(total), "sum ≈ 1.0",
                "Payer mix proportions must sum to 1.0, got $total")
        )
        new(Float64(m), Float64(md), Float64(c), Float64(s), Float64(o))
    end
end

"""
    Hospital

Clinical facility with geographic and operational metadata.
"""
struct Hospital
    id::String
    name::String
    county::CountyKey
    hospital_type::HospitalType
    beds::Int
    payer_mix::PayerMix
    is_critical_access::Bool

    function Hospital(id::String, name::String, county::CountyKey,
                     htype::HospitalType, beds::Int, payer_mix::PayerMix,
                     is_critical::Bool = false)
        isempty(id) && throw(DataValidationError("hospital id cannot be empty"))
        isempty(name) && throw(DataValidationError("hospital name cannot be empty"))
        beds > 0 || throw(DomainValidationError("beds", string(beds), "beds > 0", "Hospital must have ≥1 bed"))
        new(id, name, county, htype, beds, payer_mix, is_critical)
    end
end

"""
    County

Geographic county with demographics.
"""
struct County
    key::CountyKey
    name::String
    state::String
    population::Int
    rural_code::Int  # RUCA code
end

"""
    Region

Multi-county region for aggregated analysis.
"""
struct Region
    id::String
    name::String
    counties::Vector{CountyKey}
end

"""
    MetricDomain

Clinical or operational domain for quality metrics.
"""
@enum MetricDomain begin
    MORTALITY
    SAFETY
    READMISSION
    TIMELINESS
    EFFECTIVENESS
    EFFICIENCY
    EQUITY
end

"""
    QualityMetric

Clinical quality or performance metric with benchmarks.
"""
struct QualityMetric
    id::String
    name::String
    domain::MetricDomain
    value::Float64
    benchmark::Float64
    percentile::Union{Int, Nothing}  # Facility percentile vs peers
end

"""
    ChapterMeta

Metadata for educational chapters/textbooks.
"""
struct ChapterMeta
    id::String
    title::String
    description::String
    author::String
    created_at::DateTime
    updated_at::DateTime
    version::String
end
