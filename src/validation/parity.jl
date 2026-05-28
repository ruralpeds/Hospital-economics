"""
    Parity

Parity testing framework for validating Julia implementations against reference
implementations (R, Python, Excel models).

This is the Julia equivalent of the Rust `cah-validation::parity` module. It
compares outputs from a Julia implementation to expected reference outputs
within configurable absolute and relative tolerances.

Supports scalar, vector, and dictionary comparisons (recursively), JSON fixture
loading, and report export to JSON or CSV.

# Example
```julia
using .Parity

tol = Tolerance(1e-9, 1e-6, true)
cmp = compare("npv_calculation", 1234567.89, 1234567.89; tolerance=tol)
report = run_parity_suite("finance_v1", [cmp])
println(parity_summary_text(report))
```
"""
module Parity

using Dates
using Statistics
using JSON3

export Tolerance, ParityComparison, ParityReport
export compare, compare_scalar, compare_vector, compare_dict
export run_parity_suite, load_reference_fixtures, export_parity_report
export parity_summary_text
export @parity_test

# ---------------------------------------------------------------------------
# Tolerance
# ---------------------------------------------------------------------------

"""
    Tolerance(absolute=1e-9, relative=1e-6, nan_equal=true)

Tolerance settings for numeric comparisons.

- `absolute`: absolute difference threshold; pass if `|a-b| <= absolute`.
- `relative`: relative difference threshold; pass if `|a-b|/|expected| <= relative`.
- `nan_equal`: when `true`, NaN values compare equal to NaN.

A comparison passes if either the absolute or relative criterion is satisfied.
"""
Base.@kwdef struct Tolerance
    absolute::Float64 = 1e-9
    relative::Float64 = 1e-6
    nan_equal::Bool   = true
end

# ---------------------------------------------------------------------------
# ParityComparison
# ---------------------------------------------------------------------------

"""
    ParityComparison

Result of a single parity comparison.

Fields:
- `name::String` — comparison identifier (e.g. `"npv_calculation"`).
- `expected::Any` — reference value (scalar, vector, or dict).
- `actual::Any` — Julia output value.
- `tolerance::Tolerance` — tolerance settings used.
- `passed::Bool` — overall pass/fail.
- `delta::Union{Float64,Nothing}` — absolute difference for scalar comparisons.
- `relative_delta::Union{Float64,Nothing}` — relative difference for scalar comparisons.
- `message::String` — human-readable status / diagnostics.
"""
mutable struct ParityComparison
    name::String
    expected::Any
    actual::Any
    tolerance::Tolerance
    passed::Bool
    delta::Union{Float64,Nothing}
    relative_delta::Union{Float64,Nothing}
    message::String
end

# ---------------------------------------------------------------------------
# ParityReport
# ---------------------------------------------------------------------------

"""
    ParityReport

Aggregated results from running a parity suite.
"""
mutable struct ParityReport
    suite_name::String
    timestamp::DateTime
    comparisons::Vector{ParityComparison}
    passed_count::Int
    failed_count::Int
    summary::String
end

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

"""
    _scalar_check(expected, actual, tol) -> (passed, delta, rel_delta, message)

Core scalar comparison logic. Returns the absolute delta, relative delta,
pass/fail flag, and a message.
"""
function _scalar_check(expected::Real, actual::Real, tol::Tolerance)
    # Handle NaN.
    if isnan(expected) || isnan(actual)
        if isnan(expected) && isnan(actual)
            passed = tol.nan_equal
            msg = tol.nan_equal ? "NaN == NaN (nan_equal=true)" :
                                  "NaN != NaN (nan_equal=false)"
            return passed, NaN, NaN, msg
        else
            return false, NaN, NaN,
                   "NaN mismatch: expected=$expected, actual=$actual"
        end
    end

    # Handle Inf.
    if isinf(expected) || isinf(actual)
        if expected == actual
            return true, 0.0, 0.0, "Inf == Inf"
        else
            return false, Inf, Inf,
                   "Inf mismatch: expected=$expected, actual=$actual"
        end
    end

    delta = abs(float(expected) - float(actual))
    denom = abs(float(expected))
    rel_delta = denom > 0 ? delta / denom :
                (abs(float(actual)) > 0 ? delta / abs(float(actual)) : 0.0)

    abs_ok = delta <= tol.absolute
    rel_ok = rel_delta <= tol.relative
    passed = abs_ok || rel_ok

    msg = passed ?
        "OK (Δ=$(delta), rel=$(rel_delta))" :
        "FAIL (Δ=$(delta) > abs_tol=$(tol.absolute); rel=$(rel_delta) > rel_tol=$(tol.relative))"

    return passed, delta, rel_delta, msg
end

# ---------------------------------------------------------------------------
# Public comparison functions
# ---------------------------------------------------------------------------

"""
    compare_scalar(name, expected::Real, actual::Real; tolerance=Tolerance())

Compare two scalar numeric values. A comparison passes if either the absolute
or relative tolerance is satisfied.
"""
function compare_scalar(name::AbstractString, expected::Real, actual::Real;
                        tolerance::Tolerance=Tolerance())
    passed, delta, rel_delta, msg = _scalar_check(expected, actual, tolerance)
    return ParityComparison(String(name), expected, actual, tolerance,
                            passed, delta, rel_delta, msg)
end

"""
    compare_vector(name, expected::AbstractVector, actual::AbstractVector;
                   tolerance=Tolerance())

Element-wise vector comparison. Fails immediately if vectors differ in length.
"""
function compare_vector(name::AbstractString,
                        expected::AbstractVector, actual::AbstractVector;
                        tolerance::Tolerance=Tolerance())
    if length(expected) != length(actual)
        return ParityComparison(String(name), expected, actual, tolerance,
                                false, nothing, nothing,
                                "Length mismatch: expected=$(length(expected)), actual=$(length(actual))")
    end

    if isempty(expected)
        return ParityComparison(String(name), expected, actual, tolerance,
                                true, 0.0, 0.0, "Empty vectors: trivially equal")
    end

    max_delta = 0.0
    max_rel   = 0.0
    failures  = Tuple{Int,String}[]

    for i in eachindex(expected)
        e = expected[i]
        a = actual[i]
        passed_i, delta_i, rel_i, msg_i = _scalar_check(e, a, tolerance)
        if !isnan(delta_i) && !isinf(delta_i)
            max_delta = max(max_delta, delta_i)
        end
        if !isnan(rel_i) && !isinf(rel_i)
            max_rel = max(max_rel, rel_i)
        end
        if !passed_i
            push!(failures, (i, msg_i))
        end
    end

    passed = isempty(failures)
    msg = if passed
        "OK ($(length(expected)) elements; max Δ=$(max_delta), max rel=$(max_rel))"
    else
        "FAIL ($(length(failures))/$(length(expected)) elements failed; first: idx=$(failures[1][1]) $(failures[1][2]))"
    end

    return ParityComparison(String(name), expected, actual, tolerance,
                            passed, max_delta, max_rel, msg)
end

"""
    compare_dict(name, expected::AbstractDict, actual::AbstractDict;
                 tolerance=Tolerance())

Recursive dictionary comparison. All keys must match. Nested dicts and vectors
are compared via `compare_dict` / `compare_vector`; scalar values via
`compare_scalar`.
"""
function compare_dict(name::AbstractString,
                      expected::AbstractDict, actual::AbstractDict;
                      tolerance::Tolerance=Tolerance())
    e_keys = Set(keys(expected))
    a_keys = Set(keys(actual))

    if e_keys != a_keys
        missing_keys = setdiff(e_keys, a_keys)
        extra_keys   = setdiff(a_keys, e_keys)
        msg = "Key mismatch"
        if !isempty(missing_keys)
            msg *= "; missing=$(collect(missing_keys))"
        end
        if !isempty(extra_keys)
            msg *= "; extra=$(collect(extra_keys))"
        end
        return ParityComparison(String(name), expected, actual, tolerance,
                                false, nothing, nothing, msg)
    end

    failures = String[]
    max_delta = 0.0
    max_rel   = 0.0

    for k in e_keys
        sub_name = "$(name).$(k)"
        sub = compare(sub_name, expected[k], actual[k]; tolerance=tolerance)
        if sub.delta !== nothing && !isnan(sub.delta) && !isinf(sub.delta)
            max_delta = max(max_delta, sub.delta)
        end
        if sub.relative_delta !== nothing && !isnan(sub.relative_delta) &&
           !isinf(sub.relative_delta)
            max_rel = max(max_rel, sub.relative_delta)
        end
        if !sub.passed
            push!(failures, "$(k): $(sub.message)")
        end
    end

    passed = isempty(failures)
    msg = if passed
        "OK ($(length(e_keys)) keys; max Δ=$(max_delta), max rel=$(max_rel))"
    else
        "FAIL ($(length(failures))/$(length(e_keys)) keys failed; first: $(failures[1]))"
    end

    return ParityComparison(String(name), expected, actual, tolerance,
                            passed, max_delta, max_rel, msg)
end

"""
    compare(name, expected, actual; tolerance=Tolerance())

Generic comparison dispatching on the type of `expected`/`actual`.

- `Real` vs `Real` -> `compare_scalar`
- `AbstractVector` vs `AbstractVector` -> `compare_vector`
- `AbstractDict` vs `AbstractDict` -> `compare_dict`
- Otherwise fallback to `==` equality.
"""
function compare(name::AbstractString, expected, actual;
                 tolerance::Tolerance=Tolerance())
    if expected isa Real && actual isa Real
        return compare_scalar(name, expected, actual; tolerance=tolerance)
    elseif expected isa AbstractVector && actual isa AbstractVector
        return compare_vector(name, expected, actual; tolerance=tolerance)
    elseif expected isa AbstractDict && actual isa AbstractDict
        return compare_dict(name, expected, actual; tolerance=tolerance)
    else
        passed = expected == actual
        msg = passed ? "OK (equality)" :
                       "FAIL (non-numeric inequality: expected=$expected, actual=$actual)"
        return ParityComparison(String(name), expected, actual, tolerance,
                                passed, nothing, nothing, msg)
    end
end

# ---------------------------------------------------------------------------
# Suite execution
# ---------------------------------------------------------------------------

"""
    run_parity_suite(suite_name, comparisons) -> ParityReport

Aggregate a vector of `ParityComparison` results into a `ParityReport`.
"""
function run_parity_suite(suite_name::AbstractString,
                          comparisons::Vector{ParityComparison})::ParityReport
    passed_count = count(c -> c.passed, comparisons)
    failed_count = length(comparisons) - passed_count
    summary = "$(suite_name): $(passed_count)/$(length(comparisons)) passed, $(failed_count) failed"
    return ParityReport(String(suite_name), now(), comparisons,
                        passed_count, failed_count, summary)
end

# ---------------------------------------------------------------------------
# Fixture loading
# ---------------------------------------------------------------------------

"""
    load_reference_fixtures(filepath) -> Dict

Load a JSON fixture file containing reference outputs from R / Python / Excel
implementations. Returns a `Dict{String,Any}`.
"""
function load_reference_fixtures(filepath::AbstractString)::Dict
    isfile(filepath) ||
        throw(ArgumentError("Fixture file not found: $filepath"))
    raw = read(filepath, String)
    parsed = JSON3.read(raw)
    return _to_dict(parsed)
end

# Convert JSON3 objects/arrays to plain Julia Dict / Vector so that downstream
# `compare_dict` works uniformly.
function _to_dict(x::JSON3.Object)
    Dict{String,Any}(String(k) => _to_dict(v) for (k, v) in pairs(x))
end
_to_dict(x::JSON3.Array) = Any[_to_dict(v) for v in x]
_to_dict(x) = x

# ---------------------------------------------------------------------------
# Report export
# ---------------------------------------------------------------------------

"""
    export_parity_report(report, filepath; format=:json)

Serialise a `ParityReport` to disk as JSON (default) or CSV.
"""
function export_parity_report(report::ParityReport, filepath::AbstractString;
                              format::Symbol=:json)
    if format === :json
        payload = Dict(
            "suite_name"   => report.suite_name,
            "timestamp"    => string(report.timestamp),
            "passed_count" => report.passed_count,
            "failed_count" => report.failed_count,
            "summary"      => report.summary,
            "comparisons"  => [_comparison_to_dict(c) for c in report.comparisons],
        )
        open(filepath, "w") do io
            JSON3.write(io, payload)
        end
    elseif format === :csv
        open(filepath, "w") do io
            println(io, "name,passed,delta,relative_delta,absolute_tol,relative_tol,message")
            for c in report.comparisons
                println(io, _csv_row(c))
            end
        end
    else
        throw(ArgumentError("Unsupported format: $format (expected :json or :csv)"))
    end
    return filepath
end

function _comparison_to_dict(c::ParityComparison)
    Dict(
        "name"           => c.name,
        "passed"         => c.passed,
        "delta"          => c.delta === nothing ? nothing :
                            (isnan(c.delta) || isinf(c.delta) ? string(c.delta) : c.delta),
        "relative_delta" => c.relative_delta === nothing ? nothing :
                            (isnan(c.relative_delta) || isinf(c.relative_delta) ?
                             string(c.relative_delta) : c.relative_delta),
        "absolute_tol"   => c.tolerance.absolute,
        "relative_tol"   => c.tolerance.relative,
        "nan_equal"      => c.tolerance.nan_equal,
        "message"        => c.message,
    )
end

function _csv_row(c::ParityComparison)
    delta_str = c.delta === nothing ? "" : string(c.delta)
    rel_str   = c.relative_delta === nothing ? "" : string(c.relative_delta)
    msg_esc   = replace(c.message, '"' => "\"\"")
    return string('"', c.name, '"', ",",
                  c.passed, ",",
                  delta_str, ",",
                  rel_str, ",",
                  c.tolerance.absolute, ",",
                  c.tolerance.relative, ",",
                  '"', msg_esc, '"')
end

# ---------------------------------------------------------------------------
# Human-readable summary
# ---------------------------------------------------------------------------

"""
    parity_summary_text(report) -> String

Format the report as a multi-line text report similar to the Rust
`ParityTestSuite::report`.
"""
function parity_summary_text(report::ParityReport)::String
    io = IOBuffer()
    println(io, "=== Parity Test Report ===")
    println(io, "Suite:        ", report.suite_name)
    println(io, "Timestamp:    ", report.timestamp)
    println(io, "Total Tests:  ", length(report.comparisons))
    println(io, "Passed:       ", report.passed_count)
    println(io, "Failed:       ", report.failed_count)
    println(io)
    for c in report.comparisons
        status = c.passed ? "PASS" : "FAIL"
        println(io, "[$status] $(c.name) :: $(c.message)")
    end
    return String(take!(io))
end

# ---------------------------------------------------------------------------
# Macro
# ---------------------------------------------------------------------------

"""
    @parity_test name expected actual [tolerance]

Convenience macro that builds a `ParityComparison` for the given values.

If a vector named `__parity_results__` exists in the enclosing scope, the
resulting comparison is appended to it; otherwise the comparison is returned.
The optional `tolerance` argument must be a `Tolerance` instance; if omitted
a default `Tolerance()` is used.

# Example
```julia
__parity_results__ = ParityComparison[]
@parity_test "npv" 100.0 100.000000001
@parity_test "rate" 0.05 0.0500001 Tolerance(1e-12, 1e-3, true)
```
"""
macro parity_test(name, expected, actual, tolerance=nothing)
    tol_expr = tolerance === nothing ? :(Tolerance()) : esc(tolerance)
    # Use an escaped reference to `__parity_results__` so that hygiene does not
    # mangle the name — the macro is meant to look up a variable by that exact
    # name in the caller's scope.
    accum = esc(:__parity_results__)
    quote
        local _cmp = compare($(esc(name)), $(esc(expected)), $(esc(actual));
                             tolerance=$tol_expr)
        if @isdefined($accum)
            push!($accum, _cmp)
        end
        _cmp
    end
end

end # module Parity
