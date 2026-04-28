using Test
using Statistics
using FinanceEngine

@testset "A-14: Physician Compensation & Productivity Benchmarking" begin
    # Test 1: Physician profile creation
    @test begin
        doc = PhysicianProfile("DOC001", "Internal Medicine", 15, 6000.0, 900_000.0, 85.0, 90.0)
        doc.physician_id == "DOC001" &&
        doc.annual_wrvu == 6000.0 &&
        doc.patient_satisfaction_score == 85.0
    end

    # Test 2: Compensation calculation with base and wRVU
    @test begin
        profile = PhysicianProfile("DOC001", "IM", 10, 5000.0, 750_000.0, 80.0, 85.0)
        model = CompensationModel(200_000.0, 35.0, 5.0, 5500, 10.0)
        comp = calculate_physician_compensation(profile, model, 5500.0)
        comp isa PhysicianCompensation &&
        comp.wrvu_based_payment == 5000.0 * 35.0 &&
        comp.total_compensation > comp.base_salary
    end

    # Test 3: Quality incentive eligibility
    @test begin
        high_quality = PhysicianProfile("DOC001", "IM", 10, 5000.0, 750_000.0, 85.0, 85.0)
        low_quality = PhysicianProfile("DOC002", "IM", 10, 5000.0, 750_000.0, 60.0, 70.0)
        model = CompensationModel(200_000.0, 35.0, 10.0, 5500, 10.0)
        comp_high = calculate_physician_compensation(high_quality, model, 5500.0)
        comp_low = calculate_physician_compensation(low_quality, model, 5500.0)
        comp_high.total_compensation > comp_low.total_compensation
    end

    # Test 4: Productivity benchmarking
    @test begin
        profile = PhysicianProfile("DOC001", "Surgery", 12, 8000.0, 1_200_000.0, 88.0, 92.0)
        model = CompensationModel(250_000.0, 40.0, 8.0, 7000, 12.0)
        comp = calculate_physician_compensation(profile, model, 7000.0)
        comp.productivity_vs_benchmark_pct ≈ (8000.0 / 7000.0) * 100.0 atol=1.0
    end

    # Test 5: Specialty benchmarking
    @test begin
        physicians = [
            PhysicianProfile("DOC001", "IM", 10, 5000.0, 750_000.0, 82.0, 85.0),
            PhysicianProfile("DOC002", "IM", 12, 5500.0, 825_000.0, 88.0, 90.0),
            PhysicianProfile("DOC003", "IM", 8, 4500.0, 675_000.0, 80.0, 80.0)
        ]
        bench = benchmark_specialty(physicians, "IM")
        bench isa SpecialtyBenchmarks &&
        bench.specialty == "IM" &&
        bench.median_wrvu == 5000.0
    end

    # Test 6: Outlier identification
    @test begin
        physicians = [
            PhysicianProfile("DOC001", "Surgery", 10, 8000.0, 1_200_000.0, 85.0, 90.0),
            PhysicianProfile("DOC002", "Surgery", 12, 7500.0, 1_125_000.0, 88.0, 92.0),
            PhysicianProfile("DOC003", "Surgery", 8, 4000.0, 600_000.0, 75.0, 75.0)
        ]
        outliers = identify_outliers(physicians, "Surgery", productivity_threshold=0.7)
        # DOC003 at 4000 < 7500 * 0.7 = 5250, so should be outlier
        "DOC003" in outliers
    end

    # Test 7: High performer bonus eligibility
    @test begin
        high_performer = PhysicianProfile("DOC001", "IM", 15, 9000.0, 1_350_000.0, 92.0, 95.0)
        normal = PhysicianProfile("DOC002", "IM", 12, 5500.0, 825_000.0, 85.0, 88.0)
        model = CompensationModel(200_000.0, 35.0, 5.0, 5500, 15.0)
        comp_high = calculate_physician_compensation(high_performer, model, 5500.0)
        comp_normal = calculate_physician_compensation(normal, model, 5500.0)
        # High performer should have higher total comp due to bonus
        comp_high.total_compensation > comp_normal.total_compensation
    end

    # Test 8: Empty specialty returns zero benchmarks
    @test begin
        physicians = [
            PhysicianProfile("DOC001", "IM", 10, 5000.0, 750_000.0, 82.0, 85.0)
        ]
        bench = benchmark_specialty(physicians, "Surgery")
        bench.median_wrvu == 0.0 &&
        bench.median_compensation == 0.0
    end

    # Test 9: Compensation components are additive
    @test begin
        profile = PhysicianProfile("DOC001", "IM", 10, 5000.0, 750_000.0, 85.0, 85.0)
        model = CompensationModel(200_000.0, 35.0, 5.0, 5500, 10.0)
        comp = calculate_physician_compensation(profile, model, 5500.0)
        comp.total_compensation == comp.base_salary + comp.wrvu_based_payment + comp.quality_incentive
    end

    # Test 10: Quality metric is average of satisfaction and quality
    @test begin
        profile = PhysicianProfile("DOC001", "IM", 10, 5000.0, 750_000.0, 80.0, 90.0)
        model = CompensationModel(200_000.0, 35.0, 5.0, 5500, 10.0)
        comp = calculate_physician_compensation(profile, model, 5500.0)
        expected_quality = (80.0 + 90.0) / 2.0
        comp.quality_vs_benchmark_pct ≈ expected_quality atol=0.1
    end
end
