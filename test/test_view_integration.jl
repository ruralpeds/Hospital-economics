# ============================================================================
# View–Domain Smoke Tests
#
# These tests verify that the domain functions called by view model
# @onchange handlers work correctly with the parameter shapes that
# the UI layer constructs. Each test mirrors how a view model builds
# domain inputs from reactive UI variables.
# ============================================================================

using Test
using Dates

# Include source modules
include(joinpath(@__DIR__, "..", "src", "models", "abstract.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "department.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "staffing.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "payer.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "financial.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "capital.jl"))
include(joinpath(@__DIR__, "..", "src", "models", "hospital.jl"))
include(joinpath(@__DIR__, "..", "src", "utils", "constants.jl"))
using .Constants
include(joinpath(@__DIR__, "..", "src", "simulation", "deterministic.jl"))
include(joinpath(@__DIR__, "..", "src", "simulation", "montecarlo.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "ratios.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "costreport.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "reimbursement.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "breakeven.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "cashflow.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "debt_capacity.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "margin_decomposition.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "sensitivity.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "program340b.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "telehealth.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "vbc_transition.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "medicaid_supplemental.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "team_bundled.jl"))
include(joinpath(@__DIR__, "..", "src", "finance", "rhc_optimization.jl"))
include(joinpath(@__DIR__, "..", "src", "risk", "closure.jl"))
include(joinpath(@__DIR__, "..", "src", "risk", "conversion.jl"))
include(joinpath(@__DIR__, "..", "src", "risk", "closure_ml.jl"))
include(joinpath(@__DIR__, "..", "src", "risk", "disaster_resilience.jl"))
include(joinpath(@__DIR__, "..", "src", "analysis", "comparison.jl"))
include(joinpath(@__DIR__, "..", "src", "analysis", "community.jl"))
include(joinpath(@__DIR__, "..", "src", "analysis", "payer_negotiation.jl"))
include(joinpath(@__DIR__, "..", "src", "analysis", "sdoh.jl"))
include(joinpath(@__DIR__, "..", "src", "analysis", "geographic_access.jl"))
include(joinpath(@__DIR__, "..", "src", "analysis", "network_economics.jl"))
include(joinpath(@__DIR__, "..", "src", "analysis", "community_benefit.jl"))
include(joinpath(@__DIR__, "..", "src", "optimization", "portfolio.jl"))
include(joinpath(@__DIR__, "..", "src", "optimization", "capital_scoring.jl"))
include(joinpath(@__DIR__, "..", "src", "optimization", "staffing.jl"))

# ---------------------------------------------------------------------------
# Shared helpers — mirror the UI defaults
# ---------------------------------------------------------------------------
function smoke_test_cah()
    CriticalAccessHospital(;
        name="Smoke Test CAH", cms_provider_number="171301", npi="1234567890",
        cah_certification_date=Date(2006, 1, 15),
        licensed_beds=25, nearest_hospital_miles=35.0,
        location=GeoLocation(; latitude=38.5, longitude=-98.7,
            fips_code="20009", state="KS", county="Barton", zip_code="67530"),
        service_area=ServiceArea(; primary_service_area_pop=8000,
            total_service_area_pop=12000),
    )
end

function smoke_test_reh()
    RuralEmergencyHospital(;
        name="Smoke Test REH", cms_provider_number="171301", npi="1234567890",
        reh_conversion_date=Date(2024, 1, 1),
        former_designation=:cah, nearest_hospital_miles=35.0,
        location=GeoLocation(; latitude=38.5, longitude=-98.7,
            fips_code="20009", state="KS", county="Barton", zip_code="67530"),
        service_area=ServiceArea(; primary_service_area_pop=8000,
            total_service_area_pop=12000),
    )
end

function smoke_test_financials()
    AnnualFinancials(;
        fiscal_year=2025, fiscal_year_end=Date(2025, 12, 31),
        gross_patient_revenue=30_000_000.0,
        inpatient_revenue=8_000_000.0, outpatient_revenue=12_000_000.0,
        emergency_revenue=3_500_000.0, other_operating_revenue=500_000.0,
        non_operating_revenue=200_000.0,
        contractual_adjustments=12_000_000.0,
        net_patient_revenue=17_000_000.0,
        total_operating_revenue=17_500_000.0, total_revenue=17_700_000.0,
        salaries_wages=9_000_000.0, employee_benefits=2_700_000.0,
        supplies=1_800_000.0, depreciation=800_000.0, amortization=50_000.0,
        interest_expense=300_000.0, other_operating_expenses=2_000_000.0,
        total_operating_expenses=17_650_000.0,
        operating_income=-150_000.0, operating_margin=-0.0086,
        ebitda=1_000_000.0,
        total_assets=25_000_000.0, current_assets=5_000_000.0,
        cash_and_equivalents=2_500_000.0, net_accounts_receivable=2_000_000.0,
        total_liabilities=12_000_000.0, current_liabilities=3_000_000.0,
        long_term_debt=8_000_000.0, net_assets=13_000_000.0,
    )
end

@testset "View–Domain Smoke Tests" begin

    # -----------------------------------------------------------------------
    # DashboardModel: compute_all_ratios
    # -----------------------------------------------------------------------
    @testset "Dashboard → compute_all_ratios" begin
        financials = smoke_test_financials()
        ratios = compute_all_ratios(financials)
        @test ratios isa NamedTuple
        @test haskey(ratios, :operating_margin)
        @test haskey(ratios, :days_cash_on_hand)
        @test haskey(ratios, :current_ratio)
        @test ratios.operating_margin isa Float64
    end

    # -----------------------------------------------------------------------
    # CostReimbursementModel: step_down_allocation
    # -----------------------------------------------------------------------
    @testset "CostReimbursement → step_down_allocation" begin
        cost_centers = default_cah_cost_centers()
        for cc in cost_centers
            cc.direct_cost = 80_000.0
        end
        allocated = step_down_allocation(cost_centers)
        @test allocated isa Dict{String,Float64}
        @test sum(values(allocated)) > 0.0
    end

    # -----------------------------------------------------------------------
    # SimulationRunnerModel: project_financials (deterministic)
    # -----------------------------------------------------------------------
    @testset "SimulationRunner → project_financials" begin
        hospital = smoke_test_cah()
        params = DeterministicParams(; projection_years=5)
        result = project_financials(hospital, params)
        @test result isa DeterministicResult
        @test length(result.projections) == 5
    end

    # -----------------------------------------------------------------------
    # PayerMarginModel: decompose_margin
    # -----------------------------------------------------------------------
    @testset "PayerMargin → decompose_margin" begin
        payer_data = Dict(
            :medicare => (revenue=8_000_000.0, cost_ratio=1.01),
            :medicaid => (revenue=3_000_000.0, cost_ratio=1.15),
            :commercial => (revenue=5_000_000.0, cost_ratio=0.75),
            :self_pay => (revenue=1_000_000.0, cost_ratio=1.40),
        )
        result = decompose_margin(payer_data)
        @test result isa MarginDecomposition || result isa NamedTuple
    end

    # -----------------------------------------------------------------------
    # CashFlowModel: project_monthly_cash_flow
    # -----------------------------------------------------------------------
    @testset "CashFlow → project_monthly_cash_flow" begin
        result = project_monthly_cash_flow(;
            starting_cash=2_500_000.0,
            monthly_revenue=1_500_000.0,
            monthly_expenses=1_550_000.0,
            months=12,
        )
        @test length(result) == 12
        @test result[1].ending_balance isa Float64
    end

    # -----------------------------------------------------------------------
    # DebtCapacityModel: calculate_debt_capacity
    # -----------------------------------------------------------------------
    @testset "DebtCapacity → calculate_debt_capacity" begin
        params = DebtCapacityParams(;
            ebitda=1_000_000.0,
            existing_debt_service=200_000.0,
            target_dscr=1.25,
            interest_rate=0.05,
            term_years=20,
        )
        result = calculate_debt_capacity(params)
        @test result.maximum_debt > 0.0
    end

    # -----------------------------------------------------------------------
    # Program340BModel: calculate_340b_impact
    # -----------------------------------------------------------------------
    @testset "Program340B → calculate_340b_impact" begin
        params = Program340BParams(;
            total_pharmacy_spend=600_000.0,
            eligible_outpatient_revenue=12_000_000.0,
            contract_pharmacy_count=3,
        )
        result = calculate_340b_impact(params)
        @test result.estimated_savings > 0.0
    end

    # -----------------------------------------------------------------------
    # TelehealthModel: calculate_telehealth_roi
    # -----------------------------------------------------------------------
    @testset "Telehealth → calculate_telehealth_roi" begin
        services = [TelehealthService(;
            name="Primary Care", monthly_visits=100,
            revenue_per_visit=85.0, cost_per_visit=35.0,
        )]
        investment = TelehealthInvestment(;
            platform_cost=50_000.0, training_cost=10_000.0,
            annual_maintenance=12_000.0,
        )
        result = calculate_telehealth_roi(services, investment)
        @test result isa TelehealthROI || result isa NamedTuple
    end

    # -----------------------------------------------------------------------
    # VBCTransitionModel: calculate_vbc_outcome
    # -----------------------------------------------------------------------
    @testset "VBCTransition → calculate_vbc_outcome" begin
        params = VBCParams(;
            attributed_lives=2000,
            pmpm_benchmark=450.0,
            quality_score=0.80,
        )
        result = calculate_vbc_outcome(params)
        @test result isa NamedTuple || result isa VBCOutcome
    end

    # -----------------------------------------------------------------------
    # MedicaidSupplementalModel: calculate_medicaid_supplemental
    # -----------------------------------------------------------------------
    @testset "MedicaidSupplemental → calculate_medicaid_supplemental" begin
        params = MedicaidSupplementalParams(;
            medicaid_days=400,
            medicaid_charges=1_500_000.0,
            state="KS",
        )
        result = calculate_medicaid_supplemental(params)
        @test result isa NamedTuple || hasproperty(result, :total_supplemental)
    end

    # -----------------------------------------------------------------------
    # TEAMBundledModel: calculate_team_reconciliation
    # -----------------------------------------------------------------------
    @testset "TEAMBundled → calculate_team_reconciliation" begin
        params = TEAMParams(;
            episode_count=50,
            avg_episode_cost=25_000.0,
            target_price=24_000.0,
            quality_score=0.75,
        )
        result = calculate_team_reconciliation(params)
        @test result isa NamedTuple || hasproperty(result, :reconciliation_amount)
    end

    # -----------------------------------------------------------------------
    # RHCOptimizationModel: optimize_rhc_revenue
    # -----------------------------------------------------------------------
    @testset "RHCOptimization → optimize_rhc_revenue" begin
        params = RHCParams(;
            annual_visits=6000,
            current_air=120.0,
        )
        result = optimize_rhc_revenue(params)
        @test result isa NamedTuple || hasproperty(result, :optimized_revenue)
    end

    # -----------------------------------------------------------------------
    # ClosureRisk via view: assess_closure_risk
    # -----------------------------------------------------------------------
    @testset "ClosureRisk → assess_closure_risk" begin
        hospital = smoke_test_cah()
        market = MarketData(true, 0.35, -0.02, 40.0, 0.18, 0.12)
        assessment = assess_closure_risk(hospital, market;
            financial_data=Dict("operating_margin" => -0.04,
                "days_cash_on_hand" => 45.0, "current_ratio" => 1.5))
        @test 0.0 <= assessment.composite_risk_score <= 1.0
        @test assessment.risk_category in [:low, :moderate, :high, :critical]
    end

    # -----------------------------------------------------------------------
    # CommunityImpactModel: calculate_community_impact
    # -----------------------------------------------------------------------
    @testset "CommunityImpact → calculate_community_impact" begin
        params = CommunityImpactParams(;
            hospital_employees=150,
            annual_payroll=9_000_000.0,
            local_spending_pct=0.60,
            service_area_pop=12_000,
        )
        result = calculate_community_impact(params)
        @test result isa NamedTuple || hasproperty(result, :total_economic_impact)
    end

    # -----------------------------------------------------------------------
    # SDOHModel: calculate_sdoh_adjustments
    # -----------------------------------------------------------------------
    @testset "SDOH → calculate_sdoh_adjustments" begin
        profile = SDOHProfile(;
            poverty_rate=0.18,
            uninsured_rate=0.12,
            median_income=42_000.0,
            food_insecurity_pct=0.15,
        )
        result = calculate_sdoh_adjustments(profile)
        @test result isa NamedTuple || result isa Dict
    end

    # -----------------------------------------------------------------------
    # GeographicAccessModel: calculate_catchment + haversine_distance
    # -----------------------------------------------------------------------
    @testset "GeographicAccess → haversine_distance" begin
        d = haversine_distance(38.5, -98.7, 39.0, -99.0)
        @test d > 0.0
        @test d < 100.0  # should be a short distance in miles/km
    end

    # -----------------------------------------------------------------------
    # DisasterResilienceModel: assess_disaster_resilience
    # -----------------------------------------------------------------------
    @testset "DisasterResilience → assess_disaster_resilience" begin
        profile = DisasterProfile(;
            flood_risk=0.3, tornado_risk=0.5, earthquake_risk=0.1,
            pandemic_preparedness=0.6,
        )
        result = assess_disaster_resilience(profile)
        @test result isa NamedTuple || hasproperty(result, :vulnerability_scores)
    end

    # -----------------------------------------------------------------------
    # CapitalScoringModel: score_capital_projects
    # -----------------------------------------------------------------------
    @testset "CapitalScoring → score_capital_projects" begin
        projects = [
            CapitalRequest(;
                name="CT Scanner",
                cost=1_500_000.0,
                useful_life=10,
                expected_annual_revenue=500_000.0,
                clinical_priority=0.8,
            ),
            CapitalRequest(;
                name="Roof Repair",
                cost=300_000.0,
                useful_life=20,
                expected_annual_revenue=0.0,
                clinical_priority=0.3,
                safety_regulatory=true,
            ),
        ]
        scored = score_capital_projects(projects)
        @test length(scored) == 2
    end

    # -----------------------------------------------------------------------
    # SensitivityModel: run_sensitivity_analysis
    # -----------------------------------------------------------------------
    @testset "Sensitivity → run_sensitivity_analysis" begin
        hospital = smoke_test_cah()
        base_params = DeterministicParams(; projection_years=5)
        result = run_sensitivity_analysis(hospital, base_params;
            variables=[:volume_growth_rate, :cost_inflation_rate],
            range_pct=0.20,
        )
        @test result isa Dict || result isa NamedTuple || result isa Vector
    end

    # -----------------------------------------------------------------------
    # ClosureML: chartis_vulnerability_score
    # -----------------------------------------------------------------------
    @testset "ClosureML → chartis_vulnerability_score" begin
        features = ClosureMLFeatures(;
            case_mix_index=1.0, occupancy_rate=0.35,
            avg_age_of_plant=12.0, years_negative_operating_margin=1,
        )
        score = chartis_vulnerability_score(features)
        @test 0.0 <= score <= 1.0
    end

    # -----------------------------------------------------------------------
    # NetworkEconomics: evaluate_network
    # -----------------------------------------------------------------------
    @testset "NetworkEconomics → evaluate_network" begin
        members = [
            NetworkMember(; name="Hospital A", beds=25, annual_revenue=18_000_000.0),
            NetworkMember(; name="Hospital B", beds=15, annual_revenue=12_000_000.0),
        ]
        shared = [SharedService(; name="Lab", annual_cost=200_000.0, shareable_pct=0.40)]
        result = evaluate_network(members, shared)
        @test result isa NamedTuple || hasproperty(result, :total_savings)
    end

    # -----------------------------------------------------------------------
    # REH conversion via view: reh_conversion_analysis
    # -----------------------------------------------------------------------
    @testset "REHWizard → REH conversion types exist" begin
        hospital = smoke_test_reh()
        @test hospital isa RuralEmergencyHospital
        @test hospital.former_designation == :cah
        # REH reimbursement should work
        result = calculate_medicare_reimbursement(hospital; sequestration=true)
        @test result.total_reimbursement > 0.0
    end
end
