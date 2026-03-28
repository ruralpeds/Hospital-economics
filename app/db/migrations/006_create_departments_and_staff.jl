# Migration 006: Create departments, service_lines, staff_positions, and payer_contracts tables

module CreateDepartmentsAndStaff

import SearchLight.Migrations:
    create_table, column, columns, pk, add_index,
    drop_table

function up()
    create_table(:departments) do
        [
            pk()
            column(:hospital_id, :int)
            column(:cost_center_code, :string; limit=10)
            column(:name, :string; limit=100)
            column(:category, :string; limit=30)  # overhead, direct_patient, ancillary, support
            column(:is_revenue_producing, :bool, default=false)
            column(:direct_costs, :float, default=0.0)
            column(:allocated_costs, :float, default=0.0)
            column(:total_costs, :float, default=0.0)
            column(:charges, :float, default=0.0)
            column(:cost_to_charge_ratio, :float, default=0.0)
            column(:square_footage, :float, default=0.0)
            column(:created_at, :datetime)
            column(:updated_at, :datetime)
        ]
    end

    add_index(:departments, :hospital_id)

    create_table(:service_lines) do
        [
            pk()
            column(:hospital_id, :int)
            column(:name, :string; limit=100)
            column(:is_active, :bool, default=true)
            column(:annual_volume, :int, default=0)
            column(:annual_revenue, :float, default=0.0)
            column(:annual_direct_cost, :float, default=0.0)
            column(:annual_indirect_cost, :float, default=0.0)
            column(:contribution_margin, :float, default=0.0)
            column(:requires_on_call, :bool, default=false)
            column(:cross_referral_impact, :float, default=0.0)
            column(:community_need_score, :float, default=0.5)
            column(:created_at, :datetime)
            column(:updated_at, :datetime)
        ]
    end

    add_index(:service_lines, :hospital_id)

    create_table(:staff_positions) do
        [
            pk()
            column(:hospital_id, :int)
            column(:title, :string; limit=100)
            column(:department, :string; limit=100)
            column(:category, :string; limit=30)  # physician, nursing, allied, admin, support
            column(:fte, :float, default=1.0)
            column(:annual_salary, :float, default=0.0)
            column(:benefits_pct, :float, default=0.25)
            column(:is_travel, :bool, default=false)
            column(:travel_premium, :float, default=1.0)
            column(:is_vacant, :bool, default=false)
            column(:created_at, :datetime)
            column(:updated_at, :datetime)
        ]
    end

    add_index(:staff_positions, :hospital_id)

    create_table(:payer_contracts) do
        [
            pk()
            column(:hospital_id, :int)
            column(:payer_name, :string; limit=100)
            column(:payer_type, :string; limit=30)  # medicare, medicaid, commercial, self_pay, tricare, va, other
            column(:overall_volume_pct, :float, default=0.0)
            column(:inpatient_volume_pct, :float, default=0.0)
            column(:outpatient_volume_pct, :float, default=0.0)
            column(:ed_volume_pct, :float, default=0.0)
            column(:payment_method, :string; limit=30, default="fee_for_service")
            column(:payment_rate_inpatient, :float, default=0.0)
            column(:payment_rate_outpatient, :float, default=0.0)
            column(:percent_of_medicare, :float, default=1.0)
            column(:denial_rate, :float, default=0.05)
            column(:days_in_ar, :float, default=45.0)
            column(:bad_debt_rate, :float, default=0.02)
            column(:contractual_adjustment_pct, :float, default=0.40)
            column(:effective_date, :date, null=true)
            column(:created_at, :datetime)
            column(:updated_at, :datetime)
        ]
    end

    add_index(:payer_contracts, :hospital_id)
end

function down()
    drop_table(:payer_contracts)
    drop_table(:staff_positions)
    drop_table(:service_lines)
    drop_table(:departments)
end

end
