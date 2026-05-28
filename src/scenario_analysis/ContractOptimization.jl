# ============================================================================
# CONTRACT OPTIMIZATION (Module 7)
# ============================================================================
# Payer contract portfolio optimization: select and weight a mix of contracts
# to maximise expected revenue (or margin) while respecting risk, volume, and
# diversification constraints.  Uses JuMP + HiGHS for the underlying LP/MIP.
# ============================================================================

using JuMP
using HiGHS
using Statistics

# ============================================================================
# CONFIGURATION
# ============================================================================

"""
    ContractOptimizationConfig

Parameters controlling the contract portfolio optimisation.

# Fields
- `objective::Symbol`: `:maximize_margin`, `:maximize_revenue`, or `:minimize_risk`
- `max_contracts::Int`: maximum number of contracts in the portfolio
- `min_volume_per_contract::Int`: minimum annual volume assigned to any selected contract
- `max_volume_per_contract::Int`: maximum annual volume for any single contract
- `total_volume::Int`: total patient volume to allocate across contracts
- `max_single_payer_share::Float64`: diversification cap (e.g., 0.40 = no payer > 40 %)
- `min_quality_score::Float64`: minimum quality score threshold (0-1)
- `risk_tolerance::Float64`: maximum acceptable portfolio-level risk (std-dev of margin as fraction of expected margin; e.g. 0.25)
- `projection_years::Int`: horizon for financial projections (default 3)
- `discount_rate::Float64`: discount rate for NPV (default 0.03)
"""
struct ContractOptimizationConfig
    objective::Symbol
    max_contracts::Int
    min_volume_per_contract::Int
    max_volume_per_contract::Int
    total_volume::Int
    max_single_payer_share::Float64
    min_quality_score::Float64
    risk_tolerance::Float64
    projection_years::Int
    discount_rate::Float64
end

function ContractOptimizationConfig(;
    objective::Symbol = :maximize_margin,
    max_contracts::Int = 5,
    min_volume_per_contract::Int = 100,
    max_volume_per_contract::Int = 5000,
    total_volume::Int = 3000,
    max_single_payer_share::Float64 = 0.40,
    min_quality_score::Float64 = 0.70,
    risk_tolerance::Float64 = 0.25,
    projection_years::Int = 3,
    discount_rate::Float64 = 0.03,
)
    ContractOptimizationConfig(
        objective, max_contracts,
        min_volume_per_contract, max_volume_per_contract,
        total_volume, max_single_payer_share, min_quality_score,
        risk_tolerance, projection_years, discount_rate,
    )
end

function Base.show(io::IO, c::ContractOptimizationConfig)
    print(io, "ContractOptimizationConfig($(c.objective), vol=$(c.total_volume), max=$(c.max_contracts))")
end

# ============================================================================
# RESULT TYPE
# ============================================================================

"""
    OptimizedContractPortfolio

Result of a contract portfolio optimisation run.

# Fields
- `selected_contracts::Vector{PayerContract}`: contracts chosen for the portfolio
- `volume_allocation::Vector{Int}`: volume allocated to each selected contract
- `volume_share::Vector{Float64}`: fraction of total volume per contract
- `expected_annual_revenue::Float64`: portfolio-level expected annual revenue (USD)
- `expected_annual_cost::Float64`: portfolio-level expected annual cost (USD)
- `expected_annual_margin::Float64`: expected margin (revenue - cost)
- `expected_npv::Float64`: NPV of margin over the projection horizon
- `portfolio_risk::Float64`: standard deviation of projected margin
- `diversification_score::Float64`: Herfindahl-Hirschman-based diversification (0-1, higher = more diverse)
- `solver_status::String`: optimiser termination status
- `config::ContractOptimizationConfig`: config used for the run
"""
struct OptimizedContractPortfolio
    selected_contracts::Vector{PayerContract}
    volume_allocation::Vector{Int}
    volume_share::Vector{Float64}
    expected_annual_revenue::Float64
    expected_annual_cost::Float64
    expected_annual_margin::Float64
    expected_npv::Float64
    portfolio_risk::Float64
    diversification_score::Float64
    solver_status::String
    config::ContractOptimizationConfig
end

function Base.show(io::IO, p::OptimizedContractPortfolio)
    n = length(p.selected_contracts)
    margin_k = round(p.expected_annual_margin / 1000; digits=0)
    print(io, "OptimizedContractPortfolio($(n) contracts, margin=\$$(margin_k)K, risk=$(round(p.portfolio_risk, digits=3)))")
end

# ============================================================================
# OPTIMISATION ENTRY POINT
# ============================================================================

"""
    optimize_contract_portfolio(
        candidate_contracts::Vector{PayerContract},
        scenarios::Vector{HealthcareScenario},
        config::ContractOptimizationConfig;
        base_cost_per_case::Float64 = 12000.0,
        base_quality_score::Float64 = 0.80
    )::OptimizedContractPortfolio

Select and weight a subset of `candidate_contracts` to build a portfolio that
optimises the chosen objective (margin, revenue, or risk) subject to volume,
diversification, and quality constraints.

The function evaluates each candidate contract across the supplied
`scenarios`, computes expected margin and risk (standard deviation of margin
across scenarios), then solves a mixed-integer program to allocate volume.

# Arguments
- `candidate_contracts`: pool of available payer contracts
- `scenarios`: healthcare scenarios for projection (typically optimistic / base / pessimistic)
- `config`: optimisation configuration
- `base_cost_per_case`: starting average cost per case
- `base_quality_score`: starting quality metric (0-1)

# Returns
An `OptimizedContractPortfolio` with the optimal allocation, expected
financials, and solver status.
"""
function optimize_contract_portfolio(
    candidate_contracts::Vector{PayerContract},
    scenarios::Vector{HealthcareScenario},
    config::ContractOptimizationConfig;
    base_cost_per_case::Float64 = 12000.0,
    base_quality_score::Float64 = 0.80
)::OptimizedContractPortfolio

    n = length(candidate_contracts)
    n == 0 && error("candidate_contracts must not be empty")

    # ── 1. Evaluate each contract across scenarios ──────────────────────
    # For each contract i and scenario s, compute annual margin per case.
    margin_per_case = Matrix{Float64}(undef, n, length(scenarios))
    revenue_per_case = Matrix{Float64}(undef, n, length(scenarios))

    for (i, contract) in enumerate(candidate_contracts)
        for (s, scenario) in enumerate(scenarios)
            proj = project_contract_under_scenario(
                contract, scenario;
                base_volume = 1000,
                base_cost_per_case = base_cost_per_case,
                base_quality_score = base_quality_score,
            )
            avg_rev = length(proj.annual_revenue) > 0 ? mean(proj.annual_revenue) / 1000.0 : 0.0
            avg_cost = length(proj.annual_costs) > 0 ? mean(proj.annual_costs) / 1000.0 : 0.0
            revenue_per_case[i, s] = avg_rev
            margin_per_case[i, s] = avg_rev - avg_cost
        end
    end

    # Probability-weighted expected margin and risk per case
    probs = [sc.probability for sc in scenarios]
    prob_sum = sum(probs)
    w = prob_sum > 0.0 ? probs ./ prob_sum : fill(1.0 / length(scenarios), length(scenarios))

    expected_margin = [sum(margin_per_case[i, s] * w[s] for s in eachindex(scenarios)) for i in 1:n]
    expected_revenue = [sum(revenue_per_case[i, s] * w[s] for s in eachindex(scenarios)) for i in 1:n]

    margin_risk = Float64[]
    for i in 1:n
        vals = [margin_per_case[i, s] for s in eachindex(scenarios)]
        push!(margin_risk, length(vals) > 1 ? std(vals) : 0.0)
    end

    # ── 2. Build optimisation model ─────────────────────────────────────
    model = Model(HiGHS.Optimizer)
    set_silent(model)

    # Decision variables
    @variable(model, x[1:n] >= 0, Int)   # volume allocated to contract i
    @variable(model, y[1:n], Bin)          # 1 if contract i is selected

    # ── Constraints ─────────────────────────────────────────────────────

    # Total volume
    @constraint(model, sum(x[i] for i in 1:n) == config.total_volume)

    # Link x to y (big-M formulation)
    for i in 1:n
        @constraint(model, x[i] <= config.max_volume_per_contract * y[i])
        @constraint(model, x[i] >= config.min_volume_per_contract * y[i])
    end

    # Max number of contracts
    @constraint(model, sum(y[i] for i in 1:n) <= config.max_contracts)

    # Diversification: no single contract > max_single_payer_share of total volume
    for i in 1:n
        @constraint(model, x[i] <= config.max_single_payer_share * config.total_volume)
    end

    # ── Objective ───────────────────────────────────────────────────────
    if config.objective == :maximize_margin
        @objective(model, Max, sum(expected_margin[i] * x[i] for i in 1:n))
    elseif config.objective == :maximize_revenue
        @objective(model, Max, sum(expected_revenue[i] * x[i] for i in 1:n))
    elseif config.objective == :minimize_risk
        # Minimise weighted risk; use margin-risk per case * volume as proxy
        @objective(model, Min, sum(margin_risk[i] * x[i] for i in 1:n))
    else
        error("Unknown objective: $(config.objective)")
    end

    # ── 3. Solve ────────────────────────────────────────────────────────
    optimize!(model)
    status = string(termination_status(model))

    # ── 4. Extract solution ─────────────────────────────────────────────
    selected_contracts = PayerContract[]
    volume_allocation = Int[]
    volume_share = Float64[]

    for i in 1:n
        vol = Int(round(value(x[i])))
        if vol > 0
            push!(selected_contracts, candidate_contracts[i])
            push!(volume_allocation, vol)
            push!(volume_share, vol / config.total_volume)
        end
    end

    # Portfolio-level financials
    total_revenue = sum(
        expected_revenue[findfirst(==(c), candidate_contracts)] * v
        for (c, v) in zip(selected_contracts, volume_allocation)
    )
    total_cost = sum(
        (expected_revenue[findfirst(==(c), candidate_contracts)] -
         expected_margin[findfirst(==(c), candidate_contracts)]) * v
        for (c, v) in zip(selected_contracts, volume_allocation)
    )
    total_margin = total_revenue - total_cost

    # NPV of margin over projection horizon
    npv = sum(total_margin / (1.0 + config.discount_rate)^yr for yr in 1:config.projection_years)

    # Portfolio risk: weighted sum of per-contract risk
    port_risk = if !isempty(selected_contracts)
        total_vol = sum(volume_allocation)
        total_vol > 0 ? sum(
            margin_risk[findfirst(==(c), candidate_contracts)] * (v / total_vol)
            for (c, v) in zip(selected_contracts, volume_allocation)
        ) : 0.0
    else
        0.0
    end

    # Diversification score: 1 - normalized HHI (higher = more diversified)
    hhi = sum(s^2 for s in volume_share)
    diversification = isempty(volume_share) ? 0.0 : 1.0 - hhi

    return OptimizedContractPortfolio(
        selected_contracts,
        volume_allocation,
        volume_share,
        total_revenue,
        total_cost,
        total_margin,
        npv,
        port_risk,
        diversification,
        status,
        config,
    )
end
