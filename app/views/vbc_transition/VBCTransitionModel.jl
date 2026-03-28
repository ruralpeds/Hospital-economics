"""
Stipple reactive model for Value-Based Care Transition.
Models shared savings/loss calculations for Medicare ACO programs.
"""
using Stipple, StippleUI, StipplePlotly


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in model_type::String = "mssp_basic"
    @in total_cost_of_care::Float64 = 55_000_000.0
    @in benchmark::Float64 = 60_000_000.0
    @in patient_panel_size::Int = 5000
    @in quality_score::Float64 = 0.65
    @in risk_track::String = "one_sided"
    @in shared_savings_rate::Float64 = 0.50
    @in shared_loss_rate::Float64 = 0.30
    @in min_savings_rate::Float64 = 0.02
    @in care_management_investment::Float64 = 500_000.0
    @in recalculate::Bool = false

    @out model_type_options::Vector{Dict{String,Any}} = [
        Dict("label" => "MSSP Basic", "value" => "mssp_basic"),
        Dict("label" => "MSSP Enhanced", "value" => "mssp_enhanced"),
        Dict("label" => "ACO REACH Lead", "value" => "aco_lead"),
        Dict("label" => "ACO REACH Flex", "value" => "aco_flex"),
    ]
    @out risk_track_options::Vector{Dict{String,Any}} = [
        Dict("label" => "One-Sided (Savings Only)", "value" => "one_sided"),
        Dict("label" => "Two-Sided (Savings & Losses)", "value" => "two_sided"),
    ]

    # ── Outputs ─────────────────────────────────────────────────────────
    @out gross_savings::Float64 = 5_000_000.0
    @out savings_rate::Float64 = 0.083
    @out shared_savings_payment::Float64 = 1_625_000.0
    @out shared_loss_payment::Float64 = 0.0
    @out net_financial_impact::Float64 = 1_125_000.0
    @out per_beneficiary_savings::Float64 = 1_000.0
    @out meets_minimum_savings::Bool = true

    @out timeline_data::Vector{PlotData} = [
        PlotData(x=["Year 1","Year 2","Year 3","Year 4","Year 5"],
                 y=[200_000, 600_000, 1_000_000, 1_100_000, 1_200_000],
                 plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                 name="Net Financial Impact", mode="lines+markers",
                 line=PlotDataLine(color="#4CAF50"))
    ]
    @out timeline_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="VBC Transition 5-Year Projection"),
        yaxis=[PlotLayoutAxis(title="Net Impact (\$)")],
    )

    @onchange recalculate begin
        if recalculate
            recalculate = false
            gross_savings = benchmark - total_cost_of_care
            savings_rate = benchmark > 0 ? gross_savings / benchmark : 0.0
            per_beneficiary_savings = patient_panel_size > 0 ? gross_savings / patient_panel_size : 0.0
            meets_minimum_savings = savings_rate >= min_savings_rate

            ss = 0.0
            if gross_savings > 0 && meets_minimum_savings
                ss = gross_savings * shared_savings_rate * clamp(quality_score, 0.0, 1.0)
            end
            shared_savings_payment = ss

            sl = 0.0
            if risk_track == "two_sided" && gross_savings < 0
                cap = model_type in ("mssp_enhanced", "aco_lead") ? 0.15 : 0.08
                sl = min(abs(gross_savings) * shared_loss_rate, benchmark * cap)
            end
            shared_loss_payment = sl

            net_financial_impact = ss - sl - care_management_investment

            # 5-year projection
            maturity = [0.30, 0.60, 0.90, 0.95, 1.0]
            years = String[]
            impacts = Float64[]
            for yr in 1:5
                mat = maturity[yr]
                pot = benchmark - total_cost_of_care
                yr_savings = pot > 0 ? pot * mat * shared_savings_rate * min(1.0, quality_score + 0.05*(yr-1)) : 0.0
                yr_cm = care_management_investment * (yr <= 2 ? [0.6, 0.85][yr] : 1.0)
                push!(years, "Year $yr")
                push!(impacts, round(yr_savings - yr_cm, digits=0))
            end
            timeline_data = [PlotData(x=years, y=impacts,
                plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER, name="Net Financial Impact",
                mode="lines+markers", line=PlotDataLine(color="#4CAF50"))]
            @info "VBC: savings rate $(round(savings_rate*100, digits=1))%, net \$$(round(Int, net_financial_impact))"
        end
    end
end

const vbc_transition_model = @init
