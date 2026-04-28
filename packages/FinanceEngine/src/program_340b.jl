"""
A-09: 340B Drug Program Savings Estimator

Implements federal 340B drug purchasing discount analysis for rural hospitals.
Supports formulary loading, savings estimation with managed care caps, and
budget-constrained drug mix optimization.
"""

using DataFrames, CSV

struct Drug340B
    ndc::String
    description::String
    avg_wholesale_price::Float64  # AWP (manufacturer list price)
    ceiling_price::Float64        # 340B ceiling price (max price drug can sell at)
    hospital_acquisition_cost::Float64  # Estimated cost hospital pays
    estimated_monthly_usage::Float64    # Monthly unit consumption
end

struct DrugProgramMetrics
    total_annual_usage_units::Float64
    avg_discount_pct::Float64
    estimated_annual_savings::Float64
    ceiling_vs_mac_ratio::Float64
    managed_care_discount_applicability::Float64  # % of usage subject to MAC discounts
end

struct DrugOptimizationResult
    optimized_drugs::Vector{String}
    total_annual_savings::Float64
    budget_remaining::Float64
    annual_units_used::Float64
    average_discount_pct::Float64
end

"""
    load_340b_formulary(fixture_path::String) -> DataFrame

Load 340B drug formulary from CSV fixture.
Expected columns: ndc, description, avg_wholesale_price, ceiling_price, hospital_acquisition_cost, estimated_monthly_usage
"""
function load_340b_formulary(fixture_path::String)::DataFrame
    CSV.read(fixture_path, DataFrame)
end

"""
    estimate_340b_savings(drugs::Vector{Drug340B}; managed_care_cap::Float64=0.15) -> DrugProgramMetrics

Estimate total annual 340B program savings.

Args:
    - drugs: Vector of Drug340B structs
    - managed_care_cap: Max discount applicable to managed care beneficiaries (default 15%)

Returns:
    DrugProgramMetrics with savings aggregates and applicability metrics
"""
function estimate_340b_savings(drugs::Vector{Drug340B}; managed_care_cap::Float64=0.15)::DrugProgramMetrics
    if isempty(drugs)
        return DrugProgramMetrics(0.0, 0.0, 0.0, 0.0, 0.0)
    end

    total_units = sum(d.estimated_monthly_usage * 12 for d in drugs)
    total_savings = 0.0
    total_discounts = 0.0
    managed_care_eligible_units = 0.0

    for drug in drugs
        annual_units = drug.estimated_monthly_usage * 12
        # Discount per unit = (AWP - Ceiling) or (AWP - Hospital Acquisition Cost), whichever is realistic
        unit_discount = max(drug.avg_wholesale_price - drug.ceiling_price,
                           drug.avg_wholesale_price - drug.hospital_acquisition_cost)
        annual_drug_savings = unit_discount * annual_units

        # Apply managed care cap: fraction of savings subject to MAC discount limitations
        mac_applicable_savings = min(annual_drug_savings, annual_units * drug.avg_wholesale_price * managed_care_cap)

        total_savings += annual_drug_savings
        total_discounts += unit_discount
        # Estimate that ~60% of usage is managed care (variable by formulary)
        managed_care_eligible_units += annual_units * 0.6
    end

    avg_discount = total_units > 0 ? total_discounts / total_units : 0.0
    ceiling_ratio = mean(d.ceiling_price / d.avg_wholesale_price for d in drugs)
    mac_applicability = total_units > 0 ? managed_care_eligible_units / total_units : 0.0

    DrugProgramMetrics(
        total_units,
        avg_discount * 100,  # As percentage
        total_savings,
        ceiling_ratio,
        mac_applicability
    )
end

"""
    optimize_drug_mix(drugs::Vector{Drug340B}, budget::Float64; managed_care_cap::Float64=0.15) -> DrugOptimizationResult

Select optimal drug mix under budget constraint via knapsack (greedy by savings/cost).

Uses greedy approach: rank by savings per dollar spent, include highest-return drugs until budget exhausted.
"""
function optimize_drug_mix(drugs::Vector{Drug340B}, budget::Float64; managed_care_cap::Float64=0.15)::DrugOptimizationResult
    if isempty(drugs) || budget <= 0
        return DrugOptimizationResult(String[], 0.0, budget, 0.0, 0.0)
    end

    # Calculate savings and cost per drug
    drug_metrics = []
    for (i, drug) in enumerate(drugs)
        annual_units = drug.estimated_monthly_usage * 12
        unit_discount = max(drug.avg_wholesale_price - drug.ceiling_price,
                           drug.avg_wholesale_price - drug.hospital_acquisition_cost)
        annual_savings = unit_discount * annual_units
        annual_cost = drug.hospital_acquisition_cost * annual_units

        if annual_cost > 0
            roi = annual_savings / annual_cost
            push!(drug_metrics, (
                index=i,
                ndc=drug.ndc,
                annual_savings=annual_savings,
                annual_cost=annual_cost,
                roi=roi,
                units=annual_units
            ))
        end
    end

    # Sort by ROI descending
    sort!(drug_metrics, by=x->x.roi, rev=true)

    # Greedy knapsack: select highest-ROI drugs until budget exhausted
    selected_ndcs = String[]
    total_savings = 0.0
    total_units = 0.0
    budget_remaining = budget
    total_discount = 0.0

    for metric in drug_metrics
        if metric.annual_cost <= budget_remaining
            push!(selected_ndcs, metric.ndc)
            budget_remaining -= metric.annual_cost
            total_savings += metric.annual_savings
            total_units += metric.units
            total_discount += (metric.annual_savings / metric.units) if metric.units > 0 else 0.0
        end
    end

    avg_discount_pct = total_units > 0 ? (total_discount / total_units) * 100 : 0.0

    DrugOptimizationResult(
        selected_ndcs,
        total_savings,
        budget_remaining,
        total_units,
        avg_discount_pct
    )
end
