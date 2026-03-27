"""
Development environment configuration.
"""
using Genie

Genie.config.run_as_server = true
Genie.config.server_port = 8000
Genie.config.server_host = "0.0.0.0"

# Verbose logging in development
Genie.config.log_level = Logging.Debug
Genie.config.log_to_file = false

# Auto-reload templates
Genie.config.watch = true

# CORS for local development
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "*"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"

# Cache settings — disable in dev
Genie.config.cache_static_files = false

# Database (placeholder — swap for real connection string)
ENV["HOSPITAL_DB_URL"] = get(ENV, "HOSPITAL_DB_URL", "sqlite:///data/hospital_economics_dev.db")

# Simulation defaults
ENV["SIM_MAX_ITERATIONS"] = "10000"
ENV["SIM_DEFAULT_ITERATIONS"] = "1000"
ENV["SIM_TIMEOUT_SECONDS"] = "300"

@info "Development environment loaded"
