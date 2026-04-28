# Migration Guide — Upgrading to HospitalFinanceToolbox.jl v1.0

This guide covers breaking changes and migration steps for users upgrading from
pre-release versions (v0.x) of the Hospital Economics platform to the stable
v1.0 API.

---

## Overview

v1.0 introduces a stable, semantic-versioned public API. Most internal APIs have
been stabilized, but several function signatures and struct field names were
corrected for consistency before the API freeze. If you are starting fresh with
v1.0, you do not need this guide.

---

## Breaking Changes by Module

### 1. Episode Costing (`episode/Episode.jl`)

#### `Episode` constructor

**Before (v0.x):**
```julia
episode = Episode(
    "EP001",          # positional: episode_id
    "PT001",          # positional: patient_id
    Date(2024,1,1),   # positional: admission_date
    Date(2024,1,6),   # positional: discharge_date
    "I10",            # positional: primary_diagnosis
    "291",            # positional: drg_code
    String[],         # positional: secondary_diagnoses
    String[],         # positional: procedures
    Medicare          # positional: payer
)
```

**After (v1.0):** All fields are keyword arguments via `@kwdef`:
```julia
episode = Episode(
    episode_id        = "EP001",
    patient_id        = "PT001",
    admission_date    = Date(2024, 1, 1),
    discharge_date    = Date(2024, 1, 6),
    primary_diagnosis = "I10",
    drg_code          = "291",
    secondary_diagnoses = String[],
    procedures        = String[],
    payer             = Medicare
)
```

#### `calculate_icer` signature

**Before (v0.x):**
```julia
icer = calculate_icer(intervention_cost, intervention_effect,
                       control_cost, control_effect)
```

**After (v1.0):** Keyword arguments required for `control_*` parameters:
```julia
icer = calculate_icer(
    intervention_cost   = 8500.0,
    intervention_effect = 0.85,
    control_cost        = 7500.0,
    control_effect      = 0.80
)
```

---

### 2. Patient Cohort Builder (`patient_cohort/`)

#### `build_cohort` return type

**Before (v0.x):** Returned `Vector{PatientEncounter}`.

**After (v1.0):** Returns a `PatientCohort` struct with the following fields:
```julia
struct PatientCohort
    cohort_id    :: String
    definition   :: CohortDefinition
    encounters   :: Vector{PatientEncounter}
    statistics   :: CohortStatistics
    created_at   :: DateTime
end
```

**Migration:**
```julia
# Before:
encounters = build_cohort(all_encounters, criteria)
for enc in encounters
    process(enc)
end

# After:
cohort = build_cohort(all_encounters, criteria)
for enc in cohort.encounters
    process(enc)
end
# or use the statistics directly:
println(cohort.statistics.mean_cost)
```

---

### 3. Policy Simulation (`policy/MultiLevelPolicyCoupling.jl`)

#### `PolicyCouplingOutcomes` field rename

**Before (v0.x):**
```julia
outcomes.hospital_outcomes["HospitalA"]["revenue_change"]
```

**After (v1.0):** Field renamed to `hospital_level_outcomes`:
```julia
outcomes.hospital_level_outcomes["HospitalA"]["revenue_change"]
```

#### `simulate_policy_coupling!` in-place mutation

The function signature now uses the convention `!` for in-place mutation
and explicitly takes the scenario struct as first argument:

**Before (v0.x):**
```julia
results = simulate_policy_coupling(federal_policy, state_policy,
                                    hospitals, years)
```

**After (v1.0):**
```julia
scenario = MultiLevelPolicyScenario(federal_policies, state_policies,
                                     hospitals, years)
outcomes  = simulate_policy_coupling!(scenario)
```

---

### 4. Validation Module (`validation/PolicyValidation.jl`)

#### `validate_simulation` return type

**Before (v0.x):** Returned a named tuple `(mape, directional_accuracy, rmse)`.

**After (v1.0):** Returns a `ValidationResult` struct:
```julia
result = validate_simulation(case_study, simulation_fn)

# Access metrics:
println("MAPE: ", result.metrics.mape)
println("Dir. accuracy: ", result.metrics.directional_accuracy)

# Access hospital-level results:
result.hospital_level_results["KY_CAH_001"]["revenue_change"]
```

---

### 5. Release Preparation (`release/ReleasePreparation.jl`)

This module is new in v1.0. No migration needed.

---

## Dependency Changes

### Removed in v1.0
None — all pre-release dependencies are retained.

### Added in v1.0
| Package | Version | Purpose |
|---------|---------|---------|
| `HiGHS` | ≥ 1.7 | Open-source MIP solver for JuMP optimization |
| `StatsBase` | ≥ 0.34 | Statistical utilities for cohort analysis |
| `Agents` | ≥ 6.0 | Agent-based patient flow simulation |

### Updated Minimum Versions
| Package | Before | After |
|---------|--------|-------|
| `DataFrames` | ≥ 1.5 | ≥ 1.6 |
| `JuMP` | ≥ 1.15 | ≥ 1.20 |
| `Distributions` | ≥ 0.25 | ≥ 0.25 (unchanged) |

---

## Step-by-Step Migration

1. **Update `Project.toml`** dependencies to v1.0 minimum versions (see above).

2. **Re-instantiate the project:**
   ```bash
   julia --project=. -e 'using Pkg; Pkg.update()'
   ```

3. **Run the test suite** to identify any API breakage:
   ```bash
   julia --project=. test/runtests.jl
   ```

4. **Apply constructor changes** — switch `Episode(...)` calls to keyword syntax.

5. **Update `build_cohort` call sites** — add `.encounters` where previously the
   return value was iterated directly.

6. **Update policy simulation code** — rename `hospital_outcomes` →
   `hospital_level_outcomes` and switch to `MultiLevelPolicyScenario` pattern.

7. **Update validation code** — switch from named-tuple access to
   `ValidationResult` struct field access.

---

## Getting Help

If you encounter migration issues not covered here, please open a GitHub issue:
https://github.com/timothyhartzog/Hospital-economics/issues

Include:
- Your v0.x code snippet
- The error message or unexpected behavior
- Your Julia version (`julia -e 'println(VERSION)'`)
