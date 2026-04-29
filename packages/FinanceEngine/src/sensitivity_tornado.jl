"""
    sensitivity_tornado.jl — Universal Sensitivity / Tornado Analysis (MBA Gap F-04)

A universal, function-agnostic sensitivity analysis engine that produces
tornado chart data for any scalar-valued financial model.

## Why this belongs in the MBA gap list
The existing codebase has scattered ad-hoc sensitivity functions in several
modules (WACC sensitivity in nonprofit_wacc.jl, scenario sweeps in montecarlo.jl)
but no centralised API. The CFO dashboard, board packet, and rating agency memo
all need tornado data from different underlying models — they should all call
one function.

## Capabilities
1. **One-Way Sensitivity** — vary each parameter ±N% while holding others at
   baseline; sort by impact magnitude (tornado chart format).
2. **Two-Way Sensitivity** — vary two parameters simultaneously; produces an
   N×M table (e.g. WACC × terminal growth → DCF value).
3. **Probabilistic Sensitivity** — Monte Carlo with user-supplied distributions
   per parameter; outputs P5/P50/P95 of the output.
4. **Break-Even Analysis** — for each parameter, find the value that drives
   the output to a specified target (e.g. DSCR = 1.10).
5. **Scenario Comparison** — run the model under a set of named scenarios
   and return a ranked comparison table.

## API pattern
```julia
# Define any model as a function taking a NamedTuple of parameters
model(p) = p.revenue * p.margin - p.fixed_costs

baseline = (revenue=8_500_000.0, margin=0.028, fixed_costs=250_000.0)
ranges   = (revenue=0.10, margin=0.20, fixed_costs=0.15)  # ±% swings

tornado  = one_way_sensitivity(model, baseline, ranges)
# Returns sorted tornado rows ready for horizontal bar chart
```

References:
- Saltelli A et al (2008). Global Sensitivity Analysis: The Primer. Wiley.
- Briggs A, Schulpher M, Claxton K (2006). Decision Modelling for Health Economic
  Evaluation. Oxford University Press.
- Gapenski L (2015). Healthcare Financial Management, 7e. Chapter 14 (CVP analysis).
"""

using Statistics
using Printf

# ─────────────────────────────────────────────────────────────────────────────
# Core result types
# ─────────────────────────────────────────────────────────────────────────────

"""
    TornadoRow

One parameter's contribution to the sensitivity tornado.

# Fields
- `parameter::Symbol`
- `baseline_value::Float64`: Parameter value at baseline.
- `output_baseline::Float64`: Model output at all-baseline inputs.
- `output_low::Float64`: Model output when this parameter is at its low swing.
- `output_high::Float64`: Model output when this parameter is at its high swing.
- `swing_low_pct::Float64`: % below baseline for the low swing.
- `swing_high_pct::Float64`: % above baseline for the high swing.
- `total_range::Float64`: `abs(output_high - output_low)` — tornado bar width.
- `impact_direction::Symbol`: `:positive_with_increase` or `:negative_with_increase`.
"""
struct TornadoRow
    parameter::Symbol
    baseline_value::Float64
    output_baseline::Float64
    output_low::Float64
    output_high::Float64
    swing_low_pct::Float64
    swing_high_pct::Float64
    total_range::Float64
    impact_direction::Symbol
end

"""
    TornadoResult

Complete tornado analysis output.

# Fields
- `rows::Vector{TornadoRow}`: Sorted by `total_range` descending (widest bar first).
- `output_baseline::Float64`
- `top_driver::Symbol`: Parameter with largest impact.
- `n_parameters::Int`
"""
struct TornadoResult
    rows::Vector{TornadoRow}
    output_baseline::Float64
    top_driver::Symbol
    n_parameters::Int
end

# ─────────────────────────────────────────────────────────────────────────────
# One-way sensitivity (tornado)
# ─────────────────────────────────────────────────────────────────────────────

"""
    one_way_sensitivity(
        model::Function,
        baseline::NamedTuple,
        pct_swings::NamedTuple;
        asymmetric_swings
    ) -> TornadoResult

Run one-way sensitivity analysis on `model`.

For each parameter in `pct_swings`, varies that parameter ±pct while holding
all others at baseline. The model function receives a NamedTuple of parameters
and must return a single `Float64`.

# Arguments
- `model::Function`: `(NamedTuple) -> Float64`.
- `baseline::NamedTuple`: Baseline parameter values.
- `pct_swings::NamedTuple`: Fractional swing per parameter (0.10 = ±10%).
  Keys must be a subset of `baseline` keys.
- `asymmetric_swings::Union{Nothing,NamedTuple} = nothing`: Optional
  `(param=(low_pct, high_pct), ...)` for asymmetric ranges.

# Example
```julia
# DCF model: output = enterprise value
dcf_model(p) = p.fcf * (1 + p.growth) / (p.wacc - p.growth)

baseline = (fcf=500_000.0, wacc=0.07, growth=0.025)
swings   = (fcf=0.10, wacc=0.20, growth=0.30)

r = one_way_sensitivity(dcf_model, baseline, swings)
# Sorted: growth has biggest impact, then WACC, then FCF
for row in r.rows
    println(row.parameter, " : [", round(row.output_low/1e6,digits=2),
            "M — ", round(row.output_high/1e6,digits=2), "M]")
end
```
"""
function one_way_sensitivity(
    model::Function,
    baseline::NamedTuple,
    pct_swings::NamedTuple;
    asymmetric_swings::Union{Nothing,NamedTuple} = nothing,
)::TornadoResult

    output_base = Float64(model(baseline))
    rows = TornadoRow[]

    for param in keys(pct_swings)
        haskey(baseline, param) ||
            throw(ArgumentError("Parameter :$param not found in baseline"))

        base_val = Float64(baseline[param])
        pct      = Float64(pct_swings[param])

        # Determine low/high swings
        if !isnothing(asymmetric_swings) && haskey(asymmetric_swings, param)
            lo_pct, hi_pct = asymmetric_swings[param]
        else
            lo_pct, hi_pct = pct, pct
        end

        val_low  = base_val * (1.0 - lo_pct)
        val_high = base_val * (1.0 + hi_pct)

        # Rebuild NamedTuple with this parameter at low / high
        params_low  = NamedTuple{keys(baseline)}(
            k == param ? val_low : baseline[k] for k in keys(baseline))
        params_high = NamedTuple{keys(baseline)}(
            k == param ? val_high : baseline[k] for k in keys(baseline))

        out_low  = Float64(model(params_low))
        out_high = Float64(model(params_high))
        range    = abs(out_high - out_low)
        direction = out_high >= out_low ? :positive_with_increase : :negative_with_increase

        push!(rows, TornadoRow(
            param, base_val, output_base,
            out_low, out_high,
            lo_pct, hi_pct, range, direction,
        ))
    end

    sort!(rows; by=r -> -r.total_range)
    top = isempty(rows) ? :none : rows[1].parameter

    TornadoResult(rows, output_base, top, length(rows))
end

# ─────────────────────────────────────────────────────────────────────────────
# Two-way sensitivity table
# ─────────────────────────────────────────────────────────────────────────────

"""
    two_way_sensitivity(
        model::Function,
        baseline::NamedTuple,
        param_x::Symbol, x_range::Vector{Float64},
        param_y::Symbol, y_range::Vector{Float64}
    ) -> NamedTuple

Run two-way sensitivity, varying `param_x` and `param_y` simultaneously.

Returns:
- `table::Matrix{Float64}`: `length(y_range) × length(x_range)` output values.
- `x_values::Vector{Float64}`, `y_values::Vector{Float64}`
- `x_name::Symbol`, `y_name::Symbol`
- `baseline_output::Float64`

# Example
```julia
# How does EV change with WACC × growth rate?
r = two_way_sensitivity(dcf_model, baseline,
        :wacc,   [0.05, 0.06, 0.07, 0.08, 0.09],
        :growth, [0.015, 0.020, 0.025, 0.030, 0.035])
r.table   # 5×5 matrix of EV values
```
"""
function two_way_sensitivity(
    model::Function,
    baseline::NamedTuple,
    param_x::Symbol, x_range::Vector{Float64},
    param_y::Symbol, y_range::Vector{Float64},
)
    haskey(baseline, param_x) || throw(ArgumentError(":$param_x not in baseline"))
    haskey(baseline, param_y) || throw(ArgumentError(":$param_y not in baseline"))

    tbl = [begin
        p = NamedTuple{keys(baseline)}(
            k == param_x ? xv :
            k == param_y ? yv :
            baseline[k]
            for k in keys(baseline))
        Float64(model(p))
    end for yv in y_range, xv in x_range]

    (
        table           = tbl,
        x_values        = x_range,
        y_values        = y_range,
        x_name          = param_x,
        y_name          = param_y,
        baseline_output = Float64(model(baseline)),
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Break-even analysis
# ─────────────────────────────────────────────────────────────────────────────

"""
    break_even_analysis(
        model::Function,
        baseline::NamedTuple,
        parameter::Symbol,
        target_output::Float64;
        search_range_pct
    ) -> NamedTuple

Find the value of `parameter` at which `model` output equals `target_output`,
using bisection search within ±`search_range_pct` of the baseline value.

Returns:
- `break_even_value::Union{Float64,Nothing}`: The parameter value at break-even.
  `nothing` if the target is not achievable within the search range.
- `break_even_pct_change::Float64`: % change from baseline.
- `output_at_break_even::Float64`

# Example
```julia
# At what MADS DSCR covenant floor would the hospital breach?
r = break_even_analysis(dscr_model, baseline, :debt_service, 1.10;
                         search_range_pct=0.50)
r.break_even_value   # \$580,000 annual debt service
```
"""
function break_even_analysis(
    model::Function,
    baseline::NamedTuple,
    parameter::Symbol,
    target_output::Float64;
    search_range_pct::Float64 = 0.50,
    n_iter::Int = 60,
)
    haskey(baseline, parameter) || throw(ArgumentError(":$parameter not in baseline"))
    base_val = Float64(baseline[parameter])

    function output_at(v::Float64)
        p = NamedTuple{keys(baseline)}(k == parameter ? v : baseline[k] for k in keys(baseline))
        Float64(model(p))
    end

    lo = base_val * (1.0 - search_range_pct)
    hi = base_val * (1.0 + search_range_pct)
    out_lo = output_at(lo)
    out_hi = output_at(hi)

    # Check if target is bracketed
    if !((out_lo - target_output) * (out_hi - target_output) < 0)
        return (
            break_even_value      = nothing,
            break_even_pct_change = NaN,
            output_at_break_even  = NaN,
            message               = "Target $target_output not achievable within ±$(round(Int,search_range_pct*100))% of baseline",
        )
    end

    # Bisection
    for _ in 1:n_iter
        mid = (lo + hi) / 2.0
        out_mid = output_at(mid)
        abs(out_mid - target_output) < 1e-6 && (lo = hi = mid; break)
        if (out_lo - target_output) * (out_mid - target_output) < 0
            hi = mid
        else
            lo = mid; out_lo = out_mid
        end
    end

    be_val = (lo + hi) / 2.0
    (
        break_even_value      = be_val,
        break_even_pct_change = (be_val - base_val) / abs(base_val) * 100,
        output_at_break_even  = output_at(be_val),
        message               = "Break-even at $parameter = $(round(be_val, sigdigits=4))",
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Named scenario comparison
# ─────────────────────────────────────────────────────────────────────────────

"""
    scenario_sensitivity(
        model::Function,
        baseline::NamedTuple,
        scenarios::Vector{NamedTuple}
    ) -> Vector{NamedTuple}

Run the model under a set of named scenarios and return a comparison table.

Each `scenario` must be a NamedTuple with at minimum:
- `name::String`: Scenario label.
- Any subset of `baseline` keys to override.

Returns a Vector of NamedTuples: `(name, output, delta, delta_pct, inputs_changed)`.

# Example
```julia
scenarios = [
    (name="Base",     wacc=0.070, growth=0.025),
    (name="Adverse",  wacc=0.085, growth=0.015),
    (name="Optimistic", wacc=0.060, growth=0.030),
]
results = scenario_sensitivity(dcf_model, baseline, scenarios)
```
"""
function scenario_sensitivity(
    model::Function,
    baseline::NamedTuple,
    scenarios::Vector{<:NamedTuple},
)::Vector{NamedTuple}
    base_output = Float64(model(baseline))

    map(scenarios) do scen
        # Override baseline with scenario values
        merged = NamedTuple{keys(baseline)}(
            haskey(scen, k) ? Float64(scen[k]) : baseline[k]
            for k in keys(baseline)
        )
        output = Float64(model(merged))
        delta  = output - base_output
        delta_pct = base_output != 0 ? delta / abs(base_output) * 100 : NaN
        changed = [k for k in keys(baseline) if haskey(scen, k) && scen[k] != baseline[k]]

        (
            name          = get(scen, :name, "Unnamed"),
            output        = output,
            delta         = delta,
            delta_pct     = delta_pct,
            inputs_changed = changed,
        )
    end |> sort_by_delta -> sort(sort_by_delta; by=r->r.output, rev=true)
end

# ─────────────────────────────────────────────────────────────────────────────
# Plotly-ready chart data builder
# ─────────────────────────────────────────────────────────────────────────────

"""
    tornado_chart_data(result::TornadoResult) -> NamedTuple

Format a `TornadoResult` for direct use in a Plotly horizontal bar chart
(e.g. in a Stipple reactive view or board packet).

Returns:
- `labels::Vector{String}`: Parameter names for y-axis.
- `low_deltas::Vector{Float64}`: Output change from baseline at low swing (negative).
- `high_deltas::Vector{Float64}`: Output change at high swing (positive if increases output).
- `colors_low::Vector{String}`: Plotly color strings.
- `colors_high::Vector{String}`
"""
function tornado_chart_data(result::TornadoResult)::NamedTuple
    labels      = [string(r.parameter) for r in result.rows]
    low_deltas  = [r.output_low  - r.output_baseline for r in result.rows]
    high_deltas = [r.output_high - r.output_baseline for r in result.rows]

    colors_low  = ["#ef4444" for _ in result.rows]   # red for downside
    colors_high = ["#22c55e" for _ in result.rows]   # green for upside

    (
        labels      = labels,
        low_deltas  = low_deltas,
        high_deltas = high_deltas,
        colors_low  = colors_low,
        colors_high = colors_high,
        baseline    = result.output_baseline,
        top_driver  = string(result.top_driver),
    )
end
