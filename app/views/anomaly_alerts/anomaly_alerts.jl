"""
Anomaly Alert Board Dashboard View
"""
module AnomalyAlertBoard

using Genie
using Stipple, StippleUI
include("AnomalyAlertModel.jl")

@reactive model = AnomalyAlertModel.Reactive()

html(:div, class="q-pa-md") do
    [
        html(:h1, "Real-Time Anomaly Alert Board"),
        html(:div, class="row q-col-gutter-md q-mb-md") do
            [
                html(:div, class="col-auto") do
                    html(:input, "", type="text", placeholder="all", @bind("model.alert_severity"),
                        class="q-field")
                end,
                html(:div, class="col-auto") do
                    html(:button, "Refresh", @click("model.recalculate = true"),
                        class="q-btn q-btn-primary")
                end
            ]
        end,
        html(:div, class="row q-col-gutter-md q-mb-md") do
            [
                html(:div, class="col-md-3") do
                    html(:div, class="q-pa-md bg-red-1 rounded-borders") do
                        [
                            html(:div, class="text-h6 text-red text-weight-bold", "{{ critical_count }}"),
                            html(:div, class="text-caption", "Critical Alerts")
                        ]
                    end
                end,
                html(:div, class="col-md-3") do
                    html(:div, class="q-pa-md bg-orange-1 rounded-borders") do
                        [
                            html(:div, class="text-h6 text-orange text-weight-bold", "{{ high_count }}"),
                            html(:div, class="text-caption", "High Alerts")
                        ]
                    end
                end,
                html(:div, class="col-md-3") do
                    html(:div, class="q-pa-md bg-yellow-1 rounded-borders") do
                        [
                            html(:div, class="text-h6 text-weight-bold", "{{ medium_count }}"),
                            html(:div, class="text-caption", "Medium Alerts")
                        ]
                    end
                end,
                html(:div, class="col-md-3") do
                    html(:div, class="q-pa-md bg-blue-1 rounded-borders") do
                        [
                            html(:div, class="text-h6 text-blue text-weight-bold", "{{ unacknowledged_count }}"),
                            html(:div, class="text-caption", "Unacknowledged")
                        ]
                    end
                end
            ]
        end,
        html(:div, class="row q-col-gutter-md q-mb-md") do
            [
                html(:div, class="col-lg-6") do
                    html(:div, class="q-pa-md bg-white rounded-borders") do
                        plot(:alert_timeline, layout=:timeline_layout)
                    end
                end,
                html(:div, class="col-lg-6") do
                    html(:div, class="q-pa-md bg-white rounded-borders") do
                        plot(:alert_categories, layout=:categories_layout)
                    end
                end
            ]
        end,
        html(:div, class="row q-col-gutter-md") do
            [
                html(:div, class="col-12") do
                    html(:div, class="q-pa-md bg-white rounded-borders") do
                        [
                            html(:h5, "Active Alerts"),
                            html(:table, class="full-width") do
                                [
                                    html(:thead) do
                                        html(:tr) do
                                            [
                                                html(:th, "Patient"),
                                                html(:th, "Type"),
                                                html(:th, "Severity"),
                                                html(:th, "Time"),
                                                html(:th, "Description"),
                                            ]
                                        end
                                    end,
                                    html(:tbody) do
                                        [
                                            html(:tr) do
                                                [
                                                    html(:td, "{{ alert.patient_id }}"),
                                                    html(:td, "{{ alert.alert_type }}"),
                                                    html(:td, "{{ alert.severity }}"),
                                                    html(:td, "{{ alert.timestamp }}"),
                                                    html(:td, "{{ alert.description }}"),
                                                ]
                                            end
                                            for alert in active_alerts
                                        ]
                                    end
                                ]
                            end
                        ]
                    end
                end
            ]
        end
    ]
end

end
