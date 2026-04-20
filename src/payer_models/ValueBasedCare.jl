# ============================================================================
# VALUE-BASED CARE CONTRACTS (Module 5)
# ============================================================================
# Payer-hospital contract models with financial impact analysis

using Dates

# ============================================================================
# ABSTRACT CONTRACT TYPE
# ============================================================================

"""
    PayerContract

Abstract base type for payer-hospital contracts.
All specific contract types (FFS, Capitation, Bundled, Shared Savings, Quality-Based)
inherit from this type for polymorphic payment calculation.
"""
abstract type PayerContract end

# ============================================================================
# CONCRETE CONTRACT TYPES
# ============================================================================

"""
    FeeForServiceContract <: PayerContract

Traditional fee-for-service (FFS) contract with per-case payment.
The baseline payment model for comparison.

# Fields
- name::String: Contract identifier
- base_rate_per_case::Float64: Payment per case in USD (Medicare reference rate)
- annual_volume::Int: Expected number of cases/year
- inflation_rate::Float64: Annual payment increase (default: 2.5%)
"""
struct FeeForServiceContract <: PayerContract
    name::String
    base_rate_per_case::Float64
    annual_volume::Int
    inflation_rate::Float64
end

function FeeForServiceContract(;
    name::String = "FFS Baseline",
    base_rate_per_case::Float64 = 12000.0,
    annual_volume::Int = 1000,
    inflation_rate::Float64 = 0.025
)
    FeeForServiceContract(name, base_rate_per_case, annual_volume, inflation_rate)
end

"""
    CapitationContract <: PayerContract

Capitation (per member per month) contract with fixed monthly payments.
Hospital bears full risk for utilization.

# Fields
- name::String: Contract identifier
- monthly_capitation_per_member::Float64: Fixed PMPM payment in USD
- expected_members::Int: Number of covered members
- risk_adjuster::Float64: Risk adjustment factor (0.8-1.2)
- stop_loss_threshold::Float64: % of capitation triggering stop-loss
- carve_outs::Vector{String}: Services excluded (e.g., [\"specialty\", \"mental_health\"])
"""
struct CapitationContract <: PayerContract
    name::String
    monthly_capitation_per_member::Float64
    expected_members::Int
    risk_adjuster::Float64
    stop_loss_threshold::Float64
    carve_outs::Vector{String}
end

function CapitationContract(;
    name::String = "Capitation",
    monthly_capitation_per_member::Float64 = 800.0,
    expected_members::Int = 5000,
    risk_adjuster::Float64 = 1.0,
    stop_loss_threshold::Float64 = 1.15,
    carve_outs::Vector{String} = String[]
)
    CapitationContract(name, monthly_capitation_per_member, expected_members, risk_adjuster, stop_loss_threshold, carve_outs)
end

"""
    BundledPaymentContract <: PayerContract

Episode-based bundled payment with fixed payment per episode.
Hospital responsible for all costs within episode window.

# Fields
- name::String: Contract identifier
- bundle_price::Float64: Fixed payment per episode in USD
- episode_window_days::Int: Time window for episode (30, 90, or 180)
- included_services::Vector{String}: Services included in bundle
- episode_types::Vector{String}: DRGs included in bundle
- annual_volume::Int: Expected episodes/year
- outlier_threshold::Float64: % deviation triggering outlier adjustment
"""
struct BundledPaymentContract <: PayerContract
    name::String
    bundle_price::Float64
    episode_window_days::Int
    included_services::Vector{String}
    episode_types::Vector{String}
    annual_volume::Int
    outlier_threshold::Float64
end

function BundledPaymentContract(;
    name::String = "Bundled Payment",
    bundle_price::Float64 = 18000.0,
    episode_window_days::Int = 90,
    included_services::Vector{String} = ["inpatient", "professional"],
    episode_types::Vector{String} = ["246"],  # DRG 246 (MI)
    annual_volume::Int = 500,
    outlier_threshold::Float64 = 0.25
)
    BundledPaymentContract(name, bundle_price, episode_window_days, included_services, episode_types, annual_volume, outlier_threshold)
end

"""
    SharedSavingsContract <: PayerContract

Accountable Care Organization (ACO) model with shared savings and potential losses.
Hospital shares in cost savings vs. benchmark.

# Fields
- name::String: Contract identifier
- baseline_cost::Float64: Benchmark cost (USD/year)
- shared_savings_rate::Float64: % shared with hospital (0.4-0.8)
- quality_threshold::Float64: Quality score (0-1) required to share savings
- minimum_savings_threshold::Float64: \$ minimum savings to trigger sharing
- risk_sharing::Bool: Hospital shares losses below baseline
- shared_loss_rate::Float64: % of losses borne by hospital (0.25-0.75)
"""
struct SharedSavingsContract <: PayerContract
    name::String
    baseline_cost::Float64
    shared_savings_rate::Float64
    quality_threshold::Float64
    minimum_savings_threshold::Float64
    risk_sharing::Bool
    shared_loss_rate::Float64
end

function SharedSavingsContract(;
    name::String = "Shared Savings",
    baseline_cost::Float64 = 12_000_000.0,
    shared_savings_rate::Float64 = 0.50,
    quality_threshold::Float64 = 0.80,
    minimum_savings_threshold::Float64 = 50000.0,
    risk_sharing::Bool = false,
    shared_loss_rate::Float64 = 0.25
)
    SharedSavingsContract(name, baseline_cost, shared_savings_rate, quality_threshold, minimum_savings_threshold, risk_sharing, shared_loss_rate)
end

"""
    QualityBasedPaymentContract <: PayerContract

Quality-based payment with bonuses/penalties for performance metrics.
Payment adjusted based on quality scorecard performance.

# Fields
- name::String: Contract identifier
- base_payment::Float64: Base annual payment in USD
- quality_metrics::Dict{String, Float64}: Metric → target value (0-1)
- quality_adjustors::Dict{String, Float64}: Metric → % adjustment per point
- bonus_potential::Float64: Max % increase from quality bonuses
- penalty_potential::Float64: Max % decrease from quality penalties
"""
struct QualityBasedPaymentContract <: PayerContract
    name::String
    base_payment::Float64
    quality_metrics::Dict{String, Float64}
    quality_adjustors::Dict{String, Float64}
    bonus_potential::Float64
    penalty_potential::Float64
end

function QualityBasedPaymentContract(;
    name::String = "Quality-Based",
    base_payment::Float64 = 12_000_000.0,
    quality_metrics::Dict{String, Float64} = Dict(
        "mortality" => 0.03,
        "readmission" => 0.15,
        "patient_satisfaction" => 0.85,
        "complication_rate" => 0.05
    ),
    quality_adjustors::Dict{String, Float64} = Dict(
        "mortality" => -0.02,          # -2% per 1% over target
        "readmission" => -0.01,        # -1% per 1% over target
        "patient_satisfaction" => 0.03, # +3% per 1% above target
        "complication_rate" => -0.02   # -2% per 1% over target
    ),
    bonus_potential::Float64 = 0.10,
    penalty_potential::Float64 = 0.15
)
    QualityBasedPaymentContract(name, base_payment, quality_metrics, quality_adjustors, bonus_potential, penalty_potential)
end

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

"""
    contract_type_name(contract::PayerContract)::String

Get human-readable contract type name.
"""
function contract_type_name(contract::PayerContract)::String
    if isa(contract, FeeForServiceContract)
        return "Fee-for-Service"
    elseif isa(contract, CapitationContract)
        return "Capitation (PMPM)"
    elseif isa(contract, BundledPaymentContract)
        return "Bundled Payment"
    elseif isa(contract, SharedSavingsContract)
        return "Shared Savings (ACO)"
    elseif isa(contract, QualityBasedPaymentContract)
        return "Quality-Based Payment"
    else
        return "Unknown"
    end
end

"""
    get_annual_revenue(contract::PayerContract, annual_volume::Int, avg_cost::Float64)::Float64

Calculate projected annual revenue under contract.

# Arguments
- contract::PayerContract: Contract definition
- annual_volume::Int: Expected cases/episodes/patients per year
- avg_cost::Float64: Average actual cost per episode/member/year

# Returns
Projected annual revenue in USD
"""
function get_annual_revenue(contract::PayerContract, annual_volume::Int, avg_cost::Float64)::Float64
    if isa(contract, FeeForServiceContract)
        return contract.base_rate_per_case * annual_volume
    elseif isa(contract, CapitationContract)
        return contract.monthly_capitation_per_member * contract.risk_adjuster * contract.expected_members * 12
    elseif isa(contract, BundledPaymentContract)
        return contract.bundle_price * annual_volume
    elseif isa(contract, SharedSavingsContract)
        return contract.baseline_cost  # Base, before shared savings adjustment
    elseif isa(contract, QualityBasedPaymentContract)
        return contract.base_payment
    else
        return 0.0
    end
end

