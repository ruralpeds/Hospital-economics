# Migration 004: Create fiscal_years table (historical financial data)

module CreateFiscalYears

import SearchLight.Migrations:
    create_table, column, columns, pk, add_index,
    drop_table

function up()
    create_table(:fiscal_years) do
        [
            pk()
            column(:hospital_id, :int)
            column(:fiscal_year, :int)
            column(:fiscal_year_end, :date)

            # Revenue
            column(:gross_patient_revenue, :float, default=0.0)
            column(:inpatient_revenue, :float, default=0.0)
            column(:outpatient_revenue, :float, default=0.0)
            column(:emergency_revenue, :float, default=0.0)
            column(:other_operating_revenue, :float, default=0.0)
            column(:non_operating_revenue, :float, default=0.0)

            # Deductions
            column(:contractual_adjustments, :float, default=0.0)
            column(:charity_care, :float, default=0.0)
            column(:bad_debt_expense, :float, default=0.0)
            column(:net_patient_revenue, :float, default=0.0)
            column(:total_operating_revenue, :float, default=0.0)
            column(:total_revenue, :float, default=0.0)

            # Expenses
            column(:salaries_wages, :float, default=0.0)
            column(:employee_benefits, :float, default=0.0)
            column(:purchased_services, :float, default=0.0)
            column(:supplies, :float, default=0.0)
            column(:depreciation, :float, default=0.0)
            column(:interest_expense, :float, default=0.0)
            column(:other_operating_expenses, :float, default=0.0)
            column(:total_operating_expenses, :float, default=0.0)

            # Performance
            column(:operating_income, :float, default=0.0)
            column(:operating_margin, :float, default=0.0)
            column(:total_margin, :float, default=0.0)
            column(:ebitda, :float, default=0.0)

            # Balance sheet
            column(:total_assets, :float, default=0.0)
            column(:current_assets, :float, default=0.0)
            column(:cash_and_equivalents, :float, default=0.0)
            column(:total_liabilities, :float, default=0.0)
            column(:current_liabilities, :float, default=0.0)
            column(:long_term_debt, :float, default=0.0)
            column(:net_assets, :float, default=0.0)

            # Ratios
            column(:current_ratio, :float, default=0.0)
            column(:days_cash_on_hand, :float, default=0.0)
            column(:debt_to_capitalization, :float, default=0.0)
            column(:average_age_of_plant, :float, default=0.0)

            # Volume
            column(:inpatient_days, :int, default=0)
            column(:inpatient_discharges, :int, default=0)
            column(:ed_visits, :int, default=0)
            column(:outpatient_visits, :int, default=0)
            column(:medicare_days_pct, :float, default=0.0)
            column(:medicaid_days_pct, :float, default=0.0)

            column(:created_at, :datetime)
            column(:updated_at, :datetime)
        ]
    end

    add_index(:fiscal_years, :hospital_id)
    add_index(:fiscal_years, [:hospital_id, :fiscal_year]; unique=true)
end

function down()
    drop_table(:fiscal_years)
end

end
