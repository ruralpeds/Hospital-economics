# ============================================================================
# CLINICAL PATHWAY DEFINITIONS
# ============================================================================
# Evidence-based clinical pathways for common rural hospital diagnoses
# with outcome expectations and cost profiles

"""
    ClinicalPathway

Represents an evidence-based clinical pathway for a specific diagnosis (DRG).
Includes expected length of stay, outcomes, costs, and clinical milestones.

# Fields
- pathway_id::String: Unique identifier (e.g., "DRG_246_Acute_MI")
- primary_diagnosis::String: ICD-10 code
- drg_code::String: Medicare DRG code
- expected_los::Int: Expected length of stay (days)
- typical_procedures::Vector{String}: Common CPT codes
- cost_model::String: Costing approach (DRG/RVU/ActivityBased)

# Quality & Outcomes Expectations (0-1 scale)
- expected_mortality_rate::Float64: In-hospital mortality rate
- expected_readmission_30day::Float64: 30-day readmission probability
- expected_complication_rate::Float64: Major complications rate
- expected_quality_score::Float64: Patient satisfaction/quality proxy (0-1)

# Cost Expectations (USD)
- expected_cost::Float64: Mean episode cost
- cost_std::Float64: Standard deviation of episode cost

# Clinical Timing
- typical_ed_stay_hours::Int: Expected ED stay hours
- typical_icu_stay_days::Int: Expected ICU stay (0 if no ICU admission)
- typical_or_minutes::Int: Expected OR time (0 if no surgery)
- typical_readmission_window_days::Int: Days until typical readmission

# Metadata
- treatment_complexity::String: Low/Medium/High
- specialty::String: Cardiology/Orthopedics/Surgery/Internal Medicine/etc.
- metadata::Dict{String, Any}: Additional clinical/financial data
"""
struct ClinicalPathway
    pathway_id::String
    primary_diagnosis::String
    drg_code::String
    expected_los::Int
    typical_procedures::Vector{String}
    cost_model::String

    expected_mortality_rate::Float64
    expected_readmission_30day::Float64
    expected_complication_rate::Float64
    expected_quality_score::Float64

    expected_cost::Float64
    cost_std::Float64

    typical_ed_stay_hours::Int
    typical_icu_stay_days::Int
    typical_or_minutes::Int
    typical_readmission_window_days::Int

    treatment_complexity::String
    specialty::String
    metadata::Dict{String, Any}
end

# ============================================================================
# CLINICAL PATHWAY REPOSITORY
# ============================================================================
# Evidence-based pathways for 20+ common rural hospital diagnoses

"""
    get_clinical_pathways()::Dict{String, ClinicalPathway}

Return repository of evidence-based clinical pathways for common rural hospital diagnoses.
Maps DRG codes to ClinicalPathway definitions with published outcome expectations.

# Data Sources
- Medicare Average Wholesale Price (AWP) data
- CMS Hospital Quality Reporting data (mortality, readmission rates)
- AHRQ HCUPnet data (LOS, procedures)
- Published health economics literature

# Returns
Dict mapping DRG code to ClinicalPathway
"""
function get_clinical_pathways()::Dict{String, ClinicalPathway}
    pathways = Dict{String, ClinicalPathway}()

    # ────────────────────────────────────────────────────────────────────
    # CARDIOVASCULAR PATHWAYS
    # ────────────────────────────────────────────────────────────────────

    pathways["246"] = ClinicalPathway(
        "DRG_246_Acute_MI",                          # pathway_id
        "I21",                                        # ICD-10: Acute MI
        "246",                                        # DRG code
        3,                                            # expected_los (days)
        ["92004", "93000", "93005"],                  # CPT: EKG, troponin, stress test
        "DRG",                                        # cost_model
        0.02,                                         # mortality rate: 2%
        0.12,                                         # 30-day readmission: 12%
        0.08,                                         # complication rate: 8%
        0.82,                                         # quality score: 0.82
        18500.0,                                      # expected cost
        4200.0,                                       # cost_std
        2,                                            # ED stay hours
        2,                                            # ICU stay days (typical)
        0,                                            # OR minutes
        15,                                           # readmission window
        "High",                                       # complexity
        "Cardiology",                                 # specialty
        Dict("risk_factors" => ["age>65", "prior_MI", "diabetes"])
    )

    pathways["241"] = ClinicalPathway(
        "DRG_241_Septicemia",
        "A41",
        "241",
        6,
        ["80053", "85025", "87040"],                  # Blood cultures, CBC, cultures
        "DRG",
        0.08,                                         # mortality: 8%
        0.18,                                         # readmission: 18%
        0.15,                                         # complications: 15%
        0.75,
        16800.0,
        5100.0,
        3,
        3,
        0,
        10,
        "High",
        "Internal Medicine",
        Dict("risk_factors" => ["age>70", "immunocompromised", "prior_sepsis"])
    )

    pathways["291"] = ClinicalPathway(
        "DRG_291_CHF",
        "I50",
        "291",
        4,
        ["93000", "71020", "76700"],                  # EKG, CXR, ECHO
        "DRG",
        0.03,                                         # mortality: 3%
        0.22,                                         # readmission: 22% (chronic condition)
        0.10,                                         # complications: 10%
        0.78,
        12500.0,
        3200.0,
        2,
        1,
        0,
        14,
        "Medium",
        "Cardiology",
        Dict("risk_factors" => ["age>75", "diabetes", "renal_disease"])
    )

    pathways["296"] = ClinicalPathway(
        "DRG_296_Chest_Pain",
        "R07",
        "296",
        2,
        ["93000", "85025", "71020"],
        "DRG",
        0.002,                                        # mortality: 0.2%
        0.03,                                         # readmission: 3%
        0.02,                                         # complications: 2%
        0.88,
        6200.0,
        1800.0,
        2,
        0,
        0,
        30,
        "Low",
        "Emergency Medicine",
        Dict("risk_factors" => ["smoking", "family_history"])
    )

    # ────────────────────────────────────────────────────────────────────
    # RESPIRATORY PATHWAYS
    # ────────────────────────────────────────────────────────────────────

    pathways["177"] = ClinicalPathway(
        "DRG_177_Pneumonia",
        "J18",
        "177",
        5,
        ["71020", "85025", "87040"],                  # CXR, CBC, cultures
        "DRG",
        0.04,                                         # mortality: 4%
        0.16,                                         # readmission: 16%
        0.08,                                         # complications: 8%
        0.79,
        8900.0,
        2400.0,
        2,
        1,
        0,
        7,
        "Medium",
        "Internal Medicine",
        Dict("risk_factors" => ["age>65", "COPD", "smoking"])
    )

    pathways["202"] = ClinicalPathway(
        "DRG_202_COPD",
        "J44",
        "202",
        4,
        ["71020", "94060", "85025"],                  # CXR, spirometry, CBC
        "DRG",
        0.03,                                         # mortality: 3%
        0.18,                                         # readmission: 18%
        0.10,                                         # complications: 10%
        0.76,
        7500.0,
        2000.0,
        2,
        0,
        0,
        10,
        "Medium",
        "Internal Medicine",
        Dict("risk_factors" => ["age>60", "smoking_history"])
    )

    # ────────────────────────────────────────────────────────────────────
    # ORTHOPEDIC PATHWAYS
    # ────────────────────────────────────────────────────────────────────

    pathways["470"] = ClinicalPathway(
        "DRG_470_Hip_Replacement",
        "M16",
        "470",
        2,
        ["27130", "99213"],                           # Hip arthroplasty
        "DRG",
        0.001,                                        # mortality: 0.1%
        0.06,                                         # readmission: 6%
        0.04,                                         # complications: 4%
        0.89,
        24500.0,
        4800.0,
        1,
        0,
        120,                                          # Major surgery
        45,
        "Medium",
        "Orthopedic Surgery",
        Dict("risk_factors" => ["age>70", "obesity", "diabetes"])
    )

    pathways["469"] = ClinicalPathway(
        "DRG_469_Knee_Replacement",
        "M17",
        "469",
        2,
        ["27447", "99213"],                           # Knee arthroplasty
        "DRG",
        0.001,                                        # mortality: 0.1%
        0.05,                                         # readmission: 5%
        0.03,                                         # complications: 3%
        0.90,
        21800.0,
        4200.0,
        1,
        0,
        100,                                          # Major surgery
        50,
        "Medium",
        "Orthopedic Surgery",
        Dict("risk_factors" => ["age>65", "obesity"])
    )

    pathways["482"] = ClinicalPathway(
        "DRG_482_Fracture_Femur",
        "S72",
        "482",
        5,
        ["27236", "27245"],                           # Femur repair
        "DRG",
        0.06,                                         # mortality: 6% (elderly)
        0.14,                                         # readmission: 14%
        0.12,                                         # complications: 12%
        0.73,
        16200.0,
        3900.0,
        3,
        1,
        90,
        30,
        "High",
        "Orthopedic Surgery",
        Dict("risk_factors" => ["age>75", "osteoporosis", "fall"])
    )

    # ────────────────────────────────────────────────────────────────────
    # GASTROINTESTINAL PATHWAYS
    # ────────────────────────────────────────────────────────────────────

    pathways["373"] = ClinicalPathway(
        "DRG_373_Appendectomy",
        "K35",
        "373",
        2,
        ["44950"],                                    # Appendectomy
        "DRG",
        0.002,                                        # mortality: 0.2%
        0.04,                                         # readmission: 4%
        0.05,                                         # complications: 5%
        0.87,
        9800.0,
        2200.0,
        1,
        0,
        60,
        30,
        "Low",
        "General Surgery",
        Dict("risk_factors" => ["age>65", "perforation"])
    )

    pathways["384"] = ClinicalPathway(
        "DRG_384_Cholelithiasis",
        "K80",
        "384",
        2,
        ["47562"],                                    # Cholecystectomy
        "DRG",
        0.003,                                        # mortality: 0.3%
        0.05,                                         # readmission: 5%
        0.08,                                         # complications: 8%
        0.85,
        11200.0,
        2600.0,
        1,
        0,
        75,
        21,
        "Low",
        "General Surgery",
        Dict("risk_factors" => ["age>70", "obesity"])
    )

    pathways["391"] = ClinicalPathway(
        "DRG_391_Esophagitis",
        "K20",
        "391",
        3,
        ["43235"],                                    # EGD
        "DRG",
        0.01,                                         # mortality: 1%
        0.08,                                         # readmission: 8%
        0.06,                                         # complications: 6%
        0.80,
        6800.0,
        1600.0,
        2,
        0,
        45,
        10,
        "Low",
        "Gastroenterology",
        Dict("risk_factors" => ["GERD", "Barrett's"])
    )

    # ────────────────────────────────────────────────────────────────────
    # METABOLIC & ENDOCRINE PATHWAYS
    # ────────────────────────────────────────────────────────────────────

    pathways["640"] = ClinicalPathway(
        "DRG_640_Diabetes_DKA",
        "E11.65",
        "640",
        4,
        ["82947", "82948"],                           # BMP, glucose
        "DRG",
        0.01,                                         # mortality: 1%
        0.10,                                         # readmission: 10%
        0.08,                                         # complications: 8%
        0.78,
        5200.0,
        1400.0,
        2,
        1,
        0,
        14,
        "Medium",
        "Internal Medicine",
        Dict("risk_factors" => ["poor_control", "age<30"])
    )

    # ────────────────────────────────────────────────────────────────────
    # GENITOURINARY PATHWAYS
    # ────────────────────────────────────────────────────────────────────

    pathways["690"] = ClinicalPathway(
        "DRG_690_UTI",
        "N39.0",
        "690",
        3,
        ["81000", "87040"],                           # Urinalysis, culture
        "DRG",
        0.01,                                         # mortality: 1%
        0.08,                                         # readmission: 8%
        0.04,                                         # complications: 4%
        0.82,
        3200.0,
        900.0,
        1,
        0,
        0,
        5,
        "Low",
        "Urology",
        Dict("risk_factors" => ["age>65", "catheter"])
    )

    pathways["714"] = ClinicalPathway(
        "DRG_714_Acute_Kidney_Injury",
        "N17",
        "714",
        5,
        ["84025", "82310"],                           # Creatinine, potassium
        "DRG",
        0.05,                                         # mortality: 5%
        0.12,                                         # readmission: 12%
        0.10,                                         # complications: 10%
        0.72,
        8600.0,
        2300.0,
        2,
        2,
        0,
        7,
        "High",
        "Nephrology",
        Dict("risk_factors" => ["age>70", "diabetes", "CKD"])
    )

    # ────────────────────────────────────────────────────────────────────
    # NEUROLOGICAL PATHWAYS
    # ────────────────────────────────────────────────────────────────────

    pathways["65"] = ClinicalPathway(
        "DRG_65_Stroke",
        "I63",
        "65",
        5,
        ["70450", "93000"],                           # CT/MRI, EKG
        "DRG",
        0.10,                                         # mortality: 10%
        0.20,                                         # readmission: 20%
        0.15,                                         # complications: 15%
        0.68,
        19800.0,
        5200.0,
        3,
        3,
        0,
        30,
        "High",
        "Neurology",
        Dict("risk_factors" => ["age>70", "AFib", "hypertension"])
    )

    pathways["74"] = ClinicalPathway(
        "DRG_74_Intracranial_Hemorrhage",
        "I61",
        "74",
        7,
        ["70450", "70553"],                           # CT, MRI
        "DRG",
        0.18,                                         # mortality: 18%
        0.22,                                         # readmission: 22%
        0.20,                                         # complications: 20%
        0.62,
        28900.0,
        8100.0,
        4,
        5,
        0,
        30,
        "High",
        "Neurosurgery",
        Dict("risk_factors" => ["age>70", "anticoagulation"])
    )

    pathways["871"] = ClinicalPathway(
        "DRG_871_Seizure",
        "G40",
        "871",
        3,
        ["93000", "70450"],                           # EEG, CT
        "DRG",
        0.01,                                         # mortality: 1%
        0.12,                                         # readmission: 12%
        0.08,                                         # complications: 8%
        0.80,
        7400.0,
        1900.0,
        2,
        0,
        0,
        14,
        "Medium",
        "Neurology",
        Dict("risk_factors" => ["new_onset", "breakthrough_seizure"])
    )

    # ────────────────────────────────────────────────────────────────────
    # INFECTIOUS DISEASE PATHWAYS
    # ────────────────────────────────────────────────────────────────────

    pathways["876"] = ClinicalPathway(
        "DRG_876_Meningitis",
        "G00",
        "876",
        6,
        ["87040", "87088"],                           # Cultures, LP
        "DRG",
        0.12,                                         # mortality: 12%
        0.16,                                         # readmission: 16%
        0.18,                                         # complications: 18%
        0.70,
        14200.0,
        3800.0,
        3,
        3,
        0,
        10,
        "High",
        "Internal Medicine",
        Dict("risk_factors" => ["age>65", "immunocompromised"])
    )

    pathways["834"] = ClinicalPathway(
        "DRG_834_Cellulitis",
        "L03",
        "834",
        4,
        ["87040"],                                    # Culture
        "DRG",
        0.02,                                         # mortality: 2%
        0.10,                                         # readmission: 10%
        0.06,                                         # complications: 6%
        0.81,
        4600.0,
        1200.0,
        2,
        0,
        0,
        7,
        "Low",
        "Internal Medicine",
        Dict("risk_factors" => ["age>70", "diabetes", "poor_circulation"])
    )

    # ────────────────────────────────────────────────────────────────────
    # HEMATOLOGIC PATHWAYS
    # ────────────────────────────────────────────────────────────────────

    pathways["813"] = ClinicalPathway(
        "DRG_813_Anemia",
        "D50",
        "813",
        3,
        ["85025", "85004"],                           # CBC, RBC count
        "DRG",
        0.01,                                         # mortality: 1%
        0.08,                                         # readmission: 8%
        0.04,                                         # complications: 4%
        0.83,
        3800.0,
        1000.0,
        2,
        0,
        0,
        14,
        "Low",
        "Internal Medicine",
        Dict("risk_factors" => ["age>70", "GI_bleed", "CKD"])
    )

    pathways["838"] = ClinicalPathway(
        "DRG_838_Thrombocytopenia",
        "D69",
        "838",
        4,
        ["85025", "87040"],                           # CBC, cultures
        "DRG",
        0.02,                                         # mortality: 2%
        0.10,                                         # readmission: 10%
        0.08,                                         # complications: 8%
        0.78,
        6200.0,
        1600.0,
        2,
        1,
        0,
        10,
        "Medium",
        "Internal Medicine",
        Dict("risk_factors" => ["age>65", "malignancy"])
    )

    return pathways
end

# ============================================================================
# PATHWAY ROUTING LOGIC
# ============================================================================

"""
    route_to_pathway(drg_code::String)::ClinicalPathway

Route a patient to appropriate clinical pathway based on DRG code.
Returns pathway with evidence-based outcome and cost expectations.

# Arguments
- drg_code::String: Medicare DRG code (e.g., "246" for Acute MI)

# Returns
ClinicalPathway struct with complete outcome and cost specifications.
Raises KeyError if DRG code not found in repository.

# Example
```julia
pathway = route_to_pathway("246")  # Acute MI pathway
println("Expected LOS: \$(pathway.expected_los) days")
println("Mortality: \$(pathway.expected_mortality_rate * 100)%")
```
"""
function route_to_pathway(drg_code::String)::ClinicalPathway
    pathways = get_clinical_pathways()

    if !haskey(pathways, drg_code)
        error("DRG code $drg_code not found in clinical pathway repository")
    end

    return pathways[drg_code]
end

# ============================================================================
# DEFAULT PATHWAY (Fallback for unknown DRGs)
# ============================================================================

"""
    get_default_pathway(drg_code::String)::ClinicalPathway

Return default (conservative) clinical pathway for DRG codes not in repository.
Used as fallback to enable simulation for all DRGs.

# Arguments
- drg_code::String: Medicare DRG code

# Returns
ClinicalPathway with generic assumptions (conservative for budget impact)
"""
function get_default_pathway(drg_code::String)::ClinicalPathway
    return ClinicalPathway(
        "DRG_$(drg_code)_Unknown",
        "UNKNOWN",
        drg_code,
        4,                                            # Default 4-day LOS
        String[],                                     # No typical procedures
        "DRG",
        0.05,                                         # Conservative: 5% mortality
        0.15,                                         # Conservative: 15% readmission
        0.12,                                         # Conservative: 12% complications
        0.75,                                         # Conservative: 0.75 quality
        12000.0,                                      # Default cost
        4000.0,                                       # Default std dev
        2,                                            # ED hours
        0,                                            # No ICU by default
        0,                                            # No OR by default
        14,                                           # Default readmission window
        "Medium",                                     # Default complexity
        "Internal Medicine",                          # Default specialty
        Dict("note" => "Default pathway - consult specific DRG repository for actual pathways")
    )
end
