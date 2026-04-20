"""
Tests for data ingestion types (PatientEncounter, IngestionConfig, etc.)
"""

using Test
using Dates
import HealthcareEconomics.DataIngestionPipeline as DIP

@testset "PatientEncounter Type" begin
    # Test basic constructor
    enc = DIP.PatientEncounter(
        "patient_001",
        "encounter_001",
        Date(2024, 1, 15),
        Date(2024, 1, 18);
        birth_year = 1960,
        age_at_admission = 64,
        sex = "M",
        primary_diagnosis = "E11.9",
        total_charges = 15000.00,
        payer = "Medicare",
    )
    
    @test enc.patient_id == "patient_001"
    @test enc.encounter_id == "encounter_001"
    @test enc.birth_year == 1960
    @test enc.age_at_admission == 64
    @test enc.length_of_stay == 3
    @test enc.total_charges == 15000.00
    @test enc.payer == "Medicare"
    @test enc.validation_status == "Pending"
    @test !isempty(enc.ingestion_date)
end

@testset "IngestionConfig Type" begin
    config = DIP.IngestionConfig(
        "data/patients.csv",
        field_mapping = Dict(
            "MRN" => "patient_id",
            "DOB" => "dob",
        ),
        deidentify = true,
        validate = true,
        batch_size = 500,
    )
    
    @test config.filepath == "data/patients.csv"
    @test config.delimiter == ','
    @test config.deidentify == true
    @test config.validate == true
    @test config.batch_size == 500
    @test haskey(config.field_mapping, "MRN")
end

@testset "ValidationResult Type" begin
    error = DIP.ValidationError(
        1,
        "primary_diagnosis",
        "INVALID",
        "INVALID_ICD10",
        "Invalid ICD-10 code format",
        "ERROR",
    )
    
    result = DIP.ValidationResult(false, [error], ["Warning 1"])
    
    @test result.is_valid == false
    @test length(result.errors) == 1
    @test length(result.warnings) == 1
    @test result.errors[1].field == "primary_diagnosis"
end

@testset "AuditLogEntry Type" begin
    entry = DIP.AuditLogEntry(
        "user@hospital.org",
        "INGESTION_START",
        "DATA_ACTION";
        resource_type = "PATIENT_ENCOUNTER",
        resource_id = "file_001",
        status = "SUCCESS",
        record_count = 100,
    )
    
    @test entry.user_id == "user@hospital.org"
    @test entry.event_type == "INGESTION_START"
    @test entry.action == "DATA_ACTION"
    @test entry.status == "SUCCESS"
    @test entry.record_count == 100
    @test !isempty(entry.entry_id)
    @test !isempty(entry.timestamp)
end

@testset "IngestionResult Type" begin
    encounters = [
        DIP.PatientEncounter(
            "p1", "e1",
            Date(2024, 1, 15), Date(2024, 1, 18)
        )
    ]
    
    result = DIP.IngestionResult(
        true,
        10,
        8,
        1,
        1;
        encounters = encounters,
        validation_errors = DIP.ValidationError[],
        quality_summary = Dict("score" => 80.0),
        audit_log_entries = DIP.AuditLogEntry[],
        processing_time = 1.23,
    )
    
    @test result.success == true
    @test result.records_loaded == 10
    @test result.records_valid == 8
    @test result.records_with_warnings == 1
    @test result.records_rejected == 1
    @test length(result.encounters) == 1
    @test result.processing_time == 1.23
end

