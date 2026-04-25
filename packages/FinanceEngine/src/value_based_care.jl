"""
    value_based_care.jl — CMS value-based purchasing calculations

Implements quality scoring, efficiency measurement, combined value scores,
quality-adjusted life years (QALYs), and readmission penalty calculations
aligned with CMS Hospital Value-Based Purchasing (VBP) and Hospital
Readmissions Reduction Program (HRRP) methodologies.
"""

# ── Value Score ──────────────────────────────────────────────────────────────

"""
    value_score(quality::Real, efficiency::Real;
                quality_weight::Real=0.5) -> Float64

Compute a combined value score from quality and efficiency components,
as used in CMS Hospital Value-Based Purchasing.

# Arguments
- `quality`: Quality component score, typically in [0, 100].
- `efficiency`: Efficiency component score, typically in [0, 100].
- `quality_weight`: Weight assigned to quality (0 to 1); efficiency gets `1 - quality_weight`.

# Returns
Weighted composite value score.

# Example
```julia
value_score(82.0, 75.0; quality_weight=0.6)
# => 0.6 × 82 + 0.4 × 75 = 79.2
```
"""
function value_score(quality::Real, efficiency::Real;
                     quality_weight::Real=0.5)
    0.0 <= quality_weight <= 1.0 || throw(
        DomainValidationError("quality_weight", string(quality_weight),
            "0 ≤ quality_weight ≤ 1",
            "Quality weight must be between 0 and 1")
    )
    isfinite(quality) || throw(
        CalculationError("quality score is not finite: $quality")
    )
    isfinite(efficiency) || throw(
        CalculationError("efficiency score is not finite: $efficiency")
    )

    efficiency_weight = 1.0 - quality_weight
    return quality_weight * quality + efficiency_weight * efficiency
end

# ── Quality-Adjusted Life Years ──────────────────────────────────────────────

"""
    qalys(life_years::Real, utility_weight::Real) -> Float64

Compute quality-adjusted life years (QALYs).

QALY = life_years × utility_weight, where utility_weight represents
health-related quality of life on a 0–1 scale (0 = death, 1 = perfect health).

# Arguments
- `life_years`: Number of life years (must be non-negative).
- `utility_weight`: Health utility weight, in [0, 1].

# Returns
QALY value.

# Example
```julia
qalys(10.0, 0.85)  # => 8.5 QALYs
```
"""
function qalys(life_years::Real, utility_weight::Real)
    life_years >= 0 || throw(
        DomainValidationError("life_years", string(life_years), "life_years ≥ 0",
            "Life years cannot be negative")
    )
    0.0 <= utility_weight <= 1.0 || throw(
        DomainValidationError("utility_weight", string(utility_weight),
            "0 ≤ utility_weight ≤ 1",
            "Utility weight must be between 0 (death) and 1 (perfect health)")
    )
    return life_years * utility_weight
end

# ── Quality Score (Weighted Composite) ───────────────────────────────────────

"""
    quality_score(measures::Vector{<:Real}, weights::Vector{<:Real}) -> Float64

Compute a weighted composite quality score from individual quality measures.

# Arguments
- `measures`: Vector of individual quality measure scores.
- `weights`: Vector of weights (must be same length as `measures`;
  each weight ≥ 0; weights are normalized internally to sum to 1).

# Returns
Weighted average quality score.

# Example
```julia
# 3 measures: mortality (85), readmission (70), patient experience (90)
quality_score([85.0, 70.0, 90.0], [0.25, 0.25, 0.50])
# => 0.25×85 + 0.25×70 + 0.50×90 = 83.75
```
"""
function quality_score(measures::Vector{<:Real}, weights::Vector{<:Real})
    length(measures) == length(weights) || throw(
        DataValidationError("measures and weights must have equal length; " *
            "got $(length(measures)) and $(length(weights))")
    )
    isempty(measures) && throw(
        DataValidationError("measures must not be empty")
    )
    all(w -> w >= 0, weights) || throw(
        DomainValidationError("weights", string(weights), "all weights ≥ 0",
            "Quality measure weights cannot be negative")
    )
    total_weight = sum(weights)
    total_weight > 0 || throw(
        DomainValidationError("weights", string(total_weight), "sum(weights) > 0",
            "Total weight must be positive")
    )

    return sum(Float64.(measures) .* Float64.(weights)) / total_weight
end

# ── Efficiency Score ─────────────────────────────────────────────────────────

"""
    efficiency_score(cost_per_case::Real, benchmark::Real) -> Float64

Compute a cost-efficiency score relative to a benchmark.

Score = benchmark / cost_per_case × 100

A score above 100 means more efficient than benchmark (lower cost);
below 100 means less efficient.

# Arguments
- `cost_per_case`: Hospital's average cost per case (must be positive).
- `benchmark`: Benchmark cost per case (must be positive).

# Returns
Efficiency score (100 = at benchmark).

# Example
```julia
efficiency_score(8500.0, 9000.0)  # => 105.88 (more efficient than benchmark)
efficiency_score(10000.0, 9000.0) # => 90.0   (less efficient)
```
"""
function efficiency_score(cost_per_case::Real, benchmark::Real)
    cost_per_case > 0 || throw(
        DomainValidationError("cost_per_case", string(cost_per_case),
            "cost_per_case > 0",
            "Cost per case must be positive")
    )
    benchmark > 0 || throw(
        DomainValidationError("benchmark", string(benchmark),
            "benchmark > 0",
            "Benchmark cost must be positive")
    )
    return (benchmark / cost_per_case) * 100.0
end

# ── Readmission Penalty ─────────────────────────────────────────────────────

"""
    readmission_penalty(observed_rate::Real, expected_rate::Real,
                        base_payment::Real;
                        max_penalty_pct::Real=0.03) -> Float64

Compute an HRRP-style readmission penalty.

If the observed readmission rate exceeds the expected rate, the hospital
receives a payment reduction. The excess readmission ratio (ERR) determines
the penalty magnitude, capped at `max_penalty_pct` of base payment.

ERR = observed_rate / expected_rate
Penalty = min(ERR - 1.0, max_penalty_pct) × base_payment  (if ERR > 1)

# Arguments
- `observed_rate`: Hospital's actual 30-day readmission rate (0 to 1).
- `expected_rate`: Risk-adjusted expected readmission rate (0 to 1; must be positive).
- `base_payment`: Total base DRG payments subject to penalty (must be positive).
- `max_penalty_pct`: Maximum penalty as fraction of base payment (default 3%).

# Returns
Penalty amount in dollars. Returns 0.0 if observed ≤ expected.

# Example
```julia
# Hospital has 18% readmission rate vs 15% expected, on \$10M base
readmission_penalty(0.18, 0.15, 10_000_000)
# ERR = 1.20, excess = 0.20 → penalty = min(0.20, 0.03) × 10M = \$300,000
```
"""
function readmission_penalty(observed_rate::Real, expected_rate::Real,
                             base_payment::Real;
                             max_penalty_pct::Real=0.03)
    0.0 <= observed_rate <= 1.0 || throw(
        DomainValidationError("observed_rate", string(observed_rate),
            "0 ≤ observed_rate ≤ 1",
            "Observed readmission rate must be between 0 and 1")
    )
    expected_rate > 0 || throw(
        DomainValidationError("expected_rate", string(expected_rate),
            "expected_rate > 0",
            "Expected readmission rate must be positive")
    )
    expected_rate <= 1.0 || throw(
        DomainValidationError("expected_rate", string(expected_rate),
            "expected_rate ≤ 1",
            "Expected readmission rate cannot exceed 1")
    )
    base_payment > 0 || throw(
        DomainValidationError("base_payment", string(base_payment),
            "base_payment > 0",
            "Base payment must be positive")
    )
    max_penalty_pct >= 0 || throw(
        DomainValidationError("max_penalty_pct", string(max_penalty_pct),
            "max_penalty_pct ≥ 0",
            "Maximum penalty percentage cannot be negative")
    )

    err = observed_rate / expected_rate

    # No penalty if performing at or below expected rate
    if err <= 1.0
        return 0.0
    end

    excess = err - 1.0
    penalty_pct = min(excess, max_penalty_pct)
    return penalty_pct * base_payment
end
