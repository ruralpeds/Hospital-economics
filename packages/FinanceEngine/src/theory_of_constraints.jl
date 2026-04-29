"""
    theory_of_constraints.jl — Theory of Constraints / Throughput Accounting (MBA Gap C-04)

Implements Goldratt's Theory of Constraints (TOC) and the associated
Throughput Accounting (TA) framework for hospital operations management.

## Three global measures
  T  = Throughput = Revenue − Truly Variable Costs (TVC)
  OE = Operating Expense = all costs EXCEPT TVC (largely fixed in short run)
  I  = Investment / Inventory = capital tied up in the system

  Net Profit     = T − OE
  ROI            = (T − OE) / I
  Productivity   = T / OE
  Investment Turns = T / I

## The Five Focusing Steps (5FS)
  1. IDENTIFY the system's constraint
  2. EXPLOIT the constraint (maximise throughput through it)
  3. SUBORDINATE everything else to the constraint
  4. ELEVATE the constraint (invest to increase its capacity)
  5. REPEAT — find the next constraint

## Hospital constraints (common)
  - ED throughput (boarding, triage bottleneck)
  - OR availability (block scheduling inefficiency)
  - Inpatient bed capacity
  - Physician availability (appointment access)
  - Billing/coding throughput (revenue cycle delay)

References:
- Goldratt EM, Cox J (1984). The Goal. North River Press.
- Goldratt EM (1990). Theory of Constraints. North River Press.
- Kershaw R (2000). Using TOC to cure healthcare problems. Management Accounting Quarterly.
"""

using Statistics; using Printf

# ─── Throughput Accounting core ──────────────────────────────────────────────

@kwdef struct ThroughputInputs
    name::String
    annual_revenue::Float64
    truly_variable_costs::Float64   # costs that vary directly with patient volume
                                    # (supplies per case, drugs per prescription, etc.)
    operating_expense::Float64      # all other costs (salaries, rent, depreciation)
    investment::Float64             # total assets / capital invested
end

struct ThroughputMetrics
    name::String
    throughput::Float64         # T = Revenue - TVC
    operating_expense::Float64  # OE
    investment::Float64         # I
    net_profit::Float64         # T - OE
    roi::Float64                # (T - OE) / I
    productivity::Float64       # T / OE
    investment_turns::Float64   # T / I
    tvc_ratio::Float64          # TVC / Revenue (lower = better; T dominant)
end

"""
    compute_throughput_metrics(inputs::ThroughputInputs) -> ThroughputMetrics
"""
function compute_throughput_metrics(inputs::ThroughputInputs)::ThroughputMetrics
    T  = inputs.annual_revenue - inputs.truly_variable_costs
    OE = inputs.operating_expense
    I  = inputs.investment
    NP = T - OE
    ThroughputMetrics(
        inputs.name, T, OE, I, NP,
        I > 0 ? NP / I : 0.0,
        OE > 0 ? T / OE : 0.0,
        I > 0 ? T / I : 0.0,
        inputs.annual_revenue > 0 ? inputs.truly_variable_costs / inputs.annual_revenue : 0.0,
    )
end

# ─── Resource / constraint identification ────────────────────────────────────

@kwdef struct HospitalResource
    id::Symbol
    name::String
    available_capacity_units::Float64   # e.g. OR hours, beds, appointments
    demanded_capacity_units::Float64    # actual demand placed on this resource
    cost_per_unit::Float64 = 0.0        # for ROI calculations
    throughput_per_unit::Float64 = 0.0  # revenue generated per unit of this resource
end

struct ConstraintAnalysis
    resources::Vector{HospitalResource}
    constraint::HospitalResource        # the binding constraint
    utilisation_rates::Dict{Symbol,Float64}
    throughput_per_capacity_unit::Dict{Symbol,Float64}
    exploitation_recommendations::Vector{String}
    subordination_recommendations::Vector{String}
    elevation_options::Vector{String}
end

"""
    identify_constraint(resources::Vector{HospitalResource}) -> ConstraintAnalysis

Apply TOC Five Focusing Steps to identify and exploit the system constraint.

The constraint is the resource with the **highest utilisation rate** (demand/capacity).
"""
function identify_constraint(resources::Vector{HospitalResource})::ConstraintAnalysis
    isempty(resources) && throw(ArgumentError("resources must not be empty"))

    util = Dict(r.id => r.available_capacity_units > 0 ?
        r.demanded_capacity_units / r.available_capacity_units : Inf
        for r in resources)
    tput_per_unit = Dict(r.id => r.throughput_per_unit for r in resources)

    constraint = resources[argmax(get(util, r.id, 0.0) for r in resources)]
    util_pct    = get(util, constraint.id, 0.0) * 100

    exploit = [
        "Eliminate non-value-added time at $(constraint.name): scheduling gaps, " *
        "setup time, administrative delays",
        "Increase throughput through $(constraint.name) without adding capacity: " *
        "batch processing, parallel preparation, rapid turnover protocols",
        "Ensure $(constraint.name) never waits — buffer upstream to prevent starvation",
        "Review $(constraint.name) scheduling: maximise productive hours, " *
        "minimise idle time between cases/appointments",
    ]
    subordinate = [
        "All non-constraint resources should pace to $(constraint.name) — " *
        "no value in producing faster upstream if $(constraint.name) is the bottleneck",
        "Reduce work-in-progress queue at $(constraint.name) — excess queue " *
        "creates complexity without adding throughput",
        "Set $(constraint.name) drum-beat: all scheduling derived from constraint capacity",
    ]
    elevate = [
        "Invest in additional $(constraint.name) capacity (expand hours, add resources)",
        "Outsource or transfer some demand from $(constraint.name) to alternative venues",
        "Technology investment to increase throughput per unit at $(constraint.name)",
        "Cross-train staff to add flexible capacity at $(constraint.name) during peaks",
    ]

    ConstraintAnalysis(resources, constraint, util, tput_per_unit,
        exploit, subordinate, elevate)
end

# ─── Throughput decision support ─────────────────────────────────────────────

"""
    throughput_vs_cost_decision(;
        option_name, throughput_gain, oe_increase, investment_required,
        current_metrics
    ) -> NamedTuple

Evaluate whether a proposed operational investment improves the three
global TOC measures (T, OE, I) and by how much.

TOC decision rule: Accept if NP increases OR ROI improves.
"""
function throughput_vs_cost_decision(;
    option_name::String,
    throughput_gain::Float64,
    oe_increase::Float64,
    investment_required::Float64,
    current_metrics::ThroughputMetrics,
)
    new_T  = current_metrics.throughput + throughput_gain
    new_OE = current_metrics.operating_expense + oe_increase
    new_I  = current_metrics.investment + investment_required
    new_NP = new_T - new_OE
    new_ROI = new_I > 0 ? new_NP / new_I : 0.0

    delta_NP  = new_NP  - current_metrics.net_profit
    delta_ROI = new_ROI - current_metrics.roi

    (
        option             = option_name,
        throughput_gain    = throughput_gain,
        oe_increase        = oe_increase,
        investment         = investment_required,
        net_profit_change  = delta_NP,
        roi_change         = delta_ROI,
        recommended        = delta_NP > 0 || delta_ROI > 0.005,
        payback_years      = oe_increase + investment_required > 0 ?
            investment_required / max(throughput_gain - oe_increase, 1.0) : Inf,
    )
end
