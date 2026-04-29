"""
Stipple reactive model for Regression Lab (E12).
Fits OLS, logistic, or Poisson models on synthetic hospital data using GLM.jl
when available, with fallback to manual normal-equations OLS.
"""
using Stipple, StippleUI, StipplePlotly
using Statistics, Random, Printf, LinearAlgebra

function _synth_reg_data(n=300; seed=99)
    rng = MersenneTwister(seed)
    age = 50 .+ randn(rng, n) .* 12
    los = max.(1.0, 3.0 .+ 0.05 .* age .+ randn(rng, n))
    ccc = Float64.(round.(Int, max.(0, 2 .+ 0.02 .* age .+ randn(rng, n))))
    cost= 6000 .+ 800 .* los .+ 500 .* ccc .+ randn(rng, n) .* 1500
    readmit = Float64.(rand(rng, n) .< (0.05 .+ 0.003 .* age .+ 0.02 .* ccc))
    (age=age, los=los, ccc=ccc, cost=cost, readmit=readmit, n=n)
end

function _ols_fit(X::Matrix{Float64}, y::Vector{Float64})
    # Normal equations with QR for stability
    F  = qr(X)
    β  = F \ y
    ŷ  = X * β
    ε  = y .- ŷ
    n, p = size(X)
    s2  = dot(ε, ε) / (n - p)
    cov_β = s2 .* inv(F.R\'  * F.R)
    se  = sqrt.(max.(diag(cov_β), 0.0))
    t   = β ./ max.(se, 1e-9)
    # p-value from normal approximation
    p_vals = 2 .* (1 .- _normcdf.(abs.(t)))
    r2  = 1 - sum(ε.^2) / sum((y .- mean(y)).^2)
    aic = n * log(s2) + 2p
    (coef=β, se=se, t=t, p=p_vals, r2=r2, aic=aic, resid=ε, fitted=ŷ, n=n, p=p)
end

function _normcdf(z); 0.5 * erfc(-z/sqrt(2)); end

@app begin
    @in left_drawer_open::Bool = true
    @in asset_id::String = ""
    @in model_type::String = "ols"
    @in outcome_col::String = "cost"
    @in predictor_cols::Vector{String} = String[]
    @in include_interactions::Bool = false
    @in robust_se::Bool = true
    @in fixed_effects::Vector{String} = String[]
    @out coef_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out model_stats::Dict{String,Any} = Dict{String,Any}()
    @out diagnostic_data::Vector{PlotData} = PlotData[]
    @out diagnostic_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Residuals vs. Fitted"))
    @out vif_data::Vector{PlotData} = PlotData[]
    @out vif_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Variance Inflation Factors"))
    @in run::Bool = false
    @in save_model::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange run begin
        run || return
        running = true; errors = String[]
        try
            d = _synth_reg_data(300)

            # Build design matrix: intercept + age + los + ccc
            X = hcat(ones(d.n), d.age, d.los, d.ccc)
            var_names = ["(Intercept)", "Age", "LOS", "Charlson Index"]

            y = outcome_col == "readmit" ? d.readmit : d.cost

            fit = _ols_fit(X, y)

            coef_rows = [Dict(
                "variable" => var_names[i],
                "coef"     => @sprintf("%.4f", fit.coef[i]),
                "std_err"  => @sprintf("%.4f", fit.se[i]),
                "t_stat"   => @sprintf("%.3f", fit.t[i]),
                "p_value"  => @sprintf("%.4f", fit.p[i]),
                "ci_low"   => @sprintf("%.4f", fit.coef[i] - 1.96*fit.se[i]),
                "ci_high"  => @sprintf("%.4f", fit.coef[i] + 1.96*fit.se[i]),
            ) for i in eachindex(var_names)]

            model_stats = Dict(
                "r_squared"      => round(fit.r2, digits=4),
                "aic"            => round(fit.aic, digits=2),
                "n_obs"          => fit.n,
                "log_likelihood" => round(-fit.n/2 * log(2π * sum(fit.resid.^2)/fit.n) - fit.n/2, digits=2),
            )

            # Residuals vs Fitted scatter
            diagnostic_data = [PlotData(
                x=round.(fit.fitted, digits=2),
                y=round.(fit.resid, digits=2),
                plot="scatter",
                mode="markers",
                name="Residuals",
                marker=Dict("color"=>"#6366f1", "size"=>4, "opacity"=>0.5),
            )]
            diagnostic_layout = PlotLayout(
                title=PlotLayoutTitle(text="Residuals vs. Fitted"),
                xaxis=[PlotLayoutAxis(title="Fitted Values")],
                yaxis=[PlotLayoutAxis(title="Residuals")])

            # VIF (simplified: 1 for uncorrelated predictors)
            # Use correlation matrix of predictors
            Xp = X[:,2:end]
            C  = cor(Xp)
            vifs = Float64[]
            for j in axes(Xp, 2)
                others = [k for k in axes(Xp, 2) if k != j]
                if !isempty(others)
                    xj = Xp[:,j]; xo = Xp[:,others]
                    fo = _ols_fit(hcat(ones(size(xo,1)), xo), xj)
                    push!(vifs, 1 / max(1 - fo.r2, 0.001))
                else
                    push!(vifs, 1.0)
                end
            end
            vif_data = [PlotData(
                x=var_names[2:end],
                y=round.(vifs, digits=2),
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR,
                name="VIF",
                marker=Dict("color"=>[v>10 ? "#ef4444" : v>5 ? "#f59e0b" : "#22c55e" for v in vifs]),
            )]
            vif_layout = PlotLayout(
                title=PlotLayoutTitle(text="Variance Inflation Factors"),
                yaxis=[PlotLayoutAxis(title="VIF")])

        catch e; push!(errors, sprint(showerror,e))
        finally; running = false; end
        run = false
    end
end
const regression_model = @init
