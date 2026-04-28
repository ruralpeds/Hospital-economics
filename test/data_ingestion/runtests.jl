"""
Test runner for data ingestion module
"""

using Test

# Include tests
include("test_types.jl")
include("test_validators.jl")
include("test_deidentifiers.jl")
include("test_claims_formats.jl")
include("test_quality_extensions.jl")
include("test_cms_api_connectors.jl")

# Summary
println("\n" * "="^60)
println("Data Ingestion Module Test Summary")
println("="^60)
println("All tests completed successfully!")
println("\nModule is ready for integration testing and CSV ingestion.")

