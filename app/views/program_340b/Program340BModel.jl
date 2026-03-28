"""
Stipple reactive model for 340B Drug Pricing Impact analysis.
Models drug savings, contract pharmacy economics, and policy risk scenarios.
"""
using Stipple, StippleUI, StipplePlotly

@appname Program340BApp

@app begin
    # ── Inputs ──────────────────────────────────────────────────────────
    @in drug_spend::Float64 = 2_800_000.0
    @in discount_rate::Float64 = 0.35
    @in contract_pharmacy_pct::Float64 = 0.40
    @in admin_cost::Float64 = 120_000.0
    @in eligible_patient_pct::Float64 = 0.65
    @in manufacturer_restrictions::Bool = false
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out gross_savings::Float64 = 637_000.0
    @out net_benefit::Float64 = 517_000.0
    @out margin_impact_pct::Float64 = 2.8
    @out contract_pharmacy_savings::Float64 = 254_800.0
    @out in_house_savings::Float64 = 382_200.0
    @out savings_per_prescription::Float64 = 42.50

    @out policy_risk_scenarios::Vector{Dict{String,Any}} = [
        Dict("scenario" => "Status Quo", "net_benefit" => 517_000, "probability" => "60%",
             "description" => "Current 340B rules maintained"),
        Dict("scenario" => "Contract Pharmacy Restrictions", "net_benefit" => 310_200, "probability" => "25%",
             "description" => "Manufacturers limit contract pharmacy access"),
        Dict("scenario" => "Full Program Reform", "net_benefit" => 180_000, "probability" => "10%",
             "description" => "Congressional reform narrows eligibility"),
        Dict("scenario" => "Program Expansion", "net_benefit" => 680_000, "probability" => "5%",
             "description" => "Rural exemptions broaden program"),
    ]

    # ── Chart Data ──────────────────────────────────────────────────────
    @out impact_chart_data::Vector{PlotData} = [
        PlotData(
            x = ["Gross Savings", "Admin Cost", "Net Benefit"],
            y = [637, -120, 517],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "340B Impact (\$K)",
            marker = Dict("color" => ["green", "red", "blue"]),
        )
    ]
    @out impact_chart_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "340B Program Financial Impact (\$K)"),
        xaxis = [PlotLayoutAxis(title = "")],
        yaxis = [PlotLayoutAxis(title = "\$K")],
    )

    @out scenario_chart_data::Vector{PlotData} = [
        PlotData(
            x = ["Status Quo", "Contract Pharmacy Restrictions", "Full Reform", "Expansion"],
            y = [517, 310, 180, 680],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Net Benefit by Scenario (\$K)",
        )
    ]
    @out scenario_chart_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Policy Risk Scenario Comparison (\$K)"),
        xaxis = [PlotLayoutAxis(title = "Scenario")],
        yaxis = [PlotLayoutAxis(title = "Net Benefit (\$K)")],
    )

    # ── Handlers ────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false
            eligible_spend = drug_spend * eligible_patient_pct
            gross_savings = round(eligible_spend * discount_rate, digits=0)
            contract_pharmacy_savings = round(gross_savings * contract_pharmacy_pct, digits=0)
            in_house_savings = gross_savings - contract_pharmacy_savings
            net_benefit = gross_savings - admin_cost
            margin_impact_pct = round(net_benefit / 18_500_000 * 100, digits=1)

            if manufacturer_restrictions
                contract_pharmacy_savings = round(contract_pharmacy_savings * 0.5, digits=0)
                net_benefit = in_house_savings + contract_pharmacy_savings - admin_cost
            end

            impact_chart_data = [PlotData(
                x = ["Gross Savings", "Admin Cost", "Net Benefit"],
                y = round.([gross_savings, -admin_cost, net_benefit] ./ 1000, digits=0),
                plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
                name = "340B Impact (\$K)",
                marker = Dict("color" => ["green", "red", "blue"]),
            )]
            @info "340B recalculated: net benefit \$$(round(Int, net_benefit/1000))K"
        end
    end
end

const program_340b_model = @init
