"""
Stipple reactive model for Closure Risk Assessment.
Computes multi-factor risk scores using the RuralHospitalSim closure risk engine.
"""
using Stipple, StippleUI, StipplePlotly
using Dates

# Import domain layer functions
using ...RuralHospitalSim: assess_closure_risk, estimate_distress_timeline, MarketData,
    GeoLocation, ServiceArea, CriticalAccessHospital, AnnualFinancials, ClosureRiskAssessment


@app begin
    @in left_drawer_open::Bool = true
    # ── Selection ────────────────────────────────────────────────────────
    @in selected_hospital_id::Int = 1
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    @out is_loading::Bool = false

    @out hospital_options::Vector{Dict{String,Any}} = [
        Dict("label"=>"Prairie View Community Hospital", "value"=>1),
        Dict("label"=>"Mountain Valley Medical Center", "value"=>2),
        Dict("label"=>"Delta Regional Hospital", "value"=>3),
        Dict("label"=>"High Plains Health", "value"=>4),
    ]
    @in run_assessment::Bool = false

    # ── Input Overrides (user-adjustable financial indicators) ───────────
    @in input_operating_margin::Float64 = -0.038
    @in input_days_cash::Float64 = 42.0
    @in input_current_ratio::Float64 = 1.35
    @in input_debt_to_cap::Float64 = 0.48
    @in input_debt_service_coverage::Float64 = 1.1
    @in input_occupancy_rate::Float64 = 0.33
    @in input_avg_age_plant::Float64 = 14.2
    @in input_vacancy_rate::Float64 = 0.12
    @in input_travel_fte_ratio::Float64 = 0.08
    @in input_pop_growth::Float64 = -0.003
    @in input_nearest_competitor::Float64 = 35.0
    @in input_medicaid_expansion::Bool = true

    # ── Overall Risk ─────────────────────────────────────────────────────
    @out overall_risk_score::Int = 72
    @out risk_level::String = "high"
    @out financial_distress_index::Float64 = 0.78
    @out closure_probability_1yr::Float64 = 0.08
    @out closure_probability_3yr::Float64 = 0.18
    @out closure_probability_5yr::Float64 = 0.31
    @out years_to_distress::Float64 = 3.5
    @out peer_avg_risk_score::Int = 45

    # ── Risk Factor Breakdown ────────────────────────────────────────────
    @out financial_risk_score::Float64 = 0.72
    @out operational_risk_score::Float64 = 0.55
    @out market_risk_score::Float64 = 0.48
    @out workforce_risk_score::Float64 = 0.65
    @out policy_risk_score::Float64 = 0.40

    @out risk_factors::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out risk_drivers::Vector{String} = String[]

    # ── Radar Chart for Factor Scores ────────────────────────────────────
    @out radar_data::Vector{PlotData} = [
        PlotData(
            r=[72, 55, 48, 65, 40],
            theta=["Financial", "Operational", "Market", "Workforce", "Policy"],
            plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR,
            fill="toself", name="Your Hospital",
            fillcolor="rgba(255,0,0,0.15)", line=PlotDataLine(color="red")),
        PlotData(
            r=[40, 42, 38, 45, 35],
            theta=["Financial", "Operational", "Market", "Workforce", "Policy"],
            plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR,
            fill="toself", name="Peer Average",
            fillcolor="rgba(0,0,255,0.10)", line=PlotDataLine(color="blue", dash="dot")),
    ]
    @out radar_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Risk Factor Comparison"),
        polar=Dict("radialaxis"=>Dict("visible"=>true, "range"=>[0, 100])),
    )

    # ── Mitigation Recommendations ───────────────────────────────────────
    @out recommendations::Vector{Dict{String,Any}} = Dict{String,Any}[]

    # ── Handlers ─────────────────────────────────────────────────────────
    @onchange selected_hospital_id begin
        @info "Loading closure risk for hospital $selected_hospital_id"
        # Load preset data for demo hospitals
        if selected_hospital_id == 1
            input_operating_margin = -0.038; input_days_cash = 42.0
            input_current_ratio = 1.35; input_debt_to_cap = 0.48
            input_occupancy_rate = 0.33; input_avg_age_plant = 14.2
            input_vacancy_rate = 0.12; input_travel_fte_ratio = 0.08
            input_pop_growth = -0.003; input_nearest_competitor = 35.0
            input_medicaid_expansion = true
        elseif selected_hospital_id == 2
            input_operating_margin = -0.015; input_days_cash = 67.0
            input_current_ratio = 1.65; input_debt_to_cap = 0.35
            input_occupancy_rate = 0.28; input_avg_age_plant = 11.0
            input_vacancy_rate = 0.10; input_travel_fte_ratio = 0.04
            input_pop_growth = 0.001; input_nearest_competitor = 42.0
            input_medicaid_expansion = true
        elseif selected_hospital_id == 3
            input_operating_margin = -0.072; input_days_cash = 28.0
            input_current_ratio = 1.10; input_debt_to_cap = 0.62
            input_occupancy_rate = 0.18; input_avg_age_plant = 18.5
            input_vacancy_rate = 0.20; input_travel_fte_ratio = 0.15
            input_pop_growth = -0.012; input_nearest_competitor = 28.0
            input_medicaid_expansion = false
        else
            input_operating_margin = 0.012; input_days_cash = 85.0
            input_current_ratio = 2.10; input_debt_to_cap = 0.22
            input_occupancy_rate = 0.38; input_avg_age_plant = 9.0
            input_vacancy_rate = 0.06; input_travel_fte_ratio = 0.02
            input_pop_growth = 0.005; input_nearest_competitor = 50.0
            input_medicaid_expansion = true
        end
    end

    @onchange run_assessment begin
        if run_assessment
            run_assessment = false
            is_loading = true
            try
            @info "Running closure risk assessment via domain engine..."

            # Build MarketData from inputs
            market = MarketData(
                input_medicaid_expansion,
                0.35,  # MA penetration (default)
                input_pop_growth * 5,  # 5-year trend
                input_nearest_competitor,
                0.15,  # poverty rate (default)
                0.10,  # uninsured rate (default)
            )

            # Build minimal hospital
            location = GeoLocation(;
                latitude=35.0, longitude=-90.0, fips_code="00000",
                state="XX", county="Unknown", zip_code="00000",
            )
            service_area = ServiceArea(;
                primary_service_area_pop=15000, total_service_area_pop=25000,
            )
            hospital = CriticalAccessHospital(;
                name="Assessment Hospital",
                cms_provider_number="000000", npi="0000000000",
                cah_certification_date=Date(2010, 1, 1),
                licensed_beds=25,
                average_daily_census=25.0 * input_occupancy_rate,
                location=location, service_area=service_area,
                nearest_hospital_miles=input_nearest_competitor,
            )

            # Build financial and operational data dicts for the engine
            financial_data = Dict{String,Float64}(
                "operating_margin"      => input_operating_margin,
                "total_margin"          => input_operating_margin + 0.01,
                "days_cash_on_hand"     => input_days_cash,
                "current_ratio"         => input_current_ratio,
                "debt_to_cap"           => input_debt_to_cap,
                "debt_service_coverage" => input_debt_service_coverage,
            )
            operational_data = Dict{String,Float64}(
                "occupancy_rate"    => input_occupancy_rate,
                "avg_age_of_plant"  => input_avg_age_plant,
                "fte_per_aob"       => 5.5,
                "travel_fte_ratio"  => input_travel_fte_ratio,
                "physician_vacancy" => input_vacancy_rate,
            )

            # Call domain engine
            assessment = assess_closure_risk(hospital, market;
                financial_data=financial_data, operational_data=operational_data)

            # Map results to reactive outputs
            composite = assessment.composite_risk_score
            overall_risk_score = round(Int, composite * 100)
            risk_level = string(assessment.risk_category)
            financial_risk_score = assessment.financial_risk_score
            operational_risk_score = assessment.operational_risk_score
            market_risk_score = assessment.market_risk_score
            workforce_risk_score = assessment.workforce_risk_score
            policy_risk_score = assessment.policy_risk_score
            financial_distress_index = composite
            closure_probability_1yr = round(assessment.closure_probability_1yr, digits=3)
            closure_probability_3yr = round(assessment.closure_probability_3yr, digits=3)
            closure_probability_5yr = round(assessment.closure_probability_5yr, digits=3)
            years_to_distress = round(estimate_distress_timeline(composite, financial_risk_score), digits=1)
            risk_drivers = assessment.risk_drivers

            # Build risk factor table
            risk_factors = [
                Dict{String,Any}("name"=>"Financial", "score"=>round(Int, financial_risk_score*100),
                     "weight"=>0.35, "weighted_score"=>round(financial_risk_score*35, digits=1),
                     "severity"=>financial_risk_score > 0.7 ? "critical" : financial_risk_score > 0.5 ? "high" : "moderate"),
                Dict{String,Any}("name"=>"Operational", "score"=>round(Int, operational_risk_score*100),
                     "weight"=>0.25, "weighted_score"=>round(operational_risk_score*25, digits=1),
                     "severity"=>operational_risk_score > 0.7 ? "critical" : operational_risk_score > 0.5 ? "high" : "moderate"),
                Dict{String,Any}("name"=>"Market", "score"=>round(Int, market_risk_score*100),
                     "weight"=>0.20, "weighted_score"=>round(market_risk_score*20, digits=1),
                     "severity"=>market_risk_score > 0.7 ? "critical" : market_risk_score > 0.5 ? "high" : "moderate"),
                Dict{String,Any}("name"=>"Workforce", "score"=>round(Int, workforce_risk_score*100),
                     "weight"=>0.10, "weighted_score"=>round(workforce_risk_score*10, digits=1),
                     "severity"=>workforce_risk_score > 0.7 ? "critical" : workforce_risk_score > 0.5 ? "high" : "moderate"),
                Dict{String,Any}("name"=>"Policy", "score"=>round(Int, policy_risk_score*100),
                     "weight"=>0.10, "weighted_score"=>round(policy_risk_score*10, digits=1),
                     "severity"=>policy_risk_score > 0.7 ? "critical" : policy_risk_score > 0.5 ? "high" : "moderate"),
            ]

            # Update radar chart
            scores_100 = round.(Int, [financial_risk_score, operational_risk_score,
                                       market_risk_score, workforce_risk_score, policy_risk_score] .* 100)
            dims = ["Financial", "Operational", "Market", "Workforce", "Policy"]
            radar_data = [
                PlotData(r=scores_100, theta=dims, plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR,
                    fill="toself", name="Your Hospital",
                    fillcolor="rgba(255,0,0,0.15)", line=PlotDataLine(color="red")),
                PlotData(r=[40, 42, 38, 45, 35], theta=dims,
                    plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR,
                    fill="toself", name="Peer Average",
                    fillcolor="rgba(0,0,255,0.10)", line=PlotDataLine(color="blue", dash="dot")),
            ]

            # Generate recommendations based on risk scores
            recs = Dict{String,Any}[]
            if financial_risk_score > 0.6
                push!(recs, Dict{String,Any}("priority"=>"high", "action"=>"Evaluate REH conversion",
                    "impact"=>"Could improve margin by 5-7 percentage points", "category"=>"Strategic"))
            end
            if workforce_risk_score > 0.5
                push!(recs, Dict{String,Any}("priority"=>"high", "action"=>"Reduce travel nurse dependency",
                    "impact"=>"Potential \$500K-\$800K annual savings", "category"=>"Financial"))
            end
            if operational_risk_score > 0.5
                push!(recs, Dict{String,Any}("priority"=>"medium", "action"=>"Expand outpatient services",
                    "impact"=>"Increase outpatient revenue 10-15%", "category"=>"Revenue"))
            end
            if market_risk_score > 0.4
                push!(recs, Dict{String,Any}("priority"=>"medium", "action"=>"Implement telehealth program",
                    "impact"=>"Retain patients, add specialty access", "category"=>"Revenue"))
            end
            if financial_risk_score > 0.4
                push!(recs, Dict{String,Any}("priority"=>"medium", "action"=>"Build cash reserves — target 60+ days",
                    "impact"=>"Improve financial stability", "category"=>"Financial"))
            end
            recommendations = recs

            @info "Closure risk: score=$(overall_risk_score), tier=$(risk_level), P(3yr)=$(closure_probability_3yr)"
            catch e
                push!(errors, string(e))
            finally
                is_loading = false
            end
        end
    end
end

const closure_risk_model = @init
