"""
Stipple reactive model for Advanced Analytics / ML (E20).
"""
using Stipple, StippleUI, StipplePlotly

@app begin
    @in left_drawer_open::Bool = true
    @in active_tab::String = "train"
    @in cohort_id::String = ""
    @in outcome_col::String = ""
    @in feature_cols::Vector{String} = String[]
    @in algorithm::String = "glm"
    @in train_split::Float64 = 0.8
    @in n_folds::Int = 5
    @in selected_model_id::String = ""
    @in batch_asset_id::String = ""
    # Export
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false

    @out model_metrics::Dict{String,Any} = Dict{String,Any}()
    @out roc_data::Vector{PlotData} = PlotData[]
    @out roc_layout::PlotLayout = PlotLayout()
    @out calibration_data::Vector{PlotData} = PlotData[]
    @out calibration_layout::PlotLayout = PlotLayout()
    @out prediction_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out anomaly_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out saved_models::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @in do_train::Bool = false
    @in do_predict::Bool = false
    @in do_anomaly::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange do_train begin
        do_train || return
        running = true
        errors = String[]
        try
            model_metrics = Dict{String,Any}()
            roc_data = PlotData[]
            calibration_data = PlotData[]
        catch e
            push!(errors, sprint(showerror, e))
        finally
            running = false
        end
        do_train = false
    end
end

const ml_model = @init
