# ScenarioPicker

**Component file:** `app/components/scenario_picker.jl`  
**Demo route:** `/dev/components#sec-scenariopicker` (dev environment only)

## Overview

`ScenarioPicker` is a drop-in chooser over saved scenarios. It renders a select input bound to a list of saved scenarios from `scenario_options`, plus Load, Delete, and New buttons wired to Bool reactive fields.

## Usage

```julia
scenario_picker(;
    field         = :selected_scenario_id,
    options_field = :scenario_options,
    load_field    = :scenario_load,
    delete_field  = :scenario_delete,
    new_field     = :scenario_new,
    class         = "",
)
```

### Arguments

| Argument | Type | Default | Description |
|---|---|---|---|
| `field` | `Symbol` | `:selected_scenario_id` | String `@in` field for the selected scenario id |
| `options_field` | `Symbol` | `:scenario_options` | `@out Vector{Dict}` with `{label, value, description, created_at}` |
| `load_field` | `Symbol` | `:scenario_load` | Bool `@in` field triggered by Load button |
| `delete_field` | `Symbol` | `:scenario_delete` | Bool `@in` field triggered by Delete button |
| `new_field` | `Symbol` | `:scenario_new` | Bool `@in` field triggered by New button |
| `class` | `String` | `""` | Extra CSS classes |

## Required model fields

```julia
@in  selected_scenario_id::String = ""
@out scenario_options::Vector{Dict{String,Any}} = [
    Dict("label"=>"Baseline 2025", "value"=>"s1",
         "description"=>"Current trajectory", "created_at"=>"2025-01-10"),
]
@in  scenario_load::Bool   = false
@in  scenario_delete::Bool = false
@in  scenario_new::Bool    = false

@onchange scenario_load begin
    if scenario_load && !isempty(selected_scenario_id)
        # load scenario from src/models/scenarios.jl
        scenario_load = false
    end
end
```

## Linked domain functions

- `src/models/scenarios.jl` — scenario CRUD operations
- `src/simulation/montecarlo.jl` — Monte Carlo scenario runner
- `app/views/scenarios/ScenarioModel.jl` — existing scenario model
