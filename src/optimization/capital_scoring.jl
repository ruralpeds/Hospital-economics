# ============================================================================
# MCDA Capital Replacement Scoring — weighted multi-criteria scoring,
# budget-constrained selection, and replacement priority reporting.
# ============================================================================

"""A capital project request with scoring attributes across multiple criteria."""
@kwdef struct CapitalRequest
    project_name::String
    category::Symbol                 = :maintenance  # :safety, :revenue, :efficiency, :strategic, :maintenance
    estimated_cost::Float64          = 0.0
    safety_compliance_score::Float64 = 0.0           # 0-1
    revenue_impact_annual::Float64   = 0.0
    failure_risk_score::Float64      = 0.0           # 0-1
    strategic_alignment_score::Float64 = 0.0         # 0-1
    efficiency_gain_annual::Float64  = 0.0
    useful_life_years::Int           = 10
end

"""Result of capital project scoring and budget-constrained selection."""
@kwdef struct CapitalScoreResult
    projects::Vector{CapitalRequest}
    scores::Vector{Float64}
    rankings::Vector{Int}
    selected_projects::Vector{String}
    total_cost_selected::Float64
    total_annual_benefit::Float64
    budget_utilization::Float64
end

const DEFAULT_CAPITAL_WEIGHTS = (
    safety     = 0.30,
    revenue    = 0.25,
    condition  = 0.20,
    strategic  = 0.15,
    efficiency = 0.10,
)

"""
    score_capital_projects(projects; weights) -> Vector{NamedTuple}

MCDA weighted scoring across safety, revenue, condition, strategic, and
efficiency criteria. Returns `(project_name, weighted_score, rank)`.
"""
function score_capital_projects(projects::Vector{CapitalRequest};
                                weights::NamedTuple=DEFAULT_CAPITAL_WEIGHTS)::Vector{NamedTuple}
    n = length(projects)
    n == 0 && return NamedTuple[]

    # Normalize revenue and efficiency to 0-1 using max across projects
    max_revenue    = max(maximum(p.revenue_impact_annual for p in projects), 1.0)
    max_efficiency = max(maximum(p.efficiency_gain_annual for p in projects), 1.0)

    scores = Float64[]
    for p in projects
        norm_revenue    = clamp(p.revenue_impact_annual / max_revenue, 0.0, 1.0)
        norm_efficiency = clamp(p.efficiency_gain_annual / max_efficiency, 0.0, 1.0)

        weighted = weights.safety     * p.safety_compliance_score +
                   weights.revenue    * norm_revenue +
                   weights.condition  * p.failure_risk_score +
                   weights.strategic  * p.strategic_alignment_score +
                   weights.efficiency * norm_efficiency

        push!(scores, round(weighted, digits=4))
    end

    # Rank by score descending
    ranked_indices = sortperm(scores, rev=true)
    rankings = zeros(Int, n)
    for (rank, idx) in enumerate(ranked_indices)
        rankings[idx] = rank
    end

    return [(
        project_name  = projects[i].project_name,
        weighted_score = scores[i],
        rank           = rankings[i],
    ) for i in 1:n]
end

"""
    select_within_budget(projects, budget; weights) -> CapitalScoreResult

Greedy knapsack: rank by MCDA score, select until budget exhausted.
"""
function select_within_budget(projects::Vector{CapitalRequest}, budget::Float64;
                              weights::NamedTuple=DEFAULT_CAPITAL_WEIGHTS)::CapitalScoreResult
    scored = score_capital_projects(projects; weights=weights)
    n = length(projects)

    # Sort indices by score descending
    sorted_indices = sortperm([s.weighted_score for s in scored], rev=true)

    selected_names   = String[]
    total_cost       = 0.0
    total_benefit    = 0.0
    all_scores       = [s.weighted_score for s in scored]
    all_rankings     = [s.rank for s in scored]

    for idx in sorted_indices
        p = projects[idx]
        if total_cost + p.estimated_cost <= budget
            push!(selected_names, p.project_name)
            total_cost    += p.estimated_cost
            total_benefit += p.revenue_impact_annual + p.efficiency_gain_annual
        end
    end

    utilization = budget > 0.0 ? total_cost / budget : 0.0

    return CapitalScoreResult(
        projects            = projects,
        scores              = all_scores,
        rankings            = all_rankings,
        selected_projects   = selected_names,
        total_cost_selected = round(total_cost, digits=2),
        total_annual_benefit = round(total_benefit, digits=2),
        budget_utilization  = round(utilization, digits=4),
    )
end

"""
    replacement_priority_report(projects) -> Vector{NamedTuple}

Sort by failure_risk_score descending. Urgency tiers: `:critical` (>=0.8),
`:high` (>=0.6), `:moderate` (>=0.4), `:low` (<0.4).
"""
function replacement_priority_report(projects::Vector{CapitalRequest})::Vector{NamedTuple}
    sorted = sort(projects, by=p -> p.failure_risk_score, rev=true)

    return [(
        project_name      = p.project_name,
        category          = p.category,
        failure_risk_score = p.failure_risk_score,
        urgency_tier      = if p.failure_risk_score >= 0.8
            :critical
        elseif p.failure_risk_score >= 0.6
            :high
        elseif p.failure_risk_score >= 0.4
            :moderate
        else
            :low
        end,
        estimated_cost    = p.estimated_cost,
        useful_life_years = p.useful_life_years,
    ) for p in sorted]
end
