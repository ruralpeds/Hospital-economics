"""
Education Center UI - topics, glossary, and tutorials for rural hospital finance.
"""

function ui_education(model)
    app_layout(model, "Education Center", [
        row(class="q-mb-md", [
            cell(class="col", [
                h5("Education Center", class="q-mb-none"),
                p("Learn about rural hospital finance, policy, and the tools in this simulator",
                  class="text-grey-7"),
            ]),
        ]),

        # ── Section Navigation ───────────────────────────────────────────
        tabs(:active_section, dense=true, class="q-mb-lg bg-grey-2", [
            tab(name="topics", label="Topics", icon="school"),
            tab(name="glossary", label="Glossary", icon="menu_book"),
            tab(name="tutorials", label="Tutorials", icon="play_circle"),
            tab(name="detail", label="Article", icon="article",
                var"v-if"="active_section === 'detail'"),
        ]),

        tab_panels(:active_section, animated=true, [
            # ── Topics ───────────────────────────────────────────────────
            tab_panel(name="topics", [
                row(class="q-gutter-md", [
                    cell(var"v-for"="topic in topics", key!="topic.id",
                         class="col-md-4 col-sm-6 col-xs-12", [
                        card(class="cursor-pointer full-height",
                             @click("selected_topic = topic.id"), [
                            card_section([
                                row(class="items-center q-mb-sm", [
                                    badge("{{ topic.category }}", color="primary", class="q-mr-sm"),
                                    badge("{{ topic.difficulty }}",
                                        var":color"="""topic.difficulty === 'beginner' ? 'green' :
                                                        topic.difficulty === 'intermediate' ? 'orange' : 'red'"""),
                                ]),
                                h6("{{ topic.title }}", class="q-mb-sm"),
                                p("{{ topic.summary }}", class="text-body2 text-grey-7"),
                            ]),
                        ])
                    ]),
                ]),
            ]),

            # ── Topic Detail ─────────────────────────────────────────────
            tab_panel(name="detail", [
                card(var"v-if"="selected_topic_content.title", [
                    card_section([
                        btn("Back to Topics", icon="arrow_back", flat=true,
                            @click("active_section = 'topics'; selected_topic = ''"),
                            class="q-mb-md"),
                        row(class="items-center q-mb-md", [
                            badge("{{ selected_topic_content.category }}", color="primary", class="q-mr-sm"),
                            badge("{{ selected_topic_content.difficulty }}",
                                var":color"="""selected_topic_content.difficulty === 'beginner' ? 'green' :
                                               selected_topic_content.difficulty === 'intermediate' ? 'orange' : 'red'"""),
                        ]),
                        h4("{{ selected_topic_content.title }}", class="q-mb-md"),
                        p("{{ selected_topic_content.content }}", class="text-body1",
                          style="line-height: 1.8; max-width: 800px"),
                    ])
                ]),
            ]),

            # ── Glossary ─────────────────────────────────────────────────
            tab_panel(name="glossary", [
                card(class="q-mb-md", [
                    card_section([
                        textfield(:glossary_search, label="Search glossary...",
                            filled=true, dense=true, clearable=true,
                            var"prepend-inner-icon"="search"),
                    ])
                ]),
                card([
                    card_section([
                        q__list(separator=true, [
                            item(var"v-for"="term in (glossary_search ? filtered_glossary : glossary_terms)",
                                 key!="term.term", [
                                item_section(avatar=true, [
                                    avatar(color="primary", var"text-color"="white", [
                                        span("{{ term.term.charAt(0) }}")
                                    ])
                                ]),
                                item_section([
                                    item_label("{{ term.term }}"),
                                    item_label("{{ term.definition }}", caption=true),
                                ]),
                            ]),
                        ])
                    ])
                ]),
            ]),

            # ── Tutorials ────────────────────────────────────────────────
            tab_panel(name="tutorials", [
                card(class="q-mb-md", [
                    card_section([
                        h6("Getting Started Tutorial", class="q-mb-md"),
                        p("Follow these steps to run your first financial simulation.",
                          class="q-mb-md text-grey-7"),

                        stepper(:tutorial_step, vertical=true, animated=true, [
                            step(val=1, title="Set Up Hospital Profile", icon="business",
                                done=true, [
                                p("Navigate to the Hospital Profile page and enter your hospital's basic information, financial data, and volume statistics."),
                                p("You can start with sample data and modify it to match your hospital.", class="text-caption text-grey"),
                                step_navigation([
                                    btn("Next", color="primary", @click("tutorial_step = 2")),
                                ]),
                            ]),

                            step(val=2, title="Create a Scenario", icon="science", [
                                p("Go to the Scenario Builder and create your first scenario. Choose 'Baseline' to project current trends, or create a scenario with specific assumptions about revenue growth, cost changes, or policy impacts."),
                                step_navigation([
                                    btn("Back", flat=true, @click("tutorial_step = 1")),
                                    btn("Next", color="primary", @click("tutorial_step = 3")),
                                ]),
                            ]),

                            step(val=3, title="Configure Simulation", icon="settings", [
                                p("In the Simulation Runner, select your scenario and choose a methodology. Monte Carlo simulation is recommended for understanding uncertainty. Set the number of iterations (1,000 is a good starting point) and projection horizon."),
                                step_navigation([
                                    btn("Back", flat=true, @click("tutorial_step = 2")),
                                    btn("Next", color="primary", @click("tutorial_step = 4")),
                                ]),
                            ]),

                            step(val=4, title="Run and Review Results", icon="assessment", [
                                p("Click 'Run Simulation' and wait for completion. Then explore the Results page to see projected margins, probability distributions, and sensitivity analysis. Compare multiple scenarios side by side."),
                                step_navigation([
                                    btn("Back", flat=true, @click("tutorial_step = 3")),
                                    btn("Next", color="primary", @click("tutorial_step = 5")),
                                ]),
                            ]),

                            step(val=5, title="Explore Advanced Features", icon="explore", [
                                p("Try the REH Conversion Wizard to evaluate converting to a Rural Emergency Hospital. Use the Closure Risk Assessment to identify vulnerabilities. Explore the Staffing Optimizer to find labor cost savings."),
                                step_navigation([
                                    btn("Back", flat=true, @click("tutorial_step = 4")),
                                    btn("Start Over", color="primary", @click("tutorial_step = 1")),
                                ]),
                            ]),
                        ]),
                    ])
                ]),
            ]),
        ]),
    ])
end
