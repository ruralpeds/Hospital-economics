"""
    balanced_scorecard.jl — Healthcare Balanced Scorecard (MBA Gap B-01)

Implements the Kaplan-Norton (1992, 1996) Balanced Scorecard (BSC) adapted
for rural hospital and Critical Access Hospital strategy execution.

The four perspectives for healthcare:
  1. **Financial** — sustainability, growth, cost management
  2. **Patient & Community** — clinical quality, access, satisfaction, population health
  3. **Internal Process** — care delivery efficiency, care coordination, compliance
  4. **Learning & Growth** — workforce, technology, culture, innovation capacity

Provides:
- KPI definition with targets, thresholds, and RAG status
- Performance measurement (current vs prior period vs target)
- Strategy map: causal chain linking perspectives (Learning → Process → Patient → Financial)
- Strategic initiative tracking (owner, timeline, status, expected impact)
- BSC Score: weighted composite (0-100)
- Board-ready one-page scorecard formatted output

References:
- Kaplan RS, Norton DP (1992). The Balanced Scorecard. HBR Jan-Feb 1992.
- Kaplan RS, Norton DP (1996). The Balanced Scorecard. Harvard Business School Press.
- Inamdar N et al (2002). Applying the Balanced Scorecard in healthcare. JHMHP 13(2).
- Pink G et al (2006). Creating a BSC for rural hospitals. CAH and Rural Hospitals.
"""

using Statistics
using Printf
using Dates

# ─────────────────────────────────────────────────────────────────────────────
# Core KPI types
# ─────────────────────────────────────────────────────────────────────────────

"""
    BSCPerspective

The four BSC perspectives for healthcare organisations.
"""
@enum BSCPerspective financial=1 patient_community=2 internal_process=3 learning_growth=4

perspective_label(p::BSCPerspective) = p == financial ? "Financial" :
    p == patient_community ? "Patient & Community" :
    p == internal_process  ? "Internal Process" : "Learning & Growth"

"""
    KPIQ (KPI Direction)

Whether higher or lower values are better for a KPI.
"""
@enum KPIDirection higher_better=1 lower_better=2 target_range=3

"""
    BSCKPIDefinition

Definition of a single KPI in the BSC framework.

# Fields
- `id::Symbol`: Unique identifier.
- `name::String`: Display name.
- `perspective::BSCPerspective`
- `strategic_objective::String`: The parent strategic objective this KPI measures.
- `unit::Symbol`: `:pct`, `:days`, `:usd`, `:ratio`, `:count`, `:score`, `:index`.
- `direction::KPIDirection`
- `target::Float64`
- `green_threshold::Float64`: ≥ (higher_better) or ≤ (lower_better) for green.
- `amber_threshold::Float64`
- `weight::Float64`: Contribution to BSC Score within its perspective (sum per perspective = 1).
- `lag_or_lead::Symbol`: `:lag` (outcome) or `:lead` (driver/predictive).
"""
@kwdef struct BSCKPIDefinition
    id::Symbol
    name::String
    perspective::BSCPerspective
    strategic_objective::String
    unit::Symbol                = :ratio
    direction::KPIDirection     = higher_better
    target::Float64
    green_threshold::Float64
    amber_threshold::Float64
    weight::Float64             = 1.0
    lag_or_lead::Symbol         = :lag
end

"""
    BSCKPIMeasurement

One period's measurement of a KPI.

# Fields
- `kpi_id::Symbol`
- `period::String`: e.g. "Q1 FY2026".
- `current_value::Float64`
- `prior_value::Float64`
- `target_value::Float64`: May differ from definition target if revised.
- `rag_status::Symbol`: `:green`, `:amber`, `:red`.
- `trend::Symbol`: `:improving`, `:stable`, `:declining`.
- `performance_score::Float64`: 0-100 for this KPI (used in BSC Score).
"""
struct BSCKPIMeasurement
    kpi_id::Symbol
    period::String
    current_value::Float64
    prior_value::Float64
    target_value::Float64
    rag_status::Symbol
    trend::Symbol
    performance_score::Float64
end

# ─────────────────────────────────────────────────────────────────────────────
# Standard KPI library for rural CAHs
# ─────────────────────────────────────────────────────────────────────────────

"""
    CAH_STANDARD_KPI_LIBRARY

Standard BSC KPI definitions for Critical Access Hospitals.
Based on Flex Monitoring Team indicators + CMS quality measures + HFMA benchmarks.
"""
const CAH_STANDARD_KPI_LIBRARY = BSCKPIDefinition[
    # ── Financial Perspective ──────────────────────────────────────────────
    BSCKPIDefinition(id=:operating_margin, name="Operating Margin",
        perspective=financial, strategic_objective="Financial Sustainability",
        unit=:pct, direction=higher_better, target=0.03,
        green_threshold=0.03, amber_threshold=0.0, weight=0.30),

    BSCKPIDefinition(id=:days_cash_on_hand, name="Days Cash on Hand",
        perspective=financial, strategic_objective="Liquidity Management",
        unit=:days, direction=higher_better, target=55.0,
        green_threshold=55.0, amber_threshold=30.0, weight=0.25),

    BSCKPIDefinition(id=:dso, name="Days Sales Outstanding",
        perspective=financial, strategic_objective="Revenue Cycle Excellence",
        unit=:days, direction=lower_better, target=45.0,
        green_threshold=45.0, amber_threshold=60.0, weight=0.20,
        lag_or_lead=:lead),

    BSCKPIDefinition(id=:salary_to_revenue, name="Salary to Revenue",
        perspective=financial, strategic_objective="Cost Management",
        unit=:pct, direction=lower_better, target=0.50,
        green_threshold=0.50, amber_threshold=0.58, weight=0.15),

    BSCKPIDefinition(id=:net_revenue_per_discharge, name="Net Revenue per Discharge",
        perspective=financial, strategic_objective="Revenue Optimization",
        unit=:usd, direction=higher_better, target=12_000.0,
        green_threshold=12_000.0, amber_threshold=9_500.0, weight=0.10),

    # ── Patient & Community Perspective ───────────────────────────────────
    BSCKPIDefinition(id=:hcahps_top_box, name="HCAHPS Overall Rating (Top Box)",
        perspective=patient_community, strategic_objective="Patient Experience",
        unit=:pct, direction=higher_better, target=0.75,
        green_threshold=0.72, amber_threshold=0.65, weight=0.25),

    BSCKPIDefinition(id=:readmission_rate, name="All-Cause Readmission Rate",
        perspective=patient_community, strategic_objective="Clinical Quality",
        unit=:pct, direction=lower_better, target=0.10,
        green_threshold=0.12, amber_threshold=0.16, weight=0.25),

    BSCKPIDefinition(id=:ed_door_to_provider, name="ED Door-to-Provider Time (min)",
        perspective=patient_community, strategic_objective="Access & Responsiveness",
        unit=:count, direction=lower_better, target=20.0,
        green_threshold=20.0, amber_threshold=35.0, weight=0.20,
        lag_or_lead=:lead),

    BSCKPIDefinition(id=:preventable_admission_rate, name="Preventable Admission Rate",
        perspective=patient_community, strategic_objective="Population Health",
        unit=:pct, direction=lower_better, target=0.06,
        green_threshold=0.08, amber_threshold=0.12, weight=0.15),

    BSCKPIDefinition(id=:charity_care_pct, name="Charity Care as % of Revenue",
        perspective=patient_community, strategic_objective="Community Benefit",
        unit=:pct, direction=target_range, target=0.03,
        green_threshold=0.04, amber_threshold=0.015, weight=0.15),

    # ── Internal Process Perspective ──────────────────────────────────────
    BSCKPIDefinition(id=:or_utilization, name="OR Utilisation Rate",
        perspective=internal_process, strategic_objective="Operational Efficiency",
        unit=:pct, direction=higher_better, target=0.70,
        green_threshold=0.70, amber_threshold=0.55, weight=0.25),

    BSCKPIDefinition(id=:denial_rate, name="Initial Denial Rate",
        perspective=internal_process, strategic_objective="Revenue Cycle Excellence",
        unit=:pct, direction=lower_better, target=0.05,
        green_threshold=0.05, amber_threshold=0.10, weight=0.25,
        lag_or_lead=:lead),

    BSCKPIDefinition(id=:alos_inpatient, name="Average Length of Stay (Inpatient)",
        perspective=internal_process, strategic_objective="Care Efficiency",
        unit=:days, direction=lower_better, target=3.5,
        green_threshold=4.0, amber_threshold=5.5, weight=0.20),

    BSCKPIDefinition(id=:vbp_tps, name="VBP Total Performance Score",
        perspective=internal_process, strategic_objective="Quality Compliance",
        unit=:score, direction=higher_better, target=65.0,
        green_threshold=65.0, amber_threshold=50.0, weight=0.15),

    BSCKPIDefinition(id=:medication_error_rate, name="Medication Error Rate (per 1000)",
        perspective=internal_process, strategic_objective="Patient Safety",
        unit=:ratio, direction=lower_better, target=1.5,
        green_threshold=2.0, amber_threshold=4.0, weight=0.15),

    # ── Learning & Growth Perspective ─────────────────────────────────────
    BSCKPIDefinition(id=:nurse_vacancy_rate, name="RN Vacancy Rate",
        perspective=learning_growth, strategic_objective="Workforce Development",
        unit=:pct, direction=lower_better, target=0.05,
        green_threshold=0.08, amber_threshold=0.15, weight=0.30,
        lag_or_lead=:lead),

    BSCKPIDefinition(id=:employee_engagement, name="Employee Engagement Score",
        perspective=learning_growth, strategic_objective="Culture & Engagement",
        unit=:score, direction=higher_better, target=75.0,
        green_threshold=70.0, amber_threshold=60.0, weight=0.25),

    BSCKPIDefinition(id=:ehr_adoption_pct, name="EHR Module Adoption Rate",
        perspective=learning_growth, strategic_objective="Digital Transformation",
        unit=:pct, direction=higher_better, target=0.90,
        green_threshold=0.85, amber_threshold=0.70, weight=0.20,
        lag_or_lead=:lead),

    BSCKPIDefinition(id=:training_hours_per_fte, name="Training Hours per FTE",
        perspective=learning_growth, strategic_objective="Capability Building",
        unit=:count, direction=higher_better, target=24.0,
        green_threshold=20.0, amber_threshold=12.0, weight=0.15,
        lag_or_lead=:lead),

    BSCKPIDefinition(id=:succession_readiness, name="Succession Readiness (%)",
        perspective=learning_growth, strategic_objective="Leadership Development",
        unit=:pct, direction=higher_better, target=0.80,
        green_threshold=0.70, amber_threshold=0.50, weight=0.10),
]

# ─────────────────────────────────────────────────────────────────────────────
# RAG and performance scoring
# ─────────────────────────────────────────────────────────────────────────────

"""
    rag_status_for_kpi(kpi::BSCKPIDefinition, value::Float64) -> Symbol

Compute RAG status for a KPI value.
"""
function rag_status_for_kpi(kpi::BSCKPIDefinition, value::Float64)::Symbol
    if kpi.direction == higher_better
        value >= kpi.green_threshold ? :green :
        value >= kpi.amber_threshold ? :amber : :red
    elseif kpi.direction == lower_better
        value <= kpi.green_threshold ? :green :
        value <= kpi.amber_threshold ? :amber : :red
    else  # target_range: green near target, amber if drifting, red if far
        dist = abs(value - kpi.target)
        band = abs(kpi.green_threshold - kpi.amber_threshold)
        dist <= band * 0.5 ? :green : dist <= band ? :amber : :red
    end
end

"""
    performance_score_for_kpi(kpi::BSCKPIDefinition, value::Float64) -> Float64

Compute a 0-100 performance score for a single KPI.

  100 = at or beyond target
   50 = at amber threshold
    0 = at or below worst expected value
"""
function performance_score_for_kpi(kpi::BSCKPIDefinition, value::Float64)::Float64
    if kpi.direction == higher_better
        t = kpi.target; a = kpi.amber_threshold
        worst = a - (t - a)  # extrapolate below amber
        clamp((value - worst) / (t - worst) * 100, 0.0, 100.0)
    elseif kpi.direction == lower_better
        t = kpi.target; a = kpi.amber_threshold
        worst = a + (a - t)
        clamp((worst - value) / (worst - t) * 100, 0.0, 100.0)
    else  # target_range
        dist = abs(value - kpi.target)
        band = abs(kpi.green_threshold - kpi.amber_threshold)
        clamp((1.0 - dist / (2 * band)) * 100, 0.0, 100.0)
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Strategic initiatives
# ─────────────────────────────────────────────────────────────────────────────

"""
    StrategicInitiative

A strategic initiative that supports one or more BSC objectives.

# Fields
- `id::Symbol`
- `name::String`
- `perspective::BSCPerspective`
- `linked_kpis::Vector{Symbol}`: KPI ids this initiative is expected to improve.
- `owner::String`
- `start_date::Date`, `target_end_date::Date`
- `status::Symbol`: `:not_started`, `:in_progress`, `:on_hold`, `:complete`.
- `completion_pct::Float64`: 0-100.
- `expected_impact_usd::Float64`: Estimated annual financial impact.
- `budget_usd::Float64`
- `actual_spend_usd::Float64`
"""
@kwdef struct StrategicInitiative
    id::Symbol
    name::String
    perspective::BSCPerspective
    linked_kpis::Vector{Symbol}    = Symbol[]
    owner::String                  = "CFO"
    start_date::Date               = today()
    target_end_date::Date          = today() + Day(365)
    status::Symbol                 = :in_progress
    completion_pct::Float64        = 0.0
    expected_impact_usd::Float64   = 0.0
    budget_usd::Float64            = 0.0
    actual_spend_usd::Float64      = 0.0
end

# ─────────────────────────────────────────────────────────────────────────────
# Balanced Scorecard model
# ─────────────────────────────────────────────────────────────────────────────

"""
    BalancedScorecard

A configured hospital Balanced Scorecard with measurements.

# Fields
- `hospital_name::String`
- `period::String`
- `kpi_definitions::Vector{BSCKPIDefinition}`
- `measurements::Dict{Symbol,BSCKPIMeasurement}`: current period measurements.
- `initiatives::Vector{StrategicInitiative}`
- `perspective_weights::Dict{BSCPerspective,Float64}`: contribution to overall BSC score.
"""
@kwdef struct BalancedScorecard
    hospital_name::String
    period::String
    kpi_definitions::Vector{BSCKPIDefinition}    = CAH_STANDARD_KPI_LIBRARY
    measurements::Dict{Symbol,BSCKPIMeasurement} = Dict()
    initiatives::Vector{StrategicInitiative}     = StrategicInitiative[]
    perspective_weights::Dict{BSCPerspective,Float64} = Dict(
        financial        => 0.30,
        patient_community => 0.30,
        internal_process  => 0.25,
        learning_growth   => 0.15,
    )
end

"""
    measure_kpi!(bsc::BalancedScorecard, kpi_id::Symbol,
                 current::Float64, prior::Float64;
                 period, target_override) -> BSCKPIMeasurement

Add a KPI measurement to the scorecard.
"""
function measure_kpi!(
    bsc::BalancedScorecard,
    kpi_id::Symbol,
    current::Float64,
    prior::Float64;
    period::String = bsc.period,
    target_override::Union{Float64,Nothing} = nothing,
)::BSCKPIMeasurement
    defn = findfirst(k -> k.id == kpi_id, bsc.kpi_definitions)
    isnothing(defn) && throw(ArgumentError("KPI $kpi_id not found in scorecard definitions"))
    kpi = bsc.kpi_definitions[defn]

    target = isnothing(target_override) ? kpi.target : target_override
    rag    = rag_status_for_kpi(kpi, current)
    score  = performance_score_for_kpi(kpi, current)

    trend  = if kpi.direction == higher_better
        current > prior * 1.01 ? :improving : current < prior * 0.99 ? :declining : :stable
    else
        current < prior * 0.99 ? :improving : current > prior * 1.01 ? :declining : :stable
    end

    m = BSCKPIMeasurement(kpi_id, period, current, prior, target, rag, trend, score)
    bsc.measurements[kpi_id] = m
    m
end

# ─────────────────────────────────────────────────────────────────────────────
# BSC Score computation
# ─────────────────────────────────────────────────────────────────────────────

"""
    BSCSummary

Summary of the Balanced Scorecard for a given period.

# Fields
- `overall_score::Float64`: Weighted composite BSC score (0-100).
- `perspective_scores::Dict{BSCPerspective,Float64}`: Score per perspective.
- `n_green::Int`, `n_amber::Int`, `n_red::Int`
- `top_concerns::Vector{Symbol}`: Red KPI ids sorted by strategic priority.
- `top_performers::Vector{Symbol}`: Green KPI ids with highest scores.
- `measured_kpi_count::Int`
"""
struct BSCSummary
    overall_score::Float64
    perspective_scores::Dict{BSCPerspective,Float64}
    n_green::Int
    n_amber::Int
    n_red::Int
    top_concerns::Vector{Symbol}
    top_performers::Vector{Symbol}
    measured_kpi_count::Int
end

"""
    summarise_bsc(bsc::BalancedScorecard) -> BSCSummary

Compute the BSC summary for the current measurements.
"""
function summarise_bsc(bsc::BalancedScorecard)::BSCSummary
    isempty(bsc.measurements) &&
        throw(ArgumentError("No KPI measurements recorded; use measure_kpi! first"))

    perspective_scores = Dict{BSCPerspective,Float64}()
    for persp in instances(BSCPerspective)
        kpis = filter(k -> k.perspective == persp && haskey(bsc.measurements, k.id),
                      bsc.kpi_definitions)
        isempty(kpis) && continue
        total_weight = sum(k.weight for k in kpis)
        if total_weight > 0
            perspective_scores[persp] = sum(
                k.weight * bsc.measurements[k.id].performance_score
                for k in kpis
            ) / total_weight
        end
    end

    overall = if !isempty(perspective_scores)
        tw = sum(bsc.perspective_weights[p] for p in keys(perspective_scores))
        sum(bsc.perspective_weights[p] * perspective_scores[p]
            for p in keys(perspective_scores)) / tw
    else
        0.0
    end

    rags = [m.rag_status for m in values(bsc.measurements)]
    n_g = count(==(:green), rags)
    n_a = count(==(:amber), rags)
    n_r = count(==(:red),   rags)

    red_kpis = [id for (id, m) in bsc.measurements if m.rag_status == :red]
    grn_kpis = [(id, m.performance_score) for (id, m) in bsc.measurements
                 if m.rag_status == :green]
    sort!(grn_kpis; by=x->-x[2])

    BSCSummary(
        overall, perspective_scores, n_g, n_a, n_r,
        red_kpis, [id for (id, _) in grn_kpis[1:min(5,end)]],
        length(bsc.measurements),
    )
end

"""
    bsc_report_text(bsc::BalancedScorecard, summary::BSCSummary) -> String

Render a concise one-page BSC text report.
"""
function bsc_report_text(bsc::BalancedScorecard, summary::BSCSummary)::String
    io = IOBuffer()
    println(io, "═"^68)
    println(io, "BALANCED SCORECARD — $(bsc.hospital_name)")
    println(io, "Period: $(bsc.period)  |  Overall Score: $(round(summary.overall_score, digits=1))/100")
    println(io, "═"^68)

    for persp in instances(BSCPerspective)
        !haskey(summary.perspective_scores, persp) && continue
        p_score = summary.perspective_scores[persp]
        println(io, "\n  $(perspective_label(persp)) [$(round(p_score, digits=1))/100]")
        println(io, "  " * "─"^62)
        kpis = filter(k -> k.perspective == persp && haskey(bsc.measurements, k.id),
                      bsc.kpi_definitions)
        for kpi in kpis
            m = bsc.measurements[kpi.id]
            icon = m.rag_status == :green ? "▲" : m.rag_status == :amber ? "●" : "▼"
            trend_icon = m.trend == :improving ? "↑" : m.trend == :declining ? "↓" : "→"
            println(io, @sprintf("  %s %-35s  %8.2f  %s  (%s)",
                icon, kpi.name, m.current_value, trend_icon, kpi.unit))
        end
    end

    println(io, "\n  ─"^35)
    println(io, "  🔴 Top Concerns:   ", join(summary.top_concerns, ", "))
    println(io, "  🟢 Top Performers: ", join(summary.top_performers[1:min(3,end)], ", "))
    println(io, "\n  Active Initiatives: $(length(bsc.initiatives))")
    for init in bsc.initiatives
        if init.status == :in_progress
            println(io, @sprintf("    ● %-38s %3.0f%% ($(init.owner))",
                init.name, init.completion_pct))
        end
    end
    String(take!(io))
end
