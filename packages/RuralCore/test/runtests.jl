using Test
using RuralCore
using DataFrames

include("test_errors.jl")
include("test_audit.jl")

@testset "RuralCore" begin
    @testset "CountyKey" begin
        k = CountyKey("01001")
        @test k.fips == "01001"
        @test state_fips(k) == "01"
        @test county_fips(k) == "001"
        @test_throws ArgumentError CountyKey("1234")
        @test_throws ArgumentError CountyKey("abcde")
        @test CountyKey("01001") == CountyKey("01001")
        @test CountyKey("01001") != CountyKey("01002")
    end

    @testset "CountyKey — show method" begin
        k = CountyKey("01001")
        s = sprint(show, k)
        @test occursin("01001", s)
    end

    @testset "CountyKey — hash consistency" begin
        k1 = CountyKey("05045")
        k2 = CountyKey("05045")
        @test hash(k1) == hash(k2)
        @test hash(k1) != hash(CountyKey("05047"))
    end

    @testset "TimeKey" begin
        t = TimeKey(2024)
        @test t.year == 2024
        @test_throws ArgumentError TimeKey(1800)
        @test_throws ArgumentError TimeKey(2200)
    end

    @testset "TimeKey — boundary years valid" begin
        @test TimeKey(1900).year == 1900
        @test TimeKey(2100).year == 2100
    end

    @testset "CountyYearKey" begin
        k = CountyYearKey("01001", 2024)
        @test k.county.fips == "01001"
        @test k.time.year == 2024
    end

    @testset "CountyYearKey — show method" begin
        k = CountyYearKey("01001", 2024)
        s = sprint(show, k)
        @test occursin("01001", s)
        @test occursin("2024", s)
    end

    @testset "Hospital — all fields accessible" begin
        h = Hospital("011300", "Rural Medical Center", CountyKey("01001"),
            CRITICAL_ACCESS, SMALL, 25, true)
        @test h.licensed_beds == 25
        @test h.is_rural
        @test h.hospital_type == CRITICAL_ACCESS
        @test h.id == "011300"
        @test h.name == "Rural Medical Center"
        @test h.size == SMALL
    end

    @testset "Hospital — urban facility" begin
        h = Hospital("999999", "City Medical Center", CountyKey("06037"),
            ACUTE_CARE, MAJOR, 350, false)
        @test !h.is_rural
        @test h.hospital_type == ACUTE_CARE
        @test h.size == MAJOR
        @test h.licensed_beds == 350
    end

    @testset "Hospital — show method" begin
        h = Hospital("011300", "Rural Medical Center", CountyKey("01001"),
            CRITICAL_ACCESS, SMALL, 25, true)
        s = sprint(show, h)
        @test occursin("Rural Medical Center", s)
    end

    @testset "Hospital — all HospitalType enum values" begin
        for ht in [CRITICAL_ACCESS, ACUTE_CARE, LONG_TERM_CARE,
                   REHABILITATION, PSYCHIATRIC, CHILDRENS, TEACHING]
            h = Hospital("000001", "Test", CountyKey("01001"), ht, SMALL, 10, true)
            @test h.hospital_type == ht
        end
    end

    @testset "Hospital — all FacilitySize enum values" begin
        for fs in [MICRO, SMALL, MEDIUM, LARGE, MAJOR, ACADEMIC]
            h = Hospital("000001", "Test", CountyKey("01001"), ACUTE_CARE, fs, 10, false)
            @test h.size == fs
        end
    end

    @testset "PayerMix — indexed access" begin
        pm = PayerMix(Dict(
            MEDICARE => 0.45,
            MEDICAID => 0.20,
            COMMERCIAL => 0.25,
            SELF_PAY => 0.10,
        ))
        @test pm[MEDICARE] ≈ 0.45
        @test pm[MEDICAID] ≈ 0.20
        @test pm[COMMERCIAL] ≈ 0.25
        @test pm[SELF_PAY] ≈ 0.10
        @test pm[OTHER_PAYER] ≈ 0.0   # not present → default 0
    end

    @testset "PayerMix — show method" begin
        pm = PayerMix(Dict(MEDICARE => 0.60, MEDICAID => 0.40))
        s = sprint(show, pm)
        @test occursin("PayerMix", s)
    end

    @testset "QualityMetric — higher_is_better true" begin
        m = QualityMetric("HCAHPS-COMM", "Nurse Communication", PATIENT_EXPERIENCE, true, 0.78)
        @test m.id == "HCAHPS-COMM"
        @test m.higher_is_better
        @test m.domain == PATIENT_EXPERIENCE
        @test m.national_benchmark ≈ 0.78
    end

    @testset "QualityMetric — higher_is_better false" begin
        m = QualityMetric("MORT-30-AMI", "30-Day AMI Mortality", EFFECTIVENESS, false, 0.12)
        @test m.id == "MORT-30-AMI"
        @test !m.higher_is_better
    end

    @testset "QualityMetric — show method" begin
        m = QualityMetric("PSI-90", "Patient Safety", SAFETY, false, 1.0)
        s = sprint(show, m)
        @test occursin("PSI-90", s)
    end

    @testset "County — construction and fields" begin
        c = County(CountyKey("01001"), "Cherokee County", "Alabama", 25000, true, 7)
        @test c.key.fips == "01001"
        @test c.name == "Cherokee County"
        @test c.state == "Alabama"
        @test c.population == 25000
        @test c.is_rural
        @test c.rucc_code == 7
    end

    @testset "County — show method" begin
        c = County(CountyKey("01001"), "Cherokee County", "Alabama", 25000, true, 7)
        s = sprint(show, c)
        @test occursin("Cherokee County", s)
        @test occursin("rural", s)
    end

    @testset "Region — construction" begin
        counties = [CountyKey("01001"), CountyKey("01003"), CountyKey("01005")]
        r = Region("Southeast Alabama", counties)
        @test r.name == "Southeast Alabama"
        @test length(r.counties) == 3
    end

    @testset "Region — show method" begin
        r = Region("Test Region", [CountyKey("01001")])
        s = sprint(show, r)
        @test occursin("Test Region", s)
        @test occursin("1", s)
    end

    @testset "ChapterMeta — construction" begin
        cm = ChapterMeta(
            3,
            "Descriptive Statistics",
            :intermediate,
            [1, 2],
            ["Compute measures of central tendency"],
            ["mean = Σx/n"],
            "chapter3_data.csv",
            90,
        )
        @test cm.number == 3
        @test cm.title == "Descriptive Statistics"
        @test cm.tier == :intermediate
        @test length(cm.prerequisites) == 2
        @test cm.estimated_time_minutes == 90
    end

    @testset "ChapterMeta — show method" begin
        cm = ChapterMeta(1, "Introduction", :beginner, Int[], String[], String[], "", 30)
        s = sprint(show, cm)
        @test occursin("1", s)
        @test occursin("Introduction", s)
    end

    @testset "RuralDefinition" begin
        @test DEFAULT_RURAL_DEF.name == :rucc
        meta = Dict("01001" => 7)
        @test classify_rural(DEFAULT_RURAL_DEF, "01001"; metadata=meta)
        meta2 = Dict("01001" => 1)
        @test !classify_rural(DEFAULT_RURAL_DEF, "01001"; metadata=meta2)
    end

    @testset "RuralDefinition — boundary RUCC code 4 is nonmetro" begin
        meta = Dict("12345" => 4)
        @test classify_rural(DEFAULT_RURAL_DEF, "12345"; metadata=meta)
    end

    @testset "RuralDefinition — RUCC code 3 is metro" begin
        meta = Dict("12345" => 3)
        @test !classify_rural(DEFAULT_RURAL_DEF, "12345"; metadata=meta)
    end

    @testset "RuralDefinition — missing FIPS defaults to non-rural" begin
        # FIPS not in metadata, so get returns 0 which is not in RUCC_NONMETRO_CODES
        @test !classify_rural(DEFAULT_RURAL_DEF, "99999"; metadata=Dict{String,Int}())
    end

    @testset "RUCC_NONMETRO_CODES — contains codes 4–9" begin
        for code in 4:9
            @test code in RUCC_NONMETRO_CODES
        end
        @test !(1 in RUCC_NONMETRO_CODES)
        @test !(3 in RUCC_NONMETRO_CODES)
    end

    @testset "Constants" begin
        @test haskey(CMS_BENCHMARKS, "MORT-30-AMI")
        @test CMS_BENCHMARKS["CLABSI-SIR"] ≈ 1.0
        @test WONG_PALETTE.blue == "#0072B2"
    end

    @testset "CMS_BENCHMARKS — expected keys present" begin
        for key in ["MORT-30-AMI", "MORT-30-HF", "MORT-30-PN", "READM-30-AMI"]
            @test haskey(CMS_BENCHMARKS, key)
        end
    end

    @testset "Validation — validate_sample_size" begin
        @test validate_sample_size(10) === nothing
        @test validate_sample_size(2) === nothing   # minimum is 2
        @test_throws InsufficientSampleError validate_sample_size(1)
        @test_throws InsufficientSampleError validate_sample_size(0)
    end

    @testset "Validation — validate_sample_size with custom minimum" begin
        @test validate_sample_size(30, 30) === nothing
        @test_throws InsufficientSampleError validate_sample_size(29, 30)
    end

    @testset "Validation — validate_fips" begin
        @test validate_fips("01001")
        @test validate_fips("99999")
        @test_throws DataValidationError validate_fips("123")
        @test_throws DataValidationError validate_fips("abcde")
        @test_throws DataValidationError validate_fips("0100")
        @test_throws DataValidationError validate_fips("010011")
    end

    @testset "Validation — validate_columns" begin
        df = DataFrame(fips = ["01001"], year = [2020], pop = [1000])
        @test validate_columns(df, [:fips, :year, :pop]) === nothing
        @test validate_columns(df, [:fips]) === nothing
    end

    @testset "Validation — validate_columns missing column" begin
        df = DataFrame(fips = ["01001"], year = [2020])
        @test_throws DataValidationError validate_columns(df, [:fips, :year, :income])
    end

    @testset "Validation — validate_payer_mix valid" begin
        pm = PayerMix(Dict(MEDICARE => 0.50, MEDICAID => 0.50))
        @test validate_payer_mix(pm) == true
    end

    @testset "Validation — validate_payer_mix invalid sum throws" begin
        pm = PayerMix(Dict(MEDICARE => 0.50, MEDICAID => 0.20))  # sum = 0.70
        @test_throws DataValidationError validate_payer_mix(pm)
    end

    @testset "Errors — hierarchy" begin
        @test DataValidationError("test") isa RuralHealthError
        @test DataValidationError("test") isa Exception
        @test StatisticalAssumptionError("test") isa RuralHealthError
        @test InsufficientSampleError("test") isa RuralHealthError
        @test ConvergenceError("test") isa RuralHealthError
        @test FormulaParseError("test") isa RuralHealthError
        @test ConfigurationError("key", "test") isa RuralHealthError
    end

    @testset "Errors — showerror includes message" begin
        e = DataValidationError("bad FIPS code")
        s = sprint(showerror, e)
        @test occursin("bad FIPS code", s)
        @test occursin("DataValidationError", s)
    end

    @testset "AuditLog — clear and empty" begin
        clear_audit_log()
        @test isempty(get_audit_log())
    end

    @testset "AuditLog — @audited_calculation records entry" begin
        clear_audit_log()
        _ = @audited_calculation validate_fips("01001")
        log = get_audit_log()
        @test length(log) == 1
        @test log[1].function_name == "validate_fips"
    end

    @testset "AuditLog — multiple entries accumulate" begin
        clear_audit_log()
        _ = @audited_calculation validate_fips("01001")
        _ = @audited_calculation validate_fips("02001")
        @test length(get_audit_log()) == 2
    end

    @testset "AuditLog — save_audit_log writes CSV" begin
        clear_audit_log()
        _ = @audited_calculation validate_fips("01001")
        tmp = tempname() * ".csv"
        save_audit_log(tmp)
        @test isfile(tmp)
        content = read(tmp, String)
        @test occursin("validate_fips", content)
        rm(tmp)
    end

    @testset "PlatformConfig — default port assignments" begin
        @test DEFAULT_CONFIG.portal_port == 8080
        @test DEFAULT_CONFIG.biostatistics_port == 8081
        @test DEFAULT_CONFIG.finance_port == 8082
        @test DEFAULT_CONFIG.quality_port == 8083
        @test DEFAULT_CONFIG.geospatial_port == 8084
    end

    @testset "PlatformConfig — log level and data dir" begin
        @test DEFAULT_CONFIG.log_level == :info
        @test isa(DEFAULT_CONFIG.data_dir, String)
    end

    # Phase 1 audit infrastructure tests
    include("audit_tests.jl")

    # ── Bug Reporting ────────────────────────────────────────────────────────

    @testset "BugReportSeverity — labels" begin
        @test severity_label(SEVERITY_CRITICAL) == "Critical"
        @test severity_label(SEVERITY_HIGH)     == "High"
        @test severity_label(SEVERITY_MEDIUM)   == "Medium"
        @test severity_label(SEVERITY_LOW)      == "Low"
    end

    @testset "BugReportSeverity — github labels" begin
        @test severity_github_label(SEVERITY_CRITICAL) == "severity: critical"
        @test severity_github_label(SEVERITY_LOW)      == "severity: low"
    end

    @testset "BugReportCategory — labels" begin
        @test category_label(CATEGORY_CALCULATION)   == "Calculation Error"
        @test category_label(CATEGORY_DATA)          == "Data Issue"
        @test category_label(CATEGORY_UI_UX)         == "UI/UX"
        @test category_label(CATEGORY_PERFORMANCE)   == "Performance"
        @test category_label(CATEGORY_DOCUMENTATION) == "Documentation"
        @test category_label(CATEGORY_OTHER)         == "Other"
    end

    @testset "BugReportCategory — github labels" begin
        @test category_github_label(CATEGORY_CALCULATION) == "calculation"
        @test category_github_label(CATEGORY_UI_UX)       == "ui/ux"
        @test category_github_label(CATEGORY_OTHER)       == "other"
    end

    @testset "BugReport — construction with required fields" begin
        r = BugReport(title="NPV is wrong", description="Returns NaN for negative cash flows")
        @test r.title       == "NPV is wrong"
        @test r.description == "Returns NaN for negative cash flows"
        @test r.severity    == SEVERITY_MEDIUM
        @test r.category    == CATEGORY_OTHER
        @test r.app_name    == "portal"
        @test !isempty(string(r.id))
    end

    @testset "BugReport — construction with all fields" begin
        r = BugReport(
            title              = "Chart broken",
            description        = "I-MR chart shows no control limits",
            steps_to_reproduce = "1. Open Quality app\n2. Run I-MR chart",
            expected_behavior  = "Control limits appear",
            actual_behavior    = "Only centre line visible",
            severity           = SEVERITY_HIGH,
            category           = CATEGORY_CALCULATION,
            app_name           = "Quality",
            app_version        = "0.4.0",
            contact_email      = "user@example.com",
            session_id         = "abc123",
            browser_info       = "Mozilla/5.0",
            platform_url       = "http://localhost:8083",
        )
        @test r.severity          == SEVERITY_HIGH
        @test r.category          == CATEGORY_CALCULATION
        @test r.app_name          == "Quality"
        @test r.steps_to_reproduce == "1. Open Quality app\n2. Run I-MR chart"
        @test r.contact_email     == "user@example.com"
    end

    @testset "BugReport — show method" begin
        r = BugReport(title="Test bug", description="desc")
        s = sprint(show, r)
        @test occursin("BugReport", s)
        @test occursin("Test bug", s)
        @test occursin("Medium", s)
    end

    @testset "format_github_issue_title — severity prefix" begin
        r = BugReport(title="Broken chart", description="desc", severity=SEVERITY_HIGH, category=CATEGORY_CALCULATION)
        t = format_github_issue_title(r)
        @test startswith(t, "[High] [Calculation Error]")
        @test occursin("Broken chart", t)
    end

    @testset "format_github_issue_body — required sections present" begin
        r = BugReport(
            title       = "Test bug",
            description = "Something went wrong",
            severity    = SEVERITY_MEDIUM,
            category    = CATEGORY_DATA,
            app_name    = "Finance",
        )
        body = format_github_issue_body(r)
        @test occursin("## Bug Report", body)
        @test occursin("Something went wrong", body)
        @test occursin("Finance", body)
        @test occursin("Medium", body)
        @test occursin("Data Issue", body)
        @test occursin("System Information", body)
    end

    @testset "format_github_issue_body — optional sections included when present" begin
        r = BugReport(
            title              = "Test",
            description        = "desc",
            steps_to_reproduce = "Step 1\nStep 2",
            expected_behavior  = "Should work",
            actual_behavior    = "Does not work",
            session_id         = "sess-xyz",
        )
        body = format_github_issue_body(r)
        @test occursin("Steps to Reproduce", body)
        @test occursin("Step 1", body)
        @test occursin("Expected Behavior", body)
        @test occursin("Actual Behavior", body)
        @test occursin("sess-xyz", body)
    end

    @testset "format_github_issue_body — contact email not in body" begin
        r = BugReport(
            title         = "Test",
            description   = "desc",
            contact_email = "private@example.com",
        )
        body = format_github_issue_body(r)
        # Contact email must NOT appear in the GitHub issue body (privacy)
        @test !occursin("private@example.com", body)
    end

    @testset "github_issue_labels — always includes 'bug'" begin
        r = BugReport(title="T", description="d", severity=SEVERITY_LOW, category=CATEGORY_UI_UX)
        labels = github_issue_labels(r)
        @test "bug" in labels
        @test "severity: low" in labels
        @test "ui/ux" in labels
        @test length(labels) == 3
    end
end

include("aqua_tests.jl")
include("jet_tests.jl")
