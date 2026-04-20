# ============================================================================
# FINANCIAL IMPACT MODELING (Module 5)
# ============================================================================
# 3-year financial projections for hospital and payer under different contracts

using Printf

# ============================================================================
# ANNUAL FINANCIAL SUMMARY
# ============================================================================

"""
    AnnualContractFinancials

Annual financial summary under a payer contract for one year.
Includes hospital and payer perspectives.

# Hospital Perspective
- hospital_revenue::Float64: Total revenue from payer
- hospital_costs::Float64: Total operating costs
- hospital_margin::Float64: Profit/loss (revenue - costs)
- quality_bonus_hospital::Float64: Payment bonus from quality performance
- risk_adjustment_hospital::Float64: Adjustment from risk sharing or loss sharing

# Payer Perspective
- payer_total_cost::Float64: Total amount paid to hospital
- payer_savings_vs_benchmark::Float64: Savings vs. FFS baseline
- shared_savings_to_hospital::Float64: Shared savings paid to hospital (if applicable)
- payer_net_cost::Float64: Net cost after shared savings

# Volume Metrics
- cases::Int: Number of cases/episodes
- admissions::Int: Number of admissions
- readmissions::Int: Number of 30-day readmissions
"""
struct AnnualContractFinancials
    year::Int

    # Hospital perspective
    hospital_revenue::Float64
    hospital_costs::Float64
    hospital_margin::Float64
    quality_bonus_hospital::Float64
    risk_adjustment_hospital::Float64

    # Payer perspective
    payer_total_cost::Float64
    payer_savings_vs_benchmark::Float64
    shared_savings_to_hospital::Float64
    payer_net_cost::Float64

    # Volume metrics
    cases::Int
    admissions::Int
    readmissions::Int
end

function AnnualContractFinancials(;
    year::Int = 2026,
    hospital_revenue::Float64 = 0.0,
    hospital_costs::Float64 = 0.0,
    hospital_margin::Float64 = 0.0,
    quality_bonus_hospital::Float64 = 0.0,
    risk_adjustment_hospital::Float64 = 0.0,
    payer_total_cost::Float64 = 0.0,
    payer_savings_vs_benchmark::Float64 = 0.0,
    shared_savings_to_hospital::Float64 = 0.0,
    payer_net_cost::Float64 = 0.0,
    cases::Int = 0,
    admissions::Int = 0,
    readmissions::Int = 0
)
    AnnualContractFinancials(
        year, hospital_revenue, hospital_costs, hospital_margin,
        quality_bonus_hospital, risk_adjustment_hospital,
        payer_total_cost, payer_savings_vs_benchmark, shared_savings_to_hospital, payer_net_cost,
        cases, admissions, readmissions
    )
end

# ============================================================================
# 3-YEAR CONTRACT ANALYSIS
# ============================================================================

"""
    ThreeYearContractAnalysis

Comprehensive 3-year financial analysis for a payer contract.
Includes annual breakdowns and cumulative metrics.

# Annual Financials
- year1::AnnualContractFinancials: Year 1 (typically 2026)
- year2::AnnualContractFinancials: Year 2 (typically 2027)
- year3::AnnualContractFinancials: Year 3 (typically 2028)

# Cumulative Metrics (sum of 3 years)
- total_hospital_margin::Float64: Total profit across 3 years
- total_payer_savings::Float64: Total savings vs. FFS baseline
- roi_for_hospital::Float64: Return on investment (% return on initial investment)
- roi_for_payer::Float64: Return for payer (% reduction in costs)

# Decision Support
- recommendation::String: "Favorable", "Unfavorable", or "Neutral"
- contract_name::String: Name of the contract
- contract_type::String: Type (FFS, Capitation, Bundled, etc.)
"""
struct ThreeYearContractAnalysis
    contract_name::String
    contract_type::String

    year1::AnnualContractFinancials
    year2::AnnualContractFinancials
    year3::AnnualContractFinancials

    # Cumulative
    total_hospital_margin::Float64
    total_payer_savings::Float64
    roi_for_hospital::Float64
    roi_for_payer::Float64

    recommendation::String
end

function ThreeYearContractAnalysis(;
    contract_name::String = "Contract",
    contract_type::String = "Unknown",
    year1::AnnualContractFinancials = AnnualContractFinancials(),
    year2::AnnualContractFinancials = AnnualContractFinancials(),
    year3::AnnualContractFinancials = AnnualContractFinancials(),
    total_hospital_margin::Float64 = 0.0,
    total_payer_savings::Float64 = 0.0,
    roi_for_hospital::Float64 = 0.0,
    roi_for_payer::Float64 = 0.0,
    recommendation::String = "Neutral"
)
    ThreeYearContractAnalysis(
        contract_name, contract_type,
        year1, year2, year3,
        total_hospital_margin, total_payer_savings, roi_for_hospital, roi_for_payer,
        recommendation
    )
end

# ============================================================================
# FORMATTING
# ============================================================================

"""
    format_contract_analysis(analysis::ThreeYearContractAnalysis)::String

Format contract analysis as human-readable report.
"""
function format_contract_analysis(analysis::ThreeYearContractAnalysis)::String
    io = IOBuffer()

    println(io, "╔════════════════════════════════════════════════════════════════════╗")
    println(io, "║               $(analysis.contract_type) CONTRACT ANALYSIS")
    println(io, "╚════════════════════════════════════════════════════════════════════╝")
    println(io, "")

    # Header
    println(io, "Contract: $(analysis.contract_name)")
    println(io, "Recommendation: $(analysis.recommendation)")
    println(io, "")

    # Hospital Perspective
    println(io, "──── HOSPITAL PERSPECTIVE ──────────────────────────────────────────")
    println(io, "3-Year Margin:              USD \$(format(analysis.total_hospital_margin, 0))")
    println(io, "Year 1 Margin:              USD \$(format(analysis.year1.hospital_margin, 0))")
    println(io, "Year 2 Margin:              USD \$(format(analysis.year2.hospital_margin, 0))")
    println(io, "Year 3 Margin:              USD \$(format(analysis.year3.hospital_margin, 0))")
    println(io, "Return on Investment:       $(round(analysis.roi_for_hospital * 100, digits=1))%")
    println(io, "")

    # Payer Perspective
    println(io, "──── PAYER PERSPECTIVE ─────────────────────────────────────────────")
    println(io, "3-Year Savings vs FFS:      USD \$(format(analysis.total_payer_savings, 0))")
    println(io, "Year 1 Savings:             USD \$(format(analysis.year1.payer_savings_vs_benchmark, 0))")
    println(io, "Year 2 Savings:             USD \$(format(analysis.year2.payer_savings_vs_benchmark, 0))")
    println(io, "Year 3 Savings:             USD \$(format(analysis.year3.payer_savings_vs_benchmark, 0))")
    println(io, "Payer ROI:                  $(round(analysis.roi_for_payer * 100, digits=1))%")
    println(io, "")

    # Summary
    println(io, "──── SUMMARY ──────────────────────────────────────────────────────")
    total_hospital_cost = analysis.year1.hospital_costs + analysis.year2.hospital_costs + analysis.year3.hospital_costs
    total_hospital_revenue = analysis.year1.hospital_revenue + analysis.year2.hospital_revenue + analysis.year3.hospital_revenue
    total_payer_cost = analysis.year1.payer_total_cost + analysis.year2.payer_total_cost + analysis.year3.payer_total_cost
    total_cases = analysis.year1.cases + analysis.year2.cases + analysis.year3.cases

    println(io, "Total Revenue (Hospital):   USD \$(format(total_hospital_revenue, 0))")
    println(io, "Total Costs (Hospital):     USD \$(format(total_hospital_cost, 0))")
    println(io, "Total Cost (Payer):         USD \$(format(total_payer_cost, 0))")
    println(io, "Total Cases:                $(total_cases)")
    println(io, "")

    return String(take!(io))
end

function format(value::Real, decimals::Int)::String
    if value >= 1_000_000
        return "\$(round(value/1_000_000, digits=1))M"
    elseif value >= 1_000
        return "\$(round(value/1_000, digits=0))K"
    else
        return "\$(round(value, digits=decimals))"
    end
end

"""
    format_annual_financials(financials::AnnualContractFinancials)::String

Format annual financial summary as readable text.
"""
function format_annual_financials(financials::AnnualContractFinancials)::String
    io = IOBuffer()

    println(io, "Year $(financials.year):")
    println(io, "  Hospital Margin:        USD \$(format(financials.hospital_margin, 0))")
    println(io, "  Hospital Cases:         $(financials.cases)")
    println(io, "  Payer Net Cost:         USD \$(format(financials.payer_net_cost, 0))")
    println(io, "  Payer Savings vs FFS:   USD \$(format(financials.payer_savings_vs_benchmark, 0))")

    return String(take!(io))
end

# ============================================================================
# COMPARISON UTILITIES
# ============================================================================

"""
    compare_contracts(analyses::Vector{ThreeYearContractAnalysis})::String

Compare multiple contract analyses side-by-side.
"""
function compare_contracts(analyses::Vector{ThreeYearContractAnalysis})::String
    io = IOBuffer()

    println(io, "╔════════════════════════════════════════════════════════════════════╗")
    println(io, "║                     CONTRACT COMPARISON                           ║")
    println(io, "╚════════════════════════════════════════════════════════════════════╝")
    println(io, "")

    # Table header
    println(io, "Contract Type | 3-Yr Hospital | Hospital ROI | 3-Yr Payer | Payer ROI | Recommendation")
    println(io, "─"^100)

    # Table rows
    for analysis in analyses
        contract_type = length(analysis.contract_type) > 12 ? analysis.contract_type[1:12] : analysis.contract_type
        hospital_margin = format(analysis.total_hospital_margin, 0)
        hospital_roi = "$(round(analysis.roi_for_hospital * 100, digits=1))%"
        payer_savings = format(analysis.total_payer_savings, 0)
        payer_roi = "$(round(analysis.roi_for_payer * 100, digits=1))%"
        recommendation = analysis.recommendation

        # Format row using string interpolation
        row = @sprintf "%-13s | %-13s | %-11s | %-9s | %-8s | %s\n" contract_type hospital_margin hospital_roi payer_savings payer_roi recommendation
        print(io, row)
    end

    println(io, "")

    return String(take!(io))
end
