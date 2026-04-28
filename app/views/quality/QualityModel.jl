"""
Stipple reactive model for Quality & Clinical Outcomes (E10).
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in cohort_id::String = ""
    @in active_sub_tab::String = "readmissions"
    @in time_period::String = "12months"
    @in facility_id::String = ""
    @in infection_type::String = "clabsi"
    @in procedure_code::String = ""
    @in psi_measure::String = "psi_03"
    @in qol_scale::String = "eq5d"
    @in subgroup_variable::String = "race"
    @out readmission_rate::Float64 = 0.0
    @out mortality_rate::Float64 = 0.0
    @out infection_rate::Float64 = 0.0
    @out complication_rate::Float64 = 0.0
    @out qol_score::Float64 = 0.0
    @out outcome_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out km_data::Vector{PlotData} = PlotData[]
    @out km_layout::PlotLayout = PlotLayout()
    @out disparities_data::Vector{PlotData} = PlotData[]
    @out disparities_layout::PlotLayout = PlotLayout()
    @in run::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange run begin
        run || return
        running = true
        errors = String[]
        try
            readmission_rate = 0.0
            mortality_rate = 0.0
            infection_rate = 0.0
            complication_rate = 0.0
            qol_score = 0.0
            outcome_rows = Dict{String,Any}[]
            km_data = PlotData[]
            disparities_data = PlotData[]
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        run = false
    end
end

const quality_model = @init
