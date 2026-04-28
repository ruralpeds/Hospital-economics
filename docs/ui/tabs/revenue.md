# Revenue & Reimbursement

**Tab E8** — Route: `/revenue`

## Description

The Revenue & Reimbursement tab analyses total net revenue, claim denial patterns, payer mix composition, and provider-level payment rates. A policy simulation mode allows analysts to model the financial impact of contract rate changes and denial rate adjustments using a waterfall decomposition.

## Screenshot

![Revenue & Reimbursement screenshot placeholder](../../screenshots/revenue.png)

## Key Metrics

| Metric | Description |
|--------|-------------|
| Total Revenue | Net revenue after contractual adjustments |
| Total Denied | Dollar value of denied claims |
| Denial Rate | Denied claims as a percentage of billed |
| Payer Mix | Revenue breakdown by payer category |
| Revenue Waterfall | Gross-to-net waterfall decomposition |

## UI Components

- **Simulation Parameters form** — claims asset, fee schedule asset, scenario, policy knobs
- **KPI cards** — total revenue, total denied, denial rate
- **Payer Mix chart** — pie chart of revenue by payer
- **Payer Mix Detail table** — payer, revenue, % total, denial rate, avg payment
- **Revenue Waterfall chart** — bar chart showing gross-to-net flow
- **Denial Categories table** — denial reason, count, amount, % of denials

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/revenue/total` | Total net revenue from claims asset |
| `POST` | `/api/revenue/denied` | Denial analysis by category and payer |
| `POST` | `/api/revenue/payor-mix` | Revenue breakdown by payer |
| `POST` | `/api/revenue/provider-payment` | Provider payment vs. fee schedule |
| `POST` | `/api/revenue/simulate` | Policy simulation (rate/denial adjustments) |

## Usage Example

```json
POST /api/revenue/simulate
{
  "claims_asset_id": "claims_2024_normalized",
  "fee_schedule_asset_id": "fee_schedule_2024",
  "scenario": "custom",
  "policy_knob_1": 0.05,
  "policy_knob_2": -0.02
}
```

Response:
```json
{
  "status": "success",
  "claims_asset_id": "claims_2024_normalized",
  "scenario": "custom",
  "simulated_revenue": 0.0,
  "simulated_denied": 0.0,
  "waterfall_rows": [],
  "computed_at": "2024-10-01T12:00:00"
}
```

## Related Files

- Model: `app/views/revenue/RevenueModel.jl`
- View: `app/views/revenue/revenue.jl`
- Controller: `app/controllers/RevenueController.jl`
- Tests: `test/views/test_revenue.jl`
- E2E: `e2e/tests/revenue.spec.ts`
