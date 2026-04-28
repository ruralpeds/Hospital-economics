"""Telehealth & RPM Financial Valuation Stipple model"""
@app begin
    @in selected_service::String = "99456"
    @in patient_volume::Int = 100
    @in enrolled_rpm_patients::Int = 200
    @in rpm_monthly_cost::Float64 = 45.00
    @in rpm_monthly_reimbursement::Float64 = 55.00
    @in readmission_reduction::Float64 = 0.15

    @in is_calculating::Bool = false
    @in error_message::String = ""

    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @in errors::Vector{String} = String[]

    @out annual_visits::Int = 0
    @out annual_revenue::Float64 = 0.0
    @out annual_costs::Float64 = 0.0
    @out gross_margin_pct::Float64 = 0.0
    @out roi_pct::Float64 = 0.0
    @out payback_months::Float64 = 0.0
    @out break_even_volume::Int = 0

    @out rpm_annual_direct_benefit::Float64 = 0.0
    @out rpm_readmission_avoidance::Float64 = 0.0
    @out rpm_total_value::Float64 = 0.0

    # Loaded services
    available_services::Vector = []

    @onload begin
        try
            fixture_path = joinpath(@__DIR__, "..", "..", "..", "test", "fixtures", "telehealth", "sample_telehealth_services.json")
            services_data = JSON3.read(read(fixture_path), Vector{Dict})
            available_services = services_data
        catch e
            error_message = "Error loading services: $(sprint(showerror, e))"
        end
    end

    @onchange selected_service begin
        is_calculating = true
        error_message = ""
        try
            if !isempty(available_services)
                service_dict = first(filter(s -> s["service_code"] == selected_service, available_services), Dict())
                if !isempty(service_dict)
                    service = FinanceEngine.TelehealthService(
                        service_dict["service_code"],
                        service_dict["service_name"],
                        Symbol(service_dict["service_type"]),
                        service_dict["avg_reimbursement"],
                        service_dict["payer_mix"],
                        service_dict["estimated_monthly_volume"],
                        service_dict["variable_cost_per_visit"],
                        service_dict["fixed_monthly_cost"]
                    )

                    metrics = FinanceEngine.calculate_telehealth_metrics(service, patient_volume)
                    annual_visits = metrics.annual_visits
                    annual_revenue = metrics.annual_revenue
                    annual_costs = metrics.annual_variable_costs + metrics.annual_fixed_costs
                    gross_margin_pct = metrics.gross_margin_pct
                    roi_pct = metrics.roi_pct
                    payback_months = metrics.payback_months
                    break_even_volume = metrics.break_even_volume
                end
            end
        catch e
            error_message = "Error calculating telehealth metrics: $(sprint(showerror, e))"
        finally
            is_calculating = false
        end
    end

    @onchange enrolled_rpm_patients begin
        is_calculating = true
        error_message = ""
        try
            rpm_impact = FinanceEngine.calculate_rpm_financial_impact(
                enrolled_rpm_patients,
                rpm_monthly_cost,
                rpm_monthly_reimbursement,
                readmission_reduction_pct=readmission_reduction
            )
            rpm_annual_direct_benefit = rpm_impact.annual_net_benefit
            rpm_readmission_avoidance = rpm_impact.cost_avoidance_from_readmissions
            rpm_total_value = rpm_impact.total_annual_value
        catch e
            error_message = "Error calculating RPM impact: $(sprint(showerror, e))"
        finally
            is_calculating = false
        end
    end
end
