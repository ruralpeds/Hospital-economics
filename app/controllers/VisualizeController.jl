"""
VisualizeController — API handlers for visualization workbench endpoints (E17).

Routes:
  POST /api/visualize/render
  POST /api/visualize/export
"""
module VisualizeController

using JSON3, Dates

function handle_render(payload::Dict)::Dict
    try
        asset_id     = html_escape(string(get(payload, "asset_id",     "")))
        chart_preset = html_escape(string(get(payload, "chart_preset", "cost_trend")))
        x_col        = html_escape(string(get(payload, "x_col",        "")))
        y_col        = html_escape(string(get(payload, "y_col",        "")))
        title_text   = html_escape(string(get(payload, "title_text",   "")))
        Dict(
            "status"       => "success",
            "asset_id"     => asset_id,
            "chart_preset" => chart_preset,
            "chart_data"   => Dict{String,Any}[],
            "computed_at"  => string(now()),
        )
    catch e
        Dict("status" => "error", "message" => sprint(showerror, e))
    end
end

function handle_export(payload::Dict)::Dict
    try
        format     = html_escape(string(get(payload, "format", "png")))
        chart_data = get(payload, "chart_data", Dict{String,Any}[])
        Dict(
            "status"     => "success",
            "format"     => format,
            "export_url" => "",
            "computed_at"=> string(now()),
        )
    catch e
        Dict("status" => "error", "message" => sprint(showerror, e))
    end
end

end  # module VisualizeController
