"""
Causal Inference Lab UI (E13) — PSM, IV, DiD, RDD, and HTE analysis.
"""

function ui_causal(model)
    app_layout(model, "Causal Inference Lab", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Causal Inference Lab", class="q-mb-none"),
                p("Propensity score matching, IV analysis, DiD, regression discontinuity, and HTE",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Estimate", icon="science", color="primary",
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

        # Method selector
        form_grid([
            (name=:asset_id,      type=:text,   label="Dataset Asset ID"),
            (name=:method,        type=:select, label="Causal Method",
             options=[
                 Dict("value"=>"psm", "label"=>"Propensity Score Matching (PSM)"),
                 Dict("value"=>"iv",  "label"=>"Instrumental Variables (IV)"),
                 Dict("value"=>"did", "label"=>"Difference-in-Differences (DiD)"),
                 Dict("value"=>"rdd", "label"=>"Regression Discontinuity (RDD)"),
                 Dict("value"=>"hte", "label"=>"Heterogeneous Treatment Effects (HTE)"),
             ]),
            (name=:treatment_col, type=:text, label="Treatment Column"),
            (name=:outcome_col,   type=:text, label="Outcome Column"),
        ], title="Method & Variables"),

        # Method-specific params
        form_grid([
            (name=:instrument_col,    type=:text,    label="Instrument Column",   help="For IV analysis"),
            (name=:running_variable,  type=:text,    label="Running Variable",    help="For RDD"),
            (name=:cutoff,            type=:numeric, label="Cutoff Value",        help="RDD threshold"),
            (name=:pre_period,        type=:text,    label="Pre-Period",          help="DiD: e.g. 2019-01-01/2019-12-31"),
            (name=:post_period,       type=:text,    label="Post-Period",         help="DiD: e.g. 2020-01-01/2020-12-31"),
            (name=:treated_group,     type=:text,    label="Treated Group ID",    help="DiD: group identifier"),
        ], title="Method-Specific Parameters"),

        # Treatment effect KPIs
        row(class="q-mb-md q-gutter-md", [
            cell(class="col-md-4 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Treatment Effect (ATE)", class="text-overline q-mb-none"),
                    h4("{{ treatment_effect.toFixed(4) }}", class="q-mb-none",
                        var":class"="treatment_effect >= 0 ? 'text-positive' : 'text-negative'"),
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section(class="text-center", [
                    p("95% CI Lower", class="text-overline q-mb-none"),
                    h4("{{ effect_ci_low.toFixed(4) }}", class="q-mb-none"),
                ])])
            ]),
            cell(class="col-md-4 col-xs-12", [
                card([card_section(class="text-center", [
                    p("95% CI Upper", class="text-overline q-mb-none"),
                    h4("{{ effect_ci_high.toFixed(4) }}", class="q-mb-none"),
                ])])
            ]),
        ]),

        # Covariate balance table
        result_table(
            :balance_rows,
            columns=[
                (name="covariate",     label="Covariate",      field="covariate",     sortable=true),
                (name="mean_treated",  label="Mean (Treated)", field="mean_treated",  sortable=true),
                (name="mean_control",  label="Mean (Control)", field="mean_control",  sortable=true),
                (name="std_diff",      label="Std. Diff.",     field="std_diff",      sortable=true),
                (name="balanced",      label="Balanced?",      field="balanced",      sortable=true),
            ],
            title="Covariate Balance",
        ),

        # Effect and parallel trends plots
        row(class="q-mb-md q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                plot_panel(:effect_plot_data, :effect_plot_layout,
                    preset=:scatter, title="Treatment Effect Plot"),
            ]),
            cell(class="col-md-6 col-xs-12", [
                plot_panel(:parallel_trends_data, :parallel_trends_layout,
                    preset=:line, title="Parallel Trends Test"),
            ]),
        ]),

        export_bar(csv_field=nothing, xlsx_field=nothing, json_field=nothing,
                   label="Export causal analysis"),
    ])
end
