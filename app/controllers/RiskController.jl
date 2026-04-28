"""
RiskController — API handlers for risk assessment endpoints.

Routes:
  POST /api/risk/closure
  POST /api/conversion
"""
module RiskController

using JSON3, Dates, UUIDs
using ...RuralHospitalSim

"""Parse a numeric value from payload with bounds checking."""
function _validated_float(payload::Dict, key::String, default::Float64;
                          min_val::Float64=-Inf, max_val::Float64=Inf)
    val = Float64(get(payload, key, default))
    (isnan(val) || isinf(val)) && error("Parameter '$key' must be a finite number")
    val < min_val && error("Parameter '$key' must be >= $min_val")
    val > max_val && error("Parameter '$key' must be <= $max_val")
    return val
end

function _validated_int(payload::Dict, key::String, default::Int;
                        min_val::Int=typemin(Int), max_val::Int=typemax(Int))
    val = Int(get(payload, key, default))
    val < min_val && error("Parameter '$key' must be >= $min_val")
    val > max_val && error("Parameter '$key' must be <= $max_val")
    return val
end

# ═══════════════════════════════════════════════════════════════════════════
# Closure Risk Assessment
# ═══════════════════════════════════════════════════════════════════════════

"""
    handle_closure_risk(payload::Dict) -> Dict

Assess closure risk for a hospital from JSON payload.

Expected payload:
  - hospital_type: "cah" | "reh" | "pps"
  - financial_data: dict of financial indicators
  - operational_data: dict of operational indicators
  - market_data: dict of market/demographic data
"""
function handle_closure_risk(payload::Dict)
    hospital_type = Symbol(get(payload, "hospital_type", "cah"))

    # Build a minimal hospital for the assessment
    fin = get(payload, "financial_data", Dict())
    ops = get(payload, "operational_data", Dict())
    mkt = get(payload, "market_data", Dict())

    # Build MarketData (fields match src/risk/closure.jl struct)
    market = MarketData(;
        medicaid_expansion      = Bool(get(mkt, "medicaid_expansion", true)),
        ma_penetration          = Float64(get(mkt, "ma_penetration", 0.35)),
        population_trend_5yr    = Float64(get(mkt, "population_trend_5yr", -0.005)),
        nearest_competitor_miles = Float64(get(mkt, "nearest_competitor_miles", 30.0)),
        poverty_rate            = Float64(get(mkt, "poverty_rate", 0.15)),
        uninsured_rate          = Float64(get(mkt, "uninsured_rate", 0.12)),
    )

    # Build minimal CAH for assessment
    location = GeoLocation(;
        latitude     = Float64(get(mkt, "latitude", 35.0)),
        longitude    = Float64(get(mkt, "longitude", -90.0)),
        fips_code    = get(mkt, "fips_code", "00000"),
        state        = get(mkt, "state", "XX"),
        county       = get(mkt, "county", "Unknown"),
        zip_code     = get(mkt, "zip_code", "00000"),
    )

    service_area = ServiceArea(;
        primary_service_area_pop = Int(get(mkt, "service_area_pop", 15000)),
        total_service_area_pop   = Int(get(mkt, "total_service_area_pop", 25000)),
    )

    # Build AnnualFinancials for the hospital
    financials = AnnualFinancials(;
        fiscal_year              = Int(get(fin, "fiscal_year", 2025)),
        total_operating_revenue  = Float64(get(fin, "total_revenue", 20_000_000.0)),
        inpatient_revenue        = Float64(get(fin, "inpatient_revenue", 8_000_000.0)),
        outpatient_revenue       = Float64(get(fin, "outpatient_revenue", 12_000_000.0)),
        total_operating_expenses = Float64(get(fin, "total_expenses", 21_000_000.0)),
        salaries_wages           = Float64(get(fin, "salary_expense", 10_000_000.0)),
        employee_benefits        = Float64(get(fin, "benefits_expense", 2_500_000.0)),
        supplies                 = Float64(get(fin, "supply_expense", 2_000_000.0)),
        pharmaceuticals          = Float64(get(fin, "pharma_expense", 1_000_000.0)),
        depreciation             = Float64(get(fin, "depreciation", 1_200_000.0)),
        interest_expense         = Float64(get(fin, "interest_expense", 400_000.0)),
        cash_and_equivalents     = Float64(get(fin, "cash", 3_000_000.0)),
        current_assets           = Float64(get(fin, "current_assets", 5_000_000.0)),
        current_liabilities      = Float64(get(fin, "current_liabilities", 3_000_000.0)),
        total_assets             = Float64(get(fin, "total_assets", 25_000_000.0)),
        long_term_debt           = Float64(get(fin, "long_term_debt", 8_000_000.0)),
        net_plant_property       = Float64(get(fin, "net_plant", 15_000_000.0)),
        accumulated_depreciation = Float64(get(fin, "accumulated_depreciation", 12_000_000.0)),
        medicare_days_pct        = Float64(get(fin, "medicare_pct", 0.55)),
        medicaid_days_pct        = Float64(get(fin, "medicaid_pct", 0.18)),
    )

    hospital = CriticalAccessHospital(;
        name                    = get(payload, "hospital_name", "Assessment Hospital"),
        cms_provider_number     = get(payload, "cms_id", "000000"),
        npi                     = get(payload, "npi", "0000000000"),
        cah_certification_date  = Date(2010, 1, 1),
        licensed_beds           = Int(get(ops, "licensed_beds", 25)),
        average_daily_census    = Float64(get(ops, "average_daily_census", 5.0)),
        average_length_of_stay  = Float64(get(ops, "average_length_of_stay", 3.2)),
        location                = location,
        service_area            = service_area,
        nearest_hospital_miles  = Float64(get(mkt, "nearest_competitor_miles", 30.0)),
        historical_financials   = [financials],
    )

    financial_data = Dict{String,Float64}()
    for (k, v) in fin
        if v isa Number
            financial_data[string(k)] = Float64(v)
        end
    end

    operational_data = Dict{String,Float64}()
    for (k, v) in ops
        if v isa Number
            operational_data[string(k)] = Float64(v)
        end
    end

    assessment = assess_closure_risk(hospital, market;
        financial_data=financial_data, operational_data=operational_data)

    Dict(
        "status"               => "success",
        "type"                 => "closure_risk",
        "run_id"               => string(uuid4()),
        "timestamp"            => string(now()),
        "risk_score"           => round(assessment.risk_score, digits=1),
        "risk_tier"            => string(assessment.risk_tier),
        "financial_risk"       => round(assessment.financial_risk_score, digits=1),
        "operational_risk"     => round(assessment.operational_risk_score, digits=1),
        "market_risk"          => round(assessment.market_risk_score, digits=1),
        "workforce_risk"       => round(assessment.workforce_risk_score, digits=1),
        "policy_risk"          => round(assessment.policy_risk_score, digits=1),
        "top_risk_drivers"     => assessment.top_risk_drivers,
        "mitigation_factors"   => assessment.mitigation_factors,
        "years_to_distress"    => assessment.estimated_years_to_distress,
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# REH Conversion Analysis
# ═══════════════════════════════════════════════════════════════════════════

"""
    handle_reh_conversion(payload::Dict) -> Dict

Analyze CAH-to-REH conversion from JSON payload.

Expected payload:
  - base_revenue, base_costs: current hospital financials
  - conversion_params: severance, facility_mods, volume_assumptions
  - nearest_inpatient_miles: distance to nearest inpatient facility
"""
function handle_reh_conversion(payload::Dict)
    cp = get(payload, "conversion_params", Dict())

    params = ConversionParams(;
        severance_cost            = Float64(get(cp, "severance_cost", 500_000.0)),
        facility_modification_cost = Float64(get(cp, "facility_modification_cost", 1_000_000.0)),
        ip_volume_loss_pct        = _validated_float(cp, "ip_volume_loss_pct", 1.0; min_val=0.0, max_val=1.0),
        op_volume_retention_pct   = _validated_float(cp, "op_volume_retention_pct", 0.85; min_val=0.0, max_val=1.0),
        ed_volume_change_pct      = _validated_float(cp, "ed_volume_change_pct", 0.05; min_val=-0.50, max_val=1.0),
        transition_months         = _validated_int(cp, "transition_months", 12; min_val=1, max_val=60),
    )

    location = GeoLocation(;
        latitude=35.0, longitude=-90.0, fips_code="00000",
        state="XX", county="Unknown", zip_code="00000",
    )
    service_area = ServiceArea(;
        primary_service_area_pop=15000, total_service_area_pop=25000,
    )

    hospital = CriticalAccessHospital(;
        name                   = get(payload, "hospital_name", "Conversion Hospital"),
        cms_provider_number    = "000000",
        npi                    = "0000000000",
        cah_certification_date = Date(2010, 1, 1),
        licensed_beds          = Int(get(payload, "licensed_beds", 25)),
        location               = location,
        service_area           = service_area,
        nearest_hospital_miles = Float64(get(payload, "nearest_inpatient_miles", 30.0)),
    )

    analysis = analyze_reh_conversion(hospital, params;
        base_revenue           = Float64(get(payload, "base_revenue", 20_000_000.0)),
        base_costs             = Float64(get(payload, "base_costs", 21_000_000.0)),
        nearest_inpatient_miles = Float64(get(payload, "nearest_inpatient_miles", 30.0)),
    )

    Dict(
        "status"                     => "success",
        "type"                       => "reh_conversion",
        "run_id"                     => string(uuid4()),
        "timestamp"                  => string(now()),
        "pre_conversion_margin"      => round(analysis.pre_conversion_margin, digits=4),
        "post_conversion_margin"     => round(analysis.post_conversion_margin, digits=4),
        "margin_improvement"         => round(analysis.margin_improvement, digits=4),
        "annual_facility_payment"    => round(analysis.annual_facility_payment, digits=2),
        "net_revenue_change"         => round(analysis.net_revenue_change, digits=2),
        "net_cost_change"            => round(analysis.net_cost_change, digits=2),
        "one_time_conversion_cost"   => round(analysis.one_time_conversion_cost, digits=2),
        "payback_months"             => analysis.payback_months,
        "recommendation"             => analysis.recommendation,
    )
end

# ═══════════════════════════════════════════════════════════════════════════
# A-06: Medicare Advantage Risk Adjustment (HCC v28)
# ═══════════════════════════════════════════════════════════════════════════

"""
    handle_ma_risk(payload::Dict) -> Dict

API handler for MA RAF calculation and cohort analysis.

Expected payload:
  - members: Vector of member dicts with member_id, age, sex, diagnoses
  - annual_capitation: Float64 (default 10,000)

Returns member-level RAFs and cohort statistics.
"""
function handle_ma_risk(payload::Dict)::Dict
    try
        members_data = get(payload, "members", [])
        annual_capitation = Float64(get(payload, "annual_capitation", 10_000.0))

        if isempty(members_data)
            return Dict(
                "status" => "error",
                "message" => "No member data provided"
            )
        end

        # Load HCC coefficients
        fixture_path = joinpath(@__DIR__, "..", "..", "test", "fixtures", "cms", "hcc_v28_coefficients.json")
        hcc_coefficients = parse_hcc_coefficients(fixture_path)

        # Calculate member-level RAFs
        member_rafs = []
        for member in members_data
            member_id = String(get(member, "member_id", "UNKNOWN"))
            age = Int(get(member, "age", 65))
            sex = String(get(member, "sex", "M"))
            diagnoses = String.(get(member, "diagnoses", []))

            # Calculate RAF
            raf_score = calculate_member_raf(
                member_id, age, sex, diagnoses;
                hcc_coefficients = hcc_coefficients
            )

            push!(member_rafs, Dict(
                "member_id" => raf_score.member_id,
                "age" => raf_score.age,
                "sex" => raf_score.sex,
                "hcc_count" => raf_score.hcc_count,
                "diagnoses" => raf_score.diagnoses,
                "combined_raf" => raf_score.combined_raf,
                "risk_band" => raf_score.risk_band
            ))
        end

        # Aggregate cohort statistics
        raf_objects = [
            calculate_member_raf(
                String(m["member_id"]), Int(m["age"]), String(m["sex"]),
                String.(get(m, "diagnoses", []));
                hcc_coefficients = hcc_coefficients
            )
            for m in members_data
        ]
        cohort_agg = aggregate_cohort_raf(raf_objects; annual_capitation = annual_capitation)

        return Dict(
            "status" => "ok",
            "member_rafs" => member_rafs,
            "cohort_stats" => Dict(
                "member_count" => length(member_rafs),
                "mean_raf" => cohort_agg["mean_raf"],
                "std_raf" => cohort_agg["std_raf"],
                "percentiles" => get(cohort_agg, "percentiles", Dict()),
                "risk_band_distribution" => get(cohort_agg, "risk_band_distribution", Dict()),
                "capitation_impact" => get(cohort_agg, "capitation_impact", Dict())
            )
        )
    catch e
        return Dict(
            "status" => "error",
            "message" => sprint(showerror, e)
        )
    end
end

end # module RiskController
