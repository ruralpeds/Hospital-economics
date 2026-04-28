"""
DevComponentsModel — reactive model for the /dev/components demo pages.
Disabled in production (GENIE_ENV == "prod").

Provides enough reactive state to demonstrate every reusable component
without wiring to real domain logic.
"""
using Stipple, StippleUI, StipplePlotly
using Dates

@app begin
    @in left_drawer_open::Bool = true

    # ── FormGrid demo ────────────────────────────────────────────────────
    @in fg_discount_rate::Float64      = 3.0
    @in fg_time_horizon::Int           = 10
    @in fg_cohort::String              = ""
    @in fg_date_start::String          = "2025-01-01"
    @in fg_date_end::String            = "2025-12-31"
    @in fg_toggle_flag::Bool           = false
    @in fg_category::String            = "option_a"
    @in fg_tags::Vector{String}        = []
    @in fg_fill_from_upload::Bool      = false
    @out fg_category_options::Vector{Dict{String,Any}} = [
        Dict("label" => "Option A", "value" => "option_a"),
        Dict("label" => "Option B", "value" => "option_b"),
        Dict("label" => "Option C", "value" => "option_c"),
    ]
    @out cohort_options::Vector{Dict{String,Any}} = [
        Dict("label" => "All Patients",         "value" => "all"),
        Dict("label" => "Medicare (65+)",        "value" => "medicare_65"),
        Dict("label" => "Medicaid Low-Income",   "value" => "medicaid_low"),
    ]

    # ── ResultTable demo ─────────────────────────────────────────────────
    @out rt_rows::Vector{Dict{String,Any}} = [
        Dict("year" => 2025, "revenue" => 18_500_000.0, "cost" => 19_200_000.0, "margin" => -3.8),
        Dict("year" => 2026, "revenue" => 19_100_000.0, "cost" => 19_600_000.0, "margin" => -2.6),
        Dict("year" => 2027, "revenue" => 19_800_000.0, "cost" => 20_100_000.0, "margin" => -1.5),
        Dict("year" => 2028, "revenue" => 20_600_000.0, "cost" => 20_500_000.0, "margin" =>  0.5),
        Dict("year" => 2029, "revenue" => 21_400_000.0, "cost" => 20_900_000.0, "margin" =>  2.4),
    ]
    @in rt_filter::String        = ""
    @in rt_export_csv::Bool      = false
    @in rt_export_xlsx::Bool     = false

    # ── PlotPanel demo ───────────────────────────────────────────────────
    @out pp_trend_data::Vector{PlotData} = [
        PlotData(
            x    = [2025, 2026, 2027, 2028, 2029],
            y    = [-3.8, -2.6, -1.5, 0.5, 2.4],
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "Operating Margin (%)",
            mode = "lines+markers",
        )
    ]
    @out pp_trend_layout::PlotLayout = PlotLayout(
        title      = PlotLayoutTitle(text="Operating Margin Trend"),
        xaxis      = [PlotLayoutAxis(title="Year")],
        yaxis      = [PlotLayoutAxis(title="Margin %", tickformat=".1f")],
        showlegend = true,
    )

    @out pp_bar_data::Vector{PlotData} = [
        PlotData(
            x    = ["Inpatient", "Outpatient", "Emergency", "Other"],
            y    = [8_000_000.0, 7_200_000.0, 2_800_000.0, 500_000.0],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "Revenue by Service Line",
        )
    ]
    @out pp_bar_layout::PlotLayout = PlotLayout(
        title  = PlotLayoutTitle(text="Revenue by Service Line"),
        xaxis  = [PlotLayoutAxis(title="Service Line")],
        yaxis  = [PlotLayoutAxis(title="Revenue (\$)")],
    )

    @out pp_pie_data::Vector{PlotData} = [
        PlotData(
            values = [62, 18, 12, 8],
            labels = ["Medicare", "Medicaid", "Commercial", "Self-Pay"],
            plot   = StipplePlotly.Charts.PLOT_TYPE_PIE,
            hole   = 0.4,
            name   = "Payer Mix",
        )
    ]
    @out pp_pie_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text="Payer Mix"),
    )

    # ── ExportBar demo ───────────────────────────────────────────────────
    @in eb_export_csv::Bool     = false
    @in eb_export_xlsx::Bool    = false
    @in eb_export_json::Bool    = false
    @in eb_export_pdf::Bool     = false
    @in eb_export_png::Bool     = false
    @in eb_copy_methods::Bool   = false
    @out eb_last_action::String = "(none)"

    # ── CohortPicker demo ────────────────────────────────────────────────
    @in cohort_min_age::Int         = 18
    @in cohort_max_age::Int         = 120
    @in cohort_dx_codes::String     = ""
    @in cohort_cpt_codes::String    = ""
    @in cohort_payers::Vector{String} = []
    @in cohort_min_los::Int         = 0
    @in cohort_max_los::Int         = 30
    @in cohort_date_start::String   = ""
    @in cohort_date_end::String     = ""
    @in cohort_min_cost::Float64    = 0.0
    @in cohort_max_cost::Float64    = 999_999.0
    @in cohort_name::String         = ""
    @in cohort_save::Bool           = false
    @out cohort_status::String      = ""

    # ── ScenarioPicker demo ───────────────────────────────────────────────
    @in selected_scenario_id::String = ""
    @out scenario_options::Vector{Dict{String,Any}} = [
        Dict("label"=>"Baseline 2025",     "value"=>"s1",
             "description"=>"Current trajectory", "created_at"=>"2025-01-10"),
        Dict("label"=>"REH Conversion",    "value"=>"s2",
             "description"=>"Convert to Rural Emergency Hospital", "created_at"=>"2025-02-14"),
        Dict("label"=>"Cost-Cut Scenario", "value"=>"s3",
             "description"=>"10% across-the-board expense reduction", "created_at"=>"2025-03-01"),
    ]
    @in scenario_load::Bool   = false
    @in scenario_delete::Bool = false
    @in scenario_new::Bool    = false
    @out scenario_status::String = ""

    # ── AuditLogViewer demo ───────────────────────────────────────────────
    @out audit_entries::Vector{Dict{String,Any}} = [
        Dict("timestamp"=>"2025-04-01T08:00:00Z", "user_id"=>"admin@hospital.org",
             "event_type"=>"INGESTION_START", "resource_id"=>"patients_q1.csv",
             "record_count"=>5000, "status"=>"SUCCESS", "ip_address"=>"10.0.0.1"),
        Dict("timestamp"=>"2025-04-01T08:01:22Z", "user_id"=>"admin@hospital.org",
             "event_type"=>"INGESTION_COMPLETE", "resource_id"=>"patients_q1.csv",
             "record_count"=>4982, "status"=>"SUCCESS", "ip_address"=>"10.0.0.1"),
        Dict("timestamp"=>"2025-04-02T09:15:00Z", "user_id"=>"analyst@hospital.org",
             "event_type"=>"EXPORT_INITIATED", "resource_id"=>"cohort_medicare_65",
             "record_count"=>3100, "status"=>"SUCCESS", "ip_address"=>"10.0.0.5"),
        Dict("timestamp"=>"2025-04-02T09:15:45Z", "user_id"=>"analyst@hospital.org",
             "event_type"=>"EXPORT_COMPLETE", "resource_id"=>"cohort_medicare_65",
             "record_count"=>3100, "status"=>"SUCCESS", "ip_address"=>"10.0.0.5"),
        Dict("timestamp"=>"2025-04-03T11:00:00Z", "user_id"=>"extern@partner.org",
             "event_type"=>"VALIDATION_ERROR", "resource_id"=>"claims_upload.xlsx",
             "record_count"=>12, "status"=>"FAILED", "ip_address"=>"203.0.113.42"),
    ]
    @in audit_filter_user::String        = ""
    @in audit_filter_action::String      = ""
    @in audit_filter_date_start::String  = ""
    @in audit_filter_date_end::String    = ""
    @in audit_filter_status::String      = ""
    @in audit_refresh::Bool              = false
    @in audit_export_csv::Bool           = false

    # ── Reactive handlers ────────────────────────────────────────────────

    @onchange cohort_save begin
        if cohort_save
            cohort_status = isempty(cohort_name) ?
                "Please enter a cohort name." :
                "Cohort \"$(cohort_name)\" saved (demo)."
            cohort_save = false
        end
    end

    @onchange scenario_load begin
        if scenario_load
            scenario_status = isempty(selected_scenario_id) ?
                "No scenario selected." :
                "Scenario $(selected_scenario_id) loaded (demo)."
            scenario_load = false
        end
    end

    @onchange scenario_new begin
        if scenario_new
            scenario_status = "New scenario dialog would open here (demo)."
            scenario_new = false
        end
    end

    @onchange eb_export_csv begin
        if eb_export_csv
            eb_last_action = "CSV export triggered at $(Dates.now())"
            eb_export_csv = false
        end
    end

    @onchange eb_export_xlsx begin
        if eb_export_xlsx
            eb_last_action = "XLSX export triggered at $(Dates.now())"
            eb_export_xlsx = false
        end
    end

    @onchange eb_export_json begin
        if eb_export_json
            eb_last_action = "JSON export triggered at $(Dates.now())"
            eb_export_json = false
        end
    end

    @onchange eb_export_pdf begin
        if eb_export_pdf
            eb_last_action = "PDF export triggered at $(Dates.now())"
            eb_export_pdf = false
        end
    end

    @onchange eb_copy_methods begin
        if eb_copy_methods
            eb_last_action = "Methods paragraph copied (demo)."
            eb_copy_methods = false
        end
    end

    @onchange audit_refresh begin
        if audit_refresh
            @info "DevComponents: audit log refresh requested"
            audit_refresh = false
        end
    end
end

const dev_components_model = @init
