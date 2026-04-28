"""
Stipple reactive model for IRS Schedule H Community Benefit Valuation.
Calculates community benefit vs. tax exemption value with AHA benchmarking.
Delegates to RuralHospitalSim.calculate_community_benefit() for computation.
"""
using Stipple, StippleUI, StipplePlotly

# Import domain layer
using ...RuralHospitalSim: calculate_community_benefit, community_benefit_comparison,
    CommunityBenefitData, CommunityBenefitResult


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
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

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

            # Build domain data and call engine
            data = CommunityBenefitData(;
                charity_care_costs=charity_care_costs,
                medicaid_shortfall=medicaid_shortfall,
                community_health_services=community_health_services,
                health_professions_education=health_professions_education,
                subsidized_services_cost=subsidized_services_cost,
                research=research,
                cash_contributions=cash_contributions,
                community_building=community_building,
                total_expenses=total_expenses,
                assessed_value=assessed_value,
                tax_rate=tax_rate,
                property_tax_rate=property_tax_rate,
            )
            result = calculate_community_benefit(data)

            # Map domain results
            total_community_benefit = result.total_community_benefit
            benefit_as_pct = result.benefit_as_pct
            estimated_tax_exemption = result.estimated_tax_exemption
            net_community_investment = result.net_community_investment
            meets_aha_standard = result.meets_aha_standard
            percentile_estimate = result.percentile_estimate
            rating = result.rating

            cat_names = ["Charity Care", "Medicaid Shortfall", "Community Health",
                         "Education", "Subsidized Svcs", "Research", "Contributions", "Community Building"]
            cats = [charity_care_costs, medicaid_shortfall, community_health_services,
                    health_professions_education, subsidized_services_cost,
                    research, cash_contributions, community_building]

            category_data = [PlotData(labels=cat_names, values=cats,
                plot=StipplePlotly.Charts.PLOT_TYPE_PIE, hole=0.4, name="Categories")]
            comparison_data = [PlotData(x=["Community Benefit", "Tax Exemption Value"],
                y=[total_community_benefit, estimated_tax_exemption],
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                marker=Dict("color" => ["#4CAF50", "#FF9800"]))]
            @info "Community benefit (domain): $(round(benefit_as_pct*100, digits=1))%, AHA=$(meets_aha_standard)"
        end
    end
end

const community_benefit_model = @init
