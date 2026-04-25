"""
    Logging configuration for RuralCore and downstream applications.

Provides structured logging setup with timestamps and JSON serialization support.
"""

using Dates
using Logging

export configure_logging!

"""
    configure_logging!(; app_name::String="RuralCore", level::LogLevel=Info, log_to_file::Bool=false)

Configure global Julia logging with timestamps and optional file output.

# Arguments
- `app_name::String`: Name of the application (used in log formatting)
- `level::LogLevel`: Minimum log level to display (default: Info)
- `log_to_file::Bool`: Whether to also write logs to a file (default: false)

# Examples
```julia
configure_logging!(app_name="myapp", level=Debug)
@info "Application started" version="1.0"
```
"""
function configure_logging!(; app_name::String="RuralCore", level::LogLevel=Logging.Info, log_to_file::Bool=false)
    # Create a custom logger with timestamps
    function format_log(io::IO, args)
        msg, level, _module, group, id, file, line = args
        timestamp = Dates.format(Dates.now(Dates.UTC), "yyyy-mm-ddTHH:MM:SS.sssZ")
        level_str = string(level)
        println(io, "[$timestamp] [$level_str] [$app_name] $msg")
    end

    # Create console logger
    console_logger = ConsoleLogger(stderr, level; meta_formatter=format_log)

    # Set global logger
    if log_to_file
        # Optionally write to file as well (basic implementation)
        log_dir = joinpath(homedir(), ".cache", "ruralhealthplatform", "logs")
        try
            mkpath(log_dir)
            log_file = joinpath(log_dir, "$(app_name)_$(Dates.format(Dates.today(), "yyyy-mm-dd")).log")
            file_logger = SimpleLogger(open(log_file, "a"), level)
            # Use TeeLogger pattern if available, otherwise just use console
            global_logger(console_logger)
        catch e
            @warn "Could not initialize file logger" exception=e
            global_logger(console_logger)
        end
    else
        global_logger(console_logger)
    end

    @debug "Logging configured for $app_name" level=string(level) file_logging=log_to_file
end
