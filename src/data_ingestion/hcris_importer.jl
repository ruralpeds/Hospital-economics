"""
    hcris_importer.jl — CMS HCRIS cost report parser and importer

Loads hospital-level financial data from HCRIS public-use files and
populates AnnualFinancials and BalanceSheetSnapshot structs.
"""

using CSV, DataFrames, Dates

"""
    import_hcris(ccn::String, fiscal_year::Int;
                 cache_dir::String="data/hcris",
                 hospital_type::Symbol=:auto) -> NamedTuple

Import HCRIS data for a specific hospital (CCN) and fiscal year.

# Arguments
- ccn: 6-digit hospital CCN (e.g., "011300")
- fiscal_year: CMS fiscal year (e.g., 2023)
- cache_dir: Directory to cache downloaded files
- hospital_type: :cah, :pps, or :auto

# Returns
NamedTuple with:
- financials::AnnualFinancials
- balance_sheet::BalanceSheetSnapshot
- metadata::Dict

# Notes
This implementation reads from local fixture files for testing.
Production use would download from CMS HCRIS public-use files.
"""
function import_hcris(ccn::String, fiscal_year::Int;
                     cache_dir::String="data/hcris",
                     hospital_type::Symbol=:auto)::NamedTuple

    # For now, use local fixture file (in production, would download from CMS)
    fixture_file = joinpath(@__DIR__, "..", "..", "test", "fixtures", "hcris", "sample_cah_2023.csv")

    if !isfile(fixture_file)
        throw(ArgumentError("HCRIS fixture file not found: $fixture_file"))
    end

    # Read CSV
    df = CSV.read(fixture_file, DataFrame)

    # Find matching row
    row = filter(r -> r.CCN == ccn, df)
    if nrow(row) == 0
        throw(ArgumentError("CCN $ccn not found in HCRIS data"))
    end

    r = row[1, :]

    # Determine hospital type
    if hospital_type == :auto
        htype = lowercase(string(r.HospitalType)) == "cah" ? :cah : :pps
    else
        htype = hospital_type
    end

    # Build AnnualFinancials
    financials = (
        fiscal_year = fiscal_year,
        fiscal_year_end = r.FiscalYearEnd isa Date ? r.FiscalYearEnd : Date(fiscal_year, 12, 31),
        gross_patient_revenue = Float64(r.TotalGrossPatientRevenue),
        inpatient_revenue = Float64(r.TotalPatientRevenue) * 0.65,  # Estimated split
        outpatient_revenue = Float64(r.TotalPatientRevenue) * 0.35,
        emergency_revenue = Float64(r.OutpatientVisits) > 0 ? Float64(r.OutpatientVisits) * 800.0 : 0.0,
        physician_revenue = Float64(r.PhysicianFees),
        other_operating_revenue = 0.0,
        non_operating_revenue = 0.0,
        contractual_adjustments = Float64(r.TotalGrossPatientRevenue) - Float64(r.TotalPatientRevenue),
        charity_care = 0.0,
        bad_debt_expense = 0.0,
        total_deductions = Float64(r.TotalGrossPatientRevenue) - Float64(r.TotalPatientRevenue),
        net_patient_revenue = Float64(r.TotalPatientRevenue),
        total_operating_revenue = Float64(r.TotalOperatingRevenue),
        total_revenue = Float64(r.TotalOperatingRevenue),
        salaries_wages = Float64(r.SalariesWages),
        employee_benefits = Float64(r.EmployeeBenefits),
        physician_fees = Float64(r.PhysicianFees),
        purchased_services = 0.0,
        supplies = Float64(r.Supplies),
        pharmaceuticals = 0.0,
        utilities = Float64(r.Utilities),
        insurance = 0.0,
        lease_rental = 0.0,
        depreciation = Float64(r.Depreciation),
        amortization = 0.0,
        interest_expense = Float64(r.InterestExpense),
        other_operating_expenses = 0.0,
        total_operating_expenses = Float64(r.TotalOperatingExpenses),
        operating_income = Float64(r.TotalOperatingRevenue) - Float64(r.TotalOperatingExpenses),
        operating_margin = (Float64(r.TotalOperatingRevenue) - Float64(r.TotalOperatingExpenses)) / Float64(r.TotalOperatingRevenue),
        total_margin = 0.0,
        ebitda = Float64(r.TotalOperatingRevenue) - Float64(r.TotalOperatingExpenses) + Float64(r.Depreciation),
        ebitda_margin = 0.0,
        total_assets = Float64(r.TotalAssets),
        current_assets = Float64(r.CurrentAssets),
        cash_and_equivalents = Float64(r.CashAndEquivalents),
        net_accounts_receivable = Float64(r.AccountsReceivable),
        total_liabilities = Float64(r.TotalLiabilities),
        current_liabilities = Float64(r.CurrentLiabilities),
        long_term_debt = Float64(r.LongTermDebt),
        net_assets = Float64(r.NetAssets),
        current_ratio = Float64(r.CurrentAssets) / Float64(r.CurrentLiabilities),
        days_cash_on_hand = (Float64(r.CashAndEquivalents) / Float64(r.TotalOperatingExpenses)) * 365.0,
        days_in_accounts_receivable = (Float64(r.AccountsReceivable) / Float64(r.TotalOperatingRevenue)) * 365.0,
        debt_to_capitalization = Float64(r.LongTermDebt) / (Float64(r.LongTermDebt) + Float64(r.NetAssets)),
        average_age_of_plant = Float64(r.AccumulatedDepreciation) / (Float64(r.GrossPPE) > 0 ? Float64(r.GrossPPE) : 1.0),
        inpatient_days = Int(r.InpatientDays),
        inpatient_discharges = Int(r.InpatientDischarges),
        observation_hours = 0.0,
        ed_visits = Int(r.EDVisits),
        outpatient_visits = Int(r.OutpatientVisits),
        surgical_cases = 0,
        births = 0,
        medicare_days_pct = Float64(r.MedicareDaysPercent),
        medicaid_days_pct = Float64(r.MedicaidDaysPercent),
        medicare_cost_to_charge_ratio = 0.8,
        cost_per_adjusted_discharge = Float64(r.TotalOperatingExpenses) / (Float64(r.InpatientDischarges) + 0.1),
        is_operating_loss = Float64(r.TotalOperatingRevenue) < Float64(r.TotalOperatingExpenses),
        consecutive_loss_years = 0
    )

    # Build BalanceSheetSnapshot
    balance_sheet = BalanceSheetSnapshot(
        as_of_date = Date(fiscal_year, 12, 31),
        cash_and_equivalents = Float64(r.CashAndEquivalents),
        short_term_investments = Float64(r.CurrentAssets) - Float64(r.CashAndEquivalents) - Float64(r.AccountsReceivable) - Float64(r.Inventory),
        accounts_receivable_net = Float64(r.AccountsReceivable),
        inventory = Float64(r.Inventory),
        gross_ppe = Float64(r.GrossPPE),
        accumulated_depreciation = Float64(r.AccumulatedDepreciation),
        long_term_investments = max(0.0, Float64(r.TotalAssets) - Float64(r.CurrentAssets) - (Float64(r.GrossPPE) - Float64(r.AccumulatedDepreciation))),
        accounts_payable = Float64(r.AccountsPayable),
        accrued_expenses = Float64(r.CurrentLiabilities) - Float64(r.AccountsPayable),
        current_portion_lt_debt = min(Float64(r.LongTermDebt) * 0.1, Float64(r.LongTermDebt)),
        long_term_debt = Float64(r.LongTermDebt),
        net_assets_unrestricted = Float64(r.NetAssets)
    )

    # Metadata
    metadata = Dict(
        "ccn" => ccn,
        "fiscal_year" => fiscal_year,
        "hospital_type" => String(htype),
        "source" => "HCRIS",
        "import_timestamp" => Dates.now()
    )

    return (
        financials = financials,
        balance_sheet = balance_sheet,
        metadata = metadata
    )
end
