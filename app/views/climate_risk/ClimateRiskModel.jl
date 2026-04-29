"""Climate Risk / TCFD Model (D-07)."""
using Stipple, StippleUI, StipplePlotly
using ...FinanceEngine: PhysicalRiskInputs, assess_physical_risk,
                        TransitionRiskInputs, assess_transition_risk, tcfd_scenario_analysis

@app begin
    @in flood_score::Float64     = 3.0
    @in wildfire_score::Float64  = 1.0
    @in heat_score::Float64      = 5.0
    @in weather_score::Float64   = 6.0
    @in replacement_value::Float64 = 18_000_000.0
    @in annual_revenue::Float64  = 8_500_000.0
    @in generator_hours::Int     = 48
    @in scope1::Float64          = 280.0
    @in scope2::Float64          = 420.0
    @in energy_spend::Float64    = 380_000.0
    @in supply_spend::Float64    = 1_200_000.0
    @in insurance_spend::Float64 = 95_000.0
    @in run_analysis::Bool       = false

    @out composite_risk::Float64      = 0.0
    @out risk_tier::String            = "—"
    @out expected_annual_loss::Float64 = 0.0
    @out priority_investments::Vector{String} = []
    @out total_emissions::Float64     = 700.0
    @out carbon_cost_2030::Float64    = 0.0
    @out ev_risk::Float64             = 0.0
    @out worst_scenario::String       = "—"

    @out scenario_chart::Vector{PlotData} = []
    @out scenario_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="TCFD Annual Risk by Scenario"),
        barmode="stack", yaxis=[PlotLayoutAxis(title="Annual Risk")])

    @in errors::Vector{String} = String[]

    @onchange run_analysis begin
        if run_analysis
            run_analysis = false
            errors = String[]
            try
                phys = assess_physical_risk(PhysicalRiskInputs(
                    hospital_name="Hospital", state="XX", county="XX",
                    flood_hazard_score=flood_score, wildfire_hazard_score=wildfire_score,
                    extreme_heat_score=heat_score, severe_weather_score=weather_score,
                    replacement_value_usd=replacement_value, annual_revenue=annual_revenue,
                    generator_backup_hours=generator_hours))
                trans = assess_transition_risk(TransitionRiskInputs(
                    hospital_name="Hospital",
                    scope1_emissions_mtco2e=scope1, scope2_emissions_mtco2e=scope2,
                    annual_energy_spend=energy_spend, annual_supply_chain_spend=supply_spend,
                    property_insurance_annual=insurance_spend))
                result = tcfd_scenario_analysis(phys, trans)
                composite_risk      = round(phys.composite_physical_risk_score, digits=1)
                risk_tier           = uppercase(string(phys.risk_tier))
                expected_annual_loss = phys.expected_annual_loss_usd
                priority_investments = phys.priority_investments
                total_emissions     = trans.total_emissions_mtco2e
                carbon_cost_2030    = trans.carbon_cost_2030
                ev_risk             = result.expected_value_risk
                worst_scenario      = result.worst_case_scenario
                scen_names = [s.scenario for s in result.scenarios]
                scenario_chart = [
                    PlotData(x=scen_names, y=[s.physical_risk for s in result.scenarios],
                        plot="bar", name="Physical Risk", marker=Dict("color"=>"#ef4444")),
                    PlotData(x=scen_names, y=[s.transition_risk for s in result.scenarios],
                        plot="bar", name="Transition Risk", marker=Dict("color"=>"#f59e0b")),
                ]
            catch e; errors = ["$(sprint(showerror,e))"]; end
        end
    end
end
const climate_risk_model = @init
