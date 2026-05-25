"""
Gaussian Copula Monte Carlo UI — correlated bivariate simulation.
"""

function ui_copula_mc(model)
    app_layout(model, "Copula Monte Carlo", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Gaussian Copula Monte Carlo", class="q-mb-none"),
                p("Generate correlated samples using a Gaussian copula for bivariate analysis",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Generate", icon="casino", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ──────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Target Correlation", class="text-overline q-mb-none"),
                    h4("{{ correlation.toFixed(2) }}", class="q-mb-none text-primary"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Empirical Correlation", class="text-overline q-mb-none"),
                    h4("{{ empirical_corr_12.toFixed(4) }}", class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-4 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Simulations", class="text-overline q-mb-none"),
                    h4("{{ n_simulations.toLocaleString() }}", class="q-mb-none text-orange"),
                ])])
            ]),
        ]),

        # ── Inputs ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    h6("Variable 1", class="q-mb-md"),
                    textfield(:var1_mean, label="Mean", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:var1_std, label="Std Deviation", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    h6("Variable 2", class="q-mb-md"),
                    textfield(:var2_mean, label="Mean", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:var2_std, label="Std Deviation", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section([
                    h6("Simulation Settings", class="q-mb-md"),
                    textfield(:n_simulations, label="Number of Simulations", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    slider(:correlation, label=true,
                           var":label-value"="'Correlation: ' + correlation.toFixed(2)",
                           var":min"="-0.99", var":max"="0.99", var":step"="0.01", class="q-mb-sm"),
                    textfield(:random_seed, label="Random Seed", type="number",
                              filled=true, dense=true),
                ])])
            ]),
        ]),

        # ── Scatter Plot ───────────────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:scatter_data, layout=:scatter_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Summary Statistics Table ───────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    h6("Summary Statistics", class="q-mb-md"),
                    table(var":rows"="summary_table",
                          var":columns"="[
                              {name: 'variable', label: 'Variable', field: 'variable', align: 'left'},
                              {name: 'mean', label: 'Mean', field: 'mean', align: 'right'},
                              {name: 'std', label: 'Std Dev', field: 'std', align: 'right'},
                              {name: 'min', label: 'Min', field: 'min', align: 'right'},
                              {name: 'max', label: 'Max', field: 'max', align: 'right'}
                          ]",
                          flat=true, bordered=true, dense=true,
                          var"row-key"="'variable'"),
                ])])
            ]),
        ]),

        # ── Correlation Matrix Display ─────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Target Correlation Matrix", class="q-mb-md"),
                    p("[1.00, {{ correlation.toFixed(2) }}]", class="text-body1 text-weight-medium"),
                    p("[{{ correlation.toFixed(2) }}, 1.00]", class="text-body1 text-weight-medium"),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Empirical Correlation Matrix", class="q-mb-md"),
                    p("[1.00, {{ empirical_corr_12.toFixed(4) }}]", class="text-body1 text-weight-medium"),
                    p("[{{ empirical_corr_12.toFixed(4) }}, 1.00]", class="text-body1 text-weight-medium"),
                ])])
            ]),
        ]),
    ])
end
