# ============================================================================
# Rural Hospital Economics Simulator — Test Harness
# ============================================================================

using Test

@testset "RuralHospitalSim Tests" begin
    include("test_types.jl")
    include("test_reimbursement.jl")
    include("test_deterministic.jl")
    include("test_monte_carlo.jl")
    include("test_agent_based.jl")
    include("test_system_dynamics.jl")
    include("test_optimization.jl")
    include("test_closure_risk.jl")
    include("test_reh_conversion.jl")
    include("test_hcris_parser.jl")
end
