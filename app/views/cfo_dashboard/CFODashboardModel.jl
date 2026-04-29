"""
    CFODashboardModel.jl — CFO 1-Pager Stipple Reactive Model (MBA Gap F-03)

A single-screen, weekly/monthly CFO dashboard providing:
- 6 KPI cards with RAG (Red/Amber/Green) status and period-over-period delta
- 6 sparkline charts (12-week mini trend lines, < 500ms load target)
- Exception flags panel (auto-generated from threshold breaches)
- Peer benchmark percentile indicators
- One-click CSV export

Design philosophy:
- Loads in < 500ms: all data pre-aggregated server-side, no lazy loading
- Optimised for a single screen (no scroll): CFO sees everything at-a-glance
- Self-updating: @onchange fiscal_week triggers full refresh
- Mobile-safe layout: responsive Quasar grid
"""

using Stipple, StippleUI, StipplePlotly

# ─────────────────────────────────────────────────────────────────────────────
# RAG Threshold Configuration
# ─────────────────────────────────────────────────────────────────────────────

"""
    RAGThresholds

Green/Amber/Red thresholds for each KPI. All values in native units.
Direction: :higher_is_better or :lower_is_better.
"""
const CFO_RAG_THRESHOLDS = (
    operating_margin    = (green=0.03,  amber=0.0,   direction=:higher),
    days_cash_on_hand   = (green=55.0,  amber=30.0,  direction=:higher),
    current_ratio       = (green=1.8,   amber=1.2,   direction=:higher),
    debt_to_cap         = (green=0.45,  amber=0.60,  direction=:lower),
    salary_to_revenue   = (green=0.50,  amber=0.58,  direction=:lower),
    mads_dscr           = (green=1.5,   amber=1.1,   direction=:higher),
)

"""
    rag_status(value, thresholds, direction) -> String

Return \"green\", \"amber\", or \"red\" for a KPI value against its thresholds.
"""
function _rag(value::Float64, green::Float64, amber::Float64, direction::Symbol)::String
    if direction == :higher
        value >= green ? "green" : value >= amber ? "amber" : "red"
    else
        value <= green ? "green" : value <= amber ? "amber" : "red"
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Helper: build a sparkline PlotData from a vector of values
# ─────────────────────────────────────────────────────────────────────────────

function _sparkline(values::Vector{Float64}, labels::Vector{String},
                    name::String, color::String)::PlotData
    PlotData(
        x    = labels,
        y    = values,
        plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
        name = name,
        mode = "lines",
        line = Dict("color" => color, "width" => 2),
    )
end

function _sparkline_layout(title::String)::PlotLayout
    PlotLayout(
        title         = PlotLayoutTitle(text=title, font=Dict("size"=>11)),
        margin        = Dict("t"=>28, "b"=>8, "l"=>40, "r"=>8),
        height        = 80,
        showlegend    = false,
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        xaxis         = [PlotLayoutAxis(showticklabels=false, showgrid=false, zeroline=false)],
        yaxis         = [PlotLayoutAxis(showgrid=false, zeroline=false, tickformat=".1%")],
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# 12-week stub data generator (replaced with real data in production)
# ─────────────────────────────────────────────────────────────────────────────

function _week_labels(n::Int=12)::Vector{String}
    ["W-$(n-i)" for i in n-1:-1:0]
end

# ─────────────────────────────────────────────────────────────────────────────
# Stipple @app model
# ─────────────────────────────────────────────────────────────────────────────

@app begin
    # ── Controls ────────────────────────────────────────────────────────
    @in left_drawer_open::Bool     = false
    @in fiscal_week::String        = string(Dates.today())
    @in refresh::Bool              = false
    @in do_csv::Bool               = false
    @in do_xlsx::Bool              = false
    @in errors::Vector{String}     = String[]

    # ── Hospital identity ────────────────────────────────────────────────
    @out hospital_name::String     = "Prairie View Community Hospital"
    @out hospital_type::String     = "Critical Access Hospital"
    @out fiscal_period::String     = "Week of $(Dates.today())"

    # ── KPI Values ──────────────────────────────────────────────────────
    @out operating_margin::Float64       = -0.038
    @out days_cash_on_hand::Float64      = 48.2
    @out current_ratio::Float64          = 1.65
    @out debt_to_cap::Float64            = 0.52
    @out salary_to_revenue::Float64      = 0.527
    @out mads_dscr::Float64              = 1.18

    # ── Week-over-week deltas ────────────────────────────────────────────
    @out delta_operating_margin::Float64  = 0.001
    @out delta_days_cash::Float64         = -2.1
    @out delta_current_ratio::Float64     = -0.04
    @out delta_debt_to_cap::Float64       = 0.005
    @out delta_salary::Float64            = 0.003
    @out delta_mads_dscr::Float64         = -0.02

    # ── RAG Status ───────────────────────────────────────────────────────
    @out rag_operating_margin::String    = "red"
    @out rag_days_cash::String           = "amber"
    @out rag_current_ratio::String       = "amber"
    @out rag_debt_to_cap::String         = "amber"
    @out rag_salary::String              = "amber"
    @out rag_mads_dscr::String           = "amber"

    # ── Exception flags ──────────────────────────────────────────────────
    @out exception_flags::Vector{String} = [
        "⚠️  Operating margin -3.8% → below amber threshold (0.0%)",
        "⚠️  Days cash on hand 48.2 → below green threshold (55 days)",
        "⚠️  MADS DSCR 1.18× → within 8 pts of covenant floor (1.10×)",
    ]
    @out n_red_flags::Int        = 1
    @out n_amber_flags::Int      = 4
    @out n_green_flags::Int      = 1

    # ── Peer Benchmarks (Flex Monitoring percentile) ──────────────────────
    @out peer_operating_margin_pct::Float64  = 28.0
    @out peer_dcoh_pct::Float64              = 42.0
    @out peer_current_ratio_pct::Float64     = 55.0
    @out peer_debt_to_cap_pct::Float64       = 48.0

    # ── Sparkline data (12 weeks) ────────────────────────────────────────
    @out spark_labels::Vector{String} = _week_labels(12)

    @out spark_margin_data::Vector{PlotData} = [
        _sparkline(
            [-0.028,-0.030,-0.031,-0.033,-0.033,-0.034,-0.035,-0.036,-0.036,-0.037,-0.038,-0.038],
            _week_labels(12), "Op Margin", "#ef4444"),
    ]
    @out spark_margin_layout::PlotLayout = _sparkline_layout("Op Margin")

    @out spark_dcoh_data::Vector{PlotData} = [
        _sparkline(
            [62.1,60.5,58.8,57.2,56.1,54.9,53.8,52.4,51.0,49.8,48.9,48.2],
            _week_labels(12), "Days Cash", "#f59e0b"),
    ]
    @out spark_dcoh_layout::PlotLayout = let
        l = _sparkline_layout("Days Cash")
        PlotLayout(; pairs(l)..., yaxis=[PlotLayoutAxis(showgrid=false, zeroline=false, tickformat=".0f")])
    end

    @out spark_ratio_data::Vector{PlotData} = [
        _sparkline(
            [1.82,1.80,1.78,1.76,1.75,1.74,1.72,1.71,1.70,1.68,1.66,1.65],
            _week_labels(12), "Current Ratio", "#f59e0b"),
    ]
    @out spark_ratio_layout::PlotLayout = let
        l = _sparkline_layout("Current Ratio")
        PlotLayout(; pairs(l)..., yaxis=[PlotLayoutAxis(showgrid=false, zeroline=false, tickformat=".2f")])
    end

    @out spark_mads_data::Vector{PlotData} = [
        _sparkline(
            [1.32,1.30,1.28,1.27,1.26,1.25,1.24,1.22,1.21,1.20,1.19,1.18],
            _week_labels(12), "MADS DSCR", "#f59e0b"),
    ]
    @out spark_mads_layout::PlotLayout = let
        l = _sparkline_layout("MADS DSCR")
        PlotLayout(; pairs(l)..., yaxis=[PlotLayoutAxis(showgrid=false, zeroline=false, tickformat=".2f")])
    end

    @out spark_salary_data::Vector{PlotData} = [
        _sparkline(
            [0.510,0.512,0.515,0.518,0.520,0.521,0.523,0.524,0.525,0.526,0.527,0.527],
            _week_labels(12), "Salary %", "#f59e0b"),
    ]
    @out spark_salary_layout::PlotLayout = _sparkline_layout("Salary/Revenue")

    @out spark_census_data::Vector{PlotData} = [
        _sparkline(
            [10.2,9.8,10.5,11.1,10.8,9.9,10.3,9.7,10.1,9.5,9.8,10.4],
            _week_labels(12), "ADC", "#22c55e"),
    ]
    @out spark_census_layout::PlotLayout = let
        l = _sparkline_layout("Avg Daily Census")
        PlotLayout(; pairs(l)..., yaxis=[PlotLayoutAxis(showgrid=false, zeroline=false, tickformat=".1f")])
    end

    # ── Reactive handlers ────────────────────────────────────────────────
    @onchange fiscal_week, refresh begin
        # In production: reload from database for selected fiscal_week
        # Update RAG status
        rag_operating_margin = _rag(operating_margin, CFO_RAG_THRESHOLDS.operating_margin.green,
                                    CFO_RAG_THRESHOLDS.operating_margin.amber, :higher)
        rag_days_cash = _rag(days_cash_on_hand, CFO_RAG_THRESHOLDS.days_cash_on_hand.green,
                             CFO_RAG_THRESHOLDS.days_cash_on_hand.amber, :higher)
        rag_current_ratio = _rag(current_ratio, CFO_RAG_THRESHOLDS.current_ratio.green,
                                 CFO_RAG_THRESHOLDS.current_ratio.amber, :higher)
        rag_debt_to_cap = _rag(debt_to_cap, CFO_RAG_THRESHOLDS.debt_to_cap.green,
                               CFO_RAG_THRESHOLDS.debt_to_cap.amber, :lower)
        rag_salary = _rag(salary_to_revenue, CFO_RAG_THRESHOLDS.salary_to_revenue.green,
                          CFO_RAG_THRESHOLDS.salary_to_revenue.amber, :lower)
        rag_mads_dscr = _rag(mads_dscr, CFO_RAG_THRESHOLDS.mads_dscr.green,
                             CFO_RAG_THRESHOLDS.mads_dscr.amber, :higher)

        # Rebuild exception flags
        flags = String[]
        for (name, val, rag_val, threshold_desc) in [
            ("Operating margin", operating_margin*100, rag_operating_margin,
             "amber=0.0%, green=3.0%"),
            ("Days cash on hand", days_cash_on_hand, rag_days_cash,
             "amber=30d, green=55d"),
            ("MADS DSCR", mads_dscr, rag_mads_dscr,
             "amber=1.10×, green=1.50×; covenant floor=1.10×"),
        ]
            if rag_val == "red"
                push!(flags, "🔴  $name → RED ($threshold_desc)")
            elseif rag_val == "amber"
                push!(flags, "🟡  $name → AMBER ($threshold_desc)")
            end
        end
        exception_flags = flags
        n_red_flags   = count(f -> startswith(f, "🔴"), flags)
        n_amber_flags = count(f -> startswith(f, "🟡"), flags)
        n_green_flags = 6 - n_red_flags - n_amber_flags
    end
end
