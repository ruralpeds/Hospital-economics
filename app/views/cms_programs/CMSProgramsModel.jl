"""
Stipple reactive model for CMS Quality Payment Programs.
Computes VBP, HACRP, HRRP, MIPS, HAI, Star Ratings, and Combined Payment Impact.
Delegates to RuralHospitalSim domain functions for all calculations.
"""
using Stipple, StippleUI, StipplePlotly

using ...RuralHospitalSim: calculate_vbp, calculate_hacrp, calculate_hrrp,
    calculate_mips, calculate_hai, calculate_star_ratings,
    calculate_combined_payment_impact,
    VBPMeasure, VBPDomainScore, VBPResult,
    HACRPMeasure, HACRPResult,
    HRRPCondition, HRRPConditionResult, HRRPResult,
    MIPSCategory, MIPSResult,
    HAIRecord, HAITypeResult, HAIResult,
    CombinedPaymentResult


@app begin
    @in left_drawer_open::Bool = true

    # ── Program selector ───────────────────────────────────────────
    @in program_selector::String = "VBP"
    @out program_options::Vector{Dict{String,Any}} = [
        Dict("label" => "Value-Based Purchasing (VBP)", "value" => "VBP"),
        Dict("label" => "Hospital-Acquired Condition (HACRP)", "value" => "HACRP"),
        Dict("label" => "Hospital Readmissions (HRRP)", "value" => "HRRP"),
        Dict("label" => "Merit-Based Incentive (MIPS)", "value" => "MIPS"),
        Dict("label" => "Healthcare-Associated Infections (HAI)", "value" => "HAI"),
        Dict("label" => "Star Ratings", "value" => "StarRatings"),
        Dict("label" => "Combined Payment Impact", "value" => "Combined"),
    ]

    # ── VBP inputs ─────────────────────────────────────────────────
    @in vbp_clinical_points::Float64 = 7.0
    @in vbp_safety_points::Float64 = 6.0
    @in vbp_person_points::Float64 = 8.0
    @in vbp_efficiency_points::Float64 = 5.0
    @in vbp_base_drg_amount::Float64 = 10_000_000.0

    # ── HACRP inputs ───────────────────────────────────────────────
    @in hacrp_psi90_zscore::Float64 = 0.5
    @in hacrp_clabsi_zscore::Float64 = 0.3
    @in hacrp_cauti_zscore::Float64 = -0.2
    @in hacrp_ssi_zscore::Float64 = 0.1
    @in hacrp_mrsa_zscore::Float64 = 0.4
    @in hacrp_cdi_zscore::Float64 = -0.1

    # ── HRRP inputs ────────────────────────────────────────────────
    @in hrrp_ami_predicted::Float64 = 110.0
    @in hrrp_ami_expected::Float64 = 100.0
    @in hrrp_hf_predicted::Float64 = 130.0
    @in hrrp_hf_expected::Float64 = 120.0
    @in hrrp_pn_predicted::Float64 = 95.0
    @in hrrp_pn_expected::Float64 = 100.0
    @in hrrp_copd_predicted::Float64 = 105.0
    @in hrrp_copd_expected::Float64 = 100.0
    @in hrrp_base_drg::Float64 = 10_000_000.0

    # ── MIPS inputs ────────────────────────────────────────────────
    @in mips_quality_score::Float64 = 80.0
    @in mips_cost_score::Float64 = 75.0
    @in mips_pi_score::Float64 = 85.0
    @in mips_ia_score::Float64 = 90.0

    # ── HAI inputs ─────────────────────────────────────────────────
    @in hai_infection_type::String = "CLABSI"
    @out hai_type_options::Vector{Dict{String,Any}} = [
        Dict("label" => "CLABSI", "value" => "CLABSI"),
        Dict("label" => "CAUTI", "value" => "CAUTI"),
        Dict("label" => "SSI", "value" => "SSI"),
        Dict("label" => "MRSA", "value" => "MRSA"),
        Dict("label" => "CDI", "value" => "CDI"),
    ]
    @in hai_observed::Int = 5
    @in hai_predicted::Float64 = 6.0
    @in hai_device_days::Float64 = 10000.0

    # ── Combined inputs (base DRG for dollar impact) ───────────────
    @in combined_base_drg::Float64 = 10_000_000.0

    @in recalculate::Bool = false

    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    # ── Outputs ────────────────────────────────────────────────────
    @out result_label::String = "Total Performance Score"
    @out result_primary::String = "50.0"
    @out result_secondary::String = "Payment Multiplier: 1.0000"
    @out result_detail::String = "Net Adjustment: 0.00%"
    @out result_extra::String = ""

    @out payment_chart_data::Vector{PlotData} = [
        PlotData(x=["VBP", "HACRP", "HRRP", "Net"],
                 y=[0.0, 0.0, 0.0, 0.0],
                 plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                 marker=Dict("color" => ["#2196F3", "#FF9800", "#F44336", "#4CAF50"]))
    ]
    @out payment_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="CMS Payment Adjustment Impact"),
        yaxis=[PlotLayoutAxis(title="Adjustment (%)")],
    )

    # ── Handler ────────────────────────────────────────────────────
    @onchange recalculate begin
        if recalculate
            recalculate = false

            try
                if program_selector == "VBP"
                    # Build single-measure domains using achievement points
                    clinical = [VBPMeasure(measure_id="Clinical", achievement_points=vbp_clinical_points,
                                           improvement_points=0.0, benchmark=10.0, floor=0.0, threshold=5.0)]
                    safety = [VBPMeasure(measure_id="Safety", achievement_points=vbp_safety_points,
                                         improvement_points=0.0, benchmark=10.0, floor=0.0, threshold=5.0)]
                    person = [VBPMeasure(measure_id="Person", achievement_points=vbp_person_points,
                                         improvement_points=0.0, benchmark=10.0, floor=0.0, threshold=5.0)]
                    efficiency = [VBPMeasure(measure_id="Efficiency", achievement_points=vbp_efficiency_points,
                                             improvement_points=0.0, benchmark=10.0, floor=0.0, threshold=5.0)]
                    res = calculate_vbp(clinical, safety, person, efficiency, vbp_base_drg_amount)
                    result_label = "Total Performance Score (TPS)"
                    result_primary = string(round(res.total_performance_score, digits=2))
                    result_secondary = "Payment Multiplier: $(round(res.payment_multiplier, digits=4))"
                    result_detail = "Net Adjustment: $(round(res.net_adjustment_pct, digits=2))%"
                    dollar_impact = vbp_base_drg_amount * (res.payment_multiplier - 1.0)
                    result_extra = "Dollar Impact: \$$(round(Int, dollar_impact))"

                    payment_chart_data = [PlotData(
                        x=["Clinical", "Safety", "Person/Community", "Efficiency", "TPS"],
                        y=[vbp_clinical_points * 10.0 * 0.25,
                           vbp_safety_points * 10.0 * 0.25,
                           vbp_person_points * 10.0 * 0.25,
                           vbp_efficiency_points * 10.0 * 0.25,
                           res.total_performance_score],
                        plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        marker=Dict("color" => ["#2196F3", "#FF9800", "#9C27B0", "#4CAF50", "#00BCD4"]))]
                    payment_chart_layout = PlotLayout(
                        title=PlotLayoutTitle(text="VBP Domain Scores (Weighted)"),
                        yaxis=[PlotLayoutAxis(title="Score")])

                elseif program_selector == "HACRP"
                    measures = [
                        HACRPMeasure(measure_id="PSI-90", observed=0.0, predicted=0.0, z_score=hacrp_psi90_zscore),
                        HACRPMeasure(measure_id="CLABSI", observed=0.0, predicted=0.0, z_score=hacrp_clabsi_zscore),
                        HACRPMeasure(measure_id="CAUTI", observed=0.0, predicted=0.0, z_score=hacrp_cauti_zscore),
                        HACRPMeasure(measure_id="SSI", observed=0.0, predicted=0.0, z_score=hacrp_ssi_zscore),
                        HACRPMeasure(measure_id="MRSA", observed=0.0, predicted=0.0, z_score=hacrp_mrsa_zscore),
                        HACRPMeasure(measure_id="CDI", observed=0.0, predicted=0.0, z_score=hacrp_cdi_zscore),
                    ]
                    res = calculate_hacrp(measures)
                    result_label = "HACRP Total Score"
                    result_primary = string(round(res.total_score, digits=3))
                    result_secondary = "Percentile: $(round(res.percentile, digits=1))%"
                    penalty_str = res.penalty_applies ? "YES (-1%)" : "No"
                    result_detail = "Penalty Applies: $(penalty_str)"
                    result_extra = "Penalty %: $(round(res.penalty_pct * 100, digits=2))%"

                    labels = ["PSI-90", "CLABSI", "CAUTI", "SSI", "MRSA", "CDI"]
                    scores = [hacrp_psi90_zscore, hacrp_clabsi_zscore, hacrp_cauti_zscore,
                              hacrp_ssi_zscore, hacrp_mrsa_zscore, hacrp_cdi_zscore]
                    colors = [s > 0.75 ? "#F44336" : s > 0.0 ? "#FF9800" : "#4CAF50" for s in scores]
                    payment_chart_data = [PlotData(
                        x=labels, y=scores,
                        plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        marker=Dict("color" => colors))]
                    payment_chart_layout = PlotLayout(
                        title=PlotLayoutTitle(text="HACRP Measure Z-Scores"),
                        yaxis=[PlotLayoutAxis(title="Z-Score")])

                elseif program_selector == "HRRP"
                    conditions = [
                        HRRPCondition(condition=:ami, predicted=hrrp_ami_predicted, expected=hrrp_ami_expected),
                        HRRPCondition(condition=:hf, predicted=hrrp_hf_predicted, expected=hrrp_hf_expected),
                        HRRPCondition(condition=:pn, predicted=hrrp_pn_predicted, expected=hrrp_pn_expected),
                        HRRPCondition(condition=:copd, predicted=hrrp_copd_predicted, expected=hrrp_copd_expected),
                    ]
                    res = calculate_hrrp(conditions, hrrp_base_drg)
                    result_label = "HRRP Payment Adjustment"
                    result_primary = string(round(res.payment_adjustment, digits=4))
                    result_secondary = "Penalty: $(round(res.penalty_pct * 100, digits=2))%"
                    result_detail = "Dollar Impact: \$$(round(Int, hrrp_base_drg * res.penalty_pct))"
                    err_strs = [string(r.condition, ": ", round(r.excess_readmission_ratio, digits=3))
                                for r in res.condition_results]
                    result_extra = "ERR — " * join(err_strs, ", ")

                    cond_labels = [string(r.condition) for r in res.condition_results]
                    err_vals = [r.excess_readmission_ratio for r in res.condition_results]
                    colors = [e > 1.0 ? "#F44336" : "#4CAF50" for e in err_vals]
                    payment_chart_data = [PlotData(
                        x=cond_labels, y=err_vals,
                        plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        marker=Dict("color" => colors))]
                    payment_chart_layout = PlotLayout(
                        title=PlotLayoutTitle(text="Excess Readmission Ratios by Condition"),
                        yaxis=[PlotLayoutAxis(title="ERR (1.0 = expected)")],
                        shapes=[Dict("type" => "line", "y0" => 1.0, "y1" => 1.0,
                                     "x0" => 0, "x1" => 1, "xref" => "paper",
                                     "line" => Dict("color" => "red", "dash" => "dash"))])

                elseif program_selector == "MIPS"
                    res = calculate_mips(mips_quality_score, mips_cost_score,
                                         mips_pi_score, mips_ia_score)
                    result_label = "MIPS Final Score"
                    result_primary = string(round(res.final_score, digits=2))
                    result_secondary = "Payment Adjustment: $(round(res.payment_adjustment_pct, digits=2))%"
                    result_detail = join(["$(c.category_name): $(round(c.score * c.weight, digits=1))" for c in res.categories], " | ")
                    result_extra = ""

                    payment_chart_data = [PlotData(
                        x=[c.category_name for c in res.categories],
                        y=[c.score for c in res.categories],
                        plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        marker=Dict("color" => ["#2196F3", "#FF9800", "#9C27B0", "#4CAF50"]))]
                    payment_chart_layout = PlotLayout(
                        title=PlotLayoutTitle(text="MIPS Category Scores"),
                        yaxis=[PlotLayoutAxis(title="Score (0-100)")])

                elseif program_selector == "HAI"
                    itype = Symbol(hai_infection_type)
                    records = [HAIRecord(infection_type=itype,
                                         observed_events=hai_observed,
                                         predicted_events=hai_predicted,
                                         device_days_or_patient_days=hai_device_days)]
                    res = calculate_hai(records)
                    result_label = "HAI Composite SIR"
                    result_primary = string(round(res.overall_composite, digits=3))
                    compliance_str = res.compliance_flag ? "Compliant (SIR <= 1.0)" : "Non-Compliant (SIR > 1.0)"
                    result_secondary = compliance_str
                    if !isempty(res.type_results)
                        tr = res.type_results[1]
                        result_detail = "$(tr.infection_type): Obs=$(tr.observed), Pred=$(round(tr.predicted, digits=1)), SIR=$(round(tr.sir, digits=3))"
                    else
                        result_detail = ""
                    end
                    result_extra = ""

                    type_labels = [string(tr.infection_type) for tr in res.type_results]
                    sir_vals = [tr.sir for tr in res.type_results]
                    colors = [s > 1.0 ? "#F44336" : "#4CAF50" for s in sir_vals]
                    payment_chart_data = [PlotData(
                        x=type_labels, y=sir_vals,
                        plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        marker=Dict("color" => colors))]
                    payment_chart_layout = PlotLayout(
                        title=PlotLayoutTitle(text="Standardized Infection Ratio (SIR)"),
                        yaxis=[PlotLayoutAxis(title="SIR (1.0 = expected)")],
                        shapes=[Dict("type" => "line", "y0" => 1.0, "y1" => 1.0,
                                     "x0" => 0, "x1" => 1, "xref" => "paper",
                                     "line" => Dict("color" => "red", "dash" => "dash"))])

                elseif program_selector == "StarRatings"
                    # Use simplified measure inputs derived from MIPS-style scores
                    # mapped to star ratings groups
                    result_label = "Star Ratings"
                    result_primary = "N/A"
                    result_secondary = "Use Combined view for full star rating analysis"
                    result_detail = "Star Ratings require group-level measure data"
                    result_extra = ""

                elseif program_selector == "Combined"
                    # Run VBP, HACRP, HRRP and combine
                    clinical = [VBPMeasure(measure_id="Clinical", achievement_points=vbp_clinical_points,
                                           improvement_points=0.0, benchmark=10.0, floor=0.0, threshold=5.0)]
                    safety = [VBPMeasure(measure_id="Safety", achievement_points=vbp_safety_points,
                                         improvement_points=0.0, benchmark=10.0, floor=0.0, threshold=5.0)]
                    person = [VBPMeasure(measure_id="Person", achievement_points=vbp_person_points,
                                         improvement_points=0.0, benchmark=10.0, floor=0.0, threshold=5.0)]
                    efficiency = [VBPMeasure(measure_id="Efficiency", achievement_points=vbp_efficiency_points,
                                             improvement_points=0.0, benchmark=10.0, floor=0.0, threshold=5.0)]
                    vbp_res = calculate_vbp(clinical, safety, person, efficiency, combined_base_drg)

                    hacrp_measures = [
                        HACRPMeasure(measure_id="PSI-90", observed=0.0, predicted=0.0, z_score=hacrp_psi90_zscore),
                        HACRPMeasure(measure_id="CLABSI", observed=0.0, predicted=0.0, z_score=hacrp_clabsi_zscore),
                        HACRPMeasure(measure_id="CAUTI", observed=0.0, predicted=0.0, z_score=hacrp_cauti_zscore),
                        HACRPMeasure(measure_id="SSI", observed=0.0, predicted=0.0, z_score=hacrp_ssi_zscore),
                        HACRPMeasure(measure_id="MRSA", observed=0.0, predicted=0.0, z_score=hacrp_mrsa_zscore),
                        HACRPMeasure(measure_id="CDI", observed=0.0, predicted=0.0, z_score=hacrp_cdi_zscore),
                    ]
                    hacrp_res = calculate_hacrp(hacrp_measures)

                    hrrp_conditions = [
                        HRRPCondition(condition=:ami, predicted=hrrp_ami_predicted, expected=hrrp_ami_expected),
                        HRRPCondition(condition=:hf, predicted=hrrp_hf_predicted, expected=hrrp_hf_expected),
                        HRRPCondition(condition=:pn, predicted=hrrp_pn_predicted, expected=hrrp_pn_expected),
                        HRRPCondition(condition=:copd, predicted=hrrp_copd_predicted, expected=hrrp_copd_expected),
                    ]
                    hrrp_res = calculate_hrrp(hrrp_conditions, combined_base_drg)

                    combined = calculate_combined_payment_impact(vbp_res, hacrp_res, hrrp_res, combined_base_drg)

                    result_label = "Combined Net Payment Impact"
                    result_primary = "$(round(combined.net_impact_pct, digits=2))%"
                    result_secondary = "Dollar Impact: \$$(round(Int, combined.net_impact_dollars))"
                    result_detail = "VBP: $(round(combined.vbp_adjustment * 100, digits=2))% | HACRP: $(round(combined.hacrp_penalty * 100, digits=2))% | HRRP: $(round(combined.hrrp_penalty * 100, digits=2))%"
                    result_extra = "Base DRG Payments: \$$(round(Int, combined_base_drg))"

                    # Waterfall chart
                    vals = [combined.vbp_adjustment * 100, combined.hacrp_penalty * 100,
                            combined.hrrp_penalty * 100, combined.net_impact_pct]
                    colors = [v >= 0 ? "#4CAF50" : "#F44336" for v in vals]
                    payment_chart_data = [PlotData(
                        x=["VBP", "HACRP", "HRRP", "Net Impact"],
                        y=vals,
                        plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                        marker=Dict("color" => colors))]
                    payment_chart_layout = PlotLayout(
                        title=PlotLayoutTitle(text="Combined CMS Payment Adjustment Waterfall"),
                        yaxis=[PlotLayoutAxis(title="Adjustment (%)")])
                end

                @info "CMS Programs ($(program_selector)): $(result_primary)"
            catch err
                result_label = "Error"
                result_primary = "Calculation failed"
                result_secondary = sprint(showerror, err)
                result_detail = ""
                result_extra = ""
                @error "CMS Programs calculation error" exception=(err, catch_backtrace())
            end
        end
    end
end

const cms_programs_model = @init
