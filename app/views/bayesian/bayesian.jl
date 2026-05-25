"""
Bayesian Beta-Binomial Analysis UI — conjugate updating with posterior visualization.
"""

function ui_bayesian(model)
    app_layout(model, "Bayesian Analysis", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Bayesian Beta-Binomial Analysis", class="q-mb-none"),
                p("Conjugate updating of Beta prior with binomial observations",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Analyze", icon="psychology", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ──────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Posterior Mean", class="text-overline q-mb-none"),
                    h4("{{ (posterior_mean * 100).toFixed(2) }}%", class="q-mb-none text-primary"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Posterior Std", class="text-overline q-mb-none"),
                    h4("{{ (posterior_std * 100).toFixed(2) }}%", class="q-mb-none text-orange"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("95% Credible Interval", class="text-overline q-mb-none"),
                    h4("[{{ (ci_lower * 100).toFixed(1) }}%, {{ (ci_upper * 100).toFixed(1) }}%]",
                       class="q-mb-none text-green"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Prior Mean", class="text-overline q-mb-none"),
                    h4("{{ (prior_mean * 100).toFixed(2) }}%", class="q-mb-none text-grey-7"),
                ])])
            ]),
        ]),

        # ── Inputs ─────────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Prior Distribution", class="q-mb-md"),
                    p("Beta prior: higher alpha/beta = stronger prior belief", class="text-grey-7 q-mb-sm"),
                    textfield(:prior_alpha, label="Prior Alpha", type="number",
                              filled=true, dense=true, class="q-mb-sm",
                              hint="Shape parameter alpha (default 1 = uniform)"),
                    textfield(:prior_beta, label="Prior Beta", type="number",
                              filled=true, dense=true, class="q-mb-sm",
                              hint="Shape parameter beta (default 1 = uniform)"),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Observed Data", class="q-mb-md"),
                    p("Binomial observations to update the prior", class="text-grey-7 q-mb-sm"),
                    textfield(:observed_events, label="Observed Events (successes)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:total_observations, label="Total Observations (trials)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    p("Observed rate: {{ total_observations > 0 ? ((observed_events / total_observations) * 100).toFixed(1) : '0.0' }}%",
                      class="text-grey-7"),
                ])])
            ]),
        ]),

        # ── Posterior Density Chart ────────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:density_chart_data, layout=:density_chart_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),

        # ── Prior vs Posterior Comparison ──────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Prior Distribution", class="q-mb-md"),
                    p("Beta({{ prior_alpha.toFixed(1) }}, {{ prior_beta.toFixed(1) }})",
                      class="text-h6 text-weight-medium"),
                    p("Mean: {{ (prior_mean * 100).toFixed(2) }}%", class="text-body1"),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Posterior Distribution", class="q-mb-md"),
                    p("Beta({{ posterior_alpha.toFixed(1) }}, {{ posterior_beta_out.toFixed(1) }})",
                      class="text-h6 text-weight-medium text-primary"),
                    p("Mean: {{ (posterior_mean * 100).toFixed(2) }}%", class="text-body1"),
                    p("Std: {{ (posterior_std * 100).toFixed(2) }}%", class="text-body1"),
                    p("95% CI: [{{ (ci_lower * 100).toFixed(2) }}%, {{ (ci_upper * 100).toFixed(2) }}%]",
                      class="text-body1 text-green"),
                ])])
            ]),
        ]),
    ])
end
