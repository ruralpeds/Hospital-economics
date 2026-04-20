# ============================================================================
# TESTS: MODULE 5 - VALUE-BASED CARE CONTRACTS & QUALITY METRICS
# ============================================================================
# Comprehensive tests for contract types, quality metrics, and financial analysis

using Test
using Dates
using HospitalFinanceToolbox

# ============================================================================
# VALUE-BASED CONTRACT TESTS
# ============================================================================

@testset "PayerContract Types" begin
    # Fee-for-Service
    ffs = FeeForServiceContract()
    @test isa(ffs, PayerContract)
    @test ffs.base_rate_per_case > 0
    @test ffs.inflation_rate > 0

    # Capitation
    cap = CapitationContract()
    @test isa(cap, PayerContract)
    @test cap.monthly_capitation_per_member > 0
    @test 0.0 < cap.risk_adjuster <= 2.0

    # Bundled Payment
    bundle = BundledPaymentContract()
    @test isa(bundle, PayerContract)
    @test bundle.bundle_price > 0
    @test bundle.episode_window_days > 0

    # Shared Savings
    acosavings = SharedSavingsContract()
    @test isa(acosavings, PayerContract)
    @test acosavings.baseline_cost > 0
    @test 0.0 < acosavings.shared_savings_rate < 1.0

    # Quality-Based
    quality = QualityBasedPaymentContract()
    @test isa(quality, PayerContract)
    @test quality.base_payment > 0
    @test !isempty(quality.quality_metrics)
end

@testset "Contract Naming" begin
    ffs = FeeForServiceContract(name="Test FFS")
    @test contract_type_name(ffs) == "Fee-for-Service"

    cap = CapitationContract()
    @test contract_type_name(cap) == "Capitation (PMPM)"

    bundle = BundledPaymentContract()
    @test contract_type_name(bundle) == "Bundled Payment"

    acosavings = SharedSavingsContract()
    @test contract_type_name(acosavings) == "Shared Savings (ACO)"

    quality = QualityBasedPaymentContract()
    @test contract_type_name(quality) == "Quality-Based Payment"
end

@testset "Contract Revenue Calculation" begin
    ffs = FeeForServiceContract(base_rate_per_case=15000.0, annual_volume=1000)
    revenue_ffs = get_annual_revenue(ffs, 1000, 12000.0)
    @test revenue_ffs == 15000.0 * 1000

    cap = CapitationContract(
        monthly_capitation_per_member=800.0,
        expected_members=5000,
        risk_adjuster=1.0
    )
    revenue_cap = get_annual_revenue(cap, 5000, 12000.0)
    @test revenue_cap == 800.0 * 1.0 * 5000 * 12

    bundle = BundledPaymentContract(bundle_price=18000.0, annual_volume=500)
    revenue_bundle = get_annual_revenue(bundle, 500, 12000.0)
    @test revenue_bundle == 18000.0 * 500
end

# ============================================================================
# QUALITY METRICS TESTS
# ============================================================================

@testset "QualityMetrics Structure" begin
    metrics = QualityMetrics(
        patient_satisfaction_score = 0.82,
        mortality_rate = 0.025,
        readmission_30day_rate = 0.12,
        complication_rate = 0.06,
        n_patients = 500
    )

    @test 0.0 <= metrics.patient_satisfaction_score <= 1.0
    @test 0.0 <= metrics.mortality_rate <= 1.0
    @test 0.0 <= metrics.readmission_30day_rate <= 1.0
    @test 0.0 <= metrics.complication_rate <= 1.0
    @test metrics.n_patients == 500
end

@testset "Quality Rating" begin
    # Excellent quality
    excellent = QualityMetrics(
        patient_satisfaction_score = 0.92,
        mortality_rate = 0.012,
        readmission_30day_rate = 0.08,
        complication_rate = 0.03
    )
    @test get_quality_rating(excellent) == "Excellent"

    # Good quality
    good = QualityMetrics(
        patient_satisfaction_score = 0.80,
        mortality_rate = 0.025,
        readmission_30day_rate = 0.12,
        complication_rate = 0.05
    )
    @test get_quality_rating(good) == "Good"

    # Poor quality
    poor = QualityMetrics(
        patient_satisfaction_score = 0.60,
        mortality_rate = 0.06,
        readmission_30day_rate = 0.25,
        complication_rate = 0.15
    )
    @test get_quality_rating(poor) == "Poor"
end

@testset "Quality Adjustment Calculation" begin
    actual = QualityMetrics(
        mortality_rate = 0.02,
        readmission_30day_rate = 0.10,
        patient_satisfaction_score = 0.85,
        complication_rate = 0.05
    )

    target = QualityMetrics(
        mortality_rate = 0.02,
        readmission_30day_rate = 0.12,
        patient_satisfaction_score = 0.80,
        complication_rate = 0.05
    )

    adjustors = Dict(
        "mortality" => -0.02,
        "readmission" => -0.01,
        "satisfaction" => 0.03,
        "complication" => -0.02
    )

    adjustment = calculate_quality_adjustment(actual, target, adjustors)

    # Readmission below target (savings) = bonus
    # Satisfaction above target = bonus
    @test adjustment > 0
end

@testset "Compare Metrics" begin
    metrics1 = QualityMetrics(
        mortality_rate = 0.015,
        readmission_30day_rate = 0.10,
        patient_satisfaction_score = 0.88,
        cost_per_case = 12000.0
    )

    metrics2 = QualityMetrics(
        mortality_rate = 0.025,
        readmission_30day_rate = 0.15,
        patient_satisfaction_score = 0.80,
        cost_per_case = 14000.0
    )

    differences = compare_metrics(metrics1, metrics2)

    # metrics1 should be better on mortality, readmission, satisfaction
    @test differences["mortality"] > 0  # Lower mortality in metrics1
    @test differences["readmission"] > 0  # Lower readmission in metrics1
    @test differences["satisfaction"] > 0  # Higher satisfaction in metrics1
    @test differences["cost"] > 0  # Lower cost in metrics1
end

# ============================================================================
# FINANCIAL IMPACT TESTS
# ============================================================================

@testset "AnnualContractFinancials Structure" begin
    annual = AnnualContractFinancials(
        year = 2026,
        hospital_revenue = 1_200_000.0,
        hospital_costs = 960_000.0,
        hospital_margin = 240_000.0,
        cases = 100
    )

    @test annual.year == 2026
    @test annual.hospital_margin == annual.hospital_revenue - annual.hospital_costs
    @test annual.cases == 100
end

@testset "ThreeYearContractAnalysis Structure" begin
    year1 = AnnualContractFinancials(year=2026, hospital_margin=200_000.0, cases=100)
    year2 = AnnualContractFinancials(year=2027, hospital_margin=220_000.0, cases=102)
    year3 = AnnualContractFinancials(year=2028, hospital_margin=240_000.0, cases=104)

    analysis = ThreeYearContractAnalysis(
        contract_name = "Test Contract",
        contract_type = "Fee-for-Service",
        year1 = year1,
        year2 = year2,
        year3 = year3,
        total_hospital_margin = 660_000.0,
        total_payer_savings = 50_000.0,
        roi_for_hospital = 0.50,
        recommendation = "Favorable"
    )

    @test analysis.contract_name == "Test Contract"
    @test analysis.total_hospital_margin == 660_000.0
    @test analysis.recommendation == "Favorable"
end

# ============================================================================
# BUDGET IMPACT PROJECTION TESTS
# ============================================================================

@testset "Project FeeForService Contract" begin
    ffs = FeeForServiceContract(
        name = "FFS Test",
        base_rate_per_case = 12000.0,
        annual_volume = 1000
    )

    cohort = PatientCohort("Test Cohort")
    quality = QualityMetrics()

    analysis = project_contract_financials(ffs, cohort, quality, 1000)

    @test analysis.contract_name == "FFS Test"
    @test analysis.contract_type == "Fee-for-Service"
    @test analysis.year1.cases == 1000
    @test analysis.total_hospital_margin >= 0  # FFS should have positive margin
    @test !isempty(analysis.recommendation)
end

@testset "Project Capitation Contract" begin
    cap = CapitationContract(
        name = "Capitation Test",
        monthly_capitation_per_member = 800.0,
        expected_members = 5000
    )

    cohort = PatientCohort("Test Cohort")
    quality = QualityMetrics()

    analysis = project_contract_financials(cap, cohort, quality, 5000)

    @test analysis.contract_type == "Capitation (PMPM)"
    @test analysis.year1.cases == 5000  # Members as cases
    @test analysis.total_hospital_margin >= 0
end

@testset "Project Bundled Payment Contract" begin
    bundle = BundledPaymentContract(
        name = "Bundle Test",
        bundle_price = 18000.0,
        episode_window_days = 90,
        annual_volume = 500
    )

    cohort = PatientCohort("Test Cohort")
    quality = QualityMetrics()

    analysis = project_contract_financials(bundle, cohort, quality, 500)

    @test analysis.contract_type == "Bundled Payment"
    @test analysis.year1.cases == 500
end

@testset "Compare Multiple Contracts" begin
    ffs = FeeForServiceContract(base_rate_per_case = 12000.0)
    cap = CapitationContract(monthly_capitation_per_member = 800.0, expected_members = 5000)
    bundle = BundledPaymentContract(bundle_price = 18000.0)

    contracts = [ffs, cap, bundle]
    cohort = PatientCohort("Test Cohort")
    quality = QualityMetrics()

    analyses = compare_contracts(contracts, cohort, quality, 1000)

    @test length(analyses) == 3
    @test all(isa(a, ThreeYearContractAnalysis) for a in analyses)
    @test analyses[1].contract_type == "Fee-for-Service"
    @test analyses[2].contract_type == "Capitation (PMPM)"
    @test analyses[3].contract_type == "Bundled Payment"
end

# ============================================================================
# RISK ADJUSTMENT & QUALITY PENALTY TESTS
# ============================================================================

@testset "Risk Adjustment" begin
    base_payment = 12000.0

    # No risk adjustment
    factors_baseline = Dict("age" => 1.0, "comorbidity_count" => 0.0)
    adjusted_baseline = apply_risk_adjustment(base_payment, factors_baseline)
    @test adjusted_baseline == base_payment

    # Higher risk
    factors_high = Dict(
        "age" => 1.2,
        "comorbidity_count" => 3.0,
        "prior_admission" => 1.0
    )
    adjusted_high = apply_risk_adjustment(base_payment, factors_high)
    @test adjusted_high > base_payment

    # Lower risk
    factors_low = Dict("age" => 0.9, "comorbidity_count" => 0.0)
    adjusted_low = apply_risk_adjustment(base_payment, factors_low)
    @test adjusted_low < base_payment

    # Bounded to [0.5x, 1.5x]
    @test 0.5 * base_payment <= adjusted_baseline <= 1.5 * base_payment
    @test 0.5 * base_payment <= adjusted_high <= 1.5 * base_payment
    @test 0.5 * base_payment <= adjusted_low <= 1.5 * base_payment
end

@testset "Quality Penalty" begin
    good_metrics = QualityMetrics(
        mortality_rate = 0.015,
        readmission_30day_rate = 0.08,
        complication_rate = 0.03,
        patient_satisfaction_score = 0.88
    )

    poor_metrics = QualityMetrics(
        mortality_rate = 0.06,
        readmission_30day_rate = 0.25,
        complication_rate = 0.15,
        patient_satisfaction_score = 0.60
    )

    contract = FeeForServiceContract()

    penalty_good = calculate_quality_penalty(good_metrics, contract)
    penalty_poor = calculate_quality_penalty(poor_metrics, contract)

    # Poor performance should have more penalty (or less bonus)
    @test penalty_poor <= penalty_good

    # Bounded to [-0.30, 0.0]
    @test -0.30 <= penalty_good <= 0.0
    @test -0.30 <= penalty_poor <= 0.0
end

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

@testset "End-to-End Contract Analysis" begin
    # Create contracts
    ffs = FeeForServiceContract(name="FFS Baseline", base_rate_per_case=12000.0)
    bundle = BundledPaymentContract(name="Bundled 90-day", bundle_price=18000.0)

    # Create cohort and quality baseline
    cohort = PatientCohort("Medicare MI Cohort")
    quality = QualityMetrics(
        patient_satisfaction_score = 0.80,
        mortality_rate = 0.025,
        readmission_30day_rate = 0.12,
        complication_rate = 0.06
    )

    # Project financials for both contracts
    ffs_analysis = project_contract_financials(ffs, cohort, quality, 500)
    bundle_analysis = project_contract_financials(bundle, cohort, quality, 500)

    # Both should have valid 3-year analysis
    @test ffs_analysis.total_hospital_margin > 0
    @test bundle_analysis.total_hospital_margin > 0

    # Compare contracts
    analyses = [ffs_analysis, bundle_analysis]
    @test length(analyses) == 2
    @test all(a.contract_type in ["Fee-for-Service", "Bundled Payment"] for a in analyses)
end

println("\n✓ All Module 5 (Value-Based Contracts) tests passed!")
