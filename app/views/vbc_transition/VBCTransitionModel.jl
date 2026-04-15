"""
Stipple reactive model for Value-Based Care Transition.
Models shared savings/loss calculations for Medicare ACO programs.
Delegates to RuralHospitalSim.calculate_vbc_outcome() for computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: calculate_vbc_outcome, vbc_transition_timeline,
    VBCParams, VBCResult


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

            # Call domain engine
            params = VBCParams(;
                model_type=model_type,
                total_cost_of_care=total_cost_of_care,
                benchmark=benchmark,
                patient_panel_size=patient_panel_size,
                quality_score=quality_score,
                risk_track=risk_track,
                shared_savings_rate=shared_savings_rate,
                shared_loss_rate=shared_loss_rate,
                min_savings_rate=min_savings_rate,
                care_management_investment=care_management_investment,
            )
            result = calculate_vbc_outcome(params)

            # Map domain results
            gross_savings = result.gross_savings
            savings_rate = result.savings_rate
            per_beneficiary_savings = result.per_beneficiary_savings
            meets_minimum_savings = result.meets_minimum_savings
            shared_savings_payment = result.shared_savings_payment
            shared_loss_payment = result.shared_loss_payment
            net_financial_impact = result.net_financial_impact

            # 5-year timeline from domain
            timeline = vbc_transition_timeline(params)
            years = ["Year $yr" for yr in 1:5]
            impacts = [round(t.net_impact, digits=0) for t in timeline]

            timeline_data = [PlotData(x=years, y=impacts,
                plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER, name="Net Financial Impact",
                mode="lines+markers", line=PlotDataLine(color="#4CAF50"))]
            @info "VBC (domain): savings rate $(round(savings_rate*100, digits=1))%, net \$$(round(Int, net_financial_impact))"
        end
    end
end

const vbc_transition_model = @init
