# Data Preparation

**Tab E5** — Route: `/data/prepare`

## Description

The Data Preparation tab provides a configurable pipeline for transforming raw ingested assets into analysis-ready datasets. Supported operations include ID normalization, medical code standardization, episode aggregation, risk adjustment, missing-value imputation, and time-series formatting.

## Screenshot

![Data Preparation screenshot placeholder](../../screenshots/data_prepare.png)

## Pipeline Steps

| Transform | Description |
|-----------|-------------|
| `normalize_ids` | Deduplicate and standardize patient/encounter identifiers |
| `standardize_codes` | Map ICD-9 → ICD-10, CPT-4, HCPCS |
| `aggregate` | Bundle claims into episodes (30-day, 90-day, annual) |
| `risk_adjust` | Apply CMS-HCC, ACG, DxCG, or Charlson CCI risk scores |
| `impute` | Fill missing values (median, mean, mode, zero, or drop) |
| `time_series` | Format data into a regular time-series panel |

## UI Components

- **Pipeline Configuration form** — source asset, transform selection, conditional parameters
- **Pipeline Steps table** — step, status, output asset ID
- **Output Preview table** — first 20 rows of the prepared dataset

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/prepare/normalize` | Normalize patient/encounter IDs |
| `POST` | `/api/prepare/standardize` | Standardize medical codes |
| `POST` | `/api/prepare/aggregate` | Aggregate into episodes |
| `POST` | `/api/prepare/risk-adjust` | Apply risk adjustment model |
| `POST` | `/api/prepare/impute` | Impute missing values |
| `POST` | `/api/prepare/time-series` | Format as time-series panel |

## Usage Example

```json
POST /api/prepare/normalize
{
  "source_asset_id": "hcris_2024_q3",
  "id_columns": ["patient_id", "encounter_id"]
}
```

Response:
```json
{
  "status": "success",
  "transform": "normalize_ids",
  "source_asset_id": "hcris_2024_q3",
  "output_asset_id": "hcris_2024_q3_normalized",
  "rows_processed": 0,
  "completed_at": "2024-10-01T12:00:00"
}
```

## Related Files

- Model: `app/views/data_prepare/DataPrepareModel.jl`
- View: `app/views/data_prepare/data_prepare.jl`
- Controller: `app/controllers/PreparationController.jl`
- Tests: `test/views/test_data_prepare.jl`
- E2E: `e2e/tests/data_prepare.spec.ts`
