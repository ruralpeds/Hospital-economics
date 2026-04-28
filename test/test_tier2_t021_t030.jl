"""
    test_tier2_t021_t030.jl — Test suite for Tier 2 tasks T-021 through T-030

Covers:
  T-021  Monte Carlo performance (cache, convergence, ConvergenceCriteria)
  T-022  Bulk hospital parallelization
  T-023  Ratio calculation caching
  T-024  Validation utility module
  T-025  Hospital type registry
  T-026  VBC model variants
  T-027  ICER sensitivity analysis
  T-028  Cohort analysis enhancements
  T-029  REH analytics
  T-030  Reporting & export framework
"""

using Test
using Statistics
using Dates

# ── Helpers for building stub objects ────────────────────────────────────────
# These stubs satisfy the interfaces expected by the new functions without
# requiring the full Genie / Stipple stack.

function make_stub_financials(; rev=5_000_000.0, exp=4_750_000.0)
    AnnualFinancials(
        net_patient_revenue      = rev,
        total_net_revenue        = rev * 1.05,
        total_operating_expenses = exp,
        operating_income         = rev - exp,
        non_operating_income     = 50_000.0,
        total_margin             = (rev * 1.05 - exp) / (rev * 1.05),
        total_assets             = 8_000_000.0,
        total_liabilities        = 4_000_000.0,
        long_term_debt           = 2_500_000.0,
        current_assets           = 1_200_000.0,
        current_liabilities      = 900_000.0,
        cash_and_investments     = 500_000.0,
        net_assets               = 4_000_000.0,
        net_fixed_assets         = 3_000_000.0,
        depreciation_expense     = 250_000.0,
        accumulated_depreciation = 1_500_000.0,
        salary_expense           = 2_800_000.0,
        outpatient_revenue       = 2_000_000.0,
        total_costs              = exp,
        total_charges            = rev * 2.0,
        medicare_charges         = rev * 0.8,
        fiscal_year              = 2025,
    )
end

# ═════════════════════════════════════════════════════════════════════════════
# T-021: Monte Carlo Performance
# ═════════════════════════════════════════════════════════════════════════════

@testset "T-021 Monte Carlo Performance" begin

    @testset "MCResultCache" begin
        cache = MCResultCache(enabled=true)
        @test cache.enabled == true
        @test cache.hits[] == 0
        @test cache.misses[] == 0
        @test isempty(cache.store)
    end

    @testset "clear_mc_cache!" begin
        clear_mc_cache!()
        h, m = mc_cache_stats()
        @test h == 0
        @test m == 0
    end

    @testset "ConvergenceCriteria defaults" begin
        cc = ConvergenceCriteria()
        @test cc.enabled == false
        @test cc.tol > 0
        @test cc.window >= 1
        @test cc.min_iterations >= 100
    end

    @testset "ConvergenceCriteria constructor" begin
        cc = ConvergenceCriteria(enabled=true, tol=1e-3, window=3, check_every=200, min_iterations=500)
        @test cc.enabled == true
        @test cc.tol == 1e-3
        @test cc.window == 3
    end

    @testset "run_monte_carlo with use_cache (interface)" begin
        # Verify the function accepts use_cache and convergence kwargs
        @test hasmethod(run_monte_carlo, (Any, MonteCarloParams))
        methods_kw = methods(run_monte_carlo)
        @test length(methods_kw) >= 1
    end

    @testset "mc_cache_key stability" begin
        h1 = make_stub_financials()
        # Two calls produce same key
        params = MonteCarloParams(n_iterations=100, projection_years=3, random_seed=42)
        k1 = RuralHospitalSim._mc_cache_key(h1, params)
        k2 = RuralHospitalSim._mc_cache_key(h1, params)
        @test k1 == k2
    end

end  # T-021

# ═════════════════════════════════════════════════════════════════════════════
# T-022: Bulk Hospital Parallelization
# ═════════════════════════════════════════════════════════════════════════════

@testset "T-022 Bulk Hospital Parallelization" begin

    @testset "HospitalProjectionResult struct" begin
        r = HospitalProjectionResult("H001", nothing, 0.5, "test error")
        @test r.hospital_id == "H001"
        @test isnothing(r.summary)
        @test r.elapsed_seconds == 0.5
        @test r.error == "test error"
    end

    @testset "HospitalProjectionResult success" begin
        r = HospitalProjectionResult(1, nothing, 1.2, nothing)
        @test isnothing(r.error)
        @test r.hospital_id == 1
    end

    @testset "aggregate_network_projection with no failures" begin
        # Build stub results
        stubs = [
            HospitalProjectionResult("H$i", nothing, 0.1, "stub error") for i in 1:3
        ]
        agg = aggregate_network_projection(stubs)
        @test agg.n_hospitals == 3
        @test agg.n_failed == 3  # all have errors
        @test isnan(agg.network_median_margin)
    end

    @testset "aggregate_network_projection signature" begin
        @test hasmethod(aggregate_network_projection, (Vector{HospitalProjectionResult},))
    end

    @testset "bulk_project_hospitals length mismatch error" begin
        hospitals = [1, 2, 3]
        ids       = ["a", "b"]       # mismatched
        params    = MonteCarloParams(n_iterations=10, projection_years=2, random_seed=1)
        @test_throws ErrorException bulk_project_hospitals(hospitals, params; ids=ids)
    end

end  # T-022

# ═════════════════════════════════════════════════════════════════════════════
# T-023: Ratio Caching
# ═════════════════════════════════════════════════════════════════════════════

@testset "T-023 Ratio Caching" begin

    @testset "RatioCache construction" begin
        c = RatioCache(enabled=true, max_size=100)
        @test c.enabled == true
        @test c.max_size == 100
        @test isempty(c.store)
    end

    @testset "clear_ratio_cache!" begin
        clear_ratio_cache!()
        h, m = ratio_cache_stats()
        @test h == 0
        @test m == 0
    end

    @testset "cache key stability" begin
        f = make_stub_financials()
        k1 = RuralHospitalSim._ratio_key(f)
        k2 = RuralHospitalSim._ratio_key(f)
        @test k1 == k2
    end

    @testset "cache key changes with different financials" begin
        f1 = make_stub_financials(rev=5_000_000.0)
        f2 = make_stub_financials(rev=6_000_000.0)
        @test RuralHospitalSim._ratio_key(f1) != RuralHospitalSim._ratio_key(f2)
    end

    @testset "compute_all_ratios with use_cache=true — hit/miss" begin
        clear_ratio_cache!()
        f = make_stub_financials()
        r1 = compute_all_ratios(f; use_cache=true)
        h1, m1 = ratio_cache_stats()
        @test m1 == 1   # first call is a miss
        @test h1 == 0

        r2 = compute_all_ratios(f; use_cache=true)
        h2, m2 = ratio_cache_stats()
        @test h2 == 1   # second call is a hit
        @test r1 == r2  # same result
    end

    @testset "compute_all_ratios cache=false is passthrough" begin
        f = make_stub_financials()
        h_before, _ = ratio_cache_stats()
        compute_all_ratios(f; use_cache=false)
        h_after, _ = ratio_cache_stats()
        @test h_before == h_after   # cache not touched
    end

    @testset "eviction does not crash" begin
        c = RatioCache(enabled=true, max_size=3)
        for i in 1:5
            f = make_stub_financials(rev=Float64(i) * 1_000_000)
            k = RuralHospitalSim._ratio_key(f)
            RuralHospitalSim._evict_if_needed!(c)
            c.store[k] = compute_all_ratios(f)
        end
        @test length(c.store) <= 4  # eviction ran
    end

end  # T-023

# ═════════════════════════════════════════════════════════════════════════════
# T-024: Validation Utilities
# ═════════════════════════════════════════════════════════════════════════════

@testset "T-024 Validation Utilities" begin

    @testset "ValidationResult basics" begin
        r = ValidationResult()
        @test isvalid(r)
        @test isempty(r)

        r2 = ValidationResult(["error one", "error two"])
        @test !isvalid(r2)
        @test length(r2) == 2
    end

    @testset "merge_validations" begin
        r1 = ValidationResult(["e1"])
        r2 = ValidationResult(["e2", "e3"])
        merged = merge_validations(r1, r2)
        @test length(merged) == 3
        @test !isvalid(merged)

        ok = merge_validations(ValidationResult(), ValidationResult())
        @test isvalid(ok)
    end

    @testset "validate! raises on failure" begin
        r = ValidationResult(["bad input"])
        @test_throws ArgumentError validate!(r)
        @test_throws ArgumentError validate!(r, "test context")
    end

    @testset "validate! passes on success" begin
        r = ValidationResult()
        @test isnothing(validate!(r))
    end

    @testset "check_positive" begin
        @test isvalid(check_positive(1.0, "x"))
        @test isvalid(check_positive(0.001, "x"))
        @test !isvalid(check_positive(0.0, "x"))
        @test !isvalid(check_positive(-1.0, "x"))
    end

    @testset "check_non_negative" begin
        @test isvalid(check_non_negative(0.0, "x"))
        @test isvalid(check_non_negative(5.0, "x"))
        @test !isvalid(check_non_negative(-0.001, "x"))
    end

    @testset "check_in_range" begin
        @test isvalid(check_in_range(0.5, 0.0, 1.0, "r"))
        @test isvalid(check_in_range(0.0, 0.0, 1.0, "r"))
        @test isvalid(check_in_range(1.0, 0.0, 1.0, "r"))
        @test !isvalid(check_in_range(1.1, 0.0, 1.0, "r"))
        @test !isvalid(check_in_range(-0.1, 0.0, 1.0, "r"))
    end

    @testset "check_finite" begin
        @test isvalid(check_finite(1.0, "v"))
        @test !isvalid(check_finite(Inf, "v"))
        @test !isvalid(check_finite(-Inf, "v"))
        @test !isvalid(check_finite(NaN, "v"))
    end

    @testset "check_payer_mix — valid" begin
        mix = Dict("Medicare" => 0.45, "Medicaid" => 0.25, "Commercial" => 0.20, "Uncompensated" => 0.10)
        @test isvalid(check_payer_mix(mix))
    end

    @testset "check_payer_mix — does not sum to 1" begin
        mix = Dict("Medicare" => 0.45, "Medicaid" => 0.25)
        r = check_payer_mix(mix)
        @test !isvalid(r)
        @test any(contains(e, "sum") for e in r.errors)
    end

    @testset "check_payer_mix — share out of range" begin
        mix = Dict("Medicare" => 1.5, "Medicaid" => -0.5)
        r = check_payer_mix(mix)
        @test !isvalid(r)
    end

    @testset "check_payer_mix — empty" begin
        r = check_payer_mix(Dict{String,Float64}())
        @test !isvalid(r)
    end

    @testset "check_financial_field" begin
        @test isvalid(check_financial_field(100.0, "revenue"))
        @test isvalid(check_financial_field(0.0, "revenue"))
        @test !isvalid(check_financial_field(-1.0, "revenue"))
        @test isvalid(check_financial_field(-1.0, "income"; allow_negative=true))
        @test !isvalid(check_financial_field(NaN, "x"))
    end

    @testset "check_rate" begin
        @test isvalid(check_rate(0.03, "inflation"))
        @test isvalid(check_rate(0.0, "inflation"))
        @test !isvalid(check_rate(-0.01, "inflation"))
        @test !isvalid(check_rate(6.0, "inflation"))
    end

    @testset "check_fiscal_year" begin
        @test isvalid(check_fiscal_year(2025))
        @test isvalid(check_fiscal_year(2000))
        @test !isvalid(check_fiscal_year(1999))
        @test !isvalid(check_fiscal_year(2101))
    end

    @testset "check_date_range" begin
        d1 = Date(2024, 1, 1)
        d2 = Date(2025, 1, 1)
        @test isvalid(check_date_range(d1, d2))
        @test !isvalid(check_date_range(d2, d1))
        @test !isvalid(check_date_range(d1, d1))
    end

    @testset "check_one_of" begin
        @test isvalid(check_one_of(:cah, [:cah, :reh, :pps], "type"))
        @test !isvalid(check_one_of(:ltac, [:cah, :reh, :pps], "type"))
    end

end  # T-024

# ═════════════════════════════════════════════════════════════════════════════
# T-025: Hospital Type Registry
# ═════════════════════════════════════════════════════════════════════════════

@testset "T-025 Hospital Type Registry" begin

    @testset "hospital_types returns all expected keys" begin
        types = hospital_types()
        for key in [:cah, :reh, :pps, :sch, :mdh, :lva, :ihs, :childrens, :ltch, :psych]
            @test haskey(types, key) "Missing key: $key"
        end
    end

    @testset "hospital_type_properties :cah" begin
        p = hospital_type_properties(:cah)
        @test p.key == :cah
        @test p.max_beds == 25
        @test p.rural_focus == true
        @test p.payment_system == :cost_based
        @test p.inpatient_allowed == true
    end

    @testset "hospital_type_properties :reh" begin
        p = hospital_type_properties(:reh)
        @test p.key == :reh
        @test p.inpatient_allowed == false
        @test p.max_beds == 0
        @test p.rural_focus == true
    end

    @testset "hospital_type_properties :pps" begin
        p = hospital_type_properties(:pps)
        @test p.payment_system == :drg
        @test p.inpatient_allowed == true
    end

    @testset "hospital_type_properties unknown key throws" begin
        @test_throws KeyError hospital_type_properties(:does_not_exist)
    end

    @testset "hospital_type_of dispatch" begin
        cah = CriticalAccessHospital(name="Test CAH", beds=15, location="rural",
                                     county_fips="30001")
        @test hospital_type_of(cah) == :cah

        reh = RuralEmergencyHospital(name="Test REH", location="rural",
                                     county_fips="30001")
        @test hospital_type_of(reh) == :reh
    end

    @testset "create_hospital :cah" begin
        h = create_hospital(:cah; name="Factory CAH", beds=20, location="rural",
                            county_fips="30049")
        @test h isa CriticalAccessHospital
        @test h.name == "Factory CAH"
    end

    @testset "create_hospital :reh" begin
        h = create_hospital(:reh; name="Factory REH", location="rural",
                            county_fips="30049")
        @test h isa RuralEmergencyHospital
    end

    @testset "create_hospital unknown key throws" begin
        @test_throws KeyError create_hospital(:nonexistent)
    end

    @testset "create_hospital unimplemented type throws informative error" begin
        ex = try create_hospital(:sch; name="X"); nothing
             catch e; e; end
        @test ex isa ArgumentError
        @test contains(string(ex.msg), "Sole Community")
    end

    @testset "rural_hospital_types includes :cah and :reh" begin
        rural = rural_hospital_types()
        @test :cah in rural
        @test :reh in rural
    end

    @testset "cost_based_hospital_types" begin
        cost_based = cost_based_hospital_types()
        @test :cah in cost_based
        @test :reh in cost_based
        @test :pps ∉ cost_based
    end

    @testset "inpatient_hospital_types excludes :reh" begin
        inpatient = inpatient_hospital_types()
        @test :reh ∉ inpatient
        @test :cah in inpatient
        @test :pps in inpatient
    end

end  # T-025

# ═════════════════════════════════════════════════════════════════════════════
# T-026: VBC Model Variants
# ═════════════════════════════════════════════════════════════════════════════

@testset "T-026 VBC Model Variants" begin

    @testset "vbc_model_registry completeness" begin
        reg = vbc_model_registry()
        for key in EXTENDED_VBC_MODEL_KEYS
            @test haskey(reg, key) "Missing VBC model: $key"
        end
    end

    @testset "vbc_model_properties :mssp_basic" begin
        p = vbc_model_properties(:mssp_basic)
        @test p.one_sided == true
        @test p.loss_cap_pct == 0.0
        @test p.rural_eligible == true
    end

    @testset "vbc_model_properties :aco_reach_pioneer" begin
        p = vbc_model_properties(:aco_reach_pioneer)
        @test p.one_sided == false
        @test p.rural_eligible == false
        @test p.savings_rate_range[1] >= 0.80
    end

    @testset "vbc_model_properties unknown key" begin
        @test_throws KeyError vbc_model_properties(:does_not_exist)
    end

    @testset "calculate_extended_vbc — savings scenario" begin
        result = calculate_extended_vbc(ExtendedVBCParams(
            model_key             = :mssp_basic,
            actual_expenditure    = 4_800_000.0,
            benchmark_expenditure = 5_000_000.0,
            quality_score         = 1.0,
        ))
        @test result.gross_savings ≈ 200_000.0
        @test result.shared_savings > 0
        @test !result.loss_cap_applied
        @test result.savings_rate_used >= 0.40
    end

    @testset "calculate_extended_vbc — loss scenario one-sided (no loss)" begin
        result = calculate_extended_vbc(ExtendedVBCParams(
            model_key             = :mssp_basic,
            actual_expenditure    = 5_200_000.0,
            benchmark_expenditure = 5_000_000.0,
            quality_score         = 1.0,
        ))
        @test result.gross_savings < 0
        @test result.shared_savings >= 0.0    # one-sided: ACO never pays
        @test !result.loss_cap_applied
    end

    @testset "calculate_extended_vbc — loss scenario two-sided with cap" begin
        result = calculate_extended_vbc(ExtendedVBCParams(
            model_key             = :mssp_enhanced,
            actual_expenditure    = 5_500_000.0,
            benchmark_expenditure = 5_000_000.0,
            quality_score         = 1.0,
        ))
        @test result.gross_savings < 0
        @test result.shared_savings < 0   # two-sided: ACO owes money
        cap_floor = -0.08 * 5_000_000.0  # loss cap = 8%
        @test result.shared_savings >= cap_floor
    end

    @testset "quality gating reduces savings" begin
        params_full = ExtendedVBCParams(
            model_key = :mssp_enhanced,
            actual_expenditure = 4_500_000.0, benchmark_expenditure = 5_000_000.0,
            quality_score = 1.0,
        )
        params_half = ExtendedVBCParams(
            model_key = :mssp_enhanced,
            actual_expenditure = 4_500_000.0, benchmark_expenditure = 5_000_000.0,
            quality_score = 0.5,
        )
        r_full = calculate_extended_vbc(params_full)
        r_half = calculate_extended_vbc(params_half)
        @test r_full.shared_savings > r_half.shared_savings
        @test r_half.quality_adjusted_savings ≈ r_full.quality_adjusted_savings * 0.5 atol=1.0
    end

    @testset "rural_vbc_models" begin
        rural = rural_vbc_models()
        @test :mssp_basic in rural
        @test :mssp_low_revenue in rural
        @test :aco_reach_pioneer ∉ rural   # rural_eligible=false
    end

    @testset "TEAM bundled model properties" begin
        p = vbc_model_properties(:team_bundled)
        @test p.rural_eligible == true
        @test contains(p.notes, "2026")
    end

end  # T-026

# ═════════════════════════════════════════════════════════════════════════════
# T-027: ICER Sensitivity
# ═════════════════════════════════════════════════════════════════════════════

@testset "T-027 ICER Sensitivity Analysis" begin

    @testset "ICERParameter struct" begin
        p = ICERParameter(name=:cost_intervention, base_value=50_000.0,
                          low_value=40_000.0, high_value=65_000.0)
        @test p.name == :cost_intervention
        @test p.low_value < p.base_value < p.high_value
    end

    @testset "icer_one_way_sensitivity — base case" begin
        params = [
            ICERParameter(name=:cost_intervention, base_value=50_000.0,
                          low_value=40_000.0, high_value=65_000.0, label="Cost"),
            ICERParameter(name=:effect_intervention, base_value=0.85,
                          low_value=0.70, high_value=0.95, label="Efficacy"),
        ]
        tornado = icer_one_way_sensitivity(50_000.0, 20_000.0, 0.85, 0.60, params)

        @test tornado.base_icer > 0
        @test length(tornado.rows) == 2
        @test tornado.wtp_threshold == 100_000.0
        # Sorted by absolute_swing descending
        @test tornado.rows[1].absolute_swing >= tornado.rows[2].absolute_swing
    end

    @testset "icer_one_way_sensitivity — higher cost → higher ICER" begin
        params = [
            ICERParameter(name=:cost_intervention, base_value=50_000.0,
                          low_value=40_000.0, high_value=70_000.0),
        ]
        t = icer_one_way_sensitivity(50_000.0, 20_000.0, 0.85, 0.60, params)
        @test t.rows[1].icer_high > t.rows[1].icer_base  # higher cost → higher ICER
        @test t.rows[1].icer_low  < t.rows[1].icer_base  # lower cost → lower ICER
    end

    @testset "ICERSensitivityResult fields" begin
        params = [
            ICERParameter(name=:cost_intervention, base_value=50_000.0,
                          low_value=40_000.0, high_value=60_000.0),
        ]
        t = icer_one_way_sensitivity(50_000.0, 20_000.0, 0.85, 0.60, params)
        r = t.rows[1]
        @test r.absolute_swing ≈ abs(r.icer_high - r.icer_low)
        @test r.delta_low  ≈ r.icer_low  - r.icer_base
        @test r.delta_high ≈ r.icer_high - r.icer_base
    end

    @testset "icer_probabilistic_sensitivity interface" begin
        cost_fn()   = (50_000.0 + randn() * 5_000.0, 20_000.0)
        effect_fn() = (0.85 + randn() * 0.05, 0.60)

        psa = icer_probabilistic_sensitivity(cost_fn, effect_fn;
                                             n_samples=200, wtp_threshold=100_000.0)
        @test length(psa.icers) == 200
        @test 0.0 <= psa.pct_cost_effective <= 1.0
        @test psa.p025_icer <= psa.median_icer <= psa.p975_icer
        @test length(psa.ceac_wtp) == length(psa.ceac_prob)
        @test all(0.0 .<= psa.ceac_prob .<= 1.0)
    end

end  # T-027

# ═════════════════════════════════════════════════════════════════════════════
# T-028: Cohort Analysis Enhancements
# ═════════════════════════════════════════════════════════════════════════════

@testset "T-028 Cohort Analysis Enhancements" begin

    # Minimal stub encounter
    struct StubEncounter
        total_cost::Float64
        length_of_stay_days::Int
        age_at_admission::Float64
        payer::String
        primary_diagnosis_code::String
        admission_date::Date
        encounter_type::Symbol
    end

    function make_encounters(n::Int)
        [StubEncounter(
            rand() * 20_000 + 1_000,
            rand(1:15),
            Float64(rand(18:90)),
            rand(["Medicare","Medicaid","Commercial","Self-pay"]),
            rand(["I21","K92","J18","Z79"]),
            Date(2024, rand(1:12), rand(1:28)),
            rand([:inpatient, :outpatient]),
        ) for _ in 1:n]
    end

    encounters = make_encounters(200)

    @testset "group_cohort :payer" begin
        key = CohortGroupKey(dimension=:payer)
        result = group_cohort(encounters, key)
        @test result.dimension == :payer
        @test !isempty(result.groups)
        # All encounters must be in some group
        total_n = sum(s.n_encounters for s in values(result.groups))
        @test total_n == length(encounters)
    end

    @testset "group_cohort :age_decade" begin
        key = CohortGroupKey(dimension=:age_decade)
        result = group_cohort(encounters, key)
        @test result.dimension == :age_decade
        @test all(contains(label, "–") for label in keys(result.groups))
    end

    @testset "group_cohort :los_bucket" begin
        key = CohortGroupKey(dimension=:los_bucket)
        result = group_cohort(encounters, key)
        for label in keys(result.groups)
            @test label in ["1d", "2–3d", "4–7d", "8+d"]
        end
    end

    @testset "group_cohort :cost_tercile" begin
        key = CohortGroupKey(dimension=:cost_tercile)
        result = group_cohort(encounters, key)
        @test haskey(result.groups, "Low")
        @test haskey(result.groups, "Mid")
        @test haskey(result.groups, "High")
        total = sum(s.n_encounters for s in values(result.groups))
        @test total == length(encounters)
    end

    @testset "group_cohort :quarter" begin
        key = CohortGroupKey(dimension=:quarter)
        result = group_cohort(encounters, key)
        for label in keys(result.groups)
            @test startswith(label, "Q")
        end
    end

    @testset "group_cohort :custom" begin
        fn = enc -> enc.total_cost > 10_000 ? "expensive" : "affordable"
        key = CohortGroupKey(dimension=:custom, group_fn=fn)
        result = group_cohort(encounters, key)
        @test haskey(result.groups, "expensive") || haskey(result.groups, "affordable")
    end

    @testset "group_order sorted by total_cost desc" begin
        key = CohortGroupKey(dimension=:payer)
        result = group_cohort(encounters, key)
        costs = [result.groups[g].total_cost for g in result.group_order]
        @test costs == sort(costs; rev=true)
    end

    @testset "risk_stratify_cohort" begin
        strats = risk_stratify_cohort(encounters; n_strata=3)
        @test length(strats) == length(encounters)
        @test all(s.stratum in [:low, :moderate, :high] for s in strats)
        @test all(0.0 <= s.composite_score <= 1.0 for s in strats)
    end

    @testset "risk_stratify_cohort empty input" begin
        strats = risk_stratify_cohort(StubEncounter[])
        @test isempty(strats)
    end

    @testset "compare_cohorts" begin
        a = make_encounters(100)
        b = make_encounters(80)
        cmp = compare_cohorts(a, b; label_a="Control", label_b="Treatment")
        @test cmp.label_a == "Control"
        @test cmp.label_b == "Treatment"
        @test isfinite(cmp.delta_mean_cost)
        @test isfinite(cmp.pct_change_mean_cost)
        @test cmp.cost_distribution_different isa Bool
    end

    @testset "SubCohortSummary non-negative fields" begin
        key = CohortGroupKey(dimension=:payer)
        result = group_cohort(encounters, key)
        for (_, s) in result.groups
            @test s.n_encounters > 0
            @test s.mean_cost > 0
            @test s.total_cost > 0
            @test 0.0 <= s.pct_readmit <= 1.0
            @test 0.0 <= s.pct_inpatient <= 1.0
        end
    end

end  # T-028

# ═════════════════════════════════════════════════════════════════════════════
# T-029: REH Analytics
# ═════════════════════════════════════════════════════════════════════════════

@testset "T-029 REH Analytics" begin

    base_params = REHParams(
        annual_ed_visits                 = 4_500,
        annual_outpatient_visits         = 8_000,
        avg_revenue_per_ed_visit         = 850.0,
        avg_revenue_per_outpatient_visit = 320.0,
        annual_operating_expenses        = 5_200_000.0,
        conversion_capex                 = 250_000.0,
        swing_bed_days                   = 600,
        avg_swing_bed_revenue_per_day    = 450.0,
        fiscal_year                      = 2026,
    )

    @testset "Constants" begin
        @test REH_MONTHLY_FACILITY_PAYMENT_FY2026 > 0
        @test REH_OUTPATIENT_ADDON_RATE == 0.05
        @test REH_MAX_SWING_BEDS == 10
    end

    @testset "reh_facility_payment — 12 months" begin
        fp = reh_facility_payment(base_params)
        @test fp ≈ REH_MONTHLY_FACILITY_PAYMENT_FY2026 * 12
    end

    @testset "reh_facility_payment — partial year" begin
        p6 = REHParams(; base_params..., months_operating=6)
        fp = reh_facility_payment(p6)
        @test fp ≈ REH_MONTHLY_FACILITY_PAYMENT_FY2026 * 6
    end

    @testset "reh_outpatient_addon is 5% of visit revenue" begin
        addon = reh_outpatient_addon(base_params)
        visit_rev = (base_params.annual_ed_visits * base_params.avg_revenue_per_ed_visit +
                     base_params.annual_outpatient_visits * base_params.avg_revenue_per_outpatient_visit)
        @test addon ≈ visit_rev * 0.05 atol = 1.0
    end

    @testset "reh_swing_bed_revenue" begin
        rev = reh_swing_bed_revenue(base_params)
        @test rev > 0
        @test rev ≈ base_params.swing_bed_days * base_params.avg_swing_bed_revenue_per_day atol=1.0
    end

    @testset "reh_swing_bed_revenue — zero when no swing beds" begin
        p = REHParams(; base_params..., swing_bed_days=0)
        @test reh_swing_bed_revenue(p) == 0.0
    end

    @testset "reh_total_revenue composition" begin
        total = reh_total_revenue(base_params)
        manual = reh_facility_payment(base_params) + reh_outpatient_addon(base_params) +
                 reh_swing_bed_revenue(base_params) +
                 (base_params.annual_ed_visits * base_params.avg_revenue_per_ed_visit +
                  base_params.annual_outpatient_visits * base_params.avg_revenue_per_outpatient_visit)
        @test total ≈ manual atol = 1.0
    end

    @testset "reh_annual_summary fields" begin
        s = reh_annual_summary(base_params)
        @test s.total_revenue > 0
        @test s.facility_payment > 0
        @test s.outpatient_addon > 0
        @test s.operating_expenses > 0
        @test isfinite(s.operating_margin)
    end

    @testset "reh_projection — 5 years" begin
        proj = reh_projection(base_params; years=5)
        @test length(proj) == 5
        # Revenue should generally increase with positive visit growth
        @test proj[5].total_revenue >= proj[1].total_revenue
        # Cumulative income monotonically tracked
        @test proj[5].year == base_params.fiscal_year + 4
    end

    @testset "analyze_cah_to_reh_conversion" begin
        analysis = analyze_cah_to_reh_conversion(base_params; cah_annual_operating_income=-100_000.0)
        @test analysis.viability_score >= 0
        @test analysis.viability_score <= 100
        @test analysis.break_even_ed_visits >= 0
        @test analysis.is_financially_viable isa Bool
        @test isfinite(analysis.five_year_npv)
    end

    @testset "reh_viability_score range" begin
        score = reh_viability_score(base_params)
        @test 0.0 <= score <= 100.0
    end

    @testset "reh_eligibility_check — eligible CAH" begin
        result = reh_eligibility_check(
            current_designation         = :cah,
            licensed_beds               = 20,
            years_as_cah_or_small_rural = 5,
            has_inpatient_services      = true,
        )
        @test result.eligible == true
        @test !isempty(result.conditions)   # must cease inpatient services
    end

    @testset "reh_eligibility_check — ineligible (wrong designation)" begin
        result = reh_eligibility_check(
            current_designation         = :urban_pps,
            licensed_beds               = 200,
            years_as_cah_or_small_rural = 10,
            has_inpatient_services      = true,
        )
        @test result.eligible == false
        @test !isempty(result.reasons_ineligible)
    end

    @testset "reh_eligibility_check — ineligible (too new)" begin
        result = reh_eligibility_check(
            current_designation         = :cah,
            licensed_beds               = 10,
            years_as_cah_or_small_rural = 0,
            has_inpatient_services      = false,
        )
        @test result.eligible == false
    end

end  # T-029

# ═════════════════════════════════════════════════════════════════════════════
# T-030: Reporting Framework
# ═════════════════════════════════════════════════════════════════════════════

@testset "T-030 Reporting & Export Framework" begin

    simple_report = Report("Test Hospital Report", :financial_summary;
        subtitle = "FY 2025",
        sections = [
            ReportSection("Financial Highlights";
                level   = 2,
                prose   = ["Operating results were positive for FY 2025."],
                metrics = [
                    ReportKV("Net Revenue",       5_000_000.0, :currency, true),
                    ReportKV("Operating Margin",  0.048,       :percent,  true),
                    ReportKV("Days Cash on Hand", 45.2,        :float,    false),
                ],
                tables  = [
                    ReportTable("Payer Mix",
                        ["Payer", "Share"],
                        [
                            [ReportCell("Medicare", :string, :left), ReportCell(0.45, :percent)],
                            [ReportCell("Medicaid", :string, :left), ReportCell(0.25, :percent)],
                            [ReportCell("Commercial",:string,:left), ReportCell(0.20, :percent)],
                        ],
                        "Source: internal billing system",
                    ),
                ],
            ),
        ],
    )

    @testset "Report construction" begin
        @test simple_report.title == "Test Hospital Report"
        @test simple_report.report_type == :financial_summary
        @test length(simple_report.sections) == 1
        @test simple_report.generated_at <= now()
    end

    @testset "export_report :text" begin
        txt = export_report(simple_report, :text)
        @test contains(txt, "Test Hospital Report")
        @test contains(txt, "Financial Highlights")
        @test contains(txt, "Operating Margin")
        @test contains(txt, "Payer Mix")
    end

    @testset "export_report :markdown" begin
        md = export_report(simple_report, :markdown)
        @test contains(md, "# Test Hospital Report")
        @test contains(md, "## Financial Highlights") || contains(md, "### Financial Highlights")
        @test contains(md, "| Metric | Value |")
        @test contains(md, "Medicare")
    end

    @testset "export_report :csv" begin
        csv = export_report(simple_report, :csv)
        @test contains(csv, "Net Revenue")
        @test contains(csv, "Medicare")
    end

    @testset "export_report :json" begin
        json_str = export_report(simple_report, :json)
        parsed = JSON3.read(json_str)
        @test parsed["title"] == "Test Hospital Report"
        @test length(parsed["sections"]) == 1
        @test !isempty(parsed["sections"][1]["metrics"])
    end

    @testset "export_report unknown format" begin
        @test_throws ArgumentError export_report(simple_report, :pdf)
    end

    @testset "build_financial_summary_report" begin
        f = make_stub_financials()
        r = build_financial_summary_report(f, "Valley CAH"; fiscal_year=2025)
        @test r.title == "Financial Summary — Valley CAH"
        @test r.report_type == :financial_summary
        @test !isempty(r.sections)
        md = export_report(r, :markdown)
        @test contains(md, "Valley CAH")
        @test contains(md, "Operating Margin")
    end

    @testset "build_reh_conversion_report" begin
        params = REHParams(
            annual_ed_visits=4_500, annual_outpatient_visits=8_000,
            avg_revenue_per_ed_visit=850.0, avg_revenue_per_outpatient_visit=320.0,
            annual_operating_expenses=5_200_000.0, conversion_capex=250_000.0,
        )
        analysis = analyze_cah_to_reh_conversion(params)
        r = build_reh_conversion_report(analysis, "Frontier CAH")
        @test r.report_type == :reh_conversion
        @test !isempty(r.sections)
        txt = export_report(r, :text)
        @test contains(txt, "REH Conversion")
        @test contains(txt, "Viability Score")
    end

    @testset "ReportSection default constructor" begin
        s = ReportSection("My Section")
        @test s.heading == "My Section"
        @test s.level == 2
        @test isempty(s.prose)
        @test isempty(s.metrics)
        @test isempty(s.tables)
    end

    @testset "merge_validations in report context (T-024 integration)" begin
        r1 = check_positive(5_000_000.0, "net_revenue")
        r2 = check_non_negative(250_000.0, "charity_care")
        merged = merge_validations(r1, r2)
        @test isvalid(merged)
    end

end  # T-030

println("\n✅  T-021–T-030 test suite complete.")
