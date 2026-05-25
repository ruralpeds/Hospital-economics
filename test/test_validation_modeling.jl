using Test
using Dates
using Distributions
using Random

include(joinpath(@__DIR__, "..", "src", "validation", "fmea.jl"))
include(joinpath(@__DIR__, "..", "src", "validation", "requirement_traceability.jl"))
include(joinpath(@__DIR__, "..", "src", "validation", "parity_testing.jl"))
include(joinpath(@__DIR__, "..", "src", "validation", "verification_registry.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "pk_ode.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "bayesian_analysis.jl"))

# ═══════════════════════════════════════════════════════════════
# FMEA — Failure Mode and Effects Analysis
# ═══════════════════════════════════════════════════════════════

@testset "FMEA — Failure Mode and Effects Analysis" begin
    @testset "RPN calculation" begin
        @test calculate_rpn(3, 4, 2) == 24
        @test calculate_rpn(5, 5, 5) == 125
        @test calculate_rpn(1, 1, 1) == 1
    end

    @testset "risk acceptability — acceptable" begin
        @test assess_risk_acceptability(30) == :acceptable
        @test assess_risk_acceptability(50) == :acceptable
        @test assess_risk_acceptability(99) == :acceptable
    end

    @testset "risk acceptability — needs mitigation" begin
        @test assess_risk_acceptability(100) == :needs_mitigation
        @test assess_risk_acceptability(150) == :needs_mitigation
        @test assess_risk_acceptability(199) == :needs_mitigation
    end

    @testset "risk acceptability — unacceptable" begin
        @test assess_risk_acceptability(200) == :unacceptable
        @test assess_risk_acceptability(300) == :unacceptable
    end

    @testset "risk acceptability — custom threshold" begin
        @test assess_risk_acceptability(40, threshold=50) == :acceptable
        @test assess_risk_acceptability(50, threshold=50) == :needs_mitigation
        @test assess_risk_acceptability(100, threshold=50) == :unacceptable
    end

    @testset "report generation — with modes" begin
        modes = [
            FailureMode(id="FM-001", description="Calculation error", component="Finance",
                        severity=4, probability=3, detectability=2,
                        residual_severity=2, residual_probability=2),
            FailureMode(id="FM-002", description="Data loss", component="Storage",
                        severity=5, probability=2, detectability=3,
                        residual_severity=3, residual_probability=1),
        ]
        report = generate_fmea_report(modes)

        @test report.max_rpn == maximum(m.rpn for m in modes)
        @test report.average_rpn > 0.0
        @test report.risk_reduction_pct >= 0.0
        @test length(report.failure_modes) == 2
    end

    @testset "report generation — empty modes" begin
        report = generate_fmea_report(FailureMode[])

        @test report.high_risk_count == 0
        @test report.average_rpn == 0.0
        @test report.max_rpn == 0
        @test report.risk_reduction_pct == 0.0
    end

    @testset "report generation — high risk count" begin
        modes = [
            FailureMode(id="FM-A", description="Low risk", component="C1",
                        severity=2, probability=2, detectability=2),  # RPN = 8
            FailureMode(id="FM-B", description="High risk", component="C2",
                        severity=5, probability=5, detectability=5),  # RPN = 125
            FailureMode(id="FM-C", description="Moderate risk", component="C3",
                        severity=4, probability=4, detectability=3),  # RPN = 48
        ]
        report = generate_fmea_report(modes)

        # FM-A: 8 < 100 => acceptable
        # FM-B: 125 >= 100 => needs mitigation (not acceptable)
        # FM-C: 48 < 100 => acceptable
        @test report.high_risk_count == 1
    end

    @testset "report — risk reduction from controls" begin
        # Mode with residual RPN less than initial RPN
        modes = [
            FailureMode(id="FM-X", description="Controlled failure", component="System",
                        severity=5, probability=4, detectability=3,
                        controls=[:preventive],
                        residual_severity=3, residual_probability=2),
        ]
        report = generate_fmea_report(modes)

        @test modes[1].rpn == 60  # 5*4*3
        @test modes[1].residual_rpn == 18  # 3*2*3
        @test report.risk_reduction_pct > 0.0
        @test report.risk_reduction_pct ≈ (1.0 - 18.0 / 60.0) * 100.0
    end

    @testset "prioritize failure modes — sorted by RPN descending" begin
        modes = [
            FailureMode(id="FM-1", description="Low", component="A",
                        severity=1, probability=1, detectability=1),  # RPN = 1
            FailureMode(id="FM-2", description="High", component="B",
                        severity=5, probability=5, detectability=5),  # RPN = 125
            FailureMode(id="FM-3", description="Medium", component="C",
                        severity=3, probability=3, detectability=3),  # RPN = 27
        ]
        sorted = prioritize_failure_modes(modes)

        @test sorted[1].id == "FM-2"
        @test sorted[2].id == "FM-3"
        @test sorted[3].id == "FM-1"
        @test sorted[1].rpn >= sorted[2].rpn >= sorted[3].rpn
    end
end

# ═══════════════════════════════════════════════════════════════
# Requirement Traceability
# ═══════════════════════════════════════════════════════════════

@testset "Requirement Traceability" begin
    @testset "add requirement and verify" begin
        matrix = create_traceability_matrix()
        req = Requirement(id="FR-001", description="Calculate VBP scores",
                          category=:functional, status=:implemented,
                          source="CMS", affected_modules=["quality"],
                          verification_method=:unit_test)
        add_requirement!(matrix, req)

        @test haskey(matrix.requirements, "FR-001")
        @test matrix.requirements["FR-001"].description == "Calculate VBP scores"
        @test matrix.requirements["FR-001"].status == :implemented
    end

    @testset "mark verified updates status" begin
        matrix = create_traceability_matrix()
        add_requirement!(matrix, Requirement(id="FR-001", description="Test requirement",
                                             status=:implemented))
        mark_verified!(matrix, "FR-001", :unit_test, "tester1")

        @test matrix.requirements["FR-001"].status == :verified
        @test matrix.requirements["FR-001"].verified_by == "tester1"
        @test matrix.requirements["FR-001"].verified_date !== nothing
    end

    @testset "mark verified — nonexistent requirement" begin
        matrix = create_traceability_matrix()
        @test_throws KeyError mark_verified!(matrix, "MISSING", :unit_test, "tester")
    end

    @testset "coverage report — full coverage" begin
        matrix = create_traceability_matrix()
        add_requirement!(matrix, Requirement(id="FR-001", description="A", status=:verified))
        add_requirement!(matrix, Requirement(id="FR-002", description="B", status=:verified))

        report = coverage_report(matrix)

        @test report.total == 2
        @test report.verified == 2
        @test report.coverage_pct ≈ 100.0
        @test isempty(report.gaps)
    end

    @testset "coverage report — partial coverage" begin
        matrix = create_traceability_matrix()
        add_requirement!(matrix, Requirement(id="FR-001", description="A", status=:verified))
        add_requirement!(matrix, Requirement(id="FR-002", description="B", status=:implemented))
        add_requirement!(matrix, Requirement(id="FR-003", description="C", status=:draft))

        report = coverage_report(matrix)

        @test report.total == 3
        @test report.verified == 1
        @test report.coverage_pct ≈ (1.0 / 3.0) * 100.0
        @test length(report.gaps) == 2
    end

    @testset "coverage report — empty matrix" begin
        matrix = create_traceability_matrix()
        report = coverage_report(matrix)

        @test report.total == 0
        @test report.verified == 0
        @test report.coverage_pct == 0.0
    end

    @testset "find unverified — returns implemented-only" begin
        matrix = create_traceability_matrix()
        add_requirement!(matrix, Requirement(id="FR-001", description="A", status=:draft))
        add_requirement!(matrix, Requirement(id="FR-002", description="B", status=:implemented))
        add_requirement!(matrix, Requirement(id="FR-003", description="C", status=:verified))

        unverified = find_unverified(matrix)

        @test length(unverified) == 1
        @test unverified[1].id == "FR-002"
    end

    @testset "find orphaned tests" begin
        matrix = create_traceability_matrix()
        add_requirement!(matrix, Requirement(id="FR-001", description="A",
                                             affected_modules=["mod_a", "mod_b"]))

        test_ids = ["FR-001", "mod_a", "mod_b", "orphan_test_1", "orphan_test_2"]
        orphans = find_orphaned_tests(matrix, test_ids)

        @test "orphan_test_1" in orphans
        @test "orphan_test_2" in orphans
        @test !("FR-001" in orphans)
        @test !("mod_a" in orphans)
    end

    @testset "cache invalidation on add" begin
        matrix = create_traceability_matrix()
        add_requirement!(matrix, Requirement(id="FR-001", description="A", status=:verified))
        _ = coverage_report(matrix)
        @test matrix.coverage_stats !== nothing

        add_requirement!(matrix, Requirement(id="FR-002", description="B", status=:draft))
        @test matrix.coverage_stats === nothing  # invalidated by add
    end
end

# ═══════════════════════════════════════════════════════════════
# Parity Testing
# ═══════════════════════════════════════════════════════════════

@testset "Parity Testing" begin
    @testset "passing test — identical implementations" begin
        test = ParityTest(
            name="square_parity",
            implementation_a=x -> x^2,
            implementation_b=x -> x * x,
            input_generator=() -> rand(),
            tolerance=1e-12,
        )
        result = run_parity_test(test; n_samples=50)

        @test result.passed == true
        @test result.max_deviation < 1e-12
        @test result.mean_deviation < 1e-12
        @test result.n_tests == 50
        @test isempty(result.failures)
    end

    @testset "failing test — divergent implementations" begin
        test = ParityTest(
            name="broken_parity",
            implementation_a=x -> x^2,
            implementation_b=x -> x^2 + 1.0,
            input_generator=() -> 5.0,
            tolerance=1e-9,
        )
        result = run_parity_test(test; n_samples=10)

        @test result.passed == false
        @test result.max_deviation ≈ 1.0
        @test !isempty(result.failures)
        @test result.failures[1].deviation ≈ 1.0
    end

    @testset "parity suite — all pass" begin
        suite = ParityTestSuite()
        push!(suite.tests, ParityTest(
            name="add_parity",
            implementation_a=x -> x + 1.0,
            implementation_b=x -> 1.0 + x,
            input_generator=() -> rand(),
            tolerance=1e-12))
        push!(suite.tests, ParityTest(
            name="mult_parity",
            implementation_a=x -> x * 2.0,
            implementation_b=x -> 2.0 * x,
            input_generator=() -> rand(),
            tolerance=1e-12))

        all_passed = run_parity_suite(suite)

        @test all_passed == true
        @test length(suite.results) == 2
        @test all(r -> r.passed, suite.results)
    end

    @testset "parity suite — one fails" begin
        suite = ParityTestSuite()
        push!(suite.tests, ParityTest(
            name="good",
            implementation_a=x -> x,
            implementation_b=x -> x,
            input_generator=() -> 1.0,
            tolerance=1e-9))
        push!(suite.tests, ParityTest(
            name="bad",
            implementation_a=x -> x,
            implementation_b=x -> x + 100.0,
            input_generator=() -> 1.0,
            tolerance=1e-9))

        all_passed = run_parity_suite(suite)

        @test all_passed == false
        @test suite.results[1].passed == true
        @test suite.results[2].passed == false
    end

    @testset "parity report formatting" begin
        suite = ParityTestSuite()
        push!(suite.tests, ParityTest(
            name="sample_test",
            implementation_a=x -> x,
            implementation_b=x -> x,
            input_generator=() -> 1.0,
            tolerance=1e-9))
        run_parity_suite(suite)
        report_str = parity_report(suite)

        @test contains(report_str, "Parity Test Report")
        @test contains(report_str, "sample_test")
        @test contains(report_str, "PASS")
    end
end

# ═══════════════════════════════════════════════════════════════
# Verification Registry
# ═══════════════════════════════════════════════════════════════

@testset "Verification Registry" begin
    @testset "register and report" begin
        registry = VerificationRegistry()

        register_verification!(registry, VerificationRecord(
            requirement_id="FR-001", method=:unit_test,
            test_id="test_vbp_001", result=:pass))
        register_verification!(registry, VerificationRecord(
            requirement_id="FR-002", method=:integration_test,
            test_id="test_hrrp_001", result=:pass))

        @test length(registry.records) == 2
    end

    @testset "coverage by requirement — pass/fail/skip" begin
        registry = VerificationRegistry()

        register_verification!(registry, VerificationRecord(
            requirement_id="FR-001", method=:unit_test,
            test_id="t1", result=:pass))
        register_verification!(registry, VerificationRecord(
            requirement_id="FR-002", method=:unit_test,
            test_id="t2", result=:fail))
        register_verification!(registry, VerificationRecord(
            requirement_id="FR-003", method=:unit_test,
            test_id="t3", result=:skip))

        cov = coverage_by_requirement(registry)

        @test cov["FR-001"] == :pass
        @test cov["FR-002"] == :fail
        @test cov["FR-003"] == :skip
    end

    @testset "fail overrides pass for same requirement" begin
        registry = VerificationRegistry()

        register_verification!(registry, VerificationRecord(
            requirement_id="FR-001", method=:unit_test,
            test_id="t1a", result=:pass))
        register_verification!(registry, VerificationRecord(
            requirement_id="FR-001", method=:integration_test,
            test_id="t1b", result=:fail))

        cov = coverage_by_requirement(registry)
        @test cov["FR-001"] == :fail
    end

    @testset "coverage by method" begin
        registry = VerificationRegistry()

        register_verification!(registry, VerificationRecord(
            requirement_id="FR-001", method=:unit_test, test_id="t1"))
        register_verification!(registry, VerificationRecord(
            requirement_id="FR-002", method=:unit_test, test_id="t2"))
        register_verification!(registry, VerificationRecord(
            requirement_id="FR-003", method=:integration_test, test_id="t3"))

        by_method = coverage_by_method(registry)
        @test by_method[:unit_test] == 2
        @test by_method[:integration_test] == 1
    end

    @testset "generate coverage report" begin
        registry = VerificationRegistry()

        register_verification!(registry, VerificationRecord(
            requirement_id="FR-001", method=:unit_test, test_id="t1", result=:pass))
        register_verification!(registry, VerificationRecord(
            requirement_id="FR-002", method=:unit_test, test_id="t2", result=:fail))

        all_reqs = ["FR-001", "FR-002", "FR-003"]
        report = generate_coverage_report(registry, all_reqs)

        @test report.total == 3
        @test report.verified == 1
        @test report.failed == 1
        @test "FR-003" in report.unverified
        @test report.coverage_pct ≈ (1.0 / 3.0) * 100.0
    end

    @testset "generate coverage report — empty" begin
        registry = VerificationRegistry()
        report = generate_coverage_report(registry, String[])

        @test report.total == 0
        @test report.coverage_pct == 0.0
    end

    @testset "generate coverage report — all verified" begin
        registry = VerificationRegistry()
        register_verification!(registry, VerificationRecord(
            requirement_id="FR-001", method=:unit_test, test_id="t1", result=:pass))
        register_verification!(registry, VerificationRecord(
            requirement_id="FR-002", method=:unit_test, test_id="t2", result=:pass))

        report = generate_coverage_report(registry, ["FR-001", "FR-002"])
        @test report.verified == 2
        @test report.coverage_pct ≈ 100.0
        @test isempty(report.unverified)
    end
end

# ═══════════════════════════════════════════════════════════════
# PK ODE — Two-Compartment Pharmacokinetic Model
# ═══════════════════════════════════════════════════════════════

@testset "PK ODE — Two-Compartment Model" begin
    @testset "IV bolus — concentration curve" begin
        params = PKParams(
            dose=500.0,
            bioavailability=1.0,
            ka=0.0,  # IV bolus
            cl_central=10.0,
            cl_peripheral=5.0,
            v_central=50.0,
            v_peripheral=100.0,
        )
        result = simulate_pk(params; t_end=24.0, dt=0.1)

        @test length(result.times) > 0
        @test length(result.central_conc) == length(result.times)
        @test length(result.peripheral_conc) == length(result.times)
        # IV bolus: initial concentration = dose / V1
        @test result.central_conc[1] ≈ 500.0 / 50.0
        # Concentration should decay over time
        @test result.central_conc[end] < result.central_conc[1]
        @test result.auc > 0.0
    end

    @testset "oral dosing — peak finding" begin
        params = PKParams(
            dose=500.0,
            bioavailability=0.9,
            ka=1.0,  # first-order absorption
            cl_central=10.0,
            cl_peripheral=5.0,
            v_central=50.0,
            v_peripheral=100.0,
        )
        result = simulate_pk(params; t_end=24.0, dt=0.1)

        @test result.peak_concentration > 0.0
        @test result.time_to_peak > 0.0
        @test result.time_to_peak < 24.0
        # Central starts at 0 for oral dosing, rises to peak, then decays
        @test result.central_conc[1] == 0.0
    end

    @testset "terminal half-life" begin
        params = PKParams(
            dose=500.0,
            cl_central=10.0,
            cl_peripheral=5.0,
            v_central=50.0,
            v_peripheral=100.0,
        )
        result = simulate_pk(params; t_end=48.0, dt=0.05)

        @test result.terminal_half_life > 0.0
        @test isfinite(result.terminal_half_life)
    end

    @testset "AUC increases with dose" begin
        params_low = PKParams(
            dose=100.0,
            cl_central=10.0, cl_peripheral=5.0,
            v_central=50.0, v_peripheral=100.0)
        params_high = PKParams(
            dose=500.0,
            cl_central=10.0, cl_peripheral=5.0,
            v_central=50.0, v_peripheral=100.0)

        r_low = simulate_pk(params_low; t_end=24.0, dt=0.1)
        r_high = simulate_pk(params_high; t_end=24.0, dt=0.1)

        @test r_high.auc > r_low.auc
        # AUC should scale linearly with dose for linear PK
        @test r_high.auc / r_low.auc ≈ 5.0 atol=0.5
    end

    @testset "bioavailability reduces effective dose" begin
        params_full = PKParams(
            dose=500.0, bioavailability=1.0,
            cl_central=10.0, cl_peripheral=5.0,
            v_central=50.0, v_peripheral=100.0)
        params_half = PKParams(
            dose=500.0, bioavailability=0.5,
            cl_central=10.0, cl_peripheral=5.0,
            v_central=50.0, v_peripheral=100.0)

        r_full = simulate_pk(params_full; t_end=24.0, dt=0.1)
        r_half = simulate_pk(params_half; t_end=24.0, dt=0.1)

        @test r_half.peak_concentration < r_full.peak_concentration
        @test r_half.auc < r_full.auc
    end

    @testset "peripheral compartment receives drug" begin
        params = PKParams(
            dose=500.0,
            cl_central=10.0, cl_peripheral=5.0,
            v_central=50.0, v_peripheral=100.0)
        result = simulate_pk(params; t_end=24.0, dt=0.1)

        # Peripheral conc starts at 0 and should eventually have drug
        @test result.peripheral_conc[1] == 0.0
        @test maximum(result.peripheral_conc) > 0.0
    end
end

# ═══════════════════════════════════════════════════════════════
# Bayesian Beta-Binomial
# ═══════════════════════════════════════════════════════════════

@testset "Bayesian Beta-Binomial" begin
    @testset "posterior updating — uniform prior" begin
        input = BayesianBetaBinomialInput(
            prior_alpha=1.0, prior_beta=1.0,
            observed_events=7, total_observations=100,
        )
        result = analyze_beta_binomial(input)

        @test result.posterior_alpha ≈ 8.0    # 1 + 7
        @test result.posterior_beta ≈ 94.0    # 1 + (100 - 7)
        @test result.posterior_mean ≈ 8.0 / 102.0 atol=0.001
        @test result.prior_mean ≈ 0.5  # uniform prior
    end

    @testset "credible interval contains posterior mean" begin
        input = BayesianBetaBinomialInput(
            prior_alpha=2.0, prior_beta=5.0,
            observed_events=30, total_observations=100,
        )
        result = analyze_beta_binomial(input)

        @test result.credible_interval_95[1] < result.posterior_mean
        @test result.credible_interval_95[2] > result.posterior_mean
        @test result.credible_interval_95[1] >= 0.0
        @test result.credible_interval_95[2] <= 1.0
    end

    @testset "credible interval narrows with more data" begin
        input_small = BayesianBetaBinomialInput(
            prior_alpha=1.0, prior_beta=1.0,
            observed_events=5, total_observations=20,
        )
        input_large = BayesianBetaBinomialInput(
            prior_alpha=1.0, prior_beta=1.0,
            observed_events=50, total_observations=200,
        )
        r_small = analyze_beta_binomial(input_small)
        r_large = analyze_beta_binomial(input_large)

        width_small = r_small.credible_interval_95[2] - r_small.credible_interval_95[1]
        width_large = r_large.credible_interval_95[2] - r_large.credible_interval_95[1]

        @test width_large < width_small
    end

    @testset "posterior standard deviation" begin
        input = BayesianBetaBinomialInput(
            prior_alpha=1.0, prior_beta=1.0,
            observed_events=50, total_observations=100,
        )
        result = analyze_beta_binomial(input)

        @test result.posterior_std > 0.0
        @test result.posterior_std < 0.5  # bounded for a Beta distribution
    end

    @testset "1000 posterior samples generated" begin
        input = BayesianBetaBinomialInput(
            observed_events=10, total_observations=50,
        )
        result = analyze_beta_binomial(input)

        @test length(result.posterior_samples) == 1000
        @test all(0.0 .<= result.posterior_samples .<= 1.0)
    end

    @testset "strong prior dominates small sample" begin
        # Strong prior at 0.5 with small data
        input = BayesianBetaBinomialInput(
            prior_alpha=100.0, prior_beta=100.0,
            observed_events=1, total_observations=2,
        )
        result = analyze_beta_binomial(input)

        # Posterior mean should still be close to 0.5 (prior dominates)
        @test result.posterior_mean ≈ 0.5 atol=0.02
    end

    @testset "large sample overwhelms prior" begin
        input = BayesianBetaBinomialInput(
            prior_alpha=1.0, prior_beta=1.0,
            observed_events=900, total_observations=1000,
        )
        result = analyze_beta_binomial(input)

        # Posterior should be close to observed rate 0.9
        @test result.posterior_mean ≈ 0.9 atol=0.01
    end

    @testset "zero events" begin
        input = BayesianBetaBinomialInput(
            prior_alpha=1.0, prior_beta=1.0,
            observed_events=0, total_observations=100,
        )
        result = analyze_beta_binomial(input)

        @test result.posterior_alpha ≈ 1.0
        @test result.posterior_beta ≈ 101.0
        @test result.posterior_mean < 0.02
    end
end
