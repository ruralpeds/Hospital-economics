# Rural Hospital Economics Simulator

A pure Julia web application for modeling, simulating, and analyzing the financial viability of rural hospitals in the United States.

## Overview

Built with Genie.jl and Stipple.jl, this simulator provides rural hospital administrators, policymakers, and researchers with tools to:

- **Financial Projection**: Deterministic multi-year financial modeling based on CMS cost report methodology
- **Monte Carlo Simulation**: Probabilistic analysis with configurable parameter distributions
- **Agent-Based Modeling**: Patient, provider, and payer agent interactions using Agents.jl
- **System Dynamics**: Feedback loop modeling with DifferentialEquations.jl
- **Discrete Event Simulation**: ED patient flow and resource queueing with ConcurrentSim.jl
- **Mathematical Optimization**: Staffing, service portfolio, and capital prioritization with JuMP.jl
- **Closure Risk Prediction**: Multi-factor composite scoring and ML-based vulnerability assessment
- **REH Conversion Analysis**: Critical Access Hospital to Rural Emergency Hospital decision support

## Quick Start

```bash
# Clone the repository
git clone https://github.com/timothyhartzog/hospital-economics.git
cd hospital-economics

# Start with Docker
docker-compose -f docker/docker-compose.yml up

# Or run directly with Julia
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. --threads=auto -e 'include("app/app.jl"); using .HospitalEconomicsApp; start()'
```

The application will be available at `http://localhost:8000`.

## Architecture

```
src/                              # Core simulation library (RuralHospitalSim module)
├── RuralHospitalSim.jl           # Main module with exports
├── models/                       # Domain types (hospital, financial, staffing, payer)
├── finance/                      # Cost reports, reimbursement, ratios, 340B, VBC, telehealth
├── simulation/                   # 5 simulation engines + scenario framework
├── optimization/                 # JuMP.jl staffing, portfolio, capital scoring
├── risk/                         # Closure prediction, REH conversion, disaster resilience
├── analysis/                     # Community impact, SDOH, geographic access, network economics
├── data/                         # HCRIS parser, CSV/JSON import/export, benchmarks
└── utils/                        # Constants, validation, formatting

app/                              # Genie.jl web application
├── app.jl                        # Application entry point (HospitalEconomicsApp module)
├── routes.jl                     # URL routing (38 tools + 14 API endpoints)
├── views/                        # 33 Stipple.jl reactive view models
├── controllers/                  # API controllers (simulation, optimization, risk, data)
├── config/                       # Environment config (dev/prod), logging
└── public/                       # Static assets (JS, CSS)

docker/                           # Deployment
├── Dockerfile                    # Multi-stage Julia 1.11 build
├── docker-compose.yml            # Full stack (app + PostgreSQL + Redis + Nginx)
└── nginx.conf                    # Reverse proxy with rate limiting and security headers

test/                             # 44 test files
├── runtests.jl                   # Test harness
├── test_*.jl                     # Unit, integration, and view-domain smoke tests

docs/                             # Documentation
├── api_reference.md              # REST API documentation
├── methodology.md                # Simulation methodology and mathematical formulations
└── user_guide.md                 # User workflows and glossary

data/                             # Reference data and samples
├── reference/                    # CMS wage index, payer mix defaults, REH conversion params
├── benchmarks/                   # National CAH benchmarks, closure risk thresholds
├── sample_hospitals/             # 5 sample hospital profiles (JSON)
└── hcris_sample/                 # Synthetic HCRIS data for testing
```

## Key Technologies

- **Julia 1.11+** — High-performance scientific computing
- **Genie.jl + Stipple.jl** — Reactive web framework with two-way data binding
- **StippleUI.jl** — Quasar/Vue component library
- **StipplePlotly.jl** — Interactive Plotly.js charts
- **Agents.jl** — Agent-based modeling
- **DifferentialEquations.jl** — System dynamics ODE solver
- **ConcurrentSim.jl** — Discrete event simulation
- **JuMP.jl + HiGHS** — Mathematical optimization (MIP)
- **Distributions.jl** — Probability distributions for Monte Carlo

## Interactive Tools (38)

| Category | Tools |
|----------|-------|
| **Dashboard & Profile** | Dashboard, Hospital Profile |
| **Simulation** | Scenario Builder, Simulation Runner, Results Viewer |
| **Financial Analysis** | Cost Structure, Cost Reimbursement, Payer Margin, Break-Even, Cash Flow, Debt Capacity, Revenue Cycle, Sensitivity |
| **Programs & Policy** | 340B Program, TEAM Bundled Payment, VBC Transition, Medicaid Supplemental, Policy Impact |
| **Strategic** | REH Conversion Wizard, Closure Risk, Staffing Optimizer, Service Line, Capital Scoring, Strategic Planner |
| **Community** | Community Impact, Community Benefit, SDOH, Geographic Access, Network Economics |
| **Operations** | Telehealth ROI, RHC Optimization, Workforce RVU, Payer Negotiation, Disaster Resilience |
| **Education** | Education Center (topics, glossary, tutorials) |

## Data Sources

- CMS HCRIS Cost Reports (Form 2552-10)
- Chartis Rural Hospital Vulnerability Index
- CMS Provider of Services files
- American Hospital Association Annual Survey
- Flex Monitoring Team financial benchmarks

## Documentation

- [API Reference](docs/api_reference.md) — REST endpoints for simulation, optimization, risk, and data
- [Methodology](docs/methodology.md) — Mathematical formulations for all 6 simulation engines
- [User Guide](docs/user_guide.md) — Workflows, tool descriptions, and glossary
- [Deployment Guide](DEPLOYMENT.md) — Production setup, Docker, SSL, and security configuration

## License

MIT License — See [LICENSE](LICENSE) for details.
