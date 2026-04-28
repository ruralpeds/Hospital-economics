"""
ScenarioPicker — `app/components/scenario_picker.jl`

Drop-in chooser over saved scenarios.  Binds to a `@in` reactive field on
the calling model that holds the currently-selected scenario identifier.

The available scenarios list is read from `scenario_options` (a
`@out Vector{Dict{String,Any}}` field on the model) where each entry
should have the shape:
  Dict("label" => "Scenario Name", "value" => "scenario_id",
       "description" => "Optional description", "created_at" => "2025-01-15")

Required model fields (declared by the caller):
  selected_scenario_id::String  = ""
  scenario_options::Vector{Dict{String,Any}} = []
  scenario_load::Bool           = false   # toggled to trigger load
  scenario_delete::Bool         = false   # toggled to trigger delete
  scenario_new::Bool            = false   # toggled to open new-scenario dialog

Usage:
```julia
scenario_picker()
```

Pass `field=:my_scenario_id` to use a custom field name.
"""

"""
    scenario_picker(; field=:selected_scenario_id,
                     options_field=:scenario_options,
                     load_field=:scenario_load,
                     delete_field=:scenario_delete,
                     new_field=:scenario_new,
                     class="")

Render a compact scenario selection card.
"""
function scenario_picker(;
    field::Symbol         = :selected_scenario_id,
    options_field::Symbol = :scenario_options,
    load_field::Symbol    = :scenario_load,
    delete_field::Symbol  = :scenario_delete,
    new_field::Symbol     = :scenario_new,
    class::String         = "",
)
    card(class="q-mb-md " * class, [
        card_section([
            row(class="items-center q-mb-sm", [
                cell(class="col", [
                    h6("Scenario", class="q-mb-none"),
                ]),
                cell(class="col-auto", [
                    btn("New", icon="add", flat=true, color="primary",
                        dense=true, no_caps=true,
                        @click(new_field)),
                ]),
            ]),

            select(field,
                label="Select saved scenario",
                filled=true, dense=true,
                var":options"=string(options_field),
                var"option-label"="opt => opt.label",
                var"option-value"="opt => opt.value",
                var"emit-value"=true,
                var"map-options"=true,
                class="q-mb-sm"),

            # Description / metadata of selected scenario
            Html.div(var"v-if"=string(field) * " !== ''",
                class="text-caption text-grey-7 q-mb-sm", [
                Html.span(
                    var"v-for"="s in " * string(options_field),
                    var":key"="s.value",
                    var"v-if"="s.value === " * string(field), [
                    Html.span("{{ s.description || '' }}", class="q-mr-md"),
                    Html.span("Created: {{ s.created_at || '' }}"),
                ]),
            ]),

            row(class="q-gutter-xs", [
                btn("Load", icon="play_arrow", color="primary",
                    dense=true, no_caps=true,
                    var":disable"=string(field) * " === ''",
                    @click(load_field)),
                btn("Delete", icon="delete", color="negative",
                    dense=true, no_caps=true, flat=true,
                    var":disable"=string(field) * " === ''",
                    @click(delete_field)),
            ]),
        ]),
    ])
end
