# Simulation result types for Rural Hospital Economics Simulator

using Dates
using Statistics

"""
    MonteCarloResult <: AbstractSimulationResult

Results from a single Monte Carlo trial.
"""
@kwdef struct MonteCarloResult <: AbstractSimulationResult
    trial_id::Int
    random_seed::UInt64 = 0
    scenario_name::String = ""

    # Financial outcomes per year
    years::Vector{Int} = Int[]
    operating_margins::Vector{Float64} = Float64[]
    total_margins::Vector{Float64} = Float64[]
    net_revenues::Vector{Float64} = Float64[]
    total_expenses::Vector{Float64} = Float64[]
    cash_on_hand_days::Vector{Float64} = Float64[]
    debt_service_coverage::Vector{Float64} = Float64[]

    # Terminal state
    final_year_margin::Float64 = 0.0
    cumulative_operating_income::Float64 = 0.0
    is_closure::Bool = false
    closure_year::Union{Int, Nothing} = nothing
    is_conversion::Bool = false
    conversion_year::Union{Int, Nothing} = nothing
end

"""
    MonteCarloSummary

Aggregated summary statistics across all Monte Carlo trials.
"""
@kwdef struct MonteCarloSummary
    scenario_name::String = ""
    n_trials::Int = 0
    n_years::Int = 0

    # Margin distributions
    mean_operating_margin::Float64 = 0.0
    median_operating_margin::Float64 = 0.0
    std_operating_margin::Float64 = 0.0
    p5_operating_margin::Float64 = 0.0
    p25_operating_margin::Float64 = 0.0
    p75_operating_margin::Float64 = 0.0
    p95_operating_margin::Float64 = 0.0

    # Closure probability
    closure_probability::Float64 = 0.0
    mean_closure_year::Union{Float64, Nothing} = nothing
    conversion_probability::Float64 = 0.0

    # Cash flow
    mean_cumulative_income::Float64 = 0.0
    prob_negative_cumulative::Float64 = 0.0
    mean_min_cash_days::Float64 = 0.0

    # Year-by-year means
    annual_mean_margins::Vector{Float64} = Float64[]
    annual_closure_rates::Vector{Float64} = Float64[]
end

function Base.show(io::IO, mcs::MonteCarloSummary)
    print(io, "MonteCarloSummary(\"$(mcs.scenario_name)\", n=$(mcs.n_trials), closure_prob=$(round(mcs.closure_probability * 100, digits=1))%)")
end

"""
    SystemDynamicsResult <: AbstractSimulationResult

Time series output from a system dynamics (stock-and-flow) simulation.
"""
@kwdef struct SystemDynamicsResult <: AbstractSimulationResult
    scenario_name::String = ""
    time_points::Vector{Float64} = Float64[]  # in years

    # Stock variables over time
    population::Vector{Float64} = Float64[]
    pct_over_65::Vector{Float64} = Float64[]
    physician_supply::Vector{Float64} = Float64[]
    nurse_supply::Vector{Float64} = Float64[]
    inpatient_volume::Vector{Float64} = Float64[]
    outpatient_volume::Vector{Float64} = Float64[]
    ed_volume::Vector{Float64} = Float64[]
    cash_reserves::Vector{Float64} = Float64[]
    total_debt::Vector{Float64} = Float64[]
    net_assets::Vector{Float64} = Float64[]
    plant_age::Vector{Float64} = Float64[]

    # Flow / rate variables over time
    net_revenue::Vector{Float64} = Float64[]
    total_expenses::Vector{Float64} = Float64[]
    operating_margin::Vector{Float64} = Float64[]
    capital_spending::Vector{Float64} = Float64[]
    debt_service::Vector{Float64} = Float64[]

    # Equilibrium / tipping point analysis
    is_sustainable::Bool = true
    tipping_point_year::Union{Float64, Nothing} = nothing
    steady_state_margin::Union{Float64, Nothing} = nothing
end

function Base.show(io::IO, sdr::SystemDynamicsResult)
    t = isempty(sdr.time_points) ? 0.0 : last(sdr.time_points)
    print(io, "SystemDynamicsResult(\"$(sdr.scenario_name)\", t_max=$(t), sustainable=$(sdr.is_sustainable))")
end

"""
    StaffingOptimizationResult

Results from staffing mix and workforce optimization.
"""
@kwdef struct StaffingOptimizationResult
    scenario_name::String = ""
    objective_value::Float64 = 0.0  # minimized total cost or maximized coverage

    # Recommended staffing
    recommended_fte_by_category::Dict{Symbol, Float64} = Dict{Symbol, Float64}()
    recommended_travel_pct::Float64 = 0.0
    recommended_telehealth_pct::Float64 = 0.0

    # Financial impact
    total_compensation_cost::Float64 = 0.0
    travel_premium_cost::Float64 = 0.0
    recruitment_cost::Float64 = 0.0
    training_cost::Float64 = 0.0
    savings_vs_current::Float64 = 0.0

    # Workforce metrics
    projected_vacancy_rate::Float64 = 0.0
    projected_turnover_rate::Float64 = 0.0
    coverage_score::Float64 = 0.0  # 0-1, fraction of demand met
    quality_score::Float64 = 0.0   # 0-1, proxy for staffing quality

    # Constraints binding
    binding_constraints::Vector{String} = String[]
    infeasible::Bool = false
    infeasibility_reason::String = ""
end

function Base.show(io::IO, sor::StaffingOptimizationResult)
    status = sor.infeasible ? "INFEASIBLE" : "optimal"
    print(io, "StaffingOptimizationResult($(status), cost=\$$(round(Int, sor.total_compensation_cost)))")
end

"""
    PortfolioOptimizationResult

Results from service line portfolio optimization.
"""
@kwdef struct PortfolioOptimizationResult
    scenario_name::String = ""
    objective_value::Float64 = 0.0

    # Recommended portfolio
    active_service_lines::Vector{String} = String[]
    exited_service_lines::Vector{String} = String[]
    expanded_service_lines::Vector{String} = String[]

    # Financial projections
    projected_net_revenue::Float64 = 0.0
    projected_total_costs::Float64 = 0.0
    projected_operating_margin::Float64 = 0.0
    projected_contribution_margin::Float64 = 0.0

    # Community impact
    community_benefit_score::Float64 = 0.0
    services_lost_count::Int = 0
    population_affected::Int = 0
    nearest_alternative_miles::Dict{String, Float64} = Dict{String, Float64}()

    # Sensitivity
    margin_sensitivity::Dict{String, Float64} = Dict{String, Float64}()  # service_line -> marginal impact

    binding_constraints::Vector{String} = String[]
    infeasible::Bool = false
end

function Base.show(io::IO, por::PortfolioOptimizationResult)
    n_active = length(por.active_service_lines)
    print(io, "PortfolioOptimizationResult($(n_active) active, margin=$(round(por.projected_operating_margin * 100, digits=1))%)")
end

"""
    ClosureRiskAssessment

Comprehensive closure risk evaluation for a hospital.
"""
@kwdef struct ClosureRiskAssessment
    hospital_name::String = ""
    assessment_date::Date = Date(2025, 1, 1)

    # Risk scores (0.0 to 1.0)
    financial_risk_score::Float64 = 0.0
    operational_risk_score::Float64 = 0.0
    market_risk_score::Float64 = 0.0
    workforce_risk_score::Float64 = 0.0
    policy_risk_score::Float64 = 0.0
    composite_risk_score::Float64 = 0.0

    # Risk category
    risk_category::Symbol = :low  # :low, :moderate, :elevated, :high, :critical

    # Key risk drivers
    risk_drivers::Vector{String} = String[]
    mitigating_factors::Vector{String} = String[]

    # Probabilistic assessment
    closure_probability_1yr::Float64 = 0.0
    closure_probability_3yr::Float64 = 0.0
    closure_probability_5yr::Float64 = 0.0

    # Community impact if closed
    population_losing_access::Int = 0
    nearest_alternative_hospital_miles::Float64 = 0.0
    jobs_at_risk::Int = 0
    annual_economic_impact::Float64 = 0.0

    # Monte Carlo backing
    mc_summary::Union{MonteCarloSummary, Nothing} = nothing
end

function Base.show(io::IO, cra::ClosureRiskAssessment)
    print(io, "ClosureRiskAssessment(\"$(cra.hospital_name)\", risk=:$(cra.risk_category), p_close_3yr=$(round(cra.closure_probability_3yr * 100, digits=1))%)")
end

"""
    REHConversionAnalysis

Analysis of converting an existing hospital (typically CAH) to Rural Emergency Hospital status.
"""
@kwdef struct REHConversionAnalysis
    hospital_name::String = ""
    analysis_date::Date = Date(2025, 1, 1)
    conversion_params::Union{Any, Nothing} = nothing  # ConversionParams

    # Pre-conversion baseline
    pre_conversion_margin::Float64 = 0.0
    pre_conversion_net_revenue::Float64 = 0.0
    pre_conversion_total_costs::Float64 = 0.0
    pre_conversion_fte::Float64 = 0.0

    # Post-conversion projections
    post_conversion_margin::Float64 = 0.0
    post_conversion_net_revenue::Float64 = 0.0
    post_conversion_total_costs::Float64 = 0.0
    post_conversion_fte::Float64 = 0.0
    annual_facility_payment::Float64 = 0.0
    outpatient_revenue_change::Float64 = 0.0
    inpatient_revenue_lost::Float64 = 0.0

    # Net financial impact
    year_1_net_impact::Float64 = 0.0
    year_3_cumulative_impact::Float64 = 0.0
    year_5_cumulative_impact::Float64 = 0.0
    breakeven_year::Union{Int, Nothing} = nothing

    # One-time costs
    conversion_costs::Float64 = 0.0
    severance_costs::Float64 = 0.0
    capital_repurposing_costs::Float64 = 0.0

    # Community impact
    inpatient_transfers_annual::Int = 0
    avg_transfer_distance_miles::Float64 = 0.0
    services_eliminated::Vector{String} = String[]
    services_retained::Vector{String} = String[]
    jobs_eliminated::Int = 0

    # Recommendation
    is_recommended::Bool = false
    recommendation_rationale::String = ""
    alternative_strategies::Vector{String} = String[]
end

function Base.show(io::IO, rca::REHConversionAnalysis)
    rec = rca.is_recommended ? "RECOMMENDED" : "NOT recommended"
    print(io, "REHConversionAnalysis(\"$(rca.hospital_name)\", $(rec), y1_impact=\$$(round(Int, rca.year_1_net_impact)))")
end
