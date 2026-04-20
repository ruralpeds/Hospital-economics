# ============================================================================
# INTEGRATION TESTS: MODULES 4-5
# ============================================================================
# End-to-end workflow: Patient Cohort → Hospital Simulation → Contract Analysis
# Demonstrates how Module 4 (Patient Flow) integrates with Module 5 (Value-Based Care)

using Test
using Dates
using HospitalFinanceToolbox

# ============================================================================
# TEST FIXTURES
# ============================================================================

"""Create a representative patient cohort for testing"""
function create_test_cohort()::PatientCohort
    PatientCohort(
        cohort_id = "TEST_COHORT_001",
        name = "Medicare MI Cohort",
        patient_ids = ["PT_$(lpad(i, 4, '0'))" for i in 1:100],
        encounter_ids = ["ENC_$(lpad(i, 4, '0'))" for i in 1:100],
        size = 100,
        mean_age = 68.5,
        payer_distribution = Dict("Medicare" => 1.0),
        diagnosis_distribution = Dict("I21" => 100),  # ICD-10 for MI
        mean_cost = 45000.0,
        median_cost = 42000.0,
        cost_std = 15000.0,
        mean_los = 4.5,
        inclusion_criteria = [],
        exclusion_criteria = [],
        creation_date = now(),
        last_updated = now()
    )
end

"""Create quality metrics baseline"""
function create_baseline_quality()::QualityMetrics
    QualityMetrics(
        patient_satisfaction_score = 0.80,
        care_coordination = 0.80,
        communication = 0.80,
        mortality_rate = 0.025,
        readmission_30day_rate = 0.12,
        hospital_acquired_infection_rate = 0.01,
        complication_rate = 0.06,
        cost_per_case = 45000.0,
        los_variance = 0.15,
        evidence_based_care_percentage = 0.85,
        n_patients = 100,
        evaluation_period = "2026 Q1"
    )
end

# ============================================================================
# INTEGRATION TEST SUITE
# ============================================================================

@testset "Integration: Modules 4-5 End-to-End Workflows" begin

    # =======================================================================
    @testset "Workflow 1: Cohort → Simulation → Quality Metrics" begin
        # Step 1: Create patient cohort
        cohort = create_test_cohort()
        @test cohort.size == 100
        @test cohort.mean_age == 68.5

        # Step 2: Get clinical pathway for MI (DRG 246)
        mi_pathway = route_to_pathway("246")
        @test mi_pathway.pathway_id == "DRG_246_Acute_MI"
        @test mi_pathway.expected_mortality_rate > 0
        @test mi_pathway.expected_readmission_30day > 0

        # Step 3: Simulate cohort through hospital
        sim_result = simulate_cohort(
            cohort,
            PatientEncounter[];
            num_simulation_runs = 1
        )

        # Verify simulation results
        @test sim_result.n_patients == 100
        @test sim_result.mean_cost > 0
        @test sim_result.mean_los > 0
        @test 0.0 <= sim_result.mortality_rate <= 1.0
        @test 0.0 <= sim_result.readmission_30day_rate <= 1.0
        @test 0.0 <= sim_result.mean_quality_score <= 1.0

        # Step 4: Convert simulation results to quality metrics
        quality_metrics = calculate_quality_metrics(sim_result)

        @test quality_metrics.n_patients == 100
        @test quality_metrics.mortality_rate == sim_result.mortality_rate
        @test quality_metrics.readmission_30day_rate == sim_result.readmission_30day_rate
        @test quality_metrics.cost_per_case == sim_result.mean_cost
        @test !isempty(quality_metrics.evaluation_period)
    end

    # =======================================================================
    @testset "Workflow 2: Quality Metrics → Financial Impact Projection" begin
        # Setup: Cohort and quality metrics
        cohort = create_test_cohort()
        baseline_quality = create_baseline_quality()

        # Simulate to get realistic metrics
        sim_result = simulate_cohort(cohort, PatientEncounter[]; num_simulation_runs = 1)
        quality_metrics = calculate_quality_metrics(sim_result)

        # Test with Fee-for-Service contract
        ffs_contract = FeeForServiceContract(
            name = "Medicare FFS - Baseline",
            base_rate_per_case = 45000.0,
            annual_volume = 100,
            inflation_rate = 0.025
        )

        ffs_analysis = project_contract_financials(
            ffs_contract,
            cohort,
            quality_metrics,
            100
        )

        # Verify 3-year projection structure
        @test ffs_analysis.contract_name == "Medicare FFS - Baseline"
        @test ffs_analysis.contract_type == "Fee-for-Service"
        @test ffs_analysis.year1.year == 2026
        @test ffs_analysis.year2.year == 2027
        @test ffs_analysis.year3.year == 2028

        # Verify financial logic
        @test ffs_analysis.year1.cases > 0
        @test ffs_analysis.year1.hospital_revenue > 0
        @test ffs_analysis.year1.hospital_margin >= 0  # FFS should be profitable

        # Verify cumulative metrics
        @test ffs_analysis.total_hospital_margin >= 0
        @test ffs_analysis.roi_for_hospital >= 0
        @test !isempty(ffs_analysis.recommendation)
    end

    # =======================================================================
    @testset "Workflow 3: Compare Multiple Contract Types" begin
        cohort = create_test_cohort()
        baseline_quality = create_baseline_quality()
        sim_result = simulate_cohort(cohort, PatientEncounter[]; num_simulation_runs = 1)
        quality_metrics = calculate_quality_metrics(sim_result)

        # Define 5 contract types
        contracts = [
            FeeForServiceContract(
                name = "FFS Baseline",
                base_rate_per_case = 45000.0,
                annual_volume = 100,
                inflation_rate = 0.025
            ),
            CapitationContract(
                name = "Capitation",
                monthly_capitation_per_member = 3500.0,
                expected_members = 100,
                risk_adjuster = 1.0
            ),
            BundledPaymentContract(
                name = "90-Day Bundle",
                bundle_price = 45000.0,
                episode_window_days = 90,
                annual_volume = 100
            ),
            SharedSavingsContract(
                name = "ACO Shared Savings",
                baseline_cost = 45000.0,
                shared_savings_rate = 0.5,
                quality_threshold = 0.75,
                minimum_savings_threshold = 1000.0,
                risk_sharing = true,
                shared_loss_rate = 0.25
            ),
            QualityBasedPaymentContract(
                name = "Quality-Based",
                base_payment = 45000.0,
                quality_metrics = Dict(
                    "mortality" => 0.025,
                    "readmission" => 0.12,
                    "satisfaction" => 0.80
                ),
                quality_adjustors = Dict(
                    "mortality" => -0.02,
                    "readmission" => -0.01,
                    "satisfaction" => 0.03
                ),
                bonus_potential = 0.10,
                penalty_potential = 0.10
            )
        ]

        # Compare all contracts
        analyses = compare_contracts(contracts, cohort, quality_metrics, 100)

        # Verify results structure
        @test length(analyses) == 5
        @test all(isa(a, ThreeYearContractAnalysis) for a in analyses)

        # Verify each contract type
        @test analyses[1].contract_type == "Fee-for-Service"
        @test analyses[2].contract_type == "Capitation (PMPM)"
        @test analyses[3].contract_type == "Bundled Payment"
        @test analyses[4].contract_type == "Shared Savings (ACO)"
        @test analyses[5].contract_type == "Quality-Based Payment"

        # All should have valid 3-year margins
        for analysis in analyses
            @test analysis.total_hospital_margin >= 0 || analysis.recommendation == "Unfavorable"
            @test analysis.roi_for_hospital >= 0
        end

        # Print formatted comparison
        comparison_text = format_contract_analysis(analyses[1])
        @test contains(comparison_text, "FFS Baseline")
        @test contains(comparison_text, "Fee-for-Service")
    end

    # =======================================================================
    @testset "Workflow 4: Quality Adjustment Impact on Payments" begin
        baseline_quality = create_baseline_quality()

        # Scenario 1: Excellent quality performance
        excellent = QualityMetrics(
            patient_satisfaction_score = 0.92,
            care_coordination = 0.90,
            communication = 0.90,
            mortality_rate = 0.012,
            readmission_30day_rate = 0.08,
            hospital_acquired_infection_rate = 0.005,
            complication_rate = 0.03,
            cost_per_case = 42000.0,
            los_variance = 0.05,
            evidence_based_care_percentage = 0.95,
            n_patients = 100,
            evaluation_period = "2026 Q1"
        )

        # Scenario 2: Poor quality performance
        poor = QualityMetrics(
            patient_satisfaction_score = 0.60,
            care_coordination = 0.55,
            communication = 0.55,
            mortality_rate = 0.06,
            readmission_30day_rate = 0.25,
            hospital_acquired_infection_rate = 0.03,
            complication_rate = 0.15,
            cost_per_case = 52000.0,
            los_variance = 0.45,
            evidence_based_care_percentage = 0.70,
            n_patients = 100,
            evaluation_period = "2026 Q1"
        )

        # Define quality-based contract with adjustors
        contract = QualityBasedPaymentContract(
            name = "Quality Scorecard",
            base_payment = 45000.0,
            quality_metrics = Dict(
                "mortality" => 0.02,
                "readmission" => 0.12,
                "satisfaction" => 0.80,
                "complication" => 0.05
            ),
            quality_adjustors = Dict(
                "mortality" => -0.02,
                "readmission" => -0.01,
                "satisfaction" => 0.03,
                "complication" => -0.02
            ),
            bonus_potential = 0.15,
            penalty_potential = 0.30
        )

        # Calculate adjustments
        excellent_adjustment = calculate_quality_adjustment(excellent, baseline_quality, contract.quality_adjustors)
        poor_adjustment = calculate_quality_adjustment(poor, baseline_quality, contract.quality_adjustors)

        # Excellent should get bonus, poor should get penalty
        @test excellent_adjustment > 0  # Bonus
        @test poor_adjustment < 0  # Penalty
        @test excellent_adjustment > poor_adjustment

        # Apply to base payment
        excellent_payment = contract.base_payment * (1.0 + excellent_adjustment)
        poor_payment = contract.base_payment * (1.0 + poor_adjustment)

        @test excellent_payment > contract.base_payment
        @test poor_payment < contract.base_payment
        @test excellent_payment > poor_payment

        # Calculate quality rating
        excellent_rating = get_quality_rating(excellent)
        poor_rating = get_quality_rating(poor)

        @test excellent_rating == "Excellent"
        @test poor_rating == "Poor"
    end

    # =======================================================================
    @testset "Workflow 5: Risk Adjustment by Patient Complexity" begin
        # Patient with baseline risk
        baseline_factors = Dict(
            "age" => 1.0,
            "comorbidity_count" => 0.0
        )
        adjusted_baseline = apply_risk_adjustment(45000.0, baseline_factors)
        @test adjusted_baseline == 45000.0

        # High-risk patient: age >75, multiple comorbidities, prior admission
        high_risk_factors = Dict(
            "age" => 1.2,
            "comorbidity_count" => 3.0,
            "prior_admission" => 1.0,
            "chronic_illness" => 0.8
        )
        adjusted_high = apply_risk_adjustment(45000.0, high_risk_factors)
        @test adjusted_high > 45000.0
        @test adjusted_high <= 45000.0 * 1.5  # Bounded

        # Low-risk patient: young, no comorbidities
        low_risk_factors = Dict(
            "age" => 0.9,
            "comorbidity_count" => 0.0
        )
        adjusted_low = apply_risk_adjustment(45000.0, low_risk_factors)
        @test adjusted_low < 45000.0
        @test adjusted_low >= 45000.0 * 0.5  # Bounded

        # Verify ordering
        @test adjusted_low < 45000.0
        @test 45000.0 < adjusted_high
    end

    # =======================================================================
    @testset "Workflow 6: Quality Penalties for Poor Outcomes" begin
        good_metrics = QualityMetrics(
            patient_satisfaction_score = 0.88,
            care_coordination = 0.85,
            communication = 0.85,
            mortality_rate = 0.015,
            readmission_30day_rate = 0.08,
            hospital_acquired_infection_rate = 0.008,
            complication_rate = 0.03,
            cost_per_case = 43000.0,
            los_variance = 0.05,
            evidence_based_care_percentage = 0.90,
            n_patients = 100,
            evaluation_period = "2026 Q1"
        )

        poor_metrics = QualityMetrics(
            patient_satisfaction_score = 0.60,
            care_coordination = 0.55,
            communication = 0.55,
            mortality_rate = 0.06,
            readmission_30day_rate = 0.25,
            hospital_acquired_infection_rate = 0.03,
            complication_rate = 0.15,
            cost_per_case = 52000.0,
            los_variance = 0.45,
            evidence_based_care_percentage = 0.70,
            n_patients = 100,
            evaluation_period = "2026 Q1"
        )

        ffs_contract = FeeForServiceContract(
            name = "Test",
            base_rate_per_case = 45000.0,
            annual_volume = 100,
            inflation_rate = 0.025
        )

        # Calculate penalties
        penalty_good = calculate_quality_penalty(good_metrics, ffs_contract)
        penalty_poor = calculate_quality_penalty(poor_metrics, ffs_contract)

        # Poor performance should have more penalty (less bonus)
        @test penalty_poor <= penalty_good

        # Penalties should be bounded
        @test -0.30 <= penalty_good <= 0.0
        @test -0.30 <= penalty_poor <= 0.0

        # Apply to revenue
        good_revenue = 45000.0 * 100 * (1.0 + penalty_good)
        poor_revenue = 45000.0 * 100 * (1.0 + penalty_poor)

        @test good_revenue > poor_revenue
    end

    # =======================================================================
    @testset "Workflow 7: Hospital vs Payer Perspective Analysis" begin
        cohort = create_test_cohort()
        baseline_quality = create_baseline_quality()
        sim_result = simulate_cohort(cohort, PatientEncounter[]; num_simulation_runs = 1)
        quality_metrics = calculate_quality_metrics(sim_result)

        # FFS (neutral for both): Hospital gets revenue, payer pays
        ffs_contract = FeeForServiceContract(
            name = "Medicare FFS",
            base_rate_per_case = 45000.0,
            annual_volume = 100,
            inflation_rate = 0.025
        )
        ffs_analysis = project_contract_financials(ffs_contract, cohort, quality_metrics, 100)

        # Hospital perspective: FFS provides stable margin
        @test ffs_analysis.year1.hospital_revenue == 45000.0 * 100
        @test ffs_analysis.year1.hospital_margin > 0

        # Payer perspective: FFS baseline (no savings)
        @test ffs_analysis.year1.payer_savings_vs_benchmark == 0

        # Bundled Payment: Hospital controls costs for better margin
        bundle_contract = BundledPaymentContract(
            name = "90-Day Bundle",
            bundle_price = 45000.0,
            episode_window_days = 90,
            annual_volume = 100
        )
        bundle_analysis = project_contract_financials(bundle_contract, cohort, quality_metrics, 100)

        # Hospital incentive: Keep costs below bundle price
        @test bundle_analysis.year1.hospital_revenue == bundle_contract.bundle_price * 100

        # Capitation: Hospital manages total per-member cost
        cap_contract = CapitationContract(
            name = "PMPM Capitation",
            monthly_capitation_per_member = 3500.0,
            expected_members = 100,
            risk_adjuster = 1.0
        )
        cap_analysis = project_contract_financials(cap_contract, cohort, quality_metrics, 100)

        # Annual revenue = 3500 PMPM * 12 months * members
        expected_cap_revenue = 3500.0 * 12 * 100
        @test cap_analysis.year1.hospital_revenue == expected_cap_revenue
    end

    # =======================================================================
    @testset "Workflow 8: Multi-Year Impact with Volume Growth" begin
        cohort = create_test_cohort()
        baseline_quality = create_baseline_quality()
        sim_result = simulate_cohort(cohort, PatientEncounter[]; num_simulation_runs = 1)
        quality_metrics = calculate_quality_metrics(sim_result)

        ffs_contract = FeeForServiceContract(
            name = "Growth Scenario",
            base_rate_per_case = 45000.0,
            annual_volume = 100,
            inflation_rate = 0.025
        )

        analysis = project_contract_financials(ffs_contract, cohort, quality_metrics, 100)

        # Verify volume growth (2% annually)
        y1_volume = analysis.year1.cases
        y2_volume = analysis.year2.cases
        y3_volume = analysis.year3.cases

        @test y2_volume ≈ y1_volume * 1.02 atol = 2  # Allow rounding
        @test y3_volume ≈ y1_volume * 1.04 atol = 2

        # Verify rate inflation
        y1_rate = analysis.year1.hospital_revenue / analysis.year1.cases
        y2_rate = analysis.year2.hospital_revenue / analysis.year2.cases
        y3_rate = analysis.year3.hospital_revenue / analysis.year3.cases

        @test y2_rate ≈ y1_rate * 1.025 atol = 100
        @test y3_rate ≈ y1_rate * 1.025^2 atol = 100

        # Cumulative effects over 3 years
        @test analysis.total_hospital_margin > analysis.year1.hospital_margin * 2
        @test analysis.roi_for_hospital > 0
    end

    # =======================================================================
    @testset "Workflow 9: Shared Savings with Quality Gate" begin
        cohort = create_test_cohort()
        baseline_quality = create_baseline_quality()
        sim_result = simulate_cohort(cohort, PatientEncounter[]; num_simulation_runs = 1)

        # Create high-quality metrics (passes quality threshold)
        high_quality = QualityMetrics(
            patient_satisfaction_score = 0.88,
            care_coordination = 0.85,
            communication = 0.85,
            mortality_rate = 0.015,
            readmission_30day_rate = 0.08,
            hospital_acquired_infection_rate = 0.008,
            complication_rate = 0.03,
            cost_per_case = 40000.0,  # Below baseline
            los_variance = 0.05,
            evidence_based_care_percentage = 0.90,
            n_patients = 100,
            evaluation_period = "2026 Q1"
        )

        shared_savings_contract = SharedSavingsContract(
            name = "ACO Model",
            baseline_cost = 45000.0,
            shared_savings_rate = 0.5,
            quality_threshold = 0.80,  # Satisfaction must be >= 80%
            minimum_savings_threshold = 1000.0,
            risk_sharing = true,
            shared_loss_rate = 0.25
        )

        analysis = project_contract_financials(shared_savings_contract, cohort, high_quality, 100)

        # Hospital should benefit from shared savings
        # Savings = baseline - actual = 45000 - 40000 = 5000 per case
        # With 100 cases, total savings = 500K, shared @ 50% = 250K to hospital
        @test analysis.year1.hospital_revenue > analysis.year1.hospital_margin  # Savings on top
    end

    # =======================================================================
    @testset "Workflow 10: Formatting and Reporting" begin
        cohort = create_test_cohort()
        baseline_quality = create_baseline_quality()
        sim_result = simulate_cohort(cohort, PatientEncounter[]; num_simulation_runs = 1)
        quality_metrics = calculate_quality_metrics(sim_result)

        # Project contract
        contract = FeeForServiceContract(
            name = "Reporting Test",
            base_rate_per_case = 45000.0,
            annual_volume = 100,
            inflation_rate = 0.025
        )
        analysis = project_contract_financials(contract, cohort, quality_metrics, 100)

        # Format analysis
        analysis_text = format_contract_analysis(analysis)
        @test contains(analysis_text, "Reporting Test")
        @test contains(analysis_text, "Fee-for-Service")
        @test contains(analysis_text, "HOSPITAL PERSPECTIVE")
        @test contains(analysis_text, "PAYER PERSPECTIVE")
        @test contains(analysis_text, "Return on Investment")

        # Format quality metrics
        metrics_text = format_quality_metrics(quality_metrics)
        @test contains(metrics_text, "QUALITY METRICS")
        @test contains(metrics_text, "CLINICAL OUTCOMES")
        @test contains(metrics_text, "PATIENT SATISFACTION")
        @test contains(metrics_text, "%")

        # Format annual financials
        annual_text = format_annual_financials(analysis.year1)
        @test contains(annual_text, "2026")
        @test contains(annual_text, "Hospital Margin")
        @test contains(annual_text, "Payer")
    end
end

println("\n✓ All Module 4-5 Integration Tests Passed!")
