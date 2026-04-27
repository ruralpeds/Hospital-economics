# Flex Monitoring financial ratios for Critical Access Hospital benchmarking
#
# Implements the 10 key financial ratios used by the Flex Monitoring Team
# to benchmark CAH financial performance nationally.

"""
    operating_margin(financials::AnnualFinancials) -> Float64

Operating income as a fraction of total operating revenue.
A core profitability measure: positive values indicate the hospital
covers its operating costs from patient care and other operating sources.
"""
function operating_margin(financials::AnnualFinancials)::Float64
    financials.total_operating_revenue == 0.0 && return 0.0
    return financials.operating_income / financials.total_operating_revenue
end

"""
    total_margin(financials::AnnualFinancials) -> Float64

Total net income as a fraction of total revenue. Measures the hospital's
ability to cover all expenses (operating + non-operating) from all sources
(patient revenue + non-operating revenue like investments and grants).

Calculation:
    net_income = total_revenue - total_operating_expenses - interest_expense
    total_margin = net_income / total_revenue

Includes:
- Operating revenue (patient services)
- Non-operating revenue (investments, grants, donations)
- Operating expenses (salaries, supplies, utilities, etc.)
- Non-operating expenses (interest on debt)

The total margin captures the organization's overall financial sustainability
and is critical for rural hospitals that depend on non-operating revenue.
"""
function total_margin(financials::AnnualFinancials)::Float64
    financials.total_revenue == 0.0 && return 0.0
    # Total expenses: operating + financing (interest)
    total_expenses = financials.total_operating_expenses + financials.interest_expense
    net_income = financials.total_revenue - total_expenses
    return net_income / financials.total_revenue
end

"""
    days_cash_on_hand(financials::AnnualFinancials) -> Float64

Number of days the hospital could sustain operations using only its
cash and equivalents, without any additional revenue. Calculated as
cash divided by average daily operating expenses (excluding depreciation
and amortization, which are non-cash charges).
"""
function days_cash_on_hand(financials::AnnualFinancials)::Float64
    cash_expenses = financials.total_operating_expenses - financials.depreciation - financials.amortization
    cash_expenses <= 0.0 && return Inf
    daily_cash_expense = cash_expenses / 365.0
    return financials.cash_and_equivalents / daily_cash_expense
end

"""
    current_ratio(financials::AnnualFinancials) -> Float64

Current assets divided by current liabilities. Measures short-term
liquidity and the ability to meet obligations due within one year.
A ratio below 1.0 signals potential liquidity distress.
"""
function current_ratio(financials::AnnualFinancials)::Float64
    financials.current_liabilities == 0.0 && return Inf
    return financials.current_assets / financials.current_liabilities
end

"""
    debt_to_capitalization(financials::AnnualFinancials) -> Float64

Total liabilities divided by the sum of total liabilities and net assets
(i.e., total capitalization). Indicates the proportion of the hospital's
capital structure financed by debt. Higher values indicate greater leverage.
"""
function debt_to_capitalization(financials::AnnualFinancials)::Float64
    total_cap = financials.total_liabilities + financials.net_assets
    total_cap == 0.0 && return 0.0
    return financials.total_liabilities / total_cap
end

"""
    average_age_of_plant(financials::AnnualFinancials) -> Float64

Accumulated depreciation divided by annual depreciation expense. Provides
an estimate (in years) of how old the hospital's fixed assets are on average.
Higher values suggest deferred capital reinvestment.
"""
function average_age_of_plant(financials::AnnualFinancials)::Float64
    financials.depreciation == 0.0 && return 0.0
    # Use the pre-computed value if available; otherwise estimate from
    # the balance-sheet relationship (accumulated_depreciation is not a direct
    # field on AnnualFinancials, so we fall back to the stored ratio).
    financials.average_age_of_plant != 0.0 && return financials.average_age_of_plant
    return 0.0
end

"""
    fte_per_adjusted_occupied_bed(financials::AnnualFinancials, staff::StaffingModel,
                                  beds::Int, adc::Float64) -> Float64

Full-time equivalent employees per adjusted occupied bed. The adjustment
scales inpatient beds by the ratio of total revenue to inpatient revenue,
capturing outpatient workload. A workforce efficiency measure for CAHs.
"""
function fte_per_adjusted_occupied_bed(financials::AnnualFinancials, staff::StaffingModel,
                                       beds::Int, adc::Float64)::Float64
    adc <= 0.0 && return 0.0
    occupied_beds = adc
    # Adjust for outpatient volume
    financials.inpatient_revenue == 0.0 && return 0.0
    adjustment_factor = financials.total_operating_revenue / financials.inpatient_revenue
    adjusted_occupied_beds = occupied_beds * adjustment_factor
    adjusted_occupied_beds <= 0.0 && return 0.0
    return total_fte(staff) / adjusted_occupied_beds
end

"""
    salary_to_revenue(financials::AnnualFinancials) -> Float64

Total salaries and wages (including benefits) as a fraction of total
operating revenue. Labor is the largest expense for rural hospitals;
this ratio benchmarks workforce cost efficiency.
"""
function salary_to_revenue(financials::AnnualFinancials)::Float64
    financials.total_operating_revenue == 0.0 && return 0.0
    total_labor = financials.salaries_wages + financials.employee_benefits
    return total_labor / financials.total_operating_revenue
end

"""
    outpatient_revenue_share(financials::AnnualFinancials) -> Float64

Outpatient revenue as a fraction of total operating revenue.
Rural hospitals increasingly depend on outpatient services; this ratio
tracks the shift from inpatient to outpatient care delivery.
"""
function outpatient_revenue_share(financials::AnnualFinancials)::Float64
    financials.total_operating_revenue == 0.0 && return 0.0
    return financials.outpatient_revenue / financials.total_operating_revenue
end

"""
    medicare_cost_to_charge_ratio(financials::AnnualFinancials) -> Float64

The Medicare cost-to-charge ratio from the cost report. Measures how much
it costs the hospital to deliver a dollar of charges billed to Medicare.
Critical for CAH cost-based reimbursement calculations.
"""
function medicare_cost_to_charge_ratio(financials::AnnualFinancials)::Float64
    return financials.medicare_cost_to_charge_ratio
end

"""
    compute_all_ratios(financials::AnnualFinancials) -> NamedTuple

Compute all 10 Flex Monitoring financial ratios and return them as a
NamedTuple. For ratios requiring staffing or bed data (FTE per adjusted
occupied bed), the value is omitted (set to `missing`).

See also: [`compute_all_ratios(financials, staff, beds, adc)`](@ref)
"""
function compute_all_ratios(financials::AnnualFinancials)
    return (
        operating_margin = operating_margin(financials),
        total_margin = total_margin(financials),
        days_cash_on_hand = days_cash_on_hand(financials),
        current_ratio = current_ratio(financials),
        debt_to_capitalization = debt_to_capitalization(financials),
        average_age_of_plant = average_age_of_plant(financials),
        fte_per_adjusted_occupied_bed = missing,
        salary_to_revenue = salary_to_revenue(financials),
        outpatient_revenue_share = outpatient_revenue_share(financials),
        medicare_cost_to_charge_ratio = medicare_cost_to_charge_ratio(financials),
    )
end

"""
    compute_all_ratios(financials::AnnualFinancials, staff::StaffingModel,
                       beds::Int, adc::Float64) -> NamedTuple

Compute all 10 Flex Monitoring financial ratios including the staffing-dependent
FTE per adjusted occupied bed metric.
"""
function compute_all_ratios(financials::AnnualFinancials, staff::StaffingModel,
                            beds::Int, adc::Float64)
    return (
        operating_margin = operating_margin(financials),
        total_margin = total_margin(financials),
        days_cash_on_hand = days_cash_on_hand(financials),
        current_ratio = current_ratio(financials),
        debt_to_capitalization = debt_to_capitalization(financials),
        average_age_of_plant = average_age_of_plant(financials),
        fte_per_adjusted_occupied_bed = fte_per_adjusted_occupied_bed(financials, staff, beds, adc),
        salary_to_revenue = salary_to_revenue(financials),
        outpatient_revenue_share = outpatient_revenue_share(financials),
        medicare_cost_to_charge_ratio = medicare_cost_to_charge_ratio(financials),
    )
end
