"""
A-11: Medicaid Supplemental Payment & Disproportionate Share (DSH) Analysis

Models supplemental payments including Disproportionate Share Hospital (DSH)
adjustments, Upper Payment Limits (UPL), and state-specific Medicaid payment
enhancements for hospitals serving vulnerable populations.
"""

struct HospitalCharacteristics
    hospital_name::String
    medicare_cases::Int
    medicaid_cases::Int
    uninsured_cases::Int
    low_income_pct::Float64  # % of patients below 200% FPL
    medicaid_bed_days::Float64
    total_bed_days::Float64
end

struct DSHCalculation
    hospital_name::String
    medicaid_caseload_pct::Float64
    low_income_population_pct::Float64
    dsh_index::Float64  # Combined disproportionality measure
    estimated_dsh_payment::Float64
    dsh_payment_floor::Float64
    dsh_payment_ceiling::Float64
end

struct SupplementalPaymentImpact
    hospital_name::String
    base_medicaid_payment::Float64
    dsh_adjustment::Float64
    upl_adjustment::Float64
    supplemental_programs::Dict{String, Float64}  # Program name => payment
    total_supplemental::Float64
    supplemental_as_pct_base::Float64
    total_medicaid_revenue::Float64
end

"""
    calculate_medicaid_caseload_percentage(hosp::HospitalCharacteristics) -> Float64

Calculate Medicaid caseload percentage for DSH qualification.
Formula: Medicaid cases / Total cases (Medicare + Medicaid + uninsured)
"""
function calculate_medicaid_caseload_percentage(hosp::HospitalCharacteristics)::Float64
    total_cases = hosp.medicare_cases + hosp.medicaid_cases + hosp.uninsured_cases
    if total_cases == 0
        return 0.0
    end
    (hosp.medicaid_cases / total_cases) * 100.0
end

"""
    calculate_low_income_percentage(hosp::HospitalCharacteristics) -> Float64

Calculate low-income utilization percentage.
Combines Medicaid percentage with low-income uninsured.
"""
function calculate_low_income_percentage(hosp::HospitalCharacteristics)::Float64
    total_cases = hosp.medicare_cases + hosp.medicaid_cases + hosp.uninsured_cases
    if total_cases == 0
        return 0.0
    end
    # Low-income utilization = (Medicaid + Low-income uninsured)
    low_income_uninsured = hosp.uninsured_cases * (hosp.low_income_pct / 100.0)
    ((hosp.medicaid_cases + low_income_uninsured) / total_cases) * 100.0
end

"""
    calculate_dsh_index(medicaid_pct::Float64, low_income_pct::Float64) -> Float64

Calculate composite DSH index (0-1) based on two disproportionality measures.
Higher index = greater disproportionality = higher DSH eligibility.

State thresholds typically: >15% Medicaid OR >25% low-income → eligible for DSH
"""
function calculate_dsh_index(medicaid_pct::Float64, low_income_pct::Float64)::Float64
    if medicaid_pct < 0 || low_income_pct < 0
        error("Percentages must be non-negative")
    end

    # Normalize to 0-1 scale: state thresholds typically 15-30%
    medicaid_normalized = min(medicaid_pct / 30.0, 1.0)  # 30% = fully qualified
    low_income_normalized = min(low_income_pct / 40.0, 1.0)  # 40% = fully qualified

    # Composite: weighted average (Medicaid 60%, Low-income 40%)
    (medicaid_normalized * 0.6) + (low_income_normalized * 0.4)
end

"""
    calculate_dsh_payment(hosp::HospitalCharacteristics; base_dsh_pool::Float64=50_000_000.0,
                         state_allotment::Float64=25_000_000.0) -> DSHCalculation

Calculate estimated Medicaid DSH payment for a hospital.

Args:
    - hosp: Hospital characteristics
    - base_dsh_pool: State annual DSH allocation pool
    - state_allotment: Hospital's proportional state DSH allotment

Returns DSHCalculation with estimated payment, floor, ceiling.
"""
function calculate_dsh_payment(hosp::HospitalCharacteristics;
                              base_dsh_pool::Float64=50_000_000.0,
                              state_allotment::Float64=25_000_000.0)::DSHCalculation
    medicaid_pct = calculate_medicaid_caseload_percentage(hosp)
    low_income_pct = calculate_low_income_percentage(hosp)
    dsh_idx = calculate_dsh_index(medicaid_pct, low_income_pct)

    # DSH payment = state allotment × DSH index
    # Typically capped at state law limits (1.5-2.5% of Medicaid payments)
    estimated_dsh = state_allotment * dsh_idx

    # Floor: minimum DSH for eligible hospitals (e.g., $500K)
    floor = dsh_idx > 0.3 ? 500_000.0 : 0.0

    # Ceiling: maximum DSH (e.g., 2.5% of base Medicaid)
    ceiling = base_dsh_pool * 0.025

    DSHCalculation(
        hosp.hospital_name,
        medicaid_pct,
        low_income_pct,
        dsh_idx,
        max(floor, min(ceiling, estimated_dsh)),
        floor,
        ceiling
    )
end

"""
    calculate_supplemental_impacts(hosp::HospitalCharacteristics, base_medicaid::Float64;
                                  include_dsh::Bool=true, include_upl::Bool=true,
                                  include_enhanced_rates::Bool=false,
                                  enhanced_rate_pct::Float64=0.05) -> SupplementalPaymentImpact

Comprehensive calculation of all supplemental Medicaid payments.

Includes DSH, UPL adjustment, and optional state-specific enhancements.
"""
function calculate_supplemental_impacts(hosp::HospitalCharacteristics, base_medicaid::Float64;
                                       include_dsh::Bool=true, include_upl::Bool=true,
                                       include_enhanced_rates::Bool=false,
                                       enhanced_rate_pct::Float64=0.05)::SupplementalPaymentImpact
    supplementals = Dict{String, Float64}()
    total_supp = 0.0

    # DSH adjustment
    dsh_adj = 0.0
    if include_dsh
        dsh_calc = calculate_dsh_payment(hosp)
        dsh_adj = dsh_calc.estimated_dsh_payment
        supplementals["DSH"] = dsh_adj
        total_supp += dsh_adj
    end

    # Upper Payment Limit (UPL) adjustment
    # Medicare reasonable cost-based payment serves as UPL for outpatient
    upl_adj = 0.0
    if include_upl
        medicaid_pct = calculate_medicaid_caseload_percentage(hosp)
        # UPL typically adds 2-3% for high Medicaid volume hospitals
        upl_pct = 0.02 + (medicaid_pct / 100.0 * 0.01)
        upl_adj = base_medicaid * upl_pct
        supplementals["UPL"] = upl_adj
        total_supp += upl_adj
    end

    # State-specific enhancements (e.g., directed payments)
    if include_enhanced_rates
        enhanced = base_medicaid * enhanced_rate_pct
        supplementals["Enhanced_Rates"] = enhanced
        total_supp += enhanced
    end

    supp_pct = base_medicaid > 0 ? (total_supp / base_medicaid) * 100.0 : 0.0

    SupplementalPaymentImpact(
        hosp.hospital_name,
        base_medicaid,
        dsh_adj,
        upl_adj,
        supplementals,
        total_supp,
        supp_pct,
        base_medicaid + total_supp
    )
end
