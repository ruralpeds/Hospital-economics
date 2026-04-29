"""
Stipple reactive model for Database & Queries (E19).
Simulates query results from a hospital financial/clinical data warehouse.
Returns paginated rows filtered by entity type, date range, and payer.
"""
using Stipple, StippleUI, StipplePlotly
using Statistics, Random, Printf, Dates

function _gen_records(entity::String, n::Int; seed=77)
    rng = MersenneTwister(seed)
    payers = ["Medicare","Medicaid","Blue Cross","Aetna","United","Self-Pay"]
    facilities = ["Main Campus","Rural Clinic","ED","Swing Bed Unit"]
    base_date = Date(2025,1,1)

    if entity == "patients"
        [Dict(
            "id"       => "PT-$(1000+i)",
            "date"     => string(base_date + Day(rand(rng,0:364))),
            "age"      => rand(rng,18:90),
            "payer"    => rand(rng,payers),
            "facility" => rand(rng,facilities),
            "los"      => rand(rng,1:14),
            "drg"      => rand(rng,["470","291","292","193","194","065","066"]),
        ) for i in 1:n]
    elseif entity == "claims"
        [Dict(
            "id"        => "CLM-$(5000+i)",
            "date"      => string(base_date + Day(rand(rng,0:364))),
            "amount"    => round(rand(rng,800.0:35000.0), digits=2),
            "payer"     => rand(rng,payers),
            "status"    => rand(rng,["Paid","Denied","Pending","Appealed"]),
            "procedure" => rand(rng,["99213","99214","93000","71046","80053"]),
        ) for i in 1:n]
    else  # financial
        [Dict(
            "id"         => "TXN-$(9000+i)",
            "date"       => string(base_date + Day(rand(rng,0:364))),
            "account"    => rand(rng,["4100","4200","4300","5100","5200","6100"]),
            "amount"     => round(rand(rng,-50000.0:50000.0), digits=2),
            "department" => rand(rng,["Nursing","ED","Ancillary","Admin","Pharmacy"]),
            "type"       => rand(rng,["Revenue","Expense","Adjustment"]),
        ) for i in 1:n]
    end
end

@app begin
    @in left_drawer_open::Bool = true
    @in entity_type::String = "patients"
    @in date_from::String = "2025-01-01"
    @in date_to::String = "2025-12-31"
    @in payer_filter::String = ""
    @in facility_filter::String = ""
    @in account_code::String = ""
    @in query_name::String = ""
    @in version_name::String = ""
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @out result_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out result_count::Int = 0
    @out saved_queries::Vector{Dict{String,Any}} = [
        Dict("name"=>"FY2025 Medicare IP","entity"=>"patients","rows"=>482),
        Dict("name"=>"Q4 Claims Denied","entity"=>"claims","rows"=>127),
        Dict("name"=>"Pharmacy Expense","entity"=>"financial","rows"=>2840),
    ]
    @out version_history::Vector{Dict{String,Any}} = [
        Dict("version"=>"v1.0","date"=>"2025-01-15","rows"=>350,"author"=>"Finance"),
        Dict("version"=>"v2.0","date"=>"2025-07-01","rows"=>482,"author"=>"CFO"),
    ]
    @in run_query::Bool = false
    @in save_query::Bool = false
    @in save_dataset::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange run_query begin
        run_query || return
        running = true; errors = String[]
        try
            all_rows = _gen_records(entity_type, 500)

            # Filter by payer
            filtered = isempty(payer_filter) ? all_rows :
                filter(r -> lowercase(get(r,"payer","")) == lowercase(payer_filter), all_rows)
            # Filter by facility
            filtered = isempty(facility_filter) ? filtered :
                filter(r -> contains(lowercase(get(r,"facility","")), lowercase(facility_filter)), filtered)
            # Filter by account code
            filtered = isempty(account_code) ? filtered :
                filter(r -> startswith(get(r,"account",""), account_code), filtered)

            result_count = length(filtered)
            result_rows  = filtered[1:min(100, end)]
        catch e; push!(errors, sprint(showerror,e))
        finally; running = false; end
        run_query = false
    end
end
const database_model = @init
