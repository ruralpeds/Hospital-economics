"""
Stipple reactive model for Risk Stratification Dashboard.
Integrates Phase 4A AdvancedAnalytics for patient risk analysis.
"""
using Stipple, StippleUI, StipplePlotly
using Dates

# Import domain layer
using ...HospitalFinanceToolbox: stratify_patient_risk, RiskStratificationResult,
    AdvancedAnalytics, PatientCohort


@app begin
    # ── UI State ────────────────────────────────────────────────────────────
    @in left_drawer_open::Bool = true
    @in cohort_filter::String = "all"  # "all", "cardiology", "orthopedics", etc.
    @in risk_threshold::Float64 = 0.33  # Filter patients above this risk level
    @in sort_by::String = "risk"  # "risk", "cost", "readmission"
    @in search_patient_id::String = ""
    @in recalculate::Bool = false

    # ── Data Inputs (from Phase 4A) ────────────────────────────────────────
    @in cohort_data::Vector{Dict} = []  # Patient records with age, cost, comorbidities, etc.
    @in risk_model::Union{Nothing, AdvancedAnalytics.ReadmissionRiskModel} = nothing

    # ── Computed Outputs ────────────────────────────────────────────────────
    @out patient_risks::Vector{Dict} = []  # Filtered and sorted patient list
    @out filtered_count::Int = 0
    @out high_risk_count::Int = 0
    @out medium_risk_count::Int = 0
    @out low_risk_count::Int = 0

    # ── Risk Distribution Chart ─────────────────────────────────────────────
    @out risk_distribution::Vector{PlotData} = [
        PlotData(x=Float64[], y=String[], orientation="h", plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
            name="Patient Count", marker=PlotDataMarker(color="rgba(33,150,243,0.6)"))
    ]
    @out risk_distribution_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Risk Distribution"),
        xaxis = PlotLayoutAxis(title = "Number of Patients"),
        yaxis = PlotLayoutAxis(title = "Risk Category"),
        margin = PlotLayoutMargin(l=100)
    )

    # ── Service Line Breakdown ──────────────────────────────────────────────
    @out service_line_breakdown::Vector{PlotData} = [
        PlotData(x=String[], y=Int[], plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
            name="High Risk", marker=PlotDataMarker(color="rgba(244,67,54,0.6)")),
        PlotData(x=String[], y=Int[], plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
            name="Medium Risk", marker=PlotDataMarker(color="rgba(255,152,0,0.6)")),
        PlotData(x=String[], y=Int[], plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
            name="Low Risk", marker=PlotDataMarker(color="rgba(76,175,80,0.6)"))
    ]
    @out service_line_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Risk by Service Line"),
        barmode = "stack",
        xaxis = PlotLayoutAxis(title = "Service Line"),
        yaxis = PlotLayoutAxis(title = "Patient Count")
    )

    # ── High Risk Patient List ──────────────────────────────────────────────
    @out high_risk_patients::Vector{Dict} = []
    @out high_risk_table_columns::Vector{Dict} = [
        Dict("name" => "patient_id", "label" => "Patient ID", "field" => "patient_id", "align" => "left"),
        Dict("name" => "risk_score", "label" => "Risk Score", "field" => "risk_score", "align" => "center", "format" => "{value:.0%}"),
        Dict("name" => "risk_category", "label" => "Category", "field" => "risk_category", "align" => "center"),
        Dict("name" => "readmission_risk", "label" => "Readmission", "field" => "readmission_risk", "align" => "center", "format" => "{value:.0%}"),
        Dict("name" => "cost_flag", "label" => "Cost Anomaly", "field" => "cost_flag", "align" => "center"),
        Dict("name" => "complication_risk", "label" => "Complication", "field" => "complication_risk", "align" => "center", "format" => "{value:.0%}"),
    ]

    # ── Risk Factors Frequency (Word Cloud Data) ────────────────────────────
    @out risk_factors_frequency::Vector{PlotData} = [
        PlotData(x=String[], y=Int[], plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
            marker=PlotDataMarker(color="rgba(156,39,176,0.6)"), name="Frequency")
    ]
    @out risk_factors_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Top Risk Factors"),
        xaxis = PlotLayoutAxis(title = "Risk Factor"),
        yaxis = PlotLayoutAxis(title = "Frequency"),
        margin = PlotLayoutMargin(b=120)
    )

    # ── Summary Statistics ──────────────────────────────────────────────────
    @out avg_risk_score::Float64 = 0.0
    @out median_risk_score::Float64 = 0.0
    @out readmission_rate::Float64 = 0.0
    @out cost_anomaly_rate::Float64 = 0.0

    # ── Report Export ───────────────────────────────────────────────────────
    @out report_generated::Bool = false
    @out report_content::String = ""

    # ── Handlers ────────────────────────────────────────────────────────────
    @onchange recalculate, cohort_filter, risk_threshold, sort_by begin
        if recalculate || !isempty(cohort_data)
            recalculate = false

            # Filter patients by cohort and risk threshold
            filtered_patients = filter(p -> (cohort_filter == "all" || p["service_line"] == cohort_filter), cohort_data)

            # Compute risk scores if model available
            if !isnothing(risk_model)
                for patient in filtered_patients
                    # Prepare patient data for risk prediction
                    patient_dict = Dict(
                        "age" => get(patient, "age", 65),
                        "comorbidity_count" => get(patient, "comorbidity_count", 2),
                        "los" => get(patient, "los", 4),
                        "age_gt75" => get(patient, "age", 65) > 75 ? 1 : 0
                    )

                    # Predict risks
                    readmission_pred = AdvancedAnalytics.predict_readmission_risk(risk_model, patient_dict)
                    cost_cost = get(patient, "total_cost", 5000.0)

                    # Get readmission risk (first element of prediction)
                    readmission_risk = isa(readmission_pred, Vector) ? readmission_pred[1] : readmission_pred

                    # Detect cost anomalies if detector available
                    cost_anomaly = cost_cost > 10000.0  # Simple threshold for demo
                    complication_risk = get(patient, "complication_risk", 0.1)

                    # Calculate weighted overall risk: 40% readmission + 30% cost + 30% complication
                    overall_risk = 0.4 * readmission_risk + 0.3 * (cost_anomaly ? 0.8 : 0.2) + 0.3 * complication_risk

                    patient["risk_score"] = clamp(overall_risk, 0.0, 1.0)
                    patient["readmission_risk"] = clamp(readmission_risk, 0.0, 1.0)
                    patient["cost_anomaly"] = cost_anomaly
                    patient["cost_flag"] = cost_anomaly ? "Yes" : "No"
                    patient["complication_risk"] = clamp(complication_risk, 0.0, 1.0)
                end
            end

            # Filter by risk threshold
            filtered_by_threshold = filter(p -> p["risk_score"] >= risk_threshold, filtered_patients)

            # Sort patients
            if sort_by == "risk"
                filtered_by_threshold = sort(filtered_by_threshold, by=p -> p["risk_score"], rev=true)
            elseif sort_by == "cost"
                filtered_by_threshold = sort(filtered_by_threshold, by=p -> get(p, "total_cost", 0.0), rev=true)
            elseif sort_by == "readmission"
                filtered_by_threshold = sort(filtered_by_threshold, by=p -> p["readmission_risk"], rev=true)
            end

            # Filter by search term if provided
            if !isempty(search_patient_id)
                filtered_by_threshold = filter(p ->
                    contains(lowercase(p["patient_id"]), lowercase(search_patient_id)),
                    filtered_by_threshold
                )
            end

            # Update patient list
            patient_risks = filtered_by_threshold
            filtered_count = length(filtered_by_threshold)

            # Count risk categories
            high_risk_count = count(p -> p["risk_score"] > 0.67, filtered_by_threshold)
            medium_risk_count = count(p -> 0.33 <= p["risk_score"] <= 0.67, filtered_by_threshold)
            low_risk_count = count(p -> p["risk_score"] < 0.33, filtered_by_threshold)

            # Calculate summary statistics
            if !isempty(filtered_by_threshold)
                risk_scores = [p["risk_score"] for p in filtered_by_threshold]
                avg_risk_score = mean(risk_scores)
                median_risk_score = median(risk_scores)
                readmission_rate = mean([p["readmission_risk"] for p in filtered_by_threshold])
                cost_anomaly_rate = count(p -> p["cost_anomaly"], filtered_by_threshold) / length(filtered_by_threshold)
            else
                avg_risk_score = 0.0
                median_risk_score = 0.0
                readmission_rate = 0.0
                cost_anomaly_rate = 0.0
            end

            # Build risk distribution histogram
            categories = ["Low Risk\n(<0.33)", "Medium Risk\n(0.33-0.67)", "High Risk\n(>0.67)"]
            counts = [low_risk_count, medium_risk_count, high_risk_count]
            risk_distribution = [
                PlotData(x=counts, y=categories, orientation="h", plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                    name="Patient Count", marker=PlotDataMarker(color=["rgba(76,175,80,0.6)", "rgba(255,152,0,0.6)", "rgba(244,67,54,0.6)"]))
            ]

            # Build service line breakdown if data has service_line field
            service_lines = unique([get(p, "service_line", "Unknown") for p in filtered_patients])
            if !isempty(service_lines)
                high_by_sl = [count(p -> get(p, "service_line", "Unknown") == sl && p["risk_score"] > 0.67, filtered_patients) for sl in service_lines]
                med_by_sl = [count(p -> get(p, "service_line", "Unknown") == sl && 0.33 <= p["risk_score"] <= 0.67, filtered_patients) for sl in service_lines]
                low_by_sl = [count(p -> get(p, "service_line", "Unknown") == sl && p["risk_score"] < 0.33, filtered_patients) for sl in service_lines]

                service_line_breakdown = [
                    PlotData(x=service_lines, y=high_by_sl, plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        name="High Risk", marker=PlotDataMarker(color="rgba(244,67,54,0.6)")),
                    PlotData(x=service_lines, y=med_by_sl, plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        name="Medium Risk", marker=PlotDataMarker(color="rgba(255,152,0,0.6)")),
                    PlotData(x=service_lines, y=low_by_sl, plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        name="Low Risk", marker=PlotDataMarker(color="rgba(76,175,80,0.6)"))
                ]
            end

            # Identify top risk factors (simplified analysis)
            risk_factor_counts = Dict{String,Int}()
            for p in filtered_by_threshold
                if p["risk_score"] > 0.67
                    age_gt75 = get(p, "age", 65) > 75
                    high_cost = get(p, "total_cost", 0.0) > 10000.0
                    high_comorbidity = get(p, "comorbidity_count", 0) > 2

                    age_gt75 && (risk_factor_counts["Age > 75"] = get(risk_factor_counts, "Age > 75", 0) + 1)
                    high_cost && (risk_factor_counts["High Cost"] = get(risk_factor_counts, "High Cost", 0) + 1)
                    high_comorbidity && (risk_factor_counts["High Comorbidities"] = get(risk_factor_counts, "High Comorbidities", 0) + 1)
                    p["cost_anomaly"] && (risk_factor_counts["Cost Anomaly"] = get(risk_factor_counts, "Cost Anomaly", 0) + 1)
                end
            end

            if !isempty(risk_factor_counts)
                factors = sort(collect(keys(risk_factor_counts)), by=k -> risk_factor_counts[k], rev=true)[1:min(5, length(risk_factor_counts))]
                frequencies = [risk_factor_counts[f] for f in factors]
                risk_factors_frequency = [
                    PlotData(x=factors, y=frequencies, plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        marker=PlotDataMarker(color="rgba(156,39,176,0.6)"), name="Frequency")
                ]
            end

            # Build high risk patient list (top 20 for display)
            high_risk_patients = high_risk_count > 0 ? patient_risks[1:min(20, length(patient_risks))] : []
        end
    end

    # ── Export Report Handler ───────────────────────────────────────────────
    @onchange report_generated begin
        if report_generated
            report_generated = false

            report_content = """
            PATIENT RISK STRATIFICATION REPORT
            Generated: $(now())

            SUMMARY STATISTICS
            • Total Patients Analyzed: $filtered_count
            • High Risk Patients (>0.67): $high_risk_count
            • Medium Risk Patients (0.33-0.67): $medium_risk_count
            • Low Risk Patients (<0.33): $low_risk_count

            RISK METRICS
            • Average Risk Score: $(format_percentage(avg_risk_score))
            • Median Risk Score: $(format_percentage(median_risk_score))
            • Readmission Rate: $(format_percentage(readmission_rate))
            • Cost Anomaly Rate: $(format_percentage(cost_anomaly_rate))

            FILTERS APPLIED
            • Cohort: $cohort_filter
            • Risk Threshold: $(format_percentage(risk_threshold))
            • Sort By: $sort_by

            TOP RISK FACTORS
            $(join([k => v for (k, v) in sort(collect(risk_factor_counts), by=x->x[2], rev=true)], "\n"))

            RECOMMENDATIONS
            • Focus intervention efforts on $high_risk_count high-risk patients
            • Monitor $medium_risk_count medium-risk patients for risk progression
            • Implement care coordination for patients with multiple risk factors
            """

            report_generated = false
        end
    end
end


"""Helper function to format percentage"""
function format_percentage(value::Float64)
    return "$(round(value * 100; digits=1))%"
end
