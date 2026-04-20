# test/test_policy_analysis_reporting.jl
# Tests for PolicyAnalysisReporting module

using Test
using Statistics
using Random

Random.seed!(42)

include("../src/visualization/PolicyAnalysisReporting.jl")
using .PolicyAnalysisReporting

@testset "PolicyAnalysisReporting Tests" begin

    # ==================== CEAC Curves ====================
    @testset "CEAC Curves" begin
        scenario_names = ["Scenario A", "Scenario B", "Scenario C"]
        # 3 scenarios x 100 simulations (as Matrix with rows=scenarios, cols=simulations)
        qaly_gains = vcat((randn(100) .+ 1.0)', (randn(100) .+ 1.2)', (randn(100) .+ 0.9)')
        costs = vcat((randn(100) .* 5000 .+ 50000)', (randn(100) .* 5000 .+ 45000)', (randn(100) .* 5000 .+ 55000)')
        wtp_range = Vector(25000.0:25000.0:150000.0)

        ceac = plot_ceac_curves(scenario_names, qaly_gains, costs, wtp_range, num_simulations=100)

        @test ceac.scenario_names == scenario_names
        @test ceac.wtp_thresholds == wtp_range
        @test size(ceac.probabilities) == (3, length(wtp_range))
        @test all(0.0 .<= ceac.probabilities .<= 1.0)
        @test all(sum(ceac.probabilities, dims=1) .≈ 1.0)  # Probs sum to 1 at each WTP
    end

    @testset "CEAC Curve Structure" begin
        scenario_names = ["A", "B"]
        qaly_gains = vcat((randn(50) .+ 1.0)', (randn(50) .+ 1.1)')
        costs = vcat((randn(50) .* 5000 .+ 50000)', (randn(50) .* 5000 .+ 45000)')
        wtp = Vector(50000.0:10000.0:100000.0)

        ceac = plot_ceac_curves(scenario_names, qaly_gains, costs, wtp)

        @test haskey(ceac.metadata, "description")
        @test ceac.metadata["description"] == "Cost-Effectiveness Acceptability Curve"
        @test ceac.metadata["num_scenarios"] == 2
        @test ceac.metadata["num_wtp_thresholds"] == length(wtp)
    end

    # ==================== Net Benefit Curves ====================
    @testset "Net Benefit Curves" begin
        scenario_names = ["Standard", "Enhanced"]
        qaly_gains = vcat((randn(50) .+ 0.95)', (randn(50) .+ 1.05)')
        costs = vcat((randn(50) .* 4000 .+ 50000)', (randn(50) .* 5000 .+ 52000)')
        wtp = Vector(25000.0:25000.0:100000.0)

        nb = plot_net_benefit_curves(scenario_names, qaly_gains, costs, wtp)

        @test nb.scenario_names == scenario_names
        @test nb.wtp_thresholds == wtp
        @test size(nb.net_benefits) == (2, length(wtp))
        @test size(nb.incremental_net_benefits) == (2, length(wtp))
    end

    @testset "Net Benefit Increasing with WTP" begin
        scenario_names = ["Treatment"]
        qaly_gains = ones(1, 100)  # Constant QALY (1 scenario x 100 simulations)
        costs = fill(40000.0, 1, 100)
        wtp = Vector(10000.0:10000.0:100000.0)

        nb = plot_net_benefit_curves(scenario_names, qaly_gains, costs, wtp)

        # Net benefit should increase with WTP (linear in WTP)
        for i in 1:length(wtp)-1
            @test nb.net_benefits[1, i+1] > nb.net_benefits[1, i]
        end
    end

    # ==================== Budget Impact ====================
    @testset "Budget Impact Model" begin
        scenario_names = ["Policy A", "Policy B"]
        annual_impacts = Float64[
            100000 200000 300000;
            50000 150000 250000
        ]
        years = [1, 2, 3]
        affected_patients = [10000, 12000]

        bi = plot_budget_impact(scenario_names, annual_impacts, years, affected_patients)

        @test bi.scenario_names == scenario_names
        @test bi.years == years
        @test bi.affected_patients == affected_patients
        @test size(bi.annual_impacts) == (2, 3)
        @test size(bi.cumulative_impacts) == (2, 3)
    end

    @testset "Budget Impact Cumulative Calculation" begin
        scenario_names = ["Policy"]
        annual = Float64[100 200 300]
        years = [1, 2, 3]

        bi = plot_budget_impact(scenario_names, annual, years)

        # Cumulative should be [100, 300, 600]
        @test bi.cumulative_impacts[1, 1] ≈ 100
        @test bi.cumulative_impacts[1, 2] ≈ 300
        @test bi.cumulative_impacts[1, 3] ≈ 600
    end

    @testset "Budget Impact with Empty Patients" begin
        scenario_names = ["Policy"]
        annual = Float64[50000 100000]
        years = [1, 2]

        bi = plot_budget_impact(scenario_names, annual, years)

        @test isempty(bi.affected_patients)
        @test bi.cumulative_impacts[1, 2] ≈ 150000
    end

    # ==================== Equity Analysis ====================
    @testset "Equity Analysis" begin
        demographic_data = Dict(
            "White" => (health_outcome=0.90, financial_outcome=50000),
            "Black" => (health_outcome=0.80, financial_outcome=55000),
            "Hispanic" => (health_outcome=0.85, financial_outcome=52000)
        )

        ea = plot_equity_analysis("Test Policy", demographic_data)

        @test ea.scenario_name == "Test Policy"
        @test length(ea.demographic_groups) == 3
        @test haskey(ea.health_outcomes, "White")
        @test haskey(ea.financial_outcomes, "Black")
        @test haskey(ea.disparities, "Hispanic")
    end

    @testset "Equity Analysis Disparity Calculation" begin
        demographic_data = Dict(
            "Group A" => (health_outcome=1.0, financial_outcome=100000.0),
            "Group B" => (health_outcome=0.9, financial_outcome=110000.0)
        )

        ea = plot_equity_analysis("Policy", demographic_data)

        # Group A is baseline (1.0 health, 100000 cost)
        # Group B has -10% health, +10% cost (less equitable)
        @test ea.health_outcomes["Group A"] == 1.0
        @test ea.financial_outcomes["Group B"] == 110000.0
        @test haskey(ea.disparities, "Group B")
    end

    # ==================== Sensitivity Analysis (Tornado) ====================
    @testset "Tornado Plot Sensitivity" begin
        param_names = ["Discount Rate", "Cost per QALY", "QALY Gain"]
        sensitivities = Dict(
            "Discount Rate" => (45000.0, 55000.0),
            "Cost per QALY" => (40000.0, 60000.0),
            "QALY Gain" => (35000.0, 65000.0)
        )

        sa = plot_sensitivity_tornado(
            "Scenario 1",
            param_names,
            50000.0,
            sensitivities,
            "Cost-Effectiveness Ratio"
        )

        @test sa.scenario_name == "Scenario 1"
        @test sa.base_case_value == 50000.0
        @test sa.output_metric == "Cost-Effectiveness Ratio"
        @test length(sa.low_values) == 3
        @test length(sa.high_values) == 3
    end

    @testset "Tornado Plot Range" begin
        params = ["Param1", "Param2"]
        base = 100.0
        sensitivities = Dict(
            "Param1" => (80.0, 120.0),
            "Param2" => (90.0, 110.0)
        )

        sa = plot_sensitivity_tornado("Test", params, base, sensitivities)

        # Low values should be ≤ base, high values should be ≥ base
        for i in 1:length(params)
            @test sa.low_values[i] <= sa.base_case_value
            @test sa.high_values[i] >= sa.base_case_value
        end
    end

    @testset "Tornado Plot Missing Parameters" begin
        params = ["A", "B", "C"]
        base = 50.0
        sensitivities = Dict("A" => (40.0, 60.0))  # Only A provided

        sa = plot_sensitivity_tornado("Test", params, base, sensitivities)

        @test sa.low_values[1] == 40.0
        @test sa.high_values[1] == 60.0
        @test sa.low_values[2] == base  # B and C use base value
        @test sa.high_values[3] == base
    end

    # ==================== Network Visualization ====================
    @testset "Hospital Network Visualization" begin
        hospital_ids = ["H1", "H2", "H3"]
        locations = [(38.9, -84.5), (38.8, -84.4), (39.0, -84.6)]
        margins = [0.05, 0.08, 0.03]
        quality = [0.85, 0.90, 0.78]
        referral_vols = Float64[
            0 100 50;
            100 0 75;
            50 75 0
        ]
        beds = [250, 300, 150]

        nv = plot_hospital_network(hospital_ids, locations, margins, quality, referral_vols, beds)

        @test nv.hospital_ids == hospital_ids
        @test length(nv.hospital_locations) == 3
        @test length(nv.hospital_margins) == 3
        @test length(nv.hospital_quality) == 3
        @test nv.hospital_beds == beds
        @test size(nv.referral_volumes) == (3, 3)
    end

    @testset "Hospital Network Default Beds" begin
        hospital_ids = ["H1", "H2"]
        locations = [(38.9, -84.5), (38.8, -84.4)]
        margins = [0.05, 0.08]
        quality = [0.85, 0.90]
        referral_vols = Float64[0 100; 100 0]

        nv = plot_hospital_network(hospital_ids, locations, margins, quality, referral_vols)

        @test length(nv.hospital_beds) == 2
        @test all(nv.hospital_beds .== 250)  # Default beds
    end

    @testset "Hospital Network Metadata" begin
        hospital_ids = ["H1"]
        locations = [(38.9, -84.5)]
        margins = [0.05]
        quality = [0.85]
        referral_vols = Float64[0;;]

        nv = plot_hospital_network(hospital_ids, locations, margins, quality, referral_vols)

        @test haskey(nv.metadata, "description")
        @test nv.metadata["node_color_metric"] == "Profit Margin"
        @test nv.metadata["edge_width_metric"] == "Referral Volume"
    end

    # ==================== Summary Tables ====================
    @testset "Summary Table Generation" begin
        scenarios = ["Scenario 1", "Scenario 2"]
        outcomes = Dict(
            "total_cost" => 1_000_000,
            "total_qalys" => 5000,
            "icer" => 200,
            "hospital_margin" => 0.05,
            "quality_score" => 0.85,
            "access_metric" => 0.92
        )

        summary = generate_summary_table(scenarios, outcomes)

        @test size(summary, 1) == 2
        @test size(summary, 2) == 7  # Scenario + 6 outcome columns
        @test summary.TotalCost[1] == 1_000_000
        @test summary.CostPerQALY[1] == 200
    end

    @testset "Summary Table Missing Outcomes" begin
        scenarios = ["Test"]
        outcomes = Dict("total_cost" => 50000)  # Sparse outcomes

        summary = generate_summary_table(scenarios, outcomes)

        @test summary.TotalCost[1] == 50000
        @test summary.TotalQALYs[1] == 0.0  # Missing outcomes default to 0
        @test summary.CostPerQALY[1] == 0.0
    end

    # ==================== Data Exports ====================
    @testset "Data Export to CSV" begin
        using DataFrames

        results = Dict(
            :dataframe => DataFrame(
                Scenario = ["A", "B"],
                Cost = [100, 200],
                QALY = [1.0, 1.2]
            )
        )

        tempfile = "test_export.csv"
        output_path = export_analysis_data(results, tempfile, format="csv")

        @test isfile(output_path)
        @test endswith(output_path, ".csv")

        # Clean up
        rm(tempfile, force=true)
    end

    # ==================== Integration Tests ====================
    @testset "Multi-Scenario Analysis Integration" begin
        # Create data for 3 policy scenarios
        scenario_names = ["Status Quo", "Minor Reform", "Major Reform"]
        n_scenarios = 3
        n_sims = 100

        qaly_gains = vcat((randn(n_sims) .+ 0.95)', (randn(n_sims) .+ 1.05)', (randn(n_sims) .+ 1.15)')
        costs = vcat(
            (randn(n_sims) .* 4000 .+ 50000)',
            (randn(n_sims) .* 4000 .+ 48000)',
            (randn(n_sims) .* 5000 .+ 46000)'
        )
        wtp = Vector(25000.0:25000.0:150000.0)

        # Generate all visualizations
        ceac = plot_ceac_curves(scenario_names, qaly_gains, costs, wtp)
        nb = plot_net_benefit_curves(scenario_names, qaly_gains, costs, wtp)

        annual_impacts = Float64[
            -100000 -200000 -250000;
            -50000 -75000 -100000;
            50000 100000 150000
        ]
        bi = plot_budget_impact(scenario_names, annual_impacts, [1, 2, 3])

        @test ceac.scenario_names == scenario_names
        @test nb.scenario_names == scenario_names
        @test bi.scenario_names == scenario_names
        @test length(ceac.wtp_thresholds) == length(wtp)
    end

end
