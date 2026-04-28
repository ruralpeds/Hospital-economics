# Cost Analysis

**Tab E7** — Route: `/cost-analysis`

## Description

The Cost Analysis tab computes total cost of care, episode costs, category breakdowns, trend charts, and high-cost patient identification for a selected cohort. Supports confidence intervals, QALY cost calculation, and multi-year cost projections with inflation adjustment.

## Screenshot

![Cost Analysis screenshot placeholder](../../screenshots/cost_analysis.png)

## Key Metrics

| Metric | Description |
|--------|-------------|
| Total Cost | Sum of all category costs with 95% CI |
| Cost per QALY | Total cost divided by quality-adjusted life years |
| High-Cost Patients | Top N% of patients by total cost |
| Cost Breakdown | Inpatient, outpatient, pharmacy, imaging, lab, DME |
| Cost Trend | Time-series of costs over the selected period |

## UI Components

- **Analysis Parameters form** — cohort, dates, cost year, discount rate, high-cost threshold, categories
- **KPI cards** — total cost (with CI), cost per QALY, high-cost patient count
- **Breakdown chart** — stacked bar by cost category
- **Breakdown table** — category, total cost, % of total, PMPM
- **Trend chart** — cost trend over time
- **High-Cost Patients table** — patient ID, total cost, primary DX, payer, admits

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/cost-analysis/total` | Total cost with 95% CI |
| `POST` | `/api/cost-analysis/breakdown` | Breakdown by cost category |
| `POST` | `/api/cost-analysis/per-episode` | Per-episode cost calculation |
| `POST` | `/api/cost-analysis/cpq` | Cost per QALY |
| `POST` | `/api/cost-analysis/high-cost` | High-cost patient identification |
| `POST` | `/api/cost-analysis/project` | Multi-year cost projection |
| `POST` | `/api/cost-analysis/inflate` | Medical inflation adjustment |
| `POST` | `/api/cost-analysis/cohort-summary` | Full cohort cost summary |

## Usage Example

```json
POST /api/cost-analysis/total
{
  "cohort_id": "chf_65plus_2024",
  "date_from": "2024-01-01",
  "date_to": "2024-12-31",
  "discount_rate": 0.03,
  "cost_year": 2024
}
```

Response:
```json
{
  "status": "success",
  "cohort_id": "chf_65plus_2024",
  "total_cost": 0.0,
  "total_cost_ci_low": 0.0,
  "total_cost_ci_high": 0.0,
  "computed_at": "2024-10-01T12:00:00"
}
```

## Related Files

- Model: `app/views/cost_analysis/CostAnalysisModel.jl`
- View: `app/views/cost_analysis/cost_analysis.jl`
- Controller: `app/controllers/CostAnalysisController.jl`
- Tests: `test/views/test_cost_analysis.jl`
- E2E: `e2e/tests/cost_analysis.spec.ts`
