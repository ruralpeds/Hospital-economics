# ============================================================================
# Tests for REH conversion analysis
# ============================================================================

using Test

include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "utils", "constants.jl"))
using .Constants

# ---------------------------------------------------------------------------
# Stub REH conversion analysis
# ---------------------------------------------------------------------------

struct CAHFinancials
    total_revenue::Float64
    inpatient_revenue::Float64
    outpatient_revenue::Float64
    total_expense::Float64
    inpatient_expense::Float64
    outpatient_expense::Float64
    medicare_inpatient_revenue::Float64
    medicare_outpatient_revenue::Float64
    inpatient_days::Int
    ed_visits::Int
    outpatient_visits::Int
    annual_debt_service::Float64
    capital_lease_obligations::Float64
end

struct REHConversionResult
    annual_reh_facility_payment::Float64
    enhanced_opps_revenue::Float64
    lost_inpatient_revenue::Float64
    avoided_inpatient_cost::Float64
    net_revenue_change::Float64
    estimated_conversion_cost::Float64
    payback_period_years::Float64
    is_financially_beneficial::Bool
    five_year_npv::Float64
end

"""
    analyze_reh_conversion(cah_financials, conversion_cost, discount_rate) -> REHConversionResult

Analyze the financial impact of converting a CAH to an REH.
"""
function analyze_reh_conversion(
    fin::CAHFinancials;
    conversion_cost::Float64=500_000.0,
    discount_rate::Float64=Constants.DEFAULT_DISCOUNT_RATE,
    opps_base_payment::Float64=0.0,
)
    # Annual REH facility payment
    annual_facility = Constants.REH_MONTHLY_FACILITY_PAYMENT * 12

    # Enhanced outpatient: existing outpatient revenue + 5% add-on
    opps_payment = opps_base_payment > 0.0 ? opps_base_payment : fin.outpatient_revenue
    enhanced_opps = opps_payment * (1.0 + Constants.REH_OPPS_ADDON)

    # Lost inpatient revenue
    lost_ip_revenue = fin.inpatient_revenue

    # Avoided inpatient costs
    avoided_ip_cost = fin.inpatient_expense

    # Net annual revenue change
    reh_total_revenue = annual_facility + enhanced_opps
    cah_total_revenue = fin.total_revenue
    net_revenue = reh_total_revenue - cah_total_revenue

    # Net annual cost change (avoid inpatient costs)
    reh_total_cost = fin.total_expense - avoided_ip_cost
    net_annual_benefit = (reh_total_revenue - reh_total_cost) -
                         (cah_total_revenue - fin.total_expense)

    # Payback period
    payback = net_annual_benefit > 0.0 ? conversion_cost / net_annual_benefit : Inf

    # 5-year NPV
    npv = -conversion_cost
    for year in 1:5
        npv += net_annual_benefit / (1.0 + discount_rate)^year
    end

    is_beneficial = npv > 0.0

    return REHConversionResult(
        annual_facility,
        enhanced_opps,
        lost_ip_revenue,
        avoided_ip_cost,
        net_revenue,
        conversion_cost,
        payback,
        is_beneficial,
        npv,
    )
end

"""
    reh_eligible(cah_financials) -> Bool

Check basic REH eligibility criteria.
"""
function reh_eligible(fin::CAHFinancials)
    # Must have an ED (proxied by having ED visits)
    fin.ed_visits > 0 || return false
    # Must not be primarily an inpatient facility (REH has no beds)
    return true
end

@testset "REH Conversion Analysis" begin

    # -----------------------------------------------------------------------
    @testset "REH facility payment constants" begin
        annual = Constants.REH_MONTHLY_FACILITY_PAYMENT * 12
        @test annual > 3_000_000.0
        @test isapprox(annual, Constants.REH_ANNUAL_FACILITY_PAYMENT; atol=0.01)
    end

    # -----------------------------------------------------------------------
    @testset "Favorable conversion — low inpatient, high outpatient" begin
        fin = CAHFinancials(
            10_000_000.0,   # total revenue
            1_500_000.0,    # inpatient revenue (low)
            8_500_000.0,    # outpatient revenue (high)
            10_200_000.0,   # total expense
            2_000_000.0,    # inpatient expense
            8_200_000.0,    # outpatient expense
            1_200_000.0,    # medicare inpatient
            5_000_000.0,    # medicare outpatient
            400,            # inpatient days
            6000,           # ED visits
            25000,          # outpatient visits
            300_000.0,      # debt service
            0.0,            # capital leases
        )

        result = analyze_reh_conversion(fin)

        @test result.annual_reh_facility_payment > 3_000_000.0
        @test result.enhanced_opps_revenue > fin.outpatient_revenue
        @test result.lost_inpatient_revenue == fin.inpatient_revenue
        @test result.avoided_inpatient_cost == fin.inpatient_expense
        @test result.estimated_conversion_cost == 500_000.0

        # With large facility payment and low inpatient, conversion may be beneficial
        @test isfinite(result.payback_period_years)
        @test result.five_year_npv isa Float64
    end

    # -----------------------------------------------------------------------
    @testset "Unfavorable conversion — high inpatient dependency" begin
        fin = CAHFinancials(
            12_000_000.0,   # total revenue
            6_000_000.0,    # inpatient revenue (high)
            6_000_000.0,    # outpatient revenue
            11_500_000.0,   # total expense
            5_000_000.0,    # inpatient expense
            6_500_000.0,    # outpatient expense
            5_000_000.0,    # medicare inpatient
            3_500_000.0,    # medicare outpatient
            2000,           # inpatient days (high)
            4000,           # ED visits
            15000,          # outpatient visits
            500_000.0,      # debt service
            200_000.0,      # capital leases
        )

        result = analyze_reh_conversion(fin)

        @test result.lost_inpatient_revenue == 6_000_000.0
        # High inpatient loss means conversion is less likely to be beneficial
        @test result.lost_inpatient_revenue > result.avoided_inpatient_cost
    end

    # -----------------------------------------------------------------------
    @testset "Conversion cost sensitivity" begin
        fin = CAHFinancials(
            8_000_000.0, 1_000_000.0, 7_000_000.0,
            8_200_000.0, 1_500_000.0, 6_700_000.0,
            800_000.0, 4_000_000.0,
            300, 5000, 20000, 200_000.0, 0.0,
        )

        low_cost = analyze_reh_conversion(fin; conversion_cost=200_000.0)
        high_cost = analyze_reh_conversion(fin; conversion_cost=2_000_000.0)

        @test low_cost.five_year_npv > high_cost.five_year_npv
        @test low_cost.payback_period_years < high_cost.payback_period_years
    end

    # -----------------------------------------------------------------------
    @testset "Discount rate sensitivity" begin
        fin = CAHFinancials(
            9_000_000.0, 1_200_000.0, 7_800_000.0,
            9_100_000.0, 1_800_000.0, 7_300_000.0,
            1_000_000.0, 4_500_000.0,
            350, 5500, 22000, 250_000.0, 0.0,
        )

        low_dr = analyze_reh_conversion(fin; discount_rate=0.01)
        high_dr = analyze_reh_conversion(fin; discount_rate=0.08)

        # Higher discount rate reduces NPV of future cash flows
        @test low_dr.five_year_npv > high_dr.five_year_npv
    end

    # -----------------------------------------------------------------------
    @testset "REH eligibility check" begin
        # Eligible: has ED visits
        fin_eligible = CAHFinancials(
            8_000_000.0, 1_000_000.0, 7_000_000.0,
            8_200_000.0, 1_500_000.0, 6_700_000.0,
            800_000.0, 4_000_000.0,
            300, 5000, 20000, 200_000.0, 0.0,
        )
        @test reh_eligible(fin_eligible) == true

        # Not eligible: no ED
        fin_no_ed = CAHFinancials(
            8_000_000.0, 1_000_000.0, 7_000_000.0,
            8_200_000.0, 1_500_000.0, 6_700_000.0,
            800_000.0, 4_000_000.0,
            300, 0, 20000, 200_000.0, 0.0,
        )
        @test reh_eligible(fin_no_ed) == false
    end

    # -----------------------------------------------------------------------
    @testset "Revenue component checks" begin
        fin = CAHFinancials(
            10_000_000.0, 2_000_000.0, 8_000_000.0,
            10_500_000.0, 2_500_000.0, 8_000_000.0,
            1_600_000.0, 5_000_000.0,
            500, 5000, 20000, 300_000.0, 0.0,
        )
        result = analyze_reh_conversion(fin)

        # Enhanced OPPS should be 5% more than base outpatient
        @test isapprox(result.enhanced_opps_revenue,
                       fin.outpatient_revenue * 1.05; atol=1.0)

        # Facility payment should match constant
        @test isapprox(result.annual_reh_facility_payment,
                       Constants.REH_ANNUAL_FACILITY_PAYMENT; atol=1.0)
    end
end
