"""
    dea.jl — Data Envelopment Analysis for Hospital Efficiency (MBA Gap C-01)

Implements DEA-CCR (Charnes, Cooper, Rhodes 1978) and DEA-BCC (Banker,
Charnes, Cooper 1984) input-oriented efficiency models for peer comparison
of rural hospitals.

DEA identifies the efficient frontier from observed input/output combinations
and assigns each Decision Making Unit (DMU) a relative efficiency score [0,1].
A score of 1.0 means the DMU is on the efficient frontier; below 1.0 means
inputs could theoretically be reduced by (1 − score) while maintaining outputs.

## Stack
Uses JuMP.jl + HiGHS.Optimizer (already in Project.toml).

## Typical hospital DEA application
Inputs:  FTEs, licensed beds, total operating expenses
Outputs: inpatient discharges, ED visits, outpatient revenue (or visits)
         optionally weighted by quality scores

## References
- Charnes A, Cooper W, Rhodes E (1978). Measuring efficiency of DMUs.
  European Journal of Operational Research 2(6): 429-444.
- Banker R, Charnes A, Cooper W (1984). Some models for estimating technical
  and scale inefficiencies in DEA. Management Science 30(9): 1078-1092.
- Rosko M, Mutter R (2011). What have we learned from the application of
  stochastic frontier analysis to U.S. hospitals? Medical Care Research and
  Review 68(1 Suppl): 75S-100S.
"""

using JuMP
using HiGHS
using Statistics
using Printf

# ─────────────────────────────────────────────────────────────────────────────
# Data structures
# ─────────────────────────────────────────────────────────────────────────────

"""
    DEAUnit

A single Decision Making Unit (DMU) — one hospital — with named inputs and
outputs. All values must be strictly positive.

# Fields
- `id`: Any identifier (String, Int, Symbol).
- `inputs::Dict{Symbol,Float64}`: Named inputs (e.g. `:ftes`, `:beds`, `:expenses`).
- `outputs::Dict{Symbol,Float64}`: Named outputs (e.g. `:discharges`, `:ed_visits`).
"""
struct DEAUnit
    id::Any
    inputs::Dict{Symbol, Float64}
    outputs::Dict{Symbol, Float64}
end

"""
    DEAResult

Efficiency result for a single DMU.

# Fields
- `id`: DMU identifier.
- `score::Float64`: Efficiency score ∈ (0, 1]. 1.0 = fully efficient (on frontier).
- `is_efficient::Bool`: `true` if `score ≈ 1.0`.
- `lambdas::Dict{Any,Float64}`: Reference set weights — non-zero peers that define the
  efficient target for this DMU.
- `input_targets::Dict{Symbol,Float64}`: Efficient-frontier input levels (CCR/BCC projection).
- `input_slacks::Dict{Symbol,Float64}`: Excess inputs beyond the proportional reduction.
- `output_slacks::Dict{Symbol,Float64}`: Shortfall in outputs below efficient level.
- `returns_to_scale::Symbol`: `:irs` (increasing), `:drs` (decreasing), or `:crs`. BCC only.
"""
struct DEAResult
    id::Any
    score::Float64
    is_efficient::Bool
    lambdas::Dict{Any, Float64}
    input_targets::Dict{Symbol, Float64}
    input_slacks::Dict{Symbol, Float64}
    output_slacks::Dict{Symbol, Float64}
    returns_to_scale::Symbol
end

"""
    DEAAnalysis

Full DEA analysis output for a set of DMUs.

# Fields
- `model::Symbol`: `:ccr` or `:bcc`.
- `orientation::Symbol`: `:input` (minimize inputs) — only input-orientation implemented.
- `results::Vector{DEAResult}`: One per DMU, in input order.
- `n_efficient::Int`: Number of DMUs on the frontier.
- `mean_score::Float64`
- `median_score::Float64`
- `efficient_ids::Vector{Any}`: IDs of frontier DMUs.
- `input_names::Vector{Symbol}`
- `output_names::Vector{Symbol}`
"""
struct DEAAnalysis
    model::Symbol
    orientation::Symbol
    results::Vector{DEAResult}
    n_efficient::Int
    mean_score::Float64
    median_score::Float64
    efficient_ids::Vector{Any}
    input_names::Vector{Symbol}
    output_names::Vector{Symbol}
end

# ─────────────────────────────────────────────────────────────────────────────
# Internal LP solver
# ─────────────────────────────────────────────────────────────────────────────

const _EFF_TOL = 1e-6   # score treated as 1.0 if ≥ 1 − _EFF_TOL

function _solve_dea_lp(
    x0::Vector{Float64},          # inputs of DMU under evaluation (m × 1)
    y0::Vector{Float64},          # outputs of DMU under evaluation (s × 1)
    X::Matrix{Float64},           # inputs of all DMUs (m × n)
    Y::Matrix{Float64},           # outputs of all DMUs (s × n)
    n_dmus::Int,
    bcc::Bool,                    # true = BCC (VRS); false = CCR (CRS)
)::Tuple{Float64, Vector{Float64}, Vector{Float64}, Vector{Float64}}
    # Returns (θ, λ, input_slacks, output_slacks)

    m = length(x0)    # inputs
    s = length(y0)    # outputs
    n = n_dmus

    model = Model(() -> HiGHS.Optimizer())
    set_silent(model)

    @variable(model, θ >= 0)
    @variable(model, λ[1:n] >= 0)
    @variable(model, s_minus[1:m] >= 0)   # input slacks
    @variable(model, s_plus[1:s] >= 0)    # output slacks

    # Input constraint: Xλ + s⁻ = θ·x₀
    @constraint(model, [i=1:m], sum(X[i,j]*λ[j] for j in 1:n) + s_minus[i] == θ*x0[i])

    # Output constraint: Yλ − s⁺ = y₀
    @constraint(model, [r=1:s], sum(Y[r,j]*λ[j] for j in 1:n) - s_plus[r] == y0[r])

    # BCC convexity constraint
    bcc && @constraint(model, sum(λ) == 1)

    # Phase I: minimize θ
    @objective(model, Min, θ)
    optimize!(model)
    termination_status(model) == MOI.OPTIMAL || return (NaN, zeros(n), zeros(m), zeros(s))

    θ_opt = value(θ)

    # Phase II: maximize sum of slacks (enumerating all efficient vertices)
    @objective(model, Max, sum(s_minus) + sum(s_plus))
    @constraint(model, θ == θ_opt)
    optimize!(model)

    if termination_status(model) == MOI.OPTIMAL
        λ_v = value.(λ)
        sm  = value.(s_minus)
        sp  = value.(s_plus)
    else
        λ_v = zeros(n)
        sm  = zeros(m)
        sp  = zeros(s)
    end

    (θ_opt, λ_v, sm, sp)
end

# ─────────────────────────────────────────────────────────────────────────────
# Public DEA functions
# ─────────────────────────────────────────────────────────────────────────────

"""
    dea(units::Vector{DEAUnit}; model=:ccr) -> DEAAnalysis

Run input-oriented DEA on a set of hospital DMUs.

# Arguments
- `units`: Vector of `DEAUnit`s. All units must share the same input and output keys.
- `model::Symbol = :ccr`: `:ccr` (CRS, Charnes-Cooper-Rhodes) or `:bcc` (VRS, Banker-Charnes-Cooper).

# Returns
`DEAAnalysis` with per-DMU `DEAResult`s, frontier composition, and summary statistics.

# Example
```julia
hospitals = [
    DEAUnit("CAH-001",
        Dict(:ftes=>85.0, :beds=>18.0, :opex=>7_500_000.0),
        Dict(:discharges=>620.0, :ed_visits=>4_200.0)),
    DEAUnit("CAH-002",
        Dict(:ftes=>110.0, :beds=>25.0, :opex=>9_800_000.0),
        Dict(:discharges=>980.0, :ed_visits=>5_500.0)),
    # ... more hospitals
]
result = dea(hospitals; model=:bcc)
for r in result.results
    println(r.id, " efficiency: ", round(r.score*100, digits=1), "%")
end
```

# Interpretation
- Score 1.0: on the efficient frontier — no identified waste given current outputs.
- Score 0.85: theoretically could produce same outputs with 15% fewer inputs.
- `lambdas`: weighted combination of frontier peers that defines the efficient target.
- `input_targets`: what input levels the efficient target requires.
- `input_slacks`: residual excess inputs after proportional reduction.
"""
function dea(units::Vector{DEAUnit}; model::Symbol = :ccr)::DEAAnalysis
    model in (:ccr, :bcc) || throw(ArgumentError("model must be :ccr or :bcc"))
    length(units) >= 2 || throw(ArgumentError("Need at least 2 DMUs for DEA"))

    # Validate consistent keys
    input_names  = sort(collect(keys(units[1].inputs)))
    output_names = sort(collect(keys(units[1].outputs)))
    for u in units
        sort(collect(keys(u.inputs)))  == input_names  ||
            throw(ArgumentError("DMU $(u.id) has different input keys"))
        sort(collect(keys(u.outputs))) == output_names ||
            throw(ArgumentError("DMU $(u.id) has different output keys"))
    end

    n = length(units)
    m = length(input_names)
    s = length(output_names)

    # Build matrices (m × n) and (s × n)
    X = [units[j].inputs[input_names[i]]  for i in 1:m, j in 1:n]
    Y = [units[j].outputs[output_names[r]] for r in 1:s, j in 1:n]

    # Validate positivity
    all(X .> 0) || throw(ArgumentError("All inputs must be strictly positive"))
    all(Y .> 0) || throw(ArgumentError("All outputs must be strictly positive"))

    bcc = (model == :bcc)
    results = DEAResult[]

    for k in 1:n
        x0 = X[:, k]
        y0 = Y[:, k]
        θ, λ_v, sm, sp = _solve_dea_lp(x0, y0, X, Y, n, bcc)

        is_eff = isnan(θ) ? false : θ >= 1.0 - _EFF_TOL
        score  = isnan(θ) ? 0.0 : clamp(θ, 0.0, 1.0)

        # Reference set
        λ_dict = Dict(units[j].id => λ_v[j] for j in 1:n if λ_v[j] > _EFF_TOL)

        # Input targets: θ·x₀ − s⁻
        input_targets = Dict(
            input_names[i] => score * x0[i] - sm[i] for i in 1:m
        )
        input_slacks  = Dict(input_names[i]  => sm[i] for i in 1:m)
        output_slacks = Dict(output_names[r] => sp[r] for r in 1:s)

        # Returns to scale (BCC only: compare BCC vs CCR score)
        rts = :crs
        if bcc && !is_eff
            # Quick CCR re-solve to detect RTS
            θ_ccr, _, _, _ = _solve_dea_lp(x0, y0, X, Y, n, false)
            if !isnan(θ_ccr) && !isnan(θ)
                rts = θ < θ_ccr - _EFF_TOL ? :irs : θ > θ_ccr + _EFF_TOL ? :drs : :crs
            end
        elseif bcc && is_eff
            # On frontier: check sum of λ in CCR
            θ_ccr, λ_ccr, _, _ = _solve_dea_lp(x0, y0, X, Y, n, false)
            sum_λ = sum(λ_ccr)
            rts = sum_λ < 1 - _EFF_TOL ? :irs : sum_λ > 1 + _EFF_TOL ? :drs : :crs
        end

        push!(results, DEAResult(
            units[k].id, score, is_eff,
            λ_dict, input_targets, input_slacks, output_slacks, rts,
        ))
    end

    scores   = [r.score for r in results]
    eff_ids  = [r.id for r in results if r.is_efficient]

    DEAAnalysis(
        model, :input, results,
        length(eff_ids), mean(scores), median(scores),
        eff_ids, input_names, output_names,
    )
end

"""
    dea_ccr(units::Vector{DEAUnit}) -> DEAAnalysis

Shorthand for `dea(units; model=:ccr)` — Constant Returns to Scale.
"""
dea_ccr(units::Vector{DEAUnit}) = dea(units; model=:ccr)

"""
    dea_bcc(units::Vector{DEAUnit}) -> DEAAnalysis

Shorthand for `dea(units; model=:bcc)` — Variable Returns to Scale.
"""
dea_bcc(units::Vector{DEAUnit}) = dea(units; model=:bcc)

"""
    scale_efficiency(ccr_result::DEAResult, bcc_result::DEAResult) -> Float64

Compute scale efficiency = CCR score / BCC score.

Scale efficiency < 1 indicates the DMU is operating at sub-optimal scale
(either too small for IRS or too large for DRS).
"""
function scale_efficiency(ccr::DEAResult, bcc::DEAResult)::Float64
    bcc.score > _EFF_TOL ? clamp(ccr.score / bcc.score, 0.0, 1.0) : NaN
end

"""
    dea_summary_table(analysis::DEAAnalysis) -> Vector{NamedTuple}

Return a sorted summary table (Vector of NamedTuples) for the DEA analysis,
one row per DMU, sorted by efficiency score descending.

Each row: `(id, score, is_efficient, returns_to_scale, top_peer, n_peers)`
"""
function dea_summary_table(analysis::DEAAnalysis)::Vector{NamedTuple}
    rows = map(analysis.results) do r
        top_peer = isempty(r.lambdas) ? nothing :
                   first(sort(collect(r.lambdas); by=x->-x[2]))[1]
        (
            id                = r.id,
            score             = r.score,
            pct_efficient     = r.score * 100,
            is_efficient      = r.is_efficient,
            returns_to_scale  = r.returns_to_scale,
            top_peer          = top_peer,
            n_peers           = length(r.lambdas),
        )
    end
    sort(rows; by=r->-r.score)
end
