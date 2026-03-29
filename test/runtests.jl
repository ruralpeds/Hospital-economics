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

    # Finance module tests
    include("test_ratios.jl")
    include("test_breakeven.jl")
    include("test_cashflow.jl")
    include("test_depreciation.jl")
    include("test_program340b.jl")
    include("test_sensitivity.jl")

    # V3.1 Finance module tests
    include("test_team_bundled.jl")
    include("test_telehealth.jl")
    include("test_vbc_transition.jl")
    include("test_medicaid_supplemental.jl")
    include("test_debt_capacity.jl")
    include("test_margin_decomposition.jl")
    include("test_rhc_optimization.jl")

    # Simulation engine tests
    include("test_des.jl")
    include("test_scenario_framework.jl")

    # Analysis module tests
    include("test_comparison.jl")
    include("test_community.jl")
    include("test_payer_negotiation.jl")
    include("test_benchmarks.jl")

    # V3.1 Analysis module tests
    include("test_sdoh.jl")
    include("test_geographic_access.jl")
    include("test_community_benefit.jl")
    include("test_network_economics.jl")

    # V3.1 Risk module tests
    include("test_closure_ml.jl")
    include("test_disaster_resilience.jl")

    # V3.1 Optimization module tests
    include("test_capital_scoring.jl")

    # Phase 4 — coverage gap tests
    include("test_reimbursement_functions.jl")
    include("test_monte_carlo_analytics.jl")
    include("test_data_import_export.jl")
    include("test_optimization_portfolio.jl")
    include("test_risk_assessment_extended.jl")

    # Integration & smoke tests
    include("test_integration.jl")
    include("test_view_integration.jl")
end
