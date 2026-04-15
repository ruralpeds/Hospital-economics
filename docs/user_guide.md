# User Guide — Rural Hospital Economics Simulator

## Getting Started

### Quick Start with Docker

```bash
cd docker/
docker compose up -d
```

The application will be available at `http://localhost:8000`.

### Quick Start with Julia

```bash
julia --project=. -e '
    using Pkg
    Pkg.instantiate()
    include("app/app.jl")
    using .HospitalEconomicsApp
    start(port=8000)
'
```

### Default Login

On first launch, create an organization and admin user through the setup wizard at `/profile`.

---

## Navigation

The application is organized into five major sections:

### Dashboard (`/dashboard`)
Your home screen showing key performance indicators (KPIs) for the currently selected hospital:
- Operating margin trend
- Days cash on hand
- Closure risk score
- Volume trends
- Payer mix breakdown

### Hospital Profile (`/profile`)
Enter and manage your hospital's data:
- **General Information**: Name, CMS provider number, type (CAH/REH/PPS), location
- **Departments**: Add cost centers with revenue and expense data
- **Staffing**: FTE counts by category, vacancy rates, travel dependency
- **Payer Mix**: Medicare, Medicaid, Commercial, Self-Pay percentages
- **Import Data**: Upload from CSV, Excel, or HCRIS cost reports

### Analysis Tools
Interactive calculators for specific financial analyses:

| Tool | Path | What It Does |
|------|------|-------------|
| Financial Simulator | `/financial-sim` | 7-slider real-time projection (the main tool) |
| Cost Structure | `/cost-structure` | Fixed vs. variable cost breakdown |
| Cost-Based Reimbursement | `/cost-reimbursement` | CMS 2552-10 step-down allocation simulator |
| Payer Margin Analysis | `/payer-margin` | Margin by payer type with waterfall |
| Service Line P&L | `/service-lines` | Contribution margin by service line |
| 340B Impact | `/340b` | Drug pricing program financial impact |
| Revenue Cycle | `/revenue-cycle` | Optimization opportunity calculator |
| Break-Even | `/break-even` | Volume needed to cover costs |
| Cash Flow | `/cash-flow` | 12-month cash projection |
| Sensitivity | `/sensitivity` | Tornado diagram of key drivers |
| Debt Capacity | `/debt-capacity` | Maximum borrowing analysis |
| Workforce/RVU | `/workforce` | Provider productivity benchmarking |
| Benchmark Radar | `/benchmark` | Compare to national CAH medians |

### Strategic Tools
Decision support for major strategic choices:

| Tool | Path | What It Does |
|------|------|-------------|
| REH Conversion Wizard | `/conversion` | Model CAH-to-REH conversion |
| Closure Risk | `/closure-risk` | Multi-factor closure risk assessment |
| Staffing Optimizer | `/staffing` | Optimal permanent/travel staff mix |
| Payer Negotiation | `/payer-negotiation` | Contract rate optimization |
| Community Impact | `/community-impact` | Economic impact of hospital on community |
| Strategic Plan | `/strategic-plan` | Multi-year plan with timed initiatives |
| Policy Impact | `/policy` | Toggle policy changes to see financial effects |

### Simulations (`/simulate`)
Run advanced simulations:
1. **Deterministic**: Fixed-assumption projection (fastest)
2. **Monte Carlo**: Probabilistic with confidence intervals (recommended)
3. **Agent-Based**: Emergent behavior modeling (most detailed)
4. **System Dynamics**: Long-term feedback loop analysis
5. **Discrete Event**: ED throughput optimization

### Education Center (`/education`)
Learn about hospital economics through interactive content covering revenue cycles, reimbursement models, financial ratios, staffing economics, and more.

---

## Typical Workflows

### Workflow 1: Annual Strategic Planning

1. **Update hospital profile** with latest fiscal year data
2. Run **Financial Simulator** with baseline assumptions
3. Run **Monte Carlo** to understand uncertainty range
4. Use **Closure Risk** to assess vulnerability
5. Compare scenarios with **Scenario Builder**
6. Export results for board presentation

### Workflow 2: REH Conversion Decision

1. Enter current CAH financials in **Hospital Profile**
2. Run baseline **Deterministic Projection** as CAH
3. Open **REH Conversion Wizard** — enter conversion costs
4. Compare pre/post conversion margins
5. Check **Community Impact** for community effects
6. Run **Monte Carlo** on both scenarios for risk comparison

### Workflow 3: Staffing Crisis Response

1. Update **Staffing** data (current vacancies, travel usage)
2. Run **Staffing Optimizer** to find minimum-cost coverage
3. Check **Financial Simulator** impact of travel costs
4. Use **Workforce/RVU** to benchmark provider productivity
5. Model long-term with **System Dynamics** (staffing death spiral risk)

---

## Working with the API

The simulator exposes a REST API for programmatic access. See [API Reference](api_reference.md) for complete documentation.

### Example: Run a Deterministic Projection via API

```bash
curl -X POST http://localhost:8000/api/simulate/deterministic \
  -H "Content-Type: application/json" \
  -d '{
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
      "projection_years": 5,
      "volume_growth_rate": -0.02
    }
  }'
```

---

## Sample Data

The `/data/sample_hospitals/` directory contains example hospital profiles:

| File | Type | Scenario |
|------|------|----------|
| `sample_cah_25bed.json` | CAH | Typical 25-bed CAH |
| `sample_cah_struggling.json` | CAH | Financially distressed, high travel dependency |
| `sample_cah_system_affiliated.json` | CAH | System-affiliated, strong performance |
| `sample_reh_converted.json` | REH | Post-conversion REH |
| `sample_pps_rural.json` | PPS | Rural PPS with high Medicaid |

Load any sample by importing its JSON through the Hospital Profile page or via the API.

---

## Glossary

| Term | Definition |
|------|-----------|
| **CAH** | Critical Access Hospital — ≤25 beds, 96-hour ALOS limit, cost-based Medicare reimbursement |
| **REH** | Rural Emergency Hospital — No inpatient beds, monthly facility payment + OPPS+5% |
| **PPS** | Prospective Payment System — DRG-based Medicare payment |
| **HCRIS** | Healthcare Cost Reporting Information System — CMS cost report database |
| **CCR** | Cost-to-Charge Ratio — Used in cost-based reimbursement calculations |
| **DSCR** | Debt Service Coverage Ratio — EBITDA / annual debt service |
| **FTE** | Full-Time Equivalent — 2,080 hours/year |
| **OPPS** | Outpatient Prospective Payment System |
| **340B** | Federal drug discount program for eligible hospitals |
| **ALOS** | Average Length of Stay |
| **ADC** | Average Daily Census |
| **CMI** | Case Mix Index — Average DRG weight |
