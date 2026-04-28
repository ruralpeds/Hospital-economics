"""
Database & Queries UI (E19) — entity picker, filter builder,
result table, saved queries, and data versioning.
"""

function ui_database(model)
    app_layout(model, "Database & Queries", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Database & Queries", class="q-mb-none"),
                p("Query patient records, claims, encounters, and financial data; save datasets for analysis",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Run Query", icon="search", color="primary",
                    @click(:run_query),
                    var":loading"="running"),
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

        # Query builder
        form_grid([
            (name=:entity_type,     type=:select, label="Entity Type",
             options=[
                 Dict("value"=>"patients",    "label"=>"Patients"),
                 Dict("value"=>"claims",      "label"=>"Claims"),
                 Dict("value"=>"encounters",  "label"=>"Encounters"),
                 Dict("value"=>"financial",   "label"=>"Financial Records"),
             ]),
            (name=:date_from,       type=:date,   label="Date From"),
            (name=:date_to,         type=:date,   label="Date To"),
            (name=:payer_filter,    type=:text,   label="Payer Filter",       help="e.g. Medicare, Medicaid"),
            (name=:facility_filter, type=:text,   label="Facility Filter"),
            (name=:account_code,    type=:text,   label="Account Code",       help="GL account or DRG code"),
        ], title="Query Filters"),

        # Result count
        card(class="q-mb-md", [
            card_section([
                p("Results: {{ result_count }} records", class="text-subtitle2 q-mb-none"),
            ]),
        ]),

        # Result table
        result_table(
            :result_rows,
            columns=[
                (name="id",         label="ID",         field="id",         sortable=true),
                (name="date",       label="Date",       field="date",       sortable=true),
                (name="entity",     label="Entity",     field="entity",     sortable=true),
                (name="payer",      label="Payer",      field="payer",      sortable=true),
                (name="amount",     label="Amount",     field="amount",     sortable=true, format="currency"),
                (name="facility",   label="Facility",   field="facility",   sortable=true),
            ],
            title="Query Results",
        ),

        # Save actions
        row(class="q-mb-md q-gutter-sm items-center", [
            cell(class="col-md-4 col-xs-12", [
                form_grid([
                    (name=:query_name,   type=:text, label="Save Query As"),
                    (name=:version_name, type=:text, label="Dataset Version Name"),
                ], title="Save Options"),
            ]),
            cell(class="col-auto", [
                btn("Save Query", icon="save", color="secondary",
                    @click(:save_query), outline=true),
            ]),
            cell(class="col-auto", [
                btn("Save as Asset", icon="cloud_upload", color="positive",
                    @click(:save_dataset), outline=true),
            ]),
        ]),

        # Saved queries
        result_table(
            :saved_queries,
            columns=[
                (name="name",       label="Name",       field="name",       sortable=true),
                (name="entity",     label="Entity",     field="entity",     sortable=true),
                (name="created_at", label="Created",    field="created_at", sortable=true),
            ],
            title="Saved Queries",
        ),

        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
