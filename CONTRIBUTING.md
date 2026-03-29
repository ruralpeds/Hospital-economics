# Contributing to Rural Hospital Economics Simulator

## Development Setup

```bash
# Clone and install dependencies
git clone https://github.com/timothyhartzog/hospital-economics.git
cd hospital-economics
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Run tests
julia --project=. --threads=auto -e 'using Pkg; Pkg.test()'

# Start the dev server
julia --project=. --threads=auto -e 'include("app/app.jl"); using .HospitalEconomicsApp; start()'
```

## Code Style

- Follow [BlueStyle](https://github.com/invenia/BlueStyle) conventions for Julia code
- Use `@kwdef` for structs with many fields
- Prefix private/internal functions with `_` (e.g., `_parse_base_financials`)
- Use multiple dispatch for hospital-type-specific behavior (CAH vs REH vs PPS)
- Domain functions belong in `src/`; web framework code belongs in `app/`

## Architecture Rules

- **Domain independence**: `src/` must never import Genie, Stipple, or any web framework
- **View integration**: Views use `using ...RuralHospitalSim: function_name` to import domain functions
- **API controllers**: Validate inputs, call domain functions, format JSON responses
- **Error handling**: Never expose internal exception details to API clients

## Branch Naming

- `feature/<description>` — new features
- `fix/<description>` — bug fixes
- `docs/<description>` — documentation changes

## Testing

- Unit tests for domain functions go in `test/test_<module>.jl`
- Integration tests (multi-module pipelines) go in `test/test_integration.jl`
- View-domain smoke tests go in `test/test_view_integration.jl`
- All new test files must be added to `test/runtests.jl`

### Test Conventions

- Use factory helpers (`make_test_cah()`, `smoke_test_financials()`) for test fixtures
- Use `isapprox` with explicit tolerances for floating-point comparisons
- Test edge cases: zero values, negative margins, empty collections

## Pull Request Checklist

- [ ] Tests pass locally (`julia --project=. -e 'using Pkg; Pkg.test()'`)
- [ ] New functions are exported in `src/RuralHospitalSim.jl` if needed by views or API
- [ ] API endpoint changes are reflected in `docs/api_reference.md`
- [ ] No hardcoded credentials, file paths, or secrets
- [ ] Input validation for any new API parameters (use `_validated_float`/`_validated_int`)
