"""340B Drug Program Savings Estimator Stipple model"""
@app begin
    # ──────── UI state ────────
    @in left_drawer_open::Bool = true

    @in load_sample_btn::Bool = false
    @in upload_csv::String = ""
    @in managed_care_cap::Float64 = 0.15
    @in budget_constraint::Float64 = 500_000.0
    @in optimize_mix_btn::Bool = false

    @in is_calculating::Bool = false
    @in error_message::String = ""

    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    @out total_annual_usage::Float64 = 0.0
    @out avg_discount_pct::Float64 = 0.0
    @out estimated_savings::Float64 = 0.0
    @out ceiling_ratio::Float64 = 0.0
    @out managed_care_applicability::Float64 = 0.0

    @out optimized_drug_count::Int = 0
    @out optimization_savings::Float64 = 0.0
    @out budget_remaining::Float64 = 0.0
    @out optimization_units::Float64 = 0.0

    @out formulary_rows::Vector{String} = String[]
    @out optimization_rows::Vector{String} = String[]

    # Track loaded formulary in model state
    current_drugs::Vector = []

    @onbutton load_sample_btn begin
        is_calculating = true
        error_message = ""
        try
            fixture_path = joinpath(@__DIR__, "..", "..", "..", "test", "fixtures", "drugs", "340b_sample_formulary.csv")
            df = FinanceEngine.load_340b_formulary(fixture_path)
            current_drugs = [
                FinanceEngine.Drug340B(
                    row[:ndc],
                    row[:description],
                    row[:avg_wholesale_price],
                    row[:ceiling_price],
                    row[:hospital_acquisition_cost],
                    row[:estimated_monthly_usage]
                )
                for row in eachrow(df)
            ]

            metrics = FinanceEngine.estimate_340b_savings(current_drugs, managed_care_cap=managed_care_cap)
            total_annual_usage = metrics.total_annual_usage_units
            avg_discount_pct = metrics.avg_discount_pct
            estimated_savings = metrics.estimated_annual_savings
            ceiling_ratio = metrics.ceiling_vs_mac_ratio
            managed_care_applicability = metrics.managed_care_discount_applicability

            formulary_rows = [String(row[:ndc]) for row in eachrow(df)]
        catch e
            error_message = "Error loading sample: $(sprint(showerror, e))"
        finally
            is_calculating = false
        end
    end

    @onbutton optimize_mix_btn begin
        is_calculating = true
        error_message = ""
        try
            if isempty(current_drugs)
                error_message = "Load sample formulary first"
            else
                result = FinanceEngine.optimize_drug_mix(current_drugs, budget_constraint, managed_care_cap=managed_care_cap)
                optimized_drug_count = length(result.optimized_drugs)
                optimization_savings = result.total_annual_savings
                budget_remaining = result.budget_remaining
                optimization_units = result.annual_units_used

                optimization_rows = result.optimized_drugs
            end
        catch e
            error_message = "Optimization failed: $(sprint(showerror, e))"
        finally
            is_calculating = false
        end
    end
end
