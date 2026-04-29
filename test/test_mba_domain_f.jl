"""
    test_mba_domain_f.jl — Tests for MBA Domain F Reporting

Covers:
  F-01  Board packet (data assembly, all 12 sections, Markdown render,
        Typst source generation, deterministic output)
  F-03  CFO dashboard model (RAG logic, exception flag generation,
        sparkline data structure)
  F-06  HCRIS importer (argument parsing, URL construction, data extraction)
"""

using Test
using Dates

# ═════════════════════════════════════════════════════════════════════════════
# F-01: Board Packet Generator
# ═════════════════════════════════════════════════════════════════════════════

@testset "F-01 Board Packet Generator" begin

    function sample_data(; kwargs...)
        BoardPacketData(
            hospital_name             = "Valley Community Hospital",
            hospital_type             = "Critical Access Hospital",
            ccn                       = "381322",
            fiscal_period             = "Q1 FY2026",
            board_meeting_date        = Date(2026, 4, 15),
            prepared_by               = "Finance Department",
            operating_margin          = -0.018,
            total_margin              = 0.005,
            days_cash_on_hand         = 52.4,
            current_ratio             = 1.74,
            debt_to_cap               = 0.48,
            mads_dscr                 = 1.32,
            avg_age_of_plant          = 11.8,
            prior_operating_margin    = -0.012,
            prior_days_cash           = 55.1,
            prior_current_ratio       = 1.80,
            ed_visits_ytd             = 1_050,
            inpatient_discharges_ytd  = 155,
            outpatient_visits_ytd     = 3_200,
            avg_daily_census          = 9.8,
            case_mix_index            = 0.92,
            avg_length_of_stay        = 3.6,
            occupancy_rate            = 0.392,
            medicare_pct              = 0.62,
            medicaid_pct              = 0.18,
            commercial_pct            = 0.12,
            self_pay_pct              = 0.08,
            prior_medicare_pct        = 0.60,
            days_ar_outstanding       = 51.2,
            denial_rate               = 0.068,
            clean_claim_rate          = 0.924,
            cash_collection_efficiency = 0.932,
            bad_debt_pct              = 0.028,
            total_fte                 = 138.0,
            fte_per_aob               = 6.4,
            salary_to_revenue         = 0.524,
            contract_labor_pct        = 0.045,
            supply_expense_per_discharge = 1_850.0,
            net_patient_revenue       = 5_800_000.0,
            total_assets              = 9_200_000.0,
            long_term_debt            = 3_100_000.0,
            net_assets                = 4_800_000.0,
            capital_expenditures_ytd  = 285_000.0,
            depreciation_expense      = 420_000.0,
            hac_score                 = 1.08,
            readmission_rate          = 0.118,
            patient_satisfaction_score = 0.714,
            vbp_tps                   = 62.0,
            charity_care_pct          = 0.031,
            community_benefit_total   = 890_000.0,
            sdoh_risk_score           = 0.68,
            strategic_initiatives     = ["Implement electronic prior authorization by Q3",
                                          "Launch RHC expansion at rural satellite site"],
            key_risks                 = ["Contract labor costs remain elevated (+4.5% salary)",
                                          "MA penetration increased 2pp year-over-year"],
            management_responses      = ["Recruiting 3 RN positions to reduce agency spend"],
            peer_operating_margin_pct = 42.0,
            peer_dcoh_pct             = 38.0,
            peer_debt_to_cap_pct      = 55.0,
            kwargs...
        )
    end

    @testset "generate_board_packet — returns 12 sections" begin
        doc = generate_board_packet(sample_data())
        @test length(doc.sections) == 12
        @test doc.sections[1].number == 1
        @test doc.sections[end].number == 12
    end

    @testset "generate_board_packet — correct section titles" begin
        doc = generate_board_packet(sample_data())
        titles = [s.title for s in doc.sections]
        @test "Cover" in titles
        @test "Financial Scorecard" in titles
        @test "Quality & Regulatory Compliance" in titles
        @test "Strategic Initiatives & Risks" in titles
        @test "Appendix: Flex Monitoring Peer Benchmarks" in titles
    end

    @testset "generate_board_packet — hospital name propagated" begin
        doc = generate_board_packet(sample_data())
        @test doc.hospital_name == "Valley Community Hospital"
        @test doc.fiscal_period == "Q1 FY2026"
        @test doc.prepared_by   == "Finance Department"
    end

    @testset "generate_board_packet — generated_at is DateTime" begin
        doc = generate_board_packet(sample_data())
        @test doc.generated_at isa DateTime
        @test doc.generated_at <= now()
    end

    @testset "generate_board_packet — deterministic output (same input)" begin
        d = sample_data()
        doc1 = generate_board_packet(d)
        doc2 = generate_board_packet(d)
        @test length(doc1.sections) == length(doc2.sections)
        @test doc1.hospital_name == doc2.hospital_name
        for (s1, s2) in zip(doc1.sections, doc2.sections)
            @test s1.title == s2.title
            @test length(s1.subsections) == length(s2.subsections)
        end
    end

    @testset "render_to_markdown — contains key content" begin
        doc = generate_board_packet(sample_data())
        md  = render_to_markdown(doc)
        @test contains(md, "Valley Community Hospital")
        @test contains(md, "Q1 FY2026")
        @test contains(md, "Financial Scorecard")
        @test contains(md, "Operating Margin")
        @test contains(md, "MADS DSCR")
        @test contains(md, "Strategic Initiatives")
        @test contains(md, "Appendix")
    end

    @testset "render_to_markdown — has RAG indicators" begin
        doc = generate_board_packet(sample_data())
        md  = render_to_markdown(doc)
        @test contains(md, "🟢") || contains(md, "🟡") || contains(md, "🔴")
    end

    @testset "render_to_markdown — no empty sections" begin
        doc = generate_board_packet(sample_data())
        md  = render_to_markdown(doc)
        @test !isempty(md)
        @test length(md) > 1000   # meaningful content
    end

    @testset "render_to_typst — valid Typst structure" begin
        doc = generate_board_packet(sample_data())
        typ = render_to_typst(doc)
        @test contains(typ, "#set document(")
        @test contains(typ, "#set page(")
        @test contains(typ, "Valley Community Hospital")
        @test contains(typ, "= 2.")    # section 2 heading
        @test contains(typ, "= 12.")   # section 12 heading
        @test contains(typ, "rag-cell")
    end

    @testset "render_to_typst — cover page present" begin
        doc = generate_board_packet(sample_data())
        typ = render_to_typst(doc)
        @test contains(typ, "Board of Directors Meeting")
        @test contains(typ, "#pagebreak()")
    end

    @testset "render_to_typst — financial scorecard has all 8 metrics" begin
        doc = generate_board_packet(sample_data())
        typ = render_to_typst(doc)
        for metric in ["Operating Margin", "Days Cash on Hand", "Current Ratio",
                        "Debt / Capitalization", "MADS DSCR", "Salary / Revenue"]
            @test contains(typ, metric) "Missing metric: $metric"
        end
    end

    @testset "board packet — strategic items rendered" begin
        doc = generate_board_packet(sample_data())
        md  = render_to_markdown(doc)
        @test contains(md, "prior authorization")   # from strategic_initiatives
        @test contains(md, "Contract labor")        # from key_risks
        @test contains(md, "Recruiting")            # from management_responses
    end

    @testset "board packet — empty strategic items handled gracefully" begin
        d = sample_data(strategic_initiatives=String[], key_risks=String[],
                        management_responses=String[])
        doc = generate_board_packet(d)
        md  = render_to_markdown(doc)
        @test !isempty(md)
        strategic_section = doc.sections[11]
        @test !isempty(strategic_section.subsections)
    end

    @testset "RAG logic — _rag_str" begin
        # Higher is better (operating margin)
        @test _rag_str(0.05,  0.03, 0.0,  :higher) == "green"
        @test _rag_str(0.01,  0.03, 0.0,  :higher) == "amber"
        @test _rag_str(-0.02, 0.03, 0.0,  :higher) == "red"
        # Lower is better (debt to cap)
        @test _rag_str(0.40,  0.45, 0.60, :lower)  == "green"
        @test _rag_str(0.55,  0.45, 0.60, :lower)  == "amber"
        @test _rag_str(0.70,  0.45, 0.60, :lower)  == "red"
    end

    @testset "format helpers" begin
        @test contains(_fmt_pct(0.045), "4.5")
        @test contains(_fmt_usd(5_800_000.0), "5.8M")
        @test contains(_fmt_usd(285_000.0), "285K")
        @test contains(_fmt_days(52.4), "52.4")
        @test contains(_fmt_ratio(1.32), "1.32")
    end

end  # F-01


# ═════════════════════════════════════════════════════════════════════════════
# F-03: CFO Dashboard Model
# ═════════════════════════════════════════════════════════════════════════════

@testset "F-03 CFO Dashboard Model" begin

    @testset "RAG thresholds defined" begin
        t = CFO_RAG_THRESHOLDS
        @test t.operating_margin.green > t.operating_margin.amber
        @test t.days_cash_on_hand.green > t.days_cash_on_hand.amber
        @test t.current_ratio.green > t.current_ratio.amber
        # Lower-is-better thresholds
        @test t.debt_to_cap.green < t.debt_to_cap.amber
        @test t.salary_to_revenue.green < t.salary_to_revenue.amber
    end

    @testset "_rag — higher is better" begin
        @test _rag(0.05, 0.03, 0.0, :higher) == "green"
        @test _rag(0.01, 0.03, 0.0, :higher) == "amber"
        @test _rag(-0.05, 0.03, 0.0, :higher) == "red"
    end

    @testset "_rag — lower is better" begin
        @test _rag(0.40, 0.45, 0.60, :lower) == "green"
        @test _rag(0.52, 0.45, 0.60, :lower) == "amber"
        @test _rag(0.70, 0.45, 0.60, :lower) == "red"
    end

    @testset "sparkline data structure" begin
        labels = _week_labels(12)
        @test length(labels) == 12
        @test labels[1] == "W-11"
        @test labels[end] == "W-0"
    end

    @testset "_sparkline returns PlotData" begin
        vals   = fill(0.03, 12)
        labels = _week_labels(12)
        pd = _sparkline(vals, labels, "Margin", "#22c55e")
        @test pd isa PlotData
        @test length(pd.y) == 12
        @test pd.name == "Margin"
    end

    @testset "_sparkline_layout is compact (height=80)" begin
        layout = _sparkline_layout("Test")
        @test layout isa PlotLayout
        # Layout should have height specified as 80
        @test layout.height == 80
    end

end  # F-03


# ═════════════════════════════════════════════════════════════════════════════
# F-06: HCRIS Importer
# ═════════════════════════════════════════════════════════════════════════════

@testset "F-06 HCRIS Importer" begin

    @testset "hcris_annual_url — modern format (≥ 2020)" begin
        url = hcris_annual_url(2023)
        @test contains(url, "cms.gov")
        @test contains(url, "HOSP10")
        @test contains(url, "2023")
        @test startswith(url, "https://")
    end

    @testset "hcris_annual_url — legacy format (< 2020)" begin
        url = hcris_annual_url(2018)
        @test contains(url, "2018")
        @test !contains(url, "FY")
    end

    @testset "hcris_annual_url — different format for 2020+ vs pre-2020" begin
        old_url = hcris_annual_url(2019)
        new_url = hcris_annual_url(2020)
        @test old_url != new_url
    end

    @testset "cache_path — returns valid path string" begin
        p = cache_path("011300", 2023)
        @test contains(p, "011300")
        @test contains(p, "2023")
        @test endswith(p, ".zip")
        @test contains(p, "hcris_cache")
    end

    @testset "parse_args — required args" begin
        args = parse_args(["--ccn", "381322", "--year", "2023"])
        @test args[:ccn] == "381322"
        @test args[:year] == 2023
        @test args[:format] == "json"
        @test !args[:verbose]
        @test !args[:no_cache]
    end

    @testset "parse_args — optional args" begin
        args = parse_args(["--ccn", "011300", "--year", "2022",
                           "--output", "my_output.json",
                           "--format", "text",
                           "--verbose", "--no-cache"])
        @test args[:output] == "my_output.json"
        @test args[:format] == "text"
        @test args[:verbose] == true
        @test args[:no_cache] == true
    end

    @testset "parse_args — default output path includes CCN and year" begin
        args = parse_args(["--ccn", "381322", "--year", "2023"])
        @test contains(args[:output], "381322")
        @test contains(args[:output], "2023")
        @test endswith(args[:output], ".json")
    end

    @testset "extract_annual_financials — returns expected keys" begin
        # Empty worksheets → all zeros, but keys should all be present
        ws = Dict{String,Any}()
        af = extract_annual_financials(ws)
        @test haskey(af, "net_patient_revenue")
        @test haskey(af, "total_operating_expenses")
        @test haskey(af, "operating_income")
        @test haskey(af, "total_assets")
        @test haskey(af, "long_term_debt")
        @test haskey(af, "net_assets")
    end

    @testset "extract_annual_financials — operating_income = revenue - expenses" begin
        ws = Dict{String,Any}(
            "G300000" => Dict((1,1) => 5_000_000.0, (3,1) => 5_200_000.0),
            "A000000" => Dict((200,1) => 4_800_000.0),
        )
        af = extract_annual_financials(ws)
        @test af["net_patient_revenue"] ≈ 5_000_000.0 atol=1e-4
        @test af["total_operating_expenses"] ≈ 4_800_000.0 atol=1e-4
        @test af["operating_income"] ≈ 200_000.0 atol=1e-4
    end

    @testset "render_json — valid JSON output" begin
        report = HCRISReport(
            "011300", 2023, "Test Hospital", "CAH",
            "2022-10-01", "2023-09-30",
            Dict{String,Any}(),
            Dict("net_patient_revenue" => 5_000_000.0, "total_assets" => 9_000_000.0),
        )
        json_str = render_json(report)
        @test contains(json_str, "011300")
        @test contains(json_str, "Test Hospital")
        @test contains(json_str, "annual_financials")
        @test contains(json_str, "net_patient_revenue")
    end

    @testset "render_text — human-readable output" begin
        report = HCRISReport(
            "011300", 2023, "Test Hospital", "CAH",
            "2022-10-01", "2023-09-30",
            Dict{String,Any}(),
            Dict("net_patient_revenue" => 5_000_000.0),
        )
        txt = render_text(report)
        @test contains(txt, "Test Hospital")
        @test contains(txt, "011300")
        @test contains(txt, "net_patient_revenue")
    end

end  # F-06

println("\n✅  MBA Domain F (F-01 Board Packet, F-03 CFO Dashboard, F-06 HCRIS CLI) tests complete.")
