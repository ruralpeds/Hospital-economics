"""
Test environment configuration.
"""
using Genie

Genie.config.run_as_server = false
Genie.config.server_port = 8888
Genie.config.server_host = "127.0.0.1"

Genie.config.log_level = Logging.Info
Genie.config.log_to_file = false
Genie.config.watch = false

# In-memory or test database
ENV["HOSPITAL_DB_URL"] = "sqlite://:memory:"

# Small iteration limits for fast tests
ENV["SIM_MAX_ITERATIONS"] = "100"
ENV["SIM_DEFAULT_ITERATIONS"] = "50"
ENV["SIM_TIMEOUT_SECONDS"] = "30"

@info "Test environment loaded"
