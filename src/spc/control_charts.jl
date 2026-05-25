# Statistical Process Control (SPC) chart suite
#
# Implements 11 SPC chart types following Montgomery "Introduction to
# Statistical Process Control" conventions, ported from the Rust
# cah-modeling crate (sci_quality::spc).
#
# Chart families:
#   Variable:       I-MR
#   Attribute:      p, u, c, np
#   Overdispersion: Laney p', Laney u'
#   Rare-event:     g, t
#   Time-weighted:  CUSUM, EWMA
#   Funnel plots:   proportion, rate

using Statistics

# ═══════════════════════════════════════════════════════════════════════
# Result structs
# ═══════════════════════════════════════════════════════════════════════

"""
    IMRResult

Individual and Moving Range (I-MR) chart result.

# Fields
- `center_line::Float64`  — X̄ (mean of individual values)
- `ucl::Float64`          — upper control limit for individuals chart
- `lcl::Float64`          — lower control limit for individuals chart
- `values::Vector{Float64}` — original individual values
- `mr_values::Vector{Float64}` — moving range values (length n-1)
- `mr_center::Float64`    — MR̄ (mean of moving ranges)
- `mr_ucl::Float64`       — upper control limit for MR chart
- `mr_lcl::Float64`       — lower control limit for MR chart (always 0)
- `signals::Vector{Int}`  — indices of out-of-control points on I chart
"""
struct IMRResult
    center_line::Float64
    ucl::Float64
    lcl::Float64
    values::Vector{Float64}
    mr_values::Vector{Float64}
    mr_center::Float64
    mr_ucl::Float64
    mr_lcl::Float64
    signals::Vector{Int}
end

"""
    PChartResult

Proportion defective (p) chart result with variable subgroup sizes.

# Fields
- `center_line::Float64`    — p̄ (overall proportion defective)
- `ucl::Vector{Float64}`    — per-point upper control limits
- `lcl::Vector{Float64}`    — per-point lower control limits
- `values::Vector{Float64}` — per-point proportion defective
- `signals::Vector{Int}`    — indices of out-of-control points
"""
struct PChartResult
    center_line::Float64
    ucl::Vector{Float64}
    lcl::Vector{Float64}
    values::Vector{Float64}
    signals::Vector{Int}
end

"""
    UChartResult

Defects per unit (u) chart result with variable subgroup sizes.

# Fields
- `center_line::Float64`    — ū (overall defects per unit)
- `ucl::Vector{Float64}`    — per-point upper control limits
- `lcl::Vector{Float64}`    — per-point lower control limits
- `values::Vector{Float64}` — per-point defects per unit
- `signals::Vector{Int}`    — indices of out-of-control points
"""
struct UChartResult
    center_line::Float64
    ucl::Vector{Float64}
    lcl::Vector{Float64}
    values::Vector{Float64}
    signals::Vector{Int}
end

"""
    CChartResult

Defect count (c) chart result for fixed-area/fixed-opportunity samples.

# Fields
- `center_line::Float64`    — c̄ (mean count)
- `ucl::Float64`            — upper control limit
- `lcl::Float64`            — lower control limit
- `values::Vector{Float64}` — observed counts (as Float64)
- `signals::Vector{Int}`    — indices of out-of-control points
"""
struct CChartResult
    center_line::Float64
    ucl::Float64
    lcl::Float64
    values::Vector{Float64}
    signals::Vector{Int}
end

"""
    NPChartResult

Count defective (np) chart result for fixed sample size.

# Fields
- `center_line::Float64`    — np̄ (mean count defective)
- `ucl::Float64`            — upper control limit
- `lcl::Float64`            — lower control limit
- `values::Vector{Float64}` — observed defective counts (as Float64)
- `signals::Vector{Int}`    — indices of out-of-control points
"""
struct NPChartResult
    center_line::Float64
    ucl::Float64
    lcl::Float64
    values::Vector{Float64}
    signals::Vector{Int}
end

"""
    LaneyResult

Laney p' or u' chart result with overdispersion adjustment.

# Fields
- `center_line::Float64`    — p̄ or ū
- `ucl::Vector{Float64}`    — adjusted per-point upper control limits
- `lcl::Vector{Float64}`    — adjusted per-point lower control limits
- `values::Vector{Float64}` — per-point proportions or rates
- `sigma_z::Float64`        — overdispersion multiplier (σ_Z)
- `signals::Vector{Int}`    — indices of out-of-control points
"""
struct LaneyResult
    center_line::Float64
    ucl::Vector{Float64}
    lcl::Vector{Float64}
    values::Vector{Float64}
    sigma_z::Float64
    signals::Vector{Int}
end

"""
    GChartResult

Geometric (g) chart result for counts between rare events.

# Fields
- `center_line::Float64`    — ḡ (mean count between events)
- `ucl::Float64`            — upper control limit
- `lcl::Float64`            — lower control limit
- `values::Vector{Float64}` — observed counts between events
- `signals::Vector{Int}`    — indices of out-of-control points
"""
struct GChartResult
    center_line::Float64
    ucl::Float64
    lcl::Float64
    values::Vector{Float64}
    signals::Vector{Int}
end

"""
    TChartResult

Time between events (t) chart result using log-normal transformation.

# Fields
- `center_line::Float64`    — center line on transformed scale (mean of ln(t))
- `ucl::Float64`            — upper control limit (back-transformed)
- `lcl::Float64`            — lower control limit (back-transformed)
- `values::Vector{Float64}` — original time-between values
- `transformed::Vector{Float64}` — ln-transformed values
- `signals::Vector{Int}`    — indices of out-of-control points
"""
struct TChartResult
    center_line::Float64
    ucl::Float64
    lcl::Float64
    values::Vector{Float64}
    transformed::Vector{Float64}
    signals::Vector{Int}
end

"""
    CUSUMResult

Two-sided CUSUM chart result.

# Fields
- `center_line::Float64`    — target value (μ₀)
- `ucl::Float64`            — decision interval h (upper)
- `lcl::Float64`            — decision interval -h (lower, for display)
- `values::Vector{Float64}` — original values
- `upper_cusum::Vector{Float64}` — upper CUSUM statistics (C⁺)
- `lower_cusum::Vector{Float64}` — lower CUSUM statistics (C⁻)
- `signals::Vector{Int}`    — indices where |C| exceeds h
"""
struct CUSUMResult
    center_line::Float64
    ucl::Float64
    lcl::Float64
    values::Vector{Float64}
    upper_cusum::Vector{Float64}
    lower_cusum::Vector{Float64}
    signals::Vector{Int}
end

"""
    EWMAResult

EWMA chart result.

# Fields
- `center_line::Float64`    — target value (μ₀)
- `ucl::Vector{Float64}`    — time-varying upper control limits
- `lcl::Vector{Float64}`    — time-varying lower control limits
- `values::Vector{Float64}` — original values
- `ewma::Vector{Float64}`   — EWMA statistics
- `signals::Vector{Int}`    — indices of out-of-control points
"""
struct EWMAResult
    center_line::Float64
    ucl::Vector{Float64}
    lcl::Vector{Float64}
    values::Vector{Float64}
    ewma::Vector{Float64}
    signals::Vector{Int}
end

"""
    FunnelResult

Funnel plot result for cross-sectional comparison of rates/proportions.

# Fields
- `center_line::Float64`    — overall target rate/proportion
- `ucl::Vector{Float64}`    — per-unit upper control limits (narrow with volume)
- `lcl::Vector{Float64}`    — per-unit lower control limits
- `values::Vector{Float64}` — per-unit observed rates/proportions
- `volumes::Vector{Float64}` — denominators (volume on x-axis)
- `signals::Vector{Int}`    — indices of units outside limits
"""
struct FunnelResult
    center_line::Float64
    ucl::Vector{Float64}
    lcl::Vector{Float64}
    values::Vector{Float64}
    volumes::Vector{Float64}
    signals::Vector{Int}
end

"""
    RunRuleViolation

A single Western Electric run-rule violation.

# Fields
- `index::Int`        — index of the triggering point
- `rule::Int`         — rule number (1–4)
- `description::String` — human-readable description
"""
struct RunRuleViolation
    index::Int
    rule::Int
    description::String
end

# ═══════════════════════════════════════════════════════════════════════
# Variable charts
# ═══════════════════════════════════════════════════════════════════════

"""
    calculate_imr(values::Vector{Float64}) -> IMRResult

Individual and Moving Range (I-MR) chart.

The individuals chart uses X̄ ± 3·MR̄/d₂ as control limits, where d₂ = 1.128
for a moving range of span 2. The MR chart has UCL = D₄·MR̄ (D₄ = 3.267
for n = 2) and LCL = 0.

Returns `nothing` if fewer than 2 observations are supplied.
"""
function calculate_imr(values::Vector{Float64})
    n = length(values)
    n < 2 && return nothing

    # Moving ranges (span 2)
    mr_values = [abs(values[i] - values[i-1]) for i in 2:n]

    x_bar = mean(values)
    mr_bar = mean(mr_values)

    # Constants for n=2 subgroups
    d2 = 1.128
    D4 = 3.267

    sigma_est = mr_bar / d2
    i_ucl = x_bar + 3.0 * sigma_est
    i_lcl = x_bar - 3.0 * sigma_est

    mr_ucl = D4 * mr_bar
    mr_lcl = 0.0

    # Signal detection on I chart
    signals = Int[]
    for i in 1:n
        if values[i] > i_ucl || values[i] < i_lcl
            push!(signals, i)
        end
    end

    return IMRResult(x_bar, i_ucl, i_lcl, values, mr_values,
                     mr_bar, mr_ucl, mr_lcl, signals)
end

# ═══════════════════════════════════════════════════════════════════════
# Attribute charts
# ═══════════════════════════════════════════════════════════════════════

"""
    calculate_p_chart(defectives::Vector{Int}, sample_sizes::Vector{Int}) -> PChartResult

P-chart for proportion defective with variable subgroup sizes.

Control limits are calculated per subgroup:
    UCL_i = p̄ + 3·√(p̄(1-p̄)/n_i)
    LCL_i = max(0, p̄ - 3·√(p̄(1-p̄)/n_i))

Returns `nothing` if inputs are empty or have mismatched lengths.
"""
function calculate_p_chart(defectives::Vector{Int}, sample_sizes::Vector{Int})
    n = length(defectives)
    (n == 0 || n != length(sample_sizes)) && return nothing

    total_defective = sum(defectives)
    total_inspected = sum(sample_sizes)
    total_inspected == 0 && return nothing

    p_bar = total_defective / total_inspected

    values = Float64[]
    ucl = Float64[]
    lcl = Float64[]
    signals = Int[]

    for i in 1:n
        ni = sample_sizes[i]
        pi = ni > 0 ? defectives[i] / ni : 0.0
        push!(values, pi)

        sigma_i = ni > 0 ? sqrt(p_bar * (1.0 - p_bar) / ni) : 0.0
        ui = p_bar + 3.0 * sigma_i
        li = max(0.0, p_bar - 3.0 * sigma_i)
        push!(ucl, ui)
        push!(lcl, li)

        if pi > ui || pi < li
            push!(signals, i)
        end
    end

    return PChartResult(p_bar, ucl, lcl, values, signals)
end

"""
    calculate_u_chart(defects::Vector{Int}, units::Vector{Int}) -> UChartResult

U-chart for defects per unit with variable inspection sizes.

Control limits are calculated per subgroup:
    UCL_i = ū + 3·√(ū/n_i)
    LCL_i = max(0, ū - 3·√(ū/n_i))

Returns `nothing` if inputs are empty or have mismatched lengths.
"""
function calculate_u_chart(defects::Vector{Int}, units::Vector{Int})
    n = length(defects)
    (n == 0 || n != length(units)) && return nothing

    total_defects = sum(defects)
    total_units = sum(units)
    total_units == 0 && return nothing

    u_bar = total_defects / total_units

    values = Float64[]
    ucl = Float64[]
    lcl = Float64[]
    signals = Int[]

    for i in 1:n
        ni = units[i]
        ui = ni > 0 ? defects[i] / ni : 0.0
        push!(values, ui)

        sigma_i = ni > 0 ? sqrt(u_bar / ni) : 0.0
        upper = u_bar + 3.0 * sigma_i
        lower = max(0.0, u_bar - 3.0 * sigma_i)
        push!(ucl, upper)
        push!(lcl, lower)

        if ui > upper || ui < lower
            push!(signals, i)
        end
    end

    return UChartResult(u_bar, ucl, lcl, values, signals)
end

"""
    calculate_c_chart(defects::Vector{Int}) -> CChartResult

C-chart for defect counts with fixed-size inspection units.

Control limits:
    UCL = c̄ + 3·√c̄
    LCL = max(0, c̄ - 3·√c̄)

Returns `nothing` if the input is empty.
"""
function calculate_c_chart(defects::Vector{Int})
    n = length(defects)
    n == 0 && return nothing

    c_bar = mean(Float64.(defects))
    sigma = sqrt(c_bar)
    ucl = c_bar + 3.0 * sigma
    lcl = max(0.0, c_bar - 3.0 * sigma)

    values = Float64.(defects)
    signals = Int[]
    for i in 1:n
        if values[i] > ucl || values[i] < lcl
            push!(signals, i)
        end
    end

    return CChartResult(c_bar, ucl, lcl, values, signals)
end

"""
    calculate_np_chart(defectives::Vector{Int}, sample_size::Int) -> NPChartResult

NP-chart for count defective with fixed sample size n.

Control limits:
    np̄ = mean(defective counts)
    p̄  = np̄ / n
    UCL = np̄ + 3·√(np̄·(1 - p̄))
    LCL = max(0, np̄ - 3·√(np̄·(1 - p̄)))

Returns `nothing` if the input is empty or sample_size ≤ 0.
"""
function calculate_np_chart(defectives::Vector{Int}, sample_size::Int)
    n = length(defectives)
    (n == 0 || sample_size <= 0) && return nothing

    np_bar = mean(Float64.(defectives))
    p_bar = np_bar / sample_size
    sigma = sqrt(np_bar * (1.0 - p_bar))
    ucl = np_bar + 3.0 * sigma
    lcl = max(0.0, np_bar - 3.0 * sigma)

    values = Float64.(defectives)
    signals = Int[]
    for i in 1:n
        if values[i] > ucl || values[i] < lcl
            push!(signals, i)
        end
    end

    return NPChartResult(np_bar, ucl, lcl, values, signals)
end

# ═══════════════════════════════════════════════════════════════════════
# Overdispersion-adjusted charts (Laney)
# ═══════════════════════════════════════════════════════════════════════

"""
    calculate_laney_p_prime(defectives::Vector{Int}, sample_sizes::Vector{Int}) -> LaneyResult

Laney p' chart — adjusts standard p-chart limits for overdispersion.

Steps:
1. Compute p̄ and standard Z-scores: Z_i = (p_i - p̄) / √(p̄(1-p̄)/n_i)
2. Compute σ_Z as the standard deviation of the Z-scores (between-subgroup variation)
3. Adjusted limits: p̄ ± 3·σ_Z·√(p̄(1-p̄)/n_i)

When σ_Z ≈ 1 the chart equals the standard p-chart. σ_Z > 1 indicates
overdispersion (limits widen), σ_Z < 1 indicates underdispersion.

Returns `nothing` if inputs are empty, mismatched, or have fewer than 2 points.
"""
function calculate_laney_p_prime(defectives::Vector{Int}, sample_sizes::Vector{Int})
    n = length(defectives)
    (n < 2 || n != length(sample_sizes)) && return nothing

    total_defective = sum(defectives)
    total_inspected = sum(sample_sizes)
    total_inspected == 0 && return nothing

    p_bar = total_defective / total_inspected

    # Compute proportions and Z-scores
    proportions = Float64[]
    z_scores = Float64[]
    for i in 1:n
        ni = sample_sizes[i]
        pi = ni > 0 ? defectives[i] / ni : 0.0
        push!(proportions, pi)
        sigma_i = ni > 0 ? sqrt(p_bar * (1.0 - p_bar) / ni) : 0.0
        zi = sigma_i > 0.0 ? (pi - p_bar) / sigma_i : 0.0
        push!(z_scores, zi)
    end

    # Between-subgroup variation
    sigma_z = std(z_scores; corrected=true)
    sigma_z = max(sigma_z, 0.0)  # guard against numerical issues

    # Adjusted limits
    ucl = Float64[]
    lcl = Float64[]
    signals = Int[]
    for i in 1:n
        ni = sample_sizes[i]
        sigma_i = ni > 0 ? sqrt(p_bar * (1.0 - p_bar) / ni) : 0.0
        upper = p_bar + 3.0 * sigma_z * sigma_i
        lower = max(0.0, p_bar - 3.0 * sigma_z * sigma_i)
        push!(ucl, upper)
        push!(lcl, lower)

        if proportions[i] > upper || proportions[i] < lower
            push!(signals, i)
        end
    end

    return LaneyResult(p_bar, ucl, lcl, proportions, sigma_z, signals)
end

"""
    calculate_laney_u_prime(defects::Vector{Int}, units::Vector{Int}) -> LaneyResult

Laney u' chart — adjusts standard u-chart limits for overdispersion.

Steps:
1. Compute ū and standard Z-scores: Z_i = (u_i - ū) / √(ū/n_i)
2. Compute σ_Z as the standard deviation of the Z-scores
3. Adjusted limits: ū ± 3·σ_Z·√(ū/n_i)

Returns `nothing` if inputs are empty, mismatched, or have fewer than 2 points.
"""
function calculate_laney_u_prime(defects::Vector{Int}, units::Vector{Int})
    n = length(defects)
    (n < 2 || n != length(units)) && return nothing

    total_defects = sum(defects)
    total_units = sum(units)
    total_units == 0 && return nothing

    u_bar = total_defects / total_units

    # Compute rates and Z-scores
    rates = Float64[]
    z_scores = Float64[]
    for i in 1:n
        ni = units[i]
        ui = ni > 0 ? defects[i] / ni : 0.0
        push!(rates, ui)
        sigma_i = ni > 0 ? sqrt(u_bar / ni) : 0.0
        zi = sigma_i > 0.0 ? (ui - u_bar) / sigma_i : 0.0
        push!(z_scores, zi)
    end

    sigma_z = std(z_scores; corrected=true)
    sigma_z = max(sigma_z, 0.0)

    ucl = Float64[]
    lcl = Float64[]
    signals = Int[]
    for i in 1:n
        ni = units[i]
        sigma_i = ni > 0 ? sqrt(u_bar / ni) : 0.0
        upper = u_bar + 3.0 * sigma_z * sigma_i
        lower = max(0.0, u_bar - 3.0 * sigma_z * sigma_i)
        push!(ucl, upper)
        push!(lcl, lower)

        if rates[i] > upper || rates[i] < lower
            push!(signals, i)
        end
    end

    return LaneyResult(u_bar, ucl, lcl, rates, sigma_z, signals)
end

# ═══════════════════════════════════════════════════════════════════════
# Rare-event charts
# ═══════════════════════════════════════════════════════════════════════

"""
    calculate_g_chart(counts_between::Vector{Int}) -> GChartResult

G-chart for counts between rare events (geometric distribution).

Uses the geometric distribution parameterised by p = 1/(ḡ + 1):
    UCL = (1 - α/2) quantile ≈ ḡ + 3·√(ḡ·(ḡ+1))
    LCL = max(0, ḡ - 3·√(ḡ·(ḡ+1)))

Returns `nothing` if the input is empty.
"""
function calculate_g_chart(counts_between::Vector{Int})
    n = length(counts_between)
    n == 0 && return nothing

    g_bar = mean(Float64.(counts_between))
    sigma = sqrt(g_bar * (g_bar + 1.0))
    ucl = g_bar + 3.0 * sigma
    lcl = max(0.0, g_bar - 3.0 * sigma)

    values = Float64.(counts_between)
    signals = Int[]
    for i in 1:n
        if values[i] > ucl || values[i] < lcl
            push!(signals, i)
        end
    end

    return GChartResult(g_bar, ucl, lcl, values, signals)
end

"""
    calculate_t_chart(times_between::Vector{Float64}) -> TChartResult

T-chart for time between rare events using natural-log transformation.

Because inter-event times are typically right-skewed (exponential or Weibull),
the chart applies a ln-transform to achieve approximate normality:
    y_i = ln(t_i)
    ȳ, s_y computed from the y_i
    UCL = exp(ȳ + 3·MR̄_y / d₂)
    LCL = exp(ȳ - 3·MR̄_y / d₂)

The I-MR approach on the transformed scale uses moving range estimation
for σ, which is more robust for small samples. Signals are detected on
the original scale.

Returns `nothing` if fewer than 2 positive observations are supplied.
"""
function calculate_t_chart(times_between::Vector{Float64})
    # Filter to positive values only
    positive = filter(t -> t > 0.0, times_between)
    n = length(positive)
    n < 2 && return nothing

    # Natural log transform
    transformed = log.(positive)

    # Use I-MR approach on transformed data
    mr_values = [abs(transformed[i] - transformed[i-1]) for i in 2:n]
    y_bar = mean(transformed)
    mr_bar = mean(mr_values)
    d2 = 1.128

    sigma_y = mr_bar / d2

    ucl_transformed = y_bar + 3.0 * sigma_y
    lcl_transformed = y_bar - 3.0 * sigma_y

    # Back-transform to original scale
    center = exp(y_bar)
    ucl = exp(ucl_transformed)
    lcl = exp(lcl_transformed)

    # Signals on original scale
    signals = Int[]
    for i in 1:length(times_between)
        t = times_between[i]
        t <= 0.0 && continue
        if t > ucl || t < lcl
            push!(signals, i)
        end
    end

    return TChartResult(center, ucl, lcl, times_between, transformed, signals)
end

# ═══════════════════════════════════════════════════════════════════════
# Time-weighted charts
# ═══════════════════════════════════════════════════════════════════════

"""
    calculate_cusum(values::Vector{Float64}; target::Float64,
                    k::Float64=0.5, h::Float64=5.0) -> CUSUMResult

Two-sided CUSUM chart.

Maintains upper and lower cumulative sums:
    C⁺_i = max(0, C⁺_{i-1} + (x_i - target - k·σ))
    C⁻_i = max(0, C⁻_{i-1} - (x_i - target - k·σ))

where σ is estimated from the moving range (MR̄/d₂). A signal is raised
when C⁺_i > h·σ or C⁻_i > h·σ.

When `k` and `h` are given in standardised units (multiples of σ), the
shift detection is tuned accordingly. Default k=0.5, h=5.0 gives a CUSUM
tuned for detecting a 1σ shift.

Returns `nothing` if fewer than 2 observations are supplied.
"""
function calculate_cusum(values::Vector{Float64}; target::Float64,
                         k::Float64=0.5, h::Float64=5.0)
    n = length(values)
    n < 2 && return nothing

    # Estimate process sigma from moving ranges
    mr_values = [abs(values[i] - values[i-1]) for i in 2:n]
    mr_bar = mean(mr_values)
    d2 = 1.128
    sigma = mr_bar / d2
    sigma == 0.0 && (sigma = 1.0)  # avoid division by zero for constant data

    K = k * sigma
    H = h * sigma

    upper_cusum = zeros(n)
    lower_cusum = zeros(n)
    signals = Int[]

    for i in 1:n
        prev_upper = i > 1 ? upper_cusum[i-1] : 0.0
        prev_lower = i > 1 ? lower_cusum[i-1] : 0.0

        upper_cusum[i] = max(0.0, prev_upper + (values[i] - target) - K)
        lower_cusum[i] = max(0.0, prev_lower - (values[i] - target) - K)

        if upper_cusum[i] > H || lower_cusum[i] > H
            push!(signals, i)
        end
    end

    return CUSUMResult(target, H, -H, values, upper_cusum, lower_cusum, signals)
end

"""
    calculate_ewma(values::Vector{Float64}; lambda::Float64=0.2,
                   L::Float64=3.0) -> EWMAResult

EWMA (Exponentially Weighted Moving Average) chart.

The EWMA statistic is:
    Z_i = λ·x_i + (1-λ)·Z_{i-1},  Z_0 = x̄ (or target)

Control limits expand with time and converge to steady-state:
    UCL_i = μ₀ + L·σ·√(λ/(2-λ)·(1-(1-λ)^(2i)))
    LCL_i = μ₀ - L·σ·√(λ/(2-λ)·(1-(1-λ)^(2i)))

Process σ is estimated from the moving range (MR̄/d₂). The target μ₀
defaults to the overall mean x̄.

Returns `nothing` if fewer than 2 observations are supplied.
"""
function calculate_ewma(values::Vector{Float64}; lambda::Float64=0.2,
                        L::Float64=3.0)
    n = length(values)
    n < 2 && return nothing

    # Estimate sigma from moving ranges
    mr_values = [abs(values[i] - values[i-1]) for i in 2:n]
    mr_bar = mean(mr_values)
    d2 = 1.128
    sigma = mr_bar / d2
    sigma == 0.0 && (sigma = 1.0)

    mu0 = mean(values)

    ewma_vals = zeros(n)
    ucl = zeros(n)
    lcl = zeros(n)
    signals = Int[]

    for i in 1:n
        prev_z = i > 1 ? ewma_vals[i-1] : mu0
        ewma_vals[i] = lambda * values[i] + (1.0 - lambda) * prev_z

        # Time-varying limit factor
        factor = sqrt((lambda / (2.0 - lambda)) * (1.0 - (1.0 - lambda)^(2 * i)))
        ucl[i] = mu0 + L * sigma * factor
        lcl[i] = mu0 - L * sigma * factor

        if ewma_vals[i] > ucl[i] || ewma_vals[i] < lcl[i]
            push!(signals, i)
        end
    end

    return EWMAResult(mu0, ucl, lcl, values, ewma_vals, signals)
end

# ═══════════════════════════════════════════════════════════════════════
# Funnel plots
# ═══════════════════════════════════════════════════════════════════════

"""
    calculate_funnel_proportion(events::Vector{Int}, denominators::Vector{Int};
                                target::Union{Nothing,Float64}=nothing) -> FunnelResult

Funnel plot for proportions (binomial).

Limits narrow as denominator (volume) increases:
    UCL_i = p₀ + 3·√(p₀(1-p₀)/n_i)
    LCL_i = max(0, p₀ - 3·√(p₀(1-p₀)/n_i))

If `target` is not supplied, p₀ = Σevents / Σdenominators (overall proportion).

Returns `nothing` if inputs are empty or have mismatched lengths.
"""
function calculate_funnel_proportion(events::Vector{Int}, denominators::Vector{Int};
                                     target::Union{Nothing,Float64}=nothing)
    n = length(events)
    (n == 0 || n != length(denominators)) && return nothing

    total_events = sum(events)
    total_denom = sum(denominators)
    total_denom == 0 && return nothing

    p0 = target !== nothing ? target : total_events / total_denom

    values = Float64[]
    ucl = Float64[]
    lcl = Float64[]
    volumes = Float64.(denominators)
    signals = Int[]

    for i in 1:n
        ni = denominators[i]
        pi = ni > 0 ? events[i] / ni : 0.0
        push!(values, pi)

        sigma_i = ni > 0 ? sqrt(p0 * (1.0 - p0) / ni) : 0.0
        upper = p0 + 3.0 * sigma_i
        lower = max(0.0, p0 - 3.0 * sigma_i)
        push!(ucl, upper)
        push!(lcl, lower)

        if pi > upper || pi < lower
            push!(signals, i)
        end
    end

    return FunnelResult(p0, ucl, lcl, values, volumes, signals)
end

"""
    calculate_funnel_rate(events::Vector{Int}, denominators::Vector{Float64};
                          target::Union{Nothing,Float64}=nothing) -> FunnelResult

Funnel plot for rates (Poisson).

Limits narrow as denominator (exposure) increases:
    UCL_i = λ₀ + 3·√(λ₀/d_i)
    LCL_i = max(0, λ₀ - 3·√(λ₀/d_i))

If `target` is not supplied, λ₀ = Σevents / Σdenominators (overall rate).

Returns `nothing` if inputs are empty or have mismatched lengths.
"""
function calculate_funnel_rate(events::Vector{Int}, denominators::Vector{Float64};
                               target::Union{Nothing,Float64}=nothing)
    n = length(events)
    (n == 0 || n != length(denominators)) && return nothing

    total_events = sum(events)
    total_denom = sum(denominators)
    total_denom == 0.0 && return nothing

    lambda0 = target !== nothing ? target : total_events / total_denom

    values = Float64[]
    ucl = Float64[]
    lcl = Float64[]
    volumes = copy(denominators)
    signals = Int[]

    for i in 1:n
        di = denominators[i]
        ri = di > 0.0 ? events[i] / di : 0.0
        push!(values, ri)

        sigma_i = di > 0.0 ? sqrt(lambda0 / di) : 0.0
        upper = lambda0 + 3.0 * sigma_i
        lower = max(0.0, lambda0 - 3.0 * sigma_i)
        push!(ucl, upper)
        push!(lcl, lower)

        if ri > upper || ri < lower
            push!(signals, i)
        end
    end

    return FunnelResult(lambda0, ucl, lcl, values, volumes, signals)
end

# ═══════════════════════════════════════════════════════════════════════
# Run rules (Western Electric)
# ═══════════════════════════════════════════════════════════════════════

"""
    detect_western_electric_rules(values::Vector{Float64}, center::Float64,
                                  sigma::Float64) -> Vector{RunRuleViolation}

Detect Western Electric run-rule violations.

Rule 1: Any single point beyond 3σ from center line.
Rule 2: 2 of 3 consecutive points beyond 2σ on the same side.
Rule 3: 4 of 5 consecutive points beyond 1σ on the same side.
Rule 4: 8 consecutive points on the same side of the center line.

Returns a vector of `RunRuleViolation` structs, each identifying the
triggering point index, rule number, and a human-readable description.
"""
function detect_western_electric_rules(values::Vector{Float64}, center::Float64,
                                       sigma::Float64)
    n = length(values)
    violations = RunRuleViolation[]
    sigma <= 0.0 && return violations

    zone_a = 3.0 * sigma  # beyond 3σ
    zone_b = 2.0 * sigma  # beyond 2σ
    zone_c = 1.0 * sigma  # beyond 1σ

    for i in 1:n
        dev = values[i] - center

        # Rule 1: single point beyond 3σ
        if abs(dev) > zone_a
            side = dev > 0 ? "above" : "below"
            push!(violations, RunRuleViolation(i, 1,
                "Point $i beyond 3σ $side center line"))
        end

        # Rule 2: 2 of 3 consecutive beyond 2σ same side
        if i >= 3
            for side_sign in [1.0, -1.0]
                count = 0
                for j in (i-2):i
                    d = values[j] - center
                    if side_sign * d > zone_b
                        count += 1
                    end
                end
                if count >= 2
                    side = side_sign > 0 ? "above" : "below"
                    push!(violations, RunRuleViolation(i, 2,
                        "2 of 3 points (ending at $i) beyond 2σ $side center"))
                end
            end
        end

        # Rule 3: 4 of 5 consecutive beyond 1σ same side
        if i >= 5
            for side_sign in [1.0, -1.0]
                count = 0
                for j in (i-4):i
                    d = values[j] - center
                    if side_sign * d > zone_c
                        count += 1
                    end
                end
                if count >= 4
                    side = side_sign > 0 ? "above" : "below"
                    push!(violations, RunRuleViolation(i, 3,
                        "4 of 5 points (ending at $i) beyond 1σ $side center"))
                end
            end
        end

        # Rule 4: 8 consecutive on the same side
        if i >= 8
            all_above = true
            all_below = true
            for j in (i-7):i
                d = values[j] - center
                if d <= 0; all_above = false; end
                if d >= 0; all_below = false; end
            end
            if all_above
                push!(violations, RunRuleViolation(i, 4,
                    "8 consecutive points (ending at $i) above center line"))
            elseif all_below
                push!(violations, RunRuleViolation(i, 4,
                    "8 consecutive points (ending at $i) below center line"))
            end
        end
    end

    return violations
end
