"""
Stipple reactive model for the REH Conversion Wizard (4-step wizard).
Guides users through evaluating a CAH-to-REH conversion.
"""
using Stipple, StippleUI, StipplePlotly


@app begin
    @in left_drawer_open::Bool = true
    # ── Wizard State ─────────────────────────────────────────────────────
    @in wizard_step::Int = 1
    @out total_steps::Int = 4

    # ── Step 1: Hospital Selection ───────────────────────────────────────
    @in selected_hospital_id::Int = 1
    @out hospital_options::Vector{Dict{String,Any}} = [
        Dict("label"=>"Prairie View Community Hospital (CAH, 25 beds)", "value"=>1),
        Dict("label"=>"Mountain Valley Medical Center (CAH, 15 beds)", "value"=>2),
        Dict("label"=>"High Plains Health (CAH, 20 beds)", "value"=>4),
    ]
    @out eligibility_check::Dict{String,Any} = Dict{String,Any}(
        "eligible" => true,
        "checks" => [
            Dict("item"=>"Is a CAH or rural hospital with <= 50 beds", "pass"=>true),
            Dict("item"=>"Has a currently operating emergency department", "pass"=>true),
            Dict("item"=>"Located in a rural area (RUCA >= 4)", "pass"=>true),
            Dict("item"=>"Not currently a PPS hospital > 50 beds", "pass"=>true),
        ]
    )

    # Current hospital financials (loaded on selection)
    @out current_revenue::Float64 = 18_500_000.0
    @out current_expenses::Float64 = 19_200_000.0
    @out current_margin::Float64 = -0.038
    @out current_inpatient_revenue::Float64 = 7_770_000.0
    @out current_outpatient_revenue::Float64 = 10_730_000.0
    @out current_inpatient_pct::Float64 = 0.42
    @out current_beds::Int = 25
    @out current_ed_visits::Int = 4200
    @out current_inpatient_days::Int = 2356

    # ── Step 2: Conversion Assumptions ───────────────────────────────────
    @in reh_monthly_facility_payment::Float64 = 272_866.0
    @in reh_opps_rate_increase::Float64 = 5.0
    @in inpatient_revenue_retained_pct::Float64 = 15.0
    @in inpatient_revenue_redirected_pct::Float64 = 85.0
    @in outpatient_volume_change::Float64 = 5.0
    @in ed_volume_change::Float64 = -3.0
    @in observation_volume_increase::Float64 = 25.0

    # Cost changes from conversion
    @in nursing_fte_reduction::Float64 = 18.0
    @in inpatient_staff_reduction::Float64 = 12.0
    @in support_staff_reduction::Float64 = 4.0
    @in avg_fte_cost_savings::Float64 = 68_500.0
    @in supply_cost_reduction_pct::Float64 = 20.0
    @in facility_maintenance_reduction_pct::Float64 = 15.0
    @in capital_avoidance::Float64 = 2_500_000.0
    @in conversion_costs::Float64 = 350_000.0

    # ── Step 3: Projection Settings ──────────────────────────────────────
    @in projection_years::Int = 5
    @in annual_rate_escalation::Float64 = 2.0
    @in annual_volume_growth::Float64 = 1.0
    @in cost_inflation_rate::Float64 = 3.0
    @in discount_rate::Float64 = 5.0
    @in run_projection::Bool = false

    # ── Step 4: Results ──────────────────────────────────────────────────
    @out reh_annual_facility_payment::Float64 = 3_274_392.0
    @out reh_opps_revenue_increase::Float64 = 536_500.0
    @out reh_total_new_revenue::Float64 = 3_810_892.0
    @out reh_inpatient_revenue_lost::Float64 = -6_604_500.0
    @out reh_net_revenue_change::Float64 = -2_793_608.0
    @out reh_labor_savings::Float64 = 2_329_000.0
    @out reh_supply_savings::Float64 = 560_000.0
    @out reh_facility_savings::Float64 = 285_000.0
    @out reh_total_expense_reduction::Float64 = 3_174_000.0
    @out reh_net_financial_impact::Float64 = 380_392.0
    @out reh_year1_margin::Float64 = 0.022
    @out reh_5yr_npv::Float64 = 1_250_000.0
    @out reh_breakeven_month::Int = 8
    @out reh_recommendation::String = "favorable"

    # Comparison chart data
    @out comparison_chart_data::Vector{PlotData} = [
        PlotData(x=["2026","2027","2028","2029","2030"],
                 y=[-0.038, -0.042, -0.045, -0.048, -0.052],
                 plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                 name="Current (CAH)", mode="lines+markers",
                 line=PlotDataLine(color="red")),
        PlotData(x=["2026","2027","2028","2029","2030"],
                 y=[0.022, 0.028, 0.032, 0.035, 0.038],
                 plot=StipplePlotly.Charts.PLOT_TYPE_SCATTER,
                 name="After REH Conversion", mode="lines+markers",
                 line=PlotDataLine(color="green")),
    ]
    @out comparison_chart_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Operating Margin: CAH vs REH Conversion"),
        xaxis=[PlotLayoutAxis(title="Year")],
        yaxis=[PlotLayoutAxis(title="Operating Margin", tickformat=".1%")],
        showlegend=true,
    )

    @out revenue_waterfall_data::Vector{PlotData} = [
        PlotData(
            x=["Current Revenue", "Lost Inpatient", "REH Facility Payment", "OPPS Increase",
               "OP Volume Growth", "Projected Revenue"],
            y=[18.5, -6.6, 3.3, 0.5, 0.5, 16.2],
            plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
            name="Revenue Waterfall (\$M)",
            marker=PlotDataMarker(color=["blue","red","green","green","green","blue"])),
    ]
    @out waterfall_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Revenue Impact Waterfall (\$M)"),
        yaxis=[PlotLayoutAxis(title="\$ Millions")],
    )

    # ── Community impact assessment ──────────────────────────────────────
    @out community_impacts::Vector{Dict{String,String}} = [
        Dict("area"=>"Emergency Services", "impact"=>"Maintained",
             "detail"=>"24/7 ED services continue under REH designation"),
        Dict("area"=>"Inpatient Care", "impact"=>"Eliminated",
             "detail"=>"Inpatient admissions must transfer to nearest hospital (35 miles)"),
        Dict("area"=>"Outpatient Services", "impact"=>"Enhanced",
             "detail"=>"Outpatient services expanded with higher reimbursement"),
        Dict("area"=>"Observation Care", "impact"=>"Expanded",
             "detail"=>"Extended observation stays (up to 24 hours) replace some admissions"),
        Dict("area"=>"Surgical Services", "impact"=>"Limited",
             "detail"=>"Outpatient surgery continues; inpatient surgical cases transfer"),
        Dict("area"=>"Employment", "impact"=>"Reduced",
             "detail"=>"Estimated 34 FTE reduction from inpatient service closure"),
    ]

    # ── Handlers ─────────────────────────────────────────────────────────
    @onchange selected_hospital_id begin
        @info "REH Wizard: selected hospital $selected_hospital_id"
        if selected_hospital_id == 1
            current_revenue = 18_500_000.0
            current_expenses = 19_200_000.0
            current_margin = -0.038
            current_beds = 25
        elseif selected_hospital_id == 2
            current_revenue = 12_200_000.0
            current_expenses = 12_500_000.0
            current_margin = -0.025
            current_beds = 15
        else
            current_revenue = 9_800_000.0
            current_expenses = 9_680_000.0
            current_margin = 0.012
            current_beds = 20
        end
        current_inpatient_pct = 0.42
        current_inpatient_revenue = current_revenue * current_inpatient_pct
        current_outpatient_revenue = current_revenue * (1 - current_inpatient_pct)
    end

    @onchange run_projection begin
        if run_projection
            run_projection = false
            @info "Computing REH conversion projection..."

            # Compute financial impact
            reh_annual_facility_payment = reh_monthly_facility_payment * 12
            reh_opps_revenue_increase = current_outpatient_revenue * (reh_opps_rate_increase / 100)
            reh_inpatient_revenue_lost = -(current_inpatient_revenue * (inpatient_revenue_redirected_pct / 100))
            reh_total_new_revenue = reh_annual_facility_payment + reh_opps_revenue_increase
            reh_net_revenue_change = reh_total_new_revenue + reh_inpatient_revenue_lost

            total_fte_reduced = nursing_fte_reduction + inpatient_staff_reduction + support_staff_reduction
            reh_labor_savings = total_fte_reduced * avg_fte_cost_savings
            reh_supply_savings = current_expenses * 0.15 * (supply_cost_reduction_pct / 100)
            reh_facility_savings = current_expenses * 0.05 * (facility_maintenance_reduction_pct / 100)
            reh_total_expense_reduction = reh_labor_savings + reh_supply_savings + reh_facility_savings

            reh_net_financial_impact = reh_net_revenue_change + reh_total_expense_reduction - conversion_costs
            new_revenue = current_revenue + reh_net_revenue_change
            new_expenses = current_expenses - reh_total_expense_reduction + conversion_costs / projection_years
            reh_year1_margin = new_revenue > 0 ? (new_revenue - new_expenses) / new_revenue : 0.0

            # NPV
            annual_benefit = reh_net_revenue_change + reh_total_expense_reduction
            npv = -conversion_costs
            for yr in 1:projection_years
                npv += annual_benefit / (1 + discount_rate / 100)^yr
            end
            reh_5yr_npv = npv
            reh_breakeven_month = annual_benefit > 0 ? max(1, round(Int, conversion_costs / (annual_benefit / 12))) : 0
            reh_recommendation = reh_5yr_npv > 0 ? "favorable" : "unfavorable"

            wizard_step = 4
        end
    end
end

const reh_wizard_model = @init
