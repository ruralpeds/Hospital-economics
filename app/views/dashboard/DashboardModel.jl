"""
Stipple reactive model for the Financial Dashboard.
Tracks KPIs, chart data, alerts, and user filter selections.
References RuralHospitalSim for financial ratio computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: compute_all_ratios, default_cah_benchmarks, compare_to_benchmarks


@app begin
    @in left_drawer_open::Bool = true
    # ── Reactive Inputs ──────────────────────────────────────────────────
    @in selected_hospital_id::Int = 1
    @in projection_months::Int = 12
    @in benchmark_comparison::String = "state_average"
    @in date_range_start::String = "2025-01-01"
    @in date_range_end::String = "2026-03-27"
    @in refresh_data::Bool = false
    @in show_benchmarks::Bool = true
    @in selected_kpi_detail::String = ""

    # ── KPI Reactive Outputs ─────────────────────────────────────────────
    @out hospital_name::String = "Prairie View Community Hospital"
    @out hospital_type::String = "Critical Access Hospital (CAH)"
    @out hospital_beds::Int = 25
    @out hospital_state::String = "KS"

    # Financial KPIs
    @out operating_margin::Float64 = -0.038
    @out operating_margin_trend::String = "declining"
    @out total_margin::Float64 = -0.021
    @out net_patient_revenue::Float64 = 18_500_000.0
    @out total_operating_expenses::Float64 = 19_200_000.0
    @out cost_per_adjusted_discharge::Float64 = 12_450.0
    @out days_cash_on_hand::Int = 42
    @out current_ratio::Float64 = 1.35
    @out debt_to_capitalization::Float64 = 0.48
    @out average_age_of_plant::Float64 = 14.2
    @out bad_debt_pct::Float64 = 0.062
    @out charity_care_pct::Float64 = 0.031

    # Volume KPIs
    @out avg_daily_census::Float64 = 8.3
    @out occupancy_rate::Float64 = 0.332
    @out ed_visits_annual::Int = 4200
    @out outpatient_visits::Int = 12800
    @out inpatient_discharges::Int = 620
    @out case_mix_index::Float64 = 0.85
    @out avg_length_of_stay::Float64 = 3.8
    @out outpatient_revenue_pct::Float64 = 0.58

    # Payer Mix
    @out medicare_pct::Float64 = 0.62
    @out medicaid_pct::Float64 = 0.18
    @out commercial_pct::Float64 = 0.12
    @out self_pay_pct::Float64 = 0.08

    # Staffing KPIs
    @out fte_count::Float64 = 142.0
    @out fte_per_aob::Float64 = 5.8
    @out labor_cost_pct::Float64 = 0.527
    @out vacancy_rate::Float64 = 0.12

    # ── Chart Data ───────────────────────────────────────────────────────
    @out margin_trend_data::Vector{PlotData} = [
        PlotData(
            x = ["2023-Q1","2023-Q2","2023-Q3","2023-Q4","2024-Q1","2024-Q2","2024-Q3","2024-Q4","2025-Q1","2025-Q2","2025-Q3","2025-Q4"],
            y = [-0.012, -0.018, -0.025, -0.028, -0.030, -0.032, -0.034, -0.035, -0.036, -0.037, -0.038, -0.038],
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "Operating Margin",
            mode = "lines+markers",
        ),
        PlotData(
            x = ["2023-Q1","2023-Q2","2023-Q3","2023-Q4","2024-Q1","2024-Q2","2024-Q3","2024-Q4","2025-Q1","2025-Q2","2025-Q3","2025-Q4"],
            y = [-0.005, -0.008, -0.012, -0.015, -0.016, -0.018, -0.019, -0.020, -0.020, -0.021, -0.021, -0.021],
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "Total Margin",
            mode = "lines+markers",
        )
    ]
    @out margin_trend_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Margin Trends (Quarterly)"),
        xaxis = [PlotLayoutAxis(title = "Quarter")],
        yaxis = [PlotLayoutAxis(title = "Margin %", tickformat = ".1%")],
        showlegend = true,
    )

    @out volume_chart_data::Vector{PlotData} = [
        PlotData(
            x = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],
            y = [340, 310, 365, 350, 370, 380, 355, 345, 360, 375, 350, 400],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "ED Visits",
        ),
        PlotData(
            x = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],
            y = [1050, 980, 1100, 1080, 1120, 1150, 1060, 1040, 1090, 1100, 1030, 1200],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Outpatient Visits",
        )
    ]
    @out volume_chart_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Monthly Patient Volume"),
        barmode = "group",
        xaxis = [PlotLayoutAxis(title = "Month")],
        yaxis = [PlotLayoutAxis(title = "Visits")],
    )

    @out payer_mix_data::Vector{PlotData} = [
        PlotData(
            values = [62, 18, 12, 8],
            labels = ["Medicare", "Medicaid", "Commercial", "Self-Pay"],
            plot = StipplePlotly.Charts.PLOT_TYPE_PIE,
            hole = 0.4,
            name = "Payer Mix",
        )
    ]
    @out payer_mix_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Payer Mix Distribution"),
    )

    @out revenue_expense_data::Vector{PlotData} = [
        PlotData(
            x = ["2021","2022","2023","2024","2025"],
            y = [17.2, 17.8, 18.1, 18.3, 18.5],
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "Revenue (\$M)",
            mode = "lines+markers",
        ),
        PlotData(
            x = ["2021","2022","2023","2024","2025"],
            y = [17.0, 17.5, 18.3, 18.9, 19.2],
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "Expenses (\$M)",
            mode = "lines+markers",
        )
    ]
    @out revenue_expense_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Revenue vs Expenses (Annual, \$M)"),
        xaxis = [PlotLayoutAxis(title = "Year")],
        yaxis = [PlotLayoutAxis(title = "\$ Millions")],
    )

    # ── Benchmark Comparison ─────────────────────────────────────────────
    @out benchmark_labels::Vector{String} = [
        "Operating Margin", "Days Cash", "Current Ratio",
        "FTE/AOB", "Case Mix Index", "Occupancy Rate"
    ]
    @out benchmark_hospital_values::Vector{Float64} = [-3.8, 42.0, 1.35, 5.8, 0.85, 33.2]
    @out benchmark_peer_values::Vector{Float64} = [-1.2, 58.0, 1.65, 5.2, 0.92, 38.5]

    # ── Alerts ───────────────────────────────────────────────────────────
    @out alerts::Vector{Dict{String,String}} = [
        Dict("severity" => "error", "message" => "Operating margin has been negative for 8 consecutive quarters"),
        Dict("severity" => "warning", "message" => "Days cash on hand (42) is below the 60-day recommended threshold"),
        Dict("severity" => "warning", "message" => "Vacancy rate (12%) exceeds state average (8.5%)"),
        Dict("severity" => "info", "message" => "REH conversion analysis available — estimated \$2.1M annual benefit"),
    ]

    # ── Hospital selector options ────────────────────────────────────────
    @out hospital_options::Vector{Dict{String,Any}} = [
        Dict("label" => "Prairie View Community Hospital", "value" => 1),
        Dict("label" => "Mountain Valley Medical Center", "value" => 2),
        Dict("label" => "Delta Regional Hospital", "value" => 3),
        Dict("label" => "High Plains Health", "value" => 4),
    ]

    # ── Handlers ─────────────────────────────────────────────────────────
    @onchange selected_hospital_id begin
        @info "Dashboard: loading data for hospital $selected_hospital_id"
        if selected_hospital_id == 1
            hospital_name = "Prairie View Community Hospital"
            hospital_type = "Critical Access Hospital (CAH)"
            operating_margin = -0.038
            days_cash_on_hand = 42
            net_patient_revenue = 18_500_000.0
            avg_daily_census = 8.3
        elseif selected_hospital_id == 2
            hospital_name = "Mountain Valley Medical Center"
            hospital_type = "Critical Access Hospital (CAH)"
            operating_margin = -0.015
            days_cash_on_hand = 67
            net_patient_revenue = 12_200_000.0
            avg_daily_census = 5.1
        elseif selected_hospital_id == 3
            hospital_name = "Delta Regional Hospital"
            hospital_type = "PPS Hospital"
            operating_margin = -0.072
            days_cash_on_hand = 28
            net_patient_revenue = 32_400_000.0
            avg_daily_census = 18.7
        else
            hospital_name = "High Plains Health"
            hospital_type = "Critical Access Hospital (CAH)"
            operating_margin = 0.012
            days_cash_on_hand = 85
            net_patient_revenue = 9_800_000.0
            avg_daily_census = 4.2
        end
    end

    @onchange benchmark_comparison begin
        @info "Benchmark comparison changed to: $benchmark_comparison"
        if benchmark_comparison == "state_average"
            benchmark_peer_values = [-1.2, 58.0, 1.65, 5.2, 0.92, 38.5]
        elseif benchmark_comparison == "national_average"
            benchmark_peer_values = [-0.8, 65.0, 1.72, 4.9, 0.95, 42.1]
        elseif benchmark_comparison == "top_quartile"
            benchmark_peer_values = [2.5, 95.0, 2.10, 4.5, 1.02, 52.0]
        end
    end

    @onchange refresh_data begin
        if refresh_data
            @info "Refreshing dashboard data..."
            refresh_data = false
        end
    end
end

const dashboard_model = @init
