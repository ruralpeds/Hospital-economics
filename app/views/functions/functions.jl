"""
Function Explorer UI (E23) — searchable catalog of all simulator functions
with inline execution panel and deep-links into concept tabs.
"""

function ui_functions(model)
    app_layout(model, "Function Explorer", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Function Explorer", class="q-mb-none"),
                p("Browse and invoke all catalog functions with deep-links into concept tabs",
                  class="text-grey-7"),
            ]),
        ]),

        # Error banner
        template(var"v-if"="errors && errors.length > 0", [
            card(class="q-mb-md bg-red-1 text-red-9", [
                card_section([
                    p("Errors:", class="text-weight-bold q-mb-xs"),
                    template(var"v-for"="(err, idx) in errors", var":key"="idx", [
                        p(class="q-mb-none", ["{{ err }}"]),
                    ]),
                ]),
            ]),
        ]),

        # Search and filters
        form_grid([
            (name=:search_query,   type=:text,   label="Search Functions",
             help="Filter by name, description, or section"),
            (name=:section_filter, type=:select, label="Section Filter",
             options=[
                 Dict("value"=>"all",        "label"=>"All Sections"),
                 Dict("value"=>"Quality",     "label"=>"Quality & Clinical"),
                 Dict("value"=>"Statistics",  "label"=>"Statistics"),
                 Dict("value"=>"Regression",  "label"=>"Regression"),
                 Dict("value"=>"Causal",      "label"=>"Causal Inference"),
                 Dict("value"=>"CEA",         "label"=>"CEA"),
                 Dict("value"=>"CBA",         "label"=>"CBA"),
                 Dict("value"=>"ML",          "label"=>"ML"),
                 Dict("value"=>"Scenarios",   "label"=>"Scenarios"),
                 Dict("value"=>"Audit",       "label"=>"Audit"),
             ]),
            (name=:status_filter, type=:select, label="Status Filter",
             options=[
                 Dict("value"=>"all",       "label"=>"All"),
                 Dict("value"=>"available", "label"=>"Available"),
                 Dict("value"=>"coming",    "label"=>"Coming Soon"),
             ]),
        ], title="Search & Filter"),

        # Function catalog table
        result_table(
            :filtered_functions,
            columns=[
                (name="fn_name",     label="Function Name",  field="fn_name",     sortable=true),
                (name="section",     label="Section",        field="section",     sortable=true),
                (name="description", label="Description",    field="description", sortable=false),
                (name="tab_url",     label="Tab URL",        field="tab_url",     sortable=true),
            ],
            title="Function Catalog",
        ),

        # Inline run panel
        card(class="q-mb-md", [
            card_section([
                h6("Inline Function Runner", class="q-mb-sm"),
                form_grid([
                    (name=:selected_function, type=:text, label="Function Name",
                     help="Enter function name from the catalog above"),
                    (name=:inline_params,     type=:text, label="Parameters (JSON)",
                     help="JSON object with input parameters, e.g. {\"cohort_id\":\"abc\"}"),
                ], title=""),
                row(class="q-mb-sm", [
                    cell(class="col-auto", [
                        btn("Run", icon="play_arrow", color="primary",
                            @click(:run_inline), var":loading"="running"),
                    ]),
                ]),
                template(var"v-if"="inline_result", [
                    card(class="bg-grey-1", [
                        card_section([
                            h6("Result", class="q-mb-xs"),
                            p(class="q-mb-none text-mono", ["{{ inline_result }}"]),
                        ]),
                    ]),
                ]),
            ]),
        ]),
    ])
end
