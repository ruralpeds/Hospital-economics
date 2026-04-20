"""
Tests for data validation functions
"""

using Test
using Dates
import HealthcareEconomics.DataIngestionPipeline as DIP

@testset "ICD-10 Code Validation" begin
    # Valid codes
    @test DIP.validate_icd10_code("E11.9") == true
    @test DIP.validate_icd10_code("J44.0") == true
    @test DIP.validate_icd10_code("I10") == true
    @test DIP.validate_icd10_code("Z23") == true
    @test DIP.validate_icd10_code("A01.00") == true
    
    # Invalid codes
    @test DIP.validate_icd10_code("") == false
    @test DIP.validate_icd10_code("12345") == false  # Starts with digit
    @test DIP.validate_icd10_code("V12.34") == false  # V not valid
    @test DIP.validate_icd10_code("E11") == true  # Actually valid (3 chars)
    @test DIP.validate_icd10_code("E1199999") == false  # Too long
end

@testset "CPT Code Validation" begin
    # Valid CPT codes
    @test DIP.validate_cpt_code("99213") == true
    @test DIP.validate_cpt_code("27447") == true
    @test DIP.validate_cpt_code("00100") == true
    @test DIP.validate_cpt_code("G0438") == true  # Category II code
    
    # Invalid CPT codes
    @test DIP.validate_cpt_code("") == false
    @test DIP.validate_cpt_code("9921") == false  # Too short
    @test DIP.validate_cpt_code("992134") == false  # Too long
    @test DIP.validate_cpt_code("ABC12") == false  # Two letters
end

@testset "Patient Encounter Validation" begin
    # Valid encounter
    valid_enc = DIP.PatientEncounter(
        "p1", "e1",
        Date(2024, 1, 15),
        Date(2024, 1, 18);
        birth_year = 1960,
        age_at_admission = 64,
        sex = "M",
        primary_diagnosis = "E11.9",
        total_charges = 15000.00,
    )
    
    result = DIP.validate_patient_encounter(valid_enc)
    @test result.is_valid == true
    @test isempty(result.errors)
    
    # Invalid: discharge before admission
    invalid_enc = DIP.PatientEncounter(
        "p2", "e2",
        Date(2024, 1, 18),
        Date(2024, 1, 15);
    )
    
    result = DIP.validate_patient_encounter(invalid_enc)
    @test result.is_valid == false
    @test !isempty(result.errors)
    @test result.errors[1].error_code == "DATE_RANGE_ERROR"
    
    # Invalid: negative age
    invalid_enc2 = DIP.PatientEncounter(
        "p3", "e3",
        Date(2024, 1, 15),
        Date(2024, 1, 18);
        age_at_admission = -5,
    )
    
    result = DIP.validate_patient_encounter(invalid_enc2)
    @test result.is_valid == false
    @test any(e -> e.error_code == "AGE_OUT_OF_RANGE", result.errors)
end

@testset "Cost Validation" begin
    # Valid costs
    valid_enc = DIP.PatientEncounter(
        "p1", "e1",
        Date(2024, 1, 15),
        Date(2024, 1, 18);
        total_charges = 0.00,  # Zero is valid
    )
    
    result = DIP.validate_patient_encounter(valid_enc)
    @test result.is_valid == true
    
    # Negative charges (invalid)
    invalid_enc = DIP.PatientEncounter(
        "p2", "e2",
        Date(2024, 1, 15),
        Date(2024, 1, 18);
        total_charges = -1000.00,
    )
    
    result = DIP.validate_patient_encounter(invalid_enc)
    @test result.is_valid == false
    @test any(e -> e.error_code == "NEGATIVE_COST", result.errors)
end

@testset "Batch Validation" begin
    encounters = [
        DIP.PatientEncounter(
            "p$i", "e$i",
            Date(2024, 1, 15),
            Date(2024, 1, 18);
            total_charges = 1000.0 + i * 100,
        )
        for i in 1:10
    ]
    
    report = DIP.validate_encounters_batch(encounters)
    
    @test report["total"] == 10
    @test report["valid"] == 10
    @test report["invalid"] == 0
    @test report["validity_pct"] == 100.0
end

