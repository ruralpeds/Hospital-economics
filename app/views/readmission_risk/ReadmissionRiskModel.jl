"""
Stipple reactive model for Readmission Risk (D-02).
LACE scoring, population tier distribution, HRRP penalty impact calculator.
"""
using Stipple, StippleUI, StipplePlotly
using ...FinanceEngine: lace_score, hrrp_cm_impact

@app begin
    # ── LACE individual scorer ─────────────────────────────────────────────
    @in los_days::Int          = 4
    @in ed_admission::Bool     = true
    @in charlson_index::Int    = 2
    @in ed_visits_6mo::Int     = 1
    @in score_patient::Bool    = false

    @out lace_total::Int       = 0
    @out lace_tier::String     = "—"
    @out lace_readmit_pct::Float64 = 0.0
    @out lace_color::String    = "grey"

    # ── HRRP Programme calculator ──────────────────────────────────────────
    @in hrrp_discharges::Int          = 620
    @in current_readmit_rate::Float64 = 17.5   # shown as %
    @in cm_effectiveness::Float64     = 20.0   # %
    @in cm_cost_annual::Float64       = 150_000.0
    @in base_payment::Float64         = 8_500_000.0
    @in hrrp_penalty_rate::Float64    = 1.2   # %
    @in run_hrrp::Bool                = false

    @out penalty_current::Float64     = 0.0
    @out penalty_projected::Float64   = 0.0
    @out penalty_reduction::Float64   = 0.0
    @out readmits_prevented::Int      = 0
    @out net_benefit::Float64         = 0.0
    @out cm_roi_pct::Float64          = 0.0
    @out cm_recommended::Bool         = false

    # ── Risk tier distribution chart ───────────────────────────────────────
    @out tier_chart_data::Vector{PlotData} = [PlotData(
        labels=["Low Risk (<5)", "Moderate (5-9)", "High Risk (≥10)"],
        values=[55.0, 27.0, 18.0],
        plot="pie",
        marker=Dict("colors"=>["#22c55e","#f59e0b","#ef4444"]),
    )]
    @out tier_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Population Risk Distribution"),
        showlegend=true,
    )

    @in errors::Vector{String} = String[]

    @onchange score_patient begin
        if score_patient
            score_patient = false
            r = lace_score(
                length_of_stay_days = los_days,
                acuity_ed_admission = ed_admission,
                charlson_index      = charlson_index,
                ed_visits_6mo       = ed_visits_6mo,
            )
            lace_total     = r.total_score
            lace_readmit_pct = r.approx_30day_readmission_pct
            lace_tier      = r.risk_tier == :high ? "HIGH RISK" :
                             r.risk_tier == :moderate ? "MODERATE RISK" : "LOW RISK"
            lace_color     = r.risk_tier == :high ? "red" :
                             r.risk_tier == :moderate ? "orange" : "green"
        end
    end

    @onchange run_hrrp begin
        if run_hrrp
            run_hrrp = false
            errors = String[]
            try
                r = hrrp_cm_impact(
                    annual_discharges         = hrrp_discharges,
                    current_readmission_rate  = current_readmit_rate / 100.0,
                    cm_programme_effectiveness = cm_effectiveness / 100.0,
                    cm_programme_cost_annual  = cm_cost_annual,
                    hospital_base_payment     = base_payment,
                    hrrp_penalty_rate         = hrrp_penalty_rate / 100.0,
                )
                penalty_current    = r.current_hrrp_penalty
                penalty_projected  = r.projected_hrrp_penalty
                penalty_reduction  = r.penalty_reduction
                readmits_prevented = r.readmissions_prevented
                net_benefit        = r.net_annual_benefit
                cm_roi_pct         = r.roi_pct
                cm_recommended     = r.recommended
            catch e
                errors = ["Error: $(sprint(showerror, e))"]
            end
        end
    end
end

const readmission_risk_model = @init
