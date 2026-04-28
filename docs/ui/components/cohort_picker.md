# CohortPicker

**Component file:** `app/components/cohort_picker.jl`  
**Demo route:** `/dev/components#sec-cohortpicker` (dev environment only)

## Overview

`CohortPicker` is an interactive cohort inclusion/exclusion criteria builder that mirrors the API of `src/patient_cohort/cohort_builder.jl`. It renders criteria for age, diagnosis codes (ICD-10), procedure codes (CPT), payer, length of stay, admission date range, and total cost range, plus a "Save as named cohort" control.

## Usage

```julia
cohort_picker(;
    prefix = "cohort_",
    class  = "",
)
```

### Arguments

| Argument | Type | Description |
|---|---|---|
| `prefix` | `String` | Namespace prefix for all reactive field names (default `"cohort_"`) |
| `class` | `String` | Extra CSS classes for the outer card |

## Required model fields

All fields use the `prefix` (default `"cohort_"`) as a namespace:

```julia
@in cohort_min_age::Int           = 18
@in cohort_max_age::Int           = 120
@in cohort_dx_codes::String       = ""      # comma-separated ICD-10 prefixes
@in cohort_cpt_codes::String      = ""      # comma-separated CPT prefixes
@in cohort_payers::Vector{String} = []
@in cohort_min_los::Int           = 0
@in cohort_max_los::Int           = 365
@in cohort_date_start::String     = ""
@in cohort_date_end::String       = ""
@in cohort_min_cost::Float64      = 0.0
@in cohort_max_cost::Float64      = 9_999_999.0
@in cohort_name::String           = ""
@in cohort_save::Bool             = false

@onchange cohort_save begin
    if cohort_save
        # build_cohort from src/patient_cohort/cohort_builder.jl
        criteria = [
            AgeCriterion(cohort_min_age, cohort_max_age, true),
            PayerCriterion(cohort_payers, true),
            # ...
        ]
        saved_cohort = build_cohort(encounters, criteria, cohort_name)
        cohort_save = false
    end
end
```

## Custom prefix example

```julia
# Component with custom prefix "pat_"
cohort_picker(prefix="pat_")

# Corresponding model fields:
@in pat_min_age::Int   = 0
@in pat_max_age::Int   = 120
# ... etc.
```

## Linked domain functions

- `src/patient_cohort/cohort_builder.jl` — `build_cohort`, `apply_age_criterion`,
  `apply_diagnosis_criterion`, `apply_procedure_criterion`, `apply_payer_criterion`,
  `apply_los_criterion`, `apply_cost_criterion`, `apply_date_criterion`
- `src/patient_cohort/cohort_types.jl` — `AgeCriterion`, `DiagnosisCriterion`,
  `ProcedureCriterion`, `PayerCriterion`, `LengthOfStayCriterion`,
  `CostCriterion`, `DateCriterion`, `PatientCohort`
