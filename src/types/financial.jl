# Financial types for Rural Hospital Economics Simulator

using Dates
using UUIDs

"""
    AnnualFinancials

Complete annual financial summary for a hospital entity. Encompasses revenue,
expense, balance sheet, and key financial performance indicators.
"""
@kwdef mutable struct AnnualFinancials
    fiscal_year::Int
    fiscal_year_end::Date

    # Revenue
    gross_patient_revenue::Float64 = 0.0
    inpatient_revenue::Float64 = 0.0
    outpatient_revenue::Float64 = 0.0
    swing_bed_revenue::Float64 = 0.0
    emergency_revenue::Float64 = 0.0
    physician_revenue::Float64 = 0.0
    other_operating_revenue::Float64 = 0.0
    non_operating_revenue::Float64 = 0.0

    # Deductions from revenue
    contractual_adjustments::Float64 = 0.0
    charity_care::Float64 = 0.0
    bad_debt_expense::Float64 = 0.0
    total_deductions::Float64 = 0.0

    # Net revenue
    net_patient_revenue::Float64 = 0.0
    total_operating_revenue::Float64 = 0.0
    total_revenue::Float64 = 0.0

    # Operating expenses
    salaries_wages::Float64 = 0.0
    employee_benefits::Float64 = 0.0
    physician_fees::Float64 = 0.0
    purchased_services::Float64 = 0.0
    supplies::Float64 = 0.0
    pharmaceuticals::Float64 = 0.0
    utilities::Float64 = 0.0
    insurance::Float64 = 0.0
    lease_rental::Float64 = 0.0
    depreciation::Float64 = 0.0
    amortization::Float64 = 0.0
    interest_expense::Float64 = 0.0
    other_operating_expenses::Float64 = 0.0
    total_operating_expenses::Float64 = 0.0

    # Margins and performance
    operating_income::Float64 = 0.0
    operating_margin::Float64 = 0.0
    total_margin::Float64 = 0.0
    ebitda::Float64 = 0.0
    ebitda_margin::Float64 = 0.0

    # Balance sheet items
    total_assets::Float64 = 0.0
    current_assets::Float64 = 0.0
    cash_and_equivalents::Float64 = 0.0
    net_accounts_receivable::Float64 = 0.0
    total_liabilities::Float64 = 0.0
    current_liabilities::Float64 = 0.0
    long_term_debt::Float64 = 0.0
    net_assets::Float64 = 0.0

    # Key ratios
    current_ratio::Float64 = 0.0
    days_cash_on_hand::Float64 = 0.0
    days_in_accounts_receivable::Float64 = 0.0
    debt_to_capitalization::Float64 = 0.0
    average_age_of_plant::Float64 = 0.0

    # Volume statistics
    inpatient_days::Int = 0
    inpatient_discharges::Int = 0
    observation_hours::Float64 = 0.0
    ed_visits::Int = 0
    outpatient_visits::Int = 0
    surgical_cases::Int = 0
    births::Int = 0

    # Medicare/Medicaid specifics
    medicare_days_pct::Float64 = 0.0
    medicaid_days_pct::Float64 = 0.0
    medicare_cost_to_charge_ratio::Float64 = 0.0
    cost_per_adjusted_discharge::Float64 = 0.0

    # Sustainability flags
    is_operating_loss::Bool = false
    consecutive_loss_years::Int = 0
end

function Base.show(io::IO, f::AnnualFinancials)
    print(io, "AnnualFinancials(FY$(f.fiscal_year), margin=$(round(f.operating_margin * 100, digits=1))%)")
end

"""
    CostCenter

An individual cost center within a hospital's cost accounting system.
"""
@kwdef mutable struct CostCenter
    cost_center_code::String
    name::String
    category::Symbol  # :overhead, :direct_patient, :ancillary, :support
    is_revenue_producing::Bool = false
    direct_costs::Float64 = 0.0
    allocated_costs::Float64 = 0.0
    total_costs::Float64 = 0.0
    charges::Float64 = 0.0
    cost_to_charge_ratio::Float64 = 0.0
    statistical_basis::Symbol = :square_footage  # allocation statistic
    statistical_value::Float64 = 0.0
end

"""
    AllocationBasis

Defines how overhead costs are allocated across cost centers using step-down
or reciprocal allocation methods.
"""
@kwdef struct AllocationBasis
    method::Symbol = :step_down  # :step_down, :reciprocal, :direct
    overhead_order::Vector{String} = String[]  # cost center codes in allocation order
    statistics::Dict{String, Dict{String, Float64}} = Dict{String, Dict{String, Float64}}()
end

"""
    CostReport

Medicare cost report data (Form CMS-2552) for a hospital.
"""
@kwdef mutable struct CostReport
    provider_number::String
    fiscal_year_begin::Date
    fiscal_year_end::Date
    report_status::Symbol = :filed  # :filed, :settled, :reopened, :final

    # Cost centers
    cost_centers::Vector{CostCenter} = CostCenter[]
    allocation_basis::AllocationBasis = AllocationBasis()

    # Aggregate cost report values
    total_costs::Float64 = 0.0
    total_charges::Float64 = 0.0
    overall_cost_to_charge_ratio::Float64 = 0.0

    # Medicare-specific
    medicare_inpatient_costs::Float64 = 0.0
    medicare_outpatient_costs::Float64 = 0.0
    medicare_swing_bed_costs::Float64 = 0.0
    medicare_allowable_costs::Float64 = 0.0
    medicare_payments_received::Float64 = 0.0
    medicare_settlement_amount::Float64 = 0.0

    # For CAH cost-based reimbursement
    reasonable_cost_percentage::Float64 = 1.01  # 101% for CAH
end

function Base.show(io::IO, cr::CostReport)
    print(io, "CostReport($(cr.provider_number), FY$(year(cr.fiscal_year_end)), status=:$(cr.report_status))")
end

"""
    CapitalAsset

An individual capital asset with depreciation tracking.
"""
@kwdef mutable struct CapitalAsset
    asset_id::String
    description::String
    category::Symbol  # :building, :equipment, :land, :it_system, :vehicle
    acquisition_date::Date
    acquisition_cost::Float64
    useful_life_years::Int
    salvage_value::Float64 = 0.0
    depreciation_method::Symbol = :straight_line  # :straight_line, :declining_balance
    accumulated_depreciation::Float64 = 0.0
    is_active::Bool = true
    funding_source::Symbol = :operating  # :operating, :bond, :grant, :usda_loan, :lease
end

"""
    current_book_value(asset::CapitalAsset) -> Float64

Compute the current book value of a capital asset.
"""
function current_book_value(asset::CapitalAsset)
    return asset.acquisition_cost - asset.accumulated_depreciation
end

"""
    annual_depreciation(asset::CapitalAsset) -> Float64

Compute the annual straight-line depreciation expense for a capital asset.
Falls back to straight-line for unsupported methods.
"""
function annual_depreciation(asset::CapitalAsset)
    if asset.depreciation_method == :straight_line
        return (asset.acquisition_cost - asset.salvage_value) / asset.useful_life_years
    elseif asset.depreciation_method == :declining_balance
        book = current_book_value(asset)
        rate = 2.0 / asset.useful_life_years
        return max(book * rate, 0.0)
    else
        # Default to straight-line
        return (asset.acquisition_cost - asset.salvage_value) / asset.useful_life_years
    end
end

"""
    CapitalProject

A planned or in-progress capital project.
"""
@kwdef mutable struct CapitalProject
    project_id::String
    name::String
    description::String = ""
    category::Symbol  # :facility, :equipment, :it, :renovation, :expansion
    estimated_cost::Float64
    approved_budget::Float64 = 0.0
    spent_to_date::Float64 = 0.0
    start_date::Union{Date, Nothing} = nothing
    expected_completion::Union{Date, Nothing} = nothing
    status::Symbol = :proposed  # :proposed, :approved, :in_progress, :completed, :deferred
    funding_sources::Dict{Symbol, Float64} = Dict{Symbol, Float64}()
    expected_useful_life_years::Int = 10
    priority_rank::Int = 0
end

"""
    CapitalPlan

Multi-year capital expenditure plan for a hospital.
"""
@kwdef mutable struct CapitalPlan
    plan_year_start::Int
    plan_year_end::Int
    existing_assets::Vector{CapitalAsset} = CapitalAsset[]
    planned_projects::Vector{CapitalProject} = CapitalProject[]
    annual_depreciation_budget::Float64 = 0.0
    annual_capex_budget::Float64 = 0.0
    deferred_maintenance_backlog::Float64 = 0.0
    average_age_of_plant_years::Float64 = 0.0
    target_age_of_plant_years::Float64 = 10.0
end

"""
    MedicareReimbursement

Tracks Medicare reimbursement calculation components for a given period.
"""
@kwdef mutable struct MedicareReimbursement
    provider_number::String
    payment_year::Int
    designation::Symbol  # :cah, :reh, :pps, :sch

    # CAH cost-based fields
    allowable_costs::Float64 = 0.0
    cost_reimbursement_pct::Float64 = 1.01  # 101% for CAH
    interim_payments::Float64 = 0.0
    settlement_amount::Float64 = 0.0

    # PPS fields
    base_rate::Float64 = 0.0
    wage_index::Float64 = 1.0
    case_mix_index::Float64 = 1.0
    drg_payments::Float64 = 0.0
    outlier_payments::Float64 = 0.0
    dsh_payments::Float64 = 0.0
    ime_payments::Float64 = 0.0

    # REH fields
    monthly_facility_payment::Float64 = 0.0
    outpatient_add_on_payments::Float64 = 0.0

    # Common
    total_medicare_payment::Float64 = 0.0
    total_medicare_costs::Float64 = 0.0
    payment_to_cost_ratio::Float64 = 0.0
end

function Base.show(io::IO, mr::MedicareReimbursement)
    print(io, "MedicareReimbursement($(mr.provider_number), $(mr.payment_year), :$(mr.designation))")
end
