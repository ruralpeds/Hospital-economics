"""
Stipple reactive model for Descriptive & Inferential Statistics (E11).
Computes summary statistics, hypothesis tests, and Table 1 from synthetic
hospital patient cohort data (real dataset when asset_id is provided).
"""
using Stipple, StippleUI, StipplePlotly
using Statistics, Random, Printf

function _synth_cohort(n=200; seed=42)
    rng = MersenneTwister(seed)
    grp = [i <= n÷2 ? "Intervention" : "Control" for i in 1:n]
    age = Float64.([55 + round(Int, randn(rng)*12) for _ in 1:n])
    los = Float64.([max(1.0, 3.5 + randn(rng)*2 - (g=="Intervention" ? 0.5 : 0)) for g in grp])
    cost= Float64.([8500 + randn(rng)*3000 - (g=="Intervention" ? 800 : 0) for g in grp])
    readmit = [rand(rng) < (g=="Intervention" ? 0.12 : 0.18) for g in grp]
    (grp=grp, age=age, los=los, cost=cost, readmit=readmit)
end

function _desc(v, name)
    s = sort(v); n = length(v); m = mean(v); sd = std(v)
    [Dict("statistic"=>s2, "value"=>v2) for (s2,v2) in [
        ("Variable", name), ("N", n),
        ("Mean", @sprintf("%.2f",m)), ("Median", @sprintf("%.2f",median(v))),
        ("Std Dev", @sprintf("%.2f",sd)), ("Min", @sprintf("%.2f",minimum(v))),
        ("Max", @sprintf("%.2f",maximum(v))),
        ("Q1", @sprintf("%.2f",s[max(1,round(Int,0.25n))])),
        ("Q3", @sprintf("%.2f",s[min(n,round(Int,0.75n))])),
        ("Skewness", @sprintf("%.3f", n>2 ? mean((v.-m).^3)/sd^3 : 0.0)),
    ]]
end

function _normcdf(z)
    0.5 * erfc(-z / sqrt(2))
end

function _ttest(a, b)
    n1,n2 = length(a),length(b)
    m1,m2 = mean(a),mean(b)
    v1,v2 = var(a),var(b)
    se = sqrt(v1/n1 + v2/n2)
    t  = (m1-m2) / max(se, 1e-9)
    df = (v1/n1+v2/n2)^2 / ((v1/n1)^2/(n1-1) + (v2/n2)^2/(n2-1))
    # Wilson-Hilferty approximation for p-value
    z_approx = ((abs(t)/sqrt(df))^(1/3) * (1 - 1/(9df)) - (1-1/(9df))) / sqrt(1/(9df))
    p = 2 * (1 - _normcdf(z_approx))
    d = (m1-m2) / sqrt((v1+v2)/2)
    Dict("test"=>"Welch t-test", "statistic"=>round(t,digits=3),
         "df"=>round(df,digits=1), "p_value"=>round(clamp(p,0,1),digits=4),
         "effect_size"=>round(d,digits=3),
         "mean_a"=>round(m1,digits=2), "mean_b"=>round(m2,digits=2))
end

function _table1_row(var, vals_a, vals_b)
    continuous = eltype(vals_a) <: Float64
    if continuous
        r = _ttest(vals_a, vals_b)
        Dict("variable"=>var,
             "overall"=>@sprintf("%.1f \u00b1 %.1f", mean(vcat(vals_a,vals_b)), std(vcat(vals_a,vals_b))),
             "group_a"=>@sprintf("%.1f \u00b1 %.1f", mean(vals_a), std(vals_a)),
             "group_b"=>@sprintf("%.1f \u00b1 %.1f", mean(vals_b), std(vals_b)),
             "p_value"=>string(r["p_value"]))
    else
        na,nb = sum(vals_a), sum(vals_b); n = na+nb+length(vals_a)-na+length(vals_b)-nb
        Dict("variable"=>var,
             "overall"=>@sprintf("%d (%.0f%%)", na+nb, (na+nb)/(length(vals_a)+length(vals_b))*100),
             "group_a"=>@sprintf("%d (%.0f%%)", na, na/length(vals_a)*100),
             "group_b"=>@sprintf("%d (%.0f%%)", nb, nb/length(vals_b)*100),
             "p_value"=>"see chi-square")
    end
end

@app begin
    @in left_drawer_open::Bool = true
    @in asset_id::String = ""
    @in variable_col::String = "los"
    @in group_col::String = "group"
    @in outcome_col::String = "readmit"
    @in test_type::String = "ttest"
    @in confidence_level::Float64 = 0.95
    @in active_sub_tab::String = "descriptive"
    @out summary_stats::Dict{String,Any} = Dict{String,Any}()
    @out test_result::Dict{String,Any} = Dict{String,Any}()
    @out table1_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out stats_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out dist_data::Vector{PlotData} = PlotData[]
    @out dist_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Distribution"),
        xaxis=[PlotLayoutAxis(title="Value")],
        yaxis=[PlotLayoutAxis(title="Count")])
    @in run::Bool = false
    @in do_export::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange run begin
        run || return
        running = true; errors = String[]
        try
            d = _synth_cohort(200)
            cols = Dict("age"=>d.age, "los"=>d.los, "cost"=>d.cost)
            v = get(cols, variable_col, d.los)

            stats_rows = _desc(v, variable_col)

            # Histogram data
            mn,mx = minimum(v), maximum(v); nb = 20; bw = (mx-mn)/nb
            xs = [mn+(i-0.5)*bw for i in 1:nb]
            cts= Float64.([sum(x -> mn+(i-1)*bw <= x < mn+i*bw, v) for i in 1:nb])
            dist_data = [PlotData(x=xs, y=cts,
                plot=StipplePlotly.Charts.PLOT_TYPE_BAR, name=variable_col,
                marker=Dict("color"=>"#6366f1"))]
            dist_layout = PlotLayout(
                title=PlotLayoutTitle(text="Distribution of $(variable_col)"),
                xaxis=[PlotLayoutAxis(title=variable_col)],
                yaxis=[PlotLayoutAxis(title="Count")])

            # Hypothesis test
            va = v[d.grp .== "Intervention"]
            vb = v[d.grp .== "Control"]
            test_result = length(va) > 1 && length(vb) > 1 ?
                _ttest(va, vb) :
                Dict("test"=>"Insufficient data", "statistic"=>0, "p_value"=>1, "effect_size"=>0)

            # Table 1
            table1_rows = [
                _table1_row("Age (yrs, mean±SD)",
                    d.age[d.grp.=="Intervention"], d.age[d.grp.=="Control"]),
                _table1_row("LOS (days, mean±SD)",
                    d.los[d.grp.=="Intervention"], d.los[d.grp.=="Control"]),
                _table1_row("Cost/episode (\$, mean±SD)",
                    d.cost[d.grp.=="Intervention"], d.cost[d.grp.=="Control"]),
                _table1_row("Readmit 30d, n (%)",
                    Bool.(d.readmit[d.grp.=="Intervention"]),
                    Bool.(d.readmit[d.grp.=="Control"])),
            ]
        catch e; push!(errors, sprint(showerror,e))
        finally; running = false; end
        run = false
    end
end
const stats_model = @init
