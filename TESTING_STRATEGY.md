# Testing Strategy: Healthcare Economics Research Platform

**Comprehensive testing framework including unit, integration, end-to-end, performance, and security testing for HIPAA compliance**

---

## Executive Summary

Testing is the primary mechanism for ensuring quality, accuracy, and HIPAA compliance in the Healthcare Economics Research Platform. This document defines:

- **Testing Pyramid** — Distribution of test types (80% unit, 15% integration, 5% e2e/performance)
- **Coverage Targets** — ≥80% code coverage, ≥75% requirement coverage
- **Test Scenarios** — Detailed test cases organized by module and capability
- **Security Testing** — HIPAA-specific security test scenarios
- **Performance Testing** — Load testing, concurrency, database optimization
- **UAT Process** — User acceptance testing procedures and sign-off
- **CI/CD Integration** — Automated testing in GitHub Actions

---

## Testing Pyramid

```
                          ▲
                         ╱│╲
                        ╱ │ ╲
                       ╱  │  ╲
                      ╱ E2E ╲  ╲  Manual Testing (5%)
                     ╱   (5%)   ╲  Performance, Security,
                    ╱─────────────╲ User Acceptance
                   ╱               ╲
                  ╱                 ╲
                 ╱  Integration Tests ╲  (15%)
                ╱   API, Database,    ╲ Multi-module
               ╱     Module Interaction╲ workflows
              ╱───────────────────────────╲
             ╱                             ╲
            ╱                               ╲
           ╱        Unit Tests (80%)        ╲
          ╱  Fast, Isolated, Function-level ╲
         ╱     ≥80% Code Coverage Target      ╱
        ╱___________________________________╱
```

**Rationale:**
- **Unit Tests (80%)**: Fast feedback, catch bugs early, isolated testing
- **Integration Tests (15%)**: Verify module interactions, database integration, API contracts
- **E2E & Manual (5%)**: User workflows, performance validation, security edge cases

---

## Test Coverage Targets

### By Module

| Module | Unit | Integration | E2E | Total Coverage | Target |
|--------|------|-------------|-----|----------------|--------|
| Module 1: Data Ingestion | 85% | 6 tests | 3 workflows | **80-85%** | ≥80% |
| Module 2: Cohort Building | 82% | 5 tests | 2 workflows | **78-82%** | ≥80% |
| Module 3: Cost Analysis | 80% | 5 tests | 2 workflows | **75-80%** | ≥80% |
| **Overall** | **82%** | **16 tests** | **7 workflows** | **78-82%** | **≥80%** |

### By Feature Type

| Feature Type | Unit | Integration | Notes |
|--------------|------|-------------|-------|
| Business Logic | 90%+ | 5+ | High criticality, needs thorough testing |
| Data Validation | 95%+ | 5+ | Edge cases critical (malformed input, null, etc.) |
| API Endpoints | 85%+ | 5+ | Error handling, HTTP status codes, serialization |
| Database Queries | 80%+ | 10+ | Performance, correctness, edge cases |
| Calculations | 95%+ | 5+ | Financial accuracy critical, round-trip validation |
| Security/Encryption | 90%+ | 5+ | HIPAA controls must be tested |
| Utilities/Helpers | 75%+ | 0-2 | Lower criticality, brief functions |

---

## Unit Testing

### Test Framework

**Framework:** Julia Test.jl (built-in)

**Structure:**
```
test/
├── unit/
│   ├── ingestion/
│   │   ├── test_validation.jl
│   │   ├── test_csv_ingestion.jl
│   │   └── test_audit_logging.jl
│   ├── cohort/
│   │   ├── test_criteria.jl
│   │   └── test_cohort_builder.jl
│   ├── analytics/
│   │   ├── test_cost_calculations.jl
│   │   ├── test_inflation.jl
│   │   └── test_benchmarking.jl
│   └── utilities/
│       ├── test_encryption.jl
│       └── test_de_identification.jl
├── integration/
│   ├── test_ingestion_to_cohort.jl
│   ├── test_cohort_to_cost.jl
│   └── test_data_flow.jl
└── runtests.jl (main test runner)
```

### Unit Test Example (Module 1: Data Validation)

```julia
# test/unit/ingestion/test_validation.jl
using Test
using HealthcareEconomics

@testset "ICD10 Code Validation" begin
    # Valid codes
    @test validate_icd10_code("E11.9") == true
    @test validate_icd10_code("J44.0") == true
    @test validate_icd10_code("I10") == true
    
    # Invalid codes
    @test validate_icd10_code("E11.999") == false
    @test validate_icd10_code("XYZ123") == false
    @test validate_icd10_code("") == false
    
    # Edge cases
    @test validate_icd10_code(nothing) == false
    @test_throws ErrorException validate_icd10_code(123)  # Type checking
end

@testset "CPT Code Validation" begin
    # Valid CPT codes
    @test validate_cpt_code("99213") == true
    @test validate_cpt_code("27447") == true
    
    # Invalid
    @test validate_cpt_code("99999") == false
    @test validate_cpt_code("ABC") == false
end

@testset "Date Range Validation" begin
    # Valid date ranges
    date_from = Date(2024, 1, 1)
    date_to = Date(2024, 12, 31)
    @test validate_date_range(date_from, date_to) == true
    
    # Invalid: end before start
    @test validate_date_range(date_to, date_from) == false
    
    # Invalid: dates too far apart (>5 years)
    @test validate_date_range(Date(2019, 1, 1), Date(2024, 12, 31)) == false
end

@testset "Numeric Field Validation" begin
    # Cost fields
    @test validate_cost(1000.00) == true
    @test validate_cost(0.00) == true
    @test validate_cost(-100.00) == false
    @test validate_cost(999_999_999.99) == true  # Large valid cost
    
    # Age fields
    @test validate_age(0) == true
    @test validate_age(45) == true
    @test validate_age(120) == true
    @test validate_age(121) == false
    @test validate_age(-1) == false
end
```

### Unit Test Coverage Execution

**Frequency:** Every commit (via pre-commit hook)  
**Target:** ≥80% line coverage, ≥75% branch coverage

```bash
# Run all unit tests with coverage
julia --project test/runtests.jl

# Output example:
# ✓ ICD10 Code Validation: 15 tests passed
# ✓ CPT Code Validation: 8 tests passed
# ✓ Date Range Validation: 5 tests passed
# ...
# Coverage: 82% (5,432 lines / 6,620 total)
# Status: PASS
```

---

## Integration Testing

### Definition

Integration tests verify interactions between modules and systems:
- **Ingestion → Cohort:** Data loaded can be selected into cohorts
- **Cohort → Cost Analysis:** Cohorts can be analyzed for costs
- **API → Database:** Data persists and can be retrieved
- **Encryption → Audit Log:** Encrypted data is properly logged
- **External Services:** AWS, HSM, SIEM integration

### Module 1: Data Ingestion Integration Tests

| Test Case | Setup | Action | Expected Result | Owner |
|-----------|-------|--------|-----------------|-------|
| CSV Load + Validation | Empty DB | Ingest 100 patients (CSV) | Patients stored, audit logs created | Dev1 |
| Duplicate Detection | 50 patients in DB | Ingest same 50 patients again | Duplicates rejected, error logged | Dev1 |
| Encoding Handling | - | Ingest file with special characters | Data correctly normalized | Dev1 |
| Rollback on Failure | 50 patients in DB | Ingest 50 new (1 invalid in middle) | Transaction rolls back, DB unchanged | Dev1 |
| Encryption Verification | - | Ingest sensitive data | Encrypted columns verified as encrypted | Dev1 |
| Audit Trail Creation | - | Ingest 10 records | 10 audit entries created, immutable | Dev1 |

### Module 2: Cohort Building Integration Tests

| Test Case | Setup | Action | Expected Result | Owner |
|-----------|-------|--------|-----------------|-------|
| Filter by Age | 1000 patients, ages 20-80 | Create age 40-60 cohort | 400-600 patients selected | Dev2 |
| Filter by Diagnosis | Patients with various diagnoses | Filter on E11 (diabetes) | Correct patients selected | Dev2 |
| Filter by Cost | Patients with various costs | Cost >$50K filter | 20-30% of patients selected | Dev2 |
| Exclude Criteria | 1000 patients | Include age>50, exclude dialysis codes | Correct intersection | Dev2 |
| Cohort Size Validation | - | Create empty cohort (no matches) | Cohort not created, error returned | Dev2 |
| Data Lineage | Ingested 1000 → filtered to 300 → analyzed | Trace selection back to source | Lineage complete, audit trail | Dev2 |

### Module 3: Cost Analysis Integration Tests

| Test Case | Setup | Action | Expected Result | Owner |
|-----------|-------|--------|-----------------|-------|
| Cost Aggregation | 1000 encounters with claims | Calculate total cost for cohort | Sum matches manual calculation | Dev3 |
| Inflation Adjustment | Historical costs (2020) | Adjust to 2024 base year | Correct CPI applied, ±2% accuracy | Dev3 |
| Benchmarking | Cohort A vs. Regional average | Compare costs | Variance calculated, flagged if outlier | Dev3 |
| Multi-Payer Handling | Claims from 3 different payers | Combine costs correctly | All payers included, no duplicates | Dev3 |
| Write-Off Handling | Claims with write-offs | Include/exclude correctly | Financial accuracy ±5% | Dev3 |
| Performance (1M+ claims) | 1M encounter records | Calculate costs and benchmarks | Complete in <30 seconds | Dev3 |

### End-to-End Integration Test (Full Data Flow)

```julia
# test/integration/test_data_flow.jl
@testset "Full Data Pipeline" begin
    # Step 1: Ingest data
    ingest_result = ingest_csv("test_data/patients.csv")
    @test ingest_result.success == true
    @test ingest_result.records_loaded == 1000
    
    # Step 2: Verify in database
    patient_count = query_patients()
    @test patient_count == 1000
    
    # Step 3: Build cohort
    cohort = build_cohort([
        AgeRangeCriterion(40, 65),
        DiagnosisCriterion("E11.9")
    ])
    @test cohort.size >= 100
    
    # Step 4: Analyze costs
    analysis = analyze_costs(cohort)
    @test analysis.total_cost > 0
    @test analysis.average_cost_per_patient > 0
    @test analysis.encounters_analyzed == length(cohort)
    
    # Step 5: Verify audit trail
    audit_logs = query_audit_logs()
    @test has_log_entry(audit_logs, :INGESTION_COMPLETE)
    @test has_log_entry(audit_logs, :COHORT_BUILT)
    @test has_log_entry(audit_logs, :ANALYSIS_COMPLETE)
end
```

---

## End-to-End Testing

### User Workflows (Functional E2E)

**Workflow 1: Basic Cost Analysis**
```
As a Health Economist:
1. Log in with MFA
2. Ingest 1000 patient CSV
3. Build cohort: age 40-65, diabetes diagnosis
4. Analyze costs for cohort
5. Export results to Excel
6. Verify results match manually calculated benchmark

Expected: Workflow completes in <5 minutes, results accurate ±5%
```

**Workflow 2: Cohort Comparison**
```
As a Researcher:
1. Log in
2. Create Cohort A: heart disease patients, cost >$50K
3. Create Cohort B: control group (similar age, no disease)
4. Compare cost distributions (mean, median, percentiles)
5. Generate comparison report
6. Share with team

Expected: Comparison chart generated, statistical tests run correctly
```

**Workflow 3: Benchmarking**
```
As an Administrator:
1. Log in as ADMIN role
2. Load reference benchmarking data (regional/national)
3. Build hospital cohort
4. Compare to benchmarks by major diagnostic category
5. Generate variance analysis report
6. Schedule for monthly automation

Expected: Benchmarking accuracy ±3%, report automated monthly
```

### Test Execution

**E2E Test Schedule:**
- **Daily:** Smoke test (basic login, data load, cost calculation)
- **Weekly:** Full workflow tests (after each release)
- **Pre-UAT:** All workflows tested with real data sample

---

## Performance Testing

### Performance Targets

| Metric | Target | Test Scenario |
|--------|--------|--------------|
| API Response Time (p95) | <500ms | 1000 concurrent users |
| CSV Ingestion Rate | 10K records/min | Bulk import of 100K records |
| Cohort Building | <10 seconds | Select from 1M encounters |
| Cost Analysis | <30 seconds | 10K patients, 1M+ claims |
| Database Query (p95) | <5 seconds | Complex cost aggregation |
| Report Generation | <2 min | Full hospital report, 10K patients |
| Memory Usage | <2GB | Normal operations |
| CPU Usage | <80% | Peak load (1000 concurrent users) |

### Load Testing Plan

**Tool:** Julia `BenchmarkTools.jl` + custom load scripts

**Scenario 1: Data Ingestion Stress Test**
```julia
# test/performance/test_ingestion_load.jl
using BenchmarkTools

@testset "Data Ingestion Performance" begin
    # Test: Ingest 100K records
    @time result = ingest_csv("test_data/100k_patients.csv")
    
    # Expected: <600 seconds (10K records/minute = 100K in 10 min)
    @test result.records_loaded == 100_000
    @test result.seconds_elapsed < 600
    
    # Test: Concurrent ingestions (2 simultaneous)
    t1 = @async ingest_csv("test_data/batch1.csv")
    t2 = @async ingest_csv("test_data/batch2.csv")
    
    # Verify both complete without corruption
    @test fetch(t1).success == true
    @test fetch(t2).success == true
end
```

**Scenario 2: Query Performance Under Load**
```julia
# Simulate 1000 concurrent cost analysis queries
using Distributed

@testset "Cost Analysis Query Performance" begin
    # Single query baseline
    single_time = @time analyze_costs(cohort)
    @test single_time < 30  # seconds
    
    # 10 concurrent queries
    results = pmap(1:10) do i
        @time analyze_costs(cohort)
    end
    
    # All should complete within 2x single time (with some contention)
    max_time = maximum(r.elapsed for r in results)
    @test max_time < 60  # seconds
end
```

**Scenario 3: Database Scaling Test**
```julia
# Test query performance as data volume increases
@testset "Database Performance Scaling" begin
    for record_count in [10_000, 100_000, 1_000_000]
        # Load data
        load_test_data(record_count)
        
        # Time complex query
        query_time = @time query_costs_by_diagnosis()
        
        # Verify index usage and performance
        @test query_time < 5 * seconds  # Should stay <5s even at 1M records
        
        # Cleanup
        cleanup_test_data()
    end
end
```

### Concurrency Testing

**Load Profile:**
- **Normal:** 100 concurrent users (peak office hours)
- **High Load:** 500 concurrent users (end-of-day reporting)
- **Stress:** 1000 concurrent users (what-if scenario)

**Test Metrics:**
- Response time distribution (p50, p95, p99)
- Error rate (target: <0.1%)
- Resource utilization (CPU, memory, database connections)
- Throughput (requests/second)

---

## Security Testing

### HIPAA Security Test Scenarios

#### 1. Authentication & Authorization

**Test Case 1.1: MFA Enforcement**
```
Given: User account with valid credentials but no MFA enabled
When: User attempts to log in
Then: Login denied, MFA setup required

Test Steps:
1. Create test user (no MFA)
2. Attempt login with password
3. Verify MFA challenge presented
4. Verify login denied without MFA
5. Setup TOTP MFA
6. Re-attempt login with MFA code
7. Verify login successful
```

**Test Case 1.2: Session Timeout**
```
Given: Active user session
When: Session idle for 30 minutes
Then: Session terminated, re-authentication required

Test Steps:
1. Login successfully
2. Verify session token issued
3. Wait 30 minutes (or simulate)
4. Attempt API call with old token
5. Verify 401 Unauthorized response
6. Verify forced re-login
```

**Test Case 1.3: Role-Based Access Control (RBAC)**
```
Given: Three user roles (Researcher, Admin, Auditor)
When: Each role attempts various operations
Then: Only authorized operations succeed

Test Steps:
For each role:
1. Login as role
2. Attempt to view all patient records (only Auditor allowed)
3. Attempt to delete user (only Admin allowed)
4. Attempt to export data (Researcher allowed)
5. Verify permissions enforced correctly
```

#### 2. Data Protection & Encryption

**Test Case 2.1: Encryption at Rest**
```
Given: Patient data stored in PostgreSQL
When: Database files are accessed directly (without app)
Then: Data is encrypted and unreadable

Test Steps:
1. Insert patient record with sensitive data
2. Verify column encryption (AES-256-GCM)
3. Query database files directly
4. Verify data appears as ciphertext
5. Verify only application can decrypt (HSM key required)
```

**Test Case 2.2: TLS Enforcement**
```
Given: Client attempting to connect to API
When: Client attempts unencrypted HTTP connection
Then: Connection rejected, HTTPS required

Test Steps:
1. Attempt HTTP connection (port 80)
2. Verify connection refused or redirected
3. Attempt HTTPS connection (port 443)
4. Verify TLS 1.3 handshake
5. Verify certificate valid
6. Verify no downgrade to TLS 1.2
```

#### 3. Audit Logging & Integrity

**Test Case 3.1: Audit Log Completeness**
```
Given: User performs various operations
When: Operations include PHI access and modifications
Then: All operations logged with complete details

Test Steps:
1. Query patient record (PHI_ACCESS logged)
2. Modify patient demographic (PHI_MODIFICATION logged)
3. Export cohort data (DATA_EXPORT logged)
4. Verify audit table entries created
5. Verify each entry includes:
   - user_id
   - timestamp
   - event_type
   - resource_id
   - ip_address
   - purpose_code
```

**Test Case 3.2: Audit Log Immutability**
```
Given: Audit log entries in database
When: Attempted modification or deletion
Then: Operation fails, logs unchanged

Test Steps:
1. Create audit log entry
2. Attempt UPDATE on audit table
3. Verify UPDATE blocked (trigger prevents)
4. Attempt DELETE on audit table
5. Verify DELETE blocked (trigger prevents)
6. Verify log integrity verified monthly
```

#### 4. De-identification & Privacy

**Test Case 4.1: HIPAA Safe Harbor Validation**
```
Given: Dataset marked as "de-identified"
When: Validation function executed
Then: 18 identifiers removed per Safe Harbor rule

Test Steps:
1. Create test dataset with PHI:
   - Name, SSN, DOB, medical record #, etc.
2. Apply de-identification function
3. Verify 18 identifiers removed:
   - Direct: name, SSN, DOB, MRN, etc.
   - Indirect: age >89 → ≥90, exact dates → year only
4. Run validation test
5. Verify PASS result
6. Verify re-identification impossible
```

**Test Case 4.2: Expert Determination Review**
```
Given: De-identified dataset with unusual characteristics
When: Expert review requested
Then: Statistical analysis verifies re-identification risk <0.05%

Test Steps:
1. Run re-identification risk analysis
2. Calculate uniqueness risk (risk of matching records)
3. Verify risk score < 0.05% (< 1 in 2000)
4. Generate expert review report
5. Obtain review sign-off
6. Mark dataset approved
```

### Security Test Execution

**Frequency:**
- **Weekly:** MFA, RBAC, encryption basics (automated)
- **Monthly:** Full security regression suite
- **Pre-UAT & Pre-Go-Live:** Full security audit
- **Quarterly:** Penetration testing by external firm

**Tools:**
- Static Analysis: SonarQube or Checkmarx (SAST)
- Dependency Scanning: GitHub dependabot
- OWASP ZAP for web application scanning
- Manual penetration testing (external firm)

---

## UAT (User Acceptance Testing)

### UAT Phases

**Phase 1: UAT Environment Setup** (Week 1)
- Deploy production-like infrastructure
- Load anonymized test data (1000 patients)
- Configure all monitoring and logging
- Test backup/recovery

**Phase 2: UAT Test Execution** (Weeks 2-3)
- Run all UAT test scenarios (see below)
- Document issues and resolutions
- Verify fixes in testing cycle
- Gather user feedback

**Phase 3: UAT Sign-Off** (Week 4)
- Final round of testing
- Business user validation
- Executive approval
- Go/no-go decision

### UAT Test Scenarios

**UAT-1: Data Ingestion & Validation**
```
Objective: Users can successfully load patient data
Participants: Health Economist + Data Manager

Test Steps:
1. Prepare sample CSV file (100 patient records)
2. Log in as Health Economist
3. Navigate to Data Import screen
4. Upload CSV file
5. Verify validation results (X records valid, Y warnings)
6. Review and approve import
7. Verify records appear in database
8. Query sample patient records
9. Verify data accuracy (spot check 5 records)
10. Check audit logs for import activity

Success Criteria:
✓ Import completes in <2 minutes
✓ Data visible in system within 30 seconds
✓ Audit logs show import events
✓ Data accuracy 100%
```

**UAT-2: Cohort Building**
```
Objective: Users can build patient cohorts with filters
Participants: Researcher + Health Economist

Test Steps:
1. Log in as Researcher
2. Navigate to Cohort Builder
3. Create cohort with filters:
   - Age: 40-65
   - Diagnosis: Type 2 Diabetes (E11)
   - Cost: >$50,000
4. Review cohort size (expected: ~100-200 patients)
5. Preview sample patients
6. Save cohort with name "Diabetes Cost Analysis"
7. Verify cohort appears in list
8. Re-open cohort and verify filters intact
9. Share cohort with colleague
10. Colleague verifies access

Success Criteria:
✓ Cohort created in <1 minute
✓ Filters apply correctly
✓ Cohort size within expected range
✓ Sharing works, colleague can access
✓ Filters persist on re-open
```

**UAT-3: Cost Analysis & Reporting**
```
Objective: Users can analyze costs and generate reports
Participants: Health Economist + Financial Analyst

Test Steps:
1. Log in as Health Economist
2. Open saved cohort ("Diabetes Cost Analysis")
3. Select "Analyze Costs"
4. Wait for analysis to complete
5. View results:
   - Total cost
   - Average cost per patient
   - Cost distribution (histogram)
   - By cost component (labor, supplies, etc.)
6. Compare to regional benchmark
7. Export results to Excel
8. Open Excel file and verify data
9. Generate comparison report
10. Verify report formatting and accuracy

Success Criteria:
✓ Analysis completes in <30 seconds
✓ Results display correctly
✓ Export to Excel succeeds
✓ Report formatting is professional
✓ Numbers match manual spot-check (±1%)
```

**UAT-4: Security & Access Control**
```
Objective: HIPAA controls function correctly
Participants: IT Admin + Security Officer

Test Steps:
1. Attempt login without MFA
   → Should fail
2. Login with MFA
   → Should succeed
3. Verify session timeout after 30 min
   → Should require re-login
4. Attempt PHI data access
   → Should be logged in audit trail
5. Query audit logs
   → Should show access event
6. Attempt to modify audit log
   → Should fail
7. Logout
   → Should clear session
8. Attempt API call with old token
   → Should fail with 401

Success Criteria:
✓ MFA enforced
✓ Session timeout works
✓ Audit logging captures all PHI access
✓ Audit logs immutable
✓ Logout clears session
```

**UAT-5: User Training & Documentation**
```
Objective: Users understand how to use the system
Participants: All users, trainer

Test Steps:
1. Conduct 30-min system overview training
2. Each user completes hands-on exercises:
   - Login with MFA
   - Ingest sample data
   - Build a cohort
   - Run cost analysis
   - Export report
3. Users complete knowledge assessment (80% required)
4. Collect feedback on training effectiveness
5. Identify any usability issues
6. Document workarounds if needed

Success Criteria:
✓ 100% of users achieve 80%+ on assessment
✓ Users can complete basic workflows independently
✓ Feedback identifies <3 major usability issues
✓ All issues prioritized for Phase 2
```

### UAT Issues & Resolution

**Issue Tracking During UAT:**

| Issue ID | Severity | Description | Status | Resolution Date |
|----------|----------|-------------|--------|-----------------|
| UAT-001 | HIGH | Export to Excel fails on >5K records | Fixed | Day 3 |
| UAT-002 | MEDIUM | Cohort filtering slow (>30s for 1M records) | Deferred to Phase 2 | - |
| UAT-003 | LOW | Tooltip text formatting issue | Fixed | Day 5 |

**Resolution Criteria:**
- **Critical:** Must resolve before go-live
- **High:** Should resolve before go-live (negotiable)
- **Medium:** Can defer to Phase 2 (document trade-off)
- **Low:** Can defer to Phase 2 + patch

### UAT Sign-Off Checklist

**Stakeholder Approval:**
- [ ] Product Manager: Scope complete, requirements met
- [ ] Tech Lead: Quality acceptable, performance targets met
- [ ] QA Lead: Test coverage adequate, no critical bugs
- [ ] Security Officer: HIPAA controls verified, audit logs intact
- [ ] CFO: Budget tracking okay, no cost overruns
- [ ] Chief Medical Officer: Clinical workflows validated
- [ ] IT Director: Infrastructure ready for production

**Go-Live Decision:**
```
Given: All checklist items approved
Then: Proceed to production deployment
Otherwise: Extend UAT, resolve issues, retry
```

---

## CI/CD Integration

### GitHub Actions Workflow

**File:** `.github/workflows/test.yml`

```yaml
name: Test & Quality Gates

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Julia
        uses: julia-actions/setup-julia@v1
        with:
          version: '1.10'
      
      - name: Install dependencies
        run: julia --project -e 'using Pkg; Pkg.instantiate()'
      
      - name: Run unit tests
        run: julia --project test/runtests.jl
      
      - name: Generate coverage report
        run: julia --project -e 'using Pkg; Pkg.test("HealthcareEconomics", coverage=true)'
      
      - name: Check code coverage
        run: |
          coverage=$(julia --project -e 'coverage' 2>/dev/null)
          if [ $(echo "$coverage < 80" | bc) -eq 1 ]; then
            echo "Coverage $coverage% below 80% target"
            exit 1
          fi
      
      - name: Run static analysis (SAST)
        run: |
          # SonarQube scan (configured separately)
          # Check for security issues
          echo "Running SAST..."
      
      - name: Lint code
        run: julia --project -e 'using Aqua; Aqua.test(MyProject)'
      
      - name: Integration tests
        run: julia --project test/integration/runtests.jl
      
      - name: Performance tests
        run: julia --project test/performance/runtests.jl
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Trivy container scan
        run: |
          docker run -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy image --severity HIGH,CRITICAL healthcare-economics:latest
      
      - name: Check dependencies
        run: |
          # Check for known vulnerabilities in Julia packages
          julia --project -e 'using Pkg; Pkg.audit()'
```

### Quality Gates (Merge Requirements)

**Requirement for merge to main:**
1. ✅ All unit tests pass
2. ✅ Code coverage ≥80%
3. ✅ No critical security issues
4. ✅ Code review approved (2 reviewers)
5. ✅ No merge conflicts
6. ✅ Integration tests pass
7. ✅ Performance tests meet targets

**Requirement for merge to develop:**
1. ✅ All unit tests pass
2. ✅ Code coverage ≥75%
3. ✅ Code review approved (1 reviewer)

---

## Test Data Management

### Test Data Principles

**Privacy & Security:**
- All test data must be de-identified (HIPAA Safe Harbor)
- Never use real patient data in development
- Test data encrypted same as production
- Test data isolated from production environment

**Realism:**
- Test data distributions match real data
- Edge cases represented (age 100+, extreme costs, etc.)
- Multiple encounter types, diagnoses, payers represented
- Realistic time distributions (more recent data than historical)

### Test Data Sets

**Small Dataset (100 records):**
- Use case: Unit testing, quick validation
- Size: ~1 MB
- Setup time: <1 second
- Location: `/test/data/small_100_patients.csv`

**Medium Dataset (10K records):**
- Use case: Integration testing, performance baseline
- Size: ~100 MB
- Setup time: ~10 seconds
- Location: `/test/data/medium_10k_patients.csv`

**Large Dataset (1M records):**
- Use case: Performance testing, load testing
- Size: ~10 GB (compressed)
- Setup time: ~5-10 minutes
- Location: AWS S3 (not in repo)

### Test Data Refresh

**Refresh Schedule:**
- **Weekly:** Small dataset regenerated (ensures no stale references)
- **Monthly:** Medium dataset refreshed (new synthetic data)
- **Quarterly:** Large dataset updated (new edge cases)

---

## Regression Testing

### Regression Test Suites

**Suite 1: Critical Functionality** (15 min, runs every commit)
- Login/authentication
- Data ingestion
- Cohort building
- Cost calculation
- Audit logging

**Suite 2: Module Integration** (30 min, runs pre-release)
- Module 1 → Module 2 workflow
- Module 2 → Module 3 workflow
- Database consistency checks
- Audit trail completeness

**Suite 3: Security & Compliance** (45 min, runs weekly)
- MFA enforcement
- RBAC validation
- Encryption verification
- Audit log immutability
- De-identification validation

**Suite 4: Performance** (60 min, runs pre-release)
- Ingestion throughput
- Query performance
- Concurrent users (100+)
- Memory usage stability

---

## Test Metrics & Reporting

### Weekly Metrics Report

```
WEEKLY TEST REPORT - Week of April 21, 2026

Test Execution Summary:
- Total Tests Run: 1,245
- Tests Passed: 1,243 (99.8%)
- Tests Failed: 2 (0.2%)
- Tests Skipped: 0

Coverage Metrics:
- Unit Test Coverage: 82%
- Integration Coverage: 16 test scenarios
- E2E Coverage: 7 workflows
- Target: ≥80% → PASS ✓

Quality Metrics:
- Critical Bugs Found: 0
- High Bugs Found: 1 (known, in backlog)
- Medium Bugs Found: 3
- Low Bugs Found: 5
- Bug Escape Rate: 0.1%

Performance Metrics:
- API Response Time (p95): 380ms (target: <500ms) → PASS ✓
- Ingestion Throughput: 9.8K records/min (target: >10K) → NEAR MISS
- Query Performance (p95): 3.2s (target: <5s) → PASS ✓

Defect Resolution:
- Defects Opened This Week: 5
- Defects Closed This Week: 4
- Average Resolution Time: 24 hours

CI/CD Pipeline Health:
- Build Success Rate: 98.5%
- Deployment Frequency: 5 deployments
- Mean Time to Recovery: 15 minutes (when issues occur)

Recommendation:
✓ Quality acceptable for development phase
⚠ Performance near threshold - monitor ingestion throughput
✓ No blockers to Phase 2 planning
```

---

## Testing Checklist (Pre-Go-Live)

**72 Hours Before Go-Live:**

**Code Quality:**
- [ ] All unit tests passing (100%)
- [ ] Code coverage ≥80%
- [ ] Zero critical/high security issues
- [ ] Code review completed on all recent changes
- [ ] Linting/style checks passing

**Integration:**
- [ ] All integration tests passing
- [ ] API contracts validated (OpenAPI spec matches code)
- [ ] Database migrations tested on staging
- [ ] External system integrations verified (SIEM, HSM, etc.)

**Performance:**
- [ ] Load test: 1000 concurrent users, <1% error
- [ ] Ingestion test: 10K records in <2 min
- [ ] Cost analysis: 10K patients in <30 sec
- [ ] Report generation: <2 minutes for full hospital

**Security:**
- [ ] MFA enforcement verified
- [ ] RBAC permissions tested
- [ ] Encryption at rest verified
- [ ] TLS 1.3 enforcement verified
- [ ] Audit logging complete and immutable
- [ ] De-identification validated
- [ ] Penetration test findings resolved

**UAT:**
- [ ] All UAT test scenarios passed
- [ ] User acceptance obtained
- [ ] Training completed
- [ ] Documentation finalized
- [ ] Known issues documented (with workarounds)

**Operations:**
- [ ] Backup/recovery tested
- [ ] Monitoring alerts configured
- [ ] On-call rotation scheduled
- [ ] Incident response plan validated
- [ ] Runbooks reviewed and approved
- [ ] Team trained on deployment procedures

**Sign-Off:**
- [ ] Product Manager approval
- [ ] Tech Lead approval
- [ ] QA Lead approval
- [ ] Security Officer approval
- [ ] Operations Manager approval
- [ ] Executive Sponsor approval

---

## Document References

- **IMPLEMENTATION_GUIDE.md** — Module specifications and testing examples
- **SECURITY_ARCHITECTURE.md** — HIPAA controls and security design
- **DATA_DICTIONARY.md** — Database schema for test data validation
- **DEPLOYMENT_RUNBOOK.md** — Production deployment and rollback procedures
- **PROJECT_MANAGEMENT.md** — Testing timeline and milestones

---

**Testing Lead:** [Name]  
**QA Manager:** [Name]  
**Last Updated:** April 15, 2026  
**Next Review:** May 15, 2026

