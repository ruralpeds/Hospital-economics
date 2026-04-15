"""
Stipple reactive model for Medicaid DSH/UPL/SDP Supplemental Payment Calculator.
Models DSH, UPL, and State Directed Payment programs for rural hospitals.
Delegates to RuralHospitalSim.calculate_medicaid_supplemental() for computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: calculate_medicaid_supplemental, medicaid_reform_scenarios,
    MedicaidSupplementalParams, MedicaidSupplementalResult


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

            # Call domain engine
            params = MedicaidSupplementalParams(;
                medicaid_costs=medicaid_costs,
                medicaid_payments=medicaid_payments,
                uncompensated_care_costs=uncompensated_care_costs,
                gross_patient_revenue=gross_patient_revenue,
                total_operating_expenses=total_operating_expenses,
                provider_class=provider_class,
                state_has_expansion=state_has_expansion,
                provider_tax_rate=provider_tax_rate,
            )
            result = calculate_medicaid_supplemental(params)

            # Map domain results
            dsh_payment = result.dsh_payment
            upl_payment = result.upl_payment
            sdp_payment = result.sdp_payment
            total_supplemental = result.total_supplemental
            net_medicaid_shortfall = result.net_medicaid_shortfall
            provider_tax_cost = result.provider_tax_cost

            payment_chart_data = [PlotData(labels=["DSH", "UPL", "SDP"],
                values=[dsh_payment, upl_payment, sdp_payment],
                plot=StipplePlotly.Charts.PLOT_TYPE_PIE, hole=0.4, name="Payments")]

            # Reform scenarios from domain
            reforms = medicaid_reform_scenarios(params)
            reform_names = [r.scenario_name for r in reforms]
            reform_totals = [r.total_supplemental for r in reforms]
            reform_chart_data = [PlotData(
                x=reform_names, y=reform_totals,
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Total Supplemental",
                marker=Dict("color" => "#2196F3"))]
            @info "Medicaid supplemental (domain): total \$$(round(Int, total_supplemental))"
        end
    end
end

const medicaid_supplemental_model = @init
