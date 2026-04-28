"""
Visualization Workbench UI (E17) — asset picker, preset selector,
column mapping, and Plotly chart preview.
"""

function ui_visualize(model)
    app_layout(model, "Visualization Workbench", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Visualization Workbench", class="q-mb-none"),
                p("Build charts from any dataset: cost trends, CE planes, survival curves, forest plots, and more",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Render Chart", icon="bar_chart", color="primary",
                    @click(:do_render),
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

        # Configuration
        form_grid([
            (name=:asset_id,      type=:text,   label="Dataset Asset ID",      help="Asset from Data Intake or Cohort Builder"),
            (name=:chart_preset,  type=:select, label="Chart Preset",
             options=[
                 Dict("value"=>"cost_trend",       "label"=>"Cost Trend"),
                 Dict("value"=>"cost_breakdown",    "label"=>"Cost Breakdown"),
                 Dict("value"=>"quality_dashboard", "label"=>"Quality Dashboard"),
                 Dict("value"=>"ce_plane",          "label"=>"CE Plane"),
                 Dict("value"=>"tornado",           "label"=>"Tornado Diagram"),
                 Dict("value"=>"survival",          "label"=>"Survival Curve"),
                 Dict("value"=>"forest",            "label"=>"Forest Plot"),
                 Dict("value"=>"heatmap",           "label"=>"Heatmap"),
                 Dict("value"=>"geo_map",           "label"=>"Geographic Map"),
             ]),
            (name=:x_col,         type=:text,   label="X-Axis Column"),
            (name=:y_col,         type=:text,   label="Y-Axis Column"),
            (name=:color_col,     type=:text,   label="Color / Series Column", help="Optional grouping for color"),
            (name=:group_col,     type=:text,   label="Panel / Facet Column",  help="Optional faceting variable"),
            (name=:title_text,    type=:text,   label="Chart Title"),
        ], title="Chart Configuration"),

        # Chart preview
        row(class="q-mb-md", [
            cell(class="col-xs-12", [
                plot_panel(:chart_data, :chart_layout, preset=:line, title="Chart Preview"),
            ]),
        ]),

        # Export actions
        row(class="q-mb-md q-gutter-sm", [
            cell(class="col-auto", [
                btn("Export PNG", icon="image", color="secondary",
                    @click(:do_export_png), outline=true),
            ]),
            cell(class="col-auto", [
                btn("Export SVG", icon="picture_as_pdf", color="secondary",
                    @click(:do_export_svg), outline=true),
            ]),
        ]),

        export_bar(csv_field=nothing, xlsx_field=nothing, json_field=nothing,
                   label="Export chart data"),
    ])
end
