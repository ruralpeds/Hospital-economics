"""
    validation_utils.jl — Shared validation utilities (T-024)

Consolidates common input-validation patterns that were previously duplicated
across `utils/validation.jl`, `data_ingestion/validators.jl`, `finance/*.jl`,
and `simulation/*.jl`. All public functions are pure (no side-effects) and
return a `ValidationResult` that callers can either ignore (permissive) or
raise (strict).

## Design
- `ValidationResult` carries a boolean + collected error strings so callers
  can surface all problems at once rather than stopping at the first.
- `validate!` converts a failed `ValidationResult` to an `ArgumentError`.
- Individual `check_*` helpers return `ValidationResult` and can be composed
  with `merge_validations`.
- Domain-specific helpers (`check_payer_mix`, `check_financial_field`, …)
  replace the scattered `if … error(…)` patterns in ≥ 6 existing modules.
"""

# ─────────────────────────────────────────────────────────────────────────────
# Core result type
# ─────────────────────────────────────────────────────────────────────────────

"""
    ValidationResult

Accumulates validation errors without immediately throwing. A result is
*valid* when `errors` is empty.

# Fields
- `errors::Vector{String}`: Human-readable error messages.
"""
struct ValidationResult
    errors::Vector{String}
end

ValidationResult() = ValidationResult(String[])

Base.isvalid(r::ValidationResult)  = isempty(r.errors)
Base.isempty(r::ValidationResult)  = isempty(r.errors)
Base.length(r::ValidationResult)   = length(r.errors)
Base.iterate(r::ValidationResult, s...) = iterate(r.errors, s...)

"""
    merge_validations(results...) -> ValidationResult

Combine multiple `ValidationResult`s into one by concatenating their error
lists. Useful for validating independent fields in parallel.
"""
function merge_validations(results::ValidationResult...)::ValidationResult
    all_errors = String[]
    for r in results
        append!(all_errors, r.errors)
    end
    ValidationResult(all_errors)
end

"""
    validate!(result::ValidationResult, context::String = "")

Raise `ArgumentError` if `result` is invalid. `context` is prepended to the
error message to identify the call site.
"""
function validate!(result::ValidationResult, context::String = "")
    isvalid(result) && return nothing
    prefix = isempty(context) ? "" : "[$context] "
    throw(ArgumentError(prefix * join(result.errors, "; ")))
end

# ─────────────────────────────────────────────────────────────────────────────
# Numeric range checkers
# ─────────────────────────────────────────────────────────────────────────────

"""
    check_positive(value, field_name) -> ValidationResult

Require `value > 0`.
"""
function check_positive(value::Real, field_name::String)::ValidationResult
    value > 0 ? ValidationResult() :
        ValidationResult(["$field_name must be positive; got $value"])
end

"""
    check_non_negative(value, field_name) -> ValidationResult

Require `value >= 0`.
"""
function check_non_negative(value::Real, field_name::String)::ValidationResult
    value >= 0 ? ValidationResult() :
        ValidationResult(["$field_name must be ≥ 0; got $value"])
end

"""
    check_in_range(value, lo, hi, field_name; inclusive=true) -> ValidationResult

Require `lo ≤ value ≤ hi` (or strict inequalities when `inclusive=false`).
"""
function check_in_range(
    value::Real, lo::Real, hi::Real, field_name::String;
    inclusive::Bool = true,
)::ValidationResult
    ok = inclusive ? (lo <= value <= hi) : (lo < value < hi)
    ok ? ValidationResult() :
        ValidationResult(["$field_name must be in [$(lo), $(hi)]; got $value"])
end

"""
    check_finite(value, field_name) -> ValidationResult

Require `isfinite(value)` (rejects `Inf`, `-Inf`, `NaN`).
"""
function check_finite(value::Real, field_name::String)::ValidationResult
    isfinite(value) ? ValidationResult() :
        ValidationResult(["$field_name must be finite; got $value"])
end

"""
    check_integer_range(value, lo, hi, field_name) -> ValidationResult

Require `value` is an integer in `[lo, hi]`.
"""
function check_integer_range(
    value::Integer, lo::Integer, hi::Integer, field_name::String,
)::ValidationResult
    lo <= value <= hi ? ValidationResult() :
        ValidationResult(["$field_name must be in [$lo, $hi]; got $value"])
end

# ─────────────────────────────────────────────────────────────────────────────
# String & collection checkers
# ─────────────────────────────────────────────────────────────────────────────

"""
    check_non_empty_string(value, field_name) -> ValidationResult
"""
function check_non_empty_string(value::String, field_name::String)::ValidationResult
    isempty(strip(value)) ?
        ValidationResult(["$field_name must not be empty"]) :
        ValidationResult()
end

"""
    check_one_of(value, allowed, field_name) -> ValidationResult

Require `value ∈ allowed`.
"""
function check_one_of(value, allowed, field_name::String)::ValidationResult
    value in allowed ? ValidationResult() :
        ValidationResult(["$field_name must be one of $(collect(allowed)); got $(repr(value))"])
end

"""
    check_non_empty_collection(coll, field_name) -> ValidationResult
"""
function check_non_empty_collection(coll, field_name::String)::ValidationResult
    isempty(coll) ?
        ValidationResult(["$field_name must not be empty"]) :
        ValidationResult()
end

# ─────────────────────────────────────────────────────────────────────────────
# Domain-specific helpers — payer mix
# ─────────────────────────────────────────────────────────────────────────────

"""
    check_payer_mix(mix::Dict{String,Float64}; tol=1e-6) -> ValidationResult

Validate that:
1. Every proportion is in [0, 1].
2. Proportions sum to 1.0 ± `tol`.
3. At least one payer is present.

Replaces duplicated logic in `validate_payer_mix` across `validation.jl` and
several finance modules.
"""
function check_payer_mix(
    mix::Dict{String, Float64};
    tol::Float64 = 1e-6,
)::ValidationResult
    errors = String[]

    isempty(mix) && push!(errors, "Payer mix must contain at least one payer")

    for (payer, share) in mix
        if !(0.0 <= share <= 1.0)
            push!(errors, "Payer '$payer' share must be in [0,1]; got $share")
        end
    end

    total = sum(values(mix); init = 0.0)
    if abs(total - 1.0) > tol
        push!(errors, "Payer mix shares must sum to 1.0 ± $tol; got $(@sprintf("%.6f", total))")
    end

    ValidationResult(errors)
end

# ─────────────────────────────────────────────────────────────────────────────
# Domain-specific helpers — financial fields
# ─────────────────────────────────────────────────────────────────────────────

"""
    check_financial_field(value, field_name; allow_negative=false) -> ValidationResult

Validate a dollar-valued financial field:
- Must be finite.
- Must be ≥ 0 unless `allow_negative = true` (e.g. net income, operating margin).
"""
function check_financial_field(
    value::Real,
    field_name::String;
    allow_negative::Bool = false,
)::ValidationResult
    r = check_finite(value, field_name)
    isvalid(r) || return r
    allow_negative ? r : check_non_negative(value, field_name)
end

"""
    check_rate(value, field_name; max_rate=5.0) -> ValidationResult

Validate a rate/multiplier field (e.g. inflation, cost-to-charge ratio).
Requires `value ≥ 0` and `value ≤ max_rate` (default 5.0, i.e. 500%).
"""
function check_rate(
    value::Real,
    field_name::String;
    max_rate::Float64 = 5.0,
)::ValidationResult
    merge_validations(
        check_finite(value, field_name),
        check_in_range(value, 0.0, max_rate, field_name),
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Domain-specific helpers — date / year
# ─────────────────────────────────────────────────────────────────────────────

"""
    check_fiscal_year(year; min_year=2000, max_year=2100) -> ValidationResult
"""
function check_fiscal_year(
    year::Integer;
    min_year::Int = 2000,
    max_year::Int = 2100,
)::ValidationResult
    check_integer_range(year, min_year, max_year, "fiscal_year")
end

"""
    check_date_range(start_date, end_date, field_prefix="") -> ValidationResult

Require `start_date < end_date`.
"""
function check_date_range(start_date, end_date, field_prefix::String = "")::ValidationResult
    pfx = isempty(field_prefix) ? "" : field_prefix * "_"
    start_date < end_date ? ValidationResult() :
        ValidationResult(["$(pfx)start_date must be before $(pfx)end_date; " *
                          "got $start_date >= $end_date"])
end

# ─────────────────────────────────────────────────────────────────────────────
# Bulk field validator
# ─────────────────────────────────────────────────────────────────────────────

"""
    check_fields(fields::Vector{Tuple{Real, String}};
                 allow_negative=false) -> ValidationResult

Validate multiple financial fields at once.

# Example
```julia
r = check_fields([
    (net_revenue, "net_revenue"),
    (total_expenses, "total_expenses"),
    (charity_care, "charity_care"),
])
validate!(r, "AnnualFinancials")
```
"""
function check_fields(
    fields::Vector{Tuple{T, String}} where T <: Real;
    allow_negative::Bool = false,
)::ValidationResult
    merge_validations([check_financial_field(v, n; allow_negative) for (v, n) in fields]...)
end

# Printf needed for check_payer_mix
using Printf
