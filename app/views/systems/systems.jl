"""
Network & Systems UI (E21) — referral network analysis, Sankey patient flow,
care coordination gaps, and patient pathway simulator.
"""

function ui_systems(model)
    app_layout(model, "Network & Systems", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Network & Systems", class="q-mb-none"),
                p("Referral network analysis, care coordination gaps, and patient care pathways",
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

        # Sub-tabs
        qtabs(:active_tab, class="q-mb-md", [
            qtab(name="network", label="Referral Network"),
            qtab(name="pathway", label="Care Pathway"),
        ]),
        qtabpanels(:active_tab, [
            # Network tab
            qtabpanel(name="network", [
                form_grid([
                    (name=:referral_asset_id,   type=:text, label="Referral Data Asset ID",
                     help="Dataset with referral relationships between providers"),
                    (name=:encounters_asset_id, type=:text, label="Encounters Asset ID",
                     help="Encounter dataset for network construction"),
                ], title="Network Data"),

                row(class="q-mb-md q-gutter-sm", [
                    cell(class="col-auto", [
                        btn("Build Network", icon="hub", color="primary",
                            @click(:do_network), var":loading"="running"),
                    ]),
                ]),

                # Network plot (Sankey)
                row(class="q-mb-md q-gutter-md", [
                    cell(class="col-md-6 col-xs-12", [
                        plot_panel(:sankey_data, :sankey_layout,
                            preset=:sankey, title="Patient Flow (Sankey)"),
                    ]),
                    cell(class="col-md-6 col-xs-12", [
                        plot_panel(:network_data, :network_layout,
                            preset=:scatter, title="Referral Network Graph"),
                    ]),
                ]),

                # Care gaps
                result_table(
                    :gap_rows,
                    columns=[
                        (name="specialty",     label="Specialty",     field="specialty",     sortable=true),
                        (name="gap_type",      label="Gap Type",      field="gap_type",      sortable=true),
                        (name="affected_pct",  label="% Affected",    field="affected_pct",  sortable=true, format="percent"),
                        (name="avg_delay_days",label="Avg Delay (d)", field="avg_delay_days",sortable=true),
                    ],
                    title="Care Coordination Gaps",
                ),

                # Team composition
                result_table(
                    :team_rows,
                    columns=[
                        (name="role",          label="Role",           field="role",          sortable=true),
                        (name="fte",           label="FTE",            field="fte",           sortable=true),
                        (name="productivity",  label="Productivity",   field="productivity",  sortable=true),
                    ],
                    title="Care Team Composition",
                ),
            ]),

            # Pathway tab
            qtabpanel(name="pathway", [
                form_grid([
                    (name=:patient_pathway_id,   type=:text,    label="Pathway Template ID",
                     help="Patient pathway definition asset"),
                    (name=:starting_condition,   type=:select,  label="Starting Condition",
                     options=[
                         Dict("value"=>"chest_pain",    "label"=>"Chest Pain"),
                         Dict("value"=>"hip_fracture",  "label"=>"Hip Fracture"),
                         Dict("value"=>"chf",           "label"=>"Congestive Heart Failure"),
                         Dict("value"=>"pneumonia",     "label"=>"Pneumonia"),
                         Dict("value"=>"sepsis",        "label"=>"Sepsis"),
                     ]),
                    (name=:rng_seed, type=:numeric, label="RNG Seed",
                     help="Reproducibility seed for stochastic simulation"),
                ], title="Pathway Simulation"),

                row(class="q-mb-md", [
                    cell(class="col-auto", [
                        btn("Simulate Pathway", icon="route", color="primary",
                            @click(:do_pathway), var":loading"="running"),
                    ]),
                ]),

                result_table(
                    :pathway_rows,
                    columns=[
                        (name="step",         label="Step",          field="step",         sortable=false),
                        (name="care_setting", label="Care Setting",  field="care_setting", sortable=true),
                        (name="duration_days",label="Duration (d)",  field="duration_days",sortable=true),
                        (name="cost",         label="Cost",          field="cost",         sortable=true, format="currency"),
                        (name="outcome",      label="Outcome",       field="outcome",      sortable=true),
                    ],
                    title="Simulated Care Pathway",
                ),
            ]),
        ]),

        export_bar(csv_field=nothing, xlsx_field=nothing, json_field=nothing,
                   label="Export network & pathway analysis"),
    ])
end
