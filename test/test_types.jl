# ============================================================================
# Tests for type construction and validation
# ============================================================================

using Test
using Dates
using UUIDs

# Include source files directly for testing (in dependency order)
include(joinpath(@__DIR__, "..", "src", "types", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "types", "service_lines.jl"))
include(joinpath(@__DIR__, "..", "src", "types", "staffing.jl"))
include(joinpath(@__DIR__, "..", "src", "types", "payer_mix.jl"))
include(joinpath(@__DIR__, "..", "src", "types", "financial.jl"))
include(joinpath(@__DIR__, "..", "src", "types", "hospital.jl"))

# ---------------------------------------------------------------------------
# Helper: create a minimal GeoLocation for testing
# ---------------------------------------------------------------------------
function make_test_geolocation(;
    latitude=38.5,
    longitude=-98.7,
    state="KS",
    county="Barton",
    fips_code="20009",
    zip_code="67530",
    kwargs...
)
    GeoLocation(;
        latitude=latitude,
        longitude=longitude,
        fips_code=fips_code,
        state=state,
        county=county,
        zip_code=zip_code,
        kwargs...
    )
end

# ---------------------------------------------------------------------------
# Helper: create a minimal ServiceArea for testing
# ---------------------------------------------------------------------------
function make_test_service_area(;
    primary_service_area_pop=8000,
    total_service_area_pop=12000,
    kwargs...
)
    ServiceArea(;
        primary_service_area_pop=primary_service_area_pop,
        total_service_area_pop=total_service_area_pop,
        kwargs...
    )
end

# ---------------------------------------------------------------------------
# Helper: create a test CAH
# ---------------------------------------------------------------------------
function make_test_cah(;
    name="Prairie View Medical Center",
    licensed_beds=25,
    nearest_hospital_miles=35.0,
    kwargs...
)
    CriticalAccessHospital(;
        name=name,
        cms_provider_number="171301",
        npi="1234567890",
        cah_certification_date=Date(2006, 1, 15),
        licensed_beds=licensed_beds,
        nearest_hospital_miles=nearest_hospital_miles,
        location=make_test_geolocation(),
        service_area=make_test_service_area(),
        kwargs...
    )
end

# ---------------------------------------------------------------------------
# Helper: create a test REH
# ---------------------------------------------------------------------------
function make_test_reh(;
    name="Prairie View Emergency Hospital",
    kwargs...
)
    RuralEmergencyHospital(;
        name=name,
        cms_provider_number="171301",
        npi="1234567890",
        reh_conversion_date=Date(2024, 1, 1),
        former_designation=:cah,
        nearest_hospital_miles=35.0,
        location=make_test_geolocation(),
        service_area=make_test_service_area(),
        kwargs...
    )
end

@testset "Type Construction & Validation" begin

    # -----------------------------------------------------------------------
    @testset "GeoLocation" begin
        geo = make_test_geolocation()
        @test geo.latitude == 38.5
        @test geo.longitude == -98.7
        @test geo.state == "KS"
        @test geo.county == "Barton"
        @test geo.fips_code == "20009"
        @test geo.zip_code == "67530"
        # Check defaults
        @test geo.ruca_code == 10.0
        @test geo.urban_rural == :rural
        @test geo.census_tract == ""
        @test geo.cbsa_code == ""

        # Custom overrides
        geo2 = make_test_geolocation(ruca_code=1.0, urban_rural=:urban, cbsa_code="48620")
        @test geo2.ruca_code == 1.0
        @test geo2.urban_rural == :urban
        @test geo2.cbsa_code == "48620"
    end

    # -----------------------------------------------------------------------
    @testset "ServiceArea" begin
        sa = make_test_service_area()
        @test sa.primary_service_area_pop == 8000
        @test sa.total_service_area_pop == 12000
        @test sa.secondary_service_area_pop == 0
        # Defaults
        @test sa.median_age == 40.0
        @test sa.pct_over_65 == 0.18
        @test sa.pct_under_18 == 0.22
        @test sa.poverty_rate == 0.15
        @test sa.uninsured_rate == 0.10
        @test sa.hpsa_score == 0
        @test sa.is_medically_underserved == false
        @test sa.nearest_tertiary_center_miles == 60.0
        @test sa.competing_hospitals == 0

        # Custom demographics
        sa2 = ServiceArea(;
            primary_service_area_pop=15000,
            total_service_area_pop=25000,
            pct_over_65=0.25,
            median_household_income=38000.0,
            hpsa_score=18,
            is_medically_underserved=true,
        )
        @test sa2.pct_over_65 == 0.25
        @test sa2.median_household_income == 38000.0
        @test sa2.hpsa_score == 18
        @test sa2.is_medically_underserved == true
    end

    # -----------------------------------------------------------------------
    @testset "CriticalAccessHospital construction" begin
        cah = make_test_cah()

        @test cah.name == "Prairie View Medical Center"
        @test cah.cms_provider_number == "171301"
        @test cah.npi == "1234567890"
        @test cah.licensed_beds == 25
        @test cah.nearest_hospital_miles == 35.0
        @test cah.cah_certification_date == Date(2006, 1, 15)
        @test cah.payment_designation isa CostBasedPayment
        @test cah.is_necessary_provider == false
        @test cah.swing_beds == 0
        @test cah.observation_beds == 0
        @test cah.average_daily_census == 0.0
        @test cah.average_length_of_stay == 0.0
        @test cah.is_government_owned == false
        @test cah.tax_status == :nonprofit
        @test cah.is_340b_eligible == false
        @test cah.dsh_adjustment_pct == 0.0
        @test cah.id isa UUID
        @test cah.location isa GeoLocation
        @test cah.service_area isa ServiceArea

        # Verify show method
        buf = IOBuffer()
        show(buf, cah)
        repr_str = String(take!(buf))
        @test occursin("CAH(", repr_str)
        @test occursin("Prairie View", repr_str)
        @test occursin("beds=25", repr_str)
    end

    # -----------------------------------------------------------------------
    @testset "CAH validation — 25-bed limit" begin
        # Valid: exactly 25 beds
        cah25 = make_test_cah(licensed_beds=25)
        @test validate_cah(cah25) == true

        # Valid: fewer than 25 beds
        cah10 = make_test_cah(licensed_beds=10)
        @test validate_cah(cah10) == true

        # Invalid: more than 25 beds
        cah30 = make_test_cah(licensed_beds=30)
        @test_throws ErrorException validate_cah(cah30)
    end

    # -----------------------------------------------------------------------
    @testset "CAH validation — length of stay warning" begin
        cah = make_test_cah()
        cah.average_length_of_stay = 100.0
        # Should still return true but issue a warning
        @test_logs (:warn, r"96-hour") validate_cah(cah)
    end

    # -----------------------------------------------------------------------
    @testset "CAH mutability" begin
        cah = make_test_cah()
        cah.average_daily_census = 8.5
        @test cah.average_daily_census == 8.5
        cah.average_length_of_stay = 72.0
        @test cah.average_length_of_stay == 72.0
        cah.is_340b_eligible = true
        @test cah.is_340b_eligible == true
    end

    # -----------------------------------------------------------------------
    @testset "RuralEmergencyHospital construction" begin
        reh = make_test_reh()
        @test reh.name == "Prairie View Emergency Hospital"
        @test reh.payment_designation isa REHPayment
        @test reh.former_designation == :cah
        @test reh.reh_conversion_date == Date(2024, 1, 1)
        @test reh.observation_beds == 0
        @test reh.ed_treatment_stations == 8
        @test reh.monthly_facility_payment == 272_866.30
        @test reh.outpatient_add_on_pct == 0.05
        @test reh.id isa UUID

        buf = IOBuffer()
        show(buf, reh)
        repr_str = String(take!(buf))
        @test occursin("REH(", repr_str)
        @test occursin("former=cah", repr_str)
    end

    # -----------------------------------------------------------------------
    @testset "ProspectivePaymentHospital construction" begin
        pps = ProspectivePaymentHospital(;
            name="Metro General Hospital",
            cms_provider_number="170010",
            npi="9876543210",
            licensed_beds=250,
            staffed_beds=200,
            case_mix_index=1.45,
            wage_index=0.98,
            location=make_test_geolocation(latitude=39.1, longitude=-94.6, state="MO"),
            service_area=make_test_service_area(
                primary_service_area_pop=150000,
                total_service_area_pop=300000,
            ),
        )
        @test pps.name == "Metro General Hospital"
        @test pps.payment_designation isa ProspectivePayment
        @test pps.licensed_beds == 250
        @test pps.staffed_beds == 200
        @test pps.case_mix_index == 1.45
        @test pps.wage_index == 0.98
        @test pps.is_sole_community == false
        @test pps.is_teaching == false
        @test pps.resident_count == 0

        buf = IOBuffer()
        show(buf, pps)
        repr_str = String(take!(buf))
        @test occursin("PPS(", repr_str)
        @test occursin("cmi=1.45", repr_str)
    end

    # -----------------------------------------------------------------------
    @testset "HealthSystem construction" begin
        hs = HealthSystem(;
            name="Great Plains Health Alliance",
            system_type=:alliance,
            headquarters_state="KS",
            total_hospitals=12,
            total_licensed_beds=280,
        )
        @test hs.name == "Great Plains Health Alliance"
        @test hs.system_type == :alliance
        @test hs.headquarters_state == "KS"
        @test hs.total_hospitals == 12
        @test hs.total_licensed_beds == 280
        @test hs.has_medical_school == false
        @test isempty(hs.member_hospital_ids)

        buf = IOBuffer()
        show(buf, hs)
        repr_str = String(take!(buf))
        @test occursin("HealthSystem(", repr_str)
        @test occursin("hospitals=12", repr_str)
    end

    # -----------------------------------------------------------------------
    @testset "Abstract type hierarchy" begin
        cah = make_test_cah()
        reh = make_test_reh()

        @test cah isa AbstractRuralHospital
        @test cah isa AbstractHospital
        @test cah isa AbstractEntity
        @test reh isa AbstractRuralHospital
        @test reh isa AbstractHospital

        @test CostBasedPayment() isa AbstractPaymentDesignation
        @test REHPayment() isa AbstractPaymentDesignation
        @test ProspectivePayment() isa AbstractPaymentDesignation
        @test SoleCommunityPayment() isa AbstractPaymentDesignation
    end

    # -----------------------------------------------------------------------
    @testset "PayerMix validation (field-level)" begin
        # Test that payer proportions sum to 1.0
        cah = make_test_cah()

        # Valid payer mix using the PayerMix type
        contracts = PayerContract[
            PayerContract(payer_name="Medicare", payer_type=:medicare,
                          overall_volume_pct=0.55, payment_method=:cost_based),
            PayerContract(payer_name="Medicaid", payer_type=:medicaid,
                          overall_volume_pct=0.18, payment_method=:fee_for_service),
            PayerContract(payer_name="Commercial", payer_type=:commercial,
                          overall_volume_pct=0.17, payment_method=:fee_for_service),
            PayerContract(payer_name="Self-Pay", payer_type=:self_pay,
                          overall_volume_pct=0.07, payment_method=:fee_for_service),
            PayerContract(payer_name="Other Gov", payer_type=:other,
                          overall_volume_pct=0.03, payment_method=:fee_for_service),
        ]
        pm = PayerMix(contracts, Date(2024, 1, 1))
        cah.payer_mix = pm
        @test cah.payer_mix isa PayerMix
        @test length(cah.payer_mix.contracts) == 5

        # Check volume shares sum to 1.0
        total = sum(c.overall_volume_pct for c in pm.contracts)
        @test isapprox(total, 1.0; atol=1e-10)

        # Invalid payer mix: does not sum to 1.0 — constructor should error
        bad_contracts = PayerContract[
            PayerContract(payer_name="Medicare", payer_type=:medicare, overall_volume_pct=0.60),
            PayerContract(payer_name="Medicaid", payer_type=:medicaid, overall_volume_pct=0.20),
            PayerContract(payer_name="Commercial", payer_type=:commercial, overall_volume_pct=0.25),
        ]
        @test_throws ErrorException PayerMix(bad_contracts, Date(2024, 1, 1))
    end
end
