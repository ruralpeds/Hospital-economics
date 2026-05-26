"""
    RuralCore

Foundation package for RuralHealthPlatform.jl.
Provides shared domain types, geographic identifiers, error hierarchy,
CMS benchmark constants, and validation utilities used by all packages.

No business logic — only types, constants, and validation.
"""
module RuralCore

using Dates
using UUIDs
using JSON3

# Core infrastructure
include("errors.jl")
include("types.jl")
include("constants.jl")
include("validation.jl")
include("config.jl")
include("audit.jl")
include("mutation_log.jl")
include("references.jl")
include("bug_report.jl")
include("auth.jl")

# ── Errors ──────────────────────────────────────────────────────────────────
export RuralHealthError,
    DataValidationError,
    StatisticalAssumptionError,
    InsufficientSampleError,
    ConvergenceError,
    FormulaParseError,
    DomainValidationError,
    DataIOError,
    ConfigurationError,
    NetworkError,
    StateError,
    CalculationError,
    AuditError,
    NotImplementedError

# ── Geographic Keys ────────────────────────────────────────────────────────
export CountyKey, TimeKey, CountyYearKey, state_fips, county_fips

# ── Domain Types ───────────────────────────────────────────────────────────
export Hospital, HospitalType, FacilitySize,
    PayerMix, PayerCategory,
    QualityMetric, MetricDomain,
    County, Region,
    ChapterMeta

# ── Enum values ────────────────────────────────────────────────────────────
export CRITICAL_ACCESS, RURAL_CLINIC, REGIONAL_MEDICAL_CENTER, SPECIALTY_HOSPITAL,
    VERY_SMALL, SMALL, MEDIUM, LARGE, VERY_LARGE,
    MEDICARE, MEDICAID, COMMERCIAL, SELF_PAY, OTHER,
    MORTALITY, SAFETY, READMISSION, TIMELINESS, EFFECTIVENESS, EFFICIENCY, EQUITY

# ── Constants ──────────────────────────────────────────────────────────────
export CMS_BASE_DRG_RATE, CMS_WAGE_INDEX_MIN, CMS_WAGE_INDEX_MAX,
    BREAK_EVEN_MARGIN, FINANCIAL_DISTRESS_MARGIN, MIN_SAMPLE_SIZE_HYPOTHESIS_TEST

# ── Validation ─────────────────────────────────────────────────────────────
export validate_fips, validate_hospital_beds, validate_payer_mix, validate_year,
    validate_percentage, validate_positive, validate_nonnegative,
    validate_not_empty, validate_finite

# ── Audit ──────────────────────────────────────────────────────────────────
export AuditEntry, get_audit_log, clear_audit_log, save_audit_log, @audited_calculation

# ── Mutation Log ───────────────────────────────────────────────────────────
export MutationKind, MUTATION_CREATE, MUTATION_UPDATE, MUTATION_DELETE,
    MutationEntry, get_mutation_log, clear_mutation_log, save_mutation_log,
    log_create, log_update, log_delete

# ── References ─────────────────────────────────────────────────────────────
export ClinicalReference, register_reference, get_reference, get_citation_log,
    clear_citation_log, @cited

# ── Configuration ──────────────────────────────────────────────────────────
export PlatformConfig, get_config

# ── Bug Reporting ──────────────────────────────────────────────────────────
export BugReport,
    BugReportSeverity, SEVERITY_LOW, SEVERITY_MEDIUM, SEVERITY_HIGH, SEVERITY_CRITICAL,
    BugReportCategory, CATEGORY_CALCULATION, CATEGORY_DATA, CATEGORY_UI_UX,
    CATEGORY_PERFORMANCE, CATEGORY_DOCUMENTATION, CATEGORY_OTHER,
    severity_label, severity_github_label, category_label, category_github_label,
    format_github_issue_title, format_github_issue_body, github_issue_labels,
    BugReportSpamResult, score_bug_report_spam

end  # module RuralCore
