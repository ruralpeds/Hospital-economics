"""REH Conversion Decision Model (B-04)."""
using Stipple, StippleUI, StipplePlotly
using ...FinanceEngine: CAHFinancialProfile, analyze_cah_to_reh_conversion, REH_MONTHLY_FACILITY_PAYMENT_FY2026

@app begin
    @in annual_ed_visits::Int          = 4_200
    @in annual_ip_discharges::Int      = 310
    @in cah_revenue::Float64           = 8_500_000.0
    @in cah_expenses::Float64          = 8_650_000.0
    @in opps_rate_per_visit::Float64   = 185.0
    @in inpatient_revenue_pct::Float64 = 35.0
    @in run_analysis::Bool             = false

    @out cah_margin::Float64           = 0.0
    @out reh_facility_payment::Float64 = REH_MONTHLY_FACILITY_PAYMENT_FY2026 * 12
    @out reh_total_revenue::Float64    = 0.0
    @out reh_margin::Float64           = 0.0
    @out annual_revenue_delta::Float64 = 0.0
    @out npv_5yr::Float64              = 0.0
    @out recommendation::String        = "Click Analyse to run"
    @out recommendation_color::String  = "grey"
    @out community_note::String        = ""
    @out breakeven_ed_visits::Int      = 0

    @out comparison_chart::Vector{PlotData} = []
    @out comparison_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="CAH vs REH Revenue Comparison"),
        barmode="group", yaxis=[PlotLayoutAxis(title="USD (M)")])

    @in errors::Vector{String} = String[]

    @onchange run_analysis begin
        if run_analysis
            run_analysis = false
            errors = String[]
            try
                profile = CAHFinancialProfile(
                    hospital_name="Hospital",
                    annual_ed_visits=annual_ed_visits,
                    annual_inpatient_discharges=annual_ip_discharges,
                    net_patient_revenue_cah=cah_revenue,
                    total_operating_expenses=cah_expenses,
                    opps_rate_per_ed_visit=opps_rate_per_visit,
                    inpatient_revenue_pct=inpatient_revenue_pct/100.0,
                )
                r = analyze_cah_to_reh_conversion(profile)
                cah_margin           = round(r.cah_operating_margin*100, digits=1)
                reh_facility_payment = r.reh_facility_payment_annual
                reh_total_revenue    = r.reh_total_revenue
                reh_margin           = round(r.reh_operating_margin*100, digits=1)
                annual_revenue_delta = r.annual_revenue_delta
                npv_5yr              = r.npv_conversion_5yr
                breakeven_ed_visits  = r.breakeven_ed_visits
                community_note       = r.inpatient_community_impact
                rec_sym = r.recommendation
                recommendation = rec_sym == :convert_now ? "CONVERT TO REH NOW" :
                    rec_sym == :wait ? "WAIT — DEFER DECISION" :
                    rec_sym == :stay_cah ? "MAINTAIN CAH STATUS" : "CLOSURE RISK — SEEK HELP"
                recommendation_color = rec_sym == :convert_now ? "green" :
                    rec_sym == :wait ? "orange" : rec_sym == :stay_cah ? "blue" : "red"
                comparison_chart = [
                    PlotData(x=["Net Revenue","Expenses","Net Income"],
                        y=[cah_revenue/1e6, cah_expenses/1e6, (cah_revenue-cah_expenses)/1e6],
                        plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="CAH",
                        marker=Dict("color"=>"#6366f1")),
                    PlotData(x=["Net Revenue","Expenses","Net Income"],
                        y=[reh_total_revenue/1e6, r.reh_operating_expenses/1e6,
                           (reh_total_revenue-r.reh_operating_expenses)/1e6],
                        plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="REH",
                        marker=Dict("color"=>"#22c55e")),
                ]
            catch e; errors = ["$(sprint(showerror,e))"]; end
        end
    end
end
const reh_conversion_model = @init
