@testset "Validation — FMEA" begin
    @test calculate_rpn(3, 4, 2) == 24
    @test assess_risk_acceptability(30) == :acceptable
    @test assess_risk_acceptability(60) == :needs_mitigation
    @test assess_risk_acceptability(100) == :unacceptable

    modes = [
        FailureMode(id="FM-001", description="Calc error", component="Finance",
                   severity=4, probability=3, detectability=2,
                   residual_severity=2, residual_probability=2),
        FailureMode(id="FM-002", description="Data loss", component="Storage",
                   severity=5, probability=2, detectability=3,
                   residual_severity=3, residual_probability=1),
    ]
    report = generate_fmea_report(modes)
    @test report.max_rpn == maximum(m.rpn for m in modes)
    @test report.risk_reduction_pct >= 0.0

    sorted = prioritize_failure_modes(modes)
    @test sorted[1].rpn >= sorted[end].rpn
end

@testset "Validation — Requirement Traceability" begin
    matrix = create_traceability_matrix()
    req = Requirement(id="FR-001", description="Calculate VBP", category=:functional,
                     status=:implemented, source="CMS", affected_modules=["quality"],
                     verification_method=:unit_test, verified_by="", verified_date=nothing)
    add_requirement!(matrix, req)
    @test haskey(matrix.requirements, "FR-001")

    mark_verified!(matrix, "FR-001", :unit_test, "tester1")
    report = coverage_report(matrix)
    @test report.total == 1
    @test report.verified == 1
end

@testset "Validation — Parity Testing" begin
    test = ParityTest(name="square", implementation_a=x->x^2,
                     implementation_b=x->x*x, input_generator=()->rand(),
                     tolerance=1e-12)
    result = run_parity_test(test; n_samples=50)
    @test result.passed == true
    @test result.max_deviation < 1e-12
end

@testset "Scientific Modeling — PK ODE" begin
    params = PKParams(dose=500.0, bioavailability=0.9, ka=1.0,
                     cl_central=10.0, cl_peripheral=5.0,
                     v_central=50.0, v_peripheral=100.0)
    result = simulate_pk(params; t_end=24.0, dt=0.1)
    @test length(result.times) > 0
    @test result.peak_concentration > 0.0
    @test result.time_to_peak > 0.0
    @test result.terminal_half_life > 0.0
end

@testset "Scientific Modeling — Bayesian Beta-Binomial" begin
    input = BayesianBetaBinomialInput(
        prior_alpha=1.0, prior_beta=1.0,
        observed_events=7, total_observations=100)
    result = analyze_beta_binomial(input)
    @test result.posterior_alpha ≈ 8.0
    @test result.posterior_beta ≈ 94.0
    @test result.posterior_mean ≈ 8.0 / 102.0 atol=0.001
    @test result.credible_interval_95[1] < result.posterior_mean
    @test result.credible_interval_95[2] > result.posterior_mean
    @test length(result.posterior_samples) == 1000
end
