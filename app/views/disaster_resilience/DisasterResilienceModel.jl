"""
Stipple reactive model for Disaster / Climate Resilience Assessment.
Vulnerability scoring, financial exposure estimation, and stress testing.
Delegates to RuralHospitalSim.assess_disaster_resilience() for computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: assess_disaster_resilience, disaster_stress_test,
    DisasterProfile, DisasterImpactResult


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in fema_risk_score::Float64 = 0.55
    @in flood_zone::String = "moderate"
    @in wildfire_risk::String = "low"
    @in hurricane_zone::Bool = false
    @in earthquake_zone::Bool = false
    @in days_generator_fuel::Float64 = 3.0
    @in has_helipad::Bool = false
    @in surge_bed_capacity::Int = 5
    @in supply_chain_redundancy::Float64 = 0.50
    @in insurance_coverage_pct::Float64 = 0.80
    @in annual_revenue::Float64 = 18_000_000.0
    @in annual_expenses::Float64 = 17_500_000.0
    @in cash_reserves::Float64 = 2_500_000.0
    @in recalculate::Bool = false

    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    @out flood_options::Vector{Dict{String,Any}} = [
        Dict("label"=>"Minimal","value"=>"minimal"), Dict("label"=>"Moderate","value"=>"moderate"),
        Dict("label"=>"High","value"=>"high"), Dict("label"=>"Very High","value"=>"very_high"),
    ]
    @out wildfire_options::Vector{Dict{String,Any}} = [
        Dict("label"=>"Low","value"=>"low"), Dict("label"=>"Moderate","value"=>"moderate"),
        Dict("label"=>"High","value"=>"high"), Dict("label"=>"Very High","value"=>"very_high"),
    ]

    # ── Outputs ─────────────────────────────────────────────────────────
    @out resilience_score::Float64 = 62.0
    @out financial_exposure::Float64 = 1_200_000.0
    @out interruption_days::Float64 = 18.0
    @out insurance_gap::Float64 = 300_000.0
    @out recommendations::Vector{String} = ["Increase generator fuel reserves"]

    @out stress_data::Vector{PlotData} = [
        PlotData(x=["Flood", "Tornado", "Pandemic", "Ice Storm"],
                 y=[450_000, 800_000, 1_200_000, 200_000],
                 plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                 name="Net Financial Impact", marker=Dict("color" => "#F44336"))
    ]
    @out stress_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Disaster Stress Test — Net Impact"),
        yaxis=[PlotLayoutAxis(title="Net Impact After Insurance (\$)")],
    )

    @out vuln_data::Vector{PlotData} = [
        PlotData(r=[0.5, 0.15, 0.1, 0.1, 0.4, 0.5],
                 theta=["Flood", "Wildfire", "Hurricane", "Earthquake", "Generator Gap", "Supply Chain"],
                 plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR,
                 fill="toself", name="Vulnerability",
                 fillcolor="rgba(244,67,54,0.2)", line=PlotDataLine(color="#F44336"))
    ]
    @out vuln_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Infrastructure Vulnerability Profile"),
        polar=Dict("radialaxis" => Dict("visible" => true, "range" => [0, 1])),
    )

    @onchange recalculate begin
        if recalculate
            recalculate = false

            # Build domain profile and call engine
            profile = DisasterProfile(;
                fema_risk_score=fema_risk_score,
                flood_zone=flood_zone,
                wildfire_risk=wildfire_risk,
                hurricane_zone=hurricane_zone,
                earthquake_zone=earthquake_zone,
                days_generator_fuel=days_generator_fuel,
                has_helipad=has_helipad,
                surge_bed_capacity=surge_bed_capacity,
                supply_chain_redundancy=supply_chain_redundancy,
                insurance_coverage_pct=insurance_coverage_pct,
                annual_revenue=annual_revenue,
                annual_expenses=annual_expenses,
                cash_reserves=cash_reserves,
            )
            result = assess_disaster_resilience(profile)

            # Map domain results
            resilience_score = result.resilience_score
            financial_exposure = result.financial_exposure
            interruption_days = result.interruption_days
            insurance_gap = result.insurance_gap
            recommendations = result.recommendations

            # Stress test from domain
            stress_results = disaster_stress_test(profile)
            s_names = [s.scenario_name for s in stress_results]
            s_impacts = [round(s.net_financial_impact, digits=0) for s in stress_results]

            stress_data = [PlotData(x=s_names, y=s_impacts,
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Net Financial Impact",
                marker=Dict("color" => "#F44336"))]

            # Vulnerability radar from domain result
            vuln_scores = result.vulnerability_scores
            vuln_data = [PlotData(
                r=[get(vuln_scores, k, 0.0) for k in ["flood", "wildfire", "hurricane", "earthquake", "generator_gap", "supply_chain"]],
                theta=["Flood", "Wildfire", "Hurricane", "Earthquake", "Generator Gap", "Supply Chain"],
                plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR, fill="toself", name="Vulnerability",
                fillcolor="rgba(244,67,54,0.2)", line=PlotDataLine(color="#F44336"))]
            @info "Disaster resilience (domain): score $(resilience_score), exposure \$$(round(Int, financial_exposure))"
        end
    end
end

const disaster_resilience_model = @init
