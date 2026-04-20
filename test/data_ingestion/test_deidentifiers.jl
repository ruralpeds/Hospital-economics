"""
Tests for de-identification functions (HIPAA Safe Harbor)
"""

using Test
using Dates
import HealthcareEconomics.DataIngestionPipeline as DIP

@testset "Pseudonym Generation" begin
    salt = "TestOrgSalt2024"
    
    # Same input produces same pseudonym (deterministic)
    mrn1 = "123456789"
    pseudo1 = DIP.generate_pseudonym(mrn1, salt)
    pseudo2 = DIP.generate_pseudonym(mrn1, salt)
    
    @test pseudo1 == pseudo2
    @test length(pseudo1) == 16  # Should be 16 chars (first half of SHA-256 hex)
    @test all(c -> c in "0123456789abcdef", pseudo1)  # Should be hex
    
    # Different inputs produce different pseudonyms
    mrn2 = "987654321"
    pseudo3 = DIP.generate_pseudonym(mrn2, salt)
    
    @test pseudo1 != pseudo3
    
    # Different salt produces different pseudonyms
    salt2 = "DifferentSalt"
    pseudo4 = DIP.generate_pseudonym(mrn1, salt2)
    
    @test pseudo1 != pseudo4
end

@testset "Encounter ID Generation" begin
    patient_pseudo = "3a7f2e1c9b4d6f8a"
    admission_date = Date(2024, 1, 15)
    
    encounter_id = DIP.generate_encounter_id(patient_pseudo, admission_date)
    
    @test startswith(encounter_id, "3a7f2e1c9b4d6f8a_")
    @test contains(encounter_id, "20240115")
    @test contains(encounter_id, "001")
end

@testset "De-identification Safe Harbor" begin
    salt = "TestOrgSalt2024"
    
    raw_data = Dict(
        "patient_id" => "987654321",  # MRN (will be pseudonymized)
        "first_name" => "John",  # Will be ignored
        "last_name" => "Doe",  # Will be ignored
        "dob" => "1960-05-15",
        "age_at_admission" => 64,
        "sex" => "M",
        "race_code" => "W",
        "ethnicity_code" => "Non-Hispanic",
        "zip_code" => "123456",  # Full ZIP
        "admission_date" => "2024-01-15",
        "discharge_date" => "2024-01-18",
        "admission_type" => "Scheduled",
        "discharge_disposition" => "Home",
        "primary_diagnosis" => "E11.9",
        "secondary_diagnoses" => ["I10", "J44.0"],
        "procedures" => ["99213"],
        "total_charges" => 15000.00,
        "payer" => "Medicare",
    )
    
    enc = DIP.deidentify_encounter(raw_data, salt)
    
    # Check de-identification results
    @test enc.patient_id != "987654321"  # Pseudonymized
    @test length(enc.patient_id) == 16  # Hex string
    @test enc.birth_year == 1960  # Birth year preserved
    @test enc.age_at_admission == 64  # Age preserved
    @test enc.sex == "M"  # Sex preserved
    @test enc.zip_code_prefix == "123"  # Only first 3 digits
    @test enc.primary_diagnosis == "E11.9"  # Clinical data preserved
    @test enc.total_charges == 15000.00  # Financial data preserved
    @test !haskey(enc.metadata, "first_name")  # Names not in metadata
end

@testset "Age Capping (Safe Harbor)" begin
    salt = "TestOrgSalt2024"
    
    # Age >89 should be capped at 90
    raw_data = Dict(
        "patient_id" => "111111111",
        "age_at_admission" => 95,
        "dob" => "1930-01-01",
        "admission_date" => "2024-01-15",
        "discharge_date" => "2024-01-18",
    )
    
    enc = DIP.deidentify_encounter(raw_data, salt)
    @test enc.age_at_admission == 90  # Capped at 90
end

@testset "De-identification Validation" begin
    # Create a properly de-identified encounter
    salt = "TestOrgSalt2024"
    raw_data = Dict(
        "patient_id" => "123456789",
        "dob" => "1960-05-15",
        "age_at_admission" => 64,
        "zip_code" => "123456",
        "admission_date" => "2024-01-15",
        "discharge_date" => "2024-01-18",
        "primary_diagnosis" => "E11.9",
    )
    
    enc = DIP.deidentify_encounter(raw_data, salt)
    is_safe, issues = DIP.validate_deidentification(enc)
    
    @test is_safe == true
    @test isempty(issues)
    
    # Test with age >90 (should raise issue)
    enc2 = DIP.PatientEncounter(
        "p1", "e1",
        Date(2024, 1, 15),
        Date(2024, 1, 18);
        age_at_admission = 95,  # >90, should be flagged
    )
    
    is_safe, issues = DIP.validate_deidentification(enc2)
    @test is_safe == false
    @test !isempty(issues)
    @test any(issue -> contains(lowercase(issue), "age"), issues)
end

@testset "Deterministic Hashing for Linkage" begin
    salt = "TestOrgSalt2024"
    mrn = "999888777"
    
    # Same patient processed multiple times gets same pseudonym
    pseudo1 = DIP.generate_pseudonym(mrn, salt)
    
    # Simulate processing same patient in different batch
    pseudo2 = DIP.generate_pseudonym(mrn, salt)
    
    @test pseudo1 == pseudo2
    # This allows linking same patient across multiple ingestions without storing original MRN
end

