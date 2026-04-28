"""
Stipple reactive model for Cohort Builder (E6).
Manages inclusion/exclusion criteria, cohort preview, save/load, and stats.
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in asset_id::String = ""
    @in inclusion_age_min::Int = 0
    @in inclusion_age_max::Int = 120
    @in inclusion_dx::Vector{String} = String[]
    @in inclusion_px::Vector{String} = String[]
    @in inclusion_payers::Vector{String} = String[]
    @in inclusion_los_min::Int = 0
    @in inclusion_los_max::Int = 365
    @in inclusion_date_from::String = ""
    @in inclusion_date_to::String = ""
    @in inclusion_cost_min::Float64 = 0.0
    @in inclusion_cost_max::Float64 = 1e9
    @in exclusion_dx::Vector{String} = String[]
    @in exclusion_px::Vector{String} = String[]
    @out matching_count::Int = 0
    @out preview_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out saved_cohorts::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @in cohort_name::String = ""
    @in cohort_description::String = ""
    @in save_cohort::Bool = false
    @in load_cohort_id::String = ""
    @in delete_cohort_id::String = ""
    @out cohort_stats::Dict{String,Any} = Dict{String,Any}()
    @in run_preview::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange run_preview begin
        run_preview || return
        running = true
        errors = String[]
        try
            matching_count = 0
            preview_rows = Dict{String,Any}[]
            cohort_stats = Dict{String,Any}(
                "age_min" => inclusion_age_min,
                "age_max" => inclusion_age_max,
                "los_min" => inclusion_los_min,
                "los_max" => inclusion_los_max,
            )
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        run_preview = false
    end

    @onchange save_cohort begin
        save_cohort || return
        running = true
        errors = String[]
        try
            if !isempty(cohort_name)
                new_cohort = Dict{String,Any}(
                    "id" => string(rand(UInt32), base=16),
                    "name" => cohort_name,
                    "description" => cohort_description,
                    "count" => matching_count,
                )
                push!(saved_cohorts, new_cohort)
            end
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        save_cohort = false
    end
end

const cohorts_model = @init
