"""
    ValidationHarness

Fixture-based validation runner. Loads JSON fixtures from disk, dispatches
each to a registered Julia function, and compares the produced outputs to
the expected values using a tolerance-aware recursive diff.

Tolerance semantics for numeric leaves match the Rust reference
implementation in `cah-validation::harness`:
    effective_tol = tolerance * max(1, |expected|)
which lets the same `tolerance` apply to small ratios (e.g. DSCR ~ 1.6)
and large currency amounts (e.g. NPV ~ 1e6 cents).

For arrays, the expected fixture may be a *prefix* of the actual array.
For objects, expected fields not present in actual are an error; actual
fields not present in expected are ignored.
"""
module ValidationHarness

using Dates
using JSON3
using Printf

export Fixture, FixtureResult, HarnessReport
export load_fixtures, run_fixture, run_harness
export diff_outputs, register_function!
export export_harness_report, harness_summary_text
export KNOWN_FUNCTIONS

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

"""
    Fixture

A single fixture record loaded from JSON.
"""
struct Fixture
    name::String
    function_name::String
    inputs::Dict{String,Any}
    expected_outputs::Dict{String,Any}
    tolerance::Float64
    category::String
end

function Fixture(;
    name::AbstractString,
    function_name::AbstractString,
    inputs::AbstractDict = Dict{String,Any}(),
    expected_outputs::AbstractDict = Dict{String,Any}(),
    tolerance::Real = 1e-4,
    category::AbstractString = "uncategorized",
)
    return Fixture(
        String(name),
        String(function_name),
        Dict{String,Any}(String(k) => v for (k, v) in inputs),
        Dict{String,Any}(String(k) => v for (k, v) in expected_outputs),
        Float64(tolerance),
        String(category),
    )
end

"""
    FixtureResult

Outcome of running a single fixture.
"""
struct FixtureResult
    fixture_name::String
    passed::Bool
    actual_outputs::Dict{String,Any}
    errors::Vector{String}
    duration_ms::Float64
end

"""
    HarnessReport

Aggregate result of running a fixture suite.
"""
mutable struct HarnessReport
    suite_name::String
    started_at::DateTime
    completed_at::DateTime
    results::Vector{FixtureResult}
    pass_count::Int
    fail_count::Int
    total_duration_ms::Float64
end

# ---------------------------------------------------------------------------
# Function registration
# ---------------------------------------------------------------------------

"""
    KNOWN_FUNCTIONS

Process-wide dispatch table mapping fixture `function_name` strings to
Julia callables. Initially empty; populate with `register_function!`.
"""
const KNOWN_FUNCTIONS = Dict{String,Function}()

const _REGISTRY_LOCK = ReentrantLock()

"""
    register_function!(table, name, fn)

Register `fn` under `name` in `table`. Thread-safe for the default
`KNOWN_FUNCTIONS` table; for caller-supplied tables, synchronization is
the caller's responsibility.
"""
function register_function!(
    table::AbstractDict{String,Function},
    name::AbstractString,
    fn::Function,
)
    if table === KNOWN_FUNCTIONS
        lock(_REGISTRY_LOCK) do
            table[String(name)] = fn
        end
    else
        table[String(name)] = fn
    end
    return fn
end

# ---------------------------------------------------------------------------
# Fixture loading
# ---------------------------------------------------------------------------

"""
    load_fixtures(directory) -> Vector{Fixture}

Read every `*.json` file under `directory` (recursively) and decode each
as a `Fixture`. Files that fail to parse or that lack required fields are
skipped with a `@warn`.
"""
function load_fixtures(directory::AbstractString)
    fixtures = Fixture[]
    isdir(directory) || return fixtures

    for (root, _dirs, files) in walkdir(directory)
        for file in files
            endswith(file, ".json") || continue
            path = joinpath(root, file)
            try
                content = read(path, String)
                parsed = JSON3.read(content, Dict{String,Any})
                push!(fixtures, _decode_fixture(parsed, file))
            catch err
                @warn "Failed to load fixture" path err
            end
        end
    end
    return fixtures
end

function _decode_fixture(d::AbstractDict, default_name::AbstractString)
    haskey(d, "function_name") ||
        throw(ArgumentError("fixture missing required field 'function_name'"))
    name = String(get(d, "name", replace(default_name, r"\.json$" => "")))
    function_name = String(d["function_name"])
    inputs = _to_string_dict(get(d, "inputs", Dict{String,Any}()))
    expected = _to_string_dict(get(d, "expected_outputs", Dict{String,Any}()))
    tolerance = Float64(get(d, "tolerance", 1e-4))
    category = String(get(d, "category", "uncategorized"))
    return Fixture(
        name = name,
        function_name = function_name,
        inputs = inputs,
        expected_outputs = expected,
        tolerance = tolerance,
        category = category,
    )
end

_to_string_dict(d::AbstractDict) =
    Dict{String,Any}(String(k) => _json_normalize(v) for (k, v) in d)
_to_string_dict(other) = throw(ArgumentError("expected object, got $(typeof(other))"))

# Normalize JSON3 values to plain Julia types so downstream code is simpler.
_json_normalize(x::JSON3.Object) = Dict{String,Any}(String(k) => _json_normalize(v) for (k, v) in x)
_json_normalize(x::JSON3.Array) = Any[_json_normalize(v) for v in x]
_json_normalize(x::AbstractDict) = Dict{String,Any}(String(k) => _json_normalize(v) for (k, v) in x)
_json_normalize(x::AbstractVector) = Any[_json_normalize(v) for v in x]
_json_normalize(x) = x

# ---------------------------------------------------------------------------
# Diff
# ---------------------------------------------------------------------------

"""
    diff_outputs(expected, actual, tolerance) -> Vector{String}

Recursively compare `expected` to `actual`. Returns a vector of error
messages; an empty vector means the values match within tolerance.
"""
function diff_outputs(expected, actual, tolerance::Real)
    errors = String[]
    _diff_recursive!(errors, expected, actual, Float64(tolerance), "\$")
    return errors
end

function _diff_recursive!(errors, expected, actual, tolerance::Float64, path::String)
    if expected isa AbstractDict && actual isa AbstractDict
        for (k, ev) in expected
            ks = String(k)
            if !haskey(actual, ks) && !haskey(actual, k)
                push!(errors, "$path.$ks: missing in actual")
                continue
            end
            av = haskey(actual, ks) ? actual[ks] : actual[k]
            _diff_recursive!(errors, ev, av, tolerance, "$path.$ks")
        end
        return
    end

    if expected isa AbstractVector && actual isa AbstractVector
        if length(expected) > length(actual)
            push!(
                errors,
                "$path: array length $(length(actual)) < expected $(length(expected))",
            )
            return
        end
        for (i, (ev, av)) in enumerate(zip(expected, actual))
            _diff_recursive!(errors, ev, av, tolerance, "$path[$(i - 1)]")
        end
        return
    end

    if expected isa Bool && actual isa Bool
        if expected != actual
            push!(errors, "$path: $expected != $actual")
        end
        return
    end

    if expected isa Bool || actual isa Bool
        if expected != actual
            push!(errors, "$path: type mismatch ($(typeof(expected)) vs $(typeof(actual)))")
        end
        return
    end

    if expected isa Number && actual isa Number
        ef = float(expected)
        af = float(actual)
        if !(isfinite(ef) && isfinite(af))
            if !(isnan(ef) && isnan(af)) && ef != af
                push!(errors, "$path: non-finite mismatch ($ef vs $af)")
            end
            return
        end
        abs_err = abs(ef - af)
        scale = max(abs(ef), 1.0)
        normalized = abs_err / scale
        if normalized > tolerance
            push!(
                errors,
                @sprintf("%s: |%.6g - %.6g| / %.6g = %.3e > tol %.3e",
                    path, ef, af, scale, normalized, tolerance),
            )
        end
        return
    end

    if expected isa AbstractString && actual isa AbstractString
        if expected != actual
            push!(errors, "$path: \"$expected\" != \"$actual\"")
        end
        return
    end

    if expected === nothing && actual === nothing
        return
    end

    if expected == actual
        return
    end

    push!(
        errors,
        "$path: type mismatch ($(typeof(expected)) vs $(typeof(actual)))",
    )
    return
end

# ---------------------------------------------------------------------------
# Single fixture execution
# ---------------------------------------------------------------------------

_to_dict_or_wrap(x::AbstractDict) =
    Dict{String,Any}(String(k) => v for (k, v) in x)
_to_dict_or_wrap(x) = Dict{String,Any}("value" => x)

"""
    run_fixture(fixture, function_table) -> FixtureResult

Look up `fixture.function_name` in `function_table`, invoke it with
`fixture.inputs`, and diff the result against `fixture.expected_outputs`.

If the function returns a `Dict`, it is used directly as the actual
output; any other return value is wrapped as `Dict("value" => result)`.
"""
function run_fixture(
    fixture::Fixture,
    function_table::AbstractDict{String,Function},
)
    start_ns = time_ns()
    errors = String[]
    actual = Dict{String,Any}()

    fn = get(function_table, fixture.function_name, nothing)
    if fn === nothing
        push!(errors, "no dispatch for $(fixture.function_name)")
        elapsed = (time_ns() - start_ns) / 1e6
        return FixtureResult(fixture.name, false, actual, errors, elapsed)
    end

    try
        raw = fn(fixture.inputs)
        actual = _to_dict_or_wrap(raw)
    catch err
        push!(errors, "dispatch error: $(sprint(showerror, err))")
        elapsed = (time_ns() - start_ns) / 1e6
        return FixtureResult(fixture.name, false, actual, errors, elapsed)
    end

    diff_errs = diff_outputs(fixture.expected_outputs, actual, fixture.tolerance)
    append!(errors, diff_errs)

    elapsed = (time_ns() - start_ns) / 1e6
    passed = isempty(errors)
    return FixtureResult(fixture.name, passed, actual, errors, elapsed)
end

# ---------------------------------------------------------------------------
# Suite runner
# ---------------------------------------------------------------------------

"""
    run_harness(suite_name, fixtures, function_table) -> HarnessReport

Run every fixture in `fixtures` and return an aggregated `HarnessReport`.
"""
function run_harness(
    suite_name::AbstractString,
    fixtures::AbstractVector{Fixture},
    function_table::AbstractDict{String,Function},
)
    started = now()
    started_ns = time_ns()
    results = FixtureResult[]
    pass_count = 0
    fail_count = 0
    for fx in fixtures
        result = run_fixture(fx, function_table)
        push!(results, result)
        if result.passed
            pass_count += 1
        else
            fail_count += 1
        end
    end
    completed = now()
    total_ms = (time_ns() - started_ns) / 1e6
    return HarnessReport(
        String(suite_name),
        started,
        completed,
        results,
        pass_count,
        fail_count,
        total_ms,
    )
end

# ---------------------------------------------------------------------------
# Reporting / export
# ---------------------------------------------------------------------------

function _result_to_dict(r::FixtureResult)
    return Dict(
        "fixture_name" => r.fixture_name,
        "passed" => r.passed,
        "actual_outputs" => r.actual_outputs,
        "errors" => r.errors,
        "duration_ms" => r.duration_ms,
    )
end

"""
    export_harness_report(report, filepath; format=:json)

Persist the report. Supported formats: `:json`, `:csv`.
"""
function export_harness_report(
    report::HarnessReport,
    filepath::AbstractString;
    format::Symbol = :json,
)
    if format == :json
        payload = Dict(
            "suite_name" => report.suite_name,
            "started_at" => string(report.started_at),
            "completed_at" => string(report.completed_at),
            "pass_count" => report.pass_count,
            "fail_count" => report.fail_count,
            "total_duration_ms" => report.total_duration_ms,
            "results" => [_result_to_dict(r) for r in report.results],
        )
        open(filepath, "w") do io
            JSON3.write(io, payload)
        end
    elseif format == :csv
        open(filepath, "w") do io
            println(io, "fixture_name,passed,duration_ms,errors")
            for r in report.results
                errs = replace(join(r.errors, " | "), '"' => "\"\"")
                @printf(
                    io,
                    "%s,%s,%.3f,\"%s\"\n",
                    r.fixture_name,
                    string(r.passed),
                    r.duration_ms,
                    errs,
                )
            end
        end
    else
        throw(ArgumentError("unsupported format $format; use :json or :csv"))
    end
    return filepath
end

"""
    harness_summary_text(report) -> String

Human-readable summary suitable for CI logs.
"""
function harness_summary_text(report::HarnessReport)
    io = IOBuffer()
    println(io, "=== Validation Harness: $(report.suite_name) ===")
    println(io, "Started:   ", report.started_at)
    println(io, "Completed: ", report.completed_at)
    @printf(io, "Duration:  %.2f ms\n", report.total_duration_ms)
    total = report.pass_count + report.fail_count
    println(io, "Results:   $(report.pass_count)/$total passed")
    if report.fail_count > 0
        println(io, "\nFailures:")
        for r in report.results
            r.passed && continue
            println(io, "  - ", r.fixture_name)
            for e in r.errors
                println(io, "      ", e)
            end
        end
    end
    return String(take!(io))
end

end # module ValidationHarness
