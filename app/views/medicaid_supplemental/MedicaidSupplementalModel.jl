"""Medicaid DSH & Supplemental Payment Analyzer Stipple model"""
@app begin
    @in hospital_name::String = "Sample Hospital"
    @in medicare_cases::Int = 1000
    @in medicaid_cases::Int = 1500
    @in uninsured_cases::Int = 800
    @in low_income_pct::Float64 = 0.45
    @in medicaid_bed_days::Float64 = 547500.0
    @in total_bed_days::Float64 = 1204500.0
    @in base_medicaid_payment::Float64 = 10_000_000.0
    @in include_dsh::Bool = true
    @in include_upl::Bool = true
    @in calculate_btn::Bool = false

    @in is_calculating::Bool = false
    @in error_message::String = ""

    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    @out medicaid_caseload_pct::Float64 = 0.0
    @out low_income_utilization_pct::Float64 = 0.0
    @out dsh_index::Float64 = 0.0
    @out estimated_dsh_payment::Float64 = 0.0
    @out dsh_floor::Float64 = 0.0
    @out dsh_ceiling::Float64 = 0.0

    @out total_supplemental::Float64 = 0.0
    @out supplemental_as_pct::Float64 = 0.0
    @out total_medicaid_revenue::Float64 = 0.0
    @out supplemental_detail::String = ""

    @onbutton calculate_btn begin
        is_calculating = true
        error_message = ""
        try
            hosp = FinanceEngine.HospitalCharacteristics(
                hospital_name,
                medicare_cases,
                medicaid_cases,
                uninsured_cases,
                low_income_pct,
                medicaid_bed_days,
                total_bed_days
            )

            medicaid_caseload_pct = FinanceEngine.calculate_medicaid_caseload_percentage(hosp)
            low_income_utilization_pct = FinanceEngine.calculate_low_income_percentage(hosp)

            dsh = FinanceEngine.calculate_dsh_payment(hosp)
            dsh_index = dsh.dsh_index
            estimated_dsh_payment = dsh.estimated_dsh_payment
            dsh_floor = dsh.dsh_payment_floor
            dsh_ceiling = dsh.dsh_payment_ceiling

            impact = FinanceEngine.calculate_supplemental_impacts(
                hosp, base_medicaid_payment,
                include_dsh=include_dsh,
                include_upl=include_upl
            )

            total_supplemental = impact.total_supplemental
            supplemental_as_pct = impact.supplemental_as_pct_base
            total_medicaid_revenue = impact.total_medicaid_revenue

            detail_lines = String[]
            for (prog, amt) in impact.supplemental_programs
                push!(detail_lines, "$(prog): \$$(round(Int, amt))")
            end
            supplemental_detail = join(detail_lines, " | ")
        catch e
            error_message = "Error: $(sprint(showerror, e))"
        finally
            is_calculating = false
        end
    end
end
