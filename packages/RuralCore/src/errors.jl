"""
    RuralHealthError

Base exception type for all RuralHealthPlatform domain errors.
All custom exceptions should inherit from this type.
"""
abstract type RuralHealthError <: Exception end

"""
    DataValidationError(message::String)
    DataValidationError(field::String, value::String, constraint::String, message::String)

Thrown when input data fails validation (missing columns, wrong types, etc.).
"""
struct DataValidationError <: RuralHealthError
    field::Union{String, Nothing}
    value::Union{String, Nothing}
    constraint::Union{String, Nothing}
    message::String
end

DataValidationError(msg::String) = DataValidationError(nothing, nothing, nothing, msg)

"""
    DomainValidationError(field::String, value::String, constraint::String, message::String)

Thrown when business rule constraints are violated.
"""
struct DomainValidationError <: RuralHealthError
    field::String
    value::String
    constraint::String
    message::String
end

"""
    DataIOError(message::String)

Thrown when file/database read-write operations fail.
"""
struct DataIOError <: RuralHealthError
    message::String
end

"""
    ConfigurationError(message::String)

Thrown when required configuration is missing or invalid.
"""
struct ConfigurationError <: RuralHealthError
    message::String
end

"""
    NetworkError(message::String)

Thrown when HTTP/connection operations fail.
"""
struct NetworkError <: RuralHealthError
    message::String
end

"""
    StateError(message::String)

Thrown when component state is invalid for the requested operation.
"""
struct StateError <: RuralHealthError
    message::String
end

"""
    CalculationError(message::String)

Thrown when mathematical computations produce invalid results (NaN, Inf, etc.).
"""
struct CalculationError <: RuralHealthError
    message::String
end

"""
    AuditError(message::String)

Thrown when audit logging operations fail.
"""
struct AuditError <: RuralHealthError
    message::String
end

"""
    InsufficientSampleError(n::Int, minimum::Int)

Thrown when sample size is too small for statistical operations.
"""
struct InsufficientSampleError <: RuralHealthError
    n::Int
    minimum::Int
    message::String
end

InsufficientSampleError(n::Int, min::Int) = InsufficientSampleError(n, min, "Need n≥$min, got n=$n")

"""
    StatisticalAssumptionError(message::String)

Thrown when statistical assumptions are violated.
"""
struct StatisticalAssumptionError <: RuralHealthError
    message::String
end

"""
    ConvergenceError(message::String)

Thrown when iterative algorithms fail to converge.
"""
struct ConvergenceError <: RuralHealthError
    message::String
end

"""
    FormulaParseError(message::String)

Thrown when formula syntax cannot be parsed.
"""
struct FormulaParseError <: RuralHealthError
    message::String
end

"""
    NotImplementedError(message::String)

Thrown when a feature requires an unloaded extension or is not yet implemented.
"""
struct NotImplementedError <: RuralHealthError
    message::String
end

InsufficientSampleError(msg::String) = InsufficientSampleError(0, 0, msg)
InsufficientSampleError(context::String, requirement::String) = InsufficientSampleError(0, 0, "$context — $requirement")

# Custom error display
Base.showerror(io::IO, e::DataValidationError) = print(io, "DataValidationError: ", e.message)
Base.showerror(io::IO, e::DomainValidationError) = print(io, "DomainValidationError (", e.field, "): ", e.message)
Base.showerror(io::IO, e::DataIOError) = print(io, "DataIOError: ", e.message)
Base.showerror(io::IO, e::ConfigurationError) = print(io, "ConfigurationError: ", e.message)
Base.showerror(io::IO, e::NetworkError) = print(io, "NetworkError: ", e.message)
Base.showerror(io::IO, e::StateError) = print(io, "StateError: ", e.message)
Base.showerror(io::IO, e::CalculationError) = print(io, "CalculationError: ", e.message)
Base.showerror(io::IO, e::AuditError) = print(io, "AuditError: ", e.message)
Base.showerror(io::IO, e::InsufficientSampleError) = print(io, "InsufficientSampleError: ", e.message)
Base.showerror(io::IO, e::StatisticalAssumptionError) = print(io, "StatisticalAssumptionError: ", e.message)
Base.showerror(io::IO, e::ConvergenceError) = print(io, "ConvergenceError: ", e.message)
Base.showerror(io::IO, e::FormulaParseError) = print(io, "FormulaParseError: ", e.message)
Base.showerror(io::IO, e::NotImplementedError) = print(io, "NotImplementedError: ", e.message)
