"""
Stipple reactive model for Revenue & Reimbursement (E8).
Simulates total revenue, denied claims, payer mix, and waterfall scenarios.
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in claims_asset_id::String = ""
    @in fee_schedule_asset_id::String = ""
    @in scenario::String = "current"
    @in policy_knob_1::Float64 = 0.0
    @in policy_knob_2::Float64 = 0.0
    @out total_revenue::Float64 = 0.0
    @out denied_total::Float64 = 0.0
    @out denial_rate::Float64 = 0.0
    @out payor_mix_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out denial_categories::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out payor_mix_data::Vector{PlotData} = PlotData[]
    @out payor_mix_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Payer Mix"),
        showlegend = true,
    )
    @out waterfall_data::Vector{PlotData} = PlotData[]
    @out waterfall_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Revenue Waterfall"),
        xaxis = [PlotLayoutAxis(title = "Category")],
        yaxis = [PlotLayoutAxis(title = "Amount (\$)")],
    )
    @in run_sim::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange run_sim begin
        run_sim || return
        running = true
        errors = String[]
        try
            total_revenue = 0.0
            denied_total = 0.0
            denial_rate = 0.0
            payor_mix_rows = Dict{String,Any}[]
            denial_categories = Dict{String,Any}[]
            payor_mix_data = PlotData[]
            waterfall_data = PlotData[]
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        run_sim = false
    end
end

const revenue_model = @init
