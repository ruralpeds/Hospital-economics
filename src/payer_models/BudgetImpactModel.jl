# ============================================================================
# BUDGET IMPACT MODEL (Module 5)
# ============================================================================
# Project 3-year financial impact for payer-hospital contracts

using Statistics

# ============================================================================
# CORE PROJECTION LOGIC
# ============================================================================

"""
    project_contract_financials(
        contract::PayerContract,
        baseline_cohort::PatientCohort,
        baseline_quality::QualityMetrics,
        historical_volume::Int = 1000,
        inflation_by_year::Dict{Int, Float64} = Dict(2026 => 0.025, 2027 => 0.025, 2028 => 0.025)
    )::ThreeYearContractAnalysis

Project 3-year financial impact of a payer-hospital contract.

Calculates annual financials for years 2026-2028 considering:
- Contract payment terms (FFS, capitation, bundled, shared savings, quality-based)
- Volume growth (typically 2-3% annually)
- Cost inflation by year
- Quality performance bonuses/penalties
- Risk adjustments and stop-loss protections

# Arguments
- contract::PayerContract: Contract structure (FFS, Capitation, Bundled, Shared Savings, Quality-Based)
- baseline_cohort::PatientCohort: Patient cohort definition
- baseline_quality::QualityMetrics: Current/expected quality metrics
- historical_volume::Int: Historical annual volume (cases/members/episodes)
- inflation_by_year::Dict: Annual medical cost inflation rates

# Returns
ThreeYearContractAnalysis with annual breakdowns and cumulative metrics

# Implementation Details
1. Project volume growth at 2% annually (adjustable)
2. Apply medical inflation (typically 3-4% annually)
3. Calculate quality adjustments based on expected performance
4. Compute hospital margin (revenue - costs) for each year
5. Compute payer savings vs. FFS baseline
6. Aggregate 3-year financials and calculate ROI
"""
function project_contract_financials(
    contract::PayerContract,
    baseline_cohort::PatientCohort,
    baseline_quality::QualityMetrics,
    historical_volume::Int = 1000,
    inflation_by_year::Dict{Int, Float64} = Dict(2026 => 0.025, 2027 => 0.025, 2028 => 0.025)
)::ThreeYearContractAnalysis

    # ────────────────────────────────────────────────────────────────────
    # Parameters
    # ────────────────────────────────────────────────────────────────────

    volume_growth = 0.02  # 2% annual growth
    avg_unit_cost = 12000.0  # Baseline avg cost per episode/member
    hospital_cost_percentage = 0.80  # Hospital keeps ~80% of payment for costs
    baseline_ffs_rate = 12000.0

    # ────────────────────────────────────────────────────────────────────
    # Project each year
    # ────────────────────────────────────────────────────────────────────

    annual_results = []

    for year_idx in 1:3
        year_num = 2025 + year_idx
        inflation = get(inflation_by_year, year_num, 0.025)

        # Project volume
        volume = Int(round(historical_volume * (1.0 + volume_growth) ^ (year_idx - 1)))

        # Calculate baseline FFS cost with inflation
        ffs_cost_per_case = baseline_ffs_rate * (1.0 + inflation) ^ (year_idx - 1)
        ffs_total_cost = ffs_cost_per_case * volume

        # Calculate revenue and costs under contract
        hospital_revenue = 0.0
        payer_total_cost = 0.0
        shared_savings = 0.0

        if isa(contract, FeeForServiceContract)
            # FFS: payment is per case
            case_rate = contract.base_rate_per_case * (1.0 + contract.inflation_rate) ^ (year_idx - 1)
            hospital_revenue = case_rate * volume
            payer_total_cost = hospital_revenue

        elseif isa(contract, CapitationContract)
            # Capitation: monthly per member
            monthly_rate = contract.monthly_capitation_per_member * contract.risk_adjuster * (1.0 + inflation) ^ (year_idx - 1)
            annual_pmpm = monthly_rate * 12
            hospital_revenue = annual_pmpm * contract.expected_members
            payer_total_cost = hospital_revenue

        elseif isa(contract, BundledPaymentContract)
            # Bundled: fixed price per episode
            bundle_rate = contract.bundle_price * (1.0 + inflation) ^ (year_idx - 1)
            hospital_revenue = bundle_rate * volume
            payer_total_cost = hospital_revenue

        elseif isa(contract, SharedSavingsContract)
            # Shared Savings: baseline + % of savings
            expected_cost = avg_unit_cost * (1.0 + inflation) ^ (year_idx - 1) * volume
            actual_savings = max(0.0, contract.baseline_cost - expected_cost)

            # Only share if quality threshold met
            if baseline_quality.patient_satisfaction_score >= contract.quality_threshold
                if actual_savings > contract.minimum_savings_threshold
                    shared_savings = actual_savings * contract.shared_savings_rate
                    hospital_revenue = contract.baseline_cost + shared_savings
                else
                    hospital_revenue = contract.baseline_cost
                end
            else
                hospital_revenue = contract.baseline_cost
            end

            # Payer pays baseline or baseline minus savings
            if contract.risk_sharing && actual_savings < 0
                # Hospital shares in losses
                payer_total_cost = contract.baseline_cost + abs(actual_savings) * contract.shared_loss_rate
            else
                payer_total_cost = contract.baseline_cost
            end

        elseif isa(contract, QualityBasedPaymentContract)
            # Quality-based: base + quality adjustment
            quality_adjustment = calculate_quality_adjustment(baseline_quality, baseline_quality, contract.quality_adjustors)
            adjusted_payment = contract.base_payment * (1.0 + quality_adjustment)
            hospital_revenue = adjusted_payment
            payer_total_cost = hospital_revenue
        else
            # Unknown contract type
            hospital_revenue = ffs_total_cost
            payer_total_cost = hospital_revenue
        end

        # Calculate hospital costs
        hospital_costs = hospital_revenue * hospital_cost_percentage

        # Calculate margins
        hospital_margin = hospital_revenue - hospital_costs
        payer_savings = max(0.0, ffs_total_cost - payer_total_cost)

        # Calculate readmissions
        readmission_count = Int(round(volume * baseline_quality.readmission_30day_rate))

        # Create annual result
        annual = AnnualContractFinancials(
            year = year_num,
            hospital_revenue = hospital_revenue,
            hospital_costs = hospital_costs,
            hospital_margin = hospital_margin,
            quality_bonus_hospital = shared_savings,
            risk_adjustment_hospital = 0.0,
            payer_total_cost = payer_total_cost,
            payer_savings_vs_benchmark = payer_savings,
            shared_savings_to_hospital = shared_savings,
            payer_net_cost = payer_total_cost,
            cases = volume,
            admissions = volume,
            readmissions = readmission_count
        )

        push!(annual_results, annual)
    end

    # ────────────────────────────────────────────────────────────────────
    # Aggregate 3-year results
    # ────────────────────────────────────────────────────────────────────

    total_hospital_margin = sum(annual.hospital_margin for annual in annual_results)
    total_payer_savings = sum(annual.payer_savings_vs_benchmark for annual in annual_results)

    # Calculate ROI
    # Hospital ROI: 3-year margin / initial investment (assume 10% of annual revenue)
    initial_investment = annual_results[1].hospital_revenue * 0.10
    roi_hospital = if initial_investment > 0
        total_hospital_margin / initial_investment
    else
        0.0
    end

    # Payer ROI: % reduction in costs
    baseline_3yr_cost = annual_results[1].payer_total_cost * 3  # Rough estimate
    roi_payer = if baseline_3yr_cost > 0
        total_payer_savings / baseline_3yr_cost
    else
        0.0
    end

    # Generate recommendation
    recommendation = "Neutral"
    if total_hospital_margin > annual_results[1].hospital_margin * 1.5  # 50% above year 1
        if total_payer_savings > 0
            recommendation = "Favorable"  # Good for both
        else
            recommendation = "Favorable for Hospital"
        end
    elseif total_hospital_margin < 0
        recommendation = "Unfavorable"
    end

    return ThreeYearContractAnalysis(
        contract_name = contract.name,
        contract_type = contract_type_name(contract),
        year1 = annual_results[1],
        year2 = annual_results[2],
        year3 = annual_results[3],
        total_hospital_margin = total_hospital_margin,
        total_payer_savings = total_payer_savings,
        roi_for_hospital = roi_hospital,
        roi_for_payer = roi_payer,
        recommendation = recommendation
    )
end

"""
    compare_contracts(
        contracts::Vector{PayerContract},
        baseline_cohort::PatientCohort,
        baseline_quality::QualityMetrics,
        historical_volume::Int = 1000
    )::Vector{ThreeYearContractAnalysis}

Compare multiple contracts side-by-side with financial projections.

# Arguments
- contracts: Vector of PayerContract (different types and terms)
- baseline_cohort: Patient cohort
- baseline_quality: Expected quality metrics
- historical_volume: Annual case/member volume

# Returns
Vector of ThreeYearContractAnalysis (one per contract) for comparison
"""
function compare_contracts(
    contracts::Vector{PayerContract},
    baseline_cohort::PatientCohort,
    baseline_quality::QualityMetrics,
    historical_volume::Int = 1000
)::Vector{ThreeYearContractAnalysis}

    analyses = ThreeYearContractAnalysis[]

    for contract in contracts
        analysis = project_contract_financials(
            contract,
            baseline_cohort,
            baseline_quality,
            historical_volume
        )
        push!(analyses, analysis)
    end

    return analyses
end

# ============================================================================
# RISK ADJUSTMENT & QUALITY PENALTIES
# ============================================================================

"""
    apply_risk_adjustment(
        base_payment::Float64,
        patient_risk_factors::Dict{String, Float64},
        risk_model::String = "CMS_HCC"
    )::Float64

Apply risk adjustment to payment based on patient complexity.

Implements CMS Hierarchical Condition Category (HCC) risk adjustment model.

# Arguments
- base_payment: Baseline payment (USD)
- patient_risk_factors: Dict with risk factors and weights
  - "age" => age_factor (1.0 = baseline, >1.0 = higher risk)
  - "comorbidity_count" => number of chronic conditions
  - "prior_admission" => 1.0 if recent admission, else 0.0
  - "chronic_illness" => 0.0-1.0 representing burden

- risk_model: "CMS_HCC" (default) or "Custom"

# Returns
Adjusted payment (typically 0.8-1.3x base)

# Example
```julia
risk_factors = Dict(
    "age" => 1.2,              # 20% increase for age
    "comorbidity_count" => 3,  # 3 chronic conditions
    "chronic_illness" => 0.8   # High disease burden
)
adjusted = apply_risk_adjustment(12000.0, risk_factors)
```
"""
function apply_risk_adjustment(
    base_payment::Float64,
    patient_risk_factors::Dict{String, Float64},
    risk_model::String = "CMS_HCC"
)::Float64

    adjustment_factor = 1.0

    if risk_model == "CMS_HCC"
        # CMS HCC-style adjustment
        # Age factor (1.0 = baseline 65y, increases with age >65)
        age_factor = get(patient_risk_factors, "age", 1.0)
        adjustment_factor *= age_factor

        # Comorbidity factor (each condition adds ~5% risk)
        comorbidity_count = Int(get(patient_risk_factors, "comorbidity_count", 0.0))
        adjustment_factor *= (1.0 + comorbidity_count * 0.05)

        # Prior admission multiplier
        prior_admission = get(patient_risk_factors, "prior_admission", 0.0)
        if prior_admission > 0
            adjustment_factor *= 1.15  # 15% increase if recent admission
        end

        # Chronic illness burden
        chronic_burden = get(patient_risk_factors, "chronic_illness", 0.0)
        adjustment_factor *= (1.0 + chronic_burden * 0.20)

    else
        # Custom model
        adjustment_factor = get(patient_risk_factors, "adjustment_factor", 1.0)
    end

    # Bound to reasonable range (0.5-1.5)
    adjustment_factor = max(0.50, min(1.50, adjustment_factor))

    return base_payment * adjustment_factor
end

"""
    calculate_quality_penalty(
        actual_metrics::QualityMetrics,
        contract::PayerContract
    )::Float64

Calculate payment reduction from quality performance failures.

Penalizes hospital for poor quality performance (mortality, readmission, complications).

# Arguments
- actual_metrics: Actual quality performance
- contract: Contract with quality thresholds

# Returns
Float64: Penalty as fraction (e.g., -0.10 = 10% reduction)
Bounded to [-0.30, 0.0] (max 30% penalty)
"""
function calculate_quality_penalty(
    actual_metrics::QualityMetrics,
    contract::PayerContract
)::Float64

    penalty = 0.0

    # Targets (defaults, may vary by contract type)
    target_mortality = 0.02       # 2%
    target_readmission = 0.12     # 12%
    target_complication = 0.05    # 5%
    target_satisfaction = 0.80    # 80%

    # Mortality penalty: -2% per 1% above target
    if actual_metrics.mortality_rate > target_mortality
        excess_mortality = actual_metrics.mortality_rate - target_mortality
        penalty += min(-0.10, excess_mortality * -0.02)
    end

    # Readmission penalty: -1% per 1% above target
    if actual_metrics.readmission_30day_rate > target_readmission
        excess_readmission = actual_metrics.readmission_30day_rate - target_readmission
        penalty += min(-0.10, excess_readmission * -0.01)
    end

    # Complication penalty: -1.5% per 1% above target
    if actual_metrics.complication_rate > target_complication
        excess_complication = actual_metrics.complication_rate - target_complication
        penalty += min(-0.05, excess_complication * -0.015)
    end

    # Satisfaction bonus (negative penalty = bonus)
    if actual_metrics.patient_satisfaction_score > target_satisfaction
        excess_satisfaction = actual_metrics.patient_satisfaction_score - target_satisfaction
        penalty += min(0.05, excess_satisfaction * 0.03)
    end

    # Bound to [-0.30, 0.0]
    return max(-0.30, min(0.0, penalty))
end

