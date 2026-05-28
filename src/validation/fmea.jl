"""
    FMEA

Failure Mode and Effects Analysis (FMEA) for hospital finance calculations.

Implements a lightweight, thread-safe FMEA registry tailored to financial
computations (NPV, DRG payment, reimbursement, audit, etc.). Each failure
mode is scored along severity, probability, and detectability dimensions;
the Risk Priority Number (RPN = severity x probability x detectability) is
derived automatically.

Risk acceptability bands:
  - RPN  <  50  -> :acceptable
  - 50  <= RPN <= 125 -> :review
  - RPN >  125 -> :unacceptable

This module is intentionally independent of any external state or I/O
dependencies (other than CSV/JSON export) so it can be unit-tested in
isolation.
"""
module FMEA

using Dates
using JSON3
using Printf

export FailureMode, FMEAReport
export add_failure_mode!, prioritize_by_rpn, high_risk_modes
export risk_acceptability, update_mitigation!, close_failure_mode!
export fmea_summary, export_fmea_report
export HOSPITAL_FINANCE_FMEA_TEMPLATE, FMEA_REGISTRY
export compute_rpn

# ---------------------------------------------------------------------------
# Core types
# ---------------------------------------------------------------------------

"""
    FailureMode

Single FMEA entry describing a potential failure of a financial calculation
or downstream control.

# Fields
- `id::String` — opaque identifier (e.g. "FM-NPV-001")
- `description::String` — short human-readable summary
- `function_name::String` — qualified Julia function path being analyzed
- `potential_cause::String`
- `potential_effect::String`
- `severity::Int` — 1..10, higher means worse impact
- `probability::Int` — 1..10, higher means more likely
- `detectability::Int` — 1..10, higher means harder to detect
- `rpn::Int` — severity * probability * detectability
- `mitigation::String`
- `assigned_to::String`
- `status::Symbol` — one of `:open`, `:mitigated`, `:closed`
"""
mutable struct FailureMode
    id::String
    description::String
    function_name::String
    potential_cause::String
    potential_effect::String
    severity::Int
    probability::Int
    detectability::Int
    rpn::Int
    mitigation::String
    assigned_to::String
    status::Symbol
end

function FailureMode(;
    id::AbstractString,
    description::AbstractString = "",
    function_name::AbstractString = "",
    potential_cause::AbstractString = "",
    potential_effect::AbstractString = "",
    severity::Integer = 1,
    probability::Integer = 1,
    detectability::Integer = 1,
    rpn::Integer = 0,
    mitigation::AbstractString = "",
    assigned_to::AbstractString = "",
    status::Symbol = :open,
)
    _validate_score("severity", severity)
    _validate_score("probability", probability)
    _validate_score("detectability", detectability)
    rpn_value = rpn == 0 ? compute_rpn(severity, probability, detectability) : Int(rpn)
    return FailureMode(
        String(id),
        String(description),
        String(function_name),
        String(potential_cause),
        String(potential_effect),
        Int(severity),
        Int(probability),
        Int(detectability),
        rpn_value,
        String(mitigation),
        String(assigned_to),
        status,
    )
end

"""
    FMEAReport

Mutable registry of failure modes with an internal lock for thread safety.
"""
mutable struct FMEAReport
    failure_modes::Vector{FailureMode}
    lock::ReentrantLock
    generated_at::DateTime
end

FMEAReport() = FMEAReport(FailureMode[], ReentrantLock(), now())

# ---------------------------------------------------------------------------
# Score helpers
# ---------------------------------------------------------------------------

function _validate_score(name::AbstractString, score::Integer)
    if !(1 <= score <= 10)
        throw(ArgumentError("$name must be in 1..10, got $score"))
    end
    return score
end

"""
    compute_rpn(severity, probability, detectability) -> Int

Risk Priority Number for the three FMEA scores.
"""
compute_rpn(severity::Integer, probability::Integer, detectability::Integer) =
    Int(severity) * Int(probability) * Int(detectability)

"""
    risk_acceptability(rpn::Int) -> Symbol

Map an RPN onto an acceptability band:
- `:acceptable` if RPN < 50
- `:review` if 50 <= RPN <= 125
- `:unacceptable` if RPN > 125
"""
function risk_acceptability(rpn::Integer)
    if rpn < 50
        return :acceptable
    elseif rpn <= 125
        return :review
    else
        return :unacceptable
    end
end

# ---------------------------------------------------------------------------
# Registry operations
# ---------------------------------------------------------------------------

"""
    add_failure_mode!(report, fm)

Insert `fm` into `report`. The RPN is recomputed from the score fields
unless the caller already set a non-zero value matching the product.
"""
function add_failure_mode!(report::FMEAReport, fm::FailureMode)
    fm.rpn = compute_rpn(fm.severity, fm.probability, fm.detectability)
    lock(report.lock) do
        push!(report.failure_modes, fm)
    end
    return fm
end

"""
    prioritize_by_rpn(report) -> Vector{FailureMode}

Return all failure modes sorted by RPN descending.
"""
function prioritize_by_rpn(report::FMEAReport)
    lock(report.lock) do
        return sort(copy(report.failure_modes); by = fm -> fm.rpn, rev = true)
    end
end

"""
    high_risk_modes(report; threshold=100) -> Vector{FailureMode}

Return modes with RPN at or above `threshold`, sorted descending.
"""
function high_risk_modes(report::FMEAReport; threshold::Integer = 100)
    lock(report.lock) do
        modes = filter(fm -> fm.rpn >= threshold, report.failure_modes)
        return sort(modes; by = fm -> fm.rpn, rev = true)
    end
end

"""
    update_mitigation!(report, fm_id, mitigation, new_detectability)

Replace the mitigation text and detectability score for `fm_id`. Recomputes
the RPN and marks the failure mode as `:mitigated`.

Throws `KeyError` if no failure mode matches `fm_id`.
"""
function update_mitigation!(
    report::FMEAReport,
    fm_id::AbstractString,
    mitigation::AbstractString,
    new_detectability::Integer,
)
    _validate_score("detectability", new_detectability)
    lock(report.lock) do
        idx = findfirst(fm -> fm.id == fm_id, report.failure_modes)
        idx === nothing && throw(KeyError(fm_id))
        fm = report.failure_modes[idx]
        fm.mitigation = String(mitigation)
        fm.detectability = Int(new_detectability)
        fm.rpn = compute_rpn(fm.severity, fm.probability, fm.detectability)
        fm.status = :mitigated
        return fm
    end
end

"""
    close_failure_mode!(report, fm_id)

Mark the failure mode `fm_id` as `:closed`.
"""
function close_failure_mode!(report::FMEAReport, fm_id::AbstractString)
    lock(report.lock) do
        idx = findfirst(fm -> fm.id == fm_id, report.failure_modes)
        idx === nothing && throw(KeyError(fm_id))
        report.failure_modes[idx].status = :closed
        return report.failure_modes[idx]
    end
end

"""
    fmea_summary(report) -> NamedTuple

Return counts of failure modes by status and by acceptability band, the
total count, and the mean RPN.
"""
function fmea_summary(report::FMEAReport)
    lock(report.lock) do
        fms = report.failure_modes
        total = length(fms)
        by_status = Dict{Symbol,Int}(:open => 0, :mitigated => 0, :closed => 0)
        by_acceptability = Dict{Symbol,Int}(
            :acceptable => 0, :review => 0, :unacceptable => 0,
        )
        rpn_sum = 0
        for fm in fms
            by_status[fm.status] = get(by_status, fm.status, 0) + 1
            band = risk_acceptability(fm.rpn)
            by_acceptability[band] = get(by_acceptability, band, 0) + 1
            rpn_sum += fm.rpn
        end
        mean_rpn = total == 0 ? 0.0 : rpn_sum / total
        return (;
            total,
            by_status,
            by_acceptability,
            mean_rpn = float(mean_rpn),
        )
    end
end

# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

"""
    export_fmea_report(report, filepath; format=:csv)

Persist the report. Supported formats: `:csv`, `:json`.
"""
function export_fmea_report(
    report::FMEAReport,
    filepath::AbstractString;
    format::Symbol = :csv,
)
    lock(report.lock) do
        if format == :csv
            _write_csv(report, filepath)
        elseif format == :json
            _write_json(report, filepath)
        else
            throw(ArgumentError("unsupported format $format; use :csv or :json"))
        end
    end
    return filepath
end

function _csv_escape(s::AbstractString)
    needs = occursin(',', s) || occursin('"', s) || occursin('\n', s)
    inner = replace(String(s), '"' => "\"\"")
    return needs ? "\"$inner\"" : inner
end

function _write_csv(report::FMEAReport, filepath::AbstractString)
    open(filepath, "w") do io
        println(
            io,
            "id,description,function_name,potential_cause,potential_effect,",
            "severity,probability,detectability,rpn,mitigation,assigned_to,",
            "status,acceptability",
        )
        for fm in report.failure_modes
            row = join(
                (
                    _csv_escape(fm.id),
                    _csv_escape(fm.description),
                    _csv_escape(fm.function_name),
                    _csv_escape(fm.potential_cause),
                    _csv_escape(fm.potential_effect),
                    string(fm.severity),
                    string(fm.probability),
                    string(fm.detectability),
                    string(fm.rpn),
                    _csv_escape(fm.mitigation),
                    _csv_escape(fm.assigned_to),
                    string(fm.status),
                    string(risk_acceptability(fm.rpn)),
                ),
                ",",
            )
            println(io, row)
        end
    end
end

function _fm_to_dict(fm::FailureMode)
    return Dict(
        "id" => fm.id,
        "description" => fm.description,
        "function_name" => fm.function_name,
        "potential_cause" => fm.potential_cause,
        "potential_effect" => fm.potential_effect,
        "severity" => fm.severity,
        "probability" => fm.probability,
        "detectability" => fm.detectability,
        "rpn" => fm.rpn,
        "mitigation" => fm.mitigation,
        "assigned_to" => fm.assigned_to,
        "status" => string(fm.status),
        "acceptability" => string(risk_acceptability(fm.rpn)),
    )
end

function _write_json(report::FMEAReport, filepath::AbstractString)
    payload = Dict(
        "generated_at" => string(report.generated_at),
        "failure_modes" => [_fm_to_dict(fm) for fm in report.failure_modes],
    )
    open(filepath, "w") do io
        JSON3.write(io, payload)
    end
end

# ---------------------------------------------------------------------------
# Hospital finance template (>= 10 entries)
# ---------------------------------------------------------------------------

"""
    HOSPITAL_FINANCE_FMEA_TEMPLATE

Pre-populated list of common failure modes for hospital finance
calculations. Returned as a fresh `Vector{FailureMode}` so callers may
mutate it without affecting future calls.
"""
function HOSPITAL_FINANCE_FMEA_TEMPLATE()
    return FailureMode[
        FailureMode(
            id = "FM-NPV-001",
            description = "NPV miscalculation due to incorrect discount rate",
            function_name = "finance.npv",
            potential_cause = "Wrong WACC supplied or sign error in cash flows",
            potential_effect = "Capital project approved/rejected incorrectly",
            severity = 9, probability = 4, detectability = 5,
            mitigation = "Reference fixture vs sci-rural-hospitals NPV",
            assigned_to = "finance-team",
        ),
        FailureMode(
            id = "FM-DRG-001",
            description = "DRG payment lookup returns stale weight",
            function_name = "reimbursement.drg_payment",
            potential_cause = "FY weights table not refreshed",
            potential_effect = "Under/over-billing Medicare per case",
            severity = 8, probability = 5, detectability = 4,
            mitigation = "Annual CMS IPPS final rule import check",
            assigned_to = "reimbursement-team",
        ),
        FailureMode(
            id = "FM-REIMB-001",
            description = "Reimbursement underestimated for outlier cases",
            function_name = "reimbursement.outlier_payment",
            potential_cause = "Cost-to-charge ratio applied to wrong cost center",
            potential_effect = "Net revenue projections understated",
            severity = 7, probability = 5, detectability = 6,
            mitigation = "Per-cost-center CCR validation against worksheet D-1",
            assigned_to = "revenue-cycle",
        ),
        FailureMode(
            id = "FM-AUDIT-001",
            description = "Audit log tampering or silent loss of events",
            function_name = "audit.append",
            potential_cause = "Disk full or process killed mid-write",
            potential_effect = "Loss of HIPAA / 21 CFR 11 evidence chain",
            severity = 10, probability = 2, detectability = 7,
            mitigation = "Hash chain verification + replicated storage",
            assigned_to = "security-team",
        ),
        FailureMode(
            id = "FM-DSCR-001",
            description = "DSCR computed against wrong debt service schedule",
            function_name = "finance.dscr",
            potential_cause = "Schedule loaded for prior fiscal year",
            potential_effect = "Covenant breach undetected",
            severity = 9, probability = 3, detectability = 5,
            mitigation = "Loan schedule effective-date pinning",
            assigned_to = "treasury",
        ),
        FailureMode(
            id = "FM-CASH-001",
            description = "Cash flow projection ignores Medicare DSH delay",
            function_name = "finance.cash_flow",
            potential_cause = "DSH receivable booked in wrong period",
            potential_effect = "13-week cash forecast over-optimistic",
            severity = 7, probability = 6, detectability = 4,
            mitigation = "Cross-check 13-week vs PS&R lag",
            assigned_to = "cfo-office",
        ),
        FailureMode(
            id = "FM-340B-001",
            description = "340B savings miscounted by GPO carve-out errors",
            function_name = "reimbursement.three_forty_b",
            potential_cause = "Mixed-use pharmacy classification mistake",
            potential_effect = "OPA audit finding and recoupment",
            severity = 8, probability = 4, detectability = 6,
            mitigation = "Quarterly TPA reconciliation",
            assigned_to = "pharmacy-finance",
        ),
        FailureMode(
            id = "FM-WACC-001",
            description = "Non-profit WACC uses for-profit tax shield",
            function_name = "cfo.nonprofit_wacc",
            potential_cause = "Default tax rate not zeroed for 501(c)(3)",
            potential_effect = "Hurdle rate too low, marginal projects accepted",
            severity = 8, probability = 3, detectability = 5,
            mitigation = "Entity type guard + property test",
            assigned_to = "finance-team",
        ),
        FailureMode(
            id = "FM-COST-001",
            description = "Cost-per-case allocates indirect cost twice",
            function_name = "finance.cost_per_case",
            potential_cause = "Step-down allocation re-applied at service line",
            potential_effect = "Service-line P&L misleading",
            severity = 6, probability = 5, detectability = 6,
            mitigation = "Allocation-pass counter in run summary",
            assigned_to = "cost-accounting",
        ),
        FailureMode(
            id = "FM-FORECAST-001",
            description = "Forecast accuracy reported on stale baseline",
            function_name = "cfo.forecast_accuracy",
            potential_cause = "Baseline snapshot not invalidated on rebase",
            potential_effect = "MAPE/MAD figures misleading leadership",
            severity = 5, probability = 6, detectability = 7,
            mitigation = "Baseline hash check on every forecast run",
            assigned_to = "fpa-team",
        ),
        FailureMode(
            id = "FM-CAPITAL-001",
            description = "Capital project IRR diverges for non-conventional cash flows",
            function_name = "finance.irr",
            potential_cause = "Newton iteration finds local root",
            potential_effect = "Recommendation flipped vs ground truth",
            severity = 7, probability = 4, detectability = 6,
            mitigation = "Fallback to bisection + sign-change scan",
            assigned_to = "finance-team",
        ),
        FailureMode(
            id = "FM-HRRP-001",
            description = "HRRP penalty applied to wrong base operating DRG amount",
            function_name = "cms.hrrp_evaluate",
            potential_cause = "Base amount taken pre-IME/DSH instead of post",
            potential_effect = "Net reimbursement misstated",
            severity = 8, probability = 3, detectability = 6,
            mitigation = "CMS PRA crosswalk fixture",
            assigned_to = "cms-compliance",
        ),
    ]
end

# ---------------------------------------------------------------------------
# Global singleton
# ---------------------------------------------------------------------------

"""
    FMEA_REGISTRY

Process-wide default `FMEAReport`. Use `add_failure_mode!(FMEA_REGISTRY, fm)`
for convenience in scripts; tests should build their own report.
"""
const FMEA_REGISTRY = FMEAReport()

end # module FMEA
