"""
Stipple reactive model for Visualization Workbench (E17).
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in asset_id::String = ""
    @in chart_preset::String = "cost_trend"
    @in x_col::String = ""
    @in y_col::String = ""
    @in color_col::String = ""
    @in group_col::String = ""
    @in title_text::String = ""
    @out chart_data::Vector{PlotData} = PlotData[]
    @out chart_layout::PlotLayout = PlotLayout()
    @out available_presets::Vector{Dict{String,Any}} = [
        Dict("value"=>"cost_trend",         "label"=>"Cost Trend"),
        Dict("value"=>"cost_breakdown",      "label"=>"Cost Breakdown"),
        Dict("value"=>"quality_dashboard",   "label"=>"Quality Dashboard"),
        Dict("value"=>"ce_plane",            "label"=>"CE Plane"),
        Dict("value"=>"tornado",             "label"=>"Tornado Diagram"),
        Dict("value"=>"survival",            "label"=>"Survival Curve"),
        Dict("value"=>"forest",              "label"=>"Forest Plot"),
        Dict("value"=>"heatmap",             "label"=>"Heatmap"),
        Dict("value"=>"geo_map",             "label"=>"Geographic Map"),
    ]
    @in do_render::Bool = false
    @in do_export_png::Bool = false
    @in do_export_svg::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange do_render begin
        do_render || return
        running = true
        errors = String[]
        try
            chart_data = PlotData[]
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        do_render = false
    end
end

const visualize_model = @init
