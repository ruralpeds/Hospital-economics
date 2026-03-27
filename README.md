# Rural Hospital Economics Simulator

A pure Julia web application for modeling, simulating, and analyzing the financial viability of rural hospitals in the United States.

## Overview

Built with Genie.jl and Stipple.jl, this simulator provides rural hospital administrators, policymakers, and researchers with tools to:

- **Financial Projection**: Deterministic multi-year financial modeling based on CMS cost report methodology
- **Monte Carlo Simulation**: Probabilistic analysis with configurable parameter distributions
- **Agent-Based Modeling**: Patient, provider, and payer agent interactions using Agents.jl
- **System Dynamics**: Feedback loop modeling with DifferentialEquations.jl
- **Mathematical Optimization**: Staffing and service line optimization with JuMP.jl
- **Closure Risk Prediction**: Multi-factor logistic regression risk assessment
- **REH Conversion Analysis**: Critical Access Hospital to Rural Emergency Hospital conversion decision support

## Quick Start

```bash
# Clone the repository
git clone https://github.com/timothyhartzog/hospital-economics.git
cd hospital-economics

# Start with Docker
docker-compose -f docker/docker-compose.yml up

# Or run directly with Julia
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. --threads=auto app/app.jl
```

The application will be available at `http://localhost:8000`.

## Architecture

```
src/                          # Core simulation library
├── RuralHospitalSim.jl       # Main module
├── types/                    # Domain type system
├── engines/                  # Simulation engines
├── reimbursement/            # Payment model implementations
└── data/                     # Data import/export

app/                          # Genie.jl web application
├── app.jl                    # Application entry point
├── routes.jl                 # URL routing
├── views/                    # Stipple.jl reactive UI modules
├── controllers/              # API controllers
└── config/                   # Application configuration

docker/                       # Deployment
├── Dockerfile
├── docker-compose.yml
└── nginx.conf

test/                         # Test suite
```

## Key Technologies

- **Julia 1.10+** — High-performance scientific computing
- **Genie.jl + Stipple.jl** — Reactive web framework
- **Agents.jl** — Agent-based modeling
- **DifferentialEquations.jl** — System dynamics ODE solver
- **JuMP.jl + HiGHS** — Mathematical optimization
- **PlotlyBase + StipplePlotly** — Interactive visualization

## Data Sources

- CMS HCRIS Cost Reports (Form 2552-10)
- Chartis Rural Hospital Vulnerability Index
- CMS Provider of Services files
- American Hospital Association Annual Survey

## License

MIT License — See [LICENSE](LICENSE) for details.
