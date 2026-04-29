"""
Stipple reactive model for Function Explorer (E23).
Provides a searchable catalog of all FinanceEngine analytics functions
with category filtering, parameter documentation, and demo output.
"""
using Stipple, StippleUI, StipplePlotly
using ...FinanceEngine

const _FE_CATALOG = [
    # ── Domain A
    Dict("id"=>"nonprofit_wacc","name"=>"nonprofit_wacc()","section"=>"Finance (A)","status"=>"live",
        "description"=>"Compute not-for-profit WACC from MMD yield curve, Hamada un/re-levering, and tax-exempt debt adjustment.",
        "returns"=>"WACCResult","params"=>"WACCInputs"),
    Dict("id"=>"synthetic_rating","name"=>"synthetic_rating()","section"=>"Finance (A)","status"=>"live",
        "description"=>"Generate Moody\'s/S&P equivalent credit rating from financial ratios.",
        "returns"=>"SyntheticRatingResult","params"=>"RatingInputs"),
    Dict("id"=>"hospital_lbo","name"=>"hospital_lbo()","section"=>"Finance (A)","status"=>"live",
        "description"=>"Full LBO analysis: debt tranches, amortisation schedule, exit IRR/MOIC.",
        "returns"=>"LBOResult","params"=>"LBOInputs"),
    Dict("id"=>"hospital_ma_valuation","name"=>"hospital_ma_valuation()","section"=>"Finance (A)","status"=>"live",
        "description"=>"Multi-method M&A valuation: DCF + comparable transactions + asset-based + synergy NPV.",
        "returns"=>"MAValuationResult","params"=>"MAValuationInputs"),
    Dict("id"=>"compute_working_capital","name"=>"compute_working_capital()","section"=>"Finance (A)","status"=>"live",
        "description"=>"Cash Conversion Cycle: DSO + DIO - DPO, current ratio, quick ratio.",
        "returns"=>"WorkingCapitalMetrics","params"=>"WorkingCapitalInputs"),
    # ── Domain B
    Dict("id"=>"optimize_service_line_portfolio","name"=>"optimize_service_line_portfolio()","section"=>"Strategy (B)","status"=>"live",
        "description"=>"Markowitz mean-variance efficient frontier for hospital service-line capital allocation.",
        "returns"=>"ServiceLinePortfolioResult","params"=>"Vector{ServiceLine}"),
    Dict("id"=>"nash_bargaining","name"=>"nash_bargaining()","section"=>"Strategy (B)","status"=>"live",
        "description"=>"Generalised Nash bargaining solution for payer contract negotiations.",
        "returns"=>"NashBargainResult","params"=>"NashBargainInputs"),
    Dict("id"=>"analyze_market_share","name"=>"analyze_market_share()","section"=>"Strategy (B)","status"=>"live",
        "description"=>"HHI, discharge/revenue market share, geographic overlap, competitive position score.",
        "returns"=>"MarketShareResult","params"=>"Vector{HospitalCompetitor}"),
    Dict("id"=>"blue_ocean_analysis","name"=>"blue_ocean_analysis()","section"=>"Strategy (B)","status"=>"live",
        "description"=>"Blue Ocean ERRC grid, differentiation index, and convergence warnings.",
        "returns"=>"BlueOceanResult","params"=>"StrategicCanvas"),
    # ── Domain C
    Dict("id"=>"run_sfa","name"=>"run_sfa()","section"=>"Operations (C)","status"=>"live",
        "description"=>"Stochastic Frontier Analysis: translog cost OLS + JLMS efficiency estimator.",
        "returns"=>"SFAAnalysis","params"=>"Vector{SFAHospital}"),
    Dict("id"=>"run_tdabc","name"=>"run_tdabc()","section"=>"Operations (C)","status"=>"live",
        "description"=>"Time-Driven ABC: cost per encounter, unused capacity, CTC comparison.",
        "returns"=>"NamedTuple","params"=>"TDABCModel, Vector{TDABCEncounter}"),
    Dict("id"=>"step_down_allocation","name"=>"step_down_allocation()","section"=>"Operations (C)","status"=>"live",
        "description"=>"CMS Worksheet A step-down cost allocation by sequence.",
        "returns"=>"AllocationSummary","params"=>"CostAllocationModel"),
    Dict("id"=>"reciprocal_allocation","name"=>"reciprocal_allocation()","section"=>"Operations (C)","status"=>"live",
        "description"=>"Simultaneous reciprocal cost allocation: (I-S)x=c linear system.",
        "returns"=>"AllocationSummary","params"=>"CostAllocationModel"),
    # ── Domain D
    Dict("id"=>"cox_ph_closure_risk","name"=>"cox_ph_closure_risk()","section"=>"Risk (D)","status"=>"live",
        "description"=>"Cox PH rural hospital closure risk: 1/3/5-year probabilities, risk tier.",
        "returns"=>"ClosureRiskResult","params"=>"ClosureRiskInputs"),
    Dict("id"=>"mssp_bayesian_analysis","name"=>"mssp_bayesian_analysis()","section"=>"Risk (D)","status"=>"live",
        "description"=>"Bayesian MSSP analysis: conjugate update + 3-level MC uncertainty.",
        "returns"=>"MSSPBayesianResult","params"=>"MSSPHospitalInputs"),
    Dict("id"=>"run_ccar_stress_test","name"=>"run_ccar_stress_test()","section"=>"Risk (D)","status"=>"live",
        "description"=>"CCAR stress test: baseline/adverse/severely-adverse, covenant breach.",
        "returns"=>"NamedTuple","params"=>"HospitalStressTestInputs"),
    Dict("id"=>"lace_score","name"=>"lace_score()","section"=>"Risk (D)","status"=>"live",
        "description"=>"LACE readmission risk index (van Walraven 2010): L+A+C+E scoring.",
        "returns"=>"NamedTuple","params"=>"length_of_stay, acuity, charlson, ed_visits"),
    # ── Domain E
    Dict("id"=>"calculate_team_target_price","name"=>"calculate_team_target_price()","section"=>"Reimbursement (E)","status"=>"live",
        "description"=>"TEAM FY2026 target price: benchmark × trending × risk × quality × 0.97.",
        "returns"=>"Float64","params"=>"TEAMTargetPriceInputs, risk_score, quality_category"),
    Dict("id"=>"calculate_sdp_payment","name"=>"calculate_sdp_payment()","section"=>"Reimbursement (E)","status"=>"live",
        "description"=>"Medicaid state directed payment: eligibility tier, directed amount, UPL test.",
        "returns"=>"SDPPaymentResult","params"=>"SDPHospitalInputs, SDPProgramInputs"),
    Dict("id"=>"analyze_idr_claim","name"=>"analyze_idr_claim()","section"=>"Reimbursement (E)","status"=>"live",
        "description"=>"NSA-IDR claim economics: expected payment vs QPA, admin fee, recommend/reject.",
        "returns"=>"IDRClaimResult","params"=>"IDRClaimInputs"),
    # ── Domain F
    Dict("id"=>"generate_rating_memo_markdown","name"=>"generate_rating_memo_markdown()","section"=>"Reporting (F)","status"=>"live",
        "description"=>"Rating agency credit memo: 8-section Moody\'s-style narrative as Markdown.",
        "returns"=>"String","params"=>"RatingMemoInputs"),
    Dict("id"=>"one_way_sensitivity","name"=>"one_way_sensitivity()","section"=>"Reporting (F)","status"=>"live",
        "description"=>"Universal tornado: one-way sensitivity for any (NamedTuple→Float64) model.",
        "returns"=>"TornadoResult","params"=>"model::Function, baseline, pct_swings"),
    Dict("id"=>"compare_scenarios","name"=>"compare_scenarios()","section"=>"Reporting (F)","status"=>"live",
        "description"=>"Scenario diff: delta table, best/worst per metric, waterfall builder.",
        "returns"=>"ScenarioDiff","params"=>"baseline::ScenarioSnapshot, comparisons"),
]

@app begin
    @in left_drawer_open::Bool = true
    @in search_query::String = ""
    @in section_filter::String = "all"
    @in status_filter::String = "all"
    @out filtered_functions::Vector{Dict{String,Any}} = _FE_CATALOG
    @out all_functions::Vector{Dict{String,Any}} = _FE_CATALOG
    @in selected_function::String = ""
    @in inline_params::String = "{}"
    @out inline_result::String = ""
    @in run_inline::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange search_query, section_filter, status_filter begin
        q = lowercase(search_query)
        filtered_functions = filter(_FE_CATALOG) do f
            name_match = isempty(q) || contains(lowercase(f["name"]), q) ||
                         contains(lowercase(f["description"]), q)
            sec_match  = section_filter == "all" || f["section"] == section_filter
            stat_match = status_filter == "all"  || f["status"]  == status_filter
            name_match && sec_match && stat_match
        end
    end

    @onchange run_inline begin
        run_inline || return
        running = true; errors = String[]
        try
            inline_result = "Function $(selected_function) — use the full UI view for this function to pass typed inputs and see live output."
        catch e; push!(errors, sprint(showerror,e))
        finally; running = false; end
        run_inline = false
    end
end
const functions_model = @init
