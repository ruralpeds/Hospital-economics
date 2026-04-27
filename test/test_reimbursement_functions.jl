# ============================================================================
# Tests for reimbursement calculation functions
# (step_down_allocation, Medicare/Medicaid/commercial, wage index, sequestration)
# ============================================================================

using Test
using Dates

# Include source files
include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "department.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "staffing.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "payer.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "financial.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "capital.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "hospital.jl"))
include(joinpath(@__DIR__, "..", "src", "utils", "constants.jl"))
using .Constants
include(joinpath(@__DIR__, "..", "src", "finance", "costreport.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "reimbursement.jl"))

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function make_test_geolocation()
    GeoLocation(; latitude=38.5, longitude=-98.7, fips_code="20009",
        state="KS", county="Barton", zip_code="67530")
end

function make_test_service_area()
    ServiceArea(; primary_service_area_pop=8000, total_service_area_pop=12000)
end

function make_test_cah(; kwargs...)
    CriticalAccessHospital(;
        name="Prairie View Medical Center",
        cms_provider_number="171301", npi="1234567890",
        cah_certification_date=Date(2006, 1, 15),
        licensed_beds=25, nearest_hospital_miles=35.0,
        location=make_test_geolocation(),
        service_area=make_test_service_area(),
        kwargs...
    )
end

function make_test_reh(; kwargs...)
    RuralEmergencyHospital(;
        name="Prairie View Emergency Hospital",
        cms_provider_number="171301", npi="1234567890",
        reh_conversion_date=Date(2024, 1, 1),
        former_designation=:cah, nearest_hospital_miles=35.0,
        location=make_test_geolocation(),
        service_area=make_test_service_area(),
        kwargs...
    )
end

@testset "Reimbursement Functions" begin

    # -----------------------------------------------------------------------
    @testset "step_down_allocation" begin
        cost_centers = default_cah_cost_centers()
        @test length(cost_centers) > 0

        # Set some costs on cost centers for allocation
        for cc in cost_centers
            cc.direct_cost = 100_000.0
        end

        allocated = step_down_allocation(cost_centers)
        @test allocated isa Dict{String,Float64}
        @test length(allocated) > 0

        # Total allocated should equal total direct costs
        total_direct = sum(cc.direct_cost for cc in cost_centers)
        total_allocated = sum(values(allocated))
        @test isapprox(total_allocated, total_direct; rtol=0.01)
    end

    # -----------------------------------------------------------------------
    @testset "step_down_allocation with custom order" begin
        cost_centers = default_cah_cost_centers()
        for cc in cost_centers
            cc.direct_cost = 50_000.0
        end

        custom_order = default_step_down_order()
        @test length(custom_order) >= 1

        allocated = step_down_allocation(cost_centers; order=custom_order)
        @test allocated isa Dict{String,Float64}
        @test length(allocated) > 0
    end

    # -----------------------------------------------------------------------
    @testset "default_cah_cost_centers returns valid centers" begin
        centers = default_cah_cost_centers()
        @test length(centers) >= 10  # CAH should have at least 10 cost centers
        @test all(cc -> !isempty(cc.code), centers)
        @test all(cc -> !isempty(cc.name), centers)
    end

    # -----------------------------------------------------------------------
    @testset "default_step_down_order returns valid order" begin
        order = default_step_down_order()
        @test length(order) >= 4
        @test all(o -> o isa String, order)
        # Overhead departments should be allocated first
        @test "8800" in order || "8850" in order
    end

    # -----------------------------------------------------------------------
    @testset "calculate_medicare_reimbursement - CAH" begin
        hospital = make_test_cah()
        result = calculate_medicare_reimbursement(hospital; sequestration=true)

        @test haskey(result, :allowable_costs) || hasproperty(result, :allowable_costs)
        @test result.total_reimbursement >= 0.0
        @test result.sequestration_amount >= 0.0

        # Without sequestration should yield higher reimbursement
        result_no_seq = calculate_medicare_reimbursement(hospital; sequestration=false)
        @test result_no_seq.total_reimbursement >= result.total_reimbursement
    end

    # -----------------------------------------------------------------------
    @testset "calculate_medicare_reimbursement - REH" begin
        hospital = make_test_reh()
        result = calculate_medicare_reimbursement(hospital; sequestration=true)

        @test result.facility_payment > 0.0
        @test result.total_reimbursement > 0.0
        # REH facility payment should be close to annual facility payment
        @test result.facility_payment >= Constants.REH_MONTHLY_FACILITY_PAYMENT * 11
    end

    # -----------------------------------------------------------------------
    @testset "calculate_medicaid_reimbursement" begin
        hospital = make_test_cah()
        fee_schedule = MedicaidFeeSchedule(
            "KS", 800.0, 0.60, 350.0, 250.0, false, 1.00, 500_000.0
        )
        result = calculate_medicaid_reimbursement(
            hospital, fee_schedule;
            medicaid_days=200, medicaid_outpatient_visits=500,
            medicaid_ed_visits=300, medicaid_charges=1_500_000.0
        )

        @test result.total_reimbursement > 0.0
        @test result.inpatient_payment >= 0.0
        @test result.outpatient_payment >= 0.0
        @test result.ed_payment >= 0.0
    end

    # -----------------------------------------------------------------------
    @testset "calculate_commercial_reimbursement - pct_charges method" begin
        hospital = make_test_cah()
        result = calculate_commercial_reimbursement(
            hospital;
            commercial_charges=2_000_000.0,
            pct_of_charges=0.85,
            method=:pct_charges,
        )

        @test result.net_payment > 0.0
        @test result.net_payment <= 2_000_000.0
        @test result.contractual_adjustment >= 0.0
        @test isapprox(result.net_payment, 2_000_000.0 * 0.85; rtol=0.01)
    end

    # -----------------------------------------------------------------------
    @testset "calculate_commercial_reimbursement - per_diem method" begin
        hospital = make_test_cah()
        result = calculate_commercial_reimbursement(
            hospital;
            method=:per_diem,
            commercial_days=100,
            per_diem=1_200.0,
        )

        @test result.net_payment > 0.0
    end

    # -----------------------------------------------------------------------
    @testset "calculate_uncompensated_care" begin
        hospital = make_test_cah()
        result = calculate_uncompensated_care(
            hospital;
            total_charges=20_000_000.0,
            charity_pct=0.03,
            bad_debt_pct=0.05,
        )

        @test result.charity_care_charges > 0.0
        @test result.bad_debt_charges > 0.0
        @test result.net_uncompensated_cost > 0.0
        @test result.uncompensated_pct > 0.0
        @test result.uncompensated_pct < 1.0

        # Bad debt charges = 5% of total
        @test isapprox(result.bad_debt_charges, 20_000_000.0 * 0.05; rtol=0.01)
        # Charity charges = 3% of total
        @test isapprox(result.charity_care_charges, 20_000_000.0 * 0.03; rtol=0.01)
    end

    # -----------------------------------------------------------------------
    @testset "apply_wage_index" begin
        # National average wage index = 1.0 should yield same payment
        base = 10_000.0
        adjusted_national = apply_wage_index(base, 1.0)
        @test isapprox(adjusted_national, base; rtol=0.001)

        # Rural wage index < 1.0 should reduce total
        adjusted_rural = apply_wage_index(base, 0.80)
        @test adjusted_rural < base
        @test adjusted_rural > 0.0

        # High-cost area wage index > 1.0 should increase
        adjusted_urban = apply_wage_index(base, 1.30)
        @test adjusted_urban > base

        # Custom labor share
        adjusted_custom = apply_wage_index(base, 0.80; labor_share=0.50)
        @test adjusted_custom < base
        @test adjusted_custom != adjusted_rural  # different labor share

        # Zero payment stays zero
        @test apply_wage_index(0.0, 0.80) == 0.0
    end

    # -----------------------------------------------------------------------
    @testset "apply_sequestration" begin
        payment = 100_000.0
        result = apply_sequestration(payment)

        @test result.net_payment < payment
        @test result.reduction > 0.0
        @test isapprox(result.reduction, payment * 0.02; rtol=0.001)
        @test isapprox(result.net_payment + result.reduction, payment; rtol=0.001)

        # Custom rate
        result_custom = apply_sequestration(payment; rate=0.05)
        @test isapprox(result_custom.reduction, 5_000.0; rtol=0.001)

        # Zero payment
        result_zero = apply_sequestration(0.0)
        @test result_zero.net_payment == 0.0
        @test result_zero.reduction == 0.0
    end

    # -----------------------------------------------------------------------
    @testset "apply_bad_debt_adjustment" begin
        total_bad_debt = 100_000.0

        # Test 1: Standard hospital (65% reimbursement)
        result = apply_bad_debt_adjustment(total_bad_debt)
        @test result.reimbursement > 0.0
        @test result.unreimbursed > 0.0
        @test isapprox(result.reimbursement + result.unreimbursed, total_bad_debt; rtol=0.01)
        @test isapprox(result.reimbursement, total_bad_debt * 0.65; rtol=0.01)
        @test isapprox(result.unreimbursed, total_bad_debt * 0.35; rtol=0.01)

        # Test 2: CAH (cost-based, up to 101% capped at 100%)
        result_cah = apply_bad_debt_adjustment(total_bad_debt; is_cah=true)
        # CAH should get 100% reimbursement (min(1.01, 1.0) = 1.0)
        @test isapprox(result_cah.reimbursement, total_bad_debt * 1.0; rtol=0.01)
        @test isapprox(result_cah.unreimbursed, 0.0; atol=1.0)  # Should be essentially zero
        @test result_cah.reimbursement > result.reimbursement  # CAH gets more than standard

        # Test 3: Custom reimbursement rate
        result_custom = apply_bad_debt_adjustment(total_bad_debt; reimbursement_rate=0.80)
        @test isapprox(result_custom.reimbursement, total_bad_debt * 0.80; rtol=0.01)

        # Test 4: CAH with custom rate (CAH overrides the custom rate)
        result_cah_custom = apply_bad_debt_adjustment(total_bad_debt; reimbursement_rate=0.80, is_cah=true)
        @test isapprox(result_cah_custom.reimbursement, total_bad_debt * 1.0; rtol=0.01)

        # Test 5: Zero bad debt
        result_zero = apply_bad_debt_adjustment(0.0)
        @test result_zero.reimbursement == 0.0
        @test result_zero.unreimbursed == 0.0

        # Test 6: Large bad debt
        large_bad_debt = 5_000_000.0
        result_large = apply_bad_debt_adjustment(large_bad_debt)
        @test isapprox(result_large.reimbursement, large_bad_debt * 0.65; rtol=0.01)

        # Test 7: CAH with large bad debt
        result_cah_large = apply_bad_debt_adjustment(large_bad_debt; is_cah=true)
        @test isapprox(result_cah_large.reimbursement, large_bad_debt * 1.0; rtol=0.01)
    end
end
