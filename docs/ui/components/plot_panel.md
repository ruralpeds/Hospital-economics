# PlotPanel

**Component file:** `app/components/plot_panel.jl`  
**Demo route:** `/dev/components#sec-plotpanel` (dev environment only)

## Overview

`PlotPanel` wraps StipplePlotly in a Quasar card with:
- Project colour palette (`PALETTE` constant — 8 accessible colours)
- Nine preset layout helpers for common chart types
- CI ribbon support (add low/high trace pairs manually)
- PNG and SVG export buttons (uses Plotly's native `downloadImage` API)
- Responsive height via CSS `height` argument

## Usage

```julia
plot_panel(
    data_field,
    layout_field;
    preset          = :trend,
    title           = "",
    export_filename = "chart",
    height          = "400px",
    class           = "",
)
```

### Arguments

| Argument | Type | Description |
|---|---|---|
| `data_field` | `Symbol` | `@out Vector{PlotData}` reactive field |
| `layout_field` | `Symbol` | `@out PlotLayout` reactive field |
| `preset` | `Symbol` | Preset hint for documentation intent (see presets) |
| `title` | `String` | Card header title (also shows export buttons) |
| `export_filename` | `String` | Base filename for PNG/SVG downloads |
| `height` | `String` | CSS height string (default `"400px"`) |
| `class` | `String` | Extra CSS classes |

### Preset layouts

Use `preset_layout(preset; title="")` to build a pre-configured `PlotLayout`:

| Preset | Description |
|---|---|
| `:trend` | Line/scatter over time, `hovermode="x unified"` |
| `:bar_breakdown` | Stacked bar, `barmode="stack"` |
| `:pie` | Pie/donut chart |
| `:scatter` | XY scatter, `hovermode="closest"` |
| `:tornado` | Horizontal tornado diagram, Y-axis reversed |
| `:forest` | Forest plot, zero-line at x=0 |
| `:km` | Kaplan–Meier survival curve, Y-axis 0–100 % |
| `:heatmap` | Heatmap / correlation matrix |
| `:geo` | Geographic / choropleth map |

## Example

```julia
# In the model (@app block):
@out margin_data::Vector{PlotData} = [
    PlotData(x=[2025,2026,2027], y=[-3.8,-2.6,-1.5],
             plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
             name="Operating Margin %", mode="lines+markers")
]
@out margin_layout::PlotLayout = preset_layout(:trend, title="Margin Trend")

# In the view (ui_* function):
plot_panel(:margin_data, :margin_layout,
    preset=:trend,
    title="Operating Margin Trend",
    export_filename="margin_trend",
    height="350px")
```

## Project palette

```julia
PlotPanel.PALETTE
# => ["#1976D2", "#26A69A", "#FB8C00", "#8E24AA",
#     "#43A047", "#E53935", "#00ACC1", "#6D4C41"]
```

Colours match the Quasar primary/secondary/accent design tokens used throughout the app.
