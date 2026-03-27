# ============================================================================
# Tests for cost report step-down allocation and reimbursement calculations
# ============================================================================

using Test

# Include constants
include(joinpath(@__DIR__, "..", "src", "utils", "constants.jl"))
using .Constants

@testset "Reimbursement & Cost Report" begin

    # -----------------------------------------------------------------------
    @testset "Constants sanity checks" begin
        @test Constants.SEQUESTRATION_RATE == 0.02
        @test Constants.CAH_COST_REIMBURSEMENT_RATE == 1.01
        @test Constants.REH_OPPS_ADDON == 0.05
        @test Constants.REH_MONTHLY_FACILITY_PAYMENT > 270_000.0
        @test Constants.REH_ANNUAL_FACILITY_PAYMENT ==
              Constants.REH_MONTHLY_FACILITY_PAYMENT * 12
        @test Constants.IPPS_BASE_RATE > 6000.0
        @test Constants.OPPS_CONVERSION_FACTOR > 80.0
        @test Constants.BAD_DEBT_REIMBURSEMENT_RATE == 0.65
        @test Constants.WAGE_INDEX_NATIONAL_AVG == 1.0
    end

    # -----------------------------------------------------------------------
    @testset "Cost report step-down allocation" begin
        # Simplified step-down: overhead cost centers allocate to revenue centers
        # based on allocation statistics (e.g., square footage, FTEs)
        #
        # Example: 3 overhead centers -> 2 revenue centers
        # Overhead: Administration, Plant Operations, Housekeeping
        # Revenue: Nursing, Emergency Department

        overhead_costs = Dict(
            "Administration" => 500_000.0,
            "Plant Operations" => 300_000.0,
            "Housekeeping"   => 200_000.0,
        )

        # Allocation bases (proportion of each overhead going to each revenue center)
        # Administration allocated by FTEs: Nursing 60%, ED 30%, remaining overhead 10%
        # Plant Ops allocated by sq ft: Nursing 50%, ED 40%, Housekeeping 10%
        # Housekeeping allocated by sq ft: Nursing 55%, ED 45%

        # Step 1: Allocate Administration
        admin_total = overhead_costs["Administration"]
        admin_to_nursing = admin_total * 0.60
        admin_to_ed = admin_total * 0.30
        admin_to_remaining = admin_total * 0.10  # flows to other overhead

        @test admin_to_nursing == 300_000.0
        @test admin_to_ed == 150_000.0
        @test admin_to_remaining == 50_000.0

        # Step 2: Allocate Plant Ops (original + share from admin)
        plant_adjusted = overhead_costs["Plant Operations"] + admin_to_remaining * 0.5
        plant_to_nursing = plant_adjusted * 0.50
        plant_to_ed = plant_adjusted * 0.40
        plant_to_housekeeping = plant_adjusted * 0.10

        @test plant_adjusted == 325_000.0
        @test plant_to_nursing == 162_500.0
        @test isapprox(plant_to_ed, 130_000.0; atol=1.0)
        @test plant_to_housekeeping == 32_500.0

        # Step 3: Allocate Housekeeping (original + shares from above)
        hk_adjusted = overhead_costs["Housekeeping"] + admin_to_remaining * 0.5 + plant_to_housekeeping
        hk_to_nursing = hk_adjusted * 0.55
        hk_to_ed = hk_adjusted * 0.45

        @test hk_adjusted == 257_500.0
        @test isapprox(hk_to_nursing, 141_625.0; atol=1.0)
        @test isapprox(hk_to_ed, 115_875.0; atol=1.0)

        # Total allocated costs per revenue center
        total_nursing = admin_to_nursing + plant_to_nursing + hk_to_nursing
        total_ed = admin_to_ed + plant_to_ed + hk_to_ed

        @test isapprox(total_nursing + total_ed,
                       sum(values(overhead_costs)); atol=1.0)
    end

    # -----------------------------------------------------------------------
    @testset "Medicare cost share calculation" begin
        # Medicare cost share = Total allowable cost * (Medicare charges / Total charges)
        total_allowable_cost = 8_000_000.0
        total_charges = 20_000_000.0
        medicare_charges = 9_000_000.0

        cost_to_charge_ratio = total_allowable_cost / total_charges
        @test isapprox(cost_to_charge_ratio, 0.40; atol=0.001)

        medicare_cost_share = medicare_charges * cost_to_charge_ratio
        @test isapprox(medicare_cost_share, 3_600_000.0; atol=1.0)
    end

    # -----------------------------------------------------------------------
    @testset "CAH cost-based reimbursement" begin
        # CAH receives 101% of allowable costs from Medicare
        medicare_allowable_costs = 3_600_000.0
        cah_reimbursement = medicare_allowable_costs * Constants.CAH_COST_REIMBURSEMENT_RATE
        @test isapprox(cah_reimbursement, 3_636_000.0; atol=1.0)

        # Apply sequestration
        sequestered = cah_reimbursement * (1.0 - Constants.SEQUESTRATION_RATE)
        @test isapprox(sequestered, 3_563_280.0; atol=1.0)

        # Net reimbursement should be less than pre-sequestration
        @test sequestered < cah_reimbursement

        # Bad debt reimbursement
        bad_debt = 50_000.0
        bad_debt_payment = bad_debt * Constants.BAD_DEBT_REIMBURSEMENT_RATE
        @test isapprox(bad_debt_payment, 32_500.0; atol=1.0)
    end

    # -----------------------------------------------------------------------
    @testset "REH reimbursement calculation" begin
        # REH receives monthly facility payment + enhanced OPPS
        annual_facility = Constants.REH_MONTHLY_FACILITY_PAYMENT * 12
        @test isapprox(annual_facility, Constants.REH_ANNUAL_FACILITY_PAYMENT; atol=0.01)

        # Outpatient services reimbursement with 5% add-on
        base_opps_payment = 2_000_000.0
        reh_addon = base_opps_payment * Constants.REH_OPPS_ADDON
        @test isapprox(reh_addon, 100_000.0; atol=1.0)

        total_reh_payment = annual_facility + base_opps_payment + reh_addon
        @test total_reh_payment > annual_facility
        @test total_reh_payment > base_opps_payment

        # Apply sequestration to outpatient portion only (facility payment exempt)
        sequestered_opps = (base_opps_payment + reh_addon) * (1.0 - Constants.SEQUESTRATION_RATE)
        total_with_sequester = annual_facility + sequestered_opps
        @test total_with_sequester < total_reh_payment
        @test total_with_sequester > annual_facility
    end

    # -----------------------------------------------------------------------
    @testset "IPPS DRG payment calculation" begin
        # Simplified IPPS payment = base rate * DRG weight * wage index adjustment
        base_rate = Constants.IPPS_BASE_RATE
        drg_weight = 1.35  # e.g., DRG 470 (Major Joint Replacement)
        wage_index = 0.85  # rural area

        # Labor share is approximately 68.3% of base rate
        labor_share = 0.683
        nonlabor_share = 1.0 - labor_share

        adjusted_rate = base_rate * (labor_share * wage_index + nonlabor_share)
        drg_payment = adjusted_rate * drg_weight
        @test drg_payment > 0.0
        @test drg_payment < base_rate * drg_weight * 1.5  # sanity bound

        # Payment with DSH and IME add-ons
        dsh_pct = 0.15
        ime_pct = 0.05
        total_addon = 1.0 + dsh_pct + ime_pct
        total_payment = drg_payment * total_addon
        @test total_payment > drg_payment
        @test isapprox(total_payment / drg_payment, 1.20; atol=0.001)
    end

    # -----------------------------------------------------------------------
    @testset "Cost-to-charge ratio" begin
        # Departmental CCR
        dept_costs = [500_000.0, 300_000.0, 200_000.0, 150_000.0]
        dept_charges = [1_200_000.0, 800_000.0, 600_000.0, 400_000.0]

        ccrs = dept_costs ./ dept_charges
        @test all(0.0 .< ccrs .< 1.0)

        overall_ccr = sum(dept_costs) / sum(dept_charges)
        @test isapprox(overall_ccr, 1_150_000.0 / 3_000_000.0; atol=0.001)
        @test isapprox(overall_ccr, 0.3833; atol=0.001)
    end

    # -----------------------------------------------------------------------
    @testset "Federal fiscal year utilities" begin
        @test Constants.ffy_start(2024) == Date(2023, 10, 1)
        @test Constants.ffy_end(2024) == Date(2024, 9, 30)
        @test Constants.federal_fiscal_year(Date(2024, 3, 15)) == 2024
        @test Constants.federal_fiscal_year(Date(2023, 11, 1)) == 2024
        @test Constants.federal_fiscal_year(Date(2024, 9, 30)) == 2024
        @test Constants.federal_fiscal_year(Date(2024, 10, 1)) == 2025
    end

    # -----------------------------------------------------------------------
    @testset "Benchmark constants" begin
        @test Constants.BENCHMARK_OPERATING_MARGIN < 0.0
        @test Constants.BENCHMARK_TOTAL_MARGIN > 0.0
        @test Constants.BENCHMARK_DAYS_CASH > 0.0
        @test Constants.BENCHMARK_CURRENT_RATIO > 1.0
        @test 0.0 < Constants.BENCHMARK_DEBT_TO_CAP < 1.0
        @test Constants.BENCHMARK_SALARY_TO_REVENUE > 0.0
        @test Constants.BENCHMARK_OUTPATIENT_SHARE > 0.5
        @test Constants.BENCHMARK_MEDICARE_CCR > 0.0
    end
end
