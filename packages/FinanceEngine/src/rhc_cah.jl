"""
    rhc_cah_model.jl — RHC & CAH reimbursement comparison model

Calculates annual revenues under RHC (visit-based RVU) vs CAH (diagnosis-based DRG) models.
Evaluates conversion ROI and break-even timeline for rural facility operators.
"""

using JSON3, Statistics, DataFrames

# ═══════════════════════════════════════════════════════════════════════════
# A-08: RHC & CAH Reimbursement Comparison
# ═══════════════════════════════════════════════════════════════════════════

@kwdef struct RHCReimbursement
    visit_type::String  # e.g., "initial_visit", "established_visit"
    cpt_code::String
    rvu::Float64
    conversion_factor::Float64
    payment::Float64
    mileage_adjustment::Float64  # % increase for >50 miles
end

@kwdef struct CAHReimbursement
    visit_type::String
    ar_drgcd::String  # AR DRG code (e.g., "MDC01")
    ar_payment::Float64
    non_ar_payment::Float64
    blended_rate::Float64
end

@kwdef struct ReimburseComparison
    hospital_name::String
    annual_visits::Dict{String, Int}
    annual_ar_volumes::Dict{String, Int}
    annual_non_ar_volumes::Dict{String, Int}
    cah_annual_revenue::Float64
    rhc_annual_revenue::Float64
    revenue_difference::Float64
    revenue_difference_pct::Float64
    conversion_cost::Float64
    conversion_roi_pct::Float64
    break_even_months::Float64
    recommendation::String
end

"""
    load_rhc_schedule(fixture_path::String) -> Dict{String, RHCReimbursement}

Load RHC RVU schedule from JSON fixture (CMS Physician Fee Schedule).
"""
function load_rhc_schedule(fixture_path::String)::Dict{String, RHCReimbursement}
    if !isfile(fixture_path)
        throw(ArgumentError("RHC schedule fixture not found: $fixture_path"))
    end

    json_str = read(fixture_path, String)
    data = JSON3.read(json_str)

    schedule = Dict{String, RHCReimbursement}()
    if haskey(data, "schedule")
        for entry in data["schedule"]
            visit_type = String(entry["visit_type"])
            schedule[visit_type] = RHCReimbursement(
                visit_type = visit_type,
                cpt_code = String(entry["cpt_code"]),
                rvu = Float64(entry["rvu"]),
                conversion_factor = Float64(entry["conversion_factor"]),
                payment = Float64(entry["payment"]),
                mileage_adjustment = Float64(get(entry, "mileage_adjustment", 0.10))
            )
        end
    end

    return schedule
end

"""
    load_cah_schedule(fixture_path::String) -> Dict{String, CAHReimbursement}

Load CAH AR DRG rates from JSON fixture (42 CFR 413.24).
"""
function load_cah_schedule(fixture_path::String)::Dict{String, CAHReimbursement}
    if !isfile(fixture_path)
        throw(ArgumentError("CAH schedule fixture not found: $fixture_path"))
    end

    json_str = read(fixture_path, String)
    data = JSON3.read(json_str)

    schedule = Dict{String, CAHReimbursement}()
    if haskey(data, "schedule")
        for entry in data["schedule"]
            ar_drgcd = String(entry["ar_drgcd"])
            schedule[ar_drgcd] = CAHReimbursement(
                visit_type = String(get(entry, "visit_type", "Unknown")),
                ar_drgcd = ar_drgcd,
                ar_payment = Float64(entry["ar_payment"]),
                non_ar_payment = Float64(entry["non_ar_payment"]),
                blended_rate = Float64(get(entry, "blended_rate", 0.5))
            )
        end
    end

    return schedule
end

"""
    project_rhc_revenue(visits::Dict{String, Int}, rhc_schedule::Dict,
                       mileage_miles::Float64=0.0) -> Float64

Project annual RHC revenue from visit volumes and RVU schedule.

Applies mileage adjustment if hospital is >50 miles from nearest hospital.
"""
function project_rhc_revenue(visits::Dict{String, Int}, rhc_schedule::Dict,
                            mileage_miles::Float64=0.0)::Float64

    total_revenue = 0.0
    for (visit_type, count) in visits
        if haskey(rhc_schedule, visit_type)
            rhc = rhc_schedule[visit_type]
            payment = rhc.payment

            # Apply mileage adjustment
            if mileage_miles > 50.0
                payment *= (1.0 + rhc.mileage_adjustment)
            end

            total_revenue += payment * count
        end
    end

    return total_revenue
end

"""
    project_cah_revenue(ar_volumes::Dict{String, Int}, non_ar_volumes::Dict{String, Int},
                       cah_schedule::Dict) -> Float64

Project annual CAH revenue from AR DRG volumes and non-AR visits.

CAH uses blended rates: AR (diagnosis-based) + non-AR (visit-based).
"""
function project_cah_revenue(ar_volumes::Dict{String, Int}, non_ar_volumes::Dict{String, Int},
                            cah_schedule::Dict)::Float64

    ar_revenue = 0.0
    for (drg_code, count) in ar_volumes
        if haskey(cah_schedule, drg_code)
            ar_revenue += cah_schedule[drg_code].ar_payment * count
        end
    end

    non_ar_revenue = 0.0
    for (visit_type, count) in non_ar_volumes
        # Find matching non-AR rate
        for entry in values(cah_schedule)
            if entry.visit_type == visit_type
                non_ar_revenue += entry.non_ar_payment * count
                break
            end
        end
    end

    return ar_revenue + non_ar_revenue
end

"""
    compare_reimbursement(annual_visits::Dict{String, Int},
                         ar_volumes::Dict{String, Int},
                         non_ar_volumes::Dict{String, Int},
                         rhc_schedule::Dict,
                         cah_schedule::Dict;
                         mileage_miles::Float64=0.0,
                         conversion_cost_estimate::Float64=50_000.0,
                         hospital_name::String="Rural Hospital") -> ReimburseComparison

Compare annual revenue and ROI of RHC vs CAH models.

Calculates break-even timeline for conversion investment.
"""
function compare_reimbursement(annual_visits::Dict{String, Int},
                              ar_volumes::Dict{String, Int},
                              non_ar_volumes::Dict{String, Int},
                              rhc_schedule::Dict,
                              cah_schedule::Dict;
                              mileage_miles::Float64=0.0,
                              conversion_cost_estimate::Float64=50_000.0,
                              hospital_name::String="Rural Hospital")::ReimburseComparison

    # Calculate revenues
    rhc_revenue = project_rhc_revenue(annual_visits, rhc_schedule, mileage_miles)
    cah_revenue = project_cah_revenue(ar_volumes, non_ar_volumes, cah_schedule)

    # Difference and percentage
    revenue_difference = cah_revenue - rhc_revenue
    revenue_difference_pct = rhc_revenue > 0 ? (revenue_difference / rhc_revenue) * 100.0 : 0.0

    # ROI and break-even
    annual_incremental = revenue_difference
    conversion_roi_pct = conversion_cost_estimate > 0 ? (annual_incremental / conversion_cost_estimate) * 100.0 : 0.0
    break_even_months = annual_incremental > 0 ? (conversion_cost_estimate / annual_incremental) * 12.0 : 999.0

    # Recommendation
    recommendation = if revenue_difference_pct > 10.0
        "Strong case for CAH conversion: #{revenue_difference_pct |> round(Int)}% revenue increase"
    elseif revenue_difference_pct > 0.0
        "Consider CAH conversion: #{revenue_difference_pct |> round(1)}% revenue increase"
    else
        "RHC model is better; avoid conversion"
    end

    return ReimburseComparison(
        hospital_name = hospital_name,
        annual_visits = annual_visits,
        annual_ar_volumes = ar_volumes,
        annual_non_ar_volumes = non_ar_volumes,
        cah_annual_revenue = cah_revenue,
        rhc_annual_revenue = rhc_revenue,
        revenue_difference = revenue_difference,
        revenue_difference_pct = revenue_difference_pct,
        conversion_cost = conversion_cost_estimate,
        conversion_roi_pct = conversion_roi_pct,
        break_even_months = break_even_months,
        recommendation = recommendation
    )
end
