# Scenario and policy parameter types for Rural Hospital Economics Simulator

using Dates

"""
    StaffingConstraints

Constraints on staffing levels, recruitment, and workforce policy.
"""
@kwdef mutable struct StaffingConstraints
    max_vacancy_rate::Float64 = 0.15
    max_travel_dependency_pct::Float64 = 0.25
    min_nurse_to_patient_ratio::Float64 = 0.25  # nurses per patient
    max_provider_panel_size::Int = 2000
    annual_wage_growth_rate::Float64 = 0.03
    benefits_inflation_rate::Float64 = 0.05
    travel_premium_cap::Float64 = 1.50  # max multiplier on base rate
    recruitment_budget_pct_of_salary::Float64 = 0.15
    retention_bonus_eligible::Bool = false
    retention_bonus_amount::Float64 = 0.0
    loan_repayment_program::Bool = false
    loan_repayment_annual_amount::Float64 = 0.0
    visa_waiver_slots::Int = 0
    telehealth_substitution_pct::Float64 = 0.0  # fraction of visits deliverable via telehealth
end

"""
    ConversionParams

Parameters governing CAH-to-REH or other facility conversion scenarios.
"""
@kwdef mutable struct ConversionParams
    conversion_type::Symbol = :cah_to_reh  # :cah_to_reh, :pps_to_reh, :reh_to_cah, :closure
    conversion_date::Date = Date(2025, 1, 1)
    one_time_conversion_cost::Float64 = 500_000.0
    annual_reh_facility_payment::Float64 = 3_274_392.0  # 12 * $272,866
    outpatient_add_on_pct::Float64 = 0.05
    retained_service_lines::Vector{Symbol} = [:emergency, :outpatient, :telehealth]
    eliminated_service_lines::Vector{Symbol} = [:inpatient, :swing_bed, :obstetrics]
    staff_reduction_pct::Float64 = 0.30
    severance_weeks_per_year::Float64 = 2.0
    ramp_up_months::Int = 6  # months to reach steady-state operations
    capital_repurposing_cost::Float64 = 0.0
    inpatient_transfer_distance_miles::Float64 = 0.0
    community_impact_score::Float64 = 0.0  # 0-100 qualitative rating
end

"""
    PortfolioParams

Parameters for service line portfolio optimization.
"""
@kwdef mutable struct PortfolioParams
    min_service_lines::Int = 3
    max_service_lines::Int = 15
    required_service_lines::Vector{Symbol} = [:emergency]
    min_operating_margin::Float64 = -0.05  # allow small losses on essential services
    community_benefit_weight::Float64 = 0.3
    financial_weight::Float64 = 0.5
    strategic_weight::Float64 = 0.2
    volume_growth_target::Float64 = 0.02
    max_referral_leakage::Float64 = 0.30
end

"""
    SystemDynamicsParams

Parameters for system dynamics (stock-and-flow) modeling of hospital economics.
"""
@kwdef mutable struct SystemDynamicsParams
    time_horizon_years::Int = 10
    dt::Float64 = 0.25  # time step in years (quarterly)
    population_growth_rate::Float64 = -0.005  # rural population decline
    aging_rate::Float64 = 0.01  # annual shift in age distribution
    inflation_rate::Float64 = 0.03
    medical_inflation_rate::Float64 = 0.05
    technology_cost_growth::Float64 = 0.04
    reimbursement_growth_rate::Float64 = 0.02
    volume_elasticity_to_distance::Float64 = -0.3
    volume_elasticity_to_quality::Float64 = 0.2
    physician_retirement_rate::Float64 = 0.05
    nurse_attrition_rate::Float64 = 0.15
    cash_reserve_target_days::Float64 = 60.0
    debt_capacity_ratio::Float64 = 0.40
    capital_reinvestment_rate::Float64 = 0.05
end

"""
    PolicyScenario <: AbstractSimulationParams

Comprehensive policy scenario for simulation. Encodes federal/state policy
parameters that affect rural hospital economics per Chapter 16 of the spec.
"""
@kwdef mutable struct PolicyScenario <: AbstractSimulationParams
    scenario_name::String = "Baseline"
    scenario_description::String = ""
    effective_date::Date = Date(2025, 1, 1)

    # --- Medicaid parameters ---
    medicaid_expansion_enabled::Bool = true
    medicaid_fmap_rate::Float64 = 0.90  # Federal Medical Assistance Percentage
    medicaid_base_rate_index::Float64 = 1.0  # multiplier on base Medicaid rates
    medicaid_managed_care_pct::Float64 = 0.70
    medicaid_dsh_allotment::Float64 = 0.0  # state DSH allotment
    medicaid_rate_update_pct::Float64 = 0.02
    medicaid_eligibility_threshold::Float64 = 1.38  # as fraction of FPL

    # --- Medicare parameters ---
    medicare_update_factor::Float64 = 0.02  # annual payment update
    medicare_sequestration_pct::Float64 = 0.02  # 2% sequestration
    cah_cost_reimbursement_pct::Float64 = 1.01  # 101% of reasonable cost
    reh_monthly_facility_payment::Float64 = 272_866.0
    reh_outpatient_add_on_pct::Float64 = 0.05
    medicare_bad_debt_reimbursement_pct::Float64 = 0.65
    swing_bed_snf_rate_pct::Float64 = 1.0  # percentage of SNF PPS rate
    sole_community_hold_harmless::Bool = true
    low_volume_adjustment_enabled::Bool = true
    low_volume_discharge_threshold::Int = 3800
    medicare_advantage_penetration::Float64 = 0.35
    medicare_advantage_rate_index::Float64 = 0.95  # relative to FFS rates

    # --- ACA Marketplace parameters ---
    marketplace_enrollment_pct::Float64 = 0.05
    marketplace_avg_actuarial_value::Float64 = 0.70
    premium_subsidy_threshold::Float64 = 4.0  # times FPL
    cost_sharing_reduction_enabled::Bool = true
    individual_mandate_penalty::Float64 = 0.0

    # --- Rural-specific programs ---
    rural_health_clinic_enabled::Bool = true
    telehealth_expansion_enabled::Bool = true
    telehealth_originating_site_fee::Float64 = 29.0
    state_flex_program_funding::Float64 = 0.0
    usda_loan_program_enabled::Bool = true
    community_health_center_funding::Float64 = 0.0
    ems_supplemental_payment::Float64 = 0.0
    small_rural_hospital_transition_grant::Float64 = 0.0

    # --- Staffing policy ---
    staffing_constraints::StaffingConstraints = StaffingConstraints()
    minimum_wage::Float64 = 7.25
    nurse_staffing_mandate::Bool = false
    gme_rural_track_slots::Int = 0
    nhsc_loan_repayment_slots::Int = 0
    visa_waiver_program_enabled::Bool = true
    interstate_licensure_compact::Bool = true

    # --- Conversion and structural ---
    conversion_params::Union{ConversionParams, Nothing} = nothing
    portfolio_params::PortfolioParams = PortfolioParams()
    system_dynamics_params::SystemDynamicsParams = SystemDynamicsParams()
end

function Base.show(io::IO, ps::PolicyScenario)
    print(io, "PolicyScenario(\"$(ps.scenario_name)\", effective=$(ps.effective_date))")
end
