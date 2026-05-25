# ============================================================================
# FMEA (Failure Mode and Effects Analysis) — IEC 62304 / ISO 14971
# ============================================================================

# ---------------------------------------------------------------------------
# Severity, probability, detectability, and control enumerations
# ---------------------------------------------------------------------------

"""Risk severity levels per IEC 62304 / ISO 14971."""
const RISK_SEVERITY = Dict{Symbol,Int}(
    :negligible   => 1,
    :minor        => 2,
    :moderate     => 3,
    :major        => 4,
    :catastrophic => 5,
)

"""Risk probability / likelihood of occurrence."""
const RISK_PROBABILITY = Dict{Symbol,Int}(
    :improbable  => 1,
    :remote      => 2,
    :occasional  => 3,
    :probable    => 4,
    :frequent    => 5,
)

"""Detectability rating (lower score = easier to detect)."""
const DETECTABILITY = Dict{Symbol,Int}(
    :almost_certain => 1,
    :high           => 2,
    :moderate       => 3,
    :low            => 4,
    :very_low       => 5,
)

"""Risk control strategy types."""
const CONTROL_TYPES = (:preventive, :detective, :corrective)

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

"""
    FailureMode

A single failure mode in an FMEA analysis.

# Fields
- `id::String`: unique identifier (e.g. "FM-001")
- `description::String`: what can fail
- `component::String`: affected component or subsystem
- `severity::Int`: severity rating (1–5)
- `probability::Int`: probability rating (1–5)
- `detectability::Int`: detectability rating (1–5)
- `controls::Vector{Symbol}`: applied control types (:preventive, :detective, :corrective)
- `rpn::Int`: Risk Priority Number (severity * probability * detectability)
- `residual_severity::Int`: severity after controls
- `residual_probability::Int`: probability after controls
- `residual_rpn::Int`: residual RPN after controls
- `status::Symbol`: current status (:open, :controlled, :verified, :closed)
"""
@kwdef struct FailureMode
    id::String
    description::String
    component::String
    severity::Int
    probability::Int
    detectability::Int
    controls::Vector{Symbol}       = Symbol[]
    rpn::Int                       = severity * probability * detectability
    residual_severity::Int         = severity
    residual_probability::Int      = probability
    residual_rpn::Int              = residual_severity * residual_probability * detectability
    status::Symbol                 = :open
end

"""
    FMEAReport

Summary report from an FMEA analysis.

# Fields
- `failure_modes::Vector{FailureMode}`: all analysed failure modes
- `high_risk_count::Int`: number of modes with unacceptable RPN
- `average_rpn::Float64`: mean RPN across all modes
- `max_rpn::Int`: highest RPN observed
- `risk_reduction_pct::Float64`: percentage risk reduction from controls
"""
struct FMEAReport
    failure_modes::Vector{FailureMode}
    high_risk_count::Int
    average_rpn::Float64
    max_rpn::Int
    risk_reduction_pct::Float64
end

# ---------------------------------------------------------------------------
# Core functions
# ---------------------------------------------------------------------------

"""
    calculate_rpn(severity::Int, probability::Int, detectability::Int) -> Int

Calculate the Risk Priority Number as the product of severity, probability,
and detectability ratings.
"""
function calculate_rpn(severity::Int, probability::Int, detectability::Int)
    return severity * probability * detectability
end

"""
    assess_risk_acceptability(rpn::Int; threshold::Int=100) -> Symbol

Classify the acceptability of a given RPN value.

Returns:
- `:acceptable` when rpn < threshold
- `:needs_mitigation` when threshold <= rpn < high_threshold
- `:unacceptable` when rpn >= high_threshold
"""
function assess_risk_acceptability(rpn::Int; threshold::Int=50, high_threshold::Int=75)
    if rpn < threshold
        return :acceptable
    elseif rpn < high_threshold
        return :needs_mitigation
    else
        return :unacceptable
    end
end

"""
    generate_fmea_report(modes::Vector{FailureMode}) -> FMEAReport

Generate an FMEA summary report from a collection of failure modes.

Computes high-risk count (modes with unacceptable RPN), average and maximum RPN,
and the overall risk-reduction percentage achieved by controls.
"""
function generate_fmea_report(modes::Vector{FailureMode})
    if isempty(modes)
        return FMEAReport(modes, 0, 0.0, 0, 0.0)
    end

    high_risk_count = count(m -> assess_risk_acceptability(m.rpn) == :unacceptable, modes)
    rpns = [m.rpn for m in modes]
    average_rpn = sum(rpns) / length(rpns)
    max_rpn = maximum(rpns)

    total_initial = sum(rpns)
    total_residual = sum(m.residual_rpn for m in modes)
    risk_reduction_pct = if total_initial > 0
        (1.0 - total_residual / total_initial) * 100.0
    else
        0.0
    end

    return FMEAReport(modes, high_risk_count, average_rpn, max_rpn, risk_reduction_pct)
end

"""
    prioritize_failure_modes(modes::Vector{FailureMode}) -> Vector{FailureMode}

Return failure modes sorted by RPN in descending order (highest risk first).
"""
function prioritize_failure_modes(modes::Vector{FailureMode})
    return sort(modes; by=m -> m.rpn, rev=true)
end
