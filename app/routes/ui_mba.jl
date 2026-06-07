# ═══════════════════════════════════════════════════════════════════════════
# P2 MBA Gap Views
# ═══════════════════════════════════════════════════════════════════════════

# A-08: LBO Analysis
route("/lbo") do
    include("views/lbo/LBOModel.jl")
    model = lbo_model |> init
    page(model, ui_lbo) |> html
end

# B-02: Blue Ocean Strategy
route("/blue-ocean") do
    include("views/blue_ocean/BlueOceanModel.jl")
    model = blue_ocean_model |> init
    page(model, ui_blue_ocean) |> html
end

# B-04: REH Conversion Decision
route("/reh-conversion") do
    include("views/reh_conversion/RehConversionModel.jl")
    model = reh_conversion_model |> init
    page(model, ui_reh_conversion) |> html
end

# B-05: Scenario Planning (Five Forces + 2×2 Matrix)
route("/scenario-planning") do
    include("views/scenario_planning/ScenarioPlanningModel.jl")
    model = scenario_planning_model |> init
    page(model, ui_scenario_planning) |> html
end

# C-04: Theory of Constraints / Throughput Accounting
route("/throughput") do
    include("views/throughput/ThroughputModel.jl")
    model = throughput_model |> init
    page(model, ui_throughput) |> html
end

# D-02: Readmission Risk + HRRP Impact
route("/readmission-risk") do
    include("views/readmission_risk/ReadmissionRiskModel.jl")
    model = readmission_risk_model |> init
    page(model, ui_readmission_risk) |> html
end

# D-07: Climate Risk / TCFD
route("/climate-risk") do
    include("views/climate_risk/ClimateRiskModel.jl")
    model = climate_risk_model |> init
    page(model, ui_climate_risk) |> html
end

# E-09: NSA-IDR Claim Evaluator
route("/nsa-idr") do
    include("views/nsa_idr/NsaIdrModel.jl")
    model = nsa_idr_model |> init
    page(model, ui_nsa_idr) |> html
end

# F-07: Federal Register Rate Extractor
route("/fed-register") do
    include("views/fed_register/FedRegisterModel.jl")
    model = fed_register_model |> init
    page(model, ui_fed_register) |> html
end
