"""
Stipple reactive model for Medicaid DSH/UPL/SDP Supplemental Payment Calculator.
Models DSH, UPL, and State Directed Payment programs for rural hospitals.
"""
using Stipple, StippleUI, StipplePlotly


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in medicaid_costs::Float64 = 8_000_000.0
    @in medicaid_payments::Float64 = 5_500_000.0
    @in uncompensated_care_costs::Float64 = 2_000_000.0
    @in gross_patient_revenue::Float64 = 45_000_000.0
    @in total_operating_expenses::Float64 = 40_000_000.0
    @in provider_class::String = "private"
    @in state_has_expansion::Bool = true
    @in provider_tax_rate::Float64 = 0.04
    @in recalculate::Bool = false

    @out provider_class_options::Vector{Dict{String,Any}} = [
        Dict("label" => "State Owned", "value" => "state_owned"),
        Dict("label" => "Non-State Government", "value" => "non_state_govt"),
        Dict("label" => "Private", "value" => "private"),
    ]

    # ── Outputs ─────────────────────────────────────────────────────────
    @out dsh_payment::Float64 = 1_800_000.0
    @out upl_payment::Float64 = 900_000.0
    @out sdp_payment::Float64 = 640_000.0
    @out total_supplemental::Float64 = 3_340_000.0
    @out net_medicaid_shortfall::Float64 = 0.0
    @out provider_tax_cost::Float64 = 1_800_000.0

    @out payment_chart_data::Vector{PlotData} = [
        PlotData(labels=["DSH", "UPL", "SDP"],
                 values=[1_800_000, 900_000, 640_000],
                 plot=StipplePlotly.Charts.PLOT_TYPE_PIE,
                 hole=0.4, name="Supplemental Payments")
    ]
    @out payment_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Supplemental Payment Breakdown"),
    )

    @out reform_chart_data::Vector{PlotData} = [
        PlotData(x=["Current Law", "Moderate Reform", "Significant Reform"],
                 y=[3_340_000, 2_500_000, 1_200_000],
                 plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                 name="Total Supplemental", marker=Dict("color" => "#2196F3"))
    ]
    @out reform_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Reform Scenario Impact"),
        yaxis=[PlotLayoutAxis(title="Total Supplemental (\$)")],
    )

    @onchange recalculate begin
        if recalculate
            recalculate = false
            # DSH
            dsh_limit = max(0.0, (medicaid_costs + uncompensated_care_costs) - medicaid_payments)
            dsh_pct = provider_class == "state_owned" ? 0.70 :
                      provider_class == "non_state_govt" ? 0.55 : 0.40
            dsh_payment = dsh_limit * dsh_pct

            # UPL
            medicare_eq = medicaid_costs / 0.92
            upl_room = max(0.0, medicare_eq - (medicaid_payments + dsh_payment))
            upl_capture = provider_class == "state_owned" ? 0.80 : 0.60
            upl_payment = upl_room * upl_capture

            # SDP
            sdp_rate = state_has_expansion ?
                (provider_class == "private" ? 0.08 : 0.05) :
                (provider_class == "private" ? 0.04 : 0.03)
            sdp_payment = medicaid_costs * sdp_rate

            total_supplemental = dsh_payment + upl_payment + sdp_payment
            net_medicaid_shortfall = max(0.0, medicaid_costs - (medicaid_payments + total_supplemental))
            provider_tax_cost = gross_patient_revenue * provider_tax_rate

            payment_chart_data = [PlotData(labels=["DSH", "UPL", "SDP"],
                values=[dsh_payment, upl_payment, sdp_payment],
                plot=StipplePlotly.Charts.PLOT_TYPE_PIE, hole=0.4, name="Payments")]

            # Reform scenarios
            mod_total = dsh_payment + upl_payment + sdp_payment * 0.5
            sig_total = dsh_payment * 0.8 + upl_payment * 0.7
            reform_chart_data = [PlotData(
                x=["Current Law", "Moderate Reform", "Significant Reform"],
                y=[total_supplemental, mod_total, sig_total],
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Total Supplemental",
                marker=Dict("color" => "#2196F3"))]
            @info "Medicaid supplemental: total \$$(round(Int, total_supplemental))"
        end
    end
end

const medicaid_supplemental_model = @init
