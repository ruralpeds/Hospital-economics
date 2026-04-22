"""
Shared application layout with navigation sidebar.
Wraps all page content in a consistent Quasar layout with drawer navigation.

IMPORTANT: This function returns layout elements only. The calling route handler
wraps the result in `page(model, ui_func) |> html`.
"""

function app_layout(model, page_title::String, content::Vector)
    [
        quasar(:layout, view="hHh lpR fFf", [
            # ── Top Bar ──────────────────────────────────────────────
            quasar(:header, elevated=true, class="bg-primary text-white", [
                toolbar([
                    btn("", icon="menu", flat=true, round=true, dense=true,
                        @click("left_drawer_open = !left_drawer_open")),
                    toolbar_title("Rural Hospital Economics Simulator"),
                    span(page_title, class="text-subtitle2 q-ml-md"),
                ]),
            ]),

            # ── Left Navigation Drawer ───────────────────────────────
            quasar(:drawer, side="left", var"v-model"="left_drawer_open",
                bordered=true, var"show-if-above"=true, class="bg-grey-1", [
                q__list(padding=true, [
                    item_label(header=true, "Navigation"),

                    item(clickable=true, href="/dashboard", [
                        item_section(avatar=true, [q__icon(name="dashboard")]),
                        item_section([item_label("Financial Dashboard")]),
                    ]),
                    item(clickable=true, href="/profile", [
                        item_section(avatar=true, [q__icon(name="business")]),
                        item_section([item_label("Hospital Profile")]),
                    ]),
                    item(clickable=true, href="/scenarios", [
                        item_section(avatar=true, [q__icon(name="science")]),
                        item_section([item_label("Scenario Builder")]),
                    ]),
                    item(clickable=true, href="/simulate", [
                        item_section(avatar=true, [q__icon(name="play_circle")]),
                        item_section([item_label("Run Simulation")]),
                    ]),
                    item(clickable=true, href="/results", [
                        item_section(avatar=true, [q__icon(name="assessment")]),
                        item_section([item_label("Results Explorer")]),
                    ]),

                    separator(class="q-my-sm"),
                    item_label(header=true, "Finance Tools"),

                    item(clickable=true, href="/financial-sim", [
                        item_section(avatar=true, [q__icon(name="tune")]),
                        item_section([item_label("Financial Simulator")]),
                    ]),
                    item(clickable=true, href="/cost-structure", [
                        item_section(avatar=true, [q__icon(name="pie_chart")]),
                        item_section([item_label("Cost Structure")]),
                    ]),
                    item(clickable=true, href="/cost-reimbursement", [
                        item_section(avatar=true, [q__icon(name="receipt_long")]),
                        item_section([item_label("Cost Reimbursement")]),
                    ]),
                    item(clickable=true, href="/payer-margin", [
                        item_section(avatar=true, [q__icon(name="payments")]),
                        item_section([item_label("Payer Margin")]),
                    ]),
                    item(clickable=true, href="/break-even", [
                        item_section(avatar=true, [q__icon(name="balance")]),
                        item_section([item_label("Break-Even")]),
                    ]),
                    item(clickable=true, href="/cash-flow", [
                        item_section(avatar=true, [q__icon(name="account_balance")]),
                        item_section([item_label("Cash Flow")]),
                    ]),
                    item(clickable=true, href="/340b", [
                        item_section(avatar=true, [q__icon(name="medication")]),
                        item_section([item_label("340B Program")]),
                    ]),
                    item(clickable=true, href="/debt-capacity", [
                        item_section(avatar=true, [q__icon(name="credit_score")]),
                        item_section([item_label("Debt Capacity")]),
                    ]),
                    item(clickable=true, href="/revenue-cycle", [
                        item_section(avatar=true, [q__icon(name="loop")]),
                        item_section([item_label("Revenue Cycle")]),
                    ]),
                    item(clickable=true, href="/team-bundled", [
                        item_section(avatar=true, [q__icon(name="group_work")]),
                        item_section([item_label("TEAM Bundled Payment")]),
                    ]),
                    item(clickable=true, href="/telehealth", [
                        item_section(avatar=true, [q__icon(name="video_call")]),
                        item_section([item_label("Telehealth ROI")]),
                    ]),
                    item(clickable=true, href="/vbc-transition", [
                        item_section(avatar=true, [q__icon(name="trending_up")]),
                        item_section([item_label("VBC Transition")]),
                    ]),
                    item(clickable=true, href="/medicaid-supplemental", [
                        item_section(avatar=true, [q__icon(name="health_and_safety")]),
                        item_section([item_label("Medicaid Supplemental")]),
                    ]),
                    item(clickable=true, href="/rhc-optimization", [
                        item_section(avatar=true, [q__icon(name="local_hospital")]),
                        item_section([item_label("RHC Optimization")]),
                    ]),

                    separator(class="q-my-sm"),
                    item_label(header=true, "Analysis Tools"),

                    item(clickable=true, href="/sensitivity", [
                        item_section(avatar=true, [q__icon(name="swap_vert")]),
                        item_section([item_label("Sensitivity Analysis")]),
                    ]),
                    item(clickable=true, href="/benchmark", [
                        item_section(avatar=true, [q__icon(name="radar")]),
                        item_section([item_label("Benchmarking")]),
                    ]),
                    item(clickable=true, href="/service-lines", [
                        item_section(avatar=true, [q__icon(name="view_list")]),
                        item_section([item_label("Service Lines")]),
                    ]),
                    item(clickable=true, href="/workforce", [
                        item_section(avatar=true, [q__icon(name="engineering")]),
                        item_section([item_label("Workforce RVU")]),
                    ]),
                    item(clickable=true, href="/community-impact", [
                        item_section(avatar=true, [q__icon(name="people")]),
                        item_section([item_label("Community Impact")]),
                    ]),
                    item(clickable=true, href="/payer-negotiation", [
                        item_section(avatar=true, [q__icon(name="handshake")]),
                        item_section([item_label("Payer Negotiation")]),
                    ]),
                    item(clickable=true, href="/sdoh", [
                        item_section(avatar=true, [q__icon(name="diversity_3")]),
                        item_section([item_label("SDOH Analysis")]),
                    ]),
                    item(clickable=true, href="/geographic-access", [
                        item_section(avatar=true, [q__icon(name="map")]),
                        item_section([item_label("Geographic Access")]),
                    ]),
                    item(clickable=true, href="/community-benefit", [
                        item_section(avatar=true, [q__icon(name="volunteer_activism")]),
                        item_section([item_label("Community Benefit")]),
                    ]),
                    item(clickable=true, href="/network-economics", [
                        item_section(avatar=true, [q__icon(name="hub")]),
                        item_section([item_label("Network Economics")]),
                    ]),

                    separator(class="q-my-sm"),
                    item_label(header=true, "Strategic Tools"),

                    item(clickable=true, href="/conversion", [
                        item_section(avatar=true, [q__icon(name="swap_horiz")]),
                        item_section([item_label("REH Conversion Wizard")]),
                    ]),
                    item(clickable=true, href="/closure-risk", [
                        item_section(avatar=true, [q__icon(name="warning")]),
                        item_section([item_label("Closure Risk")]),
                    ]),
                    item(clickable=true, href="/staffing", [
                        item_section(avatar=true, [q__icon(name="groups")]),
                        item_section([item_label("Staffing Optimizer")]),
                    ]),
                    item(clickable=true, href="/strategic-plan", [
                        item_section(avatar=true, [q__icon(name="map")]),
                        item_section([item_label("Strategic Planner")]),
                    ]),
                    item(clickable=true, href="/policy", [
                        item_section(avatar=true, [q__icon(name="gavel")]),
                        item_section([item_label("Policy Impact")]),
                    ]),
                    item(clickable=true, href="/disaster-resilience", [
                        item_section(avatar=true, [q__icon(name="emergency")]),
                        item_section([item_label("Disaster Resilience")]),
                    ]),
                    item(clickable=true, href="/capital-scoring", [
                        item_section(avatar=true, [q__icon(name="analytics")]),
                        item_section([item_label("Capital Scoring")]),
                    ]),

                    separator(class="q-my-sm"),
                    item_label(header=true, "Resources"),

                    item(clickable=true, href="/education", [
                        item_section(avatar=true, [q__icon(name="school")]),
                        item_section([item_label("Education Center")]),
                    ]),

                    # ── Dev tools (non-production only) ───────────────
                    if get(ENV, "GENIE_ENV", "dev") != "prod"
                        [
                            separator(class="q-my-sm"),
                            item_label(header=true, "Developer"),
                            item(clickable=true, href="/dev/components", [
                                item_section(avatar=true, [q__icon(name="widgets")]),
                                item_section([item_label("Component Library")]),
                            ]),
                        ]
                    else
                        []
                    end...,
                ])
            ]),

            # ── Main Content Area ────────────────────────────────────
            quasar(:page_container, [
                quasar(:page, padding=true, [
                    Html.div(class="q-pa-md", content)
                ]),
            ]),
        ]),

        script(src="/js/app.js"),
    ]
end
