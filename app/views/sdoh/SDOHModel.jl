"""
Stipple reactive model for SDOH Integration Analysis.
Models how social determinants of health affect hospital financial performance.
"""
using Stipple, StippleUI, StipplePlotly


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
            adi_norm = clamp(adi_national_rank / 100.0, 0.0, 1.0)
            volume_adjustment = 1.0 - 0.05 * svi_score + 0.03 * uninsured_rate
            cost_per_case_adjustment = 1.0 + 0.15 * adi_norm + 0.10 * food_desert_pct + 0.08 * (1.0 - health_literacy_score)
            ed_mult = 1.0 + 0.20 * svi_score + 0.15 * uninsured_rate + 0.10 * food_desert_pct
            ed_utilization_multiplier = transportation_desert ? ed_mult + 0.15 : ed_mult
            readmission_risk_multiplier = 1.0 + 0.18 * poverty_rate + 0.12 * food_desert_pct + 0.10 * (1.0 - health_literacy_score)
            telehealth_viability = clamp(broadband_pct * 0.7 + health_literacy_score * 0.3, 0.0, 1.0)

            composite_risk_score = clamp(0.30*svi_score + 0.20*adi_norm +
                0.15*clamp(uninsured_rate/0.30,0,1) + 0.15*clamp(poverty_rate/0.40,0,1) +
                0.10*food_desert_pct + 0.10*(transportation_desert ? 1.0 : 0.0), 0.0, 1.0)
            risk_tier = composite_risk_score < 0.25 ? "low" :
                        composite_risk_score < 0.50 ? "moderate" :
                        composite_risk_score < 0.75 ? "high" : "critical"

            uc_drag = base_revenue * uninsured_rate * 0.40
            adj_rev = base_revenue * volume_adjustment - uc_drag
            ed_premium = base_expenses * 0.10 * (ed_utilization_multiplier - 1.0)
            readmit_cost = base_expenses * 0.03 * (readmission_risk_multiplier - 1.0)
            adj_exp = base_expenses * cost_per_case_adjustment + ed_premium + readmit_cost
            revenue_impact = round(adj_rev - base_revenue, digits=0)
            expense_impact = round(adj_exp - base_expenses, digits=0)
            net_margin_impact = round((adj_rev - adj_exp) - (base_revenue - base_expenses), digits=0)

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
            @info "SDOH: composite risk $(round(composite_risk_score, digits=2)), tier $risk_tier"
        end
    end
end

const sdoh_model = @init
