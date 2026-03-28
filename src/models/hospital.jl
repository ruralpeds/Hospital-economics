# Hospital entity types for Rural Hospital Economics Simulator

using Dates
using UUIDs

"""
    GeoLocation

Geographic coordinates and Census designation for a hospital location.
"""
@kwdef struct GeoLocation
    latitude::Float64
    longitude::Float64
    fips_code::String
    state::String
    county::String
    zip_code::String
    census_tract::String = ""
    cbsa_code::String = ""
    ruca_code::Float64 = 10.0  # Rural-Urban Commuting Area code
    urban_rural::Symbol = :rural  # :urban, :rural, :frontier
end

"""
    ServiceArea

Defines the geographic service area and demographics for a hospital.
"""
@kwdef struct ServiceArea
    primary_service_area_pop::Int
    secondary_service_area_pop::Int = 0
    total_service_area_pop::Int
    pop_growth_rate::Float64 = 0.0
    median_age::Float64 = 40.0
    pct_over_65::Float64 = 0.18
    pct_under_18::Float64 = 0.22
    median_household_income::Float64 = 50000.0
    poverty_rate::Float64 = 0.15
    uninsured_rate::Float64 = 0.10
    medicaid_eligible_pct::Float64 = 0.20
    primary_care_physicians_per_100k::Float64 = 50.0
    hpsa_score::Int = 0  # Health Professional Shortage Area score (0-25)
    is_medically_underserved::Bool = false
    nearest_tertiary_center_miles::Float64 = 60.0
    competing_hospitals::Int = 0
end

"""
    CriticalAccessHospital <: AbstractRuralHospital

A Critical Access Hospital (CAH) certified under the Medicare Rural Hospital
Flexibility Program. CAHs are limited to 25 inpatient beds and receive
cost-based reimbursement from Medicare.
"""
@kwdef mutable struct CriticalAccessHospital <: AbstractRuralHospital
    id::UUID = uuid4()
    name::String
    cms_provider_number::String
    npi::String
    payment_designation::CostBasedPayment = CostBasedPayment()
    cah_certification_date::Date
    is_necessary_provider::Bool = false
    licensed_beds::Int
    swing_beds::Int = 0
    observation_beds::Int = 0
    average_daily_census::Float64 = 0.0
    average_length_of_stay::Float64 = 0.0
    location::GeoLocation
    service_area::ServiceArea
    nearest_hospital_miles::Float64
    departments::Vector{Department} = Department[]
    service_lines::Vector{ServiceLine} = ServiceLine[]
    staff::Union{StaffingModel, Nothing} = nothing
    payer_mix::Union{PayerMix, Nothing} = nothing
    cost_report::Union{CostReport, Nothing} = nothing
    capital_plan::Union{CapitalPlan, Nothing} = nothing
    historical_financials::Vector{AnnualFinancials} = AnnualFinancials[]
    system_affiliation::Union{HealthSystem, Nothing} = nothing
    is_government_owned::Bool = false
    tax_status::Symbol = :nonprofit  # :nonprofit, :government, :for_profit
    is_340b_eligible::Bool = false
    dsh_adjustment_pct::Float64 = 0.0
end

function Base.show(io::IO, h::CriticalAccessHospital)
    print(io, "CAH(\"$(h.name)\", beds=$(h.licensed_beds), adc=$(round(h.average_daily_census, digits=1)))")
end

# Enforce 25-bed limit for CAH
function validate_cah(h::CriticalAccessHospital)
    h.licensed_beds > 25 && error("CAH licensed beds cannot exceed 25; got $(h.licensed_beds)")
    h.average_length_of_stay > 96.0 && @warn "CAH average length of stay exceeds 96-hour guideline"
    return true
end

"""
    RuralEmergencyHospital <: AbstractRuralHospital

A Rural Emergency Hospital (REH) as established by the Consolidated Appropriations
Act of 2021. REHs provide emergency services without inpatient beds and receive
a monthly facility payment plus enhanced outpatient reimbursement.
"""
@kwdef mutable struct RuralEmergencyHospital <: AbstractRuralHospital
    id::UUID = uuid4()
    name::String
    cms_provider_number::String
    npi::String
    payment_designation::REHPayment = REHPayment()
    reh_conversion_date::Date
    former_designation::Symbol  # :cah, :pps_rural, :sch
    # REH has no inpatient beds
    observation_beds::Int = 0
    ed_treatment_stations::Int = 8
    monthly_facility_payment::Float64 = 295_000.00  # FY2026 base amount (CMS update)
    outpatient_add_on_pct::Float64 = 0.05  # 5% additional OPPS payment
    location::GeoLocation
    service_area::ServiceArea
    nearest_hospital_miles::Float64
    departments::Vector{Department} = Department[]
    service_lines::Vector{ServiceLine} = ServiceLine[]
    staff::Union{StaffingModel, Nothing} = nothing
    payer_mix::Union{PayerMix, Nothing} = nothing
    cost_report::Union{CostReport, Nothing} = nothing
    capital_plan::Union{CapitalPlan, Nothing} = nothing
    historical_financials::Vector{AnnualFinancials} = AnnualFinancials[]
    system_affiliation::Union{HealthSystem, Nothing} = nothing
    is_government_owned::Bool = false
    tax_status::Symbol = :nonprofit
    is_340b_eligible::Bool = false
    dsh_adjustment_pct::Float64 = 0.0
end

function Base.show(io::IO, h::RuralEmergencyHospital)
    print(io, "REH(\"$(h.name)\", ed_stations=$(h.ed_treatment_stations), former=$(h.former_designation))")
end

"""
    ProspectivePaymentHospital <: AbstractUrbanHospital

A hospital paid under the Inpatient Prospective Payment System (IPPS)
or Outpatient Prospective Payment System (OPPS).
"""
@kwdef mutable struct ProspectivePaymentHospital <: AbstractUrbanHospital
    id::UUID = uuid4()
    name::String
    cms_provider_number::String
    npi::String
    payment_designation::ProspectivePayment = ProspectivePayment()
    licensed_beds::Int
    staffed_beds::Int
    average_daily_census::Float64 = 0.0
    case_mix_index::Float64 = 1.0
    wage_index::Float64 = 1.0
    base_operating_drg_rate::Float64 = 0.0
    disproportionate_share_pct::Float64 = 0.0
    indirect_medical_education_pct::Float64 = 0.0
    location::GeoLocation
    service_area::ServiceArea
    nearest_hospital_miles::Float64 = 0.0
    departments::Vector{Department} = Department[]
    service_lines::Vector{ServiceLine} = ServiceLine[]
    staff::Union{StaffingModel, Nothing} = nothing
    payer_mix::Union{PayerMix, Nothing} = nothing
    cost_report::Union{CostReport, Nothing} = nothing
    capital_plan::Union{CapitalPlan, Nothing} = nothing
    historical_financials::Vector{AnnualFinancials} = AnnualFinancials[]
    system_affiliation::Union{HealthSystem, Nothing} = nothing
    is_government_owned::Bool = false
    tax_status::Symbol = :nonprofit
    is_340b_eligible::Bool = false
    dsh_adjustment_pct::Float64 = 0.0
    is_sole_community::Bool = false
    is_rural_referral_center::Bool = false
    is_teaching::Bool = false
    resident_count::Int = 0
end

function Base.show(io::IO, h::ProspectivePaymentHospital)
    print(io, "PPS(\"$(h.name)\", beds=$(h.licensed_beds), cmi=$(round(h.case_mix_index, digits=2)))")
end

"""
    HealthSystem

A health system that may own or be affiliated with multiple hospitals.
"""
@kwdef mutable struct HealthSystem
    id::UUID = uuid4()
    name::String
    system_type::Symbol = :integrated  # :integrated, :holding_company, :alliance
    headquarters_state::String = ""
    total_hospitals::Int = 0
    total_licensed_beds::Int = 0
    annual_net_revenue::Float64 = 0.0
    credit_rating::String = ""
    has_medical_school::Bool = false
    member_hospital_ids::Vector{UUID} = UUID[]
end

function Base.show(io::IO, s::HealthSystem)
    print(io, "HealthSystem(\"$(s.name)\", hospitals=$(s.total_hospitals))")
end
