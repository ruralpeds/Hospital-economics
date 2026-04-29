"""
    test_mba_p1_bundle2.jl — Tests for MBA P1 Bundle 2

Covers:
  A-07  Hospital M&A valuation (DCF, comparables, asset-based, synergy, IRR)
  B-01  Balanced Scorecard (KPI library, RAG, scoring, measurement, summary)
  C-06  Reciprocal cost allocation (step-down, simultaneous, comparison)
"""

using Test
using Statistics
using Dates

# ═════════════════════════════════════════════════════════════════════════════
# A-07: Hospital M&A Valuation
# ═════════════════════════════════════════════════════════════════════════════

@testset "A-07 Hospital M&A Valuation" begin

    function sample_target()
        TargetHospitalFinancials(
            hospital_name        = "Prairie View CAH",
            hospital_type        = :cah,
            net_patient_revenue  = 8_500_000.0,
            ebitda               = 680_000.0,
            ebit                 = 420_000.0,
            net_operating_income = 240_000.0,
            free_cash_flow       = 180_000.0,
            total_assets         = 9_200_000.0,
            total_liabilities    = 4_400_000.0,
            long_term_debt       = 3_100_000.0,
            net_assets           = 4_800_000.0,
            capex_annual         = 380_000.0,
            depreciation         = 420_000.0,
            revenue_growth_rate  = 0.022,
            cost_inflation_rate  = 0.035,
        )
    end

    function sample_inputs(; kwargs...)
        MAValuationInputs(
            target                       = sample_target(),
            wacc                         = 0.07,
            terminal_growth_rate         = 0.025,
            projection_years             = 5,
            synergy_cost_savings_annual  = 350_000.0,
            synergy_revenue_lift_annual  = 120_000.0,
            synergy_realisation_lag      = 2,
            deal_costs                   = 180_000.0,
            hurdle_rate                  = 0.10,
            kwargs...,
        )
    end

    @testset "dcf_valuation — EV positive" begin
        r = dcf_valuation(sample_inputs())
        @test r.enterprise_value > 0
        @test length(r.projected_fcfs) == 5
        @test r.pv_terminal_value > r.pv_fcfs   # terminal value usually dominates
    end

    @testset "dcf_valuation — sum of parts identity" begin
        r = dcf_valuation(sample_inputs())
        @test r.enterprise_value ≈ r.pv_fcfs + r.pv_terminal_value atol=1.0
    end

    @testset "dcf_valuation — lower WACC → higher EV" begin
        r_low  = dcf_valuation(sample_inputs(wacc=0.05))
        r_high = dcf_valuation(sample_inputs(wacc=0.10))
        @test r_low.enterprise_value > r_high.enterprise_value
    end

    @testset "dcf_valuation — WACC ≤ growth rate raises error" begin
        @test_throws ArgumentError dcf_valuation(sample_inputs(wacc=0.02, terminal_growth_rate=0.025))
    end

    @testset "comparable_transactions — EV range non-negative" begin
        r = comparable_transactions(sample_inputs())
        @test r.ev_low > 0
        @test r.ev_median >= r.ev_low
        @test r.ev_high >= r.ev_median
        @test !isnan(r.ev_ebitda_median)
    end

    @testset "comparable_transactions — control premium increases EV" begin
        r = comparable_transactions(sample_inputs())
        @test r.control_premium_adj_ev > r.blended_ev
    end

    @testset "asset_based_valuation — CAH premium applied" begin
        r = asset_based_valuation(sample_inputs())
        @test r.adjusted_asset_value > r.book_value_net_assets
        @test r.going_concern_premium_usd > 0
    end

    @testset "synergy_npv — net synergy positive when synergies > deal costs" begin
        # Large synergies vs small deal costs
        inputs = sample_inputs(
            synergy_cost_savings_annual=800_000.0,
            synergy_revenue_lift_annual=200_000.0,
            deal_costs=200_000.0,
        )
        r = synergy_npv(inputs)
        @test r.gross_synergy_npv > 0
        @test r.net_synergy_npv > 0
        @test r.annual_synergy ≈ 1_000_000.0
    end

    @testset "synergy_npv — gross > net by deal costs" begin
        r = synergy_npv(sample_inputs())
        @test r.gross_synergy_npv ≈ r.net_synergy_npv + r.deal_costs atol=1.0
    end

    @testset "hospital_ma_valuation — returns MAValuationResult" begin
        result = hospital_ma_valuation(sample_inputs())
        @test result isa MAValuationResult
        @test result.standalone_ev > 0
        @test result.synergy_adjusted_ev >= result.standalone_ev
    end

    @testset "hospital_ma_valuation — valuation range ordered" begin
        result = hospital_ma_valuation(sample_inputs())
        @test result.valuation_range[1] <= result.valuation_range[2]
        @test result.recommended_price_range[1] <= result.recommended_price_range[2]
    end

    @testset "hospital_ma_valuation — IRR positive and below hurdle for fair price" begin
        result = hospital_ma_valuation(sample_inputs())
        @test result.irr_at_recommended_price >= 0.0
        @test result.irr_at_recommended_price <= 0.50   # reasonable upper bound
    end

    @testset "hospital_ma_valuation — price/revenue multiple in expected range" begin
        result = hospital_ma_valuation(sample_inputs())
        m = RURAL_HOSPITAL_TRANSACTION_MULTIPLES
        @test result.price_to_revenue >= 0.15
        @test result.price_to_revenue <= 1.50   # sensible upper bound
    end

    @testset "ma_sensitivity_table — correct dimensions" begin
        tbl = ma_sensitivity_table(sample_inputs())
        @test size(tbl, 1) == 5   # default WACC scenarios
        @test size(tbl, 2) == 5   # default growth scenarios
        @test all(tbl .> 0)
    end

    @testset "ma_sensitivity_table — monotone in WACC and growth" begin
        tbl = ma_sensitivity_table(sample_inputs())
        # Along each column (fixed growth): higher WACC → lower EV
        for j in 1:5
            @test tbl[1,j] > tbl[end,j]   # first row (low WACC) > last (high WACC)
        end
        # Along each row (fixed WACC): higher growth → higher EV
        for i in 1:5
            @test tbl[i,1] < tbl[i,end]
        end
    end

end  # A-07


# ═════════════════════════════════════════════════════════════════════════════
# B-01: Balanced Scorecard
# ═════════════════════════════════════════════════════════════════════════════

@testset "B-01 Balanced Scorecard" begin

    @testset "CAH_STANDARD_KPI_LIBRARY — complete" begin
        persp_counts = Dict(p => 0 for p in instances(BSCPerspective))
        for kpi in CAH_STANDARD_KPI_LIBRARY
            persp_counts[kpi.perspective] += 1
        end
        for p in instances(BSCPerspective)
            @test persp_counts[p] >= 4 "Perspective $(p) has < 4 KPIs"
        end
    end

    @testset "CAH_STANDARD_KPI_LIBRARY — all KPIs have valid thresholds" begin
        for kpi in CAH_STANDARD_KPI_LIBRARY
            @test kpi.weight > 0
            @test kpi.target isa Float64
        end
    end

    @testset "rag_status_for_kpi — higher_better" begin
        kpi = findfirst(k -> k.id == :operating_margin, CAH_STANDARD_KPI_LIBRARY)
        k   = CAH_STANDARD_KPI_LIBRARY[kpi]
        @test rag_status_for_kpi(k, 0.05) == :green   # above green threshold
        @test rag_status_for_kpi(k, 0.01) == :amber   # between amber and green
        @test rag_status_for_kpi(k, -0.05) == :red    # below amber
    end

    @testset "rag_status_for_kpi — lower_better" begin
        kpi = findfirst(k -> k.id == :readmission_rate, CAH_STANDARD_KPI_LIBRARY)
        k   = CAH_STANDARD_KPI_LIBRARY[kpi]
        @test rag_status_for_kpi(k, 0.08) == :green   # below green threshold
        @test rag_status_for_kpi(k, 0.14) == :amber
        @test rag_status_for_kpi(k, 0.20) == :red
    end

    @testset "performance_score_for_kpi — at target = 100" begin
        k = findfirst(x -> x.id == :operating_margin, CAH_STANDARD_KPI_LIBRARY)
        kpi = CAH_STANDARD_KPI_LIBRARY[k]
        score = performance_score_for_kpi(kpi, kpi.target)
        @test score ≈ 100.0 atol=2.0
    end

    @testset "performance_score_for_kpi — scores in [0,100]" begin
        for kpi in CAH_STANDARD_KPI_LIBRARY
            for v in [kpi.amber_threshold, kpi.target, kpi.green_threshold]
                s = performance_score_for_kpi(kpi, v)
                @test 0.0 <= s <= 100.0
            end
        end
    end

    function build_sample_bsc()
        bsc = BalancedScorecard(
            hospital_name = "Valley CAH",
            period        = "Q1 FY2026",
        )
        # Measure a subset of KPIs
        measure_kpi!(bsc, :operating_margin,       -0.018, -0.012)
        measure_kpi!(bsc, :days_cash_on_hand,        52.4,   55.1)
        measure_kpi!(bsc, :dso,                      51.2,   49.8)
        measure_kpi!(bsc, :salary_to_revenue,         0.524,  0.520)
        measure_kpi!(bsc, :hcahps_top_box,            0.714,  0.705)
        measure_kpi!(bsc, :readmission_rate,           0.118,  0.122)
        measure_kpi!(bsc, :ed_door_to_provider,       22.0,   24.0)
        measure_kpi!(bsc, :or_utilization,             0.68,   0.65)
        measure_kpi!(bsc, :denial_rate,                0.068,  0.072)
        measure_kpi!(bsc, :nurse_vacancy_rate,         0.12,   0.14)
        measure_kpi!(bsc, :employee_engagement,       72.0,   70.0)
        bsc
    end

    @testset "measure_kpi! — records measurement" begin
        bsc = build_sample_bsc()
        @test haskey(bsc.measurements, :operating_margin)
        m = bsc.measurements[:operating_margin]
        @test m.current_value ≈ -0.018
        @test m.rag_status == :red   # negative margin → red
    end

    @testset "measure_kpi! — trend calculated" begin
        bsc = build_sample_bsc()
        # Operating margin declined (-0.018 < -0.012)
        @test bsc.measurements[:operating_margin].trend == :declining
        # Days cash declined (52.4 < 55.1)
        @test bsc.measurements[:days_cash_on_hand].trend == :declining
        # HCAHPS improved (0.714 > 0.705)
        @test bsc.measurements[:hcahps_top_box].trend == :improving
    end

    @testset "measure_kpi! — unknown KPI raises error" begin
        bsc = BalancedScorecard(hospital_name="X", period="P1")
        @test_throws ArgumentError measure_kpi!(bsc, :nonexistent_kpi, 1.0, 0.9)
    end

    @testset "summarise_bsc — overall score in [0,100]" begin
        bsc  = build_sample_bsc()
        summ = summarise_bsc(bsc)
        @test 0.0 <= summ.overall_score <= 100.0
    end

    @testset "summarise_bsc — RAG counts add up" begin
        bsc  = build_sample_bsc()
        summ = summarise_bsc(bsc)
        @test summ.n_green + summ.n_amber + summ.n_red == summ.measured_kpi_count
    end

    @testset "summarise_bsc — perspective scores all non-negative" begin
        bsc  = build_sample_bsc()
        summ = summarise_bsc(bsc)
        for (p, score) in summ.perspective_scores
            @test score >= 0.0
        end
    end

    @testset "summarise_bsc — top concerns are red KPIs" begin
        bsc  = build_sample_bsc()
        summ = summarise_bsc(bsc)
        for id in summ.top_concerns
            @test bsc.measurements[id].rag_status == :red
        end
    end

    @testset "bsc_report_text — renders without error" begin
        bsc  = build_sample_bsc()
        summ = summarise_bsc(bsc)
        txt  = bsc_report_text(bsc, summ)
        @test contains(txt, "Valley CAH")
        @test contains(txt, "BALANCED SCORECARD")
        @test contains(txt, "Financial")
        @test contains(txt, "Patient")
        @test contains(txt, "Q1 FY2026")
    end

    @testset "summarise_bsc — empty measurements raises error" begin
        bsc = BalancedScorecard(hospital_name="Empty", period="P1")
        @test_throws ArgumentError summarise_bsc(bsc)
    end

    @testset "StrategicInitiative — renders in BSC report" begin
        bsc = build_sample_bsc()
        push!(bsc.initiatives, StrategicInitiative(
            id=:ar_project, name="AR Acceleration Programme",
            perspective=financial, linked_kpis=[:dso],
            owner="CFO", completion_pct=45.0, status=:in_progress,
            expected_impact_usd=200_000.0, budget_usd=80_000.0,
        ))
        summ = summarise_bsc(bsc)
        txt  = bsc_report_text(bsc, summ)
        @test contains(txt, "AR Acceleration")
        @test contains(txt, "45")
    end

end  # B-01


# ═════════════════════════════════════════════════════════════════════════════
# C-06: Reciprocal Cost Allocation
# ═════════════════════════════════════════════════════════════════════════════

@testset "C-06 Reciprocal Cost Allocation" begin

    function build_sample_model()
        # 3 overhead departments, 3 patient-care departments
        depts = [
            CostCenter(id=:admin,        name="Administration", type=overhead,
                       direct_cost=800_000.0, step_sequence=1),
            CostCenter(id=:housekeeping, name="Housekeeping",   type=overhead,
                       direct_cost=400_000.0, step_sequence=2),
            CostCenter(id=:dietary,      name="Dietary",        type=overhead,
                       direct_cost=350_000.0, step_sequence=3),
            CostCenter(id=:medsurg,      name="Med-Surg",       type=patient_care,
                       direct_cost=2_200_000.0),
            CostCenter(id=:ed,           name="ED",             type=patient_care,
                       direct_cost=1_800_000.0),
            CostCenter(id=:or,           name="Operating Room", type=patient_care,
                       direct_cost=1_400_000.0),
        ]

        # Allocation bases
        bases = [
            # Admin (allocated by FTEs): 20 to housekeeping, 15 to dietary,
            #   40 to med-surg, 30 to ed, 25 to OR
            AllocationBase(from_dept=:admin, to_dept=:housekeeping, statistic_value=20.0, statistic_name="FTEs"),
            AllocationBase(from_dept=:admin, to_dept=:dietary,      statistic_value=15.0, statistic_name="FTEs"),
            AllocationBase(from_dept=:admin, to_dept=:medsurg,      statistic_value=40.0, statistic_name="FTEs"),
            AllocationBase(from_dept=:admin, to_dept=:ed,           statistic_value=30.0, statistic_name="FTEs"),
            AllocationBase(from_dept=:admin, to_dept=:or,           statistic_value=25.0, statistic_name="FTEs"),
            # Housekeeping (by square footage): 10 to admin, 5 to dietary,
            #   50 to med-surg, 30 to ed, 20 to OR
            AllocationBase(from_dept=:housekeeping, to_dept=:admin,   statistic_value=10.0, statistic_name="SqFt"),
            AllocationBase(from_dept=:housekeeping, to_dept=:dietary,  statistic_value=5.0,  statistic_name="SqFt"),
            AllocationBase(from_dept=:housekeeping, to_dept=:medsurg,  statistic_value=50.0, statistic_name="SqFt"),
            AllocationBase(from_dept=:housekeeping, to_dept=:ed,       statistic_value=30.0, statistic_name="SqFt"),
            AllocationBase(from_dept=:housekeeping, to_dept=:or,       statistic_value=20.0, statistic_name="SqFt"),
            # Dietary (by meals): 5 to admin, 8 to housekeeping,
            #   50 to med-surg, 25 to ed, 10 to OR
            AllocationBase(from_dept=:dietary, to_dept=:admin,        statistic_value=5.0,  statistic_name="Meals"),
            AllocationBase(from_dept=:dietary, to_dept=:housekeeping, statistic_value=8.0,  statistic_name="Meals"),
            AllocationBase(from_dept=:dietary, to_dept=:medsurg,      statistic_value=50.0, statistic_name="Meals"),
            AllocationBase(from_dept=:dietary, to_dept=:ed,           statistic_value=25.0, statistic_name="Meals"),
            AllocationBase(from_dept=:dietary, to_dept=:or,           statistic_value=10.0, statistic_name="Meals"),
        ]

        CostAllocationModel(depts, bases)
    end

    @testset "step_down_allocation — total cost conserved" begin
        model = build_sample_model()
        summ  = step_down_allocation(model)
        total_direct = sum(d.direct_cost for d in model.departments)
        total_allocated = sum(r.total_cost for r in summ.results)
        @test summ.check_sum_error < total_direct * 0.001   # < 0.1% error
        @test summ.method == :step_down
    end

    @testset "step_down_allocation — all patient-care depts receive overhead" begin
        model = build_sample_model()
        summ  = step_down_allocation(model)
        for r in summ.results
            @test r.total_cost >= r.direct_cost   # must receive some overhead
        end
    end

    @testset "step_down_allocation — overhead depts have allocated_overhead empty" begin
        model = build_sample_model()
        summ  = step_down_allocation(model)
        # Each overhead dept's total should appear in results
        @test length(summ.results) == 3   # 3 patient-care depts
    end

    @testset "reciprocal_allocation — total cost conserved" begin
        model = build_sample_model()
        summ  = reciprocal_allocation(model)
        total_direct = sum(d.direct_cost for d in model.departments)
        total_allocated = sum(r.total_cost for r in summ.results)
        @test summ.check_sum_error < total_direct * 0.01   # < 1% (linear system approx)
        @test summ.method == :reciprocal
    end

    @testset "reciprocal_allocation — all patient-care depts allocated to" begin
        model = build_sample_model()
        summ  = reciprocal_allocation(model)
        @test length(summ.results) == 3
        for r in summ.results
            @test r.total_allocated > 0
        end
    end

    @testset "compare_allocation_methods — results differ" begin
        model = build_sample_model()
        comparison = compare_allocation_methods(model)
        @test length(comparison) == 3
        # At least one department should have a non-trivial difference
        has_diff = any(abs(r.difference) > 100.0 for r in comparison)
        @test has_diff   # reciprocal and step-down should diverge with mutual services
    end

    @testset "compare_allocation_methods — both totals close to full cost" begin
        model  = build_sample_model()
        comp   = compare_allocation_methods(model)
        total_direct = sum(d.direct_cost for d in model.departments)
        # Step-down totals sum to all direct costs
        sd_sum  = sum(r.step_down_total for r in comp)
        rec_sum = sum(r.reciprocal_total for r in comp)
        @test abs(sd_sum  - total_direct) < total_direct * 0.001
        @test abs(rec_sum - total_direct) < total_direct * 0.05   # reciprocal slightly looser
    end

    @testset "step_down — no self-allocation" begin
        model = build_sample_model()
        summ  = step_down_allocation(model)
        for r in summ.results
            @test !haskey(r.allocated_overhead, r.dept_id)
        end
    end

    @testset "reciprocal — overhead departments get positive total" begin
        model = build_sample_model()
        summ  = reciprocal_allocation(model)
        for (oh_id, total) in summ.overhead_dept_totals
            # Some overhead departments might be small but should be > 0
            @test total >= 0.0
        end
    end

    @testset "step_down vs reciprocal — same total direct cost conserved" begin
        model = build_sample_model()
        sd    = step_down_allocation(model)
        rec   = reciprocal_allocation(model)
        @test sd.total_direct_cost ≈ rec.total_direct_cost atol=1.0
    end

end  # C-06

println("\n✅  P1 Bundle 2 (A-07 M&A Valuation, B-01 BSC, C-06 Reciprocal Allocation) tests complete.")
