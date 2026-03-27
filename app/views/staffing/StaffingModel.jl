"""
Stipple reactive model for Staffing Optimizer.
Analyzes staffing levels, benchmarks, and labor cost optimization.
"""
using Stipple, StippleUI, StipplePlotly

@appname StaffingApp

@app begin
    # ── Selection ────────────────────────────────────────────────────────
    @in selected_hospital_id::Int = 1
    @out hospital_options::Vector{Dict{String,Any}} = [
        Dict("label"=>"Prairie View Community Hospital", "value"=>1),
        Dict("label"=>"Mountain Valley Medical Center", "value"=>2),
        Dict("label"=>"Delta Regional Hospital", "value"=>3),
        Dict("label"=>"High Plains Health", "value"=>4),
    ]
    @in run_optimization::Bool = false
    @in optimization_target::String = "balanced"
    @out target_options::Vector{Dict{String,String}} = [
        Dict("label"=>"Balanced (quality + cost)", "value"=>"balanced"),
        Dict("label"=>"Maximum Cost Reduction", "value"=>"cost"),
        Dict("label"=>"Quality Focused", "value"=>"quality"),
    ]

    # ── Current Staffing Overview ────────────────────────────────────────
    @out total_fte::Float64 = 142.5
    @out total_labor_cost::Float64 = 9_761_250.0
    @out labor_cost_pct_revenue::Float64 = 0.527
    @out cost_per_fte::Float64 = 68_500.0
    @out vacancy_rate::Float64 = 0.12
    @out turnover_rate::Float64 = 0.22
    @out contract_labor_pct::Float64 = 0.08
    @out overtime_pct::Float64 = 0.065
    @out fte_per_aob::Float64 = 5.8

    # ── Department Breakdown ─────────────────────────────────────────────
    @out departments::Vector{Dict{String,Any}} = [
        Dict("name"=>"Nursing", "current_fte"=>52.0, "benchmark_fte"=>48.0,
             "variance"=>4.0, "cost"=>3_380_000, "benchmark_cost"=>3_120_000,
             "vacancy"=>0.15, "turnover"=>0.28, "contract_pct"=>0.12),
        Dict("name"=>"Administration", "current_fte"=>18.5, "benchmark_fte"=>15.0,
             "variance"=>3.5, "cost"=>1_295_000, "benchmark_cost"=>1_050_000,
             "vacancy"=>0.05, "turnover"=>0.10, "contract_pct"=>0.0),
        Dict("name"=>"Ancillary (Lab/Imaging/Pharmacy)", "current_fte"=>24.0, "benchmark_fte"=>22.0,
             "variance"=>2.0, "cost"=>1_560_000, "benchmark_cost"=>1_430_000,
             "vacancy"=>0.08, "turnover"=>0.15, "contract_pct"=>0.05),
        Dict("name"=>"Support Services", "current_fte"=>28.0, "benchmark_fte"=>26.0,
             "variance"=>2.0, "cost"=>1_540_000, "benchmark_cost"=>1_430_000,
             "vacancy"=>0.18, "turnover"=>0.35, "contract_pct"=>0.10),
        Dict("name"=>"Physicians/Providers", "current_fte"=>12.0, "benchmark_fte"=>12.0,
             "variance"=>0.0, "cost"=>3_420_000, "benchmark_cost"=>3_420_000,
             "vacancy"=>0.08, "turnover"=>0.05, "contract_pct"=>0.15),
        Dict("name"=>"Emergency Department", "current_fte"=>8.0, "benchmark_fte"=>8.0,
             "variance"=>0.0, "cost"=>624_000, "benchmark_cost"=>624_000,
             "vacancy"=>0.10, "turnover"=>0.20, "contract_pct"=>0.20),
    ]

    # ── Optimization Results ─────────────────────────────────────────────
    @out optimized_total_fte::Float64 = 131.0
    @out fte_reduction::Float64 = 11.5
    @out annual_savings::Float64 = 787_750.0
    @out savings_pct_labor::Float64 = 0.081
    @out new_labor_cost_pct::Float64 = 0.484
    @out implementation_cost::Float64 = 125_000.0
    @out payback_months::Int = 2
    @out quality_impact::String = "minimal"
    @out optimization_status::String = ""

    @out optimization_actions::Vector{Dict{String,Any}} = [
        Dict("department"=>"Nursing", "action"=>"Reduce by 4.0 FTE through attrition",
             "savings"=>274_000, "timeline"=>"6-12 months", "risk"=>"low"),
        Dict("department"=>"Administration", "action"=>"Consolidate roles, reduce by 3.5 FTE",
             "savings"=>245_000, "timeline"=>"3-6 months", "risk"=>"low"),
        Dict("department"=>"Ancillary", "action"=>"Cross-train staff, reduce by 2.0 FTE",
             "savings"=>130_000, "timeline"=>"6-12 months", "risk"=>"medium"),
        Dict("department"=>"Support Services", "action"=>"Reduce by 2.0 FTE, outsource select functions",
             "savings"=>110_000, "timeline"=>"3-6 months", "risk"=>"low"),
        Dict("department"=>"Contract Labor", "action"=>"Reduce contract labor from 8% to 5%",
             "savings"=>28_750, "timeline"=>"3-9 months", "risk"=>"medium"),
    ]

    # ── Charts ───────────────────────────────────────────────────────────
    @out staffing_comparison_data::Vector{PlotData} = [
        PlotData(
            x=["Nursing", "Admin", "Ancillary", "Support", "Physicians", "ED"],
            y=[52.0, 18.5, 24.0, 28.0, 12.0, 8.0],
            plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
            name="Current FTE"),
        PlotData(
            x=["Nursing", "Admin", "Ancillary", "Support", "Physicians", "ED"],
            y=[48.0, 15.0, 22.0, 26.0, 12.0, 8.0],
            plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
            name="Benchmark FTE"),
        PlotData(
            x=["Nursing", "Admin", "Ancillary", "Support", "Physicians", "ED"],
            y=[48.0, 15.0, 22.0, 26.0, 12.0, 8.0],
            plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
            name="Optimized FTE"),
    ]
    @out staffing_comparison_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Staffing by Department: Current vs Benchmark vs Optimized"),
        barmode="group",
        xaxis=[PlotLayoutAxis(title="Department")],
        yaxis=[PlotLayoutAxis(title="FTE")],
    )

    @out labor_cost_breakdown_data::Vector{PlotData} = [
        PlotData(
            values=[3380, 1295, 1560, 1540, 3420, 624],
            labels=["Nursing", "Admin", "Ancillary", "Support", "Physicians", "ED"],
            plot=StipplePlotly.Charts.PLOT_TYPE_PIE,
            hole=0.4, name="Labor Cost Distribution"),
    ]
    @out labor_cost_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Labor Cost Distribution by Department (\$K)"),
    )

    @out vacancy_turnover_data::Vector{PlotData} = [
        PlotData(
            x=["Nursing", "Admin", "Ancillary", "Support", "Physicians", "ED"],
            y=[15, 5, 8, 18, 8, 10],
            plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
            name="Vacancy Rate (%)"),
        PlotData(
            x=["Nursing", "Admin", "Ancillary", "Support", "Physicians", "ED"],
            y=[28, 10, 15, 35, 5, 20],
            plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
            name="Turnover Rate (%)"),
    ]
    @out vacancy_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Vacancy and Turnover Rates by Department (%)"),
        barmode="group",
        xaxis=[PlotLayoutAxis(title="Department")],
        yaxis=[PlotLayoutAxis(title="%")],
    )

    # ── Handlers ─────────────────────────────────────────────────────────
    @onchange run_optimization begin
        if run_optimization
            run_optimization = false
            @info "Running staffing optimization (target: $optimization_target) for hospital $selected_hospital_id"

            if optimization_target == "cost"
                fte_reduction = 15.0
                annual_savings = 1_027_500.0
                quality_impact = "moderate"
            elseif optimization_target == "quality"
                fte_reduction = 6.0
                annual_savings = 411_000.0
                quality_impact = "positive"
            else
                fte_reduction = 11.5
                annual_savings = 787_750.0
                quality_impact = "minimal"
            end
            optimized_total_fte = total_fte - fte_reduction
            savings_pct_labor = annual_savings / total_labor_cost
            new_labor_cost_pct = (total_labor_cost - annual_savings) / (total_labor_cost / labor_cost_pct_revenue)
            payback_months = max(1, round(Int, implementation_cost / (annual_savings / 12)))
            optimization_status = "Optimization complete — $(fte_reduction) FTE reduction, \$$(round(Int, annual_savings/1000))K annual savings"
        end
    end

    @onchange selected_hospital_id begin
        @info "Loading staffing data for hospital $selected_hospital_id"
    end
end

const staffing_model = @init
