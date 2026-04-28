# Cohort Builder

**Tab E6** — Route: `/cohorts`

## Description

The Cohort Builder enables analysts to define patient cohorts using rich inclusion and exclusion criteria—age range, diagnosis codes (ICD-10), procedure codes (CPT), payer mix, length of stay, date range, and cost thresholds. Cohorts can be previewed, named, saved, and reused across analysis tabs.

## Screenshot

![Cohort Builder screenshot placeholder](../../screenshots/cohorts.png)

## Cohort Criteria

### Inclusion
- Age range (min/max)
- Diagnosis codes (ICD-10 prefix search)
- Procedure codes (CPT prefix search)
- Payers (Medicare, Medicaid, Commercial, Self-Pay, Other)
- Length of stay (min/max days)
- Encounter date range
- Total cost range

### Exclusion
- Diagnosis codes to exclude
- Procedure codes to exclude

## UI Components

- **Cohort Metadata form** — asset ID, cohort name, description
- **Matching Patients KPI** — live count after preview
- **Inclusion Criteria form** — all inclusion parameters
- **Exclusion Criteria form** — DX/PX exclusions
- **Patient Preview table** — patient ID, age, payer, LOS, cost, primary DX
- **Saved Cohorts table** — ID, name, description, patient count

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/cohorts/preview` | Run criteria and return matching count + preview |
| `POST` | `/api/cohorts/save` | Persist a named cohort definition |
| `GET`  | `/api/cohorts` | List all saved cohorts |
| `GET`  | `/api/cohorts/:id` | Retrieve a cohort by ID |
| `DELETE` | `/api/cohorts/:id` | Delete a cohort by ID |

## Usage Example

```json
POST /api/cohorts/preview
{
  "asset_id": "claims_2024_normalized",
  "inclusion_age_min": 65,
  "inclusion_age_max": 120,
  "inclusion_payers": ["medicare"],
  "inclusion_los_min": 3,
  "inclusion_dx": ["I25", "I50"]
}
```

Response:
```json
{
  "status": "success",
  "asset_id": "claims_2024_normalized",
  "matching_count": 0,
  "preview_rows": [],
  "cohort_stats": { "age_min": 65, "age_max": 120, "los_min": 3, "los_max": 365 }
}
```

## Related Files

- Model: `app/views/cohorts/CohortsModel.jl`
- View: `app/views/cohorts/cohorts.jl`
- Controller: `app/controllers/CohortsController.jl`
- Tests: `test/views/test_cohorts.jl`
- E2E: `e2e/tests/cohorts.spec.ts`
