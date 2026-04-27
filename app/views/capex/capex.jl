"""
    capex.jl — DSL UI for capital budgeting tool (A-05)

Renders project input table, ranking calculation, results, and waterfall chart.
"""
function ui_capex()
    page(
        model = @current,
        partial = true,
        [
            heading("Capital Project Budgeting", class="text-h4 q-mb-md")

            row(
                cell(class="col-xs-12 col-sm-6",
                    card(
                        card_section(
                            class="bg-blue-1",
                            [
                                heading("Discount Rate & Budget", class="text-h6 q-mb-md")
                                separator()

                                textfield(
                                    :wacc_input,
                                    label="WACC (Discount Rate)",
                                    type="number",
                                    step=0.001,
                                    class="full-width q-mb-md"
                                )

                                toggle(
                                    :apply_budget,
                                    label="Apply Budget Constraint",
                                    class="q-mb-md"
                                )

                                @if(:apply_budget)
                                    textfield(
                                        :budget_constraint,
                                        label="Total Capital Budget ($)",
                                        type="number",
                                        class="full-width"
                                    )
                                @end
                            ]
                        )
                    )
                ),

                cell(class="col-xs-12 col-sm-6",
                    card(
                        card_section(
                            class="bg-green-1",
                            [
                                heading("Add Project", class="text-h6 q-mb-md")
                                separator()

                                textfield(
                                    :project_name,
                                    label="Project Name",
                                    placeholder="e.g., ICU Expansion",
                                    class="full-width q-mb-md"
                                )

                                textfield(
                                    :project_initial_outlay,
                                    label="Initial Investment ($)",
                                    type="number",
                                    class="full-width q-mb-md"
                                )

                                textfield(
                                    :project_useful_life,
                                    label="Useful Life (years)",
                                    type="number",
                                    class="full-width q-mb-md"
                                )

                                textfield(
                                    :project_annual_cf,
                                    label="Annual Cash Flows (comma-separated)",
                                    placeholder="100000,100000,100000,100000,100000",
                                    class="full-width q-mb-md"
                                )

                                textfield(
                                    :project_salvage,
                                    label="Salvage Value ($)",
                                    type="number",
                                    class="full-width q-mb-md"
                                )

                                button(
                                    "Add Project",
                                    @click("add_project_btn"),
                                    color="primary",
                                    class="full-width"
                                )
                            ]
                        )
                    )
                )
            )

            # Error display
            @if(!isempty(:error_message))
                row(
                    cell(class="col-xs-12",
                        card(
                            card_section(
                                class="bg-red-2 text-red-9",
                                [
                                    icon("warning", class="q-mr-md")
                                    text(:error_message)
                                ]
                            )
                        )
                    )
                )
            @end

            # Rank button
            row(
                cell(class="col-xs-12 col-sm-3 q-offset-sm-9 q-mt-md",
                    button(
                        "Rank Projects",
                        @click("rank_projects_btn"),
                        color="primary",
                        size="lg",
                        class="full-width",
                        :disable = :is_calculating
                    )
                )
            )

            @if(:is_calculating)
                row(
                    cell(class="col-xs-12",
                        linear_progress(value=0.5, color="primary")
                    )
                )
            @end

            # Results section
            @if(!isempty(:ranked_projects))
                heading("Project Rankings", class="text-h5 q-mt-lg q-mb-md")

                # Summary cards
                row(
                    cell(class="col-xs-12 col-sm-3",
                        card(
                            card_section(
                                class="text-center bg-blue-1",
                                [
                                    text("Total Selected Investment", class="text-caption text-grey-7")
                                    heading(
                                        @text(:total_selected_investment; format(x) = Printf.@sprintf("$%.0f", x)),
                                        class="text-h5 q-my-md"
                                    )
                                ]
                            )
                        )
                    ),

                    cell(class="col-xs-12 col-sm-3",
                        card(
                            card_section(
                                class="text-center bg-green-1",
                                [
                                    text("Total Selected NPV", class="text-caption text-grey-7")
                                    heading(
                                        @text(:total_selected_npv; format(x) = Printf.@sprintf("$%.0f", x)),
                                        class="text-h5 text-positive q-my-md"
                                    )
                                ]
                            )
                        )
                    ),

                    cell(class="col-xs-12 col-sm-3",
                        card(
                            card_section(
                                class="text-center bg-amber-1",
                                [
                                    text("Unallocated Budget", class="text-caption text-grey-7")
                                    heading(
                                        @text(:unallocated_budget; format(x) = Printf.@sprintf("$%.0f", x)),
                                        class="text-h5 q-my-md"
                                    )
                                ]
                            )
                        )
                    )
                )

                # Ranked projects table
                row(
                    cell(class="col-xs-12 q-mt-lg",
                        table(
                            :ranked_projects,
                            table_columns=[
                                (name="name", label="Project", field="name", align="left"),
                                (name="initial_outlay", label="Initial Outlay ($)", field="initial_outlay", align="right"),
                                (name="npv", label="NPV ($)", field="npv", align="right"),
                                (name="irr", label="IRR", field="irr", align="right"),
                                (name="profitability_index", label="Profit Index", field="profitability_index", align="right"),
                                (name="pi_rank", label="Rank", field="pi_rank", align="center"),
                                (name="selected", label="Selected?", field="selected", align="center")
                            ],
                            flat=true,
                            bordered=true
                        )
                    )
                )

                # Waterfall/bar chart of NPVs
                row(
                    cell(class="col-xs-12 col-sm-6 q-mt-lg",
                        plot(
                            type="bar",
                            layout=attr(
                                title="NPV by Project",
                                xaxis=attr(title="Project"),
                                yaxis=attr(title="NPV ($)")
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
                    )
                )

                # Clear button
                row(
                    cell(class="col-xs-12 q-mt-lg",
                        button(
                            "Clear All Projects",
                            @click("clear_projects_btn"),
                            color="negative",
                            flat=true,
                            class="full-width"
                        )
                    )
                )
            @end
        ]
    ) |> html
end
