"""
Stipple reactive model for Disaster / Climate Resilience Assessment.
Vulnerability scoring, financial exposure estimation, and stress testing.
"""
using Stipple, StippleUI, StipplePlotly


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
            hm(l) = l=="very_high" ? 1.0 : l=="high" ? 0.75 : l=="moderate" ? 0.50 : 0.15

            flood_v = hm(flood_zone)
            wild_v = hm(wildfire_risk)
            hurr_v = hurricane_zone ? 0.7 : 0.1
            eq_v = earthquake_zone ? 0.6 : 0.1
            hazard = 0.30*flood_v + 0.25*wild_v + 0.25*hurr_v + 0.20*eq_v

            gen_f = clamp(1.0 - days_generator_fuel/7.0, 0.0, 1.0)
            sup_f = 1.0 - supply_chain_redundancy
            heli_f = has_helipad ? 0.0 : 0.15
            prep_gap = 0.40*gen_f + 0.35*sup_f + 0.25*heli_f

            infra_vuln = clamp(0.55*hazard + 0.30*prep_gap + 0.15*fema_risk_score, 0.0, 1.0)
            resilience_score = round((1.0 - infra_vuln) * 100.0, digits=1)

            daily_rev = annual_revenue / 365.0
            daily_exp = annual_expenses / 365.0
            interruption_days = round(7.0 + infra_vuln * 45.0, digits=1)
            financial_exposure = round(daily_rev * interruption_days, digits=0)
            surge = surge_bed_capacity > 0 ? daily_exp*0.30*min(interruption_days,30) : daily_exp*0.15*min(interruption_days,30)
            total_loss = financial_exposure + surge
            insurance_gap = round(total_loss * (1.0 - insurance_coverage_pct), digits=0)

            recs = String[]
            days_generator_fuel < 5 && push!(recs, "Increase generator fuel to 5+ days (currently $(days_generator_fuel))")
            !has_helipad && push!(recs, "Consider helipad for emergency transport")
            supply_chain_redundancy < 0.6 && push!(recs, "Establish redundant supply chain agreements")
            insurance_coverage_pct < 0.90 && push!(recs, "Review insurance coverage ($(round(Int, insurance_coverage_pct*100))%)")
            surge_bed_capacity < 10 && push!(recs, "Develop surge capacity plan (10+ beds)")
            recommendations = recs

            # Stress test scenarios
            scenarios = [(:flood,0.40,0.25,14.0), (:tornado,0.60,0.35,21.0),
                         (:pandemic,0.30,0.50,90.0), (:ice_storm,0.35,0.15,7.0)]
            s_names = String[]
            s_impacts = Float64[]
            for (nm, rlp, csp, bd) in scenarios
                hmod = 0.5 + 0.5*fema_risk_score
                intr = bd * hmod
                rl = daily_rev * intr * rlp
                ec = daily_exp * intr * csp
                net = (rl + ec) * (1.0 - insurance_coverage_pct)
                push!(s_names, String(nm))
                push!(s_impacts, round(net, digits=0))
            end
            stress_data = [PlotData(x=s_names, y=s_impacts,
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="Net Financial Impact",
                marker=Dict("color" => "#F44336"))]

            vuln_data = [PlotData(
                r=[flood_v, wild_v, hurr_v, eq_v, gen_f, sup_f],
                theta=["Flood", "Wildfire", "Hurricane", "Earthquake", "Generator Gap", "Supply Chain"],
                plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR, fill="toself", name="Vulnerability",
                fillcolor="rgba(244,67,54,0.2)", line=PlotDataLine(color="#F44336"))]
            @info "Disaster resilience: score $(resilience_score), exposure \$$(round(Int, financial_exposure))"
        end
    end
end

const disaster_resilience_model = @init
