"""
Stipple reactive model for Network & Systems (E21).
Generates referral network graph, Sankey patient flow, and care coordination
gap analysis from synthetic hospital network data.
"""
using Stipple, StippleUI, StipplePlotly
using Statistics, Random, Printf

function _synth_referral_network(; seed=55)
    rng = MersenneTwister(seed)
    nodes = ["Valley CAH","Regional Medical","Cardiology Clinic","Ortho Clinic",
             "Oncology Centre","Mental Health","Home Health","SNF"]
    n = length(nodes)
    # Edge weights (referral volume)
    edges = Tuple{Int,Int,Int}[]
    for i in 1:n, j in 1:n
        i == j && continue
        vol = rand(rng,0:120)
        vol > 20 && push!(edges, (i,j,vol))
    end
    (nodes=nodes, edges=edges)
end

function _sankey_data(nodes, edges)
    # Convert to Plotly Sankey format
    labels = nodes
    srcs   = [e[1]-1 for e in edges]
    tgts   = [e[2]-1 for e in edges]
    vals   = [e[3]   for e in edges]
    [PlotData(
        plot="sankey",
        var"node"=Dict("label"=>labels, "pad"=>15, "thickness"=>20,
                        "color"=>["#6366f1","#3b82f6","#22c55e","#f59e0b",
                                  "#ef4444","#8b5cf6","#06b6d4","#84cc16"][1:length(labels)]),
        link=Dict("source"=>srcs, "target"=>tgts, "value"=>vals),
    )]
end

function _gap_analysis()
    [
        Dict("care_gap"=>"Diabetic A1c Monitoring", "patients_due"=>87, "overdue"=>34,
             "responsible"=>"Primary Care", "days_avg_overdue"=>42),
        Dict("care_gap"=>"Annual Wellness Visit", "patients_due"=>312, "overdue"=>128,
             "responsible"=>"PCP / RHC", "days_avg_overdue"=>67),
        Dict("care_gap"=>"CHF Follow-up (7d post-discharge)", "patients_due"=>23, "overdue"=>8,
             "responsible"=>"Hospitalist", "days_avg_overdue"=>4),
        Dict("care_gap"=>"Colorectal Cancer Screening", "patients_due"=>156, "overdue"=>89,
             "responsible"=>"PCP", "days_avg_overdue"=>180),
        Dict("care_gap"=>"Hypertension BP Control", "patients_due"=>204, "overdue"=>71,
             "responsible"=>"Primary Care / RHC", "days_avg_overdue"=>90),
    ]
end

@app begin
    @in left_drawer_open::Bool = true
    @in referral_asset_id::String = ""
    @in patient_pathway_id::String = ""
    @in encounters_asset_id::String = ""
    @in starting_condition::String = "chest_pain"
    @in rng_seed::Int = 42
    @in active_tab::String = "network"
    @out network_data::Vector{PlotData} = PlotData[]
    @out network_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Referral Network"))
    @out sankey_data::Vector{PlotData} = PlotData[]
    @out sankey_layout::PlotLayout = PlotLayout(
        title=PlotLayoutTitle(text="Patient Flow (Sankey)"))
    @out pathway_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @out gap_rows::Vector{Dict{String,Any}} = _gap_analysis()
    @out team_rows::Vector{Dict{String,Any}} = Dict{String,Any}[]
    @in do_network::Bool = false
    @in do_pathway::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange do_network begin
        do_network || return
        running = true; errors = String[]
        try
            net = _synth_referral_network(seed=rng_seed)

            # Build scatter network plot (node positions)
            n = length(net.nodes)
            angles = [2π*i/n for i in 0:n-1]
            nx = cos.(angles); ny = sin.(angles)

            # Edge traces
            edge_x = Float64[]; edge_y = Float64[]
            for (i,j,_) in net.edges
                push!(edge_x, nx[i], nx[j], NaN)
                push!(edge_y, ny[i], ny[j], NaN)
            end

            network_data = [
                PlotData(x=edge_x, y=edge_y, plot="scatter", mode="lines",
                    line=PlotDataLine(color="#cbd5e1", width=1), showlegend=false),
                PlotData(x=nx, y=ny, plot="scatter", mode="markers+text",
                    text=net.nodes, textposition="bottom center",
                    marker=Dict("size"=>20, "color"=>"#6366f1"),
                    name="Facilities"),
            ]
            network_layout = PlotLayout(
                title=PlotLayoutTitle(text="Referral Network"),
                showlegend=false,
                xaxis=[PlotLayoutAxis(showgrid=false, zeroline=false, showticklabels=false)],
                yaxis=[PlotLayoutAxis(showgrid=false, zeroline=false, showticklabels=false)])

            sankey_data   = _sankey_data(net.nodes, net.edges)
            sankey_layout = PlotLayout(title=PlotLayoutTitle(text="Patient Flow (Sankey)"))

            gap_rows = _gap_analysis()

        catch e; push!(errors, sprint(showerror,e))
        finally; running = false; end
        do_network = false
    end
end
const systems_model = @init
