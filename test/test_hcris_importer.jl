using Test
using Dates
include("../src/data_ingestion/hcris_importer.jl")

@testset "HCRIS Importer" begin
    # ─────────────────────────────────────────────────────────────────────
    # Test 1: Import valid CCN returns correct structure
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = import_hcris("011300", 2023)
        haskey(result, :financials) &&
        haskey(result, :balance_sheet) &&
        haskey(result, :metadata)
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 2: Financials struct is properly populated
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = import_hcris("011300", 2023)
        f = result.financials
        f.fiscal_year == 2023 &&
        f.total_operating_revenue > 0 &&
        f.total_operating_expenses > 0 &&
        f.net_assets > 0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 3: Balance sheet is balanced within tolerance
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = import_hcris("011300", 2023)
        bs = result.balance_sheet

        current_assets = bs.cash_and_equivalents + bs.short_term_investments +
                        bs.accounts_receivable_net + bs.inventory
        net_ppe = bs.gross_ppe - bs.accumulated_depreciation
        total_assets = current_assets + net_ppe + bs.long_term_investments

        current_liabilities = bs.accounts_payable + bs.accrued_expenses +
                            bs.current_portion_lt_debt
        total_liabilities = current_liabilities + bs.long_term_debt

        total_net_assets = bs.net_assets_unrestricted

        abs(total_assets - (total_liabilities + total_net_assets)) < 1000.0
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 4: Missing CCN throws error
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        try
            import_hcris("999999", 2023)
            false
        catch err
            err isa ArgumentError && contains(string(err), "not found")
        end
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 5: Hospital type detection works
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = import_hcris("011300", 2023)
        result.metadata["hospital_type"] == "cah"
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 6: Metadata has required keys
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = import_hcris("011300", 2023)
        m = result.metadata
        haskey(m, "ccn") &&
        haskey(m, "fiscal_year") &&
        haskey(m, "hospital_type") &&
        haskey(m, "source") &&
        haskey(m, "import_timestamp")
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 7: Multiple CCNs can be imported
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        r1 = import_hcris("011300", 2023)
        r2 = import_hcris("011301", 2023)
        r3 = import_hcris("011302", 2023)

        r1.financials.total_operating_revenue != r2.financials.total_operating_revenue &&
        r2.financials.total_operating_revenue != r3.financials.total_operating_revenue
    end

    # ─────────────────────────────────────────────────────────────────────
    # Test 8: Key financial ratios are computed
    # ─────────────────────────────────────────────────────────────────────
    @test begin
        result = import_hcris("011300", 2023)
        f = result.financials

        f.current_ratio > 0 &&
        f.days_cash_on_hand > 0 &&
        f.days_in_accounts_receivable > 0 &&
        0 <= f.debt_to_capitalization <= 1
    end
end
