# visualization/CostEffectiveness.jl
# Cost-effectiveness plane and CEAC plots

struct CEPlaneData
    cost_diff::Vector{Float64}
    effect_diff::Vector{Float64}
    willingness_to_pay::Float64
end

function cost_effectiveness_plane_plot(data::CEPlaneData)
    nothing
end

function ceac_plot(wtp::Vector{Float64}, prob_ce::Vector{Float64})
    nothing
end
