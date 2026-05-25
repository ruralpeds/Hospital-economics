using Statistics

# Altman Z'' Score — Modified for Services/Healthcare
#
# The Altman Z'' model (1993 revision) removes the sales/total-assets ratio
# that penalises asset-light service firms. Coefficients: 6.56*X1 + 3.26*X2
# + 6.72*X3 + 1.05*X4. Zones: safe (>2.6), grey (1.1–2.6), distress (<1.1).

"""
    DistressInput

Input data for the Altman Z'' distress scoring model. All values in dollars.
"""
@kwdef struct DistressInput
    working_capital::Float64
    total_assets::Float64
    retained_earnings::Float64
    ebit::Float64
    book_equity::Float64
    total_liabilities::Float64
    revenue::Float64 = 0.0
end

"""
    DistressResult

Result of the Altman Z'' distress score calculation.

Fields:
- `z_score` — composite Z'' score
- `zone` — `:safe`, `:grey`, or `:distress`
- `component_scores` — Dict mapping component names to their weighted values
"""
@kwdef struct DistressResult
    z_score::Float64
    zone::Symbol
    component_scores::Dict{String,Float64}
end

function Base.show(io::IO, r::DistressResult)
    print(io, "DistressResult(z=$(round(r.z_score, digits=2)), zone=$(r.zone))")
end

"""
    calculate_altman_z(input::DistressInput) -> DistressResult

Compute the Altman Z'' score (services-sector variant).

Z'' = 6.56*X1 + 3.26*X2 + 6.72*X3 + 1.05*X4

where:
- X1 = Working Capital / Total Assets
- X2 = Retained Earnings / Total Assets
- X3 = EBIT / Total Assets
- X4 = Book Equity / Total Liabilities
"""
function calculate_altman_z(input::DistressInput)::DistressResult
    input.total_assets > 0.0 || error("total_assets must be positive; got $(input.total_assets)")
    input.total_liabilities > 0.0 || error("total_liabilities must be positive; got $(input.total_liabilities)")

    x1 = input.working_capital / input.total_assets
    x2 = input.retained_earnings / input.total_assets
    x3 = input.ebit / input.total_assets
    x4 = input.book_equity / input.total_liabilities

    w1, w2, w3, w4 = 6.56, 3.26, 6.72, 1.05

    z = w1 * x1 + w2 * x2 + w3 * x3 + w4 * x4

    zone = if z > 2.6
        :safe
    elseif z < 1.1
        :distress
    else
        :grey
    end

    components = Dict{String,Float64}(
        "x1_working_capital_ta" => w1 * x1,
        "x2_retained_earnings_ta" => w2 * x2,
        "x3_ebit_ta" => w3 * x3,
        "x4_equity_tl" => w4 * x4,
    )

    return DistressResult(
        z_score = z,
        zone = zone,
        component_scores = components,
    )
end

"""
    estimate_distress_timeline(z_scores::Vector{Float64}, years::Vector{Float64}) -> NamedTuple

Project when the Z'' score will enter the distress zone (<1.1) using linear
regression on the provided historical series.

Returns a NamedTuple with:
- `slope` — annual rate of change in Z'' score
- `current_z` — most recent Z'' score
- `years_to_distress` — estimated years until Z'' < 1.1 (Inf if improving or already safe trend)
- `projected_z_1yr` — Z'' projected one year forward
"""
function estimate_distress_timeline(z_scores::Vector{Float64}, years::Vector{Float64})
    length(z_scores) >= 2 || error("at least 2 data points required for trend estimation")
    length(z_scores) == length(years) || error("z_scores and years must have equal length")

    n = length(z_scores)
    mean_y = mean(years)
    mean_z = mean(z_scores)

    numerator = sum((years[i] - mean_y) * (z_scores[i] - mean_z) for i in 1:n)
    denominator = sum((years[i] - mean_y)^2 for i in 1:n)

    slope = denominator > 0.0 ? numerator / denominator : 0.0
    intercept = mean_z - slope * mean_y

    current_z = z_scores[end]
    projected_z_1yr = slope * (years[end] + 1.0) + intercept

    distress_threshold = 1.1
    years_to_distress = if current_z < distress_threshold
        0.0  # already in distress
    elseif slope >= 0.0
        Inf  # not declining toward distress
    else
        (current_z - distress_threshold) / abs(slope)
    end

    return (
        slope = slope,
        current_z = current_z,
        years_to_distress = years_to_distress,
        projected_z_1yr = projected_z_1yr,
    )
end
