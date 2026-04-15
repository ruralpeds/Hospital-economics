# ============================================================================
# Input Validation Utilities
# ============================================================================

"""
    validate_hospital(hospital::AbstractHospital) -> (valid::Bool, errors::Vector{String})

Validate that all required hospital fields contain reasonable values.

Returns a tuple of a boolean indicating overall validity and a vector of
error messages describing any problems found.
"""
function validate_hospital(hospital::AbstractHospital)
    errors = String[]

    # Check bed count
    if hasproperty(hospital, :licensed_beds)
        beds = getproperty(hospital, :licensed_beds)
        if beds <= 0
            push!(errors, "Bed count must be positive; got $beds")
        end
        if hospital isa CriticalAccessHospital && beds > 25
            push!(errors, "Critical Access Hospitals are limited to 25 beds; got $beds")
        end
    end

    # Check cost-to-charge ratio
    if hasproperty(hospital, :cost_to_charge_ratio)
        ccr = getproperty(hospital, :cost_to_charge_ratio)
        if ccr <= 0.0 || ccr > 1.0
            push!(errors, "Cost-to-charge ratio must be in (0, 1]; got $ccr")
        end
    end

    # Check case mix index
    if hasproperty(hospital, :case_mix_index)
        cmi = getproperty(hospital, :case_mix_index)
        if cmi <= 0.0
            push!(errors, "Case mix index must be positive; got $cmi")
        end
        if cmi > 5.0
            push!(errors, "Case mix index unusually high (>5.0); got $cmi — verify data")
        end
    end

    # Check wage index
    if hasproperty(hospital, :wage_index)
        wi = getproperty(hospital, :wage_index)
        if wi <= 0.0
            push!(errors, "Wage index must be positive; got $wi")
        end
        if wi > 2.0
            push!(errors, "Wage index unusually high (>2.0); got $wi — verify data")
        end
    end

    return (isempty(errors), errors)
end

"""
    validate_payer_mix(payer_mix::Dict{String,Float64}) -> (valid::Bool, errors::Vector{String})

Validate that a payer mix dictionary has valid proportions summing to
approximately 1.0.
"""
function validate_payer_mix(payer_mix::Dict{String,Float64})
    errors = String[]

    for (payer, share) in payer_mix
        if share < 0.0
            push!(errors, "Payer share for '$payer' is negative: $share")
        end
        if share > 1.0
            push!(errors, "Payer share for '$payer' exceeds 1.0: $share")
        end
    end

    total = sum(values(payer_mix))
    if abs(total - 1.0) > 0.01
        push!(errors, "Payer mix shares sum to $total; expected ≈1.0")
    end

    expected_payers = ["Medicare", "Medicaid", "Commercial", "Self-Pay", "Other"]
    for payer in expected_payers
        if !haskey(payer_mix, payer)
            push!(errors, "Missing expected payer category: '$payer'")
        end
    end

    return (isempty(errors), errors)
end

"""
    validate_payer_mix(pm::PayerMix) -> (valid::Bool, errors::Vector{String})

Validate a PayerMix struct: checks that overall_volume_pct sums to ~1.0,
each contract has a valid payer_type and non-negative rates.
"""
function validate_payer_mix(pm::PayerMix)
    errors = String[]

    valid_types = (:medicare, :medicaid, :commercial, :self_pay, :tricare, :va, :other)

    for c in pm.contracts
        if !(c.payer_type in valid_types)
            push!(errors, "Invalid payer_type :$(c.payer_type) for '$(c.payer_name)'")
        end
        if c.overall_volume_pct < 0.0
            push!(errors, "Negative overall_volume_pct for '$(c.payer_name)': $(c.overall_volume_pct)")
        end
        if c.overall_volume_pct > 1.0
            push!(errors, "overall_volume_pct > 1.0 for '$(c.payer_name)': $(c.overall_volume_pct)")
        end
        if c.denial_rate < 0.0 || c.denial_rate > 1.0
            push!(errors, "denial_rate out of [0,1] for '$(c.payer_name)': $(c.denial_rate)")
        end
        if c.bad_debt_rate < 0.0 || c.bad_debt_rate > 1.0
            push!(errors, "bad_debt_rate out of [0,1] for '$(c.payer_name)': $(c.bad_debt_rate)")
        end
    end

    total_vol = sum(c.overall_volume_pct for c in pm.contracts; init=0.0)
    if abs(total_vol - 1.0) > 0.01
        push!(errors, "PayerMix overall_volume_pct sums to $(round(total_vol, digits=4)); expected ≈1.0")
    end

    return (isempty(errors), errors)
end

"""
    validate_cost_report(report::Dict) -> (valid::Bool, errors::Vector{String})

Validate cost report data for completeness and internal consistency.

Checks that total costs equal the sum of direct and indirect costs,
that cost centers have non-negative values, and that required worksheets
are present.
"""
function validate_cost_report(report::Dict)
    errors = String[]

    # Check required top-level keys
    required_keys = ["provider_id", "fiscal_year_start", "fiscal_year_end",
                     "cost_centers", "total_costs", "total_charges"]
    for key in required_keys
        if !haskey(report, key)
            push!(errors, "Missing required field: '$key'")
        end
    end

    # Validate cost centers
    if haskey(report, "cost_centers")
        for (name, center) in report["cost_centers"]
            if haskey(center, "direct_cost") && center["direct_cost"] < 0
                push!(errors, "Negative direct cost in center '$name': $(center["direct_cost"])")
            end
            if haskey(center, "total_charges") && center["total_charges"] < 0
                push!(errors, "Negative total charges in center '$name': $(center["total_charges"])")
            end
        end
    end

    # Cross-check totals
    if haskey(report, "total_costs") && haskey(report, "total_charges")
        if report["total_costs"] < 0
            push!(errors, "Total costs cannot be negative: $(report["total_costs"])")
        end
        if report["total_charges"] < 0
            push!(errors, "Total charges cannot be negative: $(report["total_charges"])")
        end
        if report["total_charges"] > 0 && report["total_costs"] > report["total_charges"]
            push!(errors, "Total costs exceed total charges — verify cost-to-charge ratio")
        end
    end

    return (isempty(errors), errors)
end

"""
    validate_cost_report(report::CostReport) -> (valid::Bool, errors::Vector{String})

Validate a CostReport struct for completeness and internal consistency.
"""
function validate_cost_report(report::CostReport)
    errors = String[]

    if report.total_costs < 0.0
        push!(errors, "Total costs cannot be negative: $(report.total_costs)")
    end
    if report.total_charges < 0.0
        push!(errors, "Total charges cannot be negative: $(report.total_charges)")
    end
    if report.total_charges > 0.0 && report.total_costs > report.total_charges
        push!(errors, "Total costs exceed total charges — verify cost-to-charge ratio")
    end
    if report.overall_cost_to_charge_ratio < 0.0 || report.overall_cost_to_charge_ratio > 1.5
        push!(errors, "overall_cost_to_charge_ratio out of expected range [0, 1.5]: $(report.overall_cost_to_charge_ratio)")
    end
    if report.fiscal_year_end <= report.fiscal_year_begin
        push!(errors, "fiscal_year_end ($(report.fiscal_year_end)) must be after fiscal_year_begin ($(report.fiscal_year_begin))")
    end
    if report.medicare_allowable_costs < 0.0
        push!(errors, "Medicare allowable costs cannot be negative: $(report.medicare_allowable_costs)")
    end
    for cc in report.cost_centers
        if cc.direct_costs < 0.0
            push!(errors, "Negative direct costs in cost center '$(cc.name)': $(cc.direct_costs)")
        end
        if cc.charges < 0.0
            push!(errors, "Negative charges in cost center '$(cc.name)': $(cc.charges)")
        end
    end

    return (isempty(errors), errors)
end
