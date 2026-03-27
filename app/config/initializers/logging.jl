# Logging initialization
using Logging

function setup_logging()
    logger = ConsoleLogger(stderr, Logging.Info)
    global_logger(logger)
    @info "Logging initialized for Rural Hospital Economics Simulator"
end
