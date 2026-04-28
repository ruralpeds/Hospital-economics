"""
Tests for X12 837/835 and FHIR parsers in claims_formats.jl.
"""

using Test
using Dates

# Load module-level pieces — these tests assume the top-level package has
# been loaded by the parent runtests.jl, so the symbols below are visible.
# Fall back to direct include when running this file standalone.
if !isdefined(Main, :parse_x12)
    include(joinpath(@__DIR__, "..", "..", "src", "data_ingestion", "types.jl"))
    include(joinpath(@__DIR__, "..", "..", "src", "data_ingestion", "claims_formats.jl"))
end

# ---------------------------------------------------------------------------
# X12 837 — synthetic minimal payload
# ---------------------------------------------------------------------------

const SAMPLE_837 = join([
    "ISA*00*          *00*          *ZZ*SUBMITTERID    *ZZ*RECEIVERID     *240101*1200*^*00501*000000001*0*P*:",
    "GS*HC*SUBMITTER*RECEIVER*20240101*1200*1*X*005010X222A1",
    "ST*837*0001*005010X222A1",
    "BHT*0019*00*0123*20240101*1200*CH",
    "NM1*41*2*BILLING PROVIDER*****46*1234567890",
    "NM1*40*2*RECEIVER*****46*RECEIVERID",
    "HL*1**20*1",
    "NM1*85*2*HOSPITAL X*****XX*1234567893",
    "HL*2*1*22*0",
    "NM1*IL*1*DOE*JANE****MI*INSUREDID",
    "CLM*CLAIM001*1500***11:B:1*Y*A*Y*Y",
    "HI*ABK:E119",
    "SV1*HC:99213*150*UN*1***1",
    "SE*13*0001",
    "GE*1*1",
    "IEA*1*000000001",
], "~") * "~"

@testset "X12 837 parsing" begin
    itx = parse_x12(SAMPLE_837)
    @test itx.delimiters.element == '*'
    @test itx.delimiters.segment == '~'
    @test itx.delimiters.component == ':'
    @test length(itx.transaction_sets) == 1
    ts = itx.transaction_sets[1]
    @test ts.set_id == "837"
    @test ts.summary["claim_count"] == 1
    @test ts.summary["billed_total"] == 1500.0
    @test ts.summary["billing_provider_npi"] == "1234567893"
    @test ts.summary["subscriber_id"] == "INSUREDID"
    @test "E119" in ts.summary["diagnoses"]
    @test ts.summary["service_lines"] == 1
end

# ---------------------------------------------------------------------------
# X12 835 — synthetic minimal payload
# ---------------------------------------------------------------------------

const SAMPLE_835 = join([
    "ISA*00*          *00*          *ZZ*PAYERID        *ZZ*PROVIDER       *240101*1200*^*00501*000000002*0*P*:",
    "GS*HP*PAYER*PROVIDER*20240101*1200*2*X*005010X221A1",
    "ST*835*0002",
    "BPR*I*5000*C*ACH*CCP*01*123456789*DA*9999*PAYERID**01*123456789*DA*9999*20240105",
    "TRN*1*EFT001*123456789",
    "DTM*405*20240105",
    "N1*PR*PAYER NAME*FI*PAYERID",
    "N1*PE*PROVIDER NAME*FI*1234567893",
    "CLP*CLAIM001*1*1500*1200*300*MC*PAYER001",
    "CAS*PR*1*300",
    "SE*9*0002",
    "GE*1*2",
    "IEA*1*000000002",
], "~") * "~"

@testset "X12 835 parsing" begin
    itx = parse_x12(SAMPLE_835)
    @test length(itx.transaction_sets) == 1
    ts = itx.transaction_sets[1]
    @test ts.set_id == "835"
    @test ts.summary["payment_total"] == 5000.0
    @test ts.summary["payer_id"] == "PAYERID"
    @test ts.summary["payee_npi"] == "1234567893"
    @test ts.summary["claim_count"] == 1
    cp = ts.summary["claim_payments"][1]
    @test cp["claim_id"] == "CLAIM001"
    @test cp["billed"] == 1500.0
    @test cp["paid"]   == 1200.0
    @test cp["patient_resp"] == 300.0
end

@testset "X12 envelope errors" begin
    @test_throws ArgumentError parse_x12("")
    @test_throws ArgumentError parse_x12("NOT_AN_X12_PAYLOAD")
end

# ---------------------------------------------------------------------------
# FHIR R4 — single resource and Bundle
# ---------------------------------------------------------------------------

const FHIR_BUNDLE_JSON = """
{
  "resourceType": "Bundle",
  "type": "collection",
  "entry": [
    {
      "resource": {
        "resourceType": "Patient",
        "id": "p1",
        "gender": "female",
        "birthDate": "1955-04-12",
        "address": [{"postalCode": "94110-2345"}]
      }
    },
    {
      "resource": {
        "resourceType": "Encounter",
        "id": "enc1",
        "subject": {"reference": "Patient/p1"},
        "class": {"code": "EMER"},
        "period": {"start": "2024-03-04", "end": "2024-03-07"},
        "diagnosis": [
          {"condition": {"display": "I50.9"}},
          {"condition": {"display": "E11.9"}}
        ]
      }
    }
  ]
}
"""

@testset "FHIR Bundle parsing and Encounter mapping" begin
    resources = parse_fhir(FHIR_BUNDLE_JSON)
    @test length(resources) == 2
    types = Set(r.resource_type for r in resources)
    @test "Patient" in types && "Encounter" in types

    encs = fhir_to_encounter(resources)
    @test length(encs) == 1
    e = encs[1]
    @test e.encounter_id == "enc1"
    @test e.patient_id == "p1"
    @test e.admission_date == Date("2024-03-04")
    @test e.discharge_date == Date("2024-03-07")
    @test e.length_of_stay == 3
    @test e.sex == "F"
    @test e.zip_code_prefix == "941"
    @test e.admission_type == "Emergency"
    @test e.primary_diagnosis == "I50.9"
    @test e.secondary_diagnoses == ["E11.9"]
    @test e.birth_year == 1955
    @test e.source_system == "FHIR"
end

@testset "FHIR single resource and missing fields" begin
    single = """{"resourceType": "Patient", "id": "p99", "gender": "male"}"""
    res = parse_fhir(single)
    @test length(res) == 1
    @test res[1].resource_type == "Patient"
    @test res[1].id == "p99"

    # Encounter with no patient match — skipped silently
    orphan = """
    {"resourceType":"Bundle","entry":[
      {"resource":{"resourceType":"Encounter","id":"e2",
        "subject":{"reference":"Patient/missing"},
        "period":{"start":"2024-01-01"}}}
    ]}"""
    encs = fhir_to_encounter(parse_fhir(orphan))
    @test length(encs) == 1
    @test encs[1].patient_id == "missing"
    @test encs[1].zip_code_prefix == "000"
end
