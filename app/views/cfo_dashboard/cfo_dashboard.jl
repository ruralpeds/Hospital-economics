"""
    cfo_dashboard.jl — CFO 1-Pager UI View (MBA Gap F-03)

Single-screen layout targeting < 500ms load time.

Layout (3 rows):
  Row 1: Exception flags banner (collapses when all green)
  Row 2: 6 KPI cards with RAG chip, current value, WoW delta, peer percentile
  Row 3: 6 sparkline mini-charts (12-week trend)

Color scheme follows Quasar semantic colours:
  green → positive/bg-green-1 text-green-9
  amber → warning/bg-orange-1 text-orange-9
  red   → danger /bg-red-1 text-red-9
"""

function ui_cfo_dashboard(model)
    app_layout(model, "CFO 1-Pager", [

        # ── Page header ────────────────────────────────────────────────────
        row(class="q-mb-sm items-center", [
            cell(class="col-auto", [
                Html.div(class="text-h6 text-weight-bold", "CFO Executive Dashboard"),
                Html.div(class="text-caption text-grey-7",
                    var":text" => "hospital_name + ' · ' + hospital_type + ' · ' + fiscal_period"),
            ]),
            cell(class="col"),
            cell(class="col-auto q-gutter-sm", [
                # RAG summary badges
                quasar(:badge, color="red",    label! => "n_red_flags + ' Red'",
                       class="q-mr-xs text-body2"),
                quasar(:badge, color="orange", label! => "n_amber_flags + ' Amber'",
                       class="q-mr-xs text-body2"),
                quasar(:badge, color="green",  label! => "n_green_flags + ' Green'",
                       class="q-mr-xs text-body2"),
                quasar(:btn, icon="refresh",    dense=true, flat=true, round=true,
                       var"@click" => "refresh = !refresh"),
                quasar(:btn, icon="download",   dense=true, flat=true, round=true,
                       var"@click" => "do_csv = true", tooltip="Export CSV"),
            ]),
        ]),

        # ── Row 1: Exception flags banner ──────────────────────────────────
        row(class="q-mb-sm", [
            cell(class="col-12", [
                quasar(:banner,
                    var"v-if"      => "exception_flags.length > 0",
                    class          = "q-pa-xs rounded-borders",
                    style          = "background: #fff3cd;",
                    inline_actions = true,
                    [
                        Html.div(class="text-caption text-weight-medium q-mb-xs",
                                 "⚡ Active Exceptions"),
                        Html.div(
                            var"v-for" => "(flag, i) in exception_flags",
                            var":key"  => "i",
                            class      = "text-caption",
                            var":text" => "flag",
                        ),
                    ]
                ),
                Html.div(
                    var"v-if" => "exception_flags.length === 0",
                    class     = "q-pa-xs rounded-borders text-caption text-green-8",
                    style     = "background: #d4edda;",
                    "✅  All indicators within normal range",
                ),
            ]),
        ]),

        # ── Row 2: KPI Cards ───────────────────────────────────────────────
        row(class="q-gutter-xs q-mb-sm", [

            # KPI Card macro: (title, value_field, fmt, rag_field, delta_field, delta_fmt, peer_field)
            _cfo_kpi_card("Operating Margin",
                :operating_margin, ".1%", :rag_operating_margin,
                :delta_operating_margin, "+.1%",
                :peer_operating_margin_pct),

            _cfo_kpi_card("Days Cash on Hand",
                :days_cash_on_hand, ".1f", :rag_days_cash,
                :delta_days_cash, "+.1f",
                :peer_dcoh_pct; unit="d"),

            _cfo_kpi_card("Current Ratio",
                :current_ratio, ".2f", :rag_current_ratio,
                :delta_current_ratio, "+.2f",
                :peer_current_ratio_pct; unit="×"),

            _cfo_kpi_card("Debt / Capitalization",
                :debt_to_cap, ".1%", :rag_debt_to_cap,
                :delta_debt_to_cap, "+.1%",
                :peer_debt_to_cap_pct; lower_is_better=true),

            _cfo_kpi_card("Salary / Revenue",
                :salary_to_revenue, ".1%", :rag_salary,
                :delta_salary, "+.1%",
                nothing; lower_is_better=true),

            _cfo_kpi_card("MADS DSCR",
                :mads_dscr, ".2f", :rag_mads_dscr,
                :delta_mads_dscr, "+.2f",
                nothing; unit="×"),
        ]),

        # ── Row 3: Sparklines ──────────────────────────────────────────────
        row(class="q-gutter-xs", [
            _cfo_sparkline(:spark_margin_data, :spark_margin_layout),
            _cfo_sparkline(:spark_dcoh_data,   :spark_dcoh_layout),
            _cfo_sparkline(:spark_ratio_data,  :spark_ratio_layout),
            _cfo_sparkline(:spark_mads_data,   :spark_mads_layout),
            _cfo_sparkline(:spark_salary_data, :spark_salary_layout),
            _cfo_sparkline(:spark_census_data, :spark_census_layout),
        ]),

    ])  # end app_layout
end

# ─────────────────────────────────────────────────────────────────────────────
# KPI card helper
# ─────────────────────────────────────────────────────────────────────────────

function _cfo_kpi_card(title::String, value_field::Symbol, value_fmt::String,
                        rag_field::Symbol, delta_field::Symbol, delta_fmt::String,
                        peer_field::Union{Symbol,Nothing};
                        unit::String = "", lower_is_better::Bool = false)

    # Background class bound to RAG status
    bg_expr = "$(rag_field) === 'green' ? 'bg-green-1' : " *
              "$(rag_field) === 'amber' ? 'bg-orange-1' : 'bg-red-1'"

    # Delta arrow
    delta_color = lower_is_better ?
        "($(delta_field) <= 0 ? 'text-green-8' : 'text-red-8')" :
        "($(delta_field) >= 0 ? 'text-green-8' : 'text-red-8')"

    peer_section = isnothing(peer_field) ? [] : [
        Html.div(class="text-caption text-grey-6 q-mt-xs",
            var":text" => "'Peer P' + $(peer_field).toFixed(0)"),
        quasar(:linear_progress,
            value! => "$(peer_field) / 100",
            color  = "blue-3",
            style  = "height: 3px;"),
    ]

    cell(class="col", [
        card(var":class" => "\"q-pa-xs\" + (\" \" + $(bg_expr))", [
            card_section(class="q-pa-xs", [
                Html.div(class="text-caption text-grey-7 text-weight-medium", title),
                row(class="items-baseline q-mt-xs", [
                    cell(class="col-auto", [
                        Html.span(
                            class = "text-h6 text-weight-bold",
                            var":text" => "$(value_field).toFixed($(length(split(value_fmt,'f'))>1 ? split(value_fmt,'f')[end-1] : split(value_fmt,'%')[end-1]))" *
                                          (isempty(unit) ? "" : " + '$(unit)'"),
                        ),
                    ]),
                    cell(class="col q-ml-xs", [
                        Html.span(
                            var":class" => "\"text-caption \" + $(delta_color)",
                            var":text"  => "($(delta_field) >= 0 ? '▲' : '▼') + Math.abs($(delta_field)).toFixed(1)",
                        ),
                    ]),
                    cell(class="col-auto", [
                        quasar(:chip, dense=true, square=true,
                            var":color" => rag_field,
                            var":label" => "$(rag_field).toUpperCase()",
                            class       = "text-white text-caption"),
                    ]),
                ]),
                peer_section...,
            ]),
        ]),
    ])
end

# ─────────────────────────────────────────────────────────────────────────────
# Sparkline helper
# ─────────────────────────────────────────────────────────────────────────────

function _cfo_sparkline(data_field::Symbol, layout_field::Symbol)
    cell(class="col", [
        Html.div(style="height: 90px;", [
            plot(data_field; layout=layout_field,
                 config="{ displayModeBar: false, staticPlot: true, responsive: true }"),
        ]),
    ])
end
