# health_economics/QALY.jl — Quality-Adjusted Life Years

"""
    QALY Calculation Framework

QALY (Quality-Adjusted Life Year) combines:
- Life years gained (quantity)
- Health utility/quality weights (quality)
= QALYs gained

Standard utility weights: 1.0 (perfect health) to 0.0 (death)
"""

"""
    calculate_qaly(life_years::Float64, utility::Float64)::Float64

Calculate QALYs from life years and utility weight.

# Arguments
- `life_years::Float64` — Years of life gained
- `utility::Float64` — Health utility weight (0.0-1.0)

# Example
```julia
# 1 year in perfect health = 1.0 QALY
calculate_qaly(1.0, 1.0)  # 1.0

# 1 year with moderate disability = 0.7 QALY
calculate_qaly(1.0, 0.7)  # 0.7
```
"""
function calculate_qaly(life_years::Float64, utility::Float64)::Float64
    @assert life_years >= 0.0 "Life years must be non-negative"
    @assert 0.0 <= utility <= 1.0 "Utility must be between 0 and 1"
    return life_years * utility
end

"""
    qaly_from_utility(baseline_utility::Float64, final_utility::Float64, 
                      follow_up_years::Float64)::Float64

Calculate QALYs gained by improving health state over time.

# Arguments
- `baseline_utility::Float64` — Starting health state utility
- `final_utility::Float64` — Ending health state utility
- `follow_up_years::Float64` — Duration of follow-up

# Example
```julia
# Improvement from 0.7 (moderate disability) to 0.9 (mild disability) over 5 years
qaly_from_utility(0.7, 0.9, 5.0)  # 5.0 * (0.9 - 0.7) = 1.0 QALY gained
```
"""
function qaly_from_utility(baseline_utility::Float64, final_utility::Float64, 
                          follow_up_years::Float64)::Float64
    @assert baseline_utility >= 0.0 && baseline_utility <= 1.0
    @assert final_utility >= 0.0 && final_utility <= 1.0
    @assert follow_up_years >= 0.0
    
    utility_gain = final_utility - baseline_utility
    return follow_up_years * utility_gain
end

"""
    qaly_gain(intervention_qaly::Float64, control_qaly::Float64)::Float64

Calculate incremental QALY gain (intervention vs. control).
"""
function qaly_gain(intervention_qaly::Float64, control_qaly::Float64)::Float64
    intervention_qaly - control_qaly
end

# ═══════════════════════════════════════════════════════════════
# UTILITY WEIGHTING SYSTEMS
# ═══════════════════════════════════════════════════════════════

"""
    SimpleUtility

Simple categorical utility weights.
"""
struct SimpleUtility <: QALYUtility
    weights::Dict{String, Float64}
    
    function SimpleUtility(;
        perfect = 1.0,
        mild = 0.9,
        moderate = 0.7,
        severe = 0.4,
        very_severe = 0.1,
        death = 0.0
    )
        new(Dict(
            "perfect" => perfect,
            "mild" => mild,
            "moderate" => moderate,
            "severe" => severe,
            "very_severe" => very_severe,
            "death" => death
        ))
    end
end

"""
    EQ5DUtility

EQ-5D-5L utility weighting (simplified UK algorithm).
EQ-5D measures 5 dimensions: mobility, self-care, usual activities, pain, anxiety.
"""
struct EQ5DUtility <: QALYUtility
    # Simplified: in real application, use official EQ-5D-5L algorithms
    base_utility::Float64
    dimension_weights::Dict{String, Float64}
    
    function EQ5DUtility()
        new(
            1.0,  # Perfect health baseline
            Dict(
                "mobility" => 0.05,
                "self_care" => 0.10,
                "usual_activities" => 0.08,
                "pain_discomfort" => 0.12,
                "anxiety_depression" => 0.08
            )
        )
    end
end

"""
    get_utility(utility_system::QALYUtility, state::String)::Float64

Get utility weight for a health state.
"""
function get_utility(utility_system::SimpleUtility, state::String)::Float64
    get(utility_system.weights, state, 0.5)
end

function get_utility(utility_system::EQ5DUtility, state::String)::Float64
    # Simplified: subtract dimension penalties
    # Real EQ-5D uses complex algorithm
    penalty = get(utility_system.dimension_weights, state, 0.05)
    return max(0.0, utility_system.base_utility - penalty)
end

# ═══════════════════════════════════════════════════════════════
# QUALITY METRICS
# ═══════════════════════════════════════════════════════════════

"""
    quality_adjusted_survival(;
        cohort_size::Int,
        annual_mortality::Float64,
        annual_utility::Float64,
        years_follow_up::Int
    )::Tuple{Float64, Float64, Float64}

Calculate QALYs from survival with quality weighting.

Returns: (total_qalys, life_years_gained, quality_adjustment_factor)
"""
function quality_adjusted_survival(;
    cohort_size::Int,
    annual_mortality::Float64,
    annual_utility::Float64,
    years_follow_up::Int
)::Tuple{Float64, Float64, Float64}
    
    # Cumulative survival
    survival_prob = (1 - annual_mortality) ^ years_follow_up
    survivors = cohort_size * survival_prob
    life_years = survivors * years_follow_up
    qalys = life_years * annual_utility
    
    quality_factor = annual_utility
    
    return (qalys, life_years, quality_factor)
end

"""
    disability_adjusted_life_years(yll::Float64, yld::Float64)::Float64

Calculate DALY (Disability-Adjusted Life Year).

DALY = Years of Life Lost (YLL) + Years Lived with Disability (YLD)
Used in Global Burden of Disease studies.
"""
function disability_adjusted_life_years(yll::Float64, yld::Float64)::Float64
    yll + yld
end

"""
    health_adjusted_life_expectancy(;
        age::Float64,
        life_expectancy::Float64,
        health_utility::Float64
    )::Float64

Calculate HALE (Health-Adjusted Life Expectancy).

HALE = Life Expectancy × Average Health Utility from age to death
"""
function health_adjusted_life_expectancy(;
    age::Float64,
    life_expectancy::Float64,
    health_utility::Float64
)::Float64
    remaining_life = life_expectancy - age
    hale = remaining_life * health_utility
    return max(0.0, hale)
end
