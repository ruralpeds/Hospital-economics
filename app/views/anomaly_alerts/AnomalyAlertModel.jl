"""
Stipple reactive model for Anomaly Alert Board Dashboard.
Real-time alerts for readmission risk, cost anomalies, and complications.
"""
using Stipple, StippleUI, StipplePlotly
using Dates

@app begin
    # ──────── UI state ────────
    @in left_drawer_open::Bool = true

    # ──────── Export ────────
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false

    @in alert_severity::String = "all"  # "all", "high", "critical"
    @in auto_refresh::Bool = true
    @in refresh_interval::Int = 60  # seconds
    @in acknowledge_alert::Bool = false
    @in recalculate::Bool = false

    @in alert_data::Vector{Dict} = []

    # ── Alert Metrics ───────────────────────────────────────────────────────
    @out critical_count::Int = 0
    @out high_count::Int = 0
    @out medium_count::Int = 0
    @out total_alerts::Int = 0
    @out unacknowledged_count::Int = 0

    # ── Active Alerts List ──────────────────────────────────────────────────
    @out active_alerts::Vector{Dict} = []
    @out alert_columns::Vector{Dict} = [
        Dict("name" => "patient_id", "label" => "Patient", "field" => "patient_id"),
        Dict("name" => "alert_type", "label" => "Type", "field" => "alert_type"),
        Dict("name" => "severity", "label" => "Severity", "field" => "severity"),
        Dict("name" => "timestamp", "label" => "Time", "field" => "timestamp"),
        Dict("name" => "description", "label" => "Description", "field" => "description"),
    ]

    # ── Alert Timeline ─────────────────────────────────────────────────────
    @out alert_timeline::Vector{PlotData} = []
    @out timeline_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Alert Timeline"),
        xaxis = PlotLayoutAxis(title = "Time"),
        yaxis = PlotLayoutAxis(title = "Alert Count")
    )

    # ── Alert Categories (Pie) ──────────────────────────────────────────────
    @out alert_categories::Vector{PlotData} = []
    @out categories_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Alert Categories")
    )

    # ── Handlers ────────────────────────────────────────────────────────────
    @onchange recalculate, alert_severity begin
        if recalculate || !isempty(alert_data)
            recalculate = false

            # Filter alerts by severity
            filtered_alerts = if alert_severity == "all"
                alert_data
            elseif alert_severity == "critical"
                filter(a -> a["severity"] == "critical", alert_data)
            elseif alert_severity == "high"
                filter(a -> a["severity"] in ["critical", "warning"], alert_data)
            else
                alert_data
            end

            # Count alerts by severity
            critical_count = count(a -> a["severity"] == "critical", alert_data)
            high_count = count(a -> a["severity"] == "warning", alert_data)
            medium_count = count(a -> a["severity"] == "info", alert_data)
            total_alerts = length(alert_data)
            unacknowledged_count = count(a -> !get(a, "acknowledged", false), filtered_alerts)

            # Set active alerts list
            active_alerts = sort(filtered_alerts, by=a -> get(a, "timestamp", now()), rev=true)[1:min(50, length(filtered_alerts))]

            # Alert timeline (count by hour)
            hours = ["0-1h", "1-2h", "2-4h", "4-8h", "8-24h"]
            now_time = now()
            counts = [
                count(a -> now_time - Hour(1) <= a["timestamp"] <= now_time, alert_data),
                count(a -> now_time - Hour(2) <= a["timestamp"] < now_time - Hour(1), alert_data),
                count(a -> now_time - Hour(4) <= a["timestamp"] < now_time - Hour(2), alert_data),
                count(a -> now_time - Hour(8) <= a["timestamp"] < now_time - Hour(4), alert_data),
                count(a -> now_time - Hour(24) <= a["timestamp"] < now_time - Hour(8), alert_data),
            ]

            alert_timeline = [
                PlotData(x=hours, y=counts, plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                    marker=PlotDataMarker(color="rgba(244,67,54,0.6)"))
            ]

            # Alert categories
            readmission_alerts = count(a -> a["alert_type"] == "readmission", alert_data)
            cost_alerts = count(a -> a["alert_type"] == "cost_anomaly", alert_data)
            complication_alerts = count(a -> a["alert_type"] == "complication", alert_data)

            if total_alerts > 0
                alert_categories = [
                    PlotData(labels=["Readmission", "Cost Anomaly", "Complication"],
                        values=[readmission_alerts, cost_alerts, complication_alerts],
                        plot=StipplePlotly.Charts.PLOT_TYPE_PIE)
                ]
            end
        end
    end
end
