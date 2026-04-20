"""
Risk Stratification Dashboard View - HTML/Quasar Interface
"""

module RiskStratificationDashboard

using Genie
using Stipple, StippleUI
include("RiskStratificationModel.jl")

# Create model instance
@reactive model = RiskStratificationModel.Reactive(
    left_drawer_open = true,
    cohort_filter = "all",
    risk_threshold = 0.33,
    sort_by = "risk",
    search_patient_id = "",
    recalculate = false
)

# ── Initial data load ───────────────────────────────────────────────────────
# In production, this would load from database or API
# For now, we'll create sample data structures for testing
function initialize_cohort_data()
    return [
        Dict(
            "patient_id" => "PT001",
            "age" => 78,
            "comorbidity_count" => 3,
            "los" => 5,
            "total_cost" => 12500.0,
            "service_line" => "Cardiology",
            "complication_risk" => 0.25,
            "risk_score" => 0.0,
            "readmission_risk" => 0.0,
            "cost_anomaly" => false,
            "cost_flag" => "No"
        ),
        Dict(
            "patient_id" => "PT002",
            "age" => 65,
            "comorbidity_count" => 1,
            "los" => 3,
            "total_cost" => 4500.0,
            "service_line" => "Orthopedics",
            "complication_risk" => 0.05,
            "risk_score" => 0.0,
            "readmission_risk" => 0.0,
            "cost_anomaly" => false,
            "cost_flag" => "No"
        ),
        Dict(
            "patient_id" => "PT003",
            "age" => 82,
            "comorbidity_count" => 4,
            "los" => 7,
            "total_cost" => 15000.0,
            "service_line" => "Cardiology",
            "complication_risk" => 0.35,
            "risk_score" => 0.0,
            "readmission_risk" => 0.0,
            "cost_anomaly" => false,
            "cost_flag" => "No"
        ),
        Dict(
            "patient_id" => "PT004",
            "age" => 71,
            "comorbidity_count" => 2,
            "los" => 4,
            "total_cost" => 6800.0,
            "service_line" => "Orthopedics",
            "complication_risk" => 0.12,
            "risk_score" => 0.0,
            "readmission_risk" => 0.0,
            "cost_anomaly" => false,
            "cost_flag" => "No"
        ),
    ]
end

# Initialize data
model.cohort_data = initialize_cohort_data()
model.recalculate = true  # Trigger initial computation

# ── HTML View ───────────────────────────────────────────────────────────────
html(:div, class="q-pa-md") do
    [
        # ── Header ──────────────────────────────────────────────────────────
        html(:div, class="row q-col-gutter-md q-mb-md") do
            [
                html(:div, class="col-12") do
                    html(:div, class="row items-center") do
                        [
                            html(:div, class="col") do
                                html(:h1, class="q-my-none", "Patient Risk Stratification Dashboard")
                            end,
                            html(:div, class="col-auto") do
                                html(:button, "Generate Report", @click("report_generated = true"),
                                    class="q-btn q-btn-primary")
                            end
                        ]
                    end
                end
            ]
        end,

        # ── Controls Section ────────────────────────────────────────────────
        html(:div, class="row q-col-gutter-md q-mb-md") do
            [
                html(:div, class="col-md-3 col-sm-6") do
                    html(:div, class="q-gutter-md") do
                        [
                            html(:div,
                                html(:label, "Cohort Filter", class="text-weight-bold"),
                                html(:input, "", type="text", placeholder="all", @bind("cohort_filter"),
                                    class="q-field q-mt-sm full-width"),
                            class="q-mb-md"
                            )
                        ]
                    end
                end,
                html(:div, class="col-md-3 col-sm-6") do
                    html(:div,
                        html(:label, "Risk Threshold", class="text-weight-bold"),
                        html(:input, "", type="range", min="0", max="1", step="0.1", @bind("risk_threshold"),
                            class="full-width q-mt-sm"),
                        html(:div, "$(round(risk_threshold; digits=2))", class="text-caption text-center q-mt-xs"),
                    class="q-mb-md"
                    )
                end,
                html(:div, class="col-md-3 col-sm-6") do
                    html(:div,
                        html(:label, "Sort By", class="text-weight-bold"),
                        html(:input, "", type="text", placeholder="risk", @bind("sort_by"),
                            class="q-field q-mt-sm full-width"),
                    class="q-mb-md"
                    )
                end,
                html(:div, class="col-md-3 col-sm-6") do
                    html(:div,
                        html(:label, "Search Patient ID", class="text-weight-bold"),
                        html(:input, "", type="text", placeholder="PT001", @bind("search_patient_id"),
                            class="q-field q-mt-sm full-width"),
                    class="q-mb-md"
                    )
                end,
                html(:div, class="col-12") do
                    html(:button, "Recalculate", @click("recalculate = true"),
                        class="q-btn q-btn-secondary")
                end
            ]
        end,

        # ── Summary Statistics Cards ────────────────────────────────────────
        html(:div, class="row q-col-gutter-md q-mb-md") do
            [
                # High Risk Card
                html(:div, class="col-md-3 col-sm-6") do
                    html(:div, class="q-pa-md bg-red-1 rounded-borders") do
                        [
                            html(:div, class="text-h6 text-red text-weight-bold", "{{ high_risk_count }}"),
                            html(:div, class="text-caption text-grey-8", "High Risk Patients"),
                            html(:div, class="text-caption q-mt-sm", "Risk > 0.67")
                        ]
                    end
                end,

                # Medium Risk Card
                html(:div, class="col-md-3 col-sm-6") do
                    html(:div, class="q-pa-md bg-orange-1 rounded-borders") do
                        [
                            html(:div, class="text-h6 text-orange text-weight-bold", "{{ medium_risk_count }}"),
                            html(:div, class="text-caption text-grey-8", "Medium Risk Patients"),
                            html(:div, class="text-caption q-mt-sm", "Risk 0.33-0.67")
                        ]
                    end
                end,

                # Low Risk Card
                html(:div, class="col-md-3 col-sm-6") do
                    html(:div, class="q-pa-md bg-green-1 rounded-borders") do
                        [
                            html(:div, class="text-h6 text-green text-weight-bold", "{{ low_risk_count }}"),
                            html(:div, class="text-caption text-grey-8", "Low Risk Patients"),
                            html(:div, class="text-caption q-mt-sm", "Risk < 0.33")
                        ]
                    end
                end,

                # Average Risk Card
                html(:div, class="col-md-3 col-sm-6") do
                    html(:div, class="q-pa-md bg-blue-1 rounded-borders") do
                        [
                            html(:div, class="text-h6 text-blue text-weight-bold",
                                "{{ (avg_risk_score * 100) |> (x -> round(x; digits=0)) }}%"),
                            html(:div, class="text-caption text-grey-8", "Average Risk"),
                            html(:div, class="text-caption q-mt-sm", "Cohort Mean")
                        ]
                    end
                end
            ]
        end,

        # ── Charts Section ──────────────────────────────────────────────────
        html(:div, class="row q-col-gutter-md q-mb-md") do
            [
                # Risk Distribution Histogram
                html(:div, class="col-lg-6 col-md-12") do
                    html(:div, class="q-pa-md bg-white rounded-borders") do
                        plot(:risk_distribution, layout=:risk_distribution_layout)
                    end
                end,

                # Service Line Breakdown
                html(:div, class="col-lg-6 col-md-12") do
                    html(:div, class="q-pa-md bg-white rounded-borders") do
                        plot(:service_line_breakdown, layout=:service_line_layout)
                    end
                end
            ]
        end,

        # ── Risk Factors Section ────────────────────────────────────────────
        html(:div, class="row q-col-gutter-md q-mb-md") do
            [
                html(:div, class="col-12") do
                    html(:div, class="q-pa-md bg-white rounded-borders") do
                        plot(:risk_factors_frequency, layout=:risk_factors_layout)
                    end
                end
            ]
        end,

        # ── High Risk Patient Table ─────────────────────────────────────────
        html(:div, class="row q-col-gutter-md q-mb-md") do
            [
                html(:div, class="col-12") do
                    html(:div, class="q-pa-md bg-white rounded-borders") do
                        [
                            html(:h5, class="q-my-none q-mb-md", "High Risk Patients (Top 20)"),
                            html(:div,
                                "{{ filtered_count }} patients shown",
                                class="text-caption text-grey-8 q-mb-md"
                            ),
                            # Simplified table representation (production would use q-table)
                            html(:table, class="full-width") do
                                [
                                    html(:thead, style="border-bottom: 2px solid #ddd;") do
                                        html(:tr, style="background-color: #f5f5f5;") do
                                            [
                                                html(:th, class="text-left q-pa-md", "Patient ID"),
                                                html(:th, class="text-center q-pa-md", "Risk Score"),
                                                html(:th, class="text-center q-pa-md", "Risk Category"),
                                                html(:th, class="text-center q-pa-md", "Readmission Risk"),
                                                html(:th, class="text-center q-pa-md", "Cost Anomaly"),
                                                html(:th, class="text-center q-pa-md", "Complication Risk"),
                                            ]
                                        end
                                    end,
                                    html(:tbody) do
                                        [
                                            html(:tr, style="border-bottom: 1px solid #eee;") do
                                                [
                                                    html(:td, class="q-pa-md text-left", "{{ patient.patient_id }}"),
                                                    html(:td, class="q-pa-md text-center", "{{ (patient.risk_score * 100) |> (x -> round(x; digits=0)) }}%"),
                                                    html(:td, class="q-pa-md text-center",
                                                        "{{ patient.risk_score > 0.67 ? 'High' : (patient.risk_score > 0.33 ? 'Medium' : 'Low') }}"
                                                    ),
                                                    html(:td, class="q-pa-md text-center", "{{ (patient.readmission_risk * 100) |> (x -> round(x; digits=0)) }}%"),
                                                    html(:td, class="q-pa-md text-center", "{{ patient.cost_flag }}"),
                                                    html(:td, class="q-pa-md text-center", "{{ (patient.complication_risk * 100) |> (x -> round(x; digits=0)) }}%"),
                                                ]
                                            end
                                        ]
                                    end
                                ]
                            end |> (tbl -> [tbl for _ in patient_risks])
                        ]
                    end
                end
            ]
        end,

        # ── Metrics Summary ─────────────────────────────────────────────────
        html(:div, class="row q-col-gutter-md") do
            [
                html(:div, class="col-md-6 col-sm-12") do
                    html(:div, class="q-pa-md bg-white rounded-borders") do
                        [
                            html(:h5, class="q-my-none q-mb-md", "Readmission Metrics"),
                            html(:div, class="q-gutter-md") do
                                [
                                    html(:div, class="row items-center") do
                                        [
                                            html(:div, class="col text-grey-8", "Readmission Rate:"),
                                            html(:div, class="col-auto text-weight-bold",
                                                "{{ (readmission_rate * 100) |> (x -> round(x; digits=1)) }}%")
                                        ]
                                    end,
                                    html(:div, class="row items-center") do
                                        [
                                            html(:div, class="col text-grey-8", "Cost Anomaly Rate:"),
                                            html(:div, class="col-auto text-weight-bold",
                                                "{{ (cost_anomaly_rate * 100) |> (x -> round(x; digits=1)) }}%")
                                        ]
                                    end
                                ]
                            end
                        ]
                    end
                end,

                html(:div, class="col-md-6 col-sm-12") do
                    html(:div, class="q-pa-md bg-white rounded-borders") do
                        [
                            html(:h5, class="q-my-none q-mb-md", "Risk Score Distribution"),
                            html(:div, class="q-gutter-md") do
                                [
                                    html(:div, class="row items-center") do
                                        [
                                            html(:div, class="col text-grey-8", "Average Risk:"),
                                            html(:div, class="col-auto text-weight-bold",
                                                "{{ (avg_risk_score * 100) |> (x -> round(x; digits=1)) }}%")
                                        ]
                                    end,
                                    html(:div, class="row items-center") do
                                        [
                                            html(:div, class="col text-grey-8", "Median Risk:"),
                                            html(:div, class="col-auto text-weight-bold",
                                                "{{ (median_risk_score * 100) |> (x -> round(x; digits=1)) }}%")
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

end # module
