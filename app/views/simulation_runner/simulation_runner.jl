"""
Simulation Runner UI - methodology selection, parameter config, and progress tracking.
"""

function ui_simulation_runner(model)
    app_layout(model, "Run Simulation", [
        row(class="q-mb-md", [
            cell(class="col", [
                h5("Simulation Runner", class="q-mb-none"),
                p("Configure and execute financial projections", class="text-grey-7"),
            ]),
        ]),

        # ── Step 1: Methodology & Scenario ───────────────────────────────
        card(class="q-mb-md", [
            card_section([
                h6("1. Select Methodology & Scenario", class="q-mb-md"),
                row(class="q-gutter-md", [
                    cell(class="col-md-6 col-xs-12", [
                        q__select(:methodology, options=:methodology_options,
                            label="Simulation Methodology", filled=true,
                            var"emit-value"=true, var"map-options"=true),
                        p(class="text-caption text-grey q-mt-sm",
                          var"v-if"="methodology === 'monte_carlo'",
                          "Runs thousands of random iterations to produce probability distributions of outcomes."),
                        p(class="text-caption text-grey q-mt-sm",
                          var"v-if"="methodology === 'deterministic'",
                          "Single-path projection using fixed assumptions. Fast but does not capture uncertainty."),
                        p(class="text-caption text-grey q-mt-sm",
                          var"v-if"="methodology === 'sensitivity'",
                          "Varies one parameter at a time to show impact on key outcomes."),
                        p(class="text-caption text-grey q-mt-sm",
                          var"v-if"="methodology === 'stress_test'",
                          "Applies extreme adverse scenarios to test financial resilience."),
                    ]),
                    cell(class="col-md-6 col-xs-12", [
                        q__select(:selected_scenario_id, options=:scenario_options,
                            label="Scenario", filled=true,
                            var"emit-value"=true, var"map-options"=true),
                    ]),
                ]),
            ])
        ]),

        # ── Step 2: Method-specific Parameters ───────────────────────────
        # Monte Carlo parameters
        card(var"v-if"="methodology === 'monte_carlo'", class="q-mb-md", [
            card_section([
                h6("2. Monte Carlo Parameters", class="q-mb-md"),
                row(class="q-gutter-md", [
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:mc_iterations, label="Iterations", filled=true, dense=true,
                            hint="100 - 50,000")
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:mc_confidence_level, label="Confidence Level (%)",
                            filled=true, dense=true, step="0.5")
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        q__select(:mc_distribution, options=:distribution_options,
                            label="Distribution", filled=true, dense=true,
                            var"emit-value"=true, var"map-options"=true)
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:mc_seed, label="Random Seed", filled=true, dense=true)
                    ]),
                ]),
                toggle(:mc_correlation_enabled, label="Enable variable correlations", class="q-mt-md"),
                separator(class="q-my-md"),
                p("Uncertainty Ranges", class="text-subtitle2"),
                row(class="q-gutter-md", [
                    cell(class="col-md-3 col-xs-6", [
                        p("Revenue Growth", class="text-caption q-mb-xs"),
                        range_slider(class="q-px-md",
                            var"v-model:min"="revenue_uncertainty_low",
                            var"v-model:max"="revenue_uncertainty_high",
                            min=-20, max=20, step=0.5, label=true, color="primary")
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        p("Volume Change", class="text-caption q-mb-xs"),
                        range_slider(class="q-px-md",
                            var"v-model:min"="volume_uncertainty_low",
                            var"v-model:max"="volume_uncertainty_high",
                            min=-30, max=15, step=0.5, label=true, color="teal")
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        p("Expense Growth", class="text-caption q-mb-xs"),
                        range_slider(class="q-px-md",
                            var"v-model:min"="expense_uncertainty_low",
                            var"v-model:max"="expense_uncertainty_high",
                            min=-5, max=20, step=0.5, label=true, color="red")
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        p("Rate Updates", class="text-caption q-mb-xs"),
                        range_slider(class="q-px-md",
                            var"v-model:min"="rate_uncertainty_low",
                            var"v-model:max"="rate_uncertainty_high",
                            min=-10, max=10, step=0.5, label=true, color="orange")
                    ]),
                ]),
            ])
        ]),

        # Sensitivity parameters
        card(var"v-if"="methodology === 'sensitivity'", class="q-mb-md", [
            card_section([
                h6("2. Sensitivity Analysis Parameters", class="q-mb-md"),
                row(class="q-gutter-md", [
                    cell(class="col-md-4 col-xs-12", [
                        q__select(:sensitivity_variable, options=:sensitivity_variables,
                            label="Variable to Analyze", filled=true,
                            var"emit-value"=true, var"map-options"=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:sensitivity_range_low, label="Range Low (%)",
                            filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:sensitivity_range_high, label="Range High (%)",
                            filled=true, dense=true)
                    ]),
                    cell(class="col-md-2 col-xs-6", [
                        numberfield(:sensitivity_steps, label="Steps", filled=true, dense=true)
                    ]),
                ]),
            ])
        ]),

        # Stress test parameters
        card(var"v-if"="methodology === 'stress_test'", class="q-mb-md", [
            card_section([
                h6("2. Stress Test Scenarios", class="q-mb-md"),
                p("Select adverse scenarios to apply:", class="q-mb-md"),
                option_group(:stress_scenarios_enabled, options=:stress_scenario_options,
                    type="checkbox", color="red"),
            ])
        ]),

        # ── Step 3: Projection Settings ──────────────────────────────────
        card(class="q-mb-md", [
            card_section([
                h6("3. Projection Settings", class="q-mb-md"),
                row(class="q-gutter-md", [
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:projection_years, label="Projection Years",
                            filled=true, dense=true, min="1", max="20")
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:projection_start_year, label="Start Year",
                            filled=true, dense=true)
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:discount_rate, label="Discount Rate (%)",
                            filled=true, dense=true, step="0.1")
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        numberfield(:terminal_growth_rate, label="Terminal Growth (%)",
                            filled=true, dense=true, step="0.1")
                    ]),
                ]),
            ])
        ]),

        # ── Validation Warnings ──────────────────────────────────────────
        quasar(:banner, var"v-for"="warn in validation_warnings", class="q-mb-sm bg-orange-1",
            dense=true, rounded=true, [
            q__icon(name="warning", color="orange", class="q-mr-sm"),
            span("{{ warn }}"),
        ]),

        # ── Run Controls ─────────────────────────────────────────────────
        card(class="q-mb-md", [
            card_section(class="text-center", [
                btn("Run Simulation", icon="play_arrow", color="primary", size="lg",
                    var"v-if"="simulation_status !== 'running'",
                    var":disable"="!can_run",
                    @click(:run_simulation)),
                btn("Cancel", icon="stop", color="red", size="lg",
                    var"v-if"="simulation_status === 'running'",
                    @click(:cancel_simulation)),
            ])
        ]),

        # ── Progress Tracking ────────────────────────────────────────────
        card(var"v-if"="simulation_status !== 'idle'", class="q-mb-md", [
            card_section([
                h6("Simulation Progress", class="q-mb-md"),
                linear_progress(var":value"="simulation_progress / 100",
                    size="24px", rounded=true,
                    var":color"="simulation_status === 'completed' ? 'green' :
                                 simulation_status === 'failed' ? 'red' :
                                 simulation_status === 'cancelled' ? 'orange' : 'primary'",
                    [
                        span(class="absolute-full flex flex-center text-white text-caption",
                             "{{ simulation_progress.toFixed(0) }}%")
                    ]),
                row(class="q-mt-md q-gutter-md text-center", [
                    cell(class="col", [
                        p("Status", class="text-overline q-mb-none"),
                        badge("{{ simulation_status }}", var":color"="""
                            simulation_status === 'completed' ? 'green' :
                            simulation_status === 'running' ? 'blue' :
                            simulation_status === 'failed' ? 'red' : 'grey'"""),
                    ]),
                    cell(class="col", [
                        p("Iterations", class="text-overline q-mb-none"),
                        span("{{ iterations_completed }}"),
                    ]),
                    cell(class="col", [
                        p("Elapsed", class="text-overline q-mb-none"),
                        span("{{ elapsed_seconds.toFixed(1) }}s"),
                    ]),
                    cell(class="col", [
                        p("Remaining", class="text-overline q-mb-none"),
                        span("{{ estimated_remaining.toFixed(1) }}s"),
                    ]),
                    cell(class="col", [
                        p("Sim ID", class="text-overline q-mb-none"),
                        span(class="text-caption", "{{ simulation_id }}"),
                    ]),
                ]),
                p("{{ status_message }}", class="q-mt-md text-center text-grey-7"),
                p(var"v-if"="error_message", class="text-red text-center", "{{ error_message }}"),

                # Link to results when done
                row(var"v-if"="simulation_status === 'completed'", class="q-mt-md text-center", [
                    cell(class="col", [
                        btn("View Results", icon="assessment", color="green",
                            href="/results", target="_self"),
                    ]),
                ]),
            ])
        ]),
    ])
end
