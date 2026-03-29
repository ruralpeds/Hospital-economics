"""
Production environment configuration.
"""
using Genie

Genie.config.run_as_server = true
Genie.config.server_port = parse(Int, get(ENV, "PORT", "8080"))
Genie.config.server_host = "0.0.0.0"

# Restricted logging
Genie.config.log_level = Logging.Warn
Genie.config.log_to_file = true

# No auto-reload
Genie.config.watch = false

# CORS — restrict in production
Genie.config.cors_headers["Access-Control-Allow-Origin"] = get(ENV, "ALLOWED_ORIGIN", "https://hospital-economics.example.com")
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET, POST"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"

# Static file caching
Genie.config.cache_static_files = true

# Database
ENV["HOSPITAL_DB_URL"] = get(ENV, "HOSPITAL_DB_URL", "postgresql://localhost/hospital_economics_prod")

# Simulation limits
ENV["SIM_MAX_ITERATIONS"] = "50000"
ENV["SIM_DEFAULT_ITERATIONS"] = "5000"
ENV["SIM_TIMEOUT_SECONDS"] = "600"

# Security — SECRET_TOKEN is mandatory in production
Genie.config.session_key_name = "__hospital_econ_session"
if !haskey(ENV, "SECRET_TOKEN") || isempty(ENV["SECRET_TOKEN"])
    error("SECRET_TOKEN environment variable is required in production. " *
          "Generate one with: julia -e 'using Random; println(randstring(64))'")
end
Genie.config.secret_token = ENV["SECRET_TOKEN"]

@info "Production environment loaded"
