# Healthcare Economics Platform - Data Dictionary
## PostgreSQL Schema Design for Healthcare Data

**Version:** 1.0
**Date:** April 15, 2026
**Database:** PostgreSQL 14+ with TimescaleDB
**Encryption:** AES-256-GCM for sensitive columns

---

## Table of Contents

1. [Database Design Principles](#database-design-principles)
2. [Core Tables](#core-tables)
3. [Clinical Tables](#clinical-tables)
4. [Financial Tables](#financial-tables)
5. [Quality & Outcome Tables](#quality--outcome-tables)
6. [Reference/Lookup Tables](#referencelookup-tables)
7. [Audit & Logging Tables](#audit--logging-tables)
8. [Indexes & Performance](#indexes--performance)

---

## Database Design Principles

### 1.1 Schema Design

- **Patient De-identification:** No PHI stored directly; internal patient_id used
- **Encryption:** Sensitive columns encrypted at column level
- **Normalization:** 3rd normal form to minimize data redundancy
- **Temporal Data:** TimescaleDB hypertables for time-series (encounters, claims)
- **Audit Trail:** All modifications tracked with created_at, updated_at, updated_by
- **Immutability:** Audit logs cannot be modified or deleted

### 1.2 Data Type Standards

```sql
-- Standard column types
patient_id: UUID (internal identifier, no PHI)
date_column: DATE or TIMESTAMP WITH TIME ZONE
amount_column: NUMERIC(15, 2) for financial data
code_column: VARCHAR(20) for medical codes
indicator_column: BOOLEAN for yes/no flags
encrypted_column: BYTEA for encrypted text/data

-- Create custom type for medical code
CREATE TYPE medical_code_type AS (
    code VARCHAR(20),
    system VARCHAR(50),  -- ICD10, CPT, HCPCS, NDC, etc.
    description TEXT
);
```

### 1.3 Encryption Strategy

```sql
-- Sensitive columns to encrypt
- patients.first_name
- patients.last_name
- patients.date_of_birth
- patients.ssn
- patients.email
- patients.phone
- encounters.patient_identifier (external ID if provided)
- medications.patient_identifier

-- Encryption function example
CREATE OR REPLACE FUNCTION encrypt_field(plaintext TEXT, key BYTEA)
RETURNS BYTEA AS $$
  SELECT pgcrypto.encrypt_iv(
    convert_to(plaintext, 'UTF8'),
    key,
    random()::bytea,
    'aes'
  );
$$ LANGUAGE SQL;

-- Decryption function
CREATE OR REPLACE FUNCTION decrypt_field(ciphertext BYTEA, key BYTEA)
RETURNS TEXT AS $$
  SELECT convert_from(
    pgcrypto.decrypt_iv(
      ciphertext,
      key,
      substring(ciphertext FROM 1 FOR 16),
      'aes'
    ),
    'UTF8'
  );
$$ LANGUAGE SQL;
```

---

## Core Tables

### 2.1 `patients` Table

**Purpose:** Master patient table (de-identified)

```sql
CREATE TABLE patients (
    -- Identification
    patient_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    external_patient_id VARCHAR(255),          -- Reference to source system
    external_patient_id_encrypted BYTEA,       -- Encrypted for audit

    -- Demographics
    birth_year SMALLINT NOT NULL,              -- Year only (not full DOB for HIPAA)
    birth_month SMALLINT,                      -- Optional: month for age calculation
    sex CHAR(1) NOT NULL,                      -- M, F, O, U (unknown)
        CHECK (sex IN ('M', 'F', 'O', 'U')),
    race_code VARCHAR(20),                     -- Race/ethnicity code
    ethnicity_code VARCHAR(20),                -- Hispanic/Non-Hispanic
    primary_language_code VARCHAR(5),          -- Language code (ISO 639-1)

    -- Geography (HIPAA: first 3 ZIP digits only)
    zip_code_prefix VARCHAR(3),                -- First 3 digits of ZIP
    state_code CHAR(2),                        -- State abbreviation
    country_code CHAR(2),                      -- Country code (ISO 3166-1)

    -- Status
    patient_status VARCHAR(20),                -- ACTIVE, DECEASED, LOST_TO_FOLLOWUP
        CHECK (patient_status IN ('ACTIVE', 'DECEASED', 'LOST_TO_FOLLOWUP')),

    -- Data Management
    source_system_id VARCHAR(100),             -- Where patient data originated
    data_source VARCHAR(50),                   -- CLAIMS, EHR, REGISTRY
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(255),

    -- Indexes
    UNIQUE(external_patient_id, source_system_id)
);

-- Indexes
CREATE INDEX idx_patients_birth_year ON patients(birth_year);
CREATE INDEX idx_patients_zip_code ON patients(zip_code_prefix, state_code);
CREATE INDEX idx_patients_source ON patients(source_system_id);

-- Audit trigger
CREATE TRIGGER patients_audit_trigger
BEFORE UPDATE ON patients
FOR EACH ROW
EXECUTE FUNCTION update_modified_column();
```

### 2.2 `encounters` Table (Time-Series)

**Purpose:** Hospital/clinical encounters (inpatient, outpatient, ED)

```sql
-- Convert to TimescaleDB hypertable for time-series efficiency
CREATE TABLE encounters (
    encounter_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(patient_id),

    -- Encounter Details
    encounter_date DATE NOT NULL,
    encounter_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    encounter_type VARCHAR(50) NOT NULL,      -- INPATIENT, OUTPATIENT, ED, PROCEDURE
        CHECK (encounter_type IN ('INPATIENT', 'OUTPATIENT', 'ED', 'PROCEDURE')),

    -- Facility
    facility_id VARCHAR(100) NOT NULL,        -- NPI for facility
    facility_name VARCHAR(500),
    facility_state CHAR(2),

    -- Clinical Information
    primary_diagnosis_code VARCHAR(20),       -- ICD-10 code
    primary_diagnosis_description VARCHAR(500),
    admission_source VARCHAR(50),             -- Emergency, urgent, planned, etc.
    admission_type VARCHAR(50),               -- Emergency, urgent, elective, newborn

    -- Discharge Information
    discharge_date DATE,
    discharge_timestamp TIMESTAMP WITH TIME ZONE,
    discharge_status VARCHAR(50),             -- Home, SNF, inpatient rehab, expired, etc.
    length_of_stay_days INT,

    -- Metrics
    quantity_admissions INT DEFAULT 1,

    -- Billing
    primary_payer_id VARCHAR(100),
    primary_payor_name VARCHAR(500),
    secondary_payer_id VARCHAR(100),

    -- Data Management
    source_system_id VARCHAR(100),
    source_encounter_id VARCHAR(100),
    data_quality_score NUMERIC(3, 2),        -- 0.00-1.00 confidence score
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(255)
);

-- Convert to TimescaleDB hypertable
SELECT create_hypertable('encounters', 'encounter_date', if_not_exists => TRUE);

-- Indexes
CREATE INDEX idx_encounters_patient ON encounters(patient_id);
CREATE INDEX idx_encounters_facility ON encounters(facility_id);
CREATE INDEX idx_encounters_type ON encounters(encounter_type);
CREATE INDEX idx_encounters_source ON encounters(source_encounter_id, source_system_id);

-- Time-series specific indexes
CREATE INDEX idx_encounters_time ON encounters(encounter_date DESC);
```

---

## Clinical Tables

### 3.1 `diagnoses` Table

**Purpose:** Patient diagnoses with ICD-10 codes

```sql
CREATE TABLE diagnoses (
    diagnosis_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    encounter_id UUID NOT NULL REFERENCES encounters(encounter_id),
    patient_id UUID NOT NULL REFERENCES patients(patient_id),

    -- Diagnosis Code
    icd10_code VARCHAR(20) NOT NULL,          -- ICD-10-CM code (e.g., E11.9)
    icd10_description VARCHAR(500),

    -- Diagnosis Details
    diagnosis_sequence INT,                   -- 1=principal, 2+=secondary
    diagnosis_type VARCHAR(50),               -- ADMISSION, PRINCIPAL, SECONDARY, COMPLICATION
    clinical_status VARCHAR(50),              -- ACTIVE, INACTIVE, RESOLVED

    -- Clinical Information
    onset_date DATE,
    resolution_date DATE,
    clinical_note TEXT,                       -- Optional: clinical context

    -- Data Management
    source_system_id VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CHECK (diagnosis_sequence > 0)
);

-- Indexes
CREATE INDEX idx_diagnoses_patient ON diagnoses(patient_id);
CREATE INDEX idx_diagnoses_encounter ON diagnoses(encounter_id);
CREATE INDEX idx_diagnoses_code ON diagnoses(icd10_code);
CREATE INDEX idx_diagnoses_sequence ON diagnoses(diagnosis_sequence);
```

### 3.2 `procedures` Table

**Purpose:** Procedures with CPT/HCPCS codes

```sql
CREATE TABLE procedures (
    procedure_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    encounter_id UUID NOT NULL REFERENCES encounters(encounter_id),
    patient_id UUID NOT NULL REFERENCES patients(patient_id),

    -- Procedure Code
    cpt_code VARCHAR(20) NOT NULL,            -- CPT or HCPCS code
    cpt_description VARCHAR(500),

    -- Procedure Details
    procedure_date DATE NOT NULL,
    procedure_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    procedure_sequence INT,

    -- Quantity
    units_of_service INT DEFAULT 1,

    -- Provider
    provider_npi VARCHAR(10),                 -- National Provider Identifier
    provider_name VARCHAR(500),
    provider_specialty VARCHAR(100),

    -- Data Management
    source_system_id VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_procedures_patient ON procedures(patient_id);
CREATE INDEX idx_procedures_encounter ON procedures(encounter_id);
CREATE INDEX idx_procedures_code ON procedures(cpt_code);
CREATE INDEX idx_procedures_date ON procedures(procedure_date);
```

### 3.3 `medications` Table

**Purpose:** Medications with NDC codes

```sql
CREATE TABLE medications (
    medication_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(patient_id),
    encounter_id UUID NOT NULL REFERENCES encounters(encounter_id),

    -- Drug Information
    ndc_code VARCHAR(20),                     -- National Drug Code (optional)
    drug_name VARCHAR(500) NOT NULL,
    generic_name VARCHAR(500),
    drug_class VARCHAR(100),

    -- Dosage
    dose_quantity NUMERIC(10, 2),
    dose_unit VARCHAR(50),                    -- mg, ml, units, etc.
    route VARCHAR(50),                        -- ORAL, IV, IM, SC, TOPICAL, etc.
    frequency VARCHAR(100),                   -- BID, TID, QID, daily, etc.

    -- Dates
    start_date DATE NOT NULL,
    end_date DATE,

    -- Status
    medication_status VARCHAR(50),            -- ACTIVE, COMPLETED, STOPPED

    -- Data Management
    source_system_id VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_medications_patient ON medications(patient_id);
CREATE INDEX idx_medications_encounter ON medications(encounter_id);
CREATE INDEX idx_medications_ndc ON medications(ndc_code);
CREATE INDEX idx_medications_start_date ON medications(start_date);
```

---

## Financial Tables

### 4.1 `claims` Table (Time-Series)

**Purpose:** Insurance claims (837 professional/institutional)

```sql
CREATE TABLE claims (
    claim_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(patient_id),
    encounter_id UUID REFERENCES encounters(encounter_id),

    -- Claim Identifiers
    external_claim_id VARCHAR(100) NOT NULL, -- Claim number from payer
    line_item_number INT,

    -- Service Information
    service_date DATE NOT NULL,
    claim_type VARCHAR(50),                   -- PROFESSIONAL, INSTITUTIONAL

    -- Procedure/Diagnosis
    procedure_code VARCHAR(20),               -- CPT/HCPCS
    diagnosis_code VARCHAR(20),               -- ICD-10
    modifier_code VARCHAR(10),                -- CPT modifier

    -- Quantities & Units
    units_of_service INT,

    -- Amounts
    charge_amount NUMERIC(15, 2) NOT NULL,   -- Billed amount
    allowed_amount NUMERIC(15, 2),           -- Payer's allowed amount
    deductible_applied NUMERIC(15, 2),
    coinsurance_applied NUMERIC(15, 2),
    copay_applied NUMERIC(15, 2),
    paid_amount NUMERIC(15, 2),              -- Actual reimbursement
    patient_responsibility NUMERIC(15, 2),   -- Out-of-pocket

    -- Claim Status
    claim_status VARCHAR(50) NOT NULL,       -- SUBMITTED, PENDING, ACCEPTED, DENIED
        CHECK (claim_status IN ('SUBMITTED', 'PENDING', 'ACCEPTED', 'DENIED')),
    denial_code VARCHAR(50),                 -- If denied, why
    denial_reason TEXT,

    -- Payer Information
    payer_id VARCHAR(100),
    payer_name VARCHAR(500),

    -- Dates
    submission_date DATE,
    decision_date DATE,
    payment_date DATE,

    -- Data Management
    source_system_id VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Convert to TimescaleDB hypertable
SELECT create_hypertable('claims', 'service_date', if_not_exists => TRUE);

-- Indexes
CREATE INDEX idx_claims_patient ON claims(patient_id);
CREATE INDEX idx_claims_encounter ON claims(encounter_id);
CREATE INDEX idx_claims_external_id ON claims(external_claim_id, source_system_id);
CREATE INDEX idx_claims_payer ON claims(payer_id);
CREATE INDEX idx_claims_status ON claims(claim_status);
CREATE INDEX idx_claims_service_date ON claims(service_date DESC);
```

### 4.2 `charge_items` Table

**Purpose:** Hospital charges (not necessarily billed)

```sql
CREATE TABLE charge_items (
    charge_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    encounter_id UUID NOT NULL REFERENCES encounters(encounter_id),
    patient_id UUID NOT NULL REFERENCES patients(patient_id),

    -- Charge Details
    department_code VARCHAR(50),              -- Department ID
    department_name VARCHAR(500),
    general_ledger_code VARCHAR(50),          -- GL account code
    charge_description VARCHAR(500),

    -- Service/Item
    procedure_code VARCHAR(20),               -- CPT/HCPCS
    item_code VARCHAR(50),                    -- Internal item ID (supply, device, etc.)
    item_description VARCHAR(500),

    -- Quantities & Pricing
    units INT,
    unit_price NUMERIC(15, 2),
    total_charge NUMERIC(15, 2) NOT NULL,

    -- Payer
    payer_id VARCHAR(100),
    payer_class VARCHAR(50),                  -- Medicare, Medicaid, commercial, etc.

    -- Dates
    charge_date DATE NOT NULL,

    -- Data Management
    source_system_id VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_charges_encounter ON charge_items(encounter_id);
CREATE INDEX idx_charges_patient ON charge_items(patient_id);
CREATE INDEX idx_charges_gl_code ON charge_items(general_ledger_code);
CREATE INDEX idx_charges_date ON charge_items(charge_date);
```

---

## Quality & Outcome Tables

### 5.1 `quality_metrics` Table

**Purpose:** Quality measures (readmission, mortality, infections, etc.)

```sql
CREATE TABLE quality_metrics (
    metric_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(patient_id),
    encounter_id UUID NOT NULL REFERENCES encounters(encounter_id),

    -- Metric Definition
    metric_name VARCHAR(100) NOT NULL,       -- READMISSION_30D, MORTALITY, HAI, etc.
        CHECK (metric_name IN (
            'READMISSION_30D',
            'READMISSION_90D',
            'MORTALITY_INPATIENT',
            'MORTALITY_30D',
            'HOSPITAL_ACQUIRED_INFECTION',
            'POSTOPERATIVE_COMPLICATION',
            'SEPSIS',
            'BLOODSTREAM_INFECTION'
        )),

    -- Metric Result
    metric_value NUMERIC(5, 2),              -- 0 = no, 1 = yes; or numeric value
    metric_type VARCHAR(50),                  -- BINARY, CONTINUOUS, CATEGORICAL

    -- Measurement
    numerator_criteria BOOLEAN,               -- Met numerator criteria?
    denominator_criteria BOOLEAN,             -- Met denominator criteria?
    exclusion_criteria BOOLEAN,               -- Met exclusion criteria?

    -- Dates
    measurement_start_date DATE,
    measurement_end_date DATE,
    metric_assessment_date DATE NOT NULL,

    -- Clinical Context
    clinical_note TEXT,
    risk_score NUMERIC(5, 2),                -- Risk-adjusted score

    -- Data Management
    source_system_id VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_quality_patient ON quality_metrics(patient_id);
CREATE INDEX idx_quality_metric_name ON quality_metrics(metric_name);
CREATE INDEX idx_quality_date ON quality_metrics(measurement_end_date);
```

### 5.2 `outcomes` Table

**Purpose:** Clinical outcomes and events

```sql
CREATE TABLE outcomes (
    outcome_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(patient_id),
    index_encounter_id UUID NOT NULL REFERENCES encounters(encounter_id),

    -- Outcome Event
    outcome_type VARCHAR(50) NOT NULL,       -- READMISSION, MORTALITY, COMPLICATION
        CHECK (outcome_type IN ('READMISSION', 'MORTALITY', 'COMPLICATION', 'ED_VISIT')),
    outcome_description VARCHAR(500),

    -- Event Dates
    event_date DATE NOT NULL,
    days_from_discharge INT,                 -- Days after discharge when event occurred

    -- Facility
    readmit_facility_id VARCHAR(100),        -- If readmission, which facility
    readmit_primary_diagnosis VARCHAR(20),   -- If readmission, primary dx

    -- Status
    outcome_verified BOOLEAN,                -- Clinical verification

    -- Data Management
    source_system_id VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_outcomes_patient ON outcomes(patient_id);
CREATE INDEX idx_outcomes_type ON outcomes(outcome_type);
CREATE INDEX idx_outcomes_event_date ON outcomes(event_date);
```

---

## Reference/Lookup Tables

### 6.1 `icd10_codes` Table

**Purpose:** Reference table for ICD-10 diagnosis codes

```sql
CREATE TABLE icd10_codes (
    icd10_code VARCHAR(20) PRIMARY KEY,
    short_description VARCHAR(200),
    long_description VARCHAR(500),
    poa_indicator CHAR(1),                   -- Present on Admission (Y/N/U)
    mcc_indicator BOOLEAN,                   -- Major Complication/Comorbidity
    cc_indicator BOOLEAN,                    -- Complication/Comorbidity
    hcc_code VARCHAR(10),                    -- HCC risk code (if applicable)
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_icd10_description ON icd10_codes(short_description);
CREATE INDEX idx_icd10_hcc ON icd10_codes(hcc_code);
```

### 6.2 `cpt_codes` Table

**Purpose:** Reference table for CPT procedure codes

```sql
CREATE TABLE cpt_codes (
    cpt_code VARCHAR(20) PRIMARY KEY,
    short_description VARCHAR(200),
    long_description VARCHAR(500),
    category VARCHAR(50),                    -- CAT I, CAT II, CAT III
    practice_expense NUMERIC(8, 2),          -- RVU value
    malpractice_rvu NUMERIC(6, 2),
    work_rvu NUMERIC(6, 2),
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

### 6.3 `payers` Table

**Purpose:** Insurance payers/plans

```sql
CREATE TABLE payers (
    payer_id VARCHAR(100) PRIMARY KEY,
    payer_name VARCHAR(500) NOT NULL,
    payer_type VARCHAR(50),                  -- MEDICARE, MEDICAID, COMMERCIAL, SELF_PAY
    plan_name VARCHAR(500),
    contact_phone VARCHAR(20),
    contact_email VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

---

## Audit & Logging Tables

### 7.1 `audit_logs` Table

**Purpose:** Immutable audit trail of all PHI access

```sql
CREATE TABLE audit_logs (
    audit_log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- User Information
    user_id VARCHAR(255) NOT NULL,
    user_name VARCHAR(500),
    user_role VARCHAR(100),

    -- Action Details
    event_type VARCHAR(50) NOT NULL,        -- PHI_ACCESS, DATA_MODIFICATION, LOGIN, EXPORT
        CHECK (event_type IN (
            'PHI_ACCESS', 'DATA_MODIFICATION', 'DATA_DELETION',
            'LOGIN', 'LOGOUT', 'MFA_VERIFICATION',
            'EXPORT', 'REPORT_RUN', 'ANALYSIS_RUN', 'ERROR'
        )),
    resource_type VARCHAR(100),              -- Table name or resource type
    resource_id VARCHAR(255),                -- Specific record ID accessed
    action VARCHAR(50),                      -- SELECT, INSERT, UPDATE, DELETE

    -- Request Context
    ip_address INET,
    user_agent VARCHAR(2048),
    session_id UUID,

    -- Result
    result_status VARCHAR(50),               -- SUCCESS, DENIED, ERROR
        CHECK (result_status IN ('SUCCESS', 'DENIED', 'ERROR')),
    error_message TEXT,

    -- Purpose (HIPAA requirement)
    purpose_code VARCHAR(50),                -- TREATMENT, PAYMENT, OPERATIONS, RESEARCH
        CHECK (purpose_code IN ('TREATMENT', 'PAYMENT', 'OPERATIONS', 'RESEARCH')),

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Hash for chain integrity (immutable logs)
    hash_previous_record UUID,
    hash_current_record BYTEA,

    -- Immutable
    CONSTRAINT audit_logs_immutable CHECK (TRUE)  -- Enforced by trigger
);

-- Prevent modifications
CREATE OR REPLACE FUNCTION prevent_audit_log_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit logs cannot be modified or deleted';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER audit_log_immutable
BEFORE UPDATE OR DELETE ON audit_logs
FOR EACH ROW EXECUTE FUNCTION prevent_audit_log_modification();

-- Indexes for SIEM queries
CREATE INDEX idx_audit_user_time ON audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_event ON audit_logs(event_type, created_at DESC);
CREATE INDEX idx_audit_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_timestamp ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_ip ON audit_logs(ip_address);
```

---

## Indexes & Performance

### 8.1 Query Performance Indexes

```sql
-- Fast patient lookup
CREATE INDEX idx_patients_birth_year_sex ON patients(birth_year, sex);

-- Encounter time-series queries
CREATE INDEX idx_encounters_patient_date ON encounters(patient_id, encounter_date DESC);

-- Cost analysis queries
CREATE INDEX idx_claims_patient_date_amount ON claims(patient_id, service_date DESC)
    INCLUDE (paid_amount, allowed_amount);

-- Diagnosis/procedure lookups
CREATE INDEX idx_diagnoses_patient_code ON diagnoses(patient_id, icd10_code);
CREATE INDEX idx_procedures_patient_code ON procedures(patient_id, cpt_code);

-- Quality metric queries
CREATE INDEX idx_quality_metric_patient_date ON quality_metrics(metric_name, measurement_end_date DESC, patient_id);

-- Outcome tracking
CREATE INDEX idx_outcomes_patient_type_date ON outcomes(patient_id, outcome_type, event_date DESC);
```

### 8.2 Materialized Views for Common Queries

```sql
-- Patient cost summary (refreshed nightly)
CREATE MATERIALIZED VIEW patient_cost_summary AS
SELECT
    p.patient_id,
    p.birth_year,
    p.sex,
    p.zip_code_prefix,
    COUNT(DISTINCT e.encounter_id) as encounter_count,
    SUM(c.paid_amount) as total_cost,
    AVG(c.paid_amount) as average_claim,
    MAX(c.paid_amount) as max_claim,
    DATE_TRUNC('month', MAX(c.service_date)) as last_service_month
FROM patients p
LEFT JOIN encounters e ON p.patient_id = e.patient_id
LEFT JOIN claims c ON e.encounter_id = c.encounter_id
GROUP BY p.patient_id, p.birth_year, p.sex, p.zip_code_prefix;

CREATE UNIQUE INDEX idx_patient_cost_summary ON patient_cost_summary(patient_id);

-- Quality metrics by facility
CREATE MATERIALIZED VIEW facility_quality_metrics AS
SELECT
    e.facility_id,
    e.facility_name,
    q.metric_name,
    COUNT(*) as total_cases,
    SUM(CAST(q.metric_value AS INT)) as metric_count,
    ROUND(100.0 * SUM(CAST(q.metric_value AS INT)) / COUNT(*), 2) as metric_rate
FROM encounters e
JOIN quality_metrics q ON e.encounter_id = q.encounter_id
GROUP BY e.facility_id, e.facility_name, q.metric_name;

CREATE UNIQUE INDEX idx_facility_quality ON facility_quality_metrics(facility_id, metric_name);
```

### 8.3 Refresh Strategy

```sql
-- Refresh materialized views nightly
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule('refresh-cost-summary', '0 2 * * *',
    'REFRESH MATERIALIZED VIEW CONCURRENTLY patient_cost_summary');

SELECT cron.schedule('refresh-quality-metrics', '0 3 * * *',
    'REFRESH MATERIALIZED VIEW CONCURRENTLY facility_quality_metrics');
```

---

## Data Validation Rules

### 9.1 Constraints & Triggers

```sql
-- Ensure discharge date after admission date
ALTER TABLE encounters ADD CONSTRAINT encounter_dates_valid
    CHECK (discharge_date IS NULL OR discharge_date >= encounter_date);

-- Ensure payment amounts don't exceed allowed
ALTER TABLE claims ADD CONSTRAINT payment_amount_valid
    CHECK (paid_amount <= allowed_amount);

-- Ensure cost date before outcome date
ALTER TABLE outcomes ADD CONSTRAINT outcome_date_valid
    CHECK (event_date >= (SELECT encounter_date FROM encounters WHERE encounter_id = index_encounter_id));

-- Enforce non-negative amounts
ALTER TABLE charges ADD CONSTRAINT positive_charge
    CHECK (total_charge >= 0);

-- Update audit log on any data modification
CREATE OR REPLACE FUNCTION log_data_modification()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_logs (
        user_id, event_type, resource_type, resource_id,
        action, result_status, purpose_code
    ) VALUES (
        CURRENT_USER,
        CASE TG_OP WHEN 'DELETE' THEN 'DATA_DELETION' ELSE 'DATA_MODIFICATION' END,
        TG_TABLE_NAME,
        NEW.patient_id::TEXT,
        TG_OP,
        'SUCCESS',
        'OPERATIONS'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach trigger to clinical tables
CREATE TRIGGER log_diagnosis_modification
AFTER INSERT OR UPDATE OR DELETE ON diagnoses
FOR EACH ROW EXECUTE FUNCTION log_data_modification();

CREATE TRIGGER log_medication_modification
AFTER INSERT OR UPDATE OR DELETE ON medications
FOR EACH ROW EXECUTE FUNCTION log_data_modification();
```

---

## Data Migration & ETL

### 10.1 Sample ETL Logic (Pseudo-Julia Code)

```julia
# Load from source CSV
df_source = CSV.read("hospital_claims.csv", DataFrame)

# Validate data
errors = validate_claims_data(df_source)
!isempty(errors) && @error "Validation failed: $errors"

# Transform
df_transformed = transform_claims_data(df_source)

# De-identify
df_deidentified = deid_safe_harbor(df_transformed)

# Insert into PostgreSQL
using LibPQ

conn = LibPQ.Connection(ENV["DATABASE_URL"])

# Begin transaction
execute(conn, "BEGIN TRANSACTION;")

try
    # Bulk insert
    copy_data(conn, df_deidentified, "claims")

    # Log ingestion
    insert_audit_log(conn, "DATA_INGESTION", "claims", "SUCCESS")

    # Commit
    execute(conn, "COMMIT;")
    @info "Data ingestion complete"
catch e
    execute(conn, "ROLLBACK;")
    @error "Data ingestion failed: $e"
    rethrow()
end
```

---

**END OF DATA DICTIONARY**
