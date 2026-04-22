# FormGrid

**Component file:** `app/components/form_grid.jl`  
**Demo route:** `/dev/components#sec-formgrid` (dev environment only)

## Overview

`FormGrid` auto-generates a responsive Quasar input form from a Julia `Vector{NamedTuple}` field specification. It replaces hand-crafted repetitive input blocks across view files, ensuring consistent styling, validation, and tooltip behaviour.

## Usage

```julia
form_grid(
    fields,
    title             = "",
    upload_model_field = nothing,
    class             = "",
)
```

### Arguments

| Argument | Type | Description |
|---|---|---|
| `fields` | `Vector` | Field descriptor `NamedTuple`s (see below) |
| `title` | `String` | Optional card section header |
| `upload_model_field` | `Symbol` or `nothing` | Bool `@in` field toggled by "Fill from upload" button |
| `class` | `String` | Extra CSS class string for the outer card |

### Field descriptor keys

| Key | Type | Required | Description |
|---|---|---|---|
| `name` | `Symbol` | ✅ | Reactive model field name (used as Stipple binding key) |
| `type` | `Symbol` | ✅ | Input type (see supported types below) |
| `label` | `String` | | Display label (defaults to title-cased `name`) |
| `help` | `String` | | Tooltip text shown as a `help_outline` icon |
| `min` | `Number` | | Minimum value (numeric/percent/integer/currency) |
| `max` | `Number` | | Maximum value |
| `step` | `Number` | | Step increment |
| `options` | `Vector{Dict}` | | `[{label, value}]` pairs for `:select`/`:multiselect` |
| `visible_when` | `String` | | Vue expression; wraps the cell in `v-if` |
| `columns` | `Vector{Symbol}` | | Column names for `:dynamic_table` type |
| `col_class` | `String` | | Quasar column class (default `"col-md-4 col-sm-6 col-xs-12"`) |

### Supported types

| Symbol | Rendered as |
|---|---|
| `:numeric` | `numberfield` |
| `:currency` | `numberfield` with `$` prefix |
| `:percent` | `numberfield` with `%` suffix |
| `:integer` | `numberfield` with `step=1` |
| `:date` | `textfield` with `type="date"` |
| `:daterange` | Two `textfield` date pickers (start/end) |
| `:select` | `q-select` single |
| `:multiselect` | `q-select` multiple |
| `:toggle` | `q-toggle` |
| `:code_search` | `textfield` with ICD/CPT/HCPCS hint |
| `:cohort_picker` | `q-select` bound to `cohort_options` |
| `:file` | `q-file` |
| `:dynamic_table` | Inline editable table with "+ Row" button |

## Example

```julia
form_grid([
    (name=:discount_rate, type=:percent, label="Discount Rate",
     default=0.03, min=0.0, max=0.15, step=0.1,
     help="Annual discount rate for present-value calculations."),
    (name=:time_horizon, type=:integer, label="Time Horizon (years)",
     default=10, min=1, max=50),
    (name=:start_date, type=:date, label="Start Date"),
    (name=:scenario_type, type=:select, label="Scenario",
     options=[Dict(:label=>"Baseline", :value=>"base"),
              Dict(:label=>"Optimistic", :value=>"opt")]),
    (name=:active, type=:toggle, label="Active"),
],
title="Analysis Parameters",
upload_model_field=:fill_from_upload)
```

## Model fields required

The calling `@app` block must declare `@in` fields matching each `name` in the field spec, plus `cohort_options` if any `:cohort_picker` fields are used.

```julia
@in discount_rate::Float64 = 3.0
@in time_horizon::Int      = 10
@in start_date::String     = "2025-01-01"
@in scenario_type::String  = "base"
@in active::Bool           = true
@in fill_from_upload::Bool = false
@out cohort_options::Vector{Dict{String,Any}} = []
```

## Linked functions

All input forms in the function catalog that accept scalar or tabular parameters
can be backed by `FormGrid` — see `docs/ui/function_index.md`.
