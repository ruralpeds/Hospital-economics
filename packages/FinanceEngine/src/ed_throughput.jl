"""
    ed_throughput.jl — ED Throughput-to-Revenue Linkage (Emergency Department Economics)

Models the financial impact of Emergency Department operations on total hospital
revenue.  Links operational metrics (door-to-provider time, LOS, boarding hours,
LWBS rate) to revenue outcomes and provides business-case tools for common ED
interventions.

## Rural ED Benchmarks (CAH / small rural)
  - Annual visits:  8,000 – 15,000
  - Beds:           8 – 20
  - Avg LOS:        180 – 280 minutes
  - Door-to-provider: 25 – 60 minutes
  - LWBS rate:      2 – 5 %
  - Boarding hours:  2 – 6 hours average
  - Admission rate:  15 – 22 % of ED visits

## Revenue by ESI Acuity Level (national medians, 2024)
  ESI 1 (resuscitation):  \$6,200
  ESI 2 (emergent):       \$3,800
  ESI 3 (urgent):         \$2,100
  ESI 4 (less urgent):    \$  900
  ESI 5 (non-urgent):     \$  450

## Key linkages
  - Every 1% LWBS ≈ 0.8 – 1.2% ED revenue leakage
  - Every hour of boarding ≈ 1 diverted patient (lost throughput)
  - 10-minute door-to-provider reduction → 0.5 – 1.0% LWBS improvement

References:
- ACEP (2023). Emergency Department Benchmarking Alliance data.
- Welch S et al. (2011). Using Data to Drive ED Improvement.
- GAO (2022). Emergency Departments: Information on Boarding and Capacity.
- Pines JM et al. (2011). The Financial Consequences of Lost Demand.
"""

using Statistics; using Printf

# ═══════════════════════════════════════════════════════════════════════════
# Types
# ═══════════════════════════════════════════════════════════════════════════

# ─── Configuration ──────────────────────────────────────────────────────────

@kwdef struct EDConfig
    beds::Int                                       # treatment bays / beds
    annual_visits::Int                              # total ED visits per year
    avg_acuity_mix::Dict{Int,Float64}               # ESI 1-5 → fraction (sum ≈ 1.0)
    avg_door_to_provider_minutes::Float64            # arrival → first physician contact
    avg_los_minutes::Float64                         # average total ED length-of-stay
    avg_boarding_hours::Float64                      # average boarding time for admitted pts
    lwbs_rate::Float64                               # fraction of patients who leave without being seen
    staffing_cost_per_hour::Float64                  # blended cost (RN + MD + tech) per staffed hour
    overhead_per_visit::Float64                      # facility overhead allocated per visit
end

@kwdef struct EDRevenueModel
    avg_revenue_by_acuity::Dict{Int,Float64}         # ESI level → average revenue per visit
    admission_rate::Float64                          # fraction of ED visits that become inpatient
    avg_inpatient_revenue::Float64                   # avg inpatient revenue per admission
    observation_rate::Float64                        # fraction placed in observation status
    avg_observation_revenue::Float64                 # avg revenue per observation stay
    emtala_compliance_cost_annual::Float64            # annual EMTALA compliance overhead
end

# ─── Result ─────────────────────────────────────────────────────────────────

struct EDThroughputResult
    current_annual_revenue::Float64
    optimized_annual_revenue::Float64
    revenue_uplift::Float64
    current_lwbs_revenue_loss::Float64
    boarding_cost_annual::Float64
    throughput_rate_per_hour::Float64
    capacity_utilization::Float64
    bottleneck::String
    recommendations::Vector{String}
end

# ═══════════════════════════════════════════════════════════════════════════
# Rural ED benchmark defaults
# ═══════════════════════════════════════════════════════════════════════════

const RURAL_ED_REVENUE_BY_ACUITY = Dict{Int,Float64}(
    1 => 6200.0,   # ESI 1 — resuscitation
    2 => 3800.0,   # ESI 2 — emergent
    3 => 2100.0,   # ESI 3 — urgent
    4 =>  900.0,   # ESI 4 — less urgent
    5 =>  450.0,   # ESI 5 — non-urgent
)

const RURAL_ED_ACUITY_MIX = Dict{Int,Float64}(
    1 => 0.01,    # ~1% resuscitation
    2 => 0.12,    # ~12% emergent
    3 => 0.32,    # ~32% urgent
    4 => 0.37,    # ~37% less urgent
    5 => 0.18,    # ~18% non-urgent
)

# LWBS patients skew toward lower acuity (ESI 4-5 predominant)
const LWBS_ACUITY_MIX = Dict{Int,Float64}(
    1 => 0.00,
    2 => 0.02,
    3 => 0.15,
    4 => 0.48,
    5 => 0.35,
)

# ═══════════════════════════════════════════════════════════════════════════
# Functions
# ═══════════════════════════════════════════════════════════════════════════

# ─── ED Revenue Analysis ───────────────────────────────────────────────────

"""
    ed_revenue_analysis(config::EDConfig, revenue::EDRevenueModel) -> Dict{String,Any}

Calculate total ED revenue by acuity level, admission-generated inpatient revenue,
observation revenue, and total ED-originated revenue contribution to the hospital.
"""
function ed_revenue_analysis(config::EDConfig, revenue::EDRevenueModel)::Dict{String,Any}
    config.annual_visits > 0 || throw(ArgumentError("annual_visits must be positive"))

    # Revenue by acuity level
    revenue_by_esi = Dict{Int,Float64}()
    total_ed_facility_revenue = 0.0
    for esi in 1:5
        mix_pct  = get(config.avg_acuity_mix, esi, 0.0)
        rev_per  = get(revenue.avg_revenue_by_acuity, esi, 0.0)
        vol      = config.annual_visits * mix_pct
        rev      = vol * rev_per
        revenue_by_esi[esi] = rev
        total_ed_facility_revenue += rev
    end

    # Admission-generated inpatient revenue
    admissions = config.annual_visits * revenue.admission_rate
    inpatient_revenue = admissions * revenue.avg_inpatient_revenue

    # Observation revenue
    observation_volume = config.annual_visits * revenue.observation_rate
    observation_revenue = observation_volume * revenue.avg_observation_revenue

    # Total ED-originated revenue (facility ED + downstream inpatient + observation)
    total_ed_originated = total_ed_facility_revenue + inpatient_revenue + observation_revenue

    # Cost side
    total_overhead = config.annual_visits * config.overhead_per_visit
    hours_of_operation = 8760.0  # 24/7/365
    total_staffing = hours_of_operation * config.staffing_cost_per_hour
    total_cost = total_overhead + total_staffing + revenue.emtala_compliance_cost_annual

    # Revenue per visit
    revenue_per_visit = config.annual_visits > 0 ? total_ed_facility_revenue / config.annual_visits : 0.0

    Dict{String,Any}(
        "revenue_by_esi"             => revenue_by_esi,
        "total_ed_facility_revenue"  => total_ed_facility_revenue,
        "admissions"                 => admissions,
        "inpatient_revenue"          => inpatient_revenue,
        "observation_volume"         => observation_volume,
        "observation_revenue"        => observation_revenue,
        "total_ed_originated_revenue"=> total_ed_originated,
        "total_cost"                 => total_cost,
        "net_ed_contribution"        => total_ed_originated - total_cost,
        "revenue_per_visit"          => revenue_per_visit,
        "ed_pct_of_hospital_revenue" => nothing,  # requires hospital-level data
    )
end

# ─── LWBS Revenue Impact ──────────────────────────────────────────────────

"""
    lwbs_revenue_impact(config::EDConfig, revenue::EDRevenueModel) -> Dict{String,Any}

Calculate revenue lost to patients who left without being seen (LWBS).

LWBS patients disproportionately come from ESI 4-5 categories.  A fraction
would have been admitted, generating downstream inpatient revenue as well.
"""
function lwbs_revenue_impact(config::EDConfig, revenue::EDRevenueModel)::Dict{String,Any}
    lwbs_volume = round(Int, config.annual_visits * config.lwbs_rate)

    # Estimate acuity mix of LWBS (skewed toward ESI 4-5)
    lwbs_revenue_loss = 0.0
    lwbs_by_esi = Dict{Int,Float64}()
    for esi in 1:5
        mix   = get(LWBS_ACUITY_MIX, esi, 0.0)
        vol   = lwbs_volume * mix
        rev   = get(revenue.avg_revenue_by_acuity, esi, 0.0)
        loss  = vol * rev
        lwbs_by_esi[esi] = loss
        lwbs_revenue_loss += loss
    end

    # Potential admissions lost — LWBS patients who might have been admitted
    # Lower acuity LWBS have ~5% admission rate; ESI 2-3 LWBS have ~20%
    lwbs_admission_rates = Dict(1=>0.50, 2=>0.20, 3=>0.10, 4=>0.05, 5=>0.02)
    lost_admissions = 0.0
    for esi in 1:5
        mix  = get(LWBS_ACUITY_MIX, esi, 0.0)
        vol  = lwbs_volume * mix
        rate = get(lwbs_admission_rates, esi, 0.0)
        lost_admissions += vol * rate
    end
    lost_inpatient_revenue = lost_admissions * revenue.avg_inpatient_revenue

    total_lwbs_loss = lwbs_revenue_loss + lost_inpatient_revenue

    Dict{String,Any}(
        "lwbs_volume"              => lwbs_volume,
        "lwbs_rate"                => config.lwbs_rate,
        "lwbs_revenue_loss_by_esi" => lwbs_by_esi,
        "lost_ed_revenue"          => lwbs_revenue_loss,
        "lost_admissions"          => lost_admissions,
        "lost_inpatient_revenue"   => lost_inpatient_revenue,
        "total_annual_lwbs_loss"   => total_lwbs_loss,
        "lwbs_loss_per_patient"    => lwbs_volume > 0 ? total_lwbs_loss / lwbs_volume : 0.0,
    )
end

# ─── Boarding Cost Analysis ───────────────────────────────────────────────

"""
    boarding_cost_analysis(config::EDConfig, revenue::EDRevenueModel) -> Dict{String,Any}

Calculate the financial cost of ED boarding (admitted patients held in ED beds
awaiting inpatient beds).

Boarding consumes nursing time, blocks throughput (diverts patients), and
degrades the ED's revenue-generating capacity.  Includes comparison of
boarding cost vs cost of adding inpatient capacity.
"""
function boarding_cost_analysis(config::EDConfig, revenue::EDRevenueModel)::Dict{String,Any}
    admissions = config.annual_visits * revenue.admission_rate
    boarding_hours_per_year = admissions * config.avg_boarding_hours

    # Staffing cost of boarding — assumes 1 RN per 4 boarding patients, using
    # blended staffing cost rate
    rn_hours_diverted = boarding_hours_per_year * 0.25  # 1:4 nurse-to-boarded ratio
    staffing_cost_of_boarding = rn_hours_diverted * config.staffing_cost_per_hour

    # Throughput reduction — each boarding hour occupies a bed, reducing capacity
    # for new patients.  Average treatment time → patients displaced.
    avg_los_hours = config.avg_los_minutes / 60.0
    patients_displaced = avg_los_hours > 0 ? boarding_hours_per_year / avg_los_hours : 0.0

    # Weighted-average revenue per visit
    weighted_rev = sum(
        get(config.avg_acuity_mix, esi, 0.0) * get(revenue.avg_revenue_by_acuity, esi, 0.0)
        for esi in 1:5
    )
    lost_revenue_from_throughput = patients_displaced * weighted_rev

    # Opportunity cost: lost admissions from displaced patients
    displaced_admissions = patients_displaced * revenue.admission_rate
    lost_downstream_revenue = displaced_admissions * revenue.avg_inpatient_revenue

    total_boarding_cost = staffing_cost_of_boarding + lost_revenue_from_throughput + lost_downstream_revenue

    # Comparison: cost of adding inpatient capacity to reduce boarding
    # Rule of thumb: each new inpatient bed costs ~$250K/year to operate
    beds_needed_to_eliminate = boarding_hours_per_year / 8760.0  # beds continuously occupied
    annual_cost_new_beds = ceil(beds_needed_to_eliminate) * 250_000.0

    Dict{String,Any}(
        "admissions"                   => admissions,
        "boarding_hours_per_year"      => boarding_hours_per_year,
        "rn_hours_diverted"            => rn_hours_diverted,
        "staffing_cost_of_boarding"    => staffing_cost_of_boarding,
        "patients_displaced"           => patients_displaced,
        "lost_throughput_revenue"       => lost_revenue_from_throughput,
        "displaced_admissions"         => displaced_admissions,
        "lost_downstream_revenue"      => lost_downstream_revenue,
        "total_boarding_cost_annual"    => total_boarding_cost,
        "beds_to_eliminate_boarding"    => ceil(Int, beds_needed_to_eliminate),
        "annual_cost_new_inpatient_beds"=> annual_cost_new_beds,
        "net_benefit_adding_beds"       => total_boarding_cost - annual_cost_new_beds,
        "boarding_hours_per_admission"  => config.avg_boarding_hours,
    )
end

# ─── Throughput Optimization ──────────────────────────────────────────────

"""
    throughput_optimization(config::EDConfig, revenue::EDRevenueModel;
                            target_los_reduction_pct::Float64=0.15) -> EDThroughputResult

Model revenue impact of ED throughput improvements:
  - Reducing door-to-provider time
  - Reducing overall LOS
  - Reducing boarding hours
  - Reducing LWBS rate

Returns an `EDThroughputResult` with current vs optimized revenue, bottleneck
identification, and ROI-ranked recommendations.
"""
function throughput_optimization(config::EDConfig, revenue::EDRevenueModel;
                                 target_los_reduction_pct::Float64=0.15)::EDThroughputResult
    0.0 <= target_los_reduction_pct <= 1.0 || throw(ArgumentError(
        "target_los_reduction_pct must be in [0, 1]"))

    # ── Current state ──
    current_analysis = ed_revenue_analysis(config, revenue)
    current_lwbs = lwbs_revenue_impact(config, revenue)
    current_boarding = boarding_cost_analysis(config, revenue)

    current_annual_revenue = current_analysis["total_ed_originated_revenue"]
    current_lwbs_loss = current_lwbs["total_annual_lwbs_loss"]
    boarding_cost = current_boarding["total_boarding_cost_annual"]

    # Throughput rate
    hours_per_year = 8760.0
    throughput_rate = config.annual_visits / hours_per_year

    # Capacity utilization
    avg_los_hours = config.avg_los_minutes / 60.0
    bed_hours_demanded = config.annual_visits * avg_los_hours
    bed_hours_available = config.beds * hours_per_year
    capacity_utilization = bed_hours_available > 0 ? bed_hours_demanded / bed_hours_available : 0.0

    # ── Optimized state ──
    # 1. LOS reduction → more patients can be seen
    new_los = config.avg_los_minutes * (1.0 - target_los_reduction_pct)
    new_los_hours = new_los / 60.0
    additional_capacity_hours = config.annual_visits * (avg_los_hours - new_los_hours)
    additional_patients_from_los = new_los_hours > 0 ? additional_capacity_hours / new_los_hours : 0.0

    # 2. Door-to-provider reduction → LWBS improvement
    # Empirical: 10 min reduction → ~1% LWBS improvement
    target_dtp = max(config.avg_door_to_provider_minutes * 0.75, 15.0)  # floor at 15 min
    dtp_reduction_min = config.avg_door_to_provider_minutes - target_dtp
    lwbs_improvement_pct = (dtp_reduction_min / 10.0) * 0.01
    new_lwbs_rate = max(config.lwbs_rate - lwbs_improvement_pct, 0.005)  # floor at 0.5%
    lwbs_volume_recovered = config.annual_visits * (config.lwbs_rate - new_lwbs_rate)

    # 3. Boarding reduction → freed capacity
    target_boarding = config.avg_boarding_hours * 0.5  # target 50% reduction
    admissions = config.annual_visits * revenue.admission_rate
    boarding_hours_freed = admissions * (config.avg_boarding_hours - target_boarding)
    additional_patients_from_boarding = avg_los_hours > 0 ? boarding_hours_freed / avg_los_hours : 0.0

    # Total additional patients
    total_additional = additional_patients_from_los + lwbs_volume_recovered + additional_patients_from_boarding

    # Revenue from additional patients (use weighted average)
    weighted_rev = sum(
        get(config.avg_acuity_mix, esi, 0.0) * get(revenue.avg_revenue_by_acuity, esi, 0.0)
        for esi in 1:5
    )
    additional_ed_revenue = total_additional * weighted_rev

    # Downstream revenue from additional admissions
    additional_admissions = total_additional * revenue.admission_rate
    additional_inpatient_revenue = additional_admissions * revenue.avg_inpatient_revenue

    optimized_annual_revenue = current_annual_revenue + additional_ed_revenue + additional_inpatient_revenue
    revenue_uplift = optimized_annual_revenue - current_annual_revenue

    # ── Bottleneck identification ──
    bottleneck = if capacity_utilization > 0.90
        "Bed capacity — utilization at $(round(capacity_utilization*100, digits=1))%"
    elseif config.avg_boarding_hours > 4.0
        "Boarding — avg $(round(config.avg_boarding_hours, digits=1)) hours blocks throughput"
    elseif config.avg_door_to_provider_minutes > 45.0
        "Door-to-provider time — $(round(config.avg_door_to_provider_minutes, digits=0)) min drives LWBS"
    elseif config.lwbs_rate > 0.04
        "LWBS rate — $(round(config.lwbs_rate*100, digits=1))% patients leaving without being seen"
    else
        "No single dominant bottleneck — balanced operations"
    end

    # ── Recommendations (ROI-ranked) ──
    recommendations = String[]
    if config.avg_boarding_hours > 2.0
        push!(recommendations,
            "Reduce boarding: implement inpatient pull system and bed-ahead protocols — " *
            "potential annual savings \$$(round(Int, boarding_cost * 0.5))")
    end
    if config.lwbs_rate > 0.02
        push!(recommendations,
            "Reduce LWBS: add triage-based protocols and lobby nurse — " *
            "potential revenue recovery \$$(round(Int, current_lwbs_loss * 0.5))")
    end
    if config.avg_door_to_provider_minutes > 30.0
        dtp_revenue = lwbs_volume_recovered * weighted_rev
        push!(recommendations,
            "Reduce door-to-provider time to <30 min via provider-in-triage — " *
            "potential revenue \$$(round(Int, dtp_revenue))")
    end
    if config.avg_los_minutes > 200.0
        push!(recommendations,
            "Implement split-flow / results-pending area to reduce LOS — " *
            "potential additional capacity: $(round(Int, additional_patients_from_los)) visits/year")
    end
    if capacity_utilization > 0.85
        push!(recommendations,
            "Consider ED expansion — capacity utilization at $(round(capacity_utilization*100, digits=1))%")
    end
    if isempty(recommendations)
        push!(recommendations, "ED operations are within benchmark ranges — focus on sustaining performance")
    end

    EDThroughputResult(
        current_annual_revenue,
        optimized_annual_revenue,
        revenue_uplift,
        current_lwbs_loss,
        boarding_cost,
        throughput_rate,
        capacity_utilization,
        bottleneck,
        recommendations,
    )
end

# ─── Fast-Track ROI ───────────────────────────────────────────────────────

"""
    fast_track_roi(config::EDConfig, revenue::EDRevenueModel;
                   fast_track_capacity::Int=8, fast_track_cost::Float64=350000.0) -> Dict{String,Any}

Model the ROI of adding a fast-track area for ESI 4-5 patients.

Fast-track diverts lower-acuity patients to a separate treatment area,
freeing main ED capacity for higher-acuity (higher-revenue) patients.
"""
function fast_track_roi(config::EDConfig, revenue::EDRevenueModel;
                        fast_track_capacity::Int=8,
                        fast_track_cost::Float64=350000.0)::Dict{String,Any}
    fast_track_capacity > 0 || throw(ArgumentError("fast_track_capacity must be positive"))

    # ESI 4-5 volume eligible for fast-track
    esi4_pct = get(config.avg_acuity_mix, 4, 0.0)
    esi5_pct = get(config.avg_acuity_mix, 5, 0.0)
    eligible_volume = config.annual_visits * (esi4_pct + esi5_pct)

    # Fast-track throughput: avg 45-minute visit for low-acuity
    ft_los_minutes = 45.0
    ft_los_hours = ft_los_minutes / 60.0
    ft_annual_capacity = fast_track_capacity * (8760.0 / ft_los_hours)  # theoretical max
    # Practical capacity at 70% utilization
    ft_practical_capacity = ft_annual_capacity * 0.70

    volume_diverted = min(eligible_volume, ft_practical_capacity)

    # Revenue from diverted patients (they still generate revenue)
    ft_revenue_per_visit = (esi4_pct * get(revenue.avg_revenue_by_acuity, 4, 900.0) +
                            esi5_pct * get(revenue.avg_revenue_by_acuity, 5, 450.0)) /
                           max(esi4_pct + esi5_pct, 0.001)
    ft_revenue = volume_diverted * ft_revenue_per_visit

    # Main ED capacity freed (hours)
    main_ed_hours_freed = volume_diverted * (config.avg_los_minutes / 60.0)
    avg_los_hours = config.avg_los_minutes / 60.0

    # Additional higher-acuity patients that can be seen in freed capacity
    additional_patients = avg_los_hours > 0 ? main_ed_hours_freed / avg_los_hours : 0.0

    # Revenue from additional patients (higher acuity mix — ESI 1-3)
    esi1_pct = get(config.avg_acuity_mix, 1, 0.0)
    esi2_pct = get(config.avg_acuity_mix, 2, 0.0)
    esi3_pct = get(config.avg_acuity_mix, 3, 0.0)
    high_acuity_total = esi1_pct + esi2_pct + esi3_pct
    high_acuity_rev = high_acuity_total > 0 ?
        (esi1_pct * get(revenue.avg_revenue_by_acuity, 1, 6200.0) +
         esi2_pct * get(revenue.avg_revenue_by_acuity, 2, 3800.0) +
         esi3_pct * get(revenue.avg_revenue_by_acuity, 3, 2100.0)) / high_acuity_total :
        2500.0

    additional_revenue = additional_patients * high_acuity_rev

    # Downstream inpatient revenue from additional patients
    additional_admissions = additional_patients * revenue.admission_rate
    additional_inpatient = additional_admissions * revenue.avg_inpatient_revenue

    # LWBS reduction — fast-track reduces wait times, cutting LWBS
    lwbs_reduction_pct = 0.30  # fast-track typically reduces LWBS by ~30%
    lwbs_current = lwbs_revenue_impact(config, revenue)
    lwbs_savings = lwbs_current["total_annual_lwbs_loss"] * lwbs_reduction_pct

    total_annual_benefit = additional_revenue + additional_inpatient + lwbs_savings
    net_annual_benefit = total_annual_benefit - fast_track_cost
    payback_months = fast_track_cost > 0 && total_annual_benefit > 0 ?
        (fast_track_cost / total_annual_benefit) * 12.0 : Inf

    Dict{String,Any}(
        "eligible_esi4_5_volume"    => eligible_volume,
        "volume_diverted_to_ft"    => volume_diverted,
        "ft_revenue_per_visit"     => ft_revenue_per_visit,
        "ft_direct_revenue"        => ft_revenue,
        "main_ed_hours_freed"      => main_ed_hours_freed,
        "additional_patients_seen" => additional_patients,
        "additional_ed_revenue"    => additional_revenue,
        "additional_admissions"    => additional_admissions,
        "additional_inpatient_rev" => additional_inpatient,
        "lwbs_savings"             => lwbs_savings,
        "total_annual_benefit"     => total_annual_benefit,
        "fast_track_annual_cost"   => fast_track_cost,
        "net_annual_benefit"       => net_annual_benefit,
        "payback_period_months"    => payback_months,
        "roi_pct"                  => fast_track_cost > 0 ? (net_annual_benefit / fast_track_cost) * 100.0 : 0.0,
    )
end

# ─── Staffing-Revenue Model ──────────────────────────────────────────────

"""
    staffing_revenue_model(config::EDConfig, revenue::EDRevenueModel,
                           hourly_patterns::Vector{Float64}) -> Dict{String,Any}

Given a 24-hour arrival pattern (`hourly_patterns` — 24 floats summing to 1.0),
model revenue by shift, identify peak-revenue hours, recommend staffing alignment,
and calculate cost of understaffing vs overstaffing per hour.
"""
function staffing_revenue_model(config::EDConfig, revenue::EDRevenueModel,
                                hourly_patterns::Vector{Float64})::Dict{String,Any}
    length(hourly_patterns) == 24 || throw(ArgumentError(
        "hourly_patterns must have exactly 24 elements"))
    abs(sum(hourly_patterns) - 1.0) < 0.01 || throw(ArgumentError(
        "hourly_patterns must sum to ≈1.0 (got $(sum(hourly_patterns)))"))

    # Weighted-average revenue per visit
    weighted_rev = sum(
        get(config.avg_acuity_mix, esi, 0.0) * get(revenue.avg_revenue_by_acuity, esi, 0.0)
        for esi in 1:5
    )

    # Hourly volume and revenue
    hourly_volume = [config.annual_visits * p / 365.0 for p in hourly_patterns]
    hourly_revenue = [v * weighted_rev for v in hourly_volume]

    # Shift revenue (7a-3p, 3p-11p, 11p-7a)
    day_shift   = sum(hourly_revenue[8:15])    # hours 7-14 (indices 8-15)
    evening_shift = sum(hourly_revenue[16:23]) # hours 15-22 (indices 16-23)
    night_shift = sum(hourly_revenue[1:7]) + hourly_revenue[24]  # hours 23-6 (indices 24, 1-7)

    shift_revenue = Dict{String,Float64}(
        "day_7a_3p"     => day_shift,
        "evening_3p_11p"=> evening_shift,
        "night_11p_7a"  => night_shift,
    )

    # Peak revenue hours (top 6 hours)
    hour_rev_pairs = [(h-1, hourly_revenue[h]) for h in 1:24]
    sort!(hour_rev_pairs, by=x -> x[2], rev=true)
    peak_hours = [p[1] for p in hour_rev_pairs[1:min(6, 24)]]

    # Capacity analysis per hour
    avg_los_hours = config.avg_los_minutes / 60.0
    beds_needed_per_hour = [v * avg_los_hours for v in hourly_volume]

    # Understaffing/overstaffing cost
    # Understaffing: if volume exceeds capacity, patients leave (LWBS) → lost revenue
    # Overstaffing: excess staffing cost with no corresponding revenue
    understaffing_cost = Float64[]
    overstaffing_cost = Float64[]
    staffing_recommendations = String[]

    for h in 1:24
        beds_needed = beds_needed_per_hour[h]
        if beds_needed > config.beds
            excess = beds_needed - config.beds
            lost_patients = excess / avg_los_hours
            push!(understaffing_cost, lost_patients * weighted_rev)
            push!(overstaffing_cost, 0.0)
        else
            idle_beds = config.beds - beds_needed
            idle_fraction = idle_beds / config.beds
            push!(understaffing_cost, 0.0)
            push!(overstaffing_cost, idle_fraction * config.staffing_cost_per_hour)
        end
    end

    # Recommendations
    total_understaffing = sum(understaffing_cost) * 365.0
    total_overstaffing = sum(overstaffing_cost) * 365.0

    if total_understaffing > total_overstaffing
        push!(staffing_recommendations,
            "Understaffing dominates: lost revenue \$$(round(Int, total_understaffing))/yr — " *
            "add capacity during peak hours $(join(peak_hours[1:min(3,length(peak_hours))], ", "))")
    end
    if total_overstaffing > 50_000
        low_hours = [p[1] for p in hour_rev_pairs[end-5:end]]
        push!(staffing_recommendations,
            "Overstaffing during hours $(join(sort(low_hours), ", ")) — " *
            "consider flex staffing or reducing overnight coverage")
    end
    push!(staffing_recommendations,
        "Align provider scheduling to arrival pattern — " *
        "$(round(Int, sum(hourly_patterns[11:21]) * 100))% of visits arrive 10am-8pm")

    Dict{String,Any}(
        "hourly_volume"            => hourly_volume,
        "hourly_revenue"           => hourly_revenue,
        "shift_revenue"            => shift_revenue,
        "peak_revenue_hours"       => peak_hours,
        "beds_needed_per_hour"     => beds_needed_per_hour,
        "understaffing_cost_daily" => understaffing_cost,
        "overstaffing_cost_daily"  => overstaffing_cost,
        "annual_understaffing_loss"=> total_understaffing,
        "annual_overstaffing_cost" => total_overstaffing,
        "recommendations"          => staffing_recommendations,
    )
end

# ─── EMTALA Compliance Cost ──────────────────────────────────────────────

"""
    emtala_compliance_cost(config::EDConfig;
                           uninsured_rate::Float64=0.15,
                           avg_uninsured_cost::Float64=1500.0) -> Dict{String,Any}

Calculate the financial impact of EMTALA (Emergency Medical Treatment and Labor Act)
obligations: uncompensated care volume, screening exam costs, on-call physician
costs, and transfer costs.
"""
function emtala_compliance_cost(config::EDConfig;
                                uninsured_rate::Float64=0.15,
                                avg_uninsured_cost::Float64=1500.0)::Dict{String,Any}
    0.0 <= uninsured_rate <= 1.0 || throw(ArgumentError("uninsured_rate must be in [0, 1]"))

    # Uncompensated care volume
    uninsured_volume = round(Int, config.annual_visits * uninsured_rate)
    total_uncompensated_cost = uninsured_volume * avg_uninsured_cost

    # Medical screening exam (MSE) cost — required for ALL patients regardless of ability to pay
    # MSE cost ≈ $250-400 per patient for physician time + basic workup
    mse_cost_per_patient = 325.0
    total_mse_cost = config.annual_visits * mse_cost_per_patient  # all patients get MSE

    # On-call physician costs — EMTALA requires specialist on-call coverage
    # Rural hospitals: ~$1,500-3,000/day for on-call stipends across specialties
    daily_oncall_stipend = 2_000.0
    annual_oncall_cost = daily_oncall_stipend * 365.0

    # Transfer costs — patients transferred for higher-level care
    # ~5-10% of rural ED visits result in transfer
    transfer_rate = 0.08
    transfer_volume = round(Int, config.annual_visits * transfer_rate)
    avg_transfer_cost = 3_500.0  # ambulance + administrative + liability
    total_transfer_cost = transfer_volume * avg_transfer_cost

    # EMTALA violation risk cost (potential penalties, litigation reserves)
    # CMS penalty up to $119,942 per violation (2024), plus exclusion risk
    litigation_reserve = 50_000.0  # annual reserve

    total_emtala_cost = total_uncompensated_cost + annual_oncall_cost +
                        total_transfer_cost + litigation_reserve

    # Cost as percentage of ED revenue
    weighted_rev = sum(
        get(config.avg_acuity_mix, esi, 0.0) * get(RURAL_ED_REVENUE_BY_ACUITY, esi, 0.0)
        for esi in 1:5
    )
    total_ed_revenue = config.annual_visits * weighted_rev
    emtala_pct_of_revenue = total_ed_revenue > 0 ? total_emtala_cost / total_ed_revenue : 0.0

    Dict{String,Any}(
        "uninsured_volume"         => uninsured_volume,
        "uninsured_rate"           => uninsured_rate,
        "total_uncompensated_cost" => total_uncompensated_cost,
        "mse_cost_per_patient"     => mse_cost_per_patient,
        "total_mse_cost"           => total_mse_cost,
        "annual_oncall_cost"       => annual_oncall_cost,
        "transfer_volume"          => transfer_volume,
        "total_transfer_cost"      => total_transfer_cost,
        "litigation_reserve"       => litigation_reserve,
        "total_emtala_cost"        => total_emtala_cost,
        "emtala_pct_of_ed_revenue" => emtala_pct_of_revenue,
    )
end

# ─── ED Expansion Business Case ─────────────────────────────────────────

"""
    ed_expansion_business_case(config::EDConfig, revenue::EDRevenueModel;
                               additional_beds::Int=4,
                               expansion_cost::Float64=2_000_000.0) -> Dict{String,Any}

Build a 10-year NPV business case for ED expansion: additional capacity,
projected additional visits, projected revenue, construction cost, NPV,
payback period, and IRR.
"""
function ed_expansion_business_case(config::EDConfig, revenue::EDRevenueModel;
                                    additional_beds::Int=4,
                                    expansion_cost::Float64=2_000_000.0)::Dict{String,Any}
    additional_beds > 0 || throw(ArgumentError("additional_beds must be positive"))

    # Current capacity metrics
    avg_los_hours = config.avg_los_minutes / 60.0
    hours_per_year = 8760.0
    current_capacity = config.beds * hours_per_year / avg_los_hours
    new_total_beds = config.beds + additional_beds
    new_capacity = new_total_beds * hours_per_year / avg_los_hours

    # Projected additional visits — expansion captures unmet demand + growth
    # Assume demand fills to 80% of new capacity over 3-year ramp
    capacity_at_80pct = new_capacity * 0.80
    potential_additional = max(capacity_at_80pct - config.annual_visits, 0.0)

    # Ramp schedule: Year 1 = 40%, Year 2 = 70%, Year 3+ = 100%
    ramp = [0.40, 0.70, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]

    # Weighted-average revenue per visit
    weighted_rev = sum(
        get(config.avg_acuity_mix, esi, 0.0) * get(revenue.avg_revenue_by_acuity, esi, 0.0)
        for esi in 1:5
    )

    # Annual volume growth assumption: 1.5% organic
    annual_growth_rate = 0.015
    discount_rate = 0.07  # 7% cost of capital for nonprofit hospital

    # 10-year cash flow projection
    annual_cashflows = Float64[]
    cumulative_cf = 0.0
    payback_year = nothing
    projected_volumes = Float64[]

    for yr in 1:10
        growth_factor = (1.0 + annual_growth_rate)^yr
        additional_visits = potential_additional * ramp[yr] * growth_factor
        push!(projected_volumes, additional_visits)

        # Revenue
        ed_revenue = additional_visits * weighted_rev
        admission_revenue = additional_visits * revenue.admission_rate * revenue.avg_inpatient_revenue
        obs_revenue = additional_visits * revenue.observation_rate * revenue.avg_observation_revenue
        total_revenue = ed_revenue + admission_revenue + obs_revenue

        # Costs
        variable_cost = additional_visits * config.overhead_per_visit
        # Additional staffing for new beds (~$150K per bed annually for incremental staff)
        incremental_staffing = additional_beds * 150_000.0
        total_cost = variable_cost + incremental_staffing

        net_cf = total_revenue - total_cost
        push!(annual_cashflows, net_cf)

        cumulative_cf += net_cf
        if isnothing(payback_year) && cumulative_cf >= expansion_cost
            payback_year = yr
        end
    end

    # NPV calculation
    npv = -expansion_cost + sum(cf / (1.0 + discount_rate)^yr
                                for (yr, cf) in enumerate(annual_cashflows))

    # IRR approximation via bisection
    irr = _approximate_irr(expansion_cost, annual_cashflows)

    Dict{String,Any}(
        "current_beds"              => config.beds,
        "additional_beds"           => additional_beds,
        "new_total_beds"            => new_total_beds,
        "current_annual_visits"     => config.annual_visits,
        "projected_additional_visits"=> projected_volumes,
        "expansion_cost"            => expansion_cost,
        "annual_cashflows"          => annual_cashflows,
        "npv_10yr"                  => npv,
        "payback_year"              => isnothing(payback_year) ? ">10" : payback_year,
        "irr"                       => irr,
        "discount_rate"             => discount_rate,
        "annual_growth_rate"        => annual_growth_rate,
        "weighted_revenue_per_visit"=> weighted_rev,
    )
end

# ─── Internal helpers ────────────────────────────────────────────────────

"""
    _approximate_irr(initial_investment, cashflows; tol=1e-4, max_iter=200) -> Float64

Bisection-based IRR approximation.  Returns NaN if no real root in [-0.5, 5.0].
"""
function _approximate_irr(initial_investment::Float64,
                          cashflows::Vector{Float64};
                          tol::Float64=1e-4, max_iter::Int=200)::Float64
    function npv_at_rate(r)
        -initial_investment + sum(cf / (1.0 + r)^t for (t, cf) in enumerate(cashflows))
    end

    lo, hi = -0.50, 5.0
    npv_lo = npv_at_rate(lo)
    npv_hi = npv_at_rate(hi)

    # Check if root exists in interval
    if npv_lo * npv_hi > 0
        return NaN
    end

    for _ in 1:max_iter
        mid = (lo + hi) / 2.0
        npv_mid = npv_at_rate(mid)
        abs(npv_mid) < tol && return mid
        if npv_lo * npv_mid < 0
            hi = mid
            npv_hi = npv_mid
        else
            lo = mid
            npv_lo = npv_mid
        end
    end
    return (lo + hi) / 2.0
end
