# Value-Based Care Transition for Rural Hospital Economics Simulator
#
# Models shared savings/loss calculations for Medicare ACO programs including
# MSSP Basic/Enhanced and ACO REACH variants. Projects multi-year financial
# impact of transitioning from fee-for-service to value-based arrangements.

"""
    VBCParams

Parameters for a value-based care shared savings/loss calculation.

# Fields
- `model_type::Symbol`: ACO model (:mssp_basic, :mssp_enhanced, :aco_lead, :aco_flex)
- `total_cost_of_care::Float64`: actual total cost of care for the period
- `benchmark::Float64`: CMS-assigned spending benchmark
- `patient_panel_size::Int`: number of attributed beneficiaries
- `quality_score::Float64`: composite quality score 0.0-1.0 (default 0.5)
- `risk_track::Symbol`: :one_sided (savings only) or :two_sided (savings and losses)
- `shared_savings_rate::Float64`: fraction of savings retained (default 0.50)
- `shared_loss_rate::Float64`: fraction of losses owed back (default 0.30)
- `min_savings_rate::Float64`: minimum savings rate to qualify (default 0.02)
- `care_management_investment::Float64`: annual care management spending
"""
@kwdef struct VBCParams
    model_type::Symbol = :mssp_basic
    total_cost_of_care::Float64
    benchmark::Float64
    patient_panel_size::Int
    quality_score::Float64 = 0.5
    risk_track::Symbol = :one_sided
    shared_savings_rate::Float64 = 0.50
    shared_loss_rate::Float64 = 0.30
    min_savings_rate::Float64 = 0.02
    care_management_investment::Float64 = 0.0
end

"""
    VBCResult

Results of a value-based care reconciliation.

# Fields
- `gross_savings::Float64`: benchmark minus actual cost (negative = losses)
- `meets_minimum_savings::Bool`: whether savings rate exceeds MSR
- `shared_savings_payment::Float64`: payment received from CMS for savings
- `shared_loss_payment::Float64`: payment owed to CMS for losses
- `net_vbc_income::Float64`: shared savings minus shared losses
- `care_management_cost::Float64`: care management investment
- `net_financial_impact::Float64`: net VBC income minus care management cost
- `savings_rate::Float64`: gross savings as fraction of benchmark
- `per_beneficiary_savings::Float64`: gross savings per attributed beneficiary
"""
@kwdef struct VBCResult
    gross_savings::Float64
    meets_minimum_savings::Bool
    shared_savings_payment::Float64
    shared_loss_payment::Float64
    net_vbc_income::Float64
    care_management_cost::Float64
    net_financial_impact::Float64
    savings_rate::Float64
    per_beneficiary_savings::Float64
end

function Base.show(io::IO, r::VBCResult)
    status = r.net_financial_impact >= 0 ? "gain" : "loss"
    print(io, "VBCResult(savings_rate=$(round(r.savings_rate * 100, digits=1))%, net_$(status)=\$$(round(Int, abs(r.net_financial_impact))))")
end

"""
    calculate_vbc_outcome(params::VBCParams) -> VBCResult

Compute shared savings or losses for a value-based care arrangement.

1. Gross savings = benchmark - total cost of care.
2. Savings rate = gross savings / benchmark.
3. If savings rate >= MSR, shared savings = gross_savings * shared_savings_rate * quality_score.
4. If two-sided and losses exist, shared losses = |gross_savings| * shared_loss_rate
   (capped at benchmark percentage based on model type).
5. Net against care management investment.
"""
function calculate_vbc_outcome(params::VBCParams)::VBCResult
    params.model_type in (:mssp_basic, :mssp_enhanced, :aco_lead, :aco_flex) || error("model_type must be one of :mssp_basic, :mssp_enhanced, :aco_lead, :aco_flex; got $(params.model_type)")
    params.benchmark > 0.0 || error("Benchmark must be positive; got $(params.benchmark)")
    params.patient_panel_size > 0 || error("Patient panel size must be positive; got $(params.patient_panel_size)")
    params.risk_track in (:one_sided, :two_sided) || error("risk_track must be :one_sided or :two_sided; got $(params.risk_track)")
    params.total_cost_of_care >= 0.0 || error("total_cost_of_care must be non-negative; got $(params.total_cost_of_care)")
    0.0 <= params.quality_score <= 1.0 || error("quality_score must be between 0 and 1; got $(params.quality_score)")
    0.0 <= params.shared_savings_rate <= 1.0 || error("shared_savings_rate must be between 0 and 1; got $(params.shared_savings_rate)")
    0.0 <= params.shared_loss_rate <= 1.0 || error("shared_loss_rate must be between 0 and 1; got $(params.shared_loss_rate)")
    0.0 <= params.min_savings_rate <= 1.0 || error("min_savings_rate must be between 0 and 1; got $(params.min_savings_rate)")
    params.care_management_investment >= 0.0 || error("care_management_investment must be non-negative; got $(params.care_management_investment)")

    gross_savings = params.benchmark - params.total_cost_of_care
    savings_rate = gross_savings / params.benchmark
    per_bene = gross_savings / params.patient_panel_size

    meets_msr = savings_rate >= params.min_savings_rate

    # Shared savings calculation
    shared_savings = 0.0
    if gross_savings > 0.0 && meets_msr
        # Quality score scales the sharing rate
        effective_rate = params.shared_savings_rate * clamp(params.quality_score, 0.0, 1.0)
        shared_savings = gross_savings * effective_rate
    end

    # Shared loss calculation (two-sided only)
    shared_losses = 0.0
    if params.risk_track == :two_sided && gross_savings < 0.0
        # Loss cap as percentage of benchmark varies by model
        loss_cap_pct = if params.model_type in (:mssp_enhanced, :aco_lead)
            0.15
        else
            0.08
        end
        max_loss = params.benchmark * loss_cap_pct
        raw_loss = abs(gross_savings) * params.shared_loss_rate
        shared_losses = min(raw_loss, max_loss)
    end

    net_vbc = shared_savings - shared_losses
    net_impact = net_vbc - params.care_management_investment

    return VBCResult(
        gross_savings = gross_savings,
        meets_minimum_savings = meets_msr,
        shared_savings_payment = shared_savings,
        shared_loss_payment = shared_losses,
        net_vbc_income = net_vbc,
        care_management_cost = params.care_management_investment,
        net_financial_impact = net_impact,
        savings_rate = savings_rate,
        per_beneficiary_savings = per_bene,
    )
end

"""
    vbc_transition_timeline(params::VBCParams; years::Int=5) -> Vector{NamedTuple}

Project year-by-year VBC financial outcomes assuming care management investment
ramps up over the first 3 years and savings improve as population health
management matures. Year 1 captures 30% of potential savings, year 2 captures
60%, and year 3+ captures 90%.
"""
function vbc_transition_timeline(params::VBCParams; years::Int = 5)::Vector{NamedTuple}
    years > 0 || error("years must be positive; got $years")
    params.benchmark > 0.0 || error("Benchmark must be positive; got $(params.benchmark)")
    params.patient_panel_size > 0 || error("Patient panel size must be positive; got $(params.patient_panel_size)")

    # Savings maturity curve: fraction of achievable savings realized each year
    maturity = [0.30, 0.60, 0.90, 0.95, 1.0]

    # Care management investment ramp: 60% year 1, 85% year 2, 100% year 3+
    cm_ramp = [0.60, 0.85, 1.0, 1.0, 1.0]

    timeline = NamedTuple[]
    for yr in 1:years
        idx = min(yr, length(maturity))
        mat = maturity[idx]
        cm_frac = cm_ramp[min(yr, length(cm_ramp))]

        # Adjust actual cost to reflect improving care management
        potential_savings = params.benchmark - params.total_cost_of_care
        yr_actual = if potential_savings > 0
            # Maturity fraction of savings realized: costs decrease toward benchmark
            params.total_cost_of_care - (potential_savings * mat)
        else
            # When over benchmark, maturity reduces cost overruns
            params.total_cost_of_care + abs(potential_savings) * (1.0 - mat)
        end

        yr_cm_cost = params.care_management_investment * cm_frac

        yr_params = VBCParams(
            model_type = params.model_type,
            total_cost_of_care = yr_actual,
            benchmark = params.benchmark,
            patient_panel_size = params.patient_panel_size,
            quality_score = min(1.0, params.quality_score + 0.05 * (yr - 1)),
            risk_track = params.risk_track,
            shared_savings_rate = params.shared_savings_rate,
            shared_loss_rate = params.shared_loss_rate,
            min_savings_rate = params.min_savings_rate,
            care_management_investment = yr_cm_cost,
        )

        result = calculate_vbc_outcome(yr_params)

        push!(timeline, (
            year = yr,
            total_cost_of_care = yr_actual,
            savings_rate = result.savings_rate,
            shared_savings = result.shared_savings_payment,
            shared_losses = result.shared_loss_payment,
            care_management_cost = yr_cm_cost,
            net_financial_impact = result.net_financial_impact,
        ))
    end

    return timeline
end
