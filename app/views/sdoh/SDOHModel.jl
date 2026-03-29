"""
Stipple reactive model for SDOH Integration Analysis.
Models how social determinants of health affect hospital financial performance.
Delegates to RuralHospitalSim.calculate_sdoh_adjustments() for computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: calculate_sdoh_adjustments, sdoh_financial_impact,
    sdoh_risk_tier, SDOHProfile, SDOHAdjustment


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in svi_score::Float64 = 0.65
    @in adi_national_rank::Int = 72
    @in food_desert_pct::Float64 = 0.20
    @in broadband_pct::Float64 = 0.70
    @in transportation_desert::Bool = true
    @in health_literacy_score::Float64 = 0.45
    @in uninsured_rate::Float64 = 0.14
    @in poverty_rate::Float64 = 0.22
    @in median_household_income::Float64 = 38_000.0
    @in base_revenue::Float64 = 18_000_000.0
    @in base_expenses::Float64 = 17_500_000.0
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out composite_risk_score::Float64 = 0.55
    @out risk_tier::String = "high"
    @out volume_adjustment::Float64 = 1.0
    @out cost_per_case_adjustment::Float64 = 1.15
    @out ed_utilization_multiplier::Float64 = 1.35
    @out readmission_risk_multiplier::Float64 = 1.10
    @out telehealth_viability::Float64 = 0.62
    @out revenue_impact::Float64 = -500_000.0
    @out expense_impact::Float64 = 800_000.0
    @out net_margin_impact::Float64 = -1_300_000.0

    @out radar_data::Vector{PlotData} = [
        PlotData(r=[0.65, 0.72, 0.20, 0.30, 0.55, 0.14, 0.22],
                 theta=["SVI", "ADI", "Food Desert", "No Broadband", "Low Literacy", "Uninsured", "Poverty"],
                 plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR,
                 fill="toself", name="Community Profile",
                 fillcolor="rgba(255,87,34,0.2)", line=PlotDataLine(color="#FF5722"))
    ]
    @out radar_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="SDOH Risk Profile"),
        polar=Dict("radialaxis" => Dict("visible" => true, "range" => [0, 1])),
    )

    @out impact_data::Vector{PlotData} = [
        PlotData(x=["Revenue Impact", "Expense Impact", "Net Margin Impact"],
                 y=[-500_000, 800_000, -1_300_000],
                 plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                 marker=Dict("color" => ["#FF9800", "#F44336", "#F44336"]))
    ]
    @out impact_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="SDOH Financial Impact"),
        yaxis=[PlotLayoutAxis(title="Dollar Impact (\$)")],
    )

    @onchange recalculate begin
        if recalculate
            recalculate = false

            # Build domain profile and call engine
            profile = SDOHProfile(;
                svi_score=svi_score,
                adi_national_rank=adi_national_rank,
                food_desert_pct=food_desert_pct,
                broadband_pct=broadband_pct,
                transportation_desert=transportation_desert,
                health_literacy_score=health_literacy_score,
                uninsured_rate=uninsured_rate,
                poverty_rate=poverty_rate,
                median_household_income=median_household_income,
            )
            adjustments = calculate_sdoh_adjustments(profile)

            # Map domain results
            volume_adjustment = adjustments.volume_adjustment
            cost_per_case_adjustment = adjustments.cost_per_case_adjustment
            ed_utilization_multiplier = adjustments.ed_utilization_multiplier
            readmission_risk_multiplier = adjustments.readmission_risk_multiplier
            telehealth_viability = adjustments.telehealth_viability
            composite_risk_score = adjustments.composite_risk_score

            # Risk tier from domain
            risk_tier = sdoh_risk_tier(composite_risk_score)

            # Financial impact from domain
            fin_impact = sdoh_financial_impact(profile, base_revenue, base_expenses)
            revenue_impact = fin_impact.revenue_impact
            expense_impact = fin_impact.expense_impact
            net_margin_impact = fin_impact.net_margin_impact

            adi_norm = clamp(adi_national_rank / 100.0, 0.0, 1.0)
            no_bb = round(1.0 - broadband_pct, digits=2)
            low_lit = round(1.0 - health_literacy_score, digits=2)
            radar_data = [PlotData(
                r=[svi_score, adi_norm, food_desert_pct, no_bb, low_lit, uninsured_rate, poverty_rate],
                theta=["SVI", "ADI", "Food Desert", "No Broadband", "Low Literacy", "Uninsured", "Poverty"],
                plot=StipplePlotly.Charts.PLOT_TYPE_SCATTERPOLAR, fill="toself", name="Community Profile",
                fillcolor="rgba(255,87,34,0.2)", line=PlotDataLine(color="#FF5722"))]

            impact_data = [PlotData(x=["Revenue Impact", "Expense Impact", "Net Margin Impact"],
                y=[revenue_impact, expense_impact, net_margin_impact],
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                marker=Dict("color" => [revenue_impact>=0 ? "#4CAF50" : "#FF9800",
                    "#F44336", net_margin_impact>=0 ? "#4CAF50" : "#F44336"]))]
            @info "SDOH (domain): composite risk $(round(composite_risk_score, digits=2)), tier $risk_tier"
        end
    end
end

const sdoh_model = @init
