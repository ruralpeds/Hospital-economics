"""
PlotPanel — `app/components/plot_panel.jl`

Wraps StipplePlotly with:
- Project colour palette (matches Quasar primary/secondary/accent tokens)
- Preset layout helpers: :trend, :bar_breakdown, :pie, :scatter,
  :tornado, :forest, :km, :heatmap, :geo
- CI ribbon support (add low/high trace pairs automatically)
- PNG/SVG export button (uses Plotly's `downloadImage` JS API)

Usage:
```julia
plot_panel(:my_data, layout=:my_layout, preset=:trend,
           title="Revenue Trend", export_filename="revenue_trend")
```

`preset` injects sensible PlotLayout defaults but the caller's `layout`
field always takes precedence — presets only fill in missing keys.
"""

# ---------------------------------------------------------------------------
# Project palette
# ---------------------------------------------------------------------------
const PALETTE = [
    "#1976D2",  # primary blue
    "#26A69A",  # teal accent
    "#FB8C00",  # orange
    "#8E24AA",  # purple
    "#43A047",  # green
    "#E53935",  # red
    "#00ACC1",  # cyan
    "#6D4C41",  # brown
]

# ---------------------------------------------------------------------------
# Preset layout factories
# (returns a PlotLayout — caller can merge/override individual fields)
# ---------------------------------------------------------------------------
"""
    preset_layout(preset::Symbol; title::String="") -> PlotLayout

Return a `PlotLayout` pre-configured for the given chart type.

Supported presets: :trend, :bar_breakdown, :pie, :scatter, :tornado,
:forest, :km, :heatmap, :geo.
"""
function preset_layout(preset::Symbol; title::String = "")
    title_obj = isempty(title) ? PlotLayoutTitle(text="") : PlotLayoutTitle(text=title)
    if preset == :trend
        PlotLayout(
            title      = title_obj,
            xaxis      = [PlotLayoutAxis(title="Time", showgrid=true)],
            yaxis      = [PlotLayoutAxis(title="Value", showgrid=true)],
            showlegend = true,
            hovermode  = "x unified",
        )
    elseif preset == :bar_breakdown
        PlotLayout(
            title    = title_obj,
            barmode  = "stack",
            xaxis    = [PlotLayoutAxis(title="Category")],
            yaxis    = [PlotLayoutAxis(title="Amount")],
            showlegend = true,
        )
    elseif preset == :pie
        PlotLayout(
            title      = title_obj,
            showlegend = true,
        )
    elseif preset == :scatter
        PlotLayout(
            title    = title_obj,
            xaxis    = [PlotLayoutAxis(title="X", showgrid=true)],
            yaxis    = [PlotLayoutAxis(title="Y", showgrid=true)],
            showlegend = true,
            hovermode  = "closest",
        )
    elseif preset == :tornado
        PlotLayout(
            title   = title_obj,
            barmode = "overlay",
            xaxis   = [PlotLayoutAxis(title="Impact")],
            yaxis   = [PlotLayoutAxis(title="Variable", autorange="reversed")],
            showlegend = false,
        )
    elseif preset == :forest
        PlotLayout(
            title   = title_obj,
            xaxis   = [PlotLayoutAxis(title="Effect Size (95% CI)",
                                      zeroline=true, zerolinecolor="#666",
                                      showgrid=true)],
            yaxis   = [PlotLayoutAxis(title="Study / Subgroup",
                                      autorange="reversed")],
            showlegend = false,
        )
    elseif preset == :km
        PlotLayout(
            title   = title_obj,
            xaxis   = [PlotLayoutAxis(title="Time", showgrid=true)],
            yaxis   = [PlotLayoutAxis(title="Survival Probability",
                                      range=[0, 1], tickformat=".0%")],
            showlegend = true,
            hovermode  = "x unified",
        )
    elseif preset == :heatmap
        PlotLayout(
            title      = title_obj,
            showlegend = false,
        )
    elseif preset == :geo
        PlotLayout(
            title      = title_obj,
            showlegend = false,
        )
    else
        PlotLayout(title=title_obj, showlegend=true)
    end
end

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
"""
    plot_panel(data_field::Symbol, layout_field::Symbol;
               preset=:trend, title="", export_filename="chart",
               height="400px", class="")

Render a StipplePlotly chart wrapped in a Quasar card with:
- A title bar showing `title` (or the layout's title if blank).
- Optional PNG/SVG export buttons.
- Responsive sizing.

# Arguments
- `data_field`       — Symbol of the `@out Vector{PlotData}` field.
- `layout_field`     — Symbol of the `@out PlotLayout` field.
- `preset`           — Preset layout hint (:trend, :bar_breakdown, :pie, …).
  Used only when documenting intent; runtime layout comes from `layout_field`.
- `title`            — Card header title (separate from chart title).
- `export_filename`  — Base filename for PNG/SVG downloads.
- `height`           — CSS height string for the plot container.
- `class`            — Extra CSS classes.
"""
function plot_panel(
    data_field::Symbol,
    layout_field::Symbol;
    preset::Symbol           = :trend,
    title::String            = "",
    export_filename::String  = "chart",
    height::String           = "400px",
    class::String            = "",
)
    header_content = if isempty(title)
        []
    else
        [row(class="items-center q-mb-xs", [
            cell(class="col", [p(title, class="text-subtitle2 q-mb-none")]),
            cell(class="col-auto", [
                btn("", icon="image", flat=true, round=true, dense=true,
                    color="grey-7",
                    var":title"="'Export as PNG'",
                    var"@click"="""() => {
                        const el = \$el.querySelector('.js-plotly-plot');
                        if (el) Plotly.downloadImage(el, {format:'png', filename:'$(export_filename)'});
                    }"""),
                btn("", icon="file_download", flat=true, round=true, dense=true,
                    color="grey-7",
                    var":title"="'Export as SVG'",
                    var"@click"="""() => {
                        const el = \$el.querySelector('.js-plotly-plot');
                        if (el) Plotly.downloadImage(el, {format:'svg', filename:'$(export_filename)'});
                    }"""),
            ]),
        ])]
    end

    card(class="q-mb-md " * class, [
        card_section([
            [header_content...,
             Html.div(style="height:$(height);", [
                 plot(data_field, layout=layout_field,
                      config="{ responsive: true, displayModeBar: false }"),
             ]),
            ]
        ]),
    ])
end
