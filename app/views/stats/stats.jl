"""
Descriptive & Inferential Statistics UI (E11) — summary statistics, hypothesis
tests, and Table 1 generator.
"""

function ui_stats(model)
    app_layout(model, "Descriptive & Inferential Statistics", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Descriptive & Inferential Statistics", class="q-mb-none"),
                p("Summary statistics, hypothesis tests, confidence intervals, and Table 1",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Run", icon="functions", color="primary",
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

        # Parameters
        form_grid([
            (name=:asset_id,          type=:text,   label="Dataset Asset ID"),
            (name=:variable_col,      type=:text,   label="Variable Column",     help="Column to analyze"),
            (name=:group_col,         type=:text,   label="Group Column",         help="Grouping variable (optional)"),
            (name=:outcome_col,       type=:text,   label="Outcome Column",       help="For regression-based tests"),
            (name=:confidence_level,  type=:numeric, label="Confidence Level",   help="e.g. 0.95 for 95%"),
            (name=:test_type,         type=:select,  label="Hypothesis Test",
             options=[
                 Dict("value"=>"ttest",      "label"=>"t-Test"),
                 Dict("value"=>"anova",      "label"=>"ANOVA"),
                 Dict("value"=>"chisquare",  "label"=>"Chi-Square"),
                 Dict("value"=>"logrank",    "label"=>"Log-Rank"),
                 Dict("value"=>"wilcoxon",   "label"=>"Wilcoxon"),
             ]),
        ], title="Analysis Parameters"),

        # Sub-tabs
        qtabs(:active_sub_tab, class="q-mb-md", [
            qtab(name="descriptive", label="Descriptive"),
            qtab(name="tests",       label="Hypothesis Tests"),
            qtab(name="table1",      label="Table 1"),
        ]),
        qtabpanels(:active_sub_tab, [
            qtabpanel(name="descriptive", [
                row(class="q-mb-md", [
                    cell(class="col-xs-12", [
                        plot_panel(:dist_data, :dist_layout, preset=:histogram,
                            title="Distribution Plot"),
                    ]),
                ]),
                result_table(
                    :stats_rows,
                    columns=[
                        (name="statistic", label="Statistic", field="statistic", sortable=true),
                        (name="value",     label="Value",     field="value",     sortable=true),
                    ],
                    title="Summary Statistics",
                ),
            ]),
            qtabpanel(name="tests", [
                card(class="q-mb-md", [
                    card_section([
                        h6("Test Result", class="q-mb-sm"),
                        p("Statistic: {{ test_result.statistic || '—' }}"),
                        p("p-value: {{ test_result.p_value !== undefined ? test_result.p_value.toFixed(4) : '—' }}"),
                        p("Effect size: {{ test_result.effect_size || '—' }}"),
                    ]),
                ]),
            ]),
            qtabpanel(name="table1", [
                result_table(
                    :table1_rows,
                    columns=[
                        (name="variable",   label="Variable",    field="variable",  sortable=true),
                        (name="overall",    label="Overall",     field="overall",   sortable=false),
                        (name="group_a",    label="Group A",     field="group_a",   sortable=false),
                        (name="group_b",    label="Group B",     field="group_b",   sortable=false),
                        (name="p_value",    label="p-value",     field="p_value",   sortable=true),
                    ],
                    title="Baseline Characteristics (Table 1)",
                ),
            ]),
        ]),

        export_bar(csv_field=nothing, xlsx_field=nothing, json_field=nothing,
                   label="Export statistics"),
    ])
end
