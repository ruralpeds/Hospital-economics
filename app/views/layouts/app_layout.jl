"""
Shared application layout with navigation sidebar.
Wraps all page content in a consistent Quasar layout with drawer navigation.
"""

function app_layout(model, page_title::String, content::Vector)
    page(model, class="app-layout", title="Hospital Economics — $page_title",
         prepend=join([
            stylesheet("https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap"),
            stylesheet("/css/app.css"),
         ]),
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
                        item_label(header=true, "Tools"),

                        item(clickable=true, href="/conversion", [
                            item_section(avatar=true, [q__icon(name="swap_horiz")]),
                            item_section([item_label("REH Conversion Wizard")]),
                        ]),

                        item(clickable=true, href="/closure-risk", [
                            item_section(avatar=true, [q__icon(name="warning")]),
                            item_section([item_label("Closure Risk Assessment")]),
                        ]),

                        item(clickable=true, href="/staffing", [
                            item_section(avatar=true, [q__icon(name="groups")]),
                            item_section([item_label("Staffing Optimizer")]),
                        ]),

                        separator(class="q-my-sm"),
                        item_label(header=true, "Resources"),

                        item(clickable=true, href="/education", [
                            item_section(avatar=true, [q__icon(name="school")]),
                            item_section([item_label("Education Center")]),
                        ]),
                    ])
                ]),

                # ── Main Content Area ────────────────────────────────────
                quasar(:page_container, [
                    quasar(:page, padding=true, [
                        Stipple.Html.div(class="q-pa-md", content)
                    ]),
                ]),
            ]),

            script(src="/js/app.js"),
         ]
    )
end
