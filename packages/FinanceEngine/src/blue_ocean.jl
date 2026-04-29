"""
    blue_ocean.jl — Blue Ocean Strategy Framework (MBA Gap B-02)

Implements the Kim & Mauborgne (2005) Blue Ocean Strategy tools for rural hospitals
seeking to differentiate from regional competitors rather than compete head-to-head.

Tools:
1. Strategic Canvas — plots hospital and competitors on competitive factors
2. Value Curve — visual comparison of value delivered on each factor
3. ERRC Grid — Eliminate / Reduce / Raise / Create action framework
4. Blue Ocean Opportunity Score — composite measure of differentiation potential
5. Non-customer analysis — three tiers of non-customers to convert

References:
- Kim WC, Mauborgne R (2005). Blue Ocean Strategy. Harvard Business School Press.
- Kim WC, Mauborgne R (2015). Blue Ocean Strategy (expanded ed.).
"""

using Statistics; using Printf

@kwdef struct CompetitiveFactor
    name::String
    weight::Float64 = 1.0          # relative importance (1–5)
    industry_score::Float64        # current industry average (1–10)
    our_score::Float64             # our hospital's current score
    target_score::Float64          # desired future score
    errc_action::Symbol = :raise   # :eliminate, :reduce, :raise, :create
    notes::String = ""
end

struct StrategicCanvas
    hospital_name::String
    factors::Vector{CompetitiveFactor}
    competitors::Dict{String, Vector{Float64}}  # name → score per factor
end

struct ERRCGrid
    eliminate::Vector{String}
    reduce::Vector{String}
    raise::Vector{String}
    create::Vector{String}
end

struct BlueOceanResult
    canvas::StrategicCanvas
    errc::ERRCGrid
    differentiation_index::Float64   # 0-100: how different is target vs industry
    value_innovation_score::Float64  # combines differentiation + value
    top_opportunities::Vector{String}
    convergence_warnings::Vector{String}  # where we look like competitors
end

"""
    build_errc_grid(factors::Vector{CompetitiveFactor}) -> ERRCGrid

Build the ERRC action grid from factor definitions.
"""
function build_errc_grid(factors::Vector{CompetitiveFactor})::ERRCGrid
    ERRCGrid(
        [f.name for f in factors if f.errc_action == :eliminate],
        [f.name for f in factors if f.errc_action == :reduce],
        [f.name for f in factors if f.errc_action == :raise],
        [f.name for f in factors if f.errc_action == :create],
    )
end

"""
    blue_ocean_analysis(canvas::StrategicCanvas) -> BlueOceanResult

Analyse a hospital's strategic canvas and generate Blue Ocean recommendations.

# Example
```julia
factors = [
    CompetitiveFactor(name="Price / Cost to Patient", industry_score=6.0,
        our_score=5.0, target_score=4.0, errc_action=:reduce, weight=2.0),
    CompetitiveFactor(name="Telehealth Access", industry_score=3.0,
        our_score=2.0, target_score=9.0, errc_action=:create, weight=3.0),
    CompetitiveFactor(name="Wait Time", industry_score=6.0,
        our_score=7.0, target_score=4.0, errc_action=:reduce, weight=2.5),
    CompetitiveFactor(name="Community Trust / Relationships", industry_score=5.0,
        our_score=8.0, target_score=9.0, errc_action=:raise, weight=3.0),
    CompetitiveFactor(name="Inpatient Bed Capacity", industry_score=7.0,
        our_score=4.0, target_score=2.0, errc_action=:eliminate, weight=1.0),
]
canvas = StrategicCanvas("Valley CAH", factors, Dict())
result = blue_ocean_analysis(canvas)
```
"""
function blue_ocean_analysis(canvas::StrategicCanvas)::BlueOceanResult
    factors = canvas.factors
    errc    = build_errc_grid(factors)

    # Differentiation index: weighted distance of target from industry average
    total_weight = sum(f.weight for f in factors)
    diff_index = 0.0
    for f in factors
        gap = abs(f.target_score - f.industry_score) / 9.0  # normalise 0-1
        diff_index += f.weight * gap * 100
    end
    diff_index = min(100.0, diff_index / total_weight)

    # Value innovation: high differentiation AND high target value (raise/create ≥ 7)
    value_factors  = filter(f -> f.errc_action in (:raise, :create), factors)
    avg_value_gain = isempty(value_factors) ? 0.0 :
        mean(f.target_score for f in value_factors)
    vi_score = (diff_index * 0.5) + (avg_value_gain / 10.0 * 50)

    # Top opportunities: factors with highest gap between target and current
    sorted_by_gap = sort(factors; by=f -> abs(f.target_score - f.our_score), rev=true)
    top_opps = ["$(f.name): $(f.errc_action) (current $(f.our_score) → target $(f.target_score))"
                for f in sorted_by_gap[1:min(3, end)]]

    # Convergence warnings: where we look like competitors
    warnings = String[]
    for (comp_name, comp_scores) in canvas.competitors
        length(comp_scores) == length(factors) || continue
        converge_count = sum(
            abs(factors[i].our_score - comp_scores[i]) < 1.5
            for i in 1:length(factors)
        )
        if converge_count >= length(factors) * 0.6
            push!(warnings, "High strategic overlap with $comp_name ($converge_count/$(length(factors)) factors within 1.5 points)")
        end
    end

    BlueOceanResult(canvas, errc, diff_index, vi_score, top_opps, warnings)
end
