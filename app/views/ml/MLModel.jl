"""
Stipple reactive model for Advanced Analytics / ML (E20).
Trains a logistic regression readmission risk model, generates ROC curve,
calibration curve, and batch predictions on synthetic patient data.
"""
using Stipple, StippleUI, StipplePlotly
using Statistics, Random, Printf, LinearAlgebra

function _synth_ml_data(n=400; seed=7)
    rng = MersenneTwister(seed)
    age = 55 .+ randn(rng,n) .* 13
    ccc = max.(0.0, round.(randn(rng,n).+2))
    los = max.(1.0, 3.5 .+ 0.03.*age .+ 0.4.*ccc .+ randn(rng,n).*1.5)
    ed  = Float64.(rand(rng,n) .< 0.35)
    logit = -3.5 .+ 0.04.*age .+ 0.25.*ccc .+ 0.2.*los .+ 0.4.*ed
    prob  = 1 ./ (1 .+ exp.(-logit))
    y = Float64.(rand(rng,n) .< prob)
    (age=age, ccc=ccc, los=los, ed=ed, prob=prob, y=y, n=n)
end

function _sigmoid(x); 1/(1+exp(-x)); end
function _normcdf(z); 0.5*erfc(-z/sqrt(2)); end

function _logistic_fit(X, y; lr=0.05, iters=300)
    β = zeros(size(X,2))
    for _ in 1:iters
        p   = _sigmoid.(X*β)
        g   = X' * (p .- y) ./ length(y)
        β  .-= lr .* g
    end
    p_hat = _sigmoid.(X*β)
    (coef=β, pred=p_hat)
end

function _roc_auc(y_true, y_score)
    pairs = sort(collect(zip(y_score, y_true)), by=x->-x[1])
    tp=fp=0; auc=0.0; prev_fp=0; prev_tp=0
    for (_, label) in pairs
        label == 1 ? (tp+=1) : (fp+=1)
    end
    total_p, total_n = sum(y_true), length(y_true)-sum(y_true)
    tprs=[0.0]; fprs=[0.0]
    cur_tp=cur_fp=0
    for (_, label) in pairs
        label == 1 ? (cur_tp+=1) : (cur_fp+=1)
        push!(tprs, cur_tp/max(total_p,1))
        push!(fprs, cur_fp/max(total_n,1))
    end
    push!(tprs,1.0); push!(fprs,1.0)
    # Trapezoidal AUC
    auc = sum((fprs[i+1]-fprs[i])*(tprs[i]+tprs[i+1])/2 for i in 1:length(fprs)-1)
    (auc=auc, tprs=tprs, fprs=fprs)
end

@app begin
    @in left_drawer_open::Bool = true
    @in active_tab::String = "train"
    @in cohort_id::String = ""
    @in outcome_col::String = "readmit"
    @in feature_cols::Vector{String} = String[]
    @in algorithm::String = "glm"
    @in train_split::Float64 = 0.8
    @in n_folds::Int = 5
    @in selected_model_id::String = ""
    @in batch_asset_id::String = ""
    @in do_csv::Bool = false
    @in do_xlsx::Bool = false
    @out model_metrics::Dict{String,Any} = Dict{String,Any}()
    @out roc_data::Vector{PlotData} = PlotData[]
    @out roc_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="ROC Curve"),
        xaxis=[PlotLayoutAxis(title="False Positive Rate")],
        yaxis=[PlotLayoutAxis(title="True Positive Rate")])
    @out calibration_data::Vector{PlotData} = PlotData[]
    @out calibration_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Calibration Curve"),
        xaxis=[PlotLayoutAxis(title="Mean Predicted Probability")],
        yaxis=[PlotLayoutAxis(title="Fraction Positive")])
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
        running = true; errors = String[]
        try
            d = _synth_ml_data(400)
            n_train = round(Int, d.n * train_split)
            idx = shuffle(MersenneTwister(42), 1:d.n)
            train_idx = idx[1:n_train]; test_idx = idx[n_train+1:end]

            X = hcat(ones(d.n), d.age, d.ccc, d.los, d.ed)
            Xtrain = X[train_idx,:]; ytrain = d.y[train_idx]
            Xtest  = X[test_idx,:];  ytest  = d.y[test_idx]

            fit = _logistic_fit(Xtrain, ytrain)
            p_test = _sigmoid.(Xtest * fit.coef)

            # Metrics
            thresh = 0.5
            pred_class = Float64.(p_test .>= thresh)
            tp = sum(pred_class .== 1 .&& ytest .== 1)
            tn = sum(pred_class .== 0 .&& ytest .== 0)
            fp = sum(pred_class .== 1 .&& ytest .== 0)
            fn = sum(pred_class .== 0 .&& ytest .== 1)
            sens = tp / max(tp+fn, 1)
            spec = tn / max(tn+fp, 1)
            ppv  = tp / max(tp+fp, 1)
            npv  = tn / max(tn+fn, 1)

            roc = _roc_auc(ytest, p_test)
            brier = mean((p_test .- ytest).^2)

            model_metrics = Dict(
                "auc"=>round(roc.auc, digits=3),
                "sensitivity"=>round(sens, digits=3),
                "specificity"=>round(spec, digits=3),
                "ppv"=>round(ppv, digits=3),
                "npv"=>round(npv, digits=3),
                "brier_score"=>round(brier, digits=4),
                "n_train"=>n_train, "n_test"=>length(test_idx),
            )

            # ROC curve
            roc_data = [
                PlotData(x=roc.fprs, y=roc.tprs, plot="scatter", mode="lines",
                    name=@sprintf("ROC (AUC=%.3f)", roc.auc),
                    line=PlotDataLine(color="#6366f1", width=2)),
                PlotData(x=[0.0,1.0], y=[0.0,1.0], plot="scatter", mode="lines",
                    name="Random", line=PlotDataLine(color="#94a3b8", dash="dash")),
            ]
            roc_layout = PlotLayout(
                title=PlotLayoutTitle(text="ROC Curve"),
                xaxis=[PlotLayoutAxis(title="False Positive Rate", range=[0.0,1.0])],
                yaxis=[PlotLayoutAxis(title="True Positive Rate", range=[0.0,1.0])])

            # Calibration curve (10 bins)
            n_bins = 10
            cal_x = Float64[]; cal_y = Float64[]
            for i in 1:n_bins
                lo = (i-1)/n_bins; hi = i/n_bins
                mask = lo .<= p_test .< hi
                sum(mask) > 0 || continue
                push!(cal_x, mean(p_test[mask]))
                push!(cal_y, mean(ytest[mask]))
            end
            calibration_data = [
                PlotData(x=cal_x, y=cal_y, plot="scatter", mode="lines+markers",
                    name="Model", line=PlotDataLine(color="#22c55e")),
                PlotData(x=[0.0,1.0], y=[0.0,1.0], plot="scatter", mode="lines",
                    name="Perfect", line=PlotDataLine(color="#94a3b8", dash="dash")),
            ]
            calibration_layout = PlotLayout(
                title=PlotLayoutTitle(text="Calibration Curve"),
                xaxis=[PlotLayoutAxis(title="Mean Predicted Prob", range=[0.0,1.0])],
                yaxis=[PlotLayoutAxis(title="Fraction Positive", range=[0.0,1.0])])

            # Prediction rows (first 20 test patients)
            prediction_rows = [Dict(
                "patient_id" => "PT-$(test_idx[i])",
                "predicted_prob" => @sprintf("%.3f", p_test[i]),
                "risk_tier" => p_test[i] >= 0.3 ? "HIGH" : p_test[i] >= 0.15 ? "MOD" : "LOW",
                "actual" => Int(ytest[i]),
            ) for i in 1:min(20, length(test_idx))]

        catch e; push!(errors, sprint(showerror,e))
        finally; running = false; end
        do_train = false
    end
end
const ml_model = @init
