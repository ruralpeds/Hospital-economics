# Healthcare Economics Platform - Implementation Guide
## Phase 1 MVP: Building the First Module

**Version:** 1.0
**Date:** April 15, 2026
**Target:** First production-ready module by Month 6

---

## Table of Contents

1. [Project Structure & Setup](#project-structure--setup)
2. [Module 1: Data Ingestion & Validation](#module-1-data-ingestion--validation)
3. [Module 2: Patient Cohort Building](#module-2-patient-cohort-building)
4. [Module 3: Cost Analysis Engine](#module-3-cost-analysis-engine)
5. [Development Workflow](#development-workflow)
6. [Testing & Quality Assurance](#testing--quality-assurance)
7. [Security Implementation](#security-implementation)
8. [Deployment Checklist](#deployment-checklist)

---

## Project Structure & Setup

### 1.1 Directory Structure

```
healthcare-economics/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                 # GitHub Actions CI/CD
│   │   ├── security-scan.yml      # Security scanning
│   │   └── deploy.yml             # Deployment pipeline
│   └── CODEOWNERS
├── .gitignore                      # Exclude .venv, secrets, build artifacts
├── Project.toml                    # Julia package metadata
├── Manifest.toml                   # Dependency lock file
├── .env.example                    # Environment variables template
├── docker/
│   ├── Dockerfile                 # Multi-stage production build
│   ├── Dockerfile.dev              # Development environment
│   └── docker-compose.yml          # Local development setup
├── k8s/
│   ├── base/                       # Kubernetes base configs
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── secret.yaml (encrypted)
│   │   ├── hpa.yaml               # Horizontal Pod Autoscaler
│   │   └── pdb.yaml               # Pod Disruption Budget
│   ├── overlays/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── helm/
│       └── Chart.yaml             # Helm deployment chart
├── src/
│   ├── HEcoSystem.jl              # Main package entry point
│   ├── config/
│   │   ├── Config.jl              # Configuration management
│   │   └── Secrets.jl             # Secret loading from Vault
│   ├── core/
│   │   ├── Types.jl               # Core data types
│   │   ├── Constants.jl           # Medical codes, constants
│   │   ├── Security.jl            # HIPAA auth & encryption
│   │   └── Logging.jl             # Audit logging
│   ├── ingestion/
│   │   ├── CSVIngestion.jl        # CSV data loading
│   │   ├── HL7Ingestion.jl        # HL7/FHIR support
│   │   ├── Validation.jl          # Data validation rules
│   │   └── Transformation.jl      # Data standardization
│   ├── cohort/
│   │   ├── CohortBuilder.jl       # Inclusion/exclusion logic
│   │   ├── Criteria.jl            # Criterion definitions
│   │   └── Filtering.jl           # Patient filtering
│   ├── analytics/
│   │   ├── CostAnalysis.jl        # Cost calculation functions
│   │   ├── QualityMetrics.jl      # Quality measures
│   │   ├── Statistics.jl          # Statistical tests
│   │   └── Regression.jl          # Regression models
│   ├── api/
│   │   ├── Server.jl              # Genie.jl server setup
│   │   ├── Routes.jl              # API endpoints
│   │   ├── Middleware.jl          # Auth, logging, error handling
│   │   └── OpenAPI.jl             # OpenAPI/Swagger generation
│   ├── database/
│   │   ├── Connection.jl          # PostgreSQL connection pool
│   │   ├── Queries.jl             # SQL query helpers
│   │   ├── Migrations.jl          # Schema migrations
│   │   └── Encryption.jl          # Data encryption/decryption
│   ├── utils/
│   │   ├── DateUtils.jl           # Date/time utilities
│   │   ├── CodingUtils.jl         # Medical code conversions
│   │   ├── Crypto.jl              # Encryption utilities
│   │   └── Formatting.jl          # Data formatting
│   └── cli/
│       └── CLI.jl                 # Command-line tools
├── test/
│   ├── runtests.jl                # Test entry point
│   ├── unit/
│   │   ├── test_types.jl
│   │   ├── test_validation.jl
│   │   ├── test_cohort.jl
│   │   ├── test_cost_analysis.jl
│   │   └── test_security.jl
│   ├── integration/
│   │   ├── test_database.jl
│   │   ├── test_ingestion.jl
│   │   ├── test_api.jl
│   │   └── test_end_to_end.jl
│   └── fixtures/
│       ├── sample_data.csv        # De-identified test data
│       ├── test_codes.jl          # Test medical codes
│       └── mock_responses.jl      # Mock API responses
├── docs/
│   ├── index.md                   # Main documentation
│   ├── api.md                     # API documentation
│   ├── architecture.md            # Architecture overview
│   ├── security.md                # Security & HIPAA guide
│   ├── contributing.md            # Development guidelines
│   └── make.jl                    # Documenter.jl build script
├── notebooks/
│   ├── 01_getting_started.jl      # Pluto notebook tutorial
│   ├── 02_data_exploration.jl
│   ├── 03_cohort_analysis.jl
│   └── 04_cost_effectiveness.jl
├── db/
│   ├── schema.sql                 # Database schema (initial)
│   ├── migrations/                # Migration files
│   │   ├── 001_create_tables.sql
│   │   ├── 002_create_indexes.sql
│   │   └── 003_add_audit_logs.sql
│   └── seeds/
│       ├── icd10_codes.sql        # Reference data
│       ├── cpt_codes.sql
│       └── hcc_risk_scores.sql
├── scripts/
│   ├── setup_dev.sh               # Local development setup
│   ├── setup_db.sh                # Database initialization
│   ├── run_tests.sh               # Test runner
│   ├── deploy.sh                  # Deployment script
│   └── backup.sh                  # Database backup
├── README.md                       # Project overview
├── CONTRIBUTING.md                # Contribution guidelines
├── LICENSE                         # Apache 2.0 or similar
└── .env.example                   # Environment template
```

### 1.2 Initial Setup

#### Step 1: Clone & Initialize
```bash
git clone https://github.com/your-org/healthcare-economics.git
cd healthcare-economics
cp .env.example .env
```

#### Step 2: Create Virtual Environment (Julia)
```bash
julia --version  # Verify Julia 1.10+

# Create new Julia environment
julia --project=.

# In Julia REPL:
] activate .
] add Genie, DataFrames, GLM, StatsModels, LibPQ, OpenSSL, JSON
] precompile
```

#### Step 3: Setup Environment Variables
```bash
# .env file - DO NOT COMMIT
DATABASE_URL=postgresql://user:password@localhost/healthcare_economics
VAULT_ADDR=http://localhost:8200
VAULT_TOKEN=<secret>
JWT_SECRET=<secret>
LOG_LEVEL=info
ENVIRONMENT=development
```

#### Step 4: Setup PostgreSQL Database
```bash
# Create database and user
createdb healthcare_economics
createuser healthcare_user -P

# Run migrations
julia scripts/setup_db.jl
```

#### Step 5: Configure IDE
- **VS Code:** Install Julia extension, configure for project
- **JetBrains:** Julia plugin configuration
- **Vim/Neovim:** LanguageServer.jl setup

#### Step 6: Pre-commit Hooks
```bash
# Install pre-commit hook for code quality
julia -e 'using Pkg; Pkg.add("JuliaFormatter")'

# Configure .git/hooks/pre-commit to run:
# julia -e 'using JuliaFormatter; format("src")'
```

---

## Module 1: Data Ingestion & Validation

### 2.1 Types Definition (`src/core/Types.jl`)

```julia
# Core data types for healthcare data
module Types

using Dates

# ============================================================================
# SECURITY & CONTEXT TYPES
# ============================================================================

struct SecurityContext
    user_id::String
    roles::Vector{String}
    permissions::Vector{String}
    mfa_verified::Bool
    session_start::DateTime
    ip_address::String
end

struct AuditLog
    id::UUID
    user_id::String
    timestamp::DateTime
    event_type::String  # PHI_ACCESS, DATA_INGESTION, ANALYSIS, etc.
    resource::String    # Table/record accessed
    action::String      # SELECT, INSERT, UPDATE, DELETE
    result::String      # SUCCESS, DENIED, ERROR
    ip_address::String
    purpose_code::String  # TREATMENT, PAYMENT, OPERATIONS, RESEARCH, etc.
end

# ============================================================================
# CLINICAL DATA TYPES
# ============================================================================

struct Patient
    patient_id::String              # De-identified internal ID
    birth_date::Date
    sex::String                     # M, F, O
    race::String                    # Race/ethnicity code
    ethnicity::String
    zip_code::String               # First 3 digits only (HIPAA)
    primary_language::String
    created_at::DateTime
    updated_at::DateTime
end

struct Encounter
    encounter_id::String
    patient_id::String
    encounter_date::Date
    encounter_type::String          # INPATIENT, OUTPATIENT, ED, etc.
    facility_id::String
    primary_diagnosis_code::String  # ICD-10
    secondary_diagnoses::Vector{String}
    procedures::Vector{String}      # CPT codes
    admit_source::String
    discharge_status::String
    length_of_stay::Int
    created_at::DateTime
end

struct Diagnosis
    diagnosis_id::String
    patient_id::String
    encounter_id::String
    code::String                    # ICD-10 code
    description::String
    sequence::Int                   # Principal vs secondary
    diagnosis_type::String          # ADMISSION, PRINCIPAL, SECONDARY
    onset_date::Date
    created_at::DateTime
end

struct Procedure
    procedure_id::String
    patient_id::String
    encounter_id::String
    code::String                    # CPT/HCPCS code
    description::String
    procedure_date::DateTime
    quantity::Int
    created_at::DateTime
end

struct Medication
    medication_id::String
    patient_id::String
    encounter_id::String
    ndc_code::String               # National Drug Code
    drug_name::String
    route::String                  # ORAL, IV, TOPICAL, etc.
    dose::String
    start_date::DateTime
    end_date::Union{DateTime, Nothing}
    created_at::DateTime
end

# ============================================================================
# FINANCIAL DATA TYPES
# ============================================================================

struct Claim
    claim_id::String
    patient_id::String
    encounter_id::String
    service_date::Date
    claim_type::String             # PROFESSIONAL, INSTITUTIONAL
    claim_status::String           # SUBMITTED, ACCEPTED, DENIED
    procedure_code::String         # CPT/HCPCS
    units_of_service::Int
    charge_amount::Float64
    allowed_amount::Float64
    paid_amount::Float64
    patient_responsibility::Float64
    payor_id::String
    facility_id::String
    provider_npi::String
    submitted_date::Date
    decision_date::Date
    created_at::DateTime
end

struct ChargeItem
    charge_id::String
    encounter_id::String
    department_code::String
    account_code::String
    procedure_code::String
    units::Int
    unit_price::Float64
    total_charge::Float64
    payor_id::String
    created_at::DateTime
end

# ============================================================================
# QUALITY & OUTCOME TYPES
# ============================================================================

struct QualityMetric
    metric_id::String
    patient_id::String
    encounter_id::String
    metric_name::String            # READMISSION_30D, MORTALITY, INFECTION, etc.
    metric_value::Union{Int, Float64, Bool}
    measurement_date::Date
    created_at::DateTime
end

struct OutcomeEvent
    event_id::String
    patient_id::String
    event_type::String             # READMISSION, MORTALITY, COMPLICATION
    event_date::Date
    days_from_discharge::Int
    description::String
    created_at::DateTime
end

# ============================================================================
# ANALYSIS & RESEARCH TYPES
# ============================================================================

struct CohortDefinition
    cohort_id::String
    name::String
    description::String
    inclusion_criteria::Vector{String}
    exclusion_criteria::Vector{String}
    cohort_size::Int
    created_by::String
    created_at::DateTime
    updated_at::DateTime
end

struct AnalysisResult
    result_id::String
    user_id::String
    cohort_id::String
    analysis_type::String          # COST_ANALYSIS, REGRESSION, etc.
    parameters::Dict{String, Any}
    results::Dict{String, Any}
    execution_time::Float64        # seconds
    row_count::Int
    created_at::DateTime
end

end  # module Types
```

### 2.2 Data Validation (`src/ingestion/Validation.jl`)

```julia
module Validation

using DataFrames, Dates

"""
    validate_ingestion_file(filepath::String, expected_schema::Dict)::Tuple{Bool, Vector{String}}

Validate incoming data file against expected schema before processing.
"""
function validate_ingestion_file(filepath::String, expected_schema::Dict)::Tuple{Bool, Vector{String}}
    errors = String[]

    # 1. File exists
    !isfile(filepath) && push!(errors, "File not found: $filepath")
    isempty(errors) || return (false, errors)

    # 2. Parse file
    try
        df = CSV.read(filepath, DataFrame)
    catch e
        push!(errors, "Failed to parse file: $(e.msg)")
        return (false, errors)
    end

    # 3. Check required columns
    required_cols = keys(expected_schema)
    missing_cols = setdiff(required_cols, names(df))
    !isempty(missing_cols) && push!(errors, "Missing columns: $(join(missing_cols, ", "))")

    # 4. Validate column types
    for (col, expected_type) in expected_schema
        col ∉ names(df) && continue
        actual_type = eltype(df[!, col])
        actual_type != expected_type && push!(errors, "Column $col has type $actual_type, expected $expected_type")
    end

    # 5. Check for completeness
    missing_required = filter(row -> any(ismissing.(row)), eachrow(df))
    !isempty(missing_required) && push!(errors, "$(nrow(missing_required)) rows have missing required fields")

    # 6. Data quality checks
    errors_quality = validate_data_quality(df)
    append!(errors, errors_quality)

    return (isempty(errors), errors)
end

"""
    validate_data_quality(df::DataFrame)::Vector{String}

Check for common data quality issues.
"""
function validate_data_quality(df::DataFrame)::Vector{String}
    errors = String[]

    # Duplicate records
    if any(nonunique(df))
        push!(errors, "$(sum(nonunique(df))) duplicate records found")
    end

    # Invalid dates
    for col in names(df)
        if eltype(df[!, col]) <: Date || eltype(df[!, col]) <: DateTime
            invalid_dates = filter(!isvalid_date, df[!, col])
            !isempty(invalid_dates) && push!(errors, "Column $col has invalid dates: $(length(invalid_dates))")
        end
    end

    # Negative amounts (for financial data)
    for col in names(df)
        if contains(lowercase(col), ["amount", "charge", "cost"])
            negative_amounts = df[df[!, col] .< 0, :]
            !isempty(negative_amounts) && push!(errors, "Column $col has negative values: $(nrow(negative_amounts))")
        end
    end

    return errors
end

# Validation rules for medical codes
const ICD10_PATTERN = r"^[A-Z]\d{2}(\.[A-Z0-9]{1,4})?$"
const CPT_PATTERN = r"^\d{5}$"
const NDC_PATTERN = r"^\d{5}-\d{3,4}-\d{2}$"

"""
    validate_icd10_code(code::String)::Bool

Validate ICD-10 code format.
"""
function validate_icd10_code(code::String)::Bool
    return match(ICD10_PATTERN, code) !== nothing
end

end  # module Validation
```

### 2.3 Data Ingestion Pipeline (`src/ingestion/CSVIngestion.jl`)

```julia
module CSVIngestion

using DataFrames, CSV, Logging, Dates
using ..Types, ..Validation, ..Logging as AuditLogging, ..Security

"""
    ingest_csv(filepath::String, context::SecurityContext, source_name::String)::Tuple{DataFrame, Vector{String}}

Secure data ingestion with validation and audit logging.
"""
function ingest_csv(filepath::String, context::SecurityContext, source_name::String)::Tuple{DataFrame, Vector{String}}

    # 1. Authorize access
    @info "Checking authorization" user=context.user_id source=source_name
    verify_access_control(context, "data_ingestion")

    # 2. Validate file
    schema = get_schema_for_source(source_name)
    is_valid, validation_errors = Validation.validate_ingestion_file(filepath, schema)
    !is_valid && return (DataFrame(), validation_errors)

    # 3. Load data
    try
        df = CSV.read(filepath, DataFrame)
    catch e
        error_msg = "Failed to load CSV: $(e.msg)"
        AuditLogging.log_access(AuditLog(
            user_id = context.user_id,
            timestamp = now(UTC),
            event_type = "DATA_INGESTION_FAILED",
            resource = source_name,
            action = "LOAD",
            result = "ERROR: $(error_msg)",
            ip_address = context.ip_address,
            purpose_code = "OPERATIONS"
        ))
        return (DataFrame(), [error_msg])
    end

    # 4. Log successful ingestion
    AuditLogging.log_access(AuditLog(
        user_id = context.user_id,
        timestamp = now(UTC),
        event_type = "DATA_INGESTION",
        resource = source_name,
        action = "LOAD",
        result = "SUCCESS",
        ip_address = context.ip_address,
        purpose_code = "OPERATIONS"
    ))

    @info "Data ingestion complete" rows=nrow(df) columns=ncol(df) source=source_name

    return (df, String[])
end

function get_schema_for_source(source_name::String)::Dict
    schemas = Dict(
        "hospital_claims" => Dict(
            :claim_id => String,
            :patient_id => String,
            :service_date => Date,
            :charge_amount => Float64,
            :allowed_amount => Float64,
            :paid_amount => Float64
        ),
        "clinical_data" => Dict(
            :patient_id => String,
            :encounter_id => String,
            :diagnosis_code => String,
            :procedure_code => String,
            :encounter_date => Date
        )
    )
    return get(schemas, source_name, Dict())
end

end  # module CSVIngestion
```

---

## Module 2: Patient Cohort Building

### 3.1 Cohort Criteria (`src/cohort/Criteria.jl`)

```julia
module Criteria

using Dates, DataFrames

abstract type Criterion end

# Specific criteria implementations
struct AgeRangeCriterion <: Criterion
    min_age::Int
    max_age::Int
    reference_date::Date
end

struct DiagnosisCriterion <: Criterion
    icd10_codes::Vector{String}
    operator::String  # "any", "all"
    within_days::Int
end

struct CostThresholdCriterion <: Criterion
    min_cost::Float64
    max_cost::Float64
    time_period_days::Int
end

struct DateRangeCriterion <: Criterion
    start_date::Date
    end_date::Date
end

"""
    apply_criterion(df::DataFrame, criterion::Criterion)::BitVector

Apply a single criterion to filter patients.
"""
function apply_criterion(df::DataFrame, criterion::AgeRangeCriterion)::BitVector
    current_date = criterion.reference_date
    ages = year.(current_date) .- year.(df.birth_date)
    return (criterion.min_age .<= ages) .& (ages .< criterion.max_age)
end

function apply_criterion(df::DataFrame, criterion::DiagnosisCriterion)::BitVector
    matching = falses(nrow(df))
    for row_idx in 1:nrow(df)
        diagnosis_codes = df.diagnosis_codes[row_idx]
        if criterion.operator == "any"
            matching[row_idx] = any(code in criterion.icd10_codes for code in diagnosis_codes)
        elseif criterion.operator == "all"
            matching[row_idx] = all(code in diagnosis_codes for code in criterion.icd10_codes)
        end
    end
    return matching
end

end  # module Criteria
```

### 3.2 Cohort Builder (`src/cohort/CohortBuilder.jl`)

```julia
module CohortBuilder

using DataFrames, Logging, Dates
using ..Types, ..Criteria

"""
    build_cohort(df::DataFrame, definition::CohortDefinition, context::SecurityContext)::Tuple{DataFrame, Int}

Build a cohort using inclusion/exclusion criteria with audit logging.
"""
function build_cohort(df::DataFrame, definition::CohortDefinition, context::SecurityContext)::Tuple{DataFrame, Int}

    @info "Building cohort" cohort_id=definition.cohort_id criteria_count=length(definition.inclusion_criteria)

    # Start with all patients
    included = trues(nrow(df))

    # Apply inclusion criteria
    for criterion_str in definition.inclusion_criteria
        criterion = parse_criterion(criterion_str)
        included .&= Criteria.apply_criterion(df, criterion)
    end

    # Apply exclusion criteria
    excluded = falses(nrow(df))
    for criterion_str in definition.exclusion_criteria
        criterion = parse_criterion(criterion_str)
        excluded .|= Criteria.apply_criterion(df, criterion)
    end

    # Final cohort
    cohort_mask = included .& .!excluded
    cohort_df = df[cohort_mask, :]

    @info "Cohort built" cohort_size=nrow(cohort_df) inclusion_count=sum(included) exclusion_count=sum(excluded)

    return (cohort_df, nrow(cohort_df))
end

function parse_criterion(criterion_str::String)::Criteria.Criterion
    # Parse criterion string format: "age:18-65" or "diagnosis:E11.0:all"
    parts = split(criterion_str, ":")
    criterion_type = parts[1]

    if criterion_type == "age"
        age_range = split(parts[2], "-")
        return Criteria.AgeRangeCriterion(parse(Int, age_range[1]), parse(Int, age_range[2]), today())
    elseif criterion_type == "diagnosis"
        codes = split(parts[2], ",")
        operator = get(parts, 3, "any")
        return Criteria.DiagnosisCriterion(codes, operator, 365)
    end

    error("Unknown criterion type: $criterion_type")
end

end  # module CohortBuilder
```

---

## Module 3: Cost Analysis Engine

### 4.1 Cost Analysis (`src/analytics/CostAnalysis.jl`)

```julia
module CostAnalysis

using DataFrames, Statistics, Logging, Dates
using ..Types

"""
    calculate_total_cost(patient_df::DataFrame)::Dict{String, Float64}

Calculate total cost of care for a patient cohort.
"""
function calculate_total_cost(patient_df::DataFrame)::Dict{String, Float64}

    total_cost = sum(skipmissing(patient_df.paid_amount))

    # Breakdown by service type
    breakdown = Dict{String, Float64}()
    for service_type in unique(skipmissing(patient_df.service_type))
        service_cost = sum(skipmissing(patient_df[patient_df.service_type .== service_type, :paid_amount]))
        breakdown[service_type] = service_cost
    end

    return Dict(
        "total_cost" => total_cost,
        "average_cost" => mean(skipmissing(patient_df.paid_amount)),
        "median_cost" => median(skipmissing(patient_df.paid_amount)),
        "std_dev" => std(skipmissing(patient_df.paid_amount)),
        "breakdown" => breakdown
    )
end

"""
    calculate_cost_per_episode(encounters_df::DataFrame)::DataFrame

Calculate cost per episode of care.
"""
function calculate_cost_per_episode(encounters_df::DataFrame)::DataFrame
    episode_costs = combine(
        groupby(encounters_df, [:encounter_id, :patient_id]),
        :paid_amount => sum => :episode_cost,
        :service_date => length => :service_count
    )

    return episode_costs
end

"""
    inflate_to_base_year(amount::Float64, from_year::Int, to_year::Int)::Float64

Adjust cost to specified base year using inflation factors.
"""
function inflate_to_base_year(amount::Float64, from_year::Int, to_year::Int)::Float64
    # Use CMS-published inflation factors
    inflation_factors = Dict(
        2023 => 1.000,
        2024 => 1.045,
        2025 => 1.090,
        2026 => 1.130
    )

    from_factor = get(inflation_factors, from_year, 1.0)
    to_factor = get(inflation_factors, to_year, 1.0)

    return amount * (to_factor / from_factor)
end

end  # module CostAnalysis
```

---

## Development Workflow

### 5.1 Daily Development Process

```bash
# 1. Start of day: pull latest changes
git pull origin develop

# 2. Create feature branch
git checkout -b feature/user-auth

# 3. Start development server
docker-compose -f docker/docker-compose.yml up -d

# 4. Make changes to code
# Edit src/api/Routes.jl, test/unit/test_api.jl, etc.

# 5. Run tests locally
julia scripts/run_tests.sh

# 6. Format code
julia -e 'using JuliaFormatter; format("src")'

# 7. Run security checks
julia -e 'using Aqua; Aqua.test_all(Main)'

# 8. Commit changes with descriptive message
git commit -m "feat: add user authentication endpoint

- Implement JWT token generation
- Add MFA verification
- Log access attempts for audit trail

Fixes #123"

# 9. Push and create Pull Request
git push origin feature/user-auth
# Create PR on GitHub with checklist
```

### 5.2 Code Review Checklist

```markdown
## Code Review Checklist

- [ ] Follows Julia style guide (JuliaFormatter)
- [ ] All functions have docstrings
- [ ] Type annotations on public API
- [ ] Unit tests pass (≥80% coverage)
- [ ] No type instability in hot loops (@code_warntype checked)
- [ ] HIPAA compliance (audit logging, encryption if needed)
- [ ] Database queries use parameterized statements
- [ ] No hardcoded secrets/credentials
- [ ] Performance acceptable (BenchmarkTools tested)
- [ ] Documentation updated
```

---

## Testing & Quality Assurance

### 6.1 Unit Test Example (`test/unit/test_cost_analysis.jl`)

```julia
module TestCostAnalysis

using Test, DataFrames, Dates
using HEcoSystem.CostAnalysis

@testset "Cost Analysis Functions" begin

    # Setup test data
    test_df = DataFrame(
        patient_id = ["P001", "P001", "P002"],
        paid_amount = [1000.0, 500.0, 2000.0],
        service_type = ["inpatient", "outpatient", "inpatient"],
        service_date = [Date(2026, 1, 1), Date(2026, 1, 5), Date(2026, 2, 1)]
    )

    @testset "calculate_total_cost" begin
        result = CostAnalysis.calculate_total_cost(test_df)

        @test result["total_cost"] ≈ 3500.0
        @test result["average_cost"] ≈ 1166.67 atol=1
        @test result["median_cost"] ≈ 1500.0
        @test haskey(result, "breakdown")
        @test result["breakdown"]["inpatient"] ≈ 3000.0
    end

    @testset "inflate_to_base_year" begin
        amount = 1000.0
        inflated = CostAnalysis.inflate_to_base_year(amount, 2023, 2026)

        @test inflated ≈ 1130.0  # 13% inflation
        @test inflated > amount
    end
end

end  # module TestCostAnalysis
```

### 6.2 Integration Test Example (`test/integration/test_end_to_end.jl`)

```julia
@testset "End-to-End Integration" begin

    # 1. Ingest test data
    test_file = "test/fixtures/sample_data.csv"
    context = create_test_context()
    df, errors = CSVIngestion.ingest_csv(test_file, context, "test_data")
    @test isempty(errors)
    @test nrow(df) > 0

    # 2. Build cohort
    criteria = CohortDefinition(
        cohort_id = "test_cohort",
        inclusion_criteria = ["age:30-65"],
        exclusion_criteria = []
    )
    cohort_df, size = CohortBuilder.build_cohort(df, criteria, context)
    @test nrow(cohort_df) > 0

    # 3. Run analysis
    results = CostAnalysis.calculate_total_cost(cohort_df)
    @test results["total_cost"] > 0
    @test haskey(results, "breakdown")

    # 4. Verify audit logging
    logs = get_audit_logs(context.user_id)
    @test length(logs) > 0
    @test any(log.event_type == "DATA_INGESTION" for log in logs)
end
```

---

## Security Implementation

### 7.1 Authentication Middleware (`src/api/Middleware.jl`)

```julia
module Middleware

using Genie, Genie.Router, Genie.Renderer.JSON
using ..Types, ..Security

"""
    authorize_request(handler::Function)

Middleware to verify MFA and RBAC before processing request.
"""
function authorize_request(handler::Function)
    return function (params...)
        # 1. Extract JWT token from header
        token = get(Genie.Router.params(), "Authorization", "")
        isempty(token) && return json(:error => "Unauthorized", :status => 401)

        # 2. Verify JWT signature
        context = Security.verify_jwt_token(token)
        isnothing(context) && return json(:error => "Invalid token", :status => 401)

        # 3. Check MFA verification
        !context.mfa_verified && return json(:error => "MFA required", :status => 403)

        # 4. Check session timeout (30 min)
        minutes_idle = (now(UTC) - context.session_start).value / 60000
        minutes_idle > 30 && return json(:error => "Session expired", :status => 401)

        # 5. Call handler with context
        return handler(context, params...)
    end
end

"""
    audit_log_request(event_type::String)

Middleware to log all API requests.
"""
function audit_log_request(event_type::String)
    return function (handler::Function)
        return function (context::SecurityContext, params...)
            # Log request
            log_entry = AuditLog(
                user_id = context.user_id,
                timestamp = now(UTC),
                event_type = event_type,
                resource = Genie.Router.current_route().path,
                action = Genie.Router.method(),
                result = "INITIATED",
                ip_address = context.ip_address,
                purpose_code = "OPERATIONS"
            )

            # Execute handler
            response = handler(context, params...)

            # Log response
            log_entry.result = "SUCCESS"
            Logging.log_access(log_entry)

            return response
        end
    end
end

end  # module Middleware
```

### 7.2 Encryption Utilities (`src/utils/Crypto.jl`)

```julia
module Crypto

using OpenSSL, Random

"""
    encrypt_aes256(plaintext::String, key::Vector{UInt8})::Vector{UInt8}

Encrypt data using AES-256-GCM.
"""
function encrypt_aes256(plaintext::String, key::Vector{UInt8})::Tuple{Vector{UInt8}, Vector{UInt8}}
    # Generate random IV
    iv = rand(UInt8, 12)  # 96-bit IV for GCM

    # Encrypt
    cipher = Cipher("aes-256-gcm", key, iv)
    ciphertext = update(cipher, plaintext)

    return (ciphertext, iv)
end

"""
    decrypt_aes256(ciphertext::Vector{UInt8}, iv::Vector{UInt8}, key::Vector{UInt8})::String

Decrypt AES-256-GCM encrypted data.
"""
function decrypt_aes256(ciphertext::Vector{UInt8}, iv::Vector{UInt8}, key::Vector{UInt8})::String
    cipher = Cipher("aes-256-gcm", key, iv; decrypt=true)
    plaintext = update(cipher, ciphertext)
    return String(plaintext)
end

end  # module Crypto
```

---

## Deployment Checklist

### 8.1 Pre-Deployment Verification

- ☐ All tests passing (≥80% coverage)
- ☐ Code reviewed and approved
- ☐ Security scan completed (no critical vulnerabilities)
- ☐ Database migrations tested in staging
- ☐ Performance testing completed (query times < 5s)
- ☐ HIPAA compliance checklist completed
- ☐ Audit logging verified
- ☐ Encryption tested (at rest and in transit)
- ☐ Disaster recovery test passed
- ☐ Documentation updated
- ☐ User training materials prepared
- ☐ Go-live communication sent

### 8.2 Deployment Command

```bash
# Build Docker image
docker build -f docker/Dockerfile -t healthcare-economics:v1.0.0 .

# Push to registry
docker push your-registry/healthcare-economics:v1.0.0

# Deploy to Kubernetes
kubectl apply -k k8s/overlays/prod/

# Verify deployment
kubectl rollout status deployment/healthcare-economics -n production
kubectl get pods -n production
```

---

## Next Steps

1. **Week 1-2:** Complete project setup, initialize Git repo, Docker containers
2. **Week 2-3:** Implement Module 1 (Data Ingestion & Validation)
3. **Week 3-4:** Implement Module 2 (Cohort Building)
4. **Week 4-5:** Implement Module 3 (Cost Analysis)
5. **Week 5-6:** Testing, security hardening, documentation
6. **Week 6:** Deployment and go-live

---

**END OF IMPLEMENTATION GUIDE**
