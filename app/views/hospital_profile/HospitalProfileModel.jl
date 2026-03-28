"""
Stipple reactive model for Hospital Profile editing.
Captures all hospital parameters needed for financial modeling.
"""
using Stipple, StippleUI, Dates

@appname HospitalProfileApp

@app begin
    # ── Identification ───────────────────────────────────────────────────
    @in hospital_id::Int = 0
    @in hospital_name::String = ""
    @in hospital_state::String = ""
    @in hospital_county::String = ""
    @in hospital_zip::String = ""
    @in hospital_type::String = "CAH"
    @in provider_number::String = ""
    @in ruca_code::Int = 7
    @in is_sole_community::Bool = false

    # ── Bed & Facility ───────────────────────────────────────────────────
    @in licensed_beds::Int = 25
    @in staffed_beds::Int = 20
    @in icu_beds::Int = 0
    @in facility_sq_ft::Int = 45000
    @in year_built::Int = 1978
    @in last_renovation_year::Int = 2010

    # ── Financial Inputs ─────────────────────────────────────────────────
    @in total_revenue::Float64 = 18_500_000.0
    @in net_patient_revenue::Float64 = 17_200_000.0
    @in total_operating_expenses::Float64 = 19_200_000.0
    @in salary_wages::Float64 = 8_400_000.0
    @in benefits_expense::Float64 = 2_500_000.0
    @in supply_expense::Float64 = 2_800_000.0
    @in depreciation::Float64 = 1_200_000.0
    @in interest_expense::Float64 = 480_000.0
    @in other_operating_expense::Float64 = 3_820_000.0
    @in non_operating_income::Float64 = 320_000.0
    @in total_assets::Float64 = 24_000_000.0
    @in total_liabilities::Float64 = 11_500_000.0
    @in long_term_debt::Float64 = 8_200_000.0
    @in cash_and_investments::Float64 = 2_200_000.0
    @in property_plant_equipment::Float64 = 15_800_000.0
    @in accumulated_depreciation::Float64 = 9_600_000.0
    @in dsh_payments::Float64 = 0.0
    @in supplemental_payments::Float64 = 850_000.0
    @in grant_income::Float64 = 120_000.0

    # ── Volume Inputs ────────────────────────────────────────────────────
    @in inpatient_discharges::Int = 620
    @in inpatient_days::Int = 2356
    @in observation_hours::Int = 3800
    @in ed_visits::Int = 4200
    @in outpatient_visits::Int = 12800
    @in surgical_cases::Int = 280
    @in births::Int = 45
    @in case_mix_index::Float64 = 0.85
    @in avg_length_of_stay::Float64 = 3.8
    @in readmission_rate::Float64 = 0.12

    # ── Payer Mix (percentages) ──────────────────────────────────────────
    @in medicare_pct::Float64 = 62.0
    @in medicaid_pct::Float64 = 18.0
    @in commercial_pct::Float64 = 12.0
    @in self_pay_pct::Float64 = 8.0

    # ── Staffing ─────────────────────────────────────────────────────────
    @in total_fte::Float64 = 142.0
    @in nursing_fte::Float64 = 52.0
    @in physician_fte::Float64 = 12.0
    @in admin_fte::Float64 = 18.5
    @in support_fte::Float64 = 28.0
    @in contract_labor_pct::Float64 = 8.0
    @in avg_nurse_salary::Float64 = 62_000.0
    @in avg_physician_compensation::Float64 = 285_000.0

    # ── Community Demographics ───────────────────────────────────────────
    @in service_area_pop::Int = 18500
    @in pop_over_65_pct::Float64 = 22.5
    @in pop_uninsured_pct::Float64 = 9.8
    @in median_household_income::Float64 = 42_500.0
    @in nearest_hospital_miles::Float64 = 35.0
    @in county_poverty_rate::Float64 = 16.2

    # ── Services Offered ─────────────────────────────────────────────────
    @in has_emergency::Bool = true
    @in has_surgery::Bool = true
    @in has_obstetrics::Bool = true
    @in has_imaging::Bool = true
    @in has_lab::Bool = true
    @in has_pharmacy::Bool = true
    @in has_rehab::Bool = true
    @in has_telehealth::Bool = false
    @in has_home_health::Bool = false
    @in has_swing_beds::Bool = true
    @in has_snf::Bool = false
    @in has_rural_health_clinic::Bool = true

    # ── Form State ───────────────────────────────────────────────────────
    @in save_profile::Bool = false
    @in load_profile::Bool = false
    @in reset_profile::Bool = false
    @out save_status::String = ""
    @out validation_errors::Vector{String} = String[]
    @out is_dirty::Bool = false
    @out is_loading::Bool = false

    # ── Computed / Derived Outputs ────────────────────────────────────────
    @out computed_operating_margin::Float64 = 0.0
    @out computed_days_cash::Int = 0
    @out computed_fte_per_aob::Float64 = 0.0
    @out computed_avg_age_plant::Float64 = 0.0
    @out computed_labor_cost_pct::Float64 = 0.0

    @onchange total_revenue, total_operating_expenses begin
        if total_revenue > 0
            computed_operating_margin = (total_revenue - total_operating_expenses) / total_revenue
        end
    end

    @onchange cash_and_investments, total_operating_expenses begin
        if total_operating_expenses > 0
            daily_expenses = total_operating_expenses / 365.0
            computed_days_cash = round(Int, cash_and_investments / daily_expenses)
        end
    end

    @onchange total_fte, staffed_beds, avg_length_of_stay, inpatient_discharges begin
        aob = staffed_beds > 0 ? (inpatient_discharges * avg_length_of_stay) / (365.0 * staffed_beds) * staffed_beds : 0.0
        if aob > 0
            computed_fte_per_aob = total_fte / aob
        end
    end

    @onchange accumulated_depreciation, depreciation begin
        if depreciation > 0
            computed_avg_age_plant = accumulated_depreciation / depreciation
        end
    end

    @onchange salary_wages, benefits_expense, net_patient_revenue begin
        if net_patient_revenue > 0
            computed_labor_cost_pct = (salary_wages + benefits_expense) / net_patient_revenue
        end
    end

    @onchange save_profile begin
        if save_profile
            save_profile = false
            errors = String[]
            if isempty(hospital_name)
                push!(errors, "Hospital name is required")
            end
            if licensed_beds <= 0
                push!(errors, "Licensed beds must be greater than 0")
            end
            payer_total = medicare_pct + medicaid_pct + commercial_pct + self_pay_pct
            if abs(payer_total - 100.0) > 1.0
                push!(errors, "Payer mix must sum to 100% (currently $(round(payer_total, digits=1))%)")
            end
            validation_errors = errors
            if isempty(errors)
                save_status = "Profile saved successfully at $(Dates.format(now(), "HH:MM:SS"))"
                is_dirty = false
            else
                save_status = "Validation failed — please correct errors"
            end
        end
    end

    @onchange reset_profile begin
        if reset_profile
            reset_profile = false
            hospital_name = ""
            total_revenue = 0.0
            total_operating_expenses = 0.0
            is_dirty = false
            save_status = "Profile reset"
        end
    end
end

const hospital_profile_model = @init
