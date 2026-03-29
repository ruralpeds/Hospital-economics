# API Reference — Rural Hospital Economics Simulator

## Base URL

All API endpoints are served from the application root. In development: `http://localhost:8000`

## Authentication

API endpoints do not currently enforce authentication. Production deployments should configure GenieAuthentication.jl with session-based or token-based auth before exposing the application to untrusted networks.

## Security

### Error Responses

API errors return a generic message without internal details:

```json
{
  "status": "error",
  "message": "Deterministic simulation failed. Check server logs for details."
}
```

Full exception details are logged server-side only.

### File Import Restrictions

File import endpoints (`/api/import/*`) restrict access to server-side directories:
- `data/uploads/` — user-uploaded files
- `data/reference/` — CMS reference data
- `data/sample/` — sample hospital profiles

Paths outside these directories are rejected. File export filenames are sanitized to prevent directory traversal.

### Rate Limiting (via Nginx)

| Endpoint | Limit | Burst |
|----------|-------|-------|
| `/api/*` | 30 req/s per IP | 50 |
| `/api/simulate/*` | 5 req/min per IP | 3 |

### CORS

Controlled by the `ALLOWED_ORIGIN` environment variable. Defaults to `*` in development; must be set to the specific domain in production.

### Required Environment Variables (Production)

| Variable | Description |
|----------|-------------|
| `SECRET_TOKEN` | Session signing key (64+ chars). Application will not start without this. |
| `ALLOWED_ORIGIN` | CORS allowed origin domain |
| `POSTGRES_PASSWORD` | Database password |

---

## Health Check

### `GET /api/health`

Returns application status and available engines.

**Response:**
```json
{
  "status": "ok",
  "version": "0.3.0",
  "timestamp": "2026-03-29T12:00:00",
  "engines": ["deterministic", "monte_carlo", "abm", "system_dynamics", "des"],
  "optimizers": ["staffing", "portfolio"],
  "risk_models": ["closure_risk", "reh_conversion"],
  "tools": 38
}
```

---

## Simulation Engines

### `POST /api/simulate/deterministic`

Run a deterministic multi-year financial projection with fixed growth assumptions.

**Request Body:**
```json
{
  "base_financials": {
    "inpatient_revenue": 8000000,
    "outpatient_revenue": 12000000,
    "salary_expense": 11000000,
    "supply_expense": 3000000,
    "other_expense": 4000000,
    "cash_reserves": 5000000,
    "depreciation": 1200000,
    "annual_debt_service": 800000,
    "payer_mix_government": 0.73
  },
  "params": {
    "projection_years": 10,
    "volume_growth_rate": -0.01,
    "cost_inflation_rate": 0.03,
    "salary_inflation_rate": 0.035,
    "supply_inflation_rate": 0.04,
    "reimbursement_adjustment": 0.015,
    "payer_mix_shift": 0.005
  }
}
```

**Response:**
```json
{
  "status": "success",
  "engine": "deterministic",
  "run_id": "uuid",
  "timestamp": "2026-03-29T12:00:00",
  "cumulative_operating_income": -5234000.00,
  "terminal_operating_margin": -0.0812,
  "closure_risk_year": null,
  "projections": [
    {
      "year": 1,
      "inpatient_revenue": 7999000,
      "outpatient_revenue": 12180000,
      "total_revenue": 20179000,
      "total_expense": 20450000,
      "operating_income": -271000,
      "operating_margin": -0.0134,
      "days_cash_on_hand": 84.5,
      "debt_service_coverage": 1.16,
      "patient_volume": 0.99,
      "payer_mix_government": 0.735
    }
  ]
}
```

### `POST /api/simulate/monte-carlo`

Run a Monte Carlo stochastic simulation with configurable distributions.

**Request Body:**
```json
{
  "base_financials": { "...same as deterministic..." },
  "params": {
    "n_iterations": 1000,
    "projection_years": 5,
    "random_seed": 42
  }
}
```

**Response:**
```json
{
  "status": "success",
  "engine": "monte_carlo",
  "run_id": "uuid",
  "n_iterations": 1000,
  "mean_terminal_margin": -0.0234,
  "median_terminal_margin": -0.0198,
  "probability_of_loss": 0.6540,
  "percentiles": {
    "p5": -0.1200,
    "p25": -0.0580,
    "p50": -0.0198,
    "p75": 0.0120,
    "p95": 0.0680
  }
}
```

### `POST /api/simulate/abm`

Run an agent-based model with patient, provider, and competitor agents.

**Request Body:**
```json
{
  "params": {
    "n_patients": 500,
    "n_providers": 20,
    "simulation_days": 365,
    "random_seed": 42
  },
  "hospitals": []
}
```

### `POST /api/simulate/system-dynamics`

Run a system dynamics ODE simulation modeling feedback loops.

**Request Body:**
```json
{
  "params": {
    "time_horizon_years": 10.0,
    "volume_growth_rate": -0.02,
    "revenue_per_patient": 3500.0,
    "cost_per_fte": 85000.0,
    "staff_turnover_rate": 0.15,
    "quality_volume_elasticity": 0.3,
    "community_health_impact": 0.1
  }
}
```

### `POST /api/simulate/des`

Run a discrete event simulation of ED throughput using Erlang-C queueing.

**Request Body:**
```json
{
  "params": {
    "simulation_hours": 720,
    "mean_arrival_rate": 2.5,
    "mean_triage_time": 0.25,
    "mean_treatment_time": 2.0,
    "mean_admission_time": 4.0,
    "ed_beds": 8,
    "admit_probability": 0.15,
    "random_seed": 42
  }
}
```

---

## Optimization

### `POST /api/optimize/staffing`

Solve a mixed-integer staffing optimization minimizing total cost.

**Request Body:**
```json
{
  "departments": ["ed", "nursing", "lab", "radiology"],
  "shifts": ["day", "evening", "night"],
  "demand": {
    "ed_day": 6.0,
    "ed_evening": 4.0,
    "ed_night": 3.0,
    "nursing_day": 8.0,
    "nursing_evening": 6.0,
    "nursing_night": 4.0
  },
  "permanent_salary": {
    "ed": 75000,
    "nursing": 68000,
    "lab": 62000,
    "radiology": 65000
  },
  "regulatory_minimums": {
    "ed": 2.0
  },
  "budget": 10000000,
  "travel_salary_premium": 1.8,
  "overtime_rate": 1.5,
  "max_overtime_fraction": 0.2
}
```

### `POST /api/optimize/portfolio`

Solve a service line portfolio optimization maximizing contribution margin.

**Request Body:**
```json
{
  "services": ["ed", "primary_care", "lab", "imaging", "surgery", "obstetrics"],
  "revenue_per_unit": { "ed": 2500, "primary_care": 350, "lab": 120, "imaging": 450, "surgery": 8500, "obstetrics": 12000 },
  "cost_per_unit": { "ed": 2200, "primary_care": 280, "lab": 80, "imaging": 320, "surgery": 7200, "obstetrics": 10500 },
  "volume_potential": { "ed": 8000, "primary_care": 15000, "lab": 40000, "imaging": 12000, "surgery": 800, "obstetrics": 200 },
  "capacity_requirement": { "ed": 10, "primary_care": 8, "lab": 5, "imaging": 6, "surgery": 12, "obstetrics": 15 },
  "total_capacity": 50,
  "fixed_costs": { "ed": 500000, "primary_care": 200000, "lab": 150000, "imaging": 300000, "surgery": 800000, "obstetrics": 600000 },
  "required_services": ["ed"],
  "community_need_weight": 0.2
}
```

---

## Risk Assessment

### `POST /api/risk/closure`

Compute a multi-factor closure risk assessment.

**Request Body:**
```json
{
  "hospital_type": "cah",
  "hospital_name": "Sample Hospital",
  "financial_data": {
    "total_revenue": 20000000,
    "total_expenses": 21000000,
    "operating_margin": -0.05,
    "cash": 3000000,
    "long_term_debt": 8000000
  },
  "operational_data": {
    "licensed_beds": 25,
    "average_daily_census": 5.0,
    "average_length_of_stay": 3.2
  },
  "market_data": {
    "service_area_pop": 15000,
    "pop_growth_rate": -0.005,
    "competing_hospitals": 1,
    "nearest_competitor_miles": 30.0,
    "medicaid_expansion": true
  }
}
```

**Response:**
```json
{
  "status": "success",
  "type": "closure_risk",
  "risk_score": 62.5,
  "risk_tier": "medium_high",
  "financial_risk": 72.0,
  "operational_risk": 55.0,
  "market_risk": 48.0,
  "workforce_risk": 65.0,
  "policy_risk": 40.0,
  "top_risk_drivers": ["Negative operating margin", "High debt-to-cap ratio"],
  "mitigation_factors": ["Medicaid expansion state", "Sole community provider"],
  "years_to_distress": 4.2
}
```

### `POST /api/conversion`

Analyze CAH-to-REH conversion financial impact.

**Request Body:**
```json
{
  "hospital_name": "Sample CAH",
  "licensed_beds": 25,
  "base_revenue": 20000000,
  "base_costs": 21000000,
  "nearest_inpatient_miles": 30.0,
  "conversion_params": {
    "severance_cost": 500000,
    "facility_modification_cost": 1000000,
    "ip_volume_loss_pct": 1.0,
    "op_volume_retention_pct": 0.85,
    "ed_volume_change_pct": 0.05,
    "transition_months": 12
  }
}
```

---

## Data Import/Export

### `POST /api/import/hcris`

Parse a HCRIS cost report file from the server filesystem.

**Request Body:**
```json
{
  "filepath": "/app/data/hcris_sample/sample_hcris_extract.csv",
  "provider_filter": "171301"
}
```

### `POST /api/import/csv`

Import hospital data from a CSV file.

**Request Body:**
```json
{
  "filepath": "/app/data/sample_hospitals/hospitals.csv",
  "hospital_type": "cah"
}
```

### `POST /api/export/csv`

Export result data to CSV format.

**Request Body:**
```json
{
  "results": [{"year": 1, "margin": -0.02}, {"year": 2, "margin": -0.04}],
  "filename": "my_projection.csv",
  "columns": ["year", "margin"]
}
```

### `POST /api/export/json`

Export result data to JSON format.

**Request Body:**
```json
{
  "results": {"scenario": "baseline", "projections": [...]},
  "filename": "my_results.json"
}
```

---

## Error Responses

All endpoints return errors in this format:

```json
{
  "status": "error",
  "message": "Description of what went wrong"
}
```

HTTP status codes:
- `200` — Success
- `400` — Bad request (invalid parameters, missing required fields)
- `500` — Internal server error
