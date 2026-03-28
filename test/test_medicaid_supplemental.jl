using Test

include(joinpath(@__DIR__, "..", "src", "finance", "medicaid_supplemental.jl"))

@testset "Medicaid Supplemental Payments" begin
    @testset "struct construction" begin
        p = MedicaidSupplementalParams(
            medicaid_costs=2_000_000.0, medicaid_payments=1_200_000.0,
            uncompensated_care_costs=500_000.0, gross_patient_revenue=10_000_000.0,
            total_operating_expenses=8_000_000.0)
        @test p.provider_class == :private
        @test p.state_has_expansion == true
        @test p.provider_tax_rate == 0.0
    end

    @testset "calculate_medicaid_supplemental — private provider" begin
        p = MedicaidSupplementalParams(
            medicaid_costs=2_000_000.0, medicaid_payments=1_200_000.0,
            uncompensated_care_costs=500_000.0, gross_patient_revenue=10_000_000.0,
            total_operating_expenses=8_000_000.0, provider_class=:private)
        r = calculate_medicaid_supplemental(p)

        # DSH limit = (2M + 500K) - 1.2M = 1.3M
        @test r.dsh_limit == 1_300_000.0
        # DSH payment = 1.3M * 0.40 = 520_000
        @test r.dsh_payment == 520_000.0
        # SDP: private + expansion => 8% of medicaid_costs = 160_000
        @test r.sdp_payment == 2_000_000.0 * 0.08
        @test r.total_supplemental == r.dsh_payment + r.upl_payment + r.sdp_payment
        @test r.provider_tax_cost == 0.0
    end

    @testset "calculate_medicaid_supplemental — state_owned" begin
        p = MedicaidSupplementalParams(
            medicaid_costs=3_000_000.0, medicaid_payments=2_000_000.0,
            uncompensated_care_costs=800_000.0, gross_patient_revenue=15_000_000.0,
            total_operating_expenses=12_000_000.0, provider_class=:state_owned)
        r = calculate_medicaid_supplemental(p)

        # DSH: (3M + 800K) - 2M = 1.8M; * 0.70 = 1_260_000
        @test r.dsh_payment == 1_260_000.0
        # SDP: state_owned + expansion => 5% = 150_000
        @test r.sdp_payment == 3_000_000.0 * 0.05
    end

    @testset "calculate_medicaid_supplemental — non_state_govt with tax" begin
        p = MedicaidSupplementalParams(
            medicaid_costs=1_500_000.0, medicaid_payments=900_000.0,
            uncompensated_care_costs=300_000.0, gross_patient_revenue=8_000_000.0,
            total_operating_expenses=6_000_000.0, provider_class=:non_state_govt,
            provider_tax_rate=0.06)
        r = calculate_medicaid_supplemental(p)

        # DSH: (1.5M + 300K) - 900K = 900K; * 0.55 = 495_000
        @test r.dsh_payment == 495_000.0
        @test r.provider_tax_cost == 8_000_000.0 * 0.06
    end

    @testset "medicaid_reform_scenarios" begin
        p = MedicaidSupplementalParams(
            medicaid_costs=2_000_000.0, medicaid_payments=1_200_000.0,
            uncompensated_care_costs=500_000.0, gross_patient_revenue=10_000_000.0,
            total_operating_expenses=8_000_000.0, provider_class=:private,
            state_has_expansion=true)
        scenarios = medicaid_reform_scenarios(p)

        @test length(scenarios) == 3
        @test scenarios[1].scenario == :current_law
        @test scenarios[2].scenario == :moderate_reform
        @test scenarios[3].scenario == :significant_reform
        # Moderate: SDP halved
        @test scenarios[2].sdp == scenarios[1].sdp * 0.50
        # Significant: no SDP
        @test scenarios[3].sdp == 0.0
        # Total supplemental decreases across reform scenarios
        @test scenarios[1].total_supplemental >= scenarios[2].total_supplemental
    end

    @testset "edge cases" begin
        @test_throws ErrorException calculate_medicaid_supplemental(
            MedicaidSupplementalParams(medicaid_costs=-1.0, medicaid_payments=0.0,
                uncompensated_care_costs=0.0, gross_patient_revenue=0.0,
                total_operating_expenses=0.0))
        @test_throws ErrorException calculate_medicaid_supplemental(
            MedicaidSupplementalParams(medicaid_costs=100.0, medicaid_payments=50.0,
                uncompensated_care_costs=0.0, gross_patient_revenue=1000.0,
                total_operating_expenses=800.0, provider_class=:invalid))
        # Zero uncompensated care
        p = MedicaidSupplementalParams(
            medicaid_costs=500_000.0, medicaid_payments=400_000.0,
            uncompensated_care_costs=0.0, gross_patient_revenue=2_000_000.0,
            total_operating_expenses=1_500_000.0)
        r = calculate_medicaid_supplemental(p)
        @test r.dsh_limit == 100_000.0
        @test r.net_medicaid_shortfall >= 0.0
    end
end
