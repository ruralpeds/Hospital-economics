"""
Platform configuration and service port assignments.
"""

"""
    PlatformConfig

Configuration for all services in the platform.
"""
@kwdef struct PlatformConfig
    portal_port::Int = 8080
    biostatistics_port::Int = 8081
    finance_port::Int = 8082
    quality_port::Int = 8083
    geospatial_port::Int = 8084
    nginx_port::Int = 80
    environment::String = "development"
    log_level::String = "info"
    debug::Bool = false
end

const PLATFORM_CONFIG = PlatformConfig()

"""
    get_config()::PlatformConfig

Get current platform configuration.
"""
function get_config()::PlatformConfig
    PLATFORM_CONFIG
end
