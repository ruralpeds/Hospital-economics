"""
Stipple reactive model for Cost-Based Reimbursement Simulator.
Models step-down cost allocation and cost-to-charge ratios for 101% reimbursement.
"""
using Stipple, StippleUI, StipplePlotly


@app begin
    @in left_drawer_open::Bool = true
    # ── Department Cost Inputs (9 departments) ──────────────────────────
    @in cost_admin::Float64 = 2_100_000.0
    @in cost_nursing::Float64 = 3_380_000.0
    @in cost_ancillary::Float64 = 1_560_000.0
    @in cost_pharmacy::Float64 = 850_000.0
    @in cost_lab::Float64 = 950_000.0
    @in cost_imaging::Float64 = 1_200_000.0
    @in cost_ed::Float64 = 1_680_000.0
    @in cost_dietary::Float64 = 480_000.0
    @in cost_plant::Float64 = 720_000.0

    # ── Charge Inputs (6 revenue centers) ───────────────────────────────
    @in charges_inpatient::Float64 = 12_500_000.0
    @in charges_outpatient::Float64 = 8_200_000.0
    @in charges_ed::Float64 = 7_800_000.0
    @in charges_lab::Float64 = 2_800_000.0
    @in charges_imaging::Float64 = 3_400_000.0
    @in charges_pharmacy::Float64 = 1_900_000.0

    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out total_costs::Float64 = 12_920_000.0
    @out total_charges::Float64 = 36_600_000.0
    @out overall_ccr::Float64 = 0.353
    @out reimbursement_101pct::Float64 = 13_049_200.0
    @out reimbursement_gap::Float64 = 129_200.0

    @out step_down_table::Vector{Dict{String,Any}} = [
        Dict("dept"=>"Admin", "direct_cost"=>2_100, "allocated"=>0, "total"=>2_100, "method"=>"sq ft"),
        Dict("dept"=>"Plant", "direct_cost"=>720, "allocated"=>0, "total"=>720, "method"=>"sq ft"),
        Dict("dept"=>"Dietary", "direct_cost"=>480, "allocated"=>0, "total"=>480, "method"=>"meals"),
        Dict("dept"=>"Nursing", "direct_cost"=>3_380, "allocated"=>820, "total"=>4_200, "method"=>"patient days"),
        Dict("dept"=>"ED", "direct_cost"=>1_680, "allocated"=>350, "total"=>2_030, "method"=>"visits"),
        Dict("dept"=>"Lab", "direct_cost"=>950, "allocated"=>180, "total"=>1_130, "method"=>"tests"),
        Dict("dept"=>"Imaging", "direct_cost"=>1_200, "allocated"=>220, "total"=>1_420, "method"=>"procedures"),
        Dict("dept"=>"Pharmacy", "direct_cost"=>850, "allocated"=>160, "total"=>1_010, "method"=>"orders"),
        Dict("dept"=>"Ancillary", "direct_cost"=>1_560, "allocated"=>350, "total"=>1_910, "method"=>"direct"),
    ]

    @out ccr_by_dept::Vector{Dict{String,Any}} = [
        Dict("dept"=>"Inpatient", "cost"=>4_200, "charges"=>12_500, "ccr"=>0.336),
        Dict("dept"=>"Outpatient", "cost"=>2_600, "charges"=>8_200, "ccr"=>0.317),
        Dict("dept"=>"ED", "cost"=>2_030, "charges"=>7_800, "ccr"=>0.260),
        Dict("dept"=>"Lab", "cost"=>1_130, "charges"=>2_800, "ccr"=>0.404),
        Dict("dept"=>"Imaging", "cost"=>1_420, "charges"=>3_400, "ccr"=>0.418),
        Dict("dept"=>"Pharmacy", "cost"=>1_010, "charges"=>1_900, "ccr"=>0.532),
    ]

    # ── Chart Data ──────────────────────────────────────────────────────
    @out ccr_chart_data::Vector{PlotData} = [
        PlotData(
            x = ["Inpatient", "Outpatient", "ED", "Lab", "Imaging", "Pharmacy"],
            y = [33.6, 31.7, 26.0, 40.4, 41.8, 53.2],
            plot = StipplePlotly.Charts.PLOT_TYPE_BAR,
            name = "CCR (%)",
        ),
        PlotData(
            x = ["Inpatient", "Outpatient", "ED", "Lab", "Imaging", "Pharmacy"],
            y = [35.3, 35.3, 35.3, 35.3, 35.3, 35.3],
            plot = StipplePlotly.Charts.PLOT_TYPE_SCATTER,
            name = "Overall CCR",
            mode = "lines",
            line = PlotDataLine(dash="dash", color="red"),
        ),
    ]
    @out ccr_chart_layout::PlotLayout = PlotLayout(
        title = PlotLayoutTitle(text = "Cost-to-Charge Ratio by Department (%)"),
        xaxis = [PlotLayoutAxis(title = "Department")],
        yaxis = [PlotLayoutAxis(title = "CCR %")],
    )

    # ── Handlers ────────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false
            total_costs = cost_admin + cost_nursing + cost_ancillary + cost_pharmacy +
                          cost_lab + cost_imaging + cost_ed + cost_dietary + cost_plant
            total_charges = charges_inpatient + charges_outpatient + charges_ed +
                           charges_lab + charges_imaging + charges_pharmacy
            overall_ccr = round(total_costs / max(total_charges, 1), digits=3)
            reimbursement_101pct = round(total_costs * 1.01, digits=0)
            reimbursement_gap = reimbursement_101pct - total_costs

            dept_names = ["Inpatient", "Outpatient", "ED", "Lab", "Imaging", "Pharmacy"]
            dept_charges = [charges_inpatient, charges_outpatient, charges_ed,
                           charges_lab, charges_imaging, charges_pharmacy]
            dept_costs = [c * overall_ccr for c in dept_charges]
            dept_ccrs = [round(dc / max(ch, 1) * 100, digits=1) for (dc, ch) in zip(dept_costs, dept_charges)]

            ccr_chart_data = [
                PlotData(x=dept_names, y=dept_ccrs,
                    plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name="CCR (%)"),
                PlotData(x=dept_names, y=fill(round(overall_ccr * 100, digits=1), 6),
                    plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER, name="Overall CCR",
                    mode="lines", line=PlotDataLine(dash="dash", color="red")),
            ]
            @info "Cost reimbursement: CCR $(round(overall_ccr*100, digits=1))%, 101% = \$$(round(Int, reimbursement_101pct/1e6))M"
        end
    end
end

const cost_reimbursement_model = @init
