# Profitability & Operations

**Tab E9** — Route: `/profitability`

## Description

The Profitability & Operations tab provides a comprehensive view of hospital financial performance including contribution margin analysis, break-even volume calculation, operating margin tracking, and departmental profitability decomposition. An interactive volume-sensitivity slider allows real-time margin exploration.

## Screenshot

![Profitability & Operations screenshot placeholder](../../screenshots/profitability.png)

## Key Metrics

| Metric | Formula | Description |
|--------|---------|-------------|
| Contribution Margin | Revenue − Variable Costs | Revenue remaining after covering variable costs |
| Break-Even Volume | Fixed Costs ÷ Contribution Margin | Volume multiple needed to cover all fixed costs |
| Operating Margin | Operating Income ÷ Revenue | Percentage of revenue retained as operating income |

## UI Components

- **Financial Inputs form** — asset ID, period, revenue, variable costs, fixed costs, operating income
- **Volume Sensitivity slider** — 50%–150% volume multiplier with real-time KPI updates
- **KPI cards** — contribution margin, break-even volume, operating margin
- **Profitability Waterfall chart** — revenue → variable costs → fixed costs → operating income
- **Departmental Profitability table** — department, revenue, costs, contribution margin, margin %

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/profitability/contrib-margin` | Contribution margin calculation |
| `POST` | `/api/profitability/by-dept` | Department-level profitability |
| `POST` | `/api/profitability/fixed-variable` | Fixed vs. variable cost decomposition |
| `POST` | `/api/profitability/break-even` | Break-even volume analysis |
| `POST` | `/api/profitability/operating-margin` | Operating margin computation |
| `POST` | `/api/profitability/margin-decomp` | Waterfall decomposition of margin drivers |
| `POST` | `/api/profitability/ratios` | Standard profitability ratios |

## Usage Example

```json
POST /api/profitability/break-even
{
  "revenue": 25000000,
  "variable_costs": 15000000,
  "fixed_costs": 8000000,
  "operating_income": 2000000
}
```

Response:
```json
{
  "status": "success",
  "fixed_costs": 8000000.0,
  "contribution_margin": 10000000.0,
  "break_even_volume": 0.8,
  "computed_at": "2024-10-01T12:00:00"
}
```

## Related Files

- Model: `app/views/profitability/ProfitabilityModel.jl`
- View: `app/views/profitability/profitability.jl`
- Controller: `app/controllers/ProfitabilityController.jl`
- Tests: `test/views/test_profitability.jl`
- E2E: `e2e/tests/profitability.spec.ts`
