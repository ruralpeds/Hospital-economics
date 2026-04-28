# Data Intake

**Tab E4** — Route: `/data/intake`

## Description

The Data Intake tab provides a unified interface for ingesting hospital, claims, clinical, financial, and registry data into the Rural Hospital Economics Simulator. Uploaded files are staged as versioned data assets, optionally de-identified, and validated against configurable rule sets before being committed.

## Screenshot

![Data Intake screenshot placeholder](../../screenshots/data_intake.png)

## Supported Sources

| Source | Formats | Key Fields |
|--------|---------|-----------|
| Hospital (HCRIS) | `.csv`, `.rpt`, `.xlsx` | Facility ID, cost report period |
| Claims (UB-04 / 837I) | `.csv`, `.xlsx`, `.json` | Payer ID, service dates |
| Clinical (EHR / FHIR) | `.json`, `.jsonl`, `.parquet` | EHR system, encounter dates |
| Financial (GL / Trial Balance) | `.csv`, `.xlsx` | Facility ID, fiscal period |
| Registry | `.csv`, `.xlsx`, `.json` | Registry name, cohort filters |

## UI Components

- **Upload stepper** — drag-and-drop multi-format uploader (up to 500 MB)
- **Source Configuration form** — source type, date range, facility/payer/EHR fields
- **Validation Rules panel** — toggles for schema, ICD-10, CPT, encounter rules
- **Recent Uploads table** — asset ID, source, row count, PHI flag, ingestion timestamp

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/ingest/hospital` | Ingest a hospital cost-report asset |
| `POST` | `/api/ingest/claims` | Ingest a claims (UB-04/837I) asset |
| `POST` | `/api/ingest/clinical` | Ingest a clinical (EHR/FHIR) asset |
| `POST` | `/api/ingest/financial` | Ingest a financial (GL) asset |
| `POST` | `/api/ingest/registry` | Ingest a registry asset |
| `POST` | `/api/ingest/validate` | Run validation rules on a committed asset |

## Usage Example

```json
POST /api/ingest/hospital
{
  "asset_id": "hcris_2024_q3",
  "facility_id": "050001",
  "date_from": "2024-01-01",
  "date_to": "2024-09-30"
}
```

Response:
```json
{
  "status": "success",
  "source": "hospital",
  "asset_id": "hcris_2024_q3",
  "facility_id": "050001",
  "ingested_at": "2024-10-01T12:00:00"
}
```

## Related Files

- Model: `app/views/data_intake/DataIntakeModel.jl`
- View: `app/views/data_intake/data_intake.jl`
- Controller: `app/controllers/IngestionController.jl`
- Tests: `test/views/test_data_intake.jl`
- E2E: `e2e/tests/data_intake.spec.ts`
