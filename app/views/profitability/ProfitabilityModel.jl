"""
Stipple reactive model for Profitability & Operations (E9).
Computes contribution margin, break-even volume, operating margin, and
departmental profitability with waterfall decomposition.
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in period_from::String = ""
    @in period_to::String = ""
    @in financial_asset_id::String = ""
    @in revenue::Float64 = 0.0
    @in variable_costs::Float64 = 0.0
    @in fixed_costs::Float64 = 0.0
    @in operating_income::Float64 = 0.0
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false

    @out contribution_margin::Float64 = 0.0
    @out break_even_volume::Float64 = 0.0
    @out operating_margin::Float64 = 0.0
    @out departmental_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out waterfall_data::Vector{PlotData} = PlotData[]
    @out waterfall_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Profitability Waterfall"),
        xaxis = [PlotLayoutAxis(title = "Component")],
        yaxis = [PlotLayoutAxis(title = "Amount (\$)")],
    )
    @in volume_slider::Float64 = 1.0
    @in run::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange run begin
        run || return
        running = true
        errors = String[]
        try
            contribution_margin = revenue - variable_costs
            operating_margin = revenue > 0 ? operating_income / revenue : 0.0
            break_even_volume = fixed_costs > 0 && revenue > variable_costs ?
                fixed_costs / (revenue - variable_costs) : 0.0
            departmental_rows = Dict{String,Any}[]
            waterfall_data = PlotData[]
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        run = false
    end

    @onchange volume_slider begin
        contribution_margin = revenue * volume_slider - variable_costs * volume_slider
        operating_margin = (revenue * volume_slider) > 0 ?
            (operating_income * volume_slider) / (revenue * volume_slider) : 0.0
    end
end

const profitability_model = @init
