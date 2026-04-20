"""
Service Line Analytics Dashboard View - HTML/Quasar Interface
"""

module ServiceLineAnalyticsDashboard

using Genie
using Stipple, StippleUI
include("ServiceLineAnalyticsModel.jl")

# Create model instance
@reactive model = ServiceLineAnalyticsModel.Reactive(
    left_drawer_open = true,
    selected_service_line = "all",
    comparison_type = "cost_vs_risk"
)

# ── HTML View ───────────────────────────────────────────────────────────────
html(:div, class="q-pa-md") do
    [
        # ── Header ──────────────────────────────────────────────────────────
        html(:div, class="row q-col-gutter-md q-mb-md") do
            [
                html(:div, class="col") do
                    html(:h1, class="q-my-none", "Service Line Analytics Dashboard")
                end
            ]
        end,

        # ── Controls Section ────────────────────────────────────────────────
        html(:div, class="row q-col-gutter-md q-mb-md") do
            [
                html(:div, class="col-md-4 col-sm-6") do
                    html(:div,
                        html(:label, "Select Service Line", class="text-weight-bold"),
                        html(:input, "", type="text", placeholder="all", @bind("selected_service_line"),
                            class="q-field q-mt-sm full-width"),
                    class="q-mb-md"
                    )
                end,
                html(:div, class="col-md-4 col-sm-6") do
                    html(:div,
                        html(:label, "Comparison Type", class="text-weight-bold"),
                        html(:input, "", type="text", placeholder="cost_vs_risk", @bind("comparison_type"),
                            class="q-field q-mt-sm full-width"),
                    class="q-mb-md"
                    )
                end,
                html(:div, class="col-md-4 col-sm-12") do
                    html(:button, "Recalculate", @click("recalculate = true"),
                        class="q-btn q-btn-primary")
                end
            ]
        end,

        # ── Selected Service Line Summary ───────────────────────────────────
        html(:div, class="row q-col-gutter-md q-mb-md") do
            [
                html(:div, class="col-12") do
                    html(:div, class="q-pa-md bg-blue-1 rounded-borders") do
                        [
                            html(:h5, class="q-my-none q-mb-sm", "{{ selected_service_name }}"),
                            html(:div, class="row q-col-gutter-md") do
                                [
                                    html(:div, class="col-auto") do
                                        html(:span, class="text-caption text-grey-8", "Cases: {{ case_volume }}")
                                    end,
                                    html(:div, class="col-auto") do
                                        html(:span, class="text-caption text-grey-8", "Avg Cost: \${{ (avg_cost) |> (x -> round(x; digits=0)) |> Int }}")
                                    end,
                                    html(:div, class="col-auto") do
                                        html(:span, class="text-caption text-grey-8", "Avg LOS: {{ (avg_los) |> (x -> round(x; digits=1)) }} days")
                                    end,
                                    html(:div, class="col-auto") do
                                        html(:span, class="text-caption text-grey-8", "Quality: {{ (quality_score * 100) |> (x -> round(x; digits=0)) }}%")
                                    end
                                ]
                            end
                        ]
                    end
                end
            ]
        end,

        # ── Key Metrics Cards ───────────────────────────────────────────────
        html(:div, class="row q-col-gutter-md q-mb-md") do
            [
                html(:div, class="col-12") do
                    html(:div, class="row q-col-gutter-md") do
                        # Dynamically render metric cards
                        [html(:div, class="col-md-2 col-sm-6") do
                            html(:div, class="q-pa-md rounded-borders", style="background: rgba(33,150,243,0.1);") do
                                [
                                    html(:div, class="text-caption text-grey-8", "{{ metric.label }}"),
                                    html(:div, class="text-h6 q-mt-sm q-mb-none", "{{ metric.value }}")
                                ]
                            end
                        end for metric in metrics_data]
                    end
                end
            ]
        end,

        # ── Charts Section ──────────────────────────────────────────────────
        html(:div, class="row q-col-gutter-md q-mb-md") do
            [
                # Cost vs Risk Scatter
                html(:div, class="col-lg-6 col-md-12") do
                    html(:div, class="q-pa-md bg-white rounded-borders") do
                        plot(:cost_vs_risk_scatter, layout=:cost_vs_risk_layout)
                    end
                end,

                # Comparison Radar Chart
                html(:div, class="col-lg-6 col-md-12") do
                    html(:div, class="q-pa-md bg-white rounded-borders") do
                        plot(:comparison_radar, layout=:comparison_layout)
                    end
                end
            ]
        end,

        # ── Service Line Comparison Table ───────────────────────────────────
        html(:div, class="row q-col-gutter-md q-mb-md") do
            [
                html(:div, class="col-12") do
                    html(:div, class="q-pa-md bg-white rounded-borders") do
                        [
                            html(:h5, class="q-my-none q-mb-md", "Service Line Comparison"),
                            html(:table, class="full-width") do
                                [
                                    html(:thead, style="border-bottom: 2px solid #ddd;") do
                                        html(:tr, style="background-color: #f5f5f5;") do
                                            [
                                                html(:th, class="text-left q-pa-md", "Service Line"),
                                                html(:th, class="text-center q-pa-md", "Cases"),
                                                html(:th, class="text-right q-pa-md", "Avg Cost"),
                                                html(:th, class="text-center q-pa-md", "Avg LOS"),
                                                html(:th, class="text-center q-pa-md", "Quality"),
                                                html(:th, class="text-center q-pa-md", "Readmission"),
                                                html(:th, class="text-center q-pa-md", "Avg Risk"),
                                            ]
                                        end
                                    end,
                                    html(:tbody) do
                                        [
                                            html(:tr, style="border-bottom: 1px solid #eee;") do
                                                [
                                                    html(:td, class="q-pa-md text-left", "{{ row.service_line }}"),
                                                    html(:td, class="q-pa-md text-center", "{{ row.case_volume }}"),
                                                    html(:td, class="q-pa-md text-right", "\${{ (row.avg_cost) |> (x -> round(x; digits=0)) |> Int }}"),
                                                    html(:td, class="q-pa-md text-center", "{{ (row.avg_los) |> (x -> round(x; digits=1)) }}"),
                                                    html(:td, class="q-pa-md text-center", "{{ (row.quality_score * 100) |> (x -> round(x; digits=0)) }}%"),
                                                    html(:td, class="q-pa-md text-center", "{{ (row.readmission_rate * 100) |> (x -> round(x; digits=0)) }}%"),
                                                    html(:td, class="q-pa-md text-center", "{{ (row.avg_risk_score * 100) |> (x -> round(x; digits=0)) }}%"),
                                                ]
                                            end
                                        ]
                                    end
                                ]
                            end |> (tbl -> [tbl for _ in comparison_table])
                        ]
                    end
                end
            ]
        end,

        # ── Cost Efficiency & Risk Factors ──────────────────────────────────
        html(:div, class="row q-col-gutter-md") do
            [
                html(:div, class="col-md-6 col-sm-12") do
                    html(:div, class="q-pa-md bg-white rounded-borders") do
                        [
                            html(:h5, class="q-my-none q-mb-md", "Cost Efficiency"),
                            html(:div, class="q-gutter-md") do
                                [
                                    html(:div, class="row items-center") do
                                        [
                                            html(:div, class="col text-grey-8", "Efficiency Score:"),
                                            html(:div, class="col-auto text-weight-bold",
                                                "\${{ (cost_efficiency['efficiency_score']) |> (x -> round(x; digits=0)) |> Int }} per quality point")
                                        ]
                                    end,
                                    html(:div, class="row items-center") do
                                        [
                                            html(:div, class="col text-grey-8", "Rank:"),
                                            html(:div, class="col-auto text-weight-bold",
                                                "{{ cost_efficiency['rank'] }} / 6")
                                        ]
                                    end,
                                    html(:div, class="row items-center") do
                                        [
                                            html(:div, class="col text-grey-8", "Percentile:"),
                                            html(:div, class="col-auto text-weight-bold",
                                                "{{ (cost_efficiency['percentile']) |> (x -> round(x; digits=0)) }}th")
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
                            html(:h5, class="q-my-none q-mb-md", "Top Risk Factors"),
                            html(:div, class="q-gutter-sm") do
                                [
                                    html(:div, class="row items-center") do
                                        [
                                            html(:div, class="col text-grey-8", "{{ factor['factor'] }}:"),
                                            html(:div, class="col-auto text-weight-bold", "{{ factor['count'] }} patients")
                                        ]
                                    end
                                    for factor in top_risk_factors
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
