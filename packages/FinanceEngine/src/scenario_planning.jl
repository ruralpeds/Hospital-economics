"""
    scenario_planning.jl — Competitive Scenario Planning (MBA Gap B-05)

Structured scenario planning framework combining:
1. Porter's Five Forces — industry competitive intensity
2. PESTLE — macro-environmental drivers of uncertainty
3. 2×2 Scenario Matrix — four named scenarios from two key uncertainties
4. Strategy implications per scenario

References:
- Porter ME (1980). Competitive Strategy. Free Press.
- Schwartz P (1991). The Art of the Long View. Doubleday.
- Courtney H, Kirkland J, Viguerie P (1997). Strategy under uncertainty. HBR.
"""

using Printf; using Dates

# ─── Porter's Five Forces ────────────────────────────────────────────────────

@kwdef struct FiveForce
    force::Symbol   # :rivalry, :new_entrants, :substitutes, :buyer_power, :supplier_power
    score::Float64  # 1 (low threat) – 10 (high threat)
    key_drivers::Vector{String} = String[]
    strategic_implication::String = ""
end

struct FiveForcesResult
    hospital_name::String
    forces::Vector{FiveForce}
    overall_intensity::Float64   # weighted average
    intensity_tier::Symbol       # :low, :moderate, :high, :extreme
    dominant_force::Symbol
    strategic_summary::String
end

const FORCE_LABELS = Dict(
    :rivalry         => "Competitive Rivalry",
    :new_entrants    => "Threat of New Entrants",
    :substitutes     => "Threat of Substitutes",
    :buyer_power     => "Buyer (Patient/Payer) Power",
    :supplier_power  => "Supplier (Labour/Drug) Power",
)

function analyze_five_forces(hospital_name::String, forces::Vector{FiveForce})::FiveForcesResult
    length(forces) == 5 || @warn "Expected 5 forces, got $(length(forces))"
    avg = mean(f.score for f in forces)
    tier = avg < 4 ? :low : avg < 6 ? :moderate : avg < 8 ? :high : :extreme
    dom  = forces[argmax(f.score for f in forces)].force
    summary = "$(hospital_name) faces $(string(tier)) competitive intensity (avg $(round(avg,digits=1))/10). " *
              "Dominant pressure: $(FORCE_LABELS[dom])."
    FiveForcesResult(hospital_name, forces, avg, tier, dom, summary)
end

# ─── PESTLE ──────────────────────────────────────────────────────────────────

@kwdef struct PESTLEFactor
    category::Symbol   # :political, :economic, :social, :technological, :legal, :environmental
    name::String
    description::String
    impact::Symbol     # :opportunity, :threat, :neutral
    probability::Float64 = 0.5   # [0,1]
    impact_magnitude::Float64 = 5.0  # 1-10
    time_horizon::Symbol = :medium   # :near (<2yr), :medium (2-5yr), :long (>5yr)
end

struct PESTLEResult
    factors::Vector{PESTLEFactor}
    top_threats::Vector{PESTLEFactor}
    top_opportunities::Vector{PESTLEFactor}
    risk_score::Float64   # weighted threats
    opportunity_score::Float64
end

function analyze_pestle(factors::Vector{PESTLEFactor})::PESTLEResult
    threats = filter(f -> f.impact == :threat, factors)
    opps    = filter(f -> f.impact == :opportunity, factors)
    sort!(threats; by=f -> -(f.probability * f.impact_magnitude))
    sort!(opps;    by=f -> -(f.probability * f.impact_magnitude))
    risk_score = isempty(threats) ? 0.0 :
        mean(f.probability * f.impact_magnitude for f in threats)
    opp_score  = isempty(opps)   ? 0.0 :
        mean(f.probability * f.impact_magnitude for f in opps)
    PESTLEResult(factors, threats[1:min(3,end)], opps[1:min(3,end)], risk_score, opp_score)
end

# ─── 2×2 Scenario Matrix ─────────────────────────────────────────────────────

@kwdef struct UncertaintyAxis
    name::String
    description::String
    low_label::String    # e.g. "Rural population grows"
    high_label::String   # e.g. "Rural population declines"
end

@kwdef struct Scenario
    name::String
    axis_x_high::Bool   # axis_x at high vs low value
    axis_y_high::Bool
    narrative::String
    strategic_imperatives::Vector{String} = String[]
    probability::Float64 = 0.25
    financial_impact::Symbol = :neutral   # :positive, :negative, :neutral
end

struct ScenarioMatrix
    axis_x::UncertaintyAxis
    axis_y::UncertaintyAxis
    scenarios::Vector{Scenario}   # 4 scenarios
    recommended_robust_strategies::Vector{String}
end

"""
    build_scenario_matrix(axis_x, axis_y, scenarios) -> ScenarioMatrix

Construct a 2×2 scenario planning matrix.
"""
function build_scenario_matrix(
    axis_x::UncertaintyAxis,
    axis_y::UncertaintyAxis,
    scenarios::Vector{Scenario};
    robust_strategies::Vector{String} = String[],
)::ScenarioMatrix
    length(scenarios) == 4 ||
        throw(ArgumentError("Exactly 4 scenarios required for 2×2 matrix"))
    ScenarioMatrix(axis_x, axis_y, scenarios, robust_strategies)
end

"""
    default_rural_hospital_scenarios() -> ScenarioMatrix

Pre-built rural hospital scenario matrix using key uncertainties:
  X-axis: Federal rural reimbursement policy (supportive ↔ retrenchment)
  Y-axis: Rural population trend (stable/growing ↔ declining)
"""
function default_rural_hospital_scenarios()::ScenarioMatrix
    axis_x = UncertaintyAxis(
        name="Federal Rural Reimbursement Policy",
        description="Direction of Medicare/Medicaid policy for rural providers",
        low_label="Policy retrenchment (cuts, CAH reform)",
        high_label="Supportive policy (enhanced rates, rural investment)",
    )
    axis_y = UncertaintyAxis(
        name="Rural Population / Demand Trend",
        description="Net population and healthcare demand in primary service area",
        low_label="Population decline / demand contraction",
        high_label="Population stable or growing / demand expansion",
    )
    scenarios = [
        Scenario(
            name="Rural Renaissance",
            axis_x_high=true, axis_y_high=true,
            narrative="Federal policy supports rural access AND population stabilises/grows. " *
                "CAH cost-based reimbursement protected; new rural programs funded. " *
                "Workforce challenges ease with rural loan forgiveness expansion.",
            strategic_imperatives=["Invest in capacity and service line expansion",
                "Recruit specialists; build RHC network", "Pursue swing-bed and SNF expansion"],
            probability=0.20, financial_impact=:positive,
        ),
        Scenario(
            name="Managed Decline",
            axis_x_high=true, axis_y_high=false,
            narrative="Policy remains supportive but community shrinks. Enhanced reimbursement " *
                "partially offsets volume loss. Consolidation with regional system possible.",
            strategic_imperatives=["Right-size cost structure proactively",
                "Maximise CAH cost-based reimbursement recovery",
                "Evaluate REH conversion or regional affiliation"],
            probability=0.30, financial_impact=:neutral,
        ),
        Scenario(
            name="Volume Growth, Margin Squeeze",
            axis_x_high=false, axis_y_high=true,
            narrative="Community grows but reimbursement rates are cut. " *
                "CAH designation threatened; cost-based reimbursement reformed. " *
                "Volume growth doesn't offset rate pressure.",
            strategic_imperatives=["Aggressively reduce unit costs via TDABC",
                "Diversify to commercial payers and RHC",
                "Build political relationships to protect CAH policy"],
            probability=0.25, financial_impact=:neutral,
        ),
        Scenario(
            name="Critical Access Crisis",
            axis_x_high=false, axis_y_high=false,
            narrative="Policy cuts AND population decline simultaneously. " *
                "CAH financial viability severely threatened. " *
                "Closure or REH conversion likely within 3–5 years without intervention.",
            strategic_imperatives=["Pursue REH conversion analysis immediately",
                "Engage state rural health office for technical assistance",
                "Model merger/acquisition with regional health system",
                "Develop community foundation and philanthropic strategy"],
            probability=0.25, financial_impact=:negative,
        ),
    ]
    robust_strategies = [
        "Build 90+ days cash on hand as buffer against all scenarios",
        "Maintain operational flexibility — avoid long-term fixed commitments",
        "Diversify revenue (RHC, telehealth, swing bed) to reduce Medicare dependency",
        "Invest in board and management capability for scenario navigation",
        "Engage with state and federal rural health policy stakeholders proactively",
    ]
    build_scenario_matrix(axis_x, axis_y, scenarios; robust_strategies=robust_strategies)
end
