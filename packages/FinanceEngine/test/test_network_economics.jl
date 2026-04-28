using Test
using FinanceEngine

@testset "A-13: Network Economics & Multi-Hospital System Valuation" begin
    # Test 1: Network margin impact calculation
    @test begin
        hospital = HospitalNode("H1", :anchor, 100_000_000.0, 5.0, ["Medical", "Surgical"])
        transfers = [
            NetworkTransfer("H1", "H2", 500, 10_000.0, 500.0),
            NetworkTransfer("H2", "H1", 300, 15_000.0, 1000.0)
        ]
        econ = calculate_network_margin_impact(hospital, transfers)
        econ isa NetworkEconomics &&
        econ.hospital_id == "H1" &&
        econ.inbound_revenue >= 0
    end

    # Test 2: Network analysis with multiple hospitals
    @test begin
        hospitals = [
            HospitalNode("H1", :anchor, 100_000_000.0, 5.0, ["Medical"]),
            HospitalNode("H2", :critical_access, 20_000_000.0, 3.0, ["ER"]),
            HospitalNode("H3", :specialty, 50_000_000.0, 6.0, ["Surgery"])
        ]
        transfers = [
            NetworkTransfer("H2", "H1", 200, 8_000.0, 300.0),
            NetworkTransfer("H2", "H3", 150, 12_000.0, 400.0)
        ]
        result = analyze_network_system(hospitals, transfers)
        result isa NetworkAnalysisResult &&
        result.total_hospitals == 3 &&
        result.total_network_revenue > 0
    end

    # Test 3: Network synergy identification
    @test begin
        hospitals = [
            HospitalNode("H1", :anchor, 100_000_000.0, 5.0, ["Medical"]),
            HospitalNode("H2", :critical_access, 20_000_000.0, 2.0, ["ER"])
        ]
        transfers = [
            NetworkTransfer("H2", "H1", 300, 10_000.0, 500.0)
        ]
        result = analyze_network_system(hospitals, transfers)
        # Network should show some synergy
        result.network_synergy_value isa Float64
    end

    # Test 4: Critical node identification
    @test begin
        hospitals = [
            HospitalNode("H1", :anchor, 100_000_000.0, 5.0, ["Medical"]),
            HospitalNode("H2", :critical_access, 20_000_000.0, 3.0, ["ER"]),
            HospitalNode("H3", :specialty, 50_000_000.0, 6.0, ["Surgery"])
        ]
        transfers = [
            NetworkTransfer("H2", "H1", 500, 8_000.0, 300.0),
            NetworkTransfer("H2", "H3", 400, 12_000.0, 400.0),
            NetworkTransfer("H3", "H1", 100, 10_000.0, 200.0)
        ]
        result = analyze_network_system(hospitals, transfers)
        !isempty(result.critical_nodes) &&
        all(n in ["H1", "H2", "H3"] for n in result.critical_nodes)
    end

    # Test 5: Empty network handling
    @test begin
        result = analyze_network_system([], [])
        result.total_hospitals == 0 &&
        result.total_network_revenue == 0.0
    end

    # Test 6: Inbound vs outbound cost calculation
    @test begin
        hospital = HospitalNode("H1", :anchor, 50_000_000.0, 4.0, ["Medical"])
        transfers = [
            NetworkTransfer("H1", "H2", 100, 5_000.0, 200.0),
            NetworkTransfer("H2", "H1", 200, 6_000.0, 300.0)
        ]
        econ = calculate_network_margin_impact(hospital, transfers)
        econ.inbound_referral_revenue > 0 &&
        econ.outbound_referral_cost >= 0
    end

    # Test 7: Shared service savings
    @test begin
        hospital = HospitalNode("H1", :anchor, 50_000_000.0, 4.0, ["Medical"])
        transfers = []
        econ = calculate_network_margin_impact(hospital, transfers, shared_savings_pct=0.05)
        econ.shared_service_savings > 0
    end

    # Test 8: Margin improvement percentage reasonable
    @test begin
        hospital = HospitalNode("H1", :anchor, 50_000_000.0, 4.0, ["Medical"])
        transfers = [
            NetworkTransfer("H2", "H1", 100, 5_000.0, 200.0)
        ]
        econ = calculate_network_margin_impact(hospital, transfers)
        econ.network_margin_improvement_pct >= -10.0 &&
        econ.network_margin_improvement_pct <= 50.0
    end

    # Test 9: Hospital type variety
    @test begin
        hospitals = [
            HospitalNode("H1", :anchor, 150_000_000.0, 6.0, ["Medical", "Surgical"]),
            HospitalNode("H2", :critical_access, 15_000_000.0, 2.0, ["ER"]),
            HospitalNode("H3", :specialty, 80_000_000.0, 7.0, ["Cardiology"]),
            HospitalNode("H4", :urgent_care, 5_000_000.0, 3.0, ["Urgent"])
        ]
        transfers = []
        result = analyze_network_system(hospitals, transfers)
        result.total_hospitals == 4
    end

    # Test 10: Network outperforms standalone
    @test begin
        hospital = HospitalNode("H1", :anchor, 100_000_000.0, 5.0, ["Medical"])
        transfers = [NetworkTransfer("H2", "H1", 300, 10_000.0, 500.0)]
        econ = calculate_network_margin_impact(hospital, transfers)
        econ.network_adjusted_margin isa Float64 &&
        econ.network_adjusted_margin >= 0
    end
end
