"""
Stipple reactive model for IRS Schedule H Community Benefit Valuation.
Calculates community benefit vs. tax exemption value with AHA benchmarking.
"""
using Stipple, StippleUI, StipplePlotly


@app begin
    @in left_drawer_open::Bool = true
    # ── Inputs ──────────────────────────────────────────────────────────
    @in charity_care_costs::Float64 = 2_500_000.0
    @in medicaid_shortfall::Float64 = 4_000_000.0
    @in community_health_services::Float64 = 800_000.0
    @in health_professions_education::Float64 = 200_000.0
    @in subsidized_services_cost::Float64 = 500_000.0
    @in research::Float64 = 0.0
    @in cash_contributions::Float64 = 150_000.0
    @in community_building::Float64 = 100_000.0
    @in total_expenses::Float64 = 80_000_000.0
    @in assessed_value::Float64 = 25_000_000.0
    @in tax_rate::Float64 = 0.21
    @in property_tax_rate::Float64 = 0.015
    @in recalculate::Bool = false

    # ── Outputs ─────────────────────────────────────────────────────────
    @out total_community_benefit::Float64 = 8_250_000.0
    @out benefit_as_pct::Float64 = 0.103
    @out estimated_tax_exemption::Float64 = 1_879_000.0
    @out net_community_investment::Float64 = 6_371_000.0
    @out meets_aha_standard::Bool = true
    @out national_median_pct::Float64 = 0.076
    @out percentile_estimate::Int = 72
    @out rating::String = "above_average"

    @out category_data::Vector{PlotData} = [
        PlotData(labels=["Charity Care", "Medicaid Shortfall", "Community Health",
                         "Education", "Subsidized Svcs", "Contributions", "Community Building"],
                 values=[2_500_000, 4_000_000, 800_000, 200_000, 500_000, 150_000, 100_000],
                 plot=StipplePlotly.Charts.PLOT_TYPE_PIE, hole=0.4, name="Categories")
    ]
    @out category_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Community Benefit by Category"),
    )

    @out comparison_data::Vector{PlotData} = [
        PlotData(x=["Community Benefit", "Tax Exemption Value"],
                 y=[8_250_000, 1_879_000],
                 plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                 marker=Dict("color" => ["#4CAF50", "#FF9800"]))
    ]
    @out comparison_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Benefit vs. Tax Exemption Value"),
        yaxis=[PlotLayoutAxis(title="Dollars (\$)")],
    )

    @onchange recalculate begin
        if recalculate
            recalculate = false
            cats = [charity_care_costs, medicaid_shortfall, community_health_services,
                    health_professions_education, subsidized_services_cost,
                    research, cash_contributions, community_building]
            cat_names = ["Charity Care", "Medicaid Shortfall", "Community Health",
                         "Education", "Subsidized Svcs", "Research", "Contributions", "Community Building"]

            total_community_benefit = sum(cats)
            benefit_as_pct = total_expenses > 0 ? total_community_benefit / total_expenses : 0.0

            corp_tax = total_expenses * 0.03 * tax_rate
            prop_tax = assessed_value * property_tax_rate
            sales_tax = total_expenses * 0.01
            estimated_tax_exemption = corp_tax + prop_tax + sales_tax

            net_community_investment = total_community_benefit - estimated_tax_exemption
            meets_aha_standard = total_community_benefit >= estimated_tax_exemption

            z = (benefit_as_pct - 0.076) / 0.04
            percentile_estimate = clamp(round(Int, 50.0 + 50.0 * tanh(z * 0.8)), 1, 99)
            rating = benefit_as_pct >= 0.076 * 1.5 ? "exemplary" :
                     benefit_as_pct >= 0.076 ? "above_average" :
                     benefit_as_pct >= 0.076 * 0.5 ? "below_average" : "needs_improvement"

            category_data = [PlotData(labels=cat_names, values=cats,
                plot=StipplePlotly.Charts.PLOT_TYPE_PIE, hole=0.4, name="Categories")]
            comparison_data = [PlotData(x=["Community Benefit", "Tax Exemption Value"],
                y=[total_community_benefit, estimated_tax_exemption],
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                marker=Dict("color" => ["#4CAF50", "#FF9800"]))]
            @info "Community benefit: $(round(benefit_as_pct*100, digits=1))%, AHA=$(meets_aha_standard)"
        end
    end
end

const community_benefit_model = @init
