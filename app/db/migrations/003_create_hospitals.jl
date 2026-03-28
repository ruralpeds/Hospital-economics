# Migration 003: Create hospitals table

module CreateHospitals

import SearchLight.Migrations:
    create_table, column, columns, pk, add_index,
    drop_table

function up()
    create_table(:hospitals) do
        [
            pk()
            column(:organization_id, :int)
            column(:name, :string; limit=255)
            column(:cms_provider_number, :string; limit=20)
            column(:npi, :string; limit=20)
            column(:hospital_type, :string; limit=20)  # cah, reh, pps
            column(:payment_designation, :string; limit=30)  # cost_based, prospective, reh

            # Bed counts
            column(:licensed_beds, :int, default=0)
            column(:staffed_beds, :int, default=0)
            column(:swing_beds, :int, default=0)
            column(:observation_beds, :int, default=0)
            column(:ed_treatment_stations, :int, default=0)

            # Utilization
            column(:average_daily_census, :float, default=0.0)
            column(:average_length_of_stay, :float, default=0.0)
            column(:case_mix_index, :float, default=1.0)
            column(:wage_index, :float, default=1.0)

            # Location
            column(:latitude, :float)
            column(:longitude, :float)
            column(:state, :string; limit=2)
            column(:county, :string; limit=100)
            column(:zip_code, :string; limit=10)
            column(:fips_code, :string; limit=10)
            column(:cbsa_code, :string; limit=10, null=true)
            column(:ruca_code, :float, default=10.0)
            column(:urban_rural, :string; limit=20, default="rural")

            # Service area demographics
            column(:primary_service_area_pop, :int, default=0)
            column(:total_service_area_pop, :int, default=0)
            column(:nearest_hospital_miles, :float, default=0.0)
            column(:nearest_tertiary_center_miles, :float, default=60.0)
            column(:competing_hospitals, :int, default=0)

            # Status flags
            column(:is_government_owned, :bool, default=false)
            column(:tax_status, :string; limit=20, default="nonprofit")
            column(:is_340b_eligible, :bool, default=false)
            column(:is_sole_community, :bool, default=false)
            column(:is_teaching, :bool, default=false)
            column(:system_affiliation, :string; limit=255, null=true)

            # CAH-specific
            column(:cah_certification_date, :date, null=true)
            column(:is_necessary_provider, :bool, default=false)

            # REH-specific
            column(:reh_conversion_date, :date, null=true)
            column(:former_designation, :string; limit=20, null=true)
            column(:monthly_facility_payment, :float, default=272866.30)
            column(:outpatient_add_on_pct, :float, default=0.05)

            column(:created_at, :datetime)
            column(:updated_at, :datetime)
        ]
    end

    add_index(:hospitals, :organization_id)
    add_index(:hospitals, :cms_provider_number; unique=true)
    add_index(:hospitals, :state)
    add_index(:hospitals, :hospital_type)
end

function down()
    drop_table(:hospitals)
end

end
