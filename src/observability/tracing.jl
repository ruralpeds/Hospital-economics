"""
Lightweight distributed tracing foundation for the Rural Hospital Economics Simulator.

Provides a span-based tracing model compatible with OpenTelemetry concepts
(trace_id, span_id, parent_span_id, attributes) without pulling in a full
OTel SDK.  Completed spans are logged as structured JSON via
[`StructuredLogger`](@ref) so they can be forwarded to Jaeger / OTLP
collectors later.

# Public API
- `SpanContext` / `ActiveSpan` — span data types
- `start_span(operation; attributes)` — begin a new span
- `end_span!(span; status)` — finish a span and log it
- `@traced(operation, expr)` — convenience macro with automatic error handling
- `current_trace_id()` — trace ID from the active span or a fresh one
- `span_to_dict(span)` — export a span as a plain `Dict`
"""
module Tracing

using Dates, Random

# We reference StructuredLogger from the parent scope (both modules are
# `include`d into the same enclosing module / Main).  The import is deferred
# so this file can be loaded before or after structured_logger.jl — the
# functions are resolved at call time.
# If StructuredLogger is not available, spans are still tracked but not
# automatically logged to the structured log file.

export SpanContext, ActiveSpan
export start_span, end_span!
export @traced
export current_trace_id, span_to_dict

# ═══════════════════════════════════════════════════════════════════════════
# Span types
# ═══════════════════════════════════════════════════════════════════════════

"""
Immutable snapshot of the identifiers and metadata captured when a span
is created.
"""
struct SpanContext
    trace_id::String
    span_id::String
    parent_span_id::Union{String, Nothing}
    operation::String
    start_time::DateTime
    attributes::Dict{String, Any}
end

"""
Mutable wrapper around a [`SpanContext`](@ref) that accumulates runtime
state (end time, final status) until the span is finished.
"""
mutable struct ActiveSpan
    context::SpanContext
    end_time::Union{DateTime, Nothing}
    status::String
end

# ═══════════════════════════════════════════════════════════════════════════
# Span stack (task-local approximation via a global vector)
# ═══════════════════════════════════════════════════════════════════════════

"""Stack of in-flight spans; the last element is the innermost active span."""
const SPAN_STACK = Vector{ActiveSpan}()

# ═══════════════════════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════════════════════

"""Generate a 32-hex-char random ID (same format as StructuredLogger UUIDs)."""
function _generate_id()::String
    bytes = rand(Random.default_rng(), UInt8, 16)
    return bytes2hex(bytes)
end

# ═══════════════════════════════════════════════════════════════════════════
# Core API
# ═══════════════════════════════════════════════════════════════════════════

"""
    start_span(operation::String; attributes::Dict{String,Any}=Dict{String,Any}())::ActiveSpan

Create a new span for `operation`, inheriting the trace ID and parent span ID
from the current top of the [`SPAN_STACK`](@ref).  The span is pushed onto
the stack and returned.
"""
function start_span(operation::String;
                    attributes::Dict{String, Any}=Dict{String, Any}())::ActiveSpan
    # Inherit trace context from the stack or from StructuredLogger
    parent = isempty(SPAN_STACK) ? nothing : last(SPAN_STACK)

    trace_id = if parent !== nothing
        parent.context.trace_id
    else
        # Try to inherit from the StructuredLogger correlation context
        try
            ctx = Main.StructuredLogger.CURRENT_CONTEXT[]
            ctx !== nothing ? ctx.trace_id : _generate_id()
        catch
            _generate_id()
        end
    end

    parent_span_id = parent !== nothing ? parent.context.span_id : nothing
    span_id = _generate_id()

    sc = SpanContext(trace_id, span_id, parent_span_id, operation,
                     now(UTC), attributes)
    span = ActiveSpan(sc, nothing, "unset")
    push!(SPAN_STACK, span)
    return span
end

"""
    end_span!(span::ActiveSpan; status::String="ok")

Mark `span` as finished, pop it from the [`SPAN_STACK`](@ref), and emit a
structured log line containing the span data and duration.
"""
function end_span!(span::ActiveSpan; status::String="ok")
    span.end_time = now(UTC)
    span.status = status

    # Pop from the stack (find by identity, not just last, for safety)
    idx = findlast(s -> s === span, SPAN_STACK)
    if idx !== nothing
        deleteat!(SPAN_STACK, idx)
    end

    # Calculate duration
    duration_ms = Dates.value(span.end_time - span.context.start_time)

    # Log via StructuredLogger if available
    try
        Main.StructuredLogger.log_structured(:info, "span_end"; extra=Dict{String,Any}(
            "span_operation"  => span.context.operation,
            "span_trace_id"   => span.context.trace_id,
            "span_span_id"    => span.context.span_id,
            "span_parent_id"  => something(span.context.parent_span_id, ""),
            "span_status"     => span.status,
            "span_duration_ms" => duration_ms,
            "span_attributes" => span.context.attributes,
        ))
    catch
        # StructuredLogger not available — silent fallback
        @debug "Span completed" operation=span.context.operation duration_ms=duration_ms status=span.status
    end

    return nothing
end

# ═══════════════════════════════════════════════════════════════════════════
# @traced macro
# ═══════════════════════════════════════════════════════════════════════════

"""
    @traced(operation, expr)

Wrap `expr` in a [`start_span`](@ref) / [`end_span!`](@ref) pair.  If `expr`
throws, the span is ended with `status="error"` and the exception is
re-raised.

# Example
```julia
result = @traced "db_query" begin
    run_expensive_query()
end
```
"""
macro traced(operation, expr)
    return quote
        local _span = start_span($(esc(operation)))
        local _result
        try
            _result = $(esc(expr))
            end_span!(_span; status="ok")
        catch _e
            end_span!(_span; status="error")
            rethrow(_e)
        end
        _result
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# Utility functions
# ═══════════════════════════════════════════════════════════════════════════

"""
    current_trace_id()::String

Return the trace ID from the innermost active span, falling back to the
StructuredLogger correlation context, or generating a fresh ID if neither
is available.
"""
function current_trace_id()::String
    if !isempty(SPAN_STACK)
        return last(SPAN_STACK).context.trace_id
    end
    # Fallback: StructuredLogger context
    try
        ctx = Main.StructuredLogger.CURRENT_CONTEXT[]
        if ctx !== nothing
            return ctx.trace_id
        end
    catch; end
    return _generate_id()
end

"""
    span_to_dict(span::ActiveSpan)::Dict{String, Any}

Convert an [`ActiveSpan`](@ref) into a plain dictionary suitable for JSON
serialisation or export to an OTLP collector.
"""
function span_to_dict(span::ActiveSpan)::Dict{String, Any}
    d = Dict{String, Any}(
        "trace_id"       => span.context.trace_id,
        "span_id"        => span.context.span_id,
        "parent_span_id" => span.context.parent_span_id,
        "operation"      => span.context.operation,
        "start_time"     => Dates.format(span.context.start_time, dateformat"yyyy-mm-ddTHH:MM:SS.sssZ"),
        "attributes"     => span.context.attributes,
        "status"         => span.status,
    )
    if span.end_time !== nothing
        d["end_time"]    = Dates.format(span.end_time, dateformat"yyyy-mm-ddTHH:MM:SS.sssZ")
        d["duration_ms"] = Dates.value(span.end_time - span.context.start_time)
    end
    return d
end

end # module Tracing
