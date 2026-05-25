# ============================================================================
# Dual-Implementation Parity Testing — IEC 62304 Class B Verification
# ============================================================================

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

"""
    ParityTest

A parity test comparing two implementations of the same calculation.

# Fields
- `name::String`: descriptive test name
- `implementation_a::Function`: first implementation to compare
- `implementation_b::Function`: second implementation to compare
- `input_generator::Function`: callable returning a test input value
- `tolerance::Float64`: maximum acceptable absolute deviation (default 1e-9)
"""
@kwdef struct ParityTest
    name::String
    implementation_a::Function
    implementation_b::Function
    input_generator::Function
    tolerance::Float64 = 1e-9
end

"""
    ParityResult

Result of running a parity test between two implementations.

# Fields
- `name::String`: test name
- `passed::Bool`: whether all samples passed within tolerance
- `max_deviation::Float64`: largest absolute deviation observed
- `mean_deviation::Float64`: mean absolute deviation across all samples
- `n_tests::Int`: number of sample inputs tested
- `failures::Vector{NamedTuple}`: details of failing comparisons
"""
struct ParityResult
    name::String
    passed::Bool
    max_deviation::Float64
    mean_deviation::Float64
    n_tests::Int
    failures::Vector{NamedTuple{(:input, :result_a, :result_b, :deviation), Tuple{Any, Float64, Float64, Float64}}}
end

"""
    ParityTestSuite

Collection of parity tests with accumulated results.

# Fields
- `tests::Vector{ParityTest}`: registered tests
- `results::Vector{ParityResult}`: populated after running the suite
"""
mutable struct ParityTestSuite
    tests::Vector{ParityTest}
    results::Vector{ParityResult}
end

ParityTestSuite() = ParityTestSuite(ParityTest[], ParityResult[])

# ---------------------------------------------------------------------------
# Core functions
# ---------------------------------------------------------------------------

"""
    run_parity_test(test::ParityTest; n_samples::Int=100) -> ParityResult

Run a parity test by generating `n_samples` inputs and comparing outputs
from both implementations. A sample passes if the absolute deviation is
within the specified tolerance.
"""
function run_parity_test(test::ParityTest; n_samples::Int=100)
    deviations = Float64[]
    failures = NamedTuple{(:input, :result_a, :result_b, :deviation), Tuple{Any, Float64, Float64, Float64}}[]

    for _ in 1:n_samples
        input = test.input_generator()
        result_a = Float64(test.implementation_a(input))
        result_b = Float64(test.implementation_b(input))
        deviation = abs(result_a - result_b)
        push!(deviations, deviation)

        if deviation > test.tolerance
            push!(failures, (input=input, result_a=result_a,
                             result_b=result_b, deviation=deviation))
        end
    end

    max_dev = isempty(deviations) ? 0.0 : maximum(deviations)
    mean_dev = isempty(deviations) ? 0.0 : sum(deviations) / length(deviations)

    return ParityResult(
        test.name,
        isempty(failures),
        max_dev,
        mean_dev,
        n_samples,
        failures,
    )
end

"""
    run_parity_suite(suite::ParityTestSuite) -> Bool

Run all tests in the suite, populate results, and return `true` if every
test passed.
"""
function run_parity_suite(suite::ParityTestSuite)
    suite.results = ParityResult[]
    for test in suite.tests
        result = run_parity_test(test)
        push!(suite.results, result)
    end
    return all(r -> r.passed, suite.results)
end

"""
    parity_report(suite::ParityTestSuite) -> String

Generate a formatted summary report of all parity test results.
"""
function parity_report(suite::ParityTestSuite)
    lines = String[]
    push!(lines, "=== Parity Test Report ===")
    push!(lines, "")
    push!(lines, "Total Tests: $(length(suite.results))")
    passed = count(r -> r.passed, suite.results)
    failed = count(r -> !r.passed, suite.results)
    push!(lines, "Passed: $passed")
    push!(lines, "Failed: $failed")
    push!(lines, "")

    for result in suite.results
        status = result.passed ? "PASS" : "FAIL"
        push!(lines, "[$status] $(result.name) | n=$(result.n_tests) | " *
              "max_dev=$(result.max_deviation) | mean_dev=$(result.mean_deviation)")
        if !isempty(result.failures)
            for f in result.failures
                push!(lines, "  FAILURE: input=$(f.input) a=$(f.result_a) " *
                      "b=$(f.result_b) dev=$(f.deviation)")
            end
        end
    end

    return join(lines, "\n")
end
