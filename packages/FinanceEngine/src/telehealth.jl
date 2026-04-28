"""
A-10: Telehealth & Remote Patient Monitoring Financial Valuation

Comprehensive financial analysis of telehealth and RPM service deployment,
including reimbursement by payer, cost structure, and ROI modeling with
patient volume and engagement scenarios.
"""

struct TelehealthService
    service_code::String  # CPT/billing code
    service_name::String
    service_type::Symbol  # :telehealth, :rpm, :hybrid
    avg_reimbursement::Float64
    payer_mix::Dict{String, Float64}  # payer name => mix %
    estimated_monthly_volume::Int
    variable_cost_per_visit::Float64
    fixed_monthly_cost::Float64
end

struct RPMDevice
    device_name::String
    device_type::Symbol  # :bp_monitor, :pulse_ox, :glucose, :weight_scale, :ecg
    upfront_cost::Float64
    monthly_device_fee::Float64
    integration_cost::Float64
    expected_patient_retention_pct::Float64
end

struct TelehealthMetrics
    annual_visits::Int
    annual_revenue::Float64
    annual_variable_costs::Float64
    annual_fixed_costs::Float64
    annual_gross_margin::Float64
    gross_margin_pct::Float64
    patient_acquisition_cost::Float64
    roi_pct::Float64
    payback_months::Float64
    break_even_volume::Int
end

struct RPMFinancialImpact
    enrolled_patients::Int
    monthly_monitoring_cost::Float64
    monthly_reimbursement::Float64
    monthly_net_benefit::Float64
    annual_net_benefit::Float64
    cost_avoidance_from_readmissions::Float64
    total_annual_value::Float64
    patient_lifetime_value::Float64
end

"""
    calculate_telehealth_metrics(service::TelehealthService, annual_patient_acquisition::Int;
                                 volume_adjustment::Float64=1.0) -> TelehealthMetrics

Calculate comprehensive financial metrics for telehealth service deployment.

Args:
    - service: TelehealthService struct with reimbursement and cost data
    - annual_patient_acquisition: New patients to enroll annually
    - volume_adjustment: Multiplier for volume scaling (1.0 = baseline)

Returns TelehealthMetrics with revenue, costs, margins, ROI, and break-even.
"""
function calculate_telehealth_metrics(service::TelehealthService, annual_patient_acquisition::Int;
                                     volume_adjustment::Float64=1.0)::TelehealthMetrics
    if annual_patient_acquisition < 0 || volume_adjustment <= 0
        error("Invalid inputs: acquisition must be ≥0, adjustment >0")
    end

    # Calculate annual visit volume with adjustment
    annual_visits = Int(round(service.estimated_monthly_volume * 12 * volume_adjustment))

    # Calculate annual revenue (blended payer rate)
    total_monthly_revenue = 0.0
    for (payer, pct) in service.payer_mix
        payer_reimbursement = service.avg_reimbursement * (pct / 100)
        total_monthly_revenue += service.estimated_monthly_volume * payer_reimbursement
    end
    annual_revenue = total_monthly_revenue * 12

    # Calculate annual costs
    annual_variable_costs = service.variable_cost_per_visit * annual_visits
    annual_fixed_costs = service.fixed_monthly_cost * 12

    # Calculate margins
    annual_gross_margin = annual_revenue - annual_variable_costs
    gross_margin_pct = annual_revenue > 0 ? (annual_gross_margin / annual_revenue) * 100 : 0.0

    # Operating profit (margin minus fixed costs)
    annual_operating_profit = annual_gross_margin - annual_fixed_costs

    # Patient acquisition cost (fixed cost allocation per patient)
    patient_acquisition_cost = annual_patient_acquisition > 0 ?
        (annual_fixed_costs / annual_patient_acquisition) : 0.0

    # ROI: operating profit / fixed costs invested
    roi_pct = annual_fixed_costs > 0 ? (annual_operating_profit / annual_fixed_costs) * 100 : 0.0

    # Break-even volume: fixed_costs / contribution_margin_per_visit
    contribution_margin_per_visit = service.avg_reimbursement - service.variable_cost_per_visit
    break_even_volume = contribution_margin_per_visit > 0 ?
        Int(ceil(annual_fixed_costs / (contribution_margin_per_visit / 12))) : 0

    # Payback period (months to recover fixed costs from operating profit)
    monthly_operating_profit = annual_operating_profit / 12
    payback_months = monthly_operating_profit > 0 ?
        annual_fixed_costs / monthly_operating_profit : 999.0

    TelehealthMetrics(
        annual_visits,
        annual_revenue,
        annual_variable_costs,
        annual_fixed_costs,
        annual_gross_margin,
        gross_margin_pct,
        patient_acquisition_cost,
        roi_pct,
        payback_months,
        break_even_volume
    )
end

"""
    calculate_rpm_financial_impact(enrolled_patients::Int, monthly_monitoring_cost::Float64,
                                  monthly_reimbursement::Float64;
                                  readmission_reduction_pct::Float64=0.15,
                                  avg_readmission_cost::Float64=15_000.0) -> RPMFinancialImpact

Calculate financial impact of RPM program including cost avoidance from prevented readmissions.

Args:
    - enrolled_patients: Number of active RPM patients
    - monthly_monitoring_cost: Cost to monitor each patient (devices + care team)
    - monthly_reimbursement: Reimbursement per patient per month
    - readmission_reduction_pct: % reduction in 30-day readmissions from RPM
    - avg_readmission_cost: Average cost per prevented readmission

Returns RPMFinancialImpact with direct revenue, costs, and cost avoidance value.
"""
function calculate_rpm_financial_impact(enrolled_patients::Int, monthly_monitoring_cost::Float64,
                                       monthly_reimbursement::Float64;
                                       readmission_reduction_pct::Float64=0.15,
                                       avg_readmission_cost::Float64=15_000.0)::RPMFinancialImpact
    if enrolled_patients < 0 || monthly_monitoring_cost < 0 || readmission_reduction_pct < 0 || readmission_reduction_pct > 1
        error("Invalid inputs")
    end

    # Direct monthly metrics
    monthly_cost = enrolled_patients * monthly_monitoring_cost
    monthly_revenue = enrolled_patients * monthly_reimbursement
    monthly_net_benefit = monthly_revenue - monthly_cost

    # Annual metrics
    annual_net_benefit = monthly_net_benefit * 12

    # Cost avoidance from readmission reduction
    # Assume ~5% baseline readmission rate for chronic disease cohorts
    baseline_readmissions = enrolled_patients * 0.05
    prevented_readmissions = baseline_readmissions * readmission_reduction_pct
    cost_avoidance_from_readmissions = prevented_readmissions * avg_readmission_cost

    # Patient lifetime value (3-year engagement window typical)
    patient_lifetime_value = monthly_net_benefit * 36  # 3 years

    # Total annual value includes direct margin + cost avoidance
    total_annual_value = annual_net_benefit + cost_avoidance_from_readmissions

    RPMFinancialImpact(
        enrolled_patients,
        monthly_monitoring_cost,
        monthly_reimbursement,
        monthly_net_benefit,
        annual_net_benefit,
        cost_avoidance_from_readmissions,
        total_annual_value,
        patient_lifetime_value
    )
end

"""
    compare_telehealth_scenarios(services::Vector{TelehealthService}, volumes::Vector{Int}) -> DataFrame

Compare financial performance across multiple telehealth service scenarios.

Returns DataFrame with metrics for each service-volume combination for easy comparison.
"""
function compare_telehealth_scenarios(services::Vector{TelehealthService}, volumes::Vector{Int})::DataFrame
    results = []
    for service in services
        for vol in volumes
            metrics = calculate_telehealth_metrics(service, vol)
            push!(results, (
                service_name = service.service_name,
                service_type = String(service.service_type),
                annual_patients = vol,
                annual_visits = metrics.annual_visits,
                annual_revenue = metrics.annual_revenue,
                annual_costs = metrics.annual_variable_costs + metrics.annual_fixed_costs,
                annual_profit = metrics.annual_gross_margin - metrics.annual_fixed_costs,
                gross_margin_pct = metrics.gross_margin_pct,
                roi_pct = metrics.roi_pct,
                payback_months = metrics.payback_months
            ))
        end
    end
    DataFrame(results)
end
