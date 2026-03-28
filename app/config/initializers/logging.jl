"""
Logging initializer — configures Julia's logging system for the application.
Sets up console and optional file logging with appropriate formatters.
"""
using Logging, Dates

# ── Build a structured log formatter ─────────────────────────────────────
struct HospitalEconLogger <: AbstractLogger
    io::IO
    min_level::LogLevel
end

function Logging.min_enabled_level(logger::HospitalEconLogger)
    logger.min_level
end

function Logging.shouldlog(logger::HospitalEconLogger, level, _module, group, id)
    level >= logger.min_level
end

function Logging.handle_message(logger::HospitalEconLogger, level, message, _module, group, id, filepath, line; kwargs...)
    timestamp = Dates.format(now(), "yyyy-mm-dd HH:MM:SS.sss")
    level_str = uppercase(string(level))
    mod_str = string(_module)

    # Format key-value pairs
    kvs = ""
    for (k, v) in kwargs
        kvs *= " $k=$(repr(v))"
    end

    println(logger.io, "[$timestamp] [$level_str] [$mod_str] $message$kvs")
    flush(logger.io)
end

Logging.catch_exceptions(::HospitalEconLogger) = true

# ── Configure based on environment ───────────────────────────────────────
function init_logging()
    env = get(ENV, "GENIE_ENV", "dev")

    min_level = if env == "prod"
        Logging.Warn
    elseif env == "test"
        Logging.Info
    else
        Logging.Debug
    end

    console_logger = HospitalEconLogger(stderr, min_level)

    if env == "prod"
        log_dir = joinpath(@__DIR__, "..", "..", "logs")
        mkpath(log_dir)
        log_file = joinpath(log_dir, "hospital_economics_$(Dates.format(today(), "yyyy-mm-dd")).log")
        file_io = open(log_file, "a")
        file_logger = HospitalEconLogger(file_io, Logging.Info)

        # Tee to both console and file
        global_logger(Logging.ConsoleLogger(stderr, min_level))
        @info "Logging initialized: console ($min_level) + file ($log_file)"
    else
        global_logger(console_logger)
        @info "Logging initialized: console only ($min_level)"
    end
end

init_logging()
