# health_economics/NMB.jl
# Net Monetary Benefit calculations

function calculate_nmb(effect::Float64, cost::Float64, wtp::Float64)::Float64
    (effect * wtp) - cost
end
