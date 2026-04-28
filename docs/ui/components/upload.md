# Upload Component — Universal File Intake

> **Location:** `app/components/upload.jl`
> **API route:** `POST /api/data/upload`
> **Issue:** [E2 — Reusable Upload component](https://github.com/timothyhartzog/Hospital-economics/issues)

---

## Overview

The `upload` component is a reusable, HIPAA-aware, 6-step Quasar stepper
widget for ingesting data from any of the supported file formats into the
platform. It is used on the **Data Intake** tab (`/data/intake`, E4) and can
be dropped into any tab that needs to accept user-supplied data.

```julia
using ...Upload   # app/components/upload.jl

# Minimal call — all defaults
upload()

# Full call
upload(
    id         = :my_upload,    # reactive model field prefix
    schema     = "patient",     # target schema for column mapping
    on_committed = "my_handler", # server-side callback after commit
    allow_phi  = false,         # always de-identify PHI (recommended)
    max_mb     = 500,           # server-side size cap (MB)
)
```

The component returns an HTML string (Quasar `q-stepper`). Paste it into the
`ui_*` function of any tab view.

---

## Supported Formats

| Extension         | Format                    | Parser                  |
|-------------------|---------------------------|-------------------------|
| `.csv`            | Comma-separated values    | stdlib (built-in)       |
| `.tsv`            | Tab-separated values      | stdlib (built-in)       |
| `.xls` / `.xlsx`  | Microsoft Excel           | `XLSX.jl`               |
| `.json`           | JSON array of objects     | stdlib (built-in)       |
| `.jsonl`          | JSON Lines (NDJSON)       | stdlib (built-in)       |
| `.parquet`        | Apache Parquet            | `Parquet2.jl` (opt.)    |
| `.feather`        | Apache Arrow/Feather      | `Arrow.jl` (opt.)       |
| `.sav`            | SPSS portable             | `ReadStatTables.jl` (opt.) |
| `.dta`            | Stata dataset             | `ReadStatTables.jl` (opt.) |
| `.sas7bdat`       | SAS dataset               | `ReadStatTables.jl` (opt.) |
| `.rpt` / `.csv`   | HCRIS cost report         | stdlib (CSV parser)     |

> **Note:** Formats marked *(opt.)* require the corresponding Julia package to
> be installed. If the package is absent, the server returns a clear error
> message instructing the user to install it.

---

## Stepper Steps

### Step 1 — Drop File

A `q-uploader` widget accepting a single file up to `max_mb` MB. The MIME
filter allows all supported extensions. Uploads are staged to a temporary path
on the server before any processing begins.

**Server-side:** The maximum file size is enforced again at `POST /api/data/upload`
regardless of the browser-side cap. A file exceeding `max_mb` returns:

```json
{ "status": "error", "message": "File too large: X.X MB (limit: 500 MB)" }
```

### Step 2 — Preview

The first 20 rows are parsed and displayed in a `q-table`. Each column shows:

- **Inferred type** (string, numeric, date, boolean)
- **% missing** values — progress bar colour-coded green / amber / red
- **PHI badge** — columns matching HIPAA identifier patterns are badged in red

PHI detection covers all 18 HIPAA Safe Harbor identifiers via regex matching
on both column names *and* sample values (SSN pattern, email, phone, etc.).

### Step 3 — Map Columns

A side-by-side list lets users select a **target schema field** for each
source column via a `q-select` dropdown.

- Click **Save template** to persist the mapping to
  `data/templates/<schema>_mapping.json`.
- Click **Load template** to auto-populate the mapping from a previously saved
  template. This enables one-click mapping for repeat uploads with the same
  schema.

### Step 4 — Validate

Clicking **Run Validation** calls the domain-layer validators:

| Rule | Function |
|------|----------|
| ICD-10 codes | `validate_icd10_code` |
| CPT codes | `validate_cpt_code` |
| Patient encounter coherence | `validate_patient_encounter` |
| Batch encounters | `validate_encounters_batch` |
| Data source | `validate_data_source` |

Results are shown per-rule as red / amber / green badges with row counts.
Clicking a badge opens a drill-down table of the offending rows.

### Step 5 — De-identify

If PHI was detected (Step 2), a banner prompts the user. The **De-identification ON/OFF**
toggle defaults to **ON** (unless `allow_phi=true` is passed to `upload()`).

- PHI columns are pseudonymised using SHA-256 HMAC with the organisation salt.
- The salt is stored server-side and never logged.
- Same patient across multiple ingestions → same pseudonym (linkable within
  the organisation, unbreakable across organisations).

### Step 6 — Commit

Clicking **Commit Upload** calls `POST /api/data/upload` which:

1. Re-validates file path and size.
2. Parses the file with the appropriate backend.
3. Applies de-identification to PHI columns (if enabled).
4. Writes committed data to `data/uploads/<uuid>/data.csv`.
5. Writes metadata to `data/uploads/<uuid>/meta.json`.
6. Appends an audit log entry to `data/uploads/audit.log`.
7. Returns a `DataAsset` record.

The **Asset ID** is displayed with a copy-to-clipboard button. It is passed
back to the calling tab via the `on_committed` callback.

---

## API Reference

### `POST /api/data/upload`

**Request body** (JSON):

```json
{
  "filepath":    "/tmp/staged_abc123.csv",
  "filename":    "patient_data_2024q1.csv",
  "schema":      "patient",
  "deidentify":  true,
  "org_salt":    "MyHospital2024SecretSalt",
  "user_id":     "analyst@hospital.org",
  "max_mb":      500
}
```

**Success response** (200):

```json
{
  "status":           "success",
  "type":             "universal_upload",
  "asset_id":         "3f2a7b1c-...",
  "original_filename": "patient_data_2024q1.csv",
  "format":           "csv",
  "schema":           "patient",
  "upload_dir":       "data/uploads/3f2a7b1c-.../",
  "row_count":        4200,
  "column_names":     ["patient_id", "admission_date", "..."],
  "phi_detected":     true,
  "phi_columns":      ["first_name", "last_name", "dob", "ssn"],
  "deidentified":     true,
  "deidentify_log":   ["De-identified 4 PHI column(s): ..."],
  "audit_entry_id":   "a1b2c3d4-...",
  "committed_at":     "2024-01-15T14:32:00.000"
}
```

**Error response** (200, `status: "error"`):

```json
{
  "status":  "error",
  "message": "File too large: 612.3 MB (limit: 500 MB)"
}
```

---

## Reactive Model Fields

Add the following fields to any `@app` model that embeds the upload component.
Use `upload_model_fields("my_prefix")` to generate them:

```julia
@app DataIntakeModel begin
    # Paste output of upload_model_fields("upload") here
    @in  upload_step::Int = 1
    @in  upload_file_staged::Bool = false
    @in  upload_filename::String = ""
    # … (see upload_model_fields() for the full list)
end
```

---

## Usage Example

```julia
# app/views/data_intake/DataIntakeModel.jl
@app DataIntakeModel begin
    # Upload component fields (prefix "upload")
    @in  upload_step::Int = 1
    @in  upload_file_staged::Bool = false
    @in  upload_filename::String = ""
    @out upload_asset_id::String = ""
    # … (copy all fields from upload_model_fields("upload"))

    # Tab-specific outputs
    @out intake_message::String = ""
end

# app/views/data_intake/data_intake.jl
function ui_data_intake(model)
    page(model, class="data-intake-page") do
        quasar(:q__layout) do
            quasar(:q__page_container) do
                quasar(:q__page, class="q-pa-lg") do
                    quasar(:q__card) do
                        quasar(:q__card_section) do
                            h5("Data Intake")
                        end
                        quasar(:q__card_section) do
                            # Embed the Upload component
                            raw_html(upload(
                                id         = :upload,
                                schema     = "patient",
                                on_committed = "handle_intake_committed",
                                allow_phi  = false,
                                max_mb     = 500,
                            ))
                        end
                    end
                end
            end
        end
    end
end
```

---

## Testing

### Unit Tests

```bash
julia --compiled-modules=no --startup-file=no test/components/upload_test.jl
```

Covers:

- Extension normalisation for all 12+ supported formats
- CSV / TSV / JSON / JSONL round-trip parsing
- PHI column and value sniffing
- Pseudonymisation determinism and collision resistance
- CSV write round-trip
- Size enforcement logic
- End-to-end payload simulation (CSV and JSONL)

### Playwright E2E Tests

```bash
npx playwright test e2e/tests/upload.spec.ts
```

Requires a running Genie server on `http://localhost:8000`. Tests:

- `POST /api/data/upload` with CSV, TSV, JSON, JSONL fixtures
- PHI detection and de-identification flags in response
- Error handling (missing filepath, non-existent file, oversized file)
- `audit_entry_id` UUID in committed response

---

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Same `upload(...)` call works on any tab | ✅ |
| All 9+ formats supported | ✅ (12 formats) |
| Maximum upload size enforced server-side | ✅ (configurable, default 500 MB) |
| PHI columns flagged automatically | ✅ (column names + value patterns) |
| De-identified before commit by default | ✅ (`deidentify=true` default) |
| Saved column mappings auto-populate | ✅ (templates in `data/templates/`) |
| Audit log entry created for every commit | ✅ (`data/uploads/audit.log`) |
| Unit tests green | ✅ |
| E2E tests | ✅ (requires server) |
