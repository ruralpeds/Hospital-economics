"""
Cohort Risk Distribution Dashboard View
"""
module CohortRiskDashboard

using Genie
using Stipple, StippleUI
include("CohortRiskModel.jl")

@reactive model = CohortRiskModel.Reactive()

html(:div, class="q-pa-md") do
    [
        html(:h1, "Cohort Risk Distribution"),
        html(:div, class="row q-col-gutter-md q-mb-md") do
            [
                html(:div, class="col-md-6") do
                    html(:input, "", type="text", placeholder="overall", @bind("model.aggregation_level"),
                        class="q-field full-width")
                end,
                html(:div, class="col-md-6") do
                    html(:button, "Recalculate", @click("model.recalculate = true"),
                        class="q-btn q-btn-primary")
                end
            ]
        end,
        html(:div, class="row q-col-gutter-md q-mb-md") do
            [
                html(:div, class="col-md-3") do
                    html(:div, class="q-pa-md bg-blue-1") do
                        [html(:span, "P10: "), html(:span, class="text-weight-bold", "{{ (p10 * 100) |> round |> Int }}%")]
                    end
                end,
                html(:div, class="col-md-3") do
                    html(:div, class="q-pa-md bg-blue-1") do
                        [html(:span, "P50: "), html(:span, class="text-weight-bold", "{{ (p50 * 100) |> round |> Int }}%")]
                    end
                end,
                html(:div, class="col-md-3") do
                    html(:div, class="q-pa-md bg-blue-1") do
                        [html(:span, "P90: "), html(:span, class="text-weight-bold", "{{ (p90 * 100) |> round |> Int }}%")]
                    end
                end,
                html(:div, class="col-md-3") do
                    html(:div, class="q-pa-md bg-blue-1") do
                        [html(:span, "Mean: "), html(:span, class="text-weight-bold", "{{ (mean_risk * 100) |> round |> Int }}%")]
                    end
                end
            ]
        end,
        html(:div, class="row q-col-gutter-md") do
            [
                html(:div, class="col-lg-6") do
                    html(:div, class="q-pa-md bg-white rounded-borders") do
                        plot(:percentile_chart, layout=:percentile_layout)
                    end
                end,
                html(:div, class="col-lg-6") do
                    html(:div, class="q-pa-md bg-white rounded-borders") do
                        plot(:anomaly_distribution, layout=:anomaly_layout)
                    end
                end
            ]
        end
    ]
end

end
