"""
    capex.jl — DSL UI for capital budgeting tool (A-05)

Renders project input table, ranking calculation, results, and waterfall chart.
"""
function ui_capex(model)
    app_layout(model, "Capital Expenditure", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Capital Project Budgeting", class="q-mb-none"),
                p("Rank capital projects by NPV, IRR, and profitability index",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Rank Projects", icon="leaderboard", color="primary",
                    @click("rank_projects_btn"),
                    :disable = :is_calculating),
            ]),
        ]),

        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-xs-12 col-sm-6", [
                card([card_section(class="bg-blue-1", [
                    h6("Discount Rate & Budget", class="q-mb-md"),
                    separator(),
                    textfield(:wacc_input, label="WACC (Discount Rate)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    toggle(:apply_budget, label="Apply Budget Constraint", class="q-mb-sm"),
                    @if(:apply_budget)
                        textfield(:budget_constraint, label="Total Capital Budget (\$)", type="number",
                                  filled=true, dense=true, class="q-mb-sm")
                    @end
                ])])
            ]),

            cell(class="col-xs-12 col-sm-6", [
                card([card_section(class="bg-green-1", [
                    h6("Add Project", class="q-mb-md"),
                    separator(),
                    textfield(:project_name, label="Project Name", placeholder="e.g., ICU Expansion",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:project_initial_outlay, label="Initial Investment (\$)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:project_useful_life, label="Useful Life (years)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:project_annual_cf, label="Annual Cash Flows (comma-separated)",
                              placeholder="100000,100000,100000,100000,100000",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:project_salvage, label="Salvage Value (\$)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    btn("Add Project", color="primary", class="full-width",
                        @click("add_project_btn")),
                ])])
            ]),
        ]),

        # Error display
        @if(!isempty(:error_message))
            row([
                cell(class="col-xs-12", [
                    card([card_section(class="bg-red-2 text-red-9", [
                        icon("warning", class="q-mr-md"),
                        text(:error_message),
                    ])])
                ])
            ])
        @end

        @if(:is_calculating)
            row([
                cell(class="col-xs-12", [
                    linear_progress(value=0.5, color="primary")
                ])
            ])
        @end

        # Results section
        @if(!isempty(:ranked_projects))
            row(class="q-mb-lg q-gutter-md", [
                cell(class="col-xs-12 col-sm-3", [
                    card([card_section(class="text-center bg-blue-1", [
                        text("Total Selected Investment", class="text-caption text-grey-7"),
                        heading(
                            @text(:total_selected_investment; format(x) = Printf.@sprintf("\$%.0f", x)),
                            class="text-h5 q-my-md"
                        ),
                    ])])
                ]),
                cell(class="col-xs-12 col-sm-3", [
                    card([card_section(class="text-center bg-green-1", [
                        text("Total Selected NPV", class="text-caption text-grey-7"),
                        heading(
                            @text(:total_selected_npv; format(x) = Printf.@sprintf("\$%.0f", x)),
                            class="text-h5 text-positive q-my-md"
                        ),
                    ])])
                ]),
                cell(class="col-xs-12 col-sm-3", [
                    card([card_section(class="text-center bg-amber-1", [
                        text("Unallocated Budget", class="text-caption text-grey-7"),
                        heading(
                            @text(:unallocated_budget; format(x) = Printf.@sprintf("\$%.0f", x)),
                            class="text-h5 q-my-md"
                        ),
                    ])])
                ]),
            ])

            # Ranked projects table
            row(class="q-mb-lg", [
                cell(class="col-xs-12", [
                    table(
                        :ranked_projects,
                        table_columns=[
                            (name="name", label="Project", field="name", align="left"),
                            (name="initial_outlay", label="Initial Outlay (\$)", field="initial_outlay", align="right"),
                            (name="npv", label="NPV (\$)", field="npv", align="right"),
                            (name="irr", label="IRR", field="irr", align="right"),
                            (name="profitability_index", label="Profit Index", field="profitability_index", align="right"),
                            (name="pi_rank", label="Rank", field="pi_rank", align="center"),
                            (name="selected", label="Selected?", field="selected", align="center")
                        ],
                        flat=true,
                        bordered=true
                    )
                ])
            ])

            # Waterfall/bar chart of NPVs
            row(class="q-mb-lg", [
                cell(class="col-xs-12 col-sm-6", [
                    plot(
                        type="bar",
                        layout=attr(
                            title="NPV by Project",
                            xaxis=attr(title="Project"),
                            yaxis=attr(title="NPV (\$)")
                        ),
                        data=[
                            attr(
                                x=:chart_labels,
                                y=:chart_npv_data,
                                type="bar",
                                marker=attr(color="rgb(70, 130, 180)")
                            )
                        ]
                    )
                ])
            ])

            # Clear button
            row([
                cell(class="col-xs-12", [
                    btn("Clear All Projects", color="negative", flat=true, class="full-width",
                        @click("clear_projects_btn")),
                ])
            ])
        @end

        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
