"""
Stipple reactive model for Physician Compensation Analysis.
Evaluates comp/wRVU productivity, flags outliers, and provides cohort summaries.
Delegates to RuralHospitalSim.calculate_physician_compensation() and physician_cohort_analysis().
"""
using Stipple, StippleUI, StipplePlotly

using ...RuralHospitalSim: calculate_physician_compensation, physician_cohort_analysis,
    PhysicianProfile, CompensationResult


@app begin
    @in left_drawer_open::Bool = true

    # ── Physician profile inputs (up to 6 rows for interactive entry) ──
    @in phys1_name::String = "Dr. Smith"
    @in phys1_specialty::String = "Family Medicine"
    @in phys1_wrvu::Float64 = 4800.0
    @in phys1_benchmark::Float64 = 5000.0
    @in phys1_salary::Float64 = 250_000.0
    @in phys1_bonus_pct::Float64 = 0.05

    @in phys2_name::String = "Dr. Jones"
    @in phys2_specialty::String = "Family Medicine"
    @in phys2_wrvu::Float64 = 5200.0
    @in phys2_benchmark::Float64 = 5000.0
    @in phys2_salary::Float64 = 260_000.0
    @in phys2_bonus_pct::Float64 = 0.08

    @in phys3_name::String = "Dr. Lee"
    @in phys3_specialty::String = "Cardiology"
    @in phys3_wrvu::Float64 = 7500.0
    @in phys3_benchmark::Float64 = 7000.0
    @in phys3_salary::Float64 = 450_000.0
    @in phys3_bonus_pct::Float64 = 0.10

    @in phys4_name::String = "Dr. Patel"
    @in phys4_specialty::String = "Cardiology"
    @in phys4_wrvu::Float64 = 6800.0
    @in phys4_benchmark::Float64 = 7000.0
    @in phys4_salary::Float64 = 480_000.0
    @in phys4_bonus_pct::Float64 = 0.03

    @in phys5_name::String = ""
    @in phys5_specialty::String = ""
    @in phys5_wrvu::Float64 = 0.0
    @in phys5_benchmark::Float64 = 0.0
    @in phys5_salary::Float64 = 0.0
    @in phys5_bonus_pct::Float64 = 0.0

    @in phys6_name::String = ""
    @in phys6_specialty::String = ""
    @in phys6_wrvu::Float64 = 0.0
    @in phys6_benchmark::Float64 = 0.0
    @in phys6_salary::Float64 = 0.0
    @in phys6_bonus_pct::Float64 = 0.0

    @in recalculate::Bool = false

    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    # ── Outputs ────────────────────────────────────────────────────
    @out results_table::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out cohort_summaries::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out total_physicians::Int = 0
    @out total_outliers::Int = 0
    @out avg_comp_per_wrvu::String = "\$0.00"
    @out avg_productivity_pct::String = "0.0%"

    @out comp_chart_data::Vector{PlotData} = PlotData[]
    @out comp_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Physician Compensation vs wRVU"),
        xaxis=[PlotLayoutAxis(title="Physician")],
        yaxis=[PlotLayoutAxis(title="Value")],
    )

    # ── Handler ────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false

            try
                # Build profiles from non-empty rows
                profiles = PhysicianProfile[]
                for (name, spec, wrvu, bench, sal, bonus) in [
                    (phys1_name, phys1_specialty, phys1_wrvu, phys1_benchmark, phys1_salary, phys1_bonus_pct),
                    (phys2_name, phys2_specialty, phys2_wrvu, phys2_benchmark, phys2_salary, phys2_bonus_pct),
                    (phys3_name, phys3_specialty, phys3_wrvu, phys3_benchmark, phys3_salary, phys3_bonus_pct),
                    (phys4_name, phys4_specialty, phys4_wrvu, phys4_benchmark, phys4_salary, phys4_bonus_pct),
                    (phys5_name, phys5_specialty, phys5_wrvu, phys5_benchmark, phys5_salary, phys5_bonus_pct),
                    (phys6_name, phys6_specialty, phys6_wrvu, phys6_benchmark, phys6_salary, phys6_bonus_pct),
                ]
                    if !isempty(strip(name)) && !isempty(strip(spec)) && sal > 0.0
                        push!(profiles, PhysicianProfile(
                            name=name, specialty=spec,
                            wrvu_actual=wrvu, wrvu_benchmark=bench,
                            base_salary=sal, quality_bonus_pct=bonus))
                    end
                end

                if isempty(profiles)
                    results_table = Dict{String,Any}[]
                    cohort_summaries = Dict{String,Any}[]
                    total_physicians = 0
                    total_outliers = 0
                    avg_comp_per_wrvu = "N/A"
                    avg_productivity_pct = "N/A"
                    return
                end

                # Run compensation analysis
                comp_results = calculate_physician_compensation(profiles)
                cohorts = physician_cohort_analysis(profiles)

                # Build results table
                results_table = [Dict{String,Any}(
                    "name" => r.name,
                    "specialty" => r.specialty,
                    "total_comp" => round(Int, r.total_comp),
                    "comp_per_wrvu" => round(r.comp_per_wrvu, digits=2),
                    "productivity_pct" => round(r.productivity_pct, digits=1),
                    "benchmark_ratio" => round(r.comp_to_benchmark_ratio, digits=2),
                    "outlier" => r.outlier_flag,
                ) for r in comp_results]

                # Build cohort summaries
                cohort_summaries = [Dict{String,Any}(
                    "specialty" => c.specialty,
                    "n_physicians" => c.n_physicians,
                    "mean_total_comp" => round(Int, c.mean_total_comp),
                    "mean_comp_per_wrvu" => round(c.mean_comp_per_wrvu, digits=2),
                    "mean_productivity_pct" => round(c.mean_productivity_pct, digits=1),
                    "total_wrvu" => round(Int, c.total_wrvu),
                    "total_compensation" => round(Int, c.total_compensation),
                    "n_outliers" => c.n_outliers,
                ) for c in cohorts]

                total_physicians = length(comp_results)
                total_outliers = count(r -> r.outlier_flag, comp_results)
                cpw_vals = [r.comp_per_wrvu for r in comp_results if r.comp_per_wrvu > 0]
                avg_comp_per_wrvu = isempty(cpw_vals) ? "N/A" :
                    "\$$(round(sum(cpw_vals) / length(cpw_vals), digits=2))"
                prod_vals = [r.productivity_pct for r in comp_results]
                avg_productivity_pct = "$(round(sum(prod_vals) / length(prod_vals), digits=1))%"

                # Build chart — grouped bar: Total Comp and wRVU
                names = [r.name for r in comp_results]
                comps = [r.total_comp / 1000.0 for r in comp_results]
                wrvus = [p.wrvu_actual for p in profiles]
                bar_colors = [r.outlier_flag ? "#F44336" : "#2196F3" for r in comp_results]

                comp_chart_data = [
                    PlotData(x=names, y=comps, name="Total Comp (\$K)",
                        plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        marker=Dict("color" => bar_colors)),
                    PlotData(x=names, y=wrvus, name="wRVU",
                        plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        marker=Dict("color" => "#FF9800")),
                ]
                comp_chart_layout = PlotLayout(
                    title=PlotLayoutTitle(text="Compensation vs Productivity by Physician"),
                    xaxis=[PlotLayoutAxis(title="Physician")],
                    yaxis=[PlotLayoutAxis(title="Value")],
                    barmode="group",
                )

                @info "Physician comp analysis: $(total_physicians) physicians, $(total_outliers) outliers"
            catch err
                total_physicians = 0
                total_outliers = 0
                avg_comp_per_wrvu = "Error"
                avg_productivity_pct = sprint(showerror, err)
                @error "Physician comp error" exception=(err, catch_backtrace())
            end
        end
    end
end

const physician_comp_model = @init
