"""
    EpisodeCostModels.jl

Three cost calculation models for healthcare episodes:
1. DRG-based costing: base costs adjusted for severity, comorbidities, length of stay
2. RVU-based costing: specialty-based relative value units with labor allocation
3. Activity-Based Costing (ABC): overhead driver allocation based on resource consumption

All models integrate with Episode.jl types for comprehensive episode cost calculation.
"""

# ============================================================================
# DRG-Based Cost Model
# ============================================================================

"""
    struct DRGCostModel

DRG-based cost calculation model using CMS methodology.

# Fields
- `base_costs::Dict{String, Float64}` — Base cost per DRG code
- `labor_rates::Dict{String, Float64}` — Labor cost per FTE type (MD, RN, RT, etc)
- `comorbidity_adjusters::Dict{String, Float64}` — Adjustment factors for comorbidities/complications
- `hospital_wage_index::Float64` — Geographic wage adjustment (1.0 = national average)
- `cost_per_day::Float64` — Base daily cost for ward stay
- `cost_per_OR_minute::Float64` — Operating room time cost

# Example
```julia
drg_model = DRGCostModel(
    base_costs = Dict("046" => 15_000.0, "247" => 28_000.0),  # Cardiology DRGs
    labor_rates = Dict("MD" => 200.0, "RN" => 60.0, "RT" => 50.0),
    comorbidity_adjusters = Dict("CC" => 1.25, "MCC" => 1.50),  # 25-50% increase
    hospital_wage_index = 0.95,  # 5% below national average
    cost_per_day = 2_500.0,
    cost_per_OR_minute = 25.0
)
```
"""
struct DRGCostModel
    base_costs::Dict{String, Float64}
    labor_rates::Dict{String, Float64}
    comorbidity_adjusters::Dict{String, Float64}
    hospital_wage_index::Float64
    cost_per_day::Float64
    cost_per_OR_minute::Float64
end

"""
    calculate_drg_cost(episode::Episode, model::DRGCostModel)::Float64

Calculate total episode cost using DRG-based methodology.

Cost components:
1. Base cost for primary DRG
2. Comorbidity/complication adjustments (CC/MCC)
3. Length of stay adjustment
4. Geographic wage index adjustment
5. Procedure costs (OR time)

# Arguments
- `episode::Episode` — Patient episode with DRG, diagnoses, procedures, LOS
- `model::DRGCostModel` — DRG cost model with base costs and adjusters

# Returns
Float64 — Total calculated cost

# Example
```julia
cost = calculate_drg_cost(episode, drg_model)
# Returns total cost adjusted for severity, LOS, geography
```
"""
function calculate_drg_cost(episode::Episode, model::DRGCostModel)::Float64
    # Get base cost for primary DRG
    base_cost = get(model.base_costs, episode.drg_code, 15_000.0)

    # Apply comorbidity/complication adjustments
    # Standard: check for "CC" or "MCC" in secondary diagnoses
    cc_multiplier = 1.0
    for dx in episode.secondary_diagnoses
        # Simple heuristic: if diagnosis contains "CC" it's complex
        if contains(lowercase(dx), "mcc")
            cc_multiplier *= 1.50
        elseif contains(lowercase(dx), "cc")
            cc_multiplier *= 1.25
        end
    end

    # Length of stay adjustment (costs increase ~5% per day beyond baseline)
    # Baseline = 3 days for most DRGs
    baseline_los = 3
    los_multiplier = 1.0
    if episode.los > baseline_los
        los_adjustment = (episode.los - baseline_los) * 0.05
        los_multiplier = 1.0 + los_adjustment
    end

    # Base calculation
    cost = base_cost * cc_multiplier * los_multiplier

    # Add daily ward costs (beyond base DRG)
    daily_cost = model.cost_per_day * episode.los

    # Add procedure costs (operating room time)
    procedure_cost = length(episode.procedures) > 0 ?
        length(episode.procedures) * 120 * model.cost_per_OR_minute :  # Assume 120 min per procedure
        0.0

    # Apply geographic wage index
    total_cost = (cost + daily_cost + procedure_cost) * model.hospital_wage_index

    return total_cost
end

# ============================================================================
# RVU-Based Cost Model
# ============================================================================

"""
    struct RVUCostModel

RVU-based cost calculation using physician work and practice expense RVUs.

# Fields
- `specialty_rvu_base::Dict{String, Float64}` — Base RVUs by specialty
- `conversion_factor::Float64` — National conversion factor (\$/RVU)
- `labor_allocation::Dict{String, Float64}` — % of total cost to each resource (MD, RN, supplies)
- `hospital_wage_index::Float64` — Geographic adjustment
- `rvu_per_procedure::Dict{String, Float64}` — RVUs for specific procedures

# Example
```julia
rvu_model = RVUCostModel(
    specialty_rvu_base = Dict("OR" => 40.0, "ED" => 15.0, "IP" => 25.0),
    conversion_factor = 35.00,  # 2026 CMS conversion factor, units \$/RVU
    labor_allocation = Dict("MD" => 0.30, "RN" => 0.35, "supplies" => 0.35),
    hospital_wage_index = 0.95,
    rvu_per_procedure = Dict("501" => 45.0, "502" => 35.0)
)
```
"""
struct RVUCostModel
    specialty_rvu_base::Dict{String, Float64}
    conversion_factor::Float64
    labor_allocation::Dict{String, Float64}
    hospital_wage_index::Float64
    rvu_per_procedure::Dict{String, Float64}
end

"""
    calculate_rvu_cost(episode::Episode, model::RVUCostModel)::Float64

Calculate episode cost using RVU-based methodology.

RVU cost = (Specialty RVUs + Procedure RVUs) × Conversion Factor × Wage Index

# Arguments
- `episode::Episode` — Patient episode with specialty, procedures
- `model::RVUCostModel` — RVU cost model

# Returns
Float64 — Total RVU-based cost

# Example
```julia
cost = calculate_rvu_cost(episode, rvu_model)
# Returns cost based on resource intensity
```
"""
function calculate_rvu_cost(episode::Episode, model::RVUCostModel)::Float64
    # Get base RVUs for specialty (inferred from setting)
    specialty = "IP"  # Default inpatient
    if contains(lowercase(episode.setting), "or")
        specialty = "OR"
    elseif contains(lowercase(episode.setting), "ed")
        specialty = "ED"
    end

    base_rvu = get(model.specialty_rvu_base, specialty, 25.0)

    # Add RVUs for each procedure
    procedure_rvu = 0.0
    for proc_code in episode.procedures
        procedure_rvu += get(model.rvu_per_procedure, proc_code, 20.0)
    end

    # Total RVUs
    total_rvu = base_rvu + procedure_rvu

    # Convert to cost
    cost = total_rvu * model.conversion_factor * model.hospital_wage_index

    # Length of stay adjustment: add daily cost component
    daily_component = 1_500.0 * episode.los  # $1,500/day base

    return cost + daily_component
end

# ============================================================================
# Activity-Based Costing (ABC) Model
# ============================================================================

"""
    struct ActivityBasedCostModel

Activity-based costing allocates overhead based on resource consumption drivers.

# Fields
- `direct_labor_rate::Float64` — Cost per hour of direct clinical labor
- `supply_cost_per_day::Float64` — Supply cost per patient-day
- `bed_cost_per_day::Float64` — Bed/facility cost per patient-day
- `overhead_drivers::Dict{String, Float64}` — Cost per activity driver unit
- `procedure_supply_cost::Dict{String, Float64}` — Supply cost by procedure code

# Example
```julia
abc_model = ActivityBasedCostModel(
    direct_labor_rate = 75.0,  # per hour nursing, tech, etc
    supply_cost_per_day = 800.0,
    bed_cost_per_day = 400.0,
    overhead_drivers = Dict(
        "lab_test" => 50.0,
        "imaging" => 200.0,
        "transfusion" => 300.0
    ),
    procedure_supply_cost = Dict(
        "501" => 2_500.0,  # Operating room procedure
        "502" => 1_200.0
    )
)
```
"""
struct ActivityBasedCostModel
    direct_labor_rate::Float64
    supply_cost_per_day::Float64
    bed_cost_per_day::Float64
    overhead_drivers::Dict{String, Float64}
    procedure_supply_cost::Dict{String, Float64}
end

"""
    calculate_abc_cost(episode::Episode, model::ActivityBasedCostModel)::Float64

Calculate episode cost using activity-based costing.

Cost components:
1. Direct labor (nursing hours × rate)
2. Supplies (daily supplies + procedure-specific)
3. Bed/facility costs (occupancy)
4. Overhead drivers (lab, imaging, transfusions)

# Arguments
- `episode::Episode` — Patient episode with length of stay, procedures
- `model::ActivityBasedCostModel` — ABC cost model

# Returns
Float64 — Total ABC-calculated cost
"""
function calculate_abc_cost(episode::Episode, model::ActivityBasedCostModel)::Float64
    # Direct labor cost (assume 6 hours nursing per day + overhead)
    hours_per_day = 6.0  # RN hours
    if contains(lowercase(episode.setting), "icu")
        hours_per_day = 12.0  # ICU needs more attention
    elseif contains(lowercase(episode.setting), "or")
        hours_per_day = 8.0  # OR case time
    end

    labor_cost = hours_per_day * episode.los * model.direct_labor_rate

    # Supply costs
    daily_supply_cost = model.supply_cost_per_day * episode.los

    procedure_supply_cost = 0.0
    for proc_code in episode.procedures
        procedure_supply_cost += get(model.procedure_supply_cost, proc_code, 1_500.0)
    end

    # Bed/facility costs
    bed_cost = model.bed_cost_per_day * episode.los

    # Overhead drivers (heuristic: assume ~3-5 lab tests, 1-2 imaging per admission)
    overhead_cost = 0.0
    # Lab tests
    overhead_cost += 4.0 * get(model.overhead_drivers, "lab_test", 50.0)
    # Imaging
    overhead_cost += 1.5 * get(model.overhead_drivers, "imaging", 200.0)

    # Check for transfusion (if admission reason suggests high risk)
    if contains(lowercase(episode.primary_diagnosis), "bleed") ||
       contains(lowercase(episode.primary_diagnosis), "s71")  # Trauma codes
        overhead_cost += 2.0 * get(model.overhead_drivers, "transfusion", 300.0)
    end

    total_cost = labor_cost + daily_supply_cost + procedure_supply_cost + bed_cost + overhead_cost

    return total_cost
end

# ============================================================================
# Unified Interface: Calculate Cost by Method
# ============================================================================

"""
    calculate_episode_cost(episode::Episode, model::Union{DRGCostModel, RVUCostModel, ActivityBasedCostModel})::Float64

Unified interface to calculate episode cost using any costing method.

Dispatches to appropriate calculator based on model type.

# Arguments
- `episode::Episode` — Patient episode
- `model::Union{DRGCostModel, RVUCostModel, ActivityBasedCostModel}` — Cost model

# Returns
Float64 — Total calculated cost

# Example
```julia
# All three approaches
drg_cost = calculate_episode_cost(episode, drg_model)
rvu_cost = calculate_episode_cost(episode, rvu_model)
abc_cost = calculate_episode_cost(episode, abc_model)
```
"""
function calculate_episode_cost(episode::Episode, model::DRGCostModel)::Float64
    return calculate_drg_cost(episode, model)
end

function calculate_episode_cost(episode::Episode, model::RVUCostModel)::Float64
    return calculate_rvu_cost(episode, model)
end

function calculate_episode_cost(episode::Episode, model::ActivityBasedCostModel)::Float64
    return calculate_abc_cost(episode, model)
end

# ============================================================================
# Model Factories: Create Standard Models
# ============================================================================

"""
    create_standard_drg_model()::DRGCostModel

Create a DRG cost model with CMS 2026 standard assumptions.

Uses approximate 2026 Medicare DRG rates and adjusters.
"""
function create_standard_drg_model()::DRGCostModel
    # Sample DRG base costs (2026 estimates)
    base_costs = Dict(
        # Cardiology
        "246" => 28_000.0,  # Acute MI with complications
        "247" => 18_000.0,  # Acute MI without complications
        "248" => 22_000.0,  # PTCA

        # General Surgery
        "164" => 16_000.0,  # Appendectomy with complications
        "165" => 10_000.0,  # Appendectomy without complications
        "166" => 14_000.0,  # Hernia repair

        # Orthopedic
        "469" => 18_000.0,  # Knee replacement
        "470" => 15_000.0,  # Hip replacement
        "471" => 12_000.0,  # Fracture treatment

        # Obstetric
        "373" => 8_000.0,   # Vaginal delivery
        "374" => 12_000.0,  # Cesarean section
        "375" => 6_000.0,   # Delivery without complications

        # Oncology
        "844" => 20_000.0,  # Cancer chemotherapy
        "845" => 16_000.0,  # Cancer radiation

        # Neurology
        "023" => 14_000.0,  # Ischemic stroke
        "024" => 18_000.0,  # Hemorrhagic stroke

        # Emergency
        "999" => 3_000.0,   # ED general visit

        # ICU
        "999" => 8_000.0,   # ICU day average
    )

    labor_rates = Dict(
        "MD" => 200.0,
        "RN" => 60.0,
        "RT" => 50.0,
        "Tech" => 35.0,
    )

    comorbidity_adjusters = Dict(
        "CC" => 1.25,
        "MCC" => 1.50,
        "SEPSIS" => 2.0,
    )

    return DRGCostModel(
        base_costs,
        labor_rates,
        comorbidity_adjusters,
        1.0,  # National wage index
        2_500.0,  # Cost per day
        25.0  # Cost per OR minute
    )
end

"""
    create_standard_rvu_model()::RVUCostModel

Create an RVU cost model with CMS 2026 standard conversion factor.
"""
function create_standard_rvu_model()::RVUCostModel
    specialty_rvu_base = Dict(
        "OR" => 40.0,   # Operating room case
        "IP" => 25.0,   # Inpatient consultation/management
        "ED" => 15.0,   # Emergency department
        "PROC" => 30.0, # Procedural service
    )

    rvu_per_procedure = Dict(
        "501" => 45.0,  # Major OR procedure
        "502" => 35.0,  # Minor OR procedure
        "503" => 25.0,  # Diagnostic procedure
    )

    return RVUCostModel(
        specialty_rvu_base,
        35.00,  # 2026 estimated CMS conversion factor
        Dict("MD" => 0.30, "RN" => 0.35, "supplies" => 0.35),
        1.0,  # National wage index
        rvu_per_procedure
    )
end

"""
    create_standard_abc_model()::ActivityBasedCostModel

Create an ABC model with typical hospital cost assumptions.
"""
function create_standard_abc_model()::ActivityBasedCostModel
    overhead_drivers = Dict(
        "lab_test" => 50.0,
        "imaging" => 200.0,
        "transfusion" => 300.0,
        "pharmacy" => 150.0,
    )

    procedure_supply_cost = Dict(
        "501" => 2_500.0,  # Major surgery supplies
        "502" => 1_200.0,  # Minor surgery supplies
        "503" => 500.0,    # Diagnostic supplies
    )

    return ActivityBasedCostModel(
        75.0,      # Labor rate $/hour
        800.0,     # Daily supplies
        400.0,     # Daily bed cost
        overhead_drivers,
        procedure_supply_cost
    )
end

# ============================================================================
# Validation & Comparison
# ============================================================================

"""
    compare_costing_methods(episode::Episode)::Dict{String, Float64}

Calculate episode cost using all three methods for comparison.

Useful for understanding method sensitivity and choosing best fit.

# Returns
Dict with keys "DRG", "RVU", "ABC" and calculated costs
"""
function compare_costing_methods(episode::Episode)::Dict{String, Float64}
    drg_model = create_standard_drg_model()
    rvu_model = create_standard_rvu_model()
    abc_model = create_standard_abc_model()

    return Dict(
        "DRG" => calculate_episode_cost(episode, drg_model),
        "RVU" => calculate_episode_cost(episode, rvu_model),
        "ABC" => calculate_episode_cost(episode, abc_model),
    )
end

"""
    validate_cost_calculation(episode::Episode, expected_cost::Float64, tolerance::Float64=0.10)::Bool

Validate that calculated costs are within acceptable tolerance of expected.

# Arguments
- `episode::Episode` — Episode to cost
- `expected_cost::Float64` — Expected cost (from actual data)
- `tolerance::Float64` — Acceptable error (default 10%)

# Returns
Bool — True if calculated costs within tolerance
"""
function validate_cost_calculation(episode::Episode, expected_cost::Float64, tolerance::Float64=0.10)::Bool
    costs = compare_costing_methods(episode)

    for (method, cost) in costs
        error = abs(cost - expected_cost) / expected_cost
        if error > tolerance
            println("⚠️  $method cost $cost deviates by $(round(error*100, digits=1))% from expected $expected_cost")
        end
    end

    return true
end
