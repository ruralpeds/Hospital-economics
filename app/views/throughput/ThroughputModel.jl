"""Theory of Constraints / Throughput Accounting Model (C-04)."""
using Stipple, StippleUI, StipplePlotly
using ...FinanceEngine: ThroughputInputs, compute_throughput_metrics, HospitalResource, identify_constraint

@app begin
    @in annual_revenue::Float64   = 8_500_000.0
    @in tvc::Float64              = 2_800_000.0
    @in operating_expense::Float64 = 5_400_000.0
    @in investment::Float64       = 12_000_000.0
    @in recalculate::Bool         = false

    @out throughput::Float64      = 0.0
    @out net_profit::Float64      = 0.0
    @out roi::Float64             = 0.0
    @out productivity::Float64    = 0.0
    @out investment_turns::Float64 = 0.0
    @out tvc_ratio::Float64       = 0.0

    @in ed_available::Float64     = 4_200.0
    @in ed_demanded::Float64      = 4_800.0
    @in or_available::Float64     = 1_200.0
    @in or_demanded::Float64      = 900.0
    @in lab_available::Float64    = 50_000.0
    @in lab_demanded::Float64     = 38_000.0
    @in run_constraint::Bool      = false

    @out constraint_name::String  = "—"
    @out constraint_util::Float64 = 0.0
    @out exploit_rec::String      = ""
    @out elevate_rec::String      = ""

    @out util_chart::Vector{PlotData} = []
    @out util_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Resource Utilisation"),
        yaxis=[PlotLayoutAxis(title="Utilisation %")])

    @in errors::Vector{String} = String[]

    @onchange recalculate begin
        if recalculate
            recalculate = false
            m = compute_throughput_metrics(ThroughputInputs(
                name="Hospital", annual_revenue=annual_revenue,
                truly_variable_costs=tvc, operating_expense=operating_expense,
                investment=investment))
            throughput       = m.throughput
            net_profit       = m.net_profit
            roi              = round(m.roi*100, digits=2)
            productivity     = round(m.productivity, digits=3)
            investment_turns = round(m.investment_turns, digits=3)
            tvc_ratio        = round(m.tvc_ratio*100, digits=1)
        end
    end

    @onchange run_constraint begin
        if run_constraint
            run_constraint = false
            resources = [
                HospitalResource(id=:ed,  name="Emergency Dept", available_capacity_units=ed_available,  demanded_capacity_units=ed_demanded),
                HospitalResource(id=:or,  name="Operating Room",  available_capacity_units=or_available,  demanded_capacity_units=or_demanded),
                HospitalResource(id=:lab, name="Laboratory",       available_capacity_units=lab_available, demanded_capacity_units=lab_demanded),
            ]
            r = identify_constraint(resources)
            constraint_name = r.constraint.name
            constraint_util = round(get(r.utilisation_rates, r.constraint.id, 0.0)*100, digits=1)
            exploit_rec = isempty(r.exploitation_recommendations) ? "" : r.exploitation_recommendations[1]
            elevate_rec = isempty(r.elevation_options) ? "" : r.elevation_options[1]
            names  = [res.name for res in resources]
            utils  = [round(get(r.utilisation_rates, res.id, 0.0)*100, digits=1) for res in resources]
            colors = [u >= 100 ? "#ef4444" : u >= 85 ? "#f59e0b" : "#22c55e" for u in utils]
            util_chart = [PlotData(x=names, y=utils, plot="bar", marker=Dict("color"=>colors))]
        end
    end
end
const throughput_model = @init
