# RuralCore.jl

**Foundation package for RuralHealthPlatform.jl**

RuralCore provides shared domain types, geographic identifiers, error handling, validation utilities, and enterprise infrastructure patterns used across all packages in the RuralHealthPlatform.

## Purpose

- **Domain types**: Hospital, PayerMix, QualityMetric, County, Region
- **Geographic keys**: CountyKey, TimeKey, CountyYearKey
- **Error handling**: Typed exception hierarchy (RuralHealthError and 12 subtypes)
- **Enterprise patterns**: Audit logging (@audited_calculation), mutation tracking (log_create/update/delete), clinical references (@cited)
- **Validation**: Input validation utilities, constants, configuration
- **Authentication**: Basic auth infrastructure for multi-tenant system

## Key Exports

### Exception Types
```julia
using RuralCore

# All exceptions inherit from RuralHealthError
throw(DataValidationError("message"))
throw(DomainValidationError("field", "value", "constraint", "message"))
throw(CalculationError("result is NaN"))
```

### Types
```julia
hospital = Hospital(id="H001", beds=100)
county = County(fips="06001", name="Alameda County")
payer_mix = PayerMix(medicare=0.4, medicaid=0.35, private=0.20, uninsured=0.05)
```

### Audit Logging
```julia
result = @audited_calculation ingest_data(filepath)
save_audit_log("audit_2024.jsonl")
```

### Mutation Tracking
```julia
log_create("Hospital", "H001", "{...}", "Initial load from CMS file")
log_update("Hospital", "H001", old_state, new_state, "Capacity expansion")
```

## Testing

```bash
julia --project=packages/RuralCore -e 'using Pkg; Pkg.test()'
```

## Documentation

See [CLAUDE.md](../../CLAUDE.md) for:
- Enterprise infrastructure patterns (errors, audit, mutations)
- Standard test patterns (error_tests.jl, audit_tests.jl)
- Adding new exception types

## Dependencies

- Julia 1.12+
- Dates (stdlib)
- UUIDs (stdlib)
- JSON3 (external)
