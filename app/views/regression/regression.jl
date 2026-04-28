"""
Regression Lab UI (E12) — OLS, logistic, Poisson, Cox regression with
diagnostics and VIF analysis.
"""

function ui_regression(model)
    app_layout(model, "Regression Lab", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Regression Lab", class="q-mb-none"),
                p("OLS, logistic, Poisson, negative binomial, and Cox regression with diagnostics",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Fit Model", icon="show_chart", color="primary",
                    @click(:run),
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

        # Model specification
        form_grid([
            (name=:asset_id,     type=:text,   label="Dataset Asset ID"),
            (name=:model_type,   type=:select, label="Model Type",
             options=[
                 Dict("value"=>"ols",      "label"=>"OLS — Linear Regression"),
                 Dict("value"=>"logistic", "label"=>"Logistic Regression"),
                 Dict("value"=>"poisson",  "label"=>"Poisson Regression"),
                 Dict("value"=>"negbin",   "label"=>"Negative Binomial"),
                 Dict("value"=>"cox",      "label"=>"Cox Proportional Hazards"),
             ]),
            (name=:outcome_col,           type=:text,   label="Outcome Column"),
            (name=:robust_se,             type=:bool,   label="Robust Standard Errors"),
            (name=:include_interactions,  type=:bool,   label="Include 2-way Interactions"),
        ], title="Model Specification"),

        # Model statistics summary
        card(class="q-mb-md", [
            card_section([
                h6("Model Fit Statistics", class="q-mb-sm"),
                row([
                    cell(class="col-md-3 col-xs-6", [
                        p("R² / Pseudo-R²", class="text-overline q-mb-none"),
                        p("{{ model_stats.r_squared !== undefined ? model_stats.r_squared.toFixed(4) : '—' }}",
                          class="text-h6"),
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        p("AIC", class="text-overline q-mb-none"),
                        p("{{ model_stats.aic !== undefined ? model_stats.aic.toFixed(2) : '—' }}",
                          class="text-h6"),
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        p("N Observations", class="text-overline q-mb-none"),
                        p("{{ model_stats.n_obs || '—' }}", class="text-h6"),
                    ]),
                    cell(class="col-md-3 col-xs-6", [
                        p("Log-likelihood", class="text-overline q-mb-none"),
                        p("{{ model_stats.log_likelihood !== undefined ? model_stats.log_likelihood.toFixed(2) : '—' }}",
                          class="text-h6"),
                    ]),
                ]),
            ]),
        ]),

        # Coefficient table
        result_table(
            :coef_rows,
            columns=[
                (name="variable",   label="Variable",    field="variable",   sortable=true),
                (name="coef",       label="Coefficient", field="coef",       sortable=true),
                (name="std_err",    label="Std. Error",  field="std_err",    sortable=true),
                (name="t_stat",     label="t / z",       field="t_stat",     sortable=true),
                (name="p_value",    label="p-value",     field="p_value",    sortable=true),
                (name="ci_low",     label="CI Low",      field="ci_low",     sortable=true),
                (name="ci_high",    label="CI High",     field="ci_high",    sortable=true),
            ],
            title="Regression Coefficients",
        ),

        # Diagnostic plots
        row(class="q-mb-md q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                plot_panel(:diagnostic_data, :diagnostic_layout,
                    preset=:scatter, title="Residuals vs. Fitted"),
            ]),
            cell(class="col-md-6 col-xs-12", [
                plot_panel(:vif_data, :vif_layout,
                    preset=:bar, title="Variance Inflation Factors (VIF)"),
            ]),
        ]),

        export_bar(csv_field=nothing, xlsx_field=nothing, json_field=nothing,
                   label="Export regression results"),
    ])
end
