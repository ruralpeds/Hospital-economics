# Value-Based Care Transition for Rural Hospital Economics Simulator
#
# Models shared savings/loss calculations for Medicare ACO programs including
# MSSP Basic/Enhanced and ACO REACH variants. Projects multi-year financial
# impact of transitioning from fee-for-service to value-based arrangements.

"""
    VBCParams

Parameters for a value-based care shared savings/loss calculation.
Source: CMS Medicare Shared Savings Program (MSSP) Regulations (42 CFR Part 425)

# Fields
- `model_type::Symbol`: ACO model type (see table below)
- `total_cost_of_care::Float64`: actual total cost of care for the period
- `benchmark::Float64`: CMS-assigned spending benchmark
- `patient_panel_size::Int`: number of attributed beneficiaries
- `quality_score::Float64`: composite quality score 0.0-1.0 (default 0.5)
- `risk_track::Symbol`: :one_sided (savings only) or :two_sided (savings and losses)
- `shared_savings_rate::Float64`: fraction of savings retained (default 0.50)
- `shared_loss_rate::Float64`: fraction of losses owed back (default 0.30)
- `min_savings_rate::Float64`: minimum savings rate threshold to qualify (default 0.02)
- `care_management_investment::Float64`: annual care management spending

# Model Types & Rules
| Model | Track | MSR | Loss Cap | Rule |
|-------|-------|-----|----------|------|
| `:mssp_basic` | one-sided | 2% | N/A | 42 CFR §425.100 |
| `:mssp_enhanced` | two-sided | 2% | 8-10% | 42 CFR §425.204 |
| `:aco_lead` | two-sided | 2% | 8-10% | 42 CFR §425.226 |
| `:aco_flex` | two-sided | 3-4% | 5-8% | 42 CFR §425.236 |

Note: Loss caps may increase after year 3 (see calculate_vbc_outcome).
"""
@kwdef struct VBCParams
    model_type::Symbol = :mssp_basic
    total_cost_of_care::Float64
    benchmark::Float64
    patient_panel_size::Int
    quality_score::Float64 = 0.5
    risk_track::Symbol = :one_sided
    shared_savings_rate::Float64 = 0.50
    shared_loss_rate::Float64 = 0.30
    min_savings_rate::Float64 = 0.02
    care_management_investment::Float64 = 0.0
end

"""
    VBCResult

Results of a value-based care reconciliation.

# Fields
- `gross_savings::Float64`: benchmark minus actual cost (negative = losses)
- `meets_minimum_savings::Bool`: whether savings rate exceeds MSR
- `shared_savings_payment::Float64`: payment received from CMS for savings
- `shared_loss_payment::Float64`: payment owed to CMS for losses
- `net_vbc_income::Float64`: shared savings minus shared losses
- `care_management_cost::Float64`: care management investment
- `net_financial_impact::Float64`: net VBC income minus care management cost
- `savings_rate::Float64`: gross savings as fraction of benchmark
- `per_beneficiary_savings::Float64`: gross savings per attributed beneficiary
"""
@kwdef struct VBCResult
    gross_savings::Float64
    meets_minimum_savings::Bool
    shared_savings_payment::Float64
    shared_loss_payment::Float64
    net_vbc_income::Float64
    care_management_cost::Float64
    net_financial_impact::Float64
    savings_rate::Float64
    per_beneficiary_savings::Float64
end

function Base.show(io::IO, r::VBCResult)
    status = r.net_financial_impact >= 0 ? "gain" : "loss"
    print(io, "VBCResult(savings_rate=$(round(r.savings_rate * 100, digits=1))%, net_$(status)=\$$(round(Int, abs(r.net_financial_impact))))")
end

"""
    calculate_vbc_outcome(params::VBCParams) -> VBCResult

Compute shared savings or losses for a value-based care arrangement.

1. Gross savings = benchmark - total cost of care.
2. Savings rate = gross savings / benchmark.
3. If savings rate >= MSR, shared savings = gross_savings * shared_savings_rate * quality_score.
4. If two-sided and losses exist, shared losses = |gross_savings| * shared_loss_rate
   (capped at benchmark percentage based on model type).
5. Net against care management investment.
"""
function calculate_vbc_outcome(params::VBCParams)::VBCResult
    params.model_type in (:mssp_basic, :mssp_enhanced, :aco_lead, :aco_flex) || error("model_type must be one of :mssp_basic, :mssp_enhanced, :aco_lead, :aco_flex; got $(params.model_type)")
    params.benchmark > 0.0 || error("Benchmark must be positive; got $(params.benchmark)")
    params.patient_panel_size > 0 || error("Patient panel size must be positive; got $(params.patient_panel_size)")
    params.risk_track in (:one_sided, :two_sided) || error("risk_track must be :one_sided or :two_sided; got $(params.risk_track)")
    params.total_cost_of_care >= 0.0 || error("total_cost_of_care must be non-negative; got $(params.total_cost_of_care)")
    0.0 <= params.quality_score <= 1.0 || error("quality_score must be between 0 and 1; got $(params.quality_score)")
    0.0 <= params.shared_savings_rate <= 1.0 || error("shared_savings_rate must be between 0 and 1; got $(params.shared_savings_rate)")
    0.0 <= params.shared_loss_rate <= 1.0 || error("shared_loss_rate must be between 0 and 1; got $(params.shared_loss_rate)")
    0.0 <= params.min_savings_rate <= 1.0 || error("min_savings_rate must be between 0 and 1; got $(params.min_savings_rate)")
    params.care_management_investment >= 0.0 || error("care_management_investment must be non-negative; got $(params.care_management_investment)")

    gross_savings = params.benchmark - params.total_cost_of_care
    savings_rate = gross_savings / params.benchmark
    per_bene = gross_savings / params.patient_panel_size

    meets_msr = savings_rate >= params.min_savings_rate

    # Shared savings calculation
    shared_savings = 0.0
    if gross_savings > 0.0 && meets_msr
        # Quality score scales the sharing rate
        effective_rate = params.shared_savings_rate * clamp(params.quality_score, 0.0, 1.0)
        shared_savings = gross_savings * effective_rate
    end

    # Shared loss calculation (two-sided only)
    # Source: CMS MSSP Regulations (42 CFR Part 425)
    shared_losses = 0.0
    if params.risk_track == :two_sided && gross_savings < 0.0
        # Loss cap as percentage of benchmark varies by model and year
        # MSSP Basic: one-sided (no losses) → doesn't reach here
        # MSSP Enhanced: 8% loss cap (years 1-3), 10% (years 4+) per 42 CFR §425.204
        # ACO Lead: similar to MSSP Enhanced, 10% cap per 42 CFR §425.226
        # ACO Flex: specialized model, typically 5-8% cap
        # NOTE (CMS CY2025): MSSP Enhanced loss cap is 8% in contract years 1-3, 10% in years 4+.
        # The year-based escalation is handled by the ExtendedVBCParams in vbc_transition.jl (T-026)
        # and the MSSP Enhanced entry in VBC_MODEL_REGISTRY. This function uses the steady-state rate.
        loss_cap_pct = if params.model_type in (:mssp_enhanced, :aco_lead)
            0.10  # Updated from 0.15 to match CMS standard (years 1-3 is 8%, years 4+ is 10%)
        elseif params.model_type == :aco_flex
            0.08  # ACO Flex typically lower risk
        else
            0.08  # MSSP Basic doesn't use this (one-sided)
        end
        max_loss = params.benchmark * loss_cap_pct
        raw_loss = abs(gross_savings) * params.shared_loss_rate
        shared_losses = min(raw_loss, max_loss)
    end

    net_vbc = shared_savings - shared_losses
    net_impact = net_vbc - params.care_management_investment

    return VBCResult(
        gross_savings = gross_savings,
        meets_minimum_savings = meets_msr,
        shared_savings_payment = shared_savings,
        shared_loss_payment = shared_losses,
        net_vbc_income = net_vbc,
        care_management_cost = params.care_management_investment,
        net_financial_impact = net_impact,
        savings_rate = savings_rate,
        per_beneficiary_savings = per_bene,
    )
end

"""
    vbc_transition_timeline(params::VBCParams; years::Int=5) -> Vector{NamedTuple}

Project year-by-year VBC financial outcomes assuming care management investment
ramps up over the first 3 years and savings improve as population health
management matures. Year 1 captures 30% of potential savings, year 2 captures
60%, and year 3+ captures 90%.
"""
function vbc_transition_timeline(params::VBCParams; years::Int = 5)::Vector{NamedTuple}
    years > 0 || error("years must be positive; got $years")
    params.benchmark > 0.0 || error("Benchmark must be positive; got $(params.benchmark)")
    params.patient_panel_size > 0 || error("Patient panel size must be positive; got $(params.patient_panel_size)")

    # Savings maturity curve: fraction of achievable savings realized each year
    maturity = [0.30, 0.60, 0.90, 0.95, 1.0]

    # Care management investment ramp: 60% year 1, 85% year 2, 100% year 3+
    cm_ramp = [0.60, 0.85, 1.0, 1.0, 1.0]

    timeline = NamedTuple[]
    for yr in 1:years
        idx = min(yr, length(maturity))
        mat = maturity[idx]
        cm_frac = cm_ramp[min(yr, length(cm_ramp))]

        # Adjust actual cost to reflect improving care management
        potential_savings = params.benchmark - params.total_cost_of_care
        yr_actual = if potential_savings > 0
            # Maturity fraction of savings realized: costs decrease toward benchmark
            params.total_cost_of_care - (potential_savings * mat)
        else
            # When over benchmark, maturity reduces cost overruns
            params.total_cost_of_care + abs(potential_savings) * (1.0 - mat)
        end

        yr_cm_cost = params.care_management_investment * cm_frac

        yr_params = VBCParams(
            model_type = params.model_type,
            total_cost_of_care = yr_actual,
            benchmark = params.benchmark,
            patient_panel_size = params.patient_panel_size,
            quality_score = min(1.0, params.quality_score + 0.05 * (yr - 1)),
            risk_track = params.risk_track,
            shared_savings_rate = params.shared_savings_rate,
            shared_loss_rate = params.shared_loss_rate,
            min_savings_rate = params.min_savings_rate,
            care_management_investment = yr_cm_cost,
        )

        result = calculate_vbc_outcome(yr_params)

        push!(timeline, (
            year = yr,
            total_cost_of_care = yr_actual,
            savings_rate = result.savings_rate,
            shared_savings = result.shared_savings_payment,
            shared_losses = result.shared_loss_payment,
            care_management_cost = yr_cm_cost,
            net_financial_impact = result.net_financial_impact,
        ))
    end

    return timeline
end

# ─────────────────────────────────────────────────────────────────────────────
# T-026: VBC Model Variants for Specialized ACOs
# ─────────────────────────────────────────────────────────────────────────────

"""
    ExtendedVBCModel

Enumeration of all supported VBC model variants, including specialized ACO
tracks beyond the four basic models in the original implementation.

| Key | Model | Track |
|---|---|---|
| `:mssp_basic` | MSSP Basic | Track 1/1+ (one-sided) |
| `:mssp_enhanced` | MSSP Enhanced | Track 1+ (two-sided) |
| `:aco_lead` | ACO REACH | High-Needs Population |
| `:aco_flex` | ACO REACH | Standard/New Entrant |
| `:aco_reach_pioneer` | ACO REACH | Global Risk (ex-Pioneer) |
| `:aco_global_cap` | Global Capitation | Full-risk PMPM |
| `:mssp_low_revenue` | MSSP Low-Revenue | Small rural ACO variant |
| `:team_bundled` | TEAM | CMS mandatory episode (2026+) |
| `:kidney_care` | CKCC Kidney Care | End-stage renal disease |
| `:oncology_care` | OCM successor | Radiation oncology episode |
"""
const EXTENDED_VBC_MODEL_KEYS = (
    :mssp_basic, :mssp_enhanced, :aco_lead, :aco_flex,
    :aco_reach_pioneer, :aco_global_cap, :mssp_low_revenue,
    :team_bundled, :kidney_care, :oncology_care,
)

"""
    VBCModelProperties

Metadata for a VBC model variant.

# Fields
- `key::Symbol`
- `display_name::String`
- `one_sided::Bool`: `true` = downside risk waived (upside only).
- `savings_rate_range::Tuple{Float64,Float64}`: Min/max sharing rate.
- `loss_cap_pct::Float64`: Maximum loss exposure as fraction of benchmark.
- `min_savings_rate::Float64`: Minimum savings rate (MSR) before sharing begins.
- `benchmark_years::Int`: Look-back benchmark period in years.
- `quality_gate::Bool`: Whether quality scores gate savings distribution.
- `rural_eligible::Bool`: Whether rural hospitals / small ACOs are eligible.
- `notes::String`
"""
@kwdef struct VBCModelProperties
    key::Symbol
    display_name::String
    one_sided::Bool
    savings_rate_range::Tuple{Float64, Float64}
    loss_cap_pct::Float64
    min_savings_rate::Float64
    benchmark_years::Int
    quality_gate::Bool
    rural_eligible::Bool
    notes::String = ""
end

const _VBC_MODEL_REGISTRY = Dict{Symbol, VBCModelProperties}(
    :mssp_basic => VBCModelProperties(
        key=:mssp_basic, display_name="MSSP Basic Track (one-sided)",
        one_sided=true, savings_rate_range=(0.40, 0.50), loss_cap_pct=0.0,
        min_savings_rate=0.02, benchmark_years=3, quality_gate=true,
        rural_eligible=true,
        notes="Track 1: upside only, no downside risk. First-year ACOs typically start here.",
    ),
    :mssp_enhanced => VBCModelProperties(
        key=:mssp_enhanced, display_name="MSSP Enhanced Track (two-sided)",
        one_sided=false, savings_rate_range=(0.50, 0.75), loss_cap_pct=0.08,
        min_savings_rate=0.0, benchmark_years=3, quality_gate=true,
        rural_eligible=true,
        notes="Track 1+: two-sided risk; higher sharing rate in exchange for downside exposure.",
    ),
    :aco_lead => VBCModelProperties(
        key=:aco_lead, display_name="ACO REACH — High-Needs Population",
        one_sided=false, savings_rate_range=(0.50, 1.00), loss_cap_pct=0.15,
        min_savings_rate=0.0, benchmark_years=3, quality_gate=true,
        rural_eligible=true,
        notes="High-Needs Population model targets complex, chronically ill beneficiaries. " *
              "Up to 100% risk sharing; prospective PMPM capitation option.",
    ),
    :aco_flex => VBCModelProperties(
        key=:aco_flex, display_name="ACO REACH — Standard / New Entrant",
        one_sided=false, savings_rate_range=(0.50, 0.80), loss_cap_pct=0.10,
        min_savings_rate=0.0, benchmark_years=3, quality_gate=true,
        rural_eligible=true,
        notes="Standard REACH model. New Entrant track for organisations without prior ACO history.",
    ),
    :aco_reach_pioneer => VBCModelProperties(
        key=:aco_reach_pioneer, display_name="ACO REACH — Global Risk (ex-Pioneer)",
        one_sided=false, savings_rate_range=(0.80, 1.00), loss_cap_pct=0.20,
        min_savings_rate=0.0, benchmark_years=3, quality_gate=true,
        rural_eligible=false,
        notes="Highest-risk REACH track, evolved from Pioneer ACO Model. " *
              "Full global capitation with prospective payments. Large health systems only.",
    ),
    :aco_global_cap => VBCModelProperties(
        key=:aco_global_cap, display_name="Global Capitation ACO",
        one_sided=false, savings_rate_range=(1.00, 1.00), loss_cap_pct=0.25,
        min_savings_rate=0.0, benchmark_years=3, quality_gate=true,
        rural_eligible=false,
        notes="Commercial / MA-adjacent full-risk PMPM contract. " *
              "ACO bears 100% of surplus and deficit. Requires substantial risk infrastructure.",
    ),
    :mssp_low_revenue => VBCModelProperties(
        key=:mssp_low_revenue, display_name="MSSP Low-Revenue ACO",
        one_sided=true, savings_rate_range=(0.40, 0.65), loss_cap_pct=0.0,
        min_savings_rate=0.015, benchmark_years=3, quality_gate=true,
        rural_eligible=true,
        notes="Preferred track for small rural and CAH-based ACOs with low per-beneficiary " *
              "revenue. CMS applies lower MSR and alternative benchmarking methodology.",
    ),
    :team_bundled => VBCModelProperties(
        key=:team_bundled, display_name="TEAM Mandatory Episode Model (2026+)",
        one_sided=false, savings_rate_range=(0.0, 1.00), loss_cap_pct=0.20,
        min_savings_rate=0.0, benchmark_years=3, quality_gate=true,
        rural_eligible=true,
        notes="Transforming Episode Accountability Model — mandatory CMS program starting 2026. " *
              "5 episode types: CABG, LEJR, major bowel procedure, surgical hip fracture, spinal fusion. " *
              "Target price = historical price × quality adjustment. CAHs are exempt.",
    ),
    :kidney_care => VBCModelProperties(
        key=:kidney_care, display_name="CKCC Kidney Care Choices",
        one_sided=false, savings_rate_range=(0.40, 0.80), loss_cap_pct=0.10,
        min_savings_rate=0.0, benchmark_years=3, quality_gate=true,
        rural_eligible=true,
        notes="Comprehensive Kidney Care Contracting model. Targets ESRD and late-stage CKD. " *
              "Dialysis providers and nephrologists as ACO participants.",
    ),
    :oncology_care => VBCModelProperties(
        key=:oncology_care, display_name="Enhancing Oncology Model (EOM)",
        one_sided=false, savings_rate_range=(0.40, 1.00), loss_cap_pct=0.10,
        min_savings_rate=0.0, benchmark_years=3, quality_gate=true,
        rural_eligible=true,
        notes="Six-month episodes around chemotherapy initiation. Successor to the " *
              "Oncology Care Model (OCM). Monthly enhanced oncology services payment.",
    ),
)

"""
    vbc_model_registry() -> Dict{Symbol, VBCModelProperties}

Return all registered VBC model variants and their metadata.
"""
vbc_model_registry() = copy(_VBC_MODEL_REGISTRY)

"""
    vbc_model_properties(key::Symbol) -> VBCModelProperties

Look up metadata for a VBC model variant. Throws `KeyError` for unknown keys.
"""
function vbc_model_properties(key::Symbol)::VBCModelProperties
    haskey(_VBC_MODEL_REGISTRY, key) ||
        throw(KeyError("Unknown VBC model: $(repr(key)). " *
                       "Valid: $(sort(collect(keys(_VBC_MODEL_REGISTRY))))"))
    _VBC_MODEL_REGISTRY[key]
end

"""
    ExtendedVBCParams

Parameters for an extended VBC calculation that supports all registered models.

Additional fields beyond `VBCParams`:
- `model_key::Symbol`: One of `EXTENDED_VBC_MODEL_KEYS`.
- `pmpm_benchmark::Float64`: Monthly per-member-per-month cost benchmark (for
  capitation models).
- `attributed_members::Int`: Number of attributed beneficiaries.
- `quality_score::Float64`: Quality composite score in [0, 1]; gates savings
  when `model.quality_gate == true`.
- `episode_type::Union{Symbol, Nothing}`: For episode-based models (`:team_bundled`,
  `:oncology_care`, `:kidney_care`).
"""
@kwdef struct ExtendedVBCParams
    model_key::Symbol
    actual_expenditure::Float64
    benchmark_expenditure::Float64
    pmpm_benchmark::Float64        = 0.0
    attributed_members::Int        = 0
    quality_score::Float64         = 1.0    # 0..1; 1 = full savings
    episode_type::Union{Symbol, Nothing} = nothing
    # Optional overrides (if nothing, use registry defaults)
    savings_share_rate::Union{Float64, Nothing} = nothing
    loss_cap_override::Union{Float64, Nothing}  = nothing
end

"""
    ExtendedVBCResult

Result of an extended VBC calculation.

# Fields
- `model_key`, `display_name`
- `gross_savings::Float64`: Benchmark − actual expenditure (can be negative).
- `quality_adjusted_savings::Float64`: Gross savings × quality score.
- `shared_savings::Float64`: What the ACO receives (positive) or owes (negative).
- `loss_cap_applied::Bool`: Whether the loss cap was binding.
- `savings_rate_used::Float64`: Effective sharing rate applied.
- `net_acm_revenue::Float64`: Net additional revenue to the ACO (saved + shared).
"""
struct ExtendedVBCResult
    model_key::Symbol
    display_name::String
    gross_savings::Float64
    quality_adjusted_savings::Float64
    shared_savings::Float64
    loss_cap_applied::Bool
    savings_rate_used::Float64
    net_acm_revenue::Float64
end

"""
    calculate_extended_vbc(params::ExtendedVBCParams) -> ExtendedVBCResult

Compute shared savings / losses for any registered VBC model variant.

Quality gating: when `props.quality_gate == true`, gross savings are multiplied
by `params.quality_score` before the sharing-rate is applied. This mirrors CMS
MSSP and REACH quality-performance gates.

Loss cap: when `!props.one_sided`, losses are capped at
`props.loss_cap_pct × params.benchmark_expenditure`. If `loss_cap_override` is
set it takes precedence.

# Example
```julia
result = calculate_extended_vbc(ExtendedVBCParams(
    model_key            = :mssp_low_revenue,
    actual_expenditure   = 4_800_000.0,
    benchmark_expenditure = 5_000_000.0,
    quality_score        = 0.88,
))
result.shared_savings   # ACO's share of the $200k savings
```
"""
function calculate_extended_vbc(params::ExtendedVBCParams)::ExtendedVBCResult
    params.model_key in keys(_VBC_MODEL_REGISTRY) ||
        throw(ArgumentError("Unknown VBC model: $(repr(params.model_key))"))

    props = _VBC_MODEL_REGISTRY[params.model_key]

    gross_savings = params.benchmark_expenditure - params.actual_expenditure

    # Quality adjustment
    qa_savings = props.quality_gate ?
        gross_savings * clamp(params.quality_score, 0.0, 1.0) :
        gross_savings

    # Determine sharing rate
    lo, hi = props.savings_rate_range
    rate = isnothing(params.savings_share_rate) ?
        (lo + hi) / 2.0 : clamp(params.savings_share_rate, lo, hi)

    # Compute shared savings / loss
    shared = qa_savings * rate

    # Apply loss cap (one-sided models never pay losses)
    loss_cap_pct = isnothing(params.loss_cap_override) ?
        props.loss_cap_pct : params.loss_cap_override
    cap_floor    = props.one_sided ? 0.0 : -(loss_cap_pct * params.benchmark_expenditure)
    loss_applied = shared < cap_floor
    shared_clamped = max(shared, cap_floor)

    ExtendedVBCResult(
        params.model_key,
        props.display_name,
        gross_savings,
        qa_savings,
        shared_clamped,
        loss_applied,
        rate,
        shared_clamped,   # net ACO revenue = shared savings (positive) or loss (negative)
    )
end

"""
    rural_vbc_models() -> Vector{Symbol}

Return keys for all VBC models where `rural_eligible == true`.
"""
rural_vbc_models() = [k for (k, p) in _VBC_MODEL_REGISTRY if p.rural_eligible] |> sort
