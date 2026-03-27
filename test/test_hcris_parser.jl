# ============================================================================
# Tests for HCRIS data import
# ============================================================================

using Test

# ---------------------------------------------------------------------------
# Stub HCRIS parser (until CSV/DataFrames integration is complete)
# ---------------------------------------------------------------------------

struct HCRISRecord
    provider_number::String
    fiscal_year_begin::String
    fiscal_year_end::String
    hospital_name::String
    state::String
    total_beds::Int
    total_discharges::Int
    total_patient_revenue::Float64
    net_patient_revenue::Float64
    total_operating_expense::Float64
    net_income::Float64
    total_charges::Float64
    total_costs::Float64
    medicare_charges::Float64
    medicare_costs::Float64
    cost_to_charge_ratio::Float64
end

"""
    parse_hcris_csv(filepath::String) -> Vector{HCRISRecord}

Parse a HCRIS CSV extract file into structured records.
"""
function parse_hcris_csv(filepath::String)::Vector{HCRISRecord}
    isfile(filepath) || error("File not found: $filepath")

    records = HCRISRecord[]
    lines = readlines(filepath)
    length(lines) < 2 && return records  # header only

    # Skip header
    for line in lines[2:end]
        fields = split(line, ",")
        length(fields) < 16 && continue

        # Skip empty or malformed rows
        try
            record = HCRISRecord(
                strip(fields[1]),
                strip(fields[2]),
                strip(fields[3]),
                strip(fields[4]),
                strip(fields[5]),
                parse(Int, strip(fields[6])),
                parse(Int, strip(fields[7])),
                parse(Float64, strip(fields[8])),
                parse(Float64, strip(fields[9])),
                parse(Float64, strip(fields[10])),
                parse(Float64, strip(fields[11])),
                parse(Float64, strip(fields[12])),
                parse(Float64, strip(fields[13])),
                parse(Float64, strip(fields[14])),
                parse(Float64, strip(fields[15])),
                parse(Float64, strip(fields[16])),
            )
            push!(records, record)
        catch e
            @warn "Skipping malformed HCRIS row" exception=e
            continue
        end
    end

    return records
end

"""
    validate_hcris_record(record::HCRISRecord) -> Vector{String}

Validate a single HCRIS record and return list of issues found.
"""
function validate_hcris_record(record::HCRISRecord)::Vector{String}
    issues = String[]

    isempty(record.provider_number) && push!(issues, "missing_provider_number")
    record.total_beds < 0 && push!(issues, "negative_beds")
    record.total_discharges < 0 && push!(issues, "negative_discharges")
    record.total_patient_revenue < 0.0 && push!(issues, "negative_revenue")
    record.total_operating_expense < 0.0 && push!(issues, "negative_expense")
    record.cost_to_charge_ratio < 0.0 && push!(issues, "negative_ccr")
    record.cost_to_charge_ratio > 1.5 && push!(issues, "unreasonable_ccr")
    record.total_costs > record.total_charges && push!(issues, "costs_exceed_charges")

    return issues
end

"""
    compute_hcris_metrics(record::HCRISRecord) -> NamedTuple

Compute key financial metrics from a HCRIS record.
"""
function compute_hcris_metrics(record::HCRISRecord)
    operating_margin = record.net_patient_revenue > 0.0 ?
        record.net_income / record.net_patient_revenue : 0.0
    ccr = record.total_charges > 0.0 ?
        record.total_costs / record.total_charges : 0.0
    cost_per_discharge = record.total_discharges > 0 ?
        record.total_operating_expense / record.total_discharges : 0.0
    revenue_per_bed = record.total_beds > 0 ?
        record.net_patient_revenue / record.total_beds : 0.0
    medicare_share = record.total_charges > 0.0 ?
        record.medicare_charges / record.total_charges : 0.0

    return (
        operating_margin=operating_margin,
        cost_to_charge_ratio=ccr,
        cost_per_discharge=cost_per_discharge,
        revenue_per_bed=revenue_per_bed,
        medicare_share=medicare_share,
    )
end

@testset "HCRIS Parser" begin

    # Path to test fixture
    fixture_path = joinpath(@__DIR__, "fixtures", "sample_hcris_extract.csv")

    # -----------------------------------------------------------------------
    @testset "Parse sample HCRIS CSV" begin
        @test isfile(fixture_path)
        records = parse_hcris_csv(fixture_path)

        @test length(records) > 0
        @test length(records) == 5  # our fixture has 5 rows

        # Check first record
        r1 = records[1]
        @test r1.provider_number == "171301"
        @test r1.state == "KS"
        @test r1.total_beds > 0
        @test r1.total_patient_revenue > 0.0
        @test r1.total_operating_expense > 0.0
    end

    # -----------------------------------------------------------------------
    @testset "HCRIS record validation — valid record" begin
        record = HCRISRecord(
            "171301", "2023-01-01", "2023-12-31",
            "Prairie View Medical Center", "KS",
            25, 450, 12_000_000.0, 9_500_000.0,
            9_200_000.0, 300_000.0,
            12_000_000.0, 5_000_000.0,
            6_500_000.0, 2_700_000.0, 0.42,
        )
        issues = validate_hcris_record(record)
        @test isempty(issues)
    end

    # -----------------------------------------------------------------------
    @testset "HCRIS record validation — invalid record" begin
        record = HCRISRecord(
            "", "2023-01-01", "2023-12-31",
            "Bad Hospital", "XX",
            -5, -10, -100.0, -50.0,
            -200.0, -300.0,
            1000.0, 2000.0,  # costs > charges
            500.0, 600.0, -0.5,
        )
        issues = validate_hcris_record(record)
        @test "missing_provider_number" in issues
        @test "negative_beds" in issues
        @test "negative_discharges" in issues
        @test "negative_revenue" in issues
        @test "negative_expense" in issues
        @test "negative_ccr" in issues
        @test "costs_exceed_charges" in issues
    end

    # -----------------------------------------------------------------------
    @testset "HCRIS metrics computation" begin
        record = HCRISRecord(
            "171301", "2023-01-01", "2023-12-31",
            "Prairie View Medical Center", "KS",
            25, 500, 12_000_000.0, 9_500_000.0,
            9_200_000.0, 300_000.0,
            12_000_000.0, 5_000_000.0,
            6_500_000.0, 2_700_000.0, 0.42,
        )
        metrics = compute_hcris_metrics(record)

        # Operating margin
        expected_margin = 300_000.0 / 9_500_000.0
        @test isapprox(metrics.operating_margin, expected_margin; atol=0.001)

        # Cost to charge ratio
        expected_ccr = 5_000_000.0 / 12_000_000.0
        @test isapprox(metrics.cost_to_charge_ratio, expected_ccr; atol=0.001)

        # Cost per discharge
        expected_cpd = 9_200_000.0 / 500
        @test isapprox(metrics.cost_per_discharge, expected_cpd; atol=1.0)

        # Revenue per bed
        expected_rpb = 9_500_000.0 / 25
        @test isapprox(metrics.revenue_per_bed, expected_rpb; atol=1.0)

        # Medicare share
        expected_ms = 6_500_000.0 / 12_000_000.0
        @test isapprox(metrics.medicare_share, expected_ms; atol=0.001)
    end

    # -----------------------------------------------------------------------
    @testset "HCRIS metrics — edge cases" begin
        # Zero beds, zero discharges
        record = HCRISRecord(
            "999999", "2023-01-01", "2023-12-31",
            "Empty Hospital", "XX",
            0, 0, 0.0, 0.0, 0.0, 0.0,
            0.0, 0.0, 0.0, 0.0, 0.0,
        )
        metrics = compute_hcris_metrics(record)
        @test metrics.operating_margin == 0.0
        @test metrics.cost_to_charge_ratio == 0.0
        @test metrics.cost_per_discharge == 0.0
        @test metrics.revenue_per_bed == 0.0
        @test metrics.medicare_share == 0.0
    end

    # -----------------------------------------------------------------------
    @testset "Parse nonexistent file" begin
        @test_throws ErrorException parse_hcris_csv("/nonexistent/path.csv")
    end

    # -----------------------------------------------------------------------
    @testset "Parse fixture records have valid data" begin
        records = parse_hcris_csv(fixture_path)
        for record in records
            issues = validate_hcris_record(record)
            @test isempty(issues)
            metrics = compute_hcris_metrics(record)
            @test isfinite(metrics.operating_margin)
            @test metrics.cost_to_charge_ratio >= 0.0
        end
    end
end
