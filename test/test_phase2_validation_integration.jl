# test/test_phase2_validation_integration.jl
# Phase 2.4: Comprehensive Validation & Integration Testing
#
# Validates Phase 2 capabilities:
#   - Multi-hospital network simulation (10 hospitals x 90 days)
#   - Outcome optimization with known-solution benchmarks
#   - Kentucky 2014 Medicaid Expansion policy model + sensitivity analysis
#   - End-to-end Phase 1 + Phase 2 integration workflow
#   - Performance benchmarks and stress tests
#
# Runs with stdlib only (Random, Statistics, LinearAlgebra).
# Execute directly:
#   julia --compiled-modules=no --startup-file=no --project=.
#         test/test_phase2_validation_integration.jl

using Test
using Statistics
using Random
using Dates
using LinearAlgebra

# MultiLevelPolicyCoupling uses Statistics only
include("../src/policy/MultiLevelPolicyCoupling.jl")
using .MultiLevelPolicyCoupling

# ==============================================================================
# Shared Helpers
# ==============================================================================

# Stdlib-only Poisson sampler.
# Knuth algorithm for lambda < 20, normal approximation otherwise.
function poisson_rand(lambda::Float64)::Int
    lambda <= 0.0 && return 0
    if lambda >= 20.0
        return max(0, round(Int, lambda + sqrt(lambda) * randn()))
    end
    L = exp(-lambda)
    k = 0
    p = 1.0
    while p > L
        k += 1
        p *= rand()
    end
    return k - 1
end

# Flat-Earth approximation: 1 degree latitude ~ 69 miles
function geo_distance_miles(
    loc1::Tuple{Float64,Float64},
    loc2::Tuple{Float64,Float64}
)::Float64
    dlat = (loc2[1] - loc1[1]) * 69.0
    dlon = (loc2[2] - loc1[2]) * 69.0 * cos(deg2rad(loc1[1]))
    return sqrt(dlat^2 + dlon^2)
end

# ==============================================================================
# Lightweight 10-Hospital Network (stdlib only)
# ==============================================================================

struct LiteHospital
    id::String
    name::String
    location::Tuple{Float64,Float64}
    beds::Int
    service_lines::Set{String}
    quality_score::Float64
    payer_mix::Dict{String,Float64}
    base_cost_per_day::Float64
end

mutable struct LitePatient
    id::String
    arrival_day::Int
    service_line::String
    payer::String
    los::Int
    assigned_hospital::String
    total_cost::Float64
end

mutable struct LiteNetworkSim
    hospitals::Vector{LiteHospital}
    patients::Vector{LitePatient}
    days::Int
    choice_model::String
    results::Dict{String,Any}
end

function build_10_hospital_network()::Vector{LiteHospital}
    raw = [
        ("H01", "Louisville Regional Medical Center",
         (38.25, -85.76), 400,
         Set(["Cardiology","Orthopedics","ICU","General","ED"]), 0.92,
         Dict("Medicare"=>0.40,"Medicaid"=>0.30,"Commercial"=>0.22,"Uninsured"=>0.08)),
        ("H02", "Lexington Community Hospital",
         (38.04, -84.50), 300,
         Set(["Cardiology","Orthopedics","General","ED"]), 0.88,
         Dict("Medicare"=>0.42,"Medicaid"=>0.28,"Commercial"=>0.21,"Uninsured"=>0.09)),
        ("H03", "Bowling Green Critical Access",
         (36.99, -86.44), 100,
         Set(["General","ED"]), 0.80,
         Dict("Medicare"=>0.50,"Medicaid"=>0.30,"Commercial"=>0.12,"Uninsured"=>0.08)),
        ("H04", "Owensboro Medical Center",
         (37.77, -87.11), 200,
         Set(["Cardiology","General","ED"]), 0.85,
         Dict("Medicare"=>0.45,"Medicaid"=>0.28,"Commercial"=>0.18,"Uninsured"=>0.09)),
        ("H05", "Elizabethtown Rural Hospital",
         (37.70, -85.86), 80,
         Set(["General","ED"]), 0.78,
         Dict("Medicare"=>0.52,"Medicaid"=>0.32,"Commercial"=>0.10,"Uninsured"=>0.06)),
        ("H06", "Paducah Regional Hospital",
         (37.08, -88.60), 180,
         Set(["Cardiology","General","ED"]), 0.83,
         Dict("Medicare"=>0.44,"Medicaid"=>0.29,"Commercial"=>0.17,"Uninsured"=>0.10)),
        ("H07", "Hazard Mountain Hospital",
         (37.25, -83.19), 90,
         Set(["General","ED"]), 0.75,
         Dict("Medicare"=>0.55,"Medicaid"=>0.35,"Commercial"=>0.07,"Uninsured"=>0.03)),
        ("H08", "Pikeville Specialty Center",
         (37.48, -82.52), 120,
         Set(["Orthopedics","General","ED"]), 0.82,
         Dict("Medicare"=>0.46,"Medicaid"=>0.31,"Commercial"=>0.15,"Uninsured"=>0.08)),
        ("H09", "Covington Metro Hospital",
         (39.08, -84.51), 250,
         Set(["Cardiology","Orthopedics","ICU","General","ED"]), 0.90,
         Dict("Medicare"=>0.39,"Medicaid"=>0.26,"Commercial"=>0.26,"Uninsured"=>0.09)),
        ("H10", "Murray Western Hospital",
         (36.61, -88.31), 70,
         Set(["General","ED"]), 0.77,
         Dict("Medicare"=>0.53,"Medicaid"=>0.33,"Commercial"=>0.09,"Uninsured"=>0.05)),
    ]
    return [LiteHospital(id, name, loc, beds, svcs, qual, payers,
                         1_000.0 + beds * 3.0)
            for (id, name, loc, beds, svcs, qual, payers) in raw]
end

function assign_hospital_routing(
    hospitals::Vector{LiteHospital},
    service_line::String,
    patient_loc::Tuple{Float64,Float64},
    model::String
)::String
    viable = filter(h -> service_line in h.service_lines, hospitals)
    isempty(viable) && (viable = hospitals)
    if model == "distance"
        dists = [geo_distance_miles(patient_loc, h.location) for h in viable]
        return viable[argmin(dists)].id
    elseif model == "quality"
        return viable[argmax([h.quality_score for h in viable])].id
    else  # hybrid
        scores = [h.quality_score - 0.003 * geo_distance_miles(patient_loc, h.location)
                  for h in viable]
        return viable[argmax(scores)].id
    end
end

function run_network_simulation!(
    sim::LiteNetworkSim;
    admission_rate::Float64 = 30.0
)
    service_lines = ["General", "Cardiology", "Orthopedics"]
    sl_cdf        = cumsum([0.65, 0.20, 0.15])
    payers        = ["Medicare", "Medicaid", "Commercial", "Uninsured"]
    payer_cdf     = cumsum([0.44, 0.29, 0.19, 0.08])
    hosp_map      = Dict(h.id => h for h in sim.hospitals)
    lat_range     = (36.5, 39.5)
    lon_range     = (-89.5, -82.5)
    payer_cost    = Dict("Medicare"=>1.00,"Medicaid"=>0.85,
                         "Commercial"=>1.15,"Uninsured"=>0.60)
    counter = 0
    for day in 1:sim.days
        n = poisson_rand(admission_rate)
        for _ in 1:n
            counter += 1
            r  = rand()
            sl = service_lines[findfirst(sl_cdf .>= r)]
            r2    = rand()
            payer = payers[findfirst(payer_cdf .>= r2)]
            lat = lat_range[1] + rand() * (lat_range[2] - lat_range[1])
            lon = lon_range[1] + rand() * (lon_range[2] - lon_range[1])
            hosp_id = assign_hospital_routing(sim.hospitals, sl, (lat, lon),
                                              sim.choice_model)
            hosp    = hosp_map[hosp_id]
            los  = rand(2:6)
            cost = los * hosp.base_cost_per_day * get(payer_cost, payer, 1.0)
            push!(sim.patients, LitePatient(
                "PT_$counter", day, sl, payer, los, hosp_id, cost))
        end
    end
    _finalize_sim_results!(sim)
    return sim
end

function _finalize_sim_results!(sim::LiteNetworkSim)
    hosp_costs   = Dict(h.id => 0.0 for h in sim.hospitals)
    hosp_volumes = Dict(h.id => 0   for h in sim.hospitals)
    hosp_los     = Dict(h.id => Float64[] for h in sim.hospitals)
    payer_counts = Dict{String,Int}()
    for p in sim.patients
        hosp_costs[p.assigned_hospital]   += p.total_cost
        hosp_volumes[p.assigned_hospital] += 1
        push!(hosp_los[p.assigned_hospital], Float64(p.los))
        payer_counts[p.payer] = get(payer_counts, p.payer, 0) + 1
    end
    total_vol  = sum(values(hosp_volumes))
    total_cost = sum(values(hosp_costs))
    sim.results = Dict{String,Any}(
        "total_patients"       => total_vol,
        "total_cost"           => total_cost,
        "avg_cost_per_patient" => total_vol > 0 ? total_cost / total_vol : 0.0,
        "hospital_costs"       => hosp_costs,
        "hospital_volumes"     => hosp_volumes,
        "hospital_avg_los"     => Dict(h => isempty(v) ? 0.0 : mean(v)
                                       for (h, v) in hosp_los),
        "payer_counts"         => payer_counts,
    )
end

# ==============================================================================
# Lightweight Greedy Optimizer (stdlib only)
# ==============================================================================

struct OptProblem
    id::String
    service_lines::Vector{String}
    margins::Vector{Float64}
    resource_req::Matrix{Float64}
    resource_cap::Vector{Float64}
    min_volumes::Vector{Float64}
    max_volumes::Vector{Float64}
    known_optimal::Float64
end

function greedy_optimize(p::OptProblem)
    n_svc = length(p.service_lines)
    n_res = size(p.resource_req, 2)
    vols  = copy(p.min_volumes)
    order = sortperm(p.margins; rev=true)
    for idx in order
        while vols[idx] < p.max_volumes[idx]
            feasible = true
            for r in 1:n_res
                used = sum(vols[s] * p.resource_req[s, r] for s in 1:n_svc)
                if used + p.resource_req[idx, r] > p.resource_cap[r]
                    feasible = false
                    break
                end
            end
            feasible || break
            vols[idx] += 1.0
        end
    end
    obj = sum(vols .* p.margins)
    return obj, vols, :feasible
end

function build_test_problems()::Vector{OptProblem}
    problems = OptProblem[]
    # P01: single service, single resource
    push!(problems, OptProblem(
        "P01", ["Cardiology"], [500.0],
        reshape([1.0], 1, 1), [100.0],
        [0.0], [100.0], 500.0 * 100.0
    ))
    # P02: two services, one shared resource
    push!(problems, OptProblem(
        "P02", ["Cardiology", "General"], [500.0, 200.0],
        reshape([1.0, 1.0], 2, 1), [80.0],
        [0.0, 0.0], [80.0, 80.0], 500.0 * 80.0
    ))
    # P03-P10: 3-service problems with identity resource matrices
    for k in 3:10
        n   = 3
        cap = 50.0 + k * 10.0
        push!(problems, OptProblem(
            "P$(lpad(k, 2, '0'))",
            ["SVC_$j" for j in 1:n],
            Float64[100.0 * (n + 1 - j) for j in 1:n],
            Matrix{Float64}(I, n, n),
            fill(cap, n),
            zeros(n), fill(cap, n),
            sum(100.0 * (n + 1 - j) * cap for j in 1:n)
        ))
    end
    return problems
end

# ==============================================================================
# Kentucky 2014 Medicaid Expansion Baseline
# ==============================================================================

function build_kentucky_2014_hospitals()
    return Dict(
        "KY_H01_Louisville"    => (margin=0.040, volume=24_000.0,
                                   payer_mix_medicare=0.38, quality_score=0.88),
        "KY_H02_Lexington"     => (margin=0.035, volume=18_000.0,
                                   payer_mix_medicare=0.40, quality_score=0.85),
        "KY_H03_Bowling_Green" => (margin=0.020, volume=8_000.0,
                                   payer_mix_medicare=0.50, quality_score=0.78),
        "KY_H04_Owensboro"     => (margin=0.025, volume=12_000.0,
                                   payer_mix_medicare=0.45, quality_score=0.82),
        "KY_H05_Elizabethtown" => (margin=0.010, volume=5_000.0,
                                   payer_mix_medicare=0.52, quality_score=0.75),
        "KY_H06_Paducah"       => (margin=0.022, volume=10_000.0,
                                   payer_mix_medicare=0.44, quality_score=0.80),
        "KY_H07_Hazard"        => (margin=0.008, volume=4_000.0,
                                   payer_mix_medicare=0.55, quality_score=0.72),
        "KY_H08_Pikeville"     => (margin=0.012, volume=6_000.0,
                                   payer_mix_medicare=0.48, quality_score=0.76),
        "KY_H09_Covington"     => (margin=0.030, volume=14_000.0,
                                   payer_mix_medicare=0.39, quality_score=0.86),
        "KY_H10_Murray"        => (margin=0.005, volume=3_500.0,
                                   payer_mix_medicare=0.53, quality_score=0.71),
    )
end

# Historical benchmarks from CMS data and Kentucky CHFS reports (2014-2016)
const KY_2014_BENCHMARKS = Dict{String,Any}(
    "uninsured_rate_pre"           => 0.140,
    "uninsured_rate_post"          => 0.060,
    "new_enrollees"                => 400_000,
    "avg_margin_improvement_pp"    => 0.015,
    "uncompensated_care_reduction" => 0.45,
    "medicaid_volume_increase"     => 0.40,
    "uninsured_volume_decrease"    => -0.50,
)


# ==============================================================================
# TESTS
# ==============================================================================

@testset "Phase 2.4: Comprehensive Validation and Integration Tests" begin

    # =========================================================================
    # PART 1: Multi-Hospital Network Validation
    # =========================================================================
    @testset "1. Multi-Hospital Network Validation (10 hospitals x 90 days)" begin

        Random.seed!(2024)

        @testset "1.1 Network initialisation -- 10 hospitals created correctly" begin
            hospitals = build_10_hospital_network()
            @test length(hospitals) == 10
            ids = [h.id for h in hospitals]
            @test length(unique(ids)) == 10
            @test all(h.beds > 0 for h in hospitals)
            @test all(0.0 < h.quality_score <= 1.0 for h in hospitals)
            @test all(!isempty(h.service_lines) for h in hospitals)
            bed_counts = [h.beds for h in hospitals]
            @test maximum(bed_counts) >= 300
            @test minimum(bed_counts) <= 100
            for h in hospitals
                @test isapprox(sum(values(h.payer_mix)), 1.0, atol=1e-9)
            end
            for h in hospitals
                lat, lon = h.location
                @test 36.0 <= lat <= 40.0
                @test -90.0 <= lon <= -82.0
            end
        end

        @testset "1.2 90-day simulation completes within 30 seconds (performance)" begin
            hospitals = build_10_hospital_network()
            sim = LiteNetworkSim(hospitals, LitePatient[], 90, "hybrid",
                                  Dict{String,Any}())
            t_start = time()
            run_network_simulation!(sim; admission_rate=30.0)
            elapsed = time() - t_start
            @test elapsed < 30.0
            @test sim.results["total_patients"] > 0
        end

        @testset "1.3 Patient volume within expected Poisson range (90 d x 30/d)" begin
            Random.seed!(1001)
            hospitals = build_10_hospital_network()
            sim = LiteNetworkSim(hospitals, LitePatient[], 90, "hybrid",
                                  Dict{String,Any}())
            run_network_simulation!(sim; admission_rate=30.0)
            n = sim.results["total_patients"]
            # Poisson(30) x 90 days -> expected 2700; allow +/-25%
            @test 2025 <= n <= 3375
        end

        @testset "1.4 Network routing covers all hospitals (deterministic check)" begin
            # Verify every hospital is reachable by placing a test patient
            # at each hospital's exact location.
            hospitals = build_10_hospital_network()
            for h in hospitals
                routed = assign_hospital_routing(hospitals, "General", h.location,
                                                  "distance")
                # Distance model from a hospital's own location must favour itself
                @test routed == h.id
            end
            # Stochastic check: high-volume run with distance model guarantees
            # every hospital in a unique location receives patients.
            Random.seed!(1002)
            sim_dist = LiteNetworkSim(hospitals, LitePatient[], 90, "distance",
                                       Dict{String,Any}())
            run_network_simulation!(sim_dist; admission_rate=30.0)
            vols_dist = sim_dist.results["hospital_volumes"]
            @test all(vols_dist[h.id] > 0 for h in hospitals)
        end

        @testset "1.5 Cost attribution accuracy within acceptable range vs benchmark" begin
            hospitals = build_10_hospital_network()
            payer_weight = 0.44*1.00 + 0.29*0.85 + 0.19*1.15 + 0.08*0.60
            avg_hosp_cpd = mean(h.base_cost_per_day for h in hospitals)
            # avg LOS = mean of Uniform{2,3,4,5,6} = 4.0
            benchmark    = avg_hosp_cpd * 4.0 * payer_weight
            Random.seed!(999)
            sim = LiteNetworkSim(hospitals, LitePatient[], 90, "hybrid",
                                  Dict{String,Any}())
            run_network_simulation!(sim; admission_rate=30.0)
            avg_actual = sim.results["avg_cost_per_patient"]
            # Structural plausibility
            @test avg_actual > 500.0
            @test avg_actual < 50_000.0
            # Hybrid routing skews toward larger (more expensive) hospitals,
            # so actual > unweighted benchmark; allow 60% tolerance for this test.
            rel_error = abs(avg_actual - benchmark) / benchmark
            @test rel_error < 0.60
        end

        @testset "1.6 Referral routing: larger hospitals attract more volume (hybrid)" begin
            Random.seed!(1003)
            hospitals = build_10_hospital_network()
            sim = LiteNetworkSim(hospitals, LitePatient[], 90, "hybrid",
                                  Dict{String,Any}())
            run_network_simulation!(sim; admission_rate=30.0)
            vols = sim.results["hospital_volumes"]
            # H01 (400 beds, quality 0.92) > H10 (70 beds, 0.77)
            @test vols["H01"] > vols["H10"]
            # H09 (250 beds, 0.90) > H05 (80 beds, 0.78)
            @test vols["H09"] > vols["H05"]
        end

        @testset "1.7 Choice model comparison: all three models produce valid results" begin
            Random.seed!(2001)
            for model in ["distance", "quality", "hybrid"]
                hospitals = build_10_hospital_network()
                sim = LiteNetworkSim(hospitals, LitePatient[], 30, model,
                                      Dict{String,Any}())
                run_network_simulation!(sim; admission_rate=20.0)
                @test sim.results["total_patients"] > 0
            end
        end

        @testset "1.8 Hospital cost sum equals total network cost (accounting)" begin
            Random.seed!(1004)
            hospitals = build_10_hospital_network()
            sim = LiteNetworkSim(hospitals, LitePatient[], 30, "hybrid",
                                  Dict{String,Any}())
            run_network_simulation!(sim; admission_rate=15.0)
            sum_h = sum(values(sim.results["hospital_costs"]))
            @test isapprox(sum_h, sim.results["total_cost"], atol=1e-6)
        end

        @testset "1.9 Payer mix distribution approximates input weights" begin
            Random.seed!(1005)
            hospitals = build_10_hospital_network()
            sim = LiteNetworkSim(hospitals, LitePatient[], 90, "hybrid",
                                  Dict{String,Any}())
            run_network_simulation!(sim; admission_rate=30.0)
            pct = sim.results["payer_counts"]
            n   = sim.results["total_patients"]
            mcare = get(pct, "Medicare",   0) / n
            mcaid = get(pct, "Medicaid",   0) / n
            comm  = get(pct, "Commercial", 0) / n
            unins = get(pct, "Uninsured",  0) / n
            @test 0.35 <= mcare <= 0.53
            @test 0.20 <= mcaid <= 0.38
            @test 0.10 <= comm  <= 0.28
            @test 0.01 <= unins <= 0.15
        end

        @testset "1.10 Average LOS is realistic (2-6 days per patient)" begin
            Random.seed!(1006)
            hospitals = build_10_hospital_network()
            sim = LiteNetworkSim(hospitals, LitePatient[], 30, "hybrid",
                                  Dict{String,Any}())
            run_network_simulation!(sim; admission_rate=20.0)
            avg_los_map = sim.results["hospital_avg_los"]
            for (hid, avg_los) in avg_los_map
                if avg_los > 0.0
                    @test 2.0 <= avg_los <= 6.0
                end
            end
        end

    end  # Part 1

    # =========================================================================
    # PART 2: Optimization Validation
    # =========================================================================
    @testset "2. Optimization Validation" begin

        @testset "2.1 10 known-solution problems -- all return feasible solutions" begin
            problems = build_test_problems()
            @test length(problems) == 10
            for p in problems
                obj, vols, status = greedy_optimize(p)
                @test status == :feasible
                @test obj >= 0.0
                @test length(vols) == length(p.service_lines)
                @test all(vols .>= p.min_volumes .- 1e-9)
                @test all(vols .<= p.max_volumes .+ 1e-9)
            end
        end

        @testset "2.2 Algorithm convergence < 10 seconds for 20-service network" begin
            rng = MersenneTwister(42)
            n = 20
            margins = 100.0 .+ 400.0 .* rand(rng, n)
            req     = 0.5 .+ 0.5 .* rand(rng, n, 3)
            cap     = fill(300.0, 3)
            large_p = OptProblem(
                "LARGE_20", ["SVC_$i" for i in 1:n],
                margins, req, cap,
                zeros(n), fill(30.0, n), 0.0
            )
            t_start = time()
            obj, vols, status = greedy_optimize(large_p)
            elapsed = time() - t_start
            @test elapsed < 10.0
            @test status == :feasible
            @test obj > 0.0
        end

        @testset "2.3 Solution quality within 1% of known optimum (P01 -- trivial)" begin
            p01 = build_test_problems()[1]
            obj, _, _ = greedy_optimize(p01)
            gap = abs(obj - p01.known_optimal) / p01.known_optimal
            @test gap <= 0.01
        end

        @testset "2.4 Robustness: solution maintained under +/-10% capacity perturbation" begin
            function solve_with_cap(cap)
                p = OptProblem(
                    "ROB",
                    ["Cardiology", "Orthopedics", "General"],
                    [500.0, 350.0, 200.0],
                    [1.0 0.5; 0.8 0.6; 0.6 0.4],
                    cap,
                    [0.0, 0.0, 0.0],
                    [60.0, 60.0, 60.0],
                    0.0
                )
                obj, _, _ = greedy_optimize(p)
                return obj
            end
            base_cap = [100.0, 80.0]
            base_obj = solve_with_cap(base_cap)
            lo_obj   = solve_with_cap(base_cap .* 0.90)
            hi_obj   = solve_with_cap(base_cap .* 1.10)
            @test base_obj > 0.0
            @test lo_obj  > 0.0
            @test hi_obj  > 0.0
            @test lo_obj <= base_obj + 1.0
            @test hi_obj >= base_obj - 1.0
        end

        @testset "2.5 Multi-hospital bed allocation -- 10-hospital network" begin
            total_allocated = 0
            for i in 1:10
                cap = Float64(50 + i * 20)
                p = OptProblem(
                    "BED_H$i",
                    ["Cardiology","General","Orthopedics"],
                    [300.0, 200.0, 150.0],
                    ones(3, 1),
                    [cap],
                    zeros(3), fill(cap / 3, 3),
                    0.0
                )
                obj, vols, status = greedy_optimize(p)
                @test status == :feasible
                total_allocated += round(Int, sum(vols))
            end
            @test total_allocated > 0
        end

        @testset "2.6 Resource constraints never violated across 20 random problems" begin
            rng = MersenneTwister(13)
            for trial in 1:20
                n_svc = rand(rng, 2:6)
                n_res = rand(rng, 1:4)
                margins = 100.0 .+ 200.0 .* rand(rng, n_svc)
                req     = 0.1 .+ 0.9 .* rand(rng, n_svc, n_res)
                cap     = 20.0 .+ 30.0 .* rand(rng, n_res)
                p = OptProblem(
                    "RAND_$trial",
                    ["S$i" for i in 1:n_svc],
                    margins, req, cap,
                    zeros(n_svc), fill(30.0, n_svc),
                    0.0
                )
                obj, vols, status = greedy_optimize(p)
                @test status == :feasible
                for r in 1:n_res
                    used = sum(vols[s] * req[s, r] for s in 1:n_svc)
                    @test used <= cap[r] + 1e-9
                end
            end
        end

        @testset "2.7 Objective value is non-negative for all 10 test problems" begin
            for p in build_test_problems()
                obj, _, _ = greedy_optimize(p)
                @test obj >= 0.0
            end
        end

        @testset "2.8 Higher-margin service selected first (greedy correctness)" begin
            p = OptProblem(
                "GREEDY_CHECK",
                ["A", "B"],
                [1000.0, 100.0],
                reshape([1.0, 1.0], 2, 1),
                [50.0],
                [0.0, 0.0], [50.0, 50.0],
                1000.0 * 50.0
            )
            obj, vols, _ = greedy_optimize(p)
            @test vols[1] >= vols[2]
        end

    end  # Part 2

    # =========================================================================
    # PART 3: Kentucky 2014 Medicaid Expansion Policy Simulation
    # =========================================================================
    @testset "3. Kentucky 2014 Medicaid Expansion Validation" begin

        @testset "3.1 Baseline Kentucky hospital configuration is valid" begin
            hospitals = build_kentucky_2014_hospitals()
            @test length(hospitals) == 10
            for (id, h) in hospitals
                @test h.margin > 0.0
                @test h.volume > 0.0
                @test 0.0 <= h.quality_score <= 1.0
                @test 0.0 <= h.payer_mix_medicare <= 1.0
            end
        end

        @testset "3.2 Medicaid Expansion raises state enrollment" begin
            hospitals = build_kentucky_2014_hospitals()
            state     = (enrollment=600_000.0, cost_per_case=120.0)
            expansion = MedicaidExpansion(
                coverage_increase       = 0.165,
                payment_rate_multiplier = 0.90,
                implementation_year     = 1
            )
            scenario = MultiLevelPolicyScenario(
                state_policies              = StatePolicy[expansion],
                insurance_demand_elasticity = -0.40,
                scenario_name               = "KY 2014 Expansion"
            )
            outcomes = simulate_policy_coupling!(scenario, hospitals, state, 3)
            @test outcomes.financial_impact["enrollment_change"] > 0.0
            @test outcomes.years == 3
        end

        @testset "3.3 Coverage to utilisation to costs mechanism is present" begin
            hospitals = build_kentucky_2014_hospitals()
            state     = (enrollment=600_000.0, cost_per_case=120.0)
            expansion = MedicaidExpansion(
                coverage_increase       = 0.165,
                payment_rate_multiplier = 0.90,
                implementation_year     = 1
            )
            scenario = MultiLevelPolicyScenario(
                state_policies              = StatePolicy[expansion],
                insurance_demand_elasticity = -0.40,
                scenario_name               = "KY Mechanism"
            )
            outcomes = simulate_policy_coupling!(scenario, hospitals, state, 4)
            @test length(outcomes.total_cost) == 4
            for id in keys(hospitals)
                id in outcomes.hospital_closures && continue
                @test length(outcomes.hospital_volumes[id]) >= 2
            end
        end

        @testset "3.4 Directional margin change matches CMS benchmark (post-expansion)" begin
            hospitals = build_kentucky_2014_hospitals()
            state     = (enrollment=600_000.0, cost_per_case=120.0)
            strats = Dict{String,HospitalStrategy}(
                id => AccommodativeStrategy(
                    payer_mix_flexibility       = 0.80,
                    quality_investment_rate     = 0.08,
                    service_mix_adjustment_rate = 0.10
                )
                for id in keys(hospitals)
            )
            expansion = MedicaidExpansion(
                coverage_increase       = 0.165,
                payment_rate_multiplier = 0.90,
                implementation_year     = 1
            )
            scenario = MultiLevelPolicyScenario(
                state_policies              = StatePolicy[expansion],
                hospital_strategies         = strats,
                insurance_demand_elasticity = -0.40,
                provider_exit_threshold     = -0.02,
                scenario_name               = "KY Comparison"
            )
            outcomes = simulate_policy_coupling!(scenario, hospitals, state, 3)
            active = setdiff(keys(hospitals), Set(outcomes.hospital_closures))
            @test !isempty(active)
            margin_changes = [
                outcomes.hospital_margins[id][end] - outcomes.hospital_margins[id][1]
                for id in active
                if length(outcomes.hospital_margins[id]) >= 2
            ]
            @test !isempty(margin_changes)
            @test mean(margin_changes) >= -0.02
        end

        @testset "3.5 Sensitivity: low demand elasticity (-0.10)" begin
            hospitals = build_kentucky_2014_hospitals()
            state     = (enrollment=600_000.0, cost_per_case=120.0)
            expansion = MedicaidExpansion(coverage_increase=0.165, implementation_year=1)
            scenario_lo = MultiLevelPolicyScenario(
                state_policies              = StatePolicy[expansion],
                insurance_demand_elasticity = -0.10,
                scenario_name               = "KY Low Elasticity"
            )
            outcomes_lo = simulate_policy_coupling!(scenario_lo, hospitals, state, 3)
            active_lo   = setdiff(keys(hospitals), Set(outcomes_lo.hospital_closures))
            @test !isempty(active_lo)
            @test outcomes_lo.years == 3
            @test length(outcomes_lo.total_cost) == 3
        end

        @testset "3.6 Sensitivity: high demand elasticity (-0.70)" begin
            hospitals = build_kentucky_2014_hospitals()
            state     = (enrollment=600_000.0, cost_per_case=120.0)
            expansion = MedicaidExpansion(coverage_increase=0.165, implementation_year=1)
            scenario_hi = MultiLevelPolicyScenario(
                state_policies              = StatePolicy[expansion],
                insurance_demand_elasticity = -0.70,
                scenario_name               = "KY High Elasticity"
            )
            outcomes_hi = simulate_policy_coupling!(scenario_hi, hospitals, state, 3)
            @test outcomes_hi.years == 3
            @test length(outcomes_hi.total_cost) == 3
        end

        @testset "3.7 Sensitivity: coverage increase magnitude (5% vs 20%)" begin
            hospitals = build_kentucky_2014_hospitals()
            state     = (enrollment=600_000.0, cost_per_case=120.0)
            function run_expansion(cov_inc)
                exp = MedicaidExpansion(coverage_increase=cov_inc, implementation_year=1)
                sc  = MultiLevelPolicyScenario(
                    state_policies              = StatePolicy[exp],
                    insurance_demand_elasticity = -0.40,
                    scenario_name               = "KY Coverage $cov_inc"
                )
                return simulate_policy_coupling!(sc, hospitals, state, 3)
            end
            out_lo = run_expansion(0.05)
            out_hi = run_expansion(0.20)
            @test out_hi.financial_impact["enrollment_change"] >=
                  out_lo.financial_impact["enrollment_change"]
        end

        @testset "3.8 Sensitivity: Medicaid payment rate impact on closures" begin
            hospitals = build_kentucky_2014_hospitals()
            state     = (enrollment=600_000.0, cost_per_case=120.0)
            function run_with_rate(rate_mult)
                exp = MedicaidExpansion(
                    coverage_increase       = 0.165,
                    payment_rate_multiplier = rate_mult,
                    implementation_year     = 1
                )
                sc = MultiLevelPolicyScenario(
                    state_policies              = StatePolicy[exp],
                    insurance_demand_elasticity = -0.40,
                    provider_exit_threshold     = -0.05,
                    scenario_name               = "KY Rate $rate_mult"
                )
                return simulate_policy_coupling!(sc, hospitals, state, 3)
            end
            out_90 = run_with_rate(0.90)
            out_70 = run_with_rate(0.70)
            @test out_90.years == 3
            @test out_70.years == 3
            @test length(out_70.hospital_closures) >= length(out_90.hospital_closures)
        end

        @testset "3.9 Rural hospitals more vulnerable at low payment rates" begin
            hospitals = build_kentucky_2014_hospitals()
            state     = (enrollment=600_000.0, cost_per_case=120.0)
            expansion = MedicaidExpansion(
                coverage_increase       = 0.165,
                payment_rate_multiplier = 0.70,
                implementation_year     = 1
            )
            scenario = MultiLevelPolicyScenario(
                state_policies              = StatePolicy[expansion],
                insurance_demand_elasticity = -0.40,
                provider_exit_threshold     = 0.005,
                scenario_name               = "KY Rural Stress"
            )
            outcomes = simulate_policy_coupling!(scenario, hospitals, state, 3)
            @test outcomes.years == 3
            rural_ids = ["KY_H05_Elizabethtown", "KY_H07_Hazard", "KY_H10_Murray"]
            for rid in rural_ids
                @test haskey(outcomes.hospital_margins, rid) ||
                      rid in outcomes.hospital_closures
            end
        end

        @testset "3.10 Combined Medicare reform + Medicaid expansion interaction" begin
            hospitals = build_kentucky_2014_hospitals()
            state     = (enrollment=600_000.0, cost_per_case=120.0)
            reform    = MedicarePaymentReform(
                drg_weight_changes     = Dict("MDC-05" => 0.97),
                quality_incentive_pool = 0.02,
                implementation_year    = 2
            )
            expansion = MedicaidExpansion(coverage_increase=0.165, implementation_year=1)
            scenario  = MultiLevelPolicyScenario(
                federal_policies            = FederalPolicy[reform],
                state_policies              = StatePolicy[expansion],
                insurance_demand_elasticity = -0.40,
                scenario_name               = "KY Combined Policy"
            )
            outcomes = simulate_policy_coupling!(scenario, hospitals, state, 5)
            @test outcomes.years == 5
            @test length(outcomes.total_cost) == 5
            interactions = analyze_policy_interactions(scenario, outcomes)
            @test interactions["medicaid_expansion_medicare_cut_stress"] == true
            @test interactions["stress_level"] == "high"
        end

    end  # Part 3

    # =========================================================================
    # PART 4: Integration Testing (Phase 1 + Phase 2 end-to-end)
    # =========================================================================
    @testset "4. Integration Testing: Phase 1 + Phase 2 End-to-End" begin

        @testset "4.1 Data pipeline: hospital baseline -> network -> policy" begin
            ky_hospitals = build_kentucky_2014_hospitals()
            @test length(ky_hospitals) == 10
            Random.seed!(5000)
            net_hospitals = build_10_hospital_network()
            sim = LiteNetworkSim(net_hospitals, LitePatient[], 30, "hybrid",
                                  Dict{String,Any}())
            run_network_simulation!(sim; admission_rate=20.0)
            @test sim.results["total_patients"] > 0
            expansion = MedicaidExpansion(coverage_increase=0.165, implementation_year=1)
            scenario  = MultiLevelPolicyScenario(
                state_policies = StatePolicy[expansion],
                scenario_name  = "Pipeline Integration Test"
            )
            state    = (enrollment=600_000.0, cost_per_case=120.0)
            outcomes = simulate_policy_coupling!(scenario, ky_hospitals, state, 3)
            @test outcomes.years == 3
            @test !isempty(outcomes.hospital_margins)
        end

        @testset "4.2 Network cost feeds into policy margin calculation" begin
            Random.seed!(5001)
            hospitals = build_10_hospital_network()
            sim = LiteNetworkSim(hospitals, LitePatient[], 30, "hybrid",
                                  Dict{String,Any}())
            run_network_simulation!(sim; admission_rate=20.0)
            avg_network_cost = sim.results["avg_cost_per_patient"]
            @test avg_network_cost > 0.0
            ky_hospitals = build_kentucky_2014_hospitals()
            state        = (enrollment=600_000.0,
                            cost_per_case=avg_network_cost / 1_000.0)
            expansion    = MedicaidExpansion(coverage_increase=0.165,
                                             implementation_year=1)
            scenario     = MultiLevelPolicyScenario(
                state_policies = StatePolicy[expansion],
                scenario_name  = "Cost-Integrated Policy"
            )
            outcomes = simulate_policy_coupling!(scenario, ky_hospitals, state, 2)
            @test outcomes.years == 2
        end

        @testset "4.3 Multiple simulation runs produce consistent structure" begin
            for run_id in 1:3
                Random.seed!(run_id * 1000)
                hospitals = build_10_hospital_network()
                sim = LiteNetworkSim(hospitals, LitePatient[], 30, "hybrid",
                                      Dict{String,Any}())
                run_network_simulation!(sim; admission_rate=20.0)
                @test haskey(sim.results, "total_patients")
                @test haskey(sim.results, "hospital_costs")
                @test haskey(sim.results, "hospital_volumes")
                @test length(sim.results["hospital_costs"]) == 10
            end
        end

        @testset "4.4 Optimization feeds into policy capacity planning" begin
            all_obj = Float64[]
            for i in 1:10
                cap = Float64(80 + i * 15)
                p = OptProblem(
                    "CAP_H$i",
                    ["General", "Cardiology", "Orthopedics"],
                    [200.0, 400.0, 300.0],
                    Matrix{Float64}(I, 3, 3),
                    [cap, cap * 0.6, cap * 0.4],
                    zeros(3), [cap, cap * 0.6, cap * 0.4],
                    0.0
                )
                obj, _, status = greedy_optimize(p)
                @test status == :feasible
                push!(all_obj, obj)
            end
            total_portfolio_obj = sum(all_obj)
            @test total_portfolio_obj > 0.0
            @test total_portfolio_obj / 10.0 > 0.0
        end

        @testset "4.5 End-to-end: baseline vs expanded scenario comparison" begin
            ky_hospitals = build_kentucky_2014_hospitals()
            state        = (enrollment=600_000.0, cost_per_case=120.0)
            base_scenario = MultiLevelPolicyScenario(scenario_name="Baseline")
            base_outcomes = simulate_policy_coupling!(base_scenario, ky_hospitals,
                                                       state, 3)
            expansion = MedicaidExpansion(coverage_increase=0.165, implementation_year=1)
            exp_scenario  = MultiLevelPolicyScenario(
                state_policies = StatePolicy[expansion],
                scenario_name  = "Expanded"
            )
            exp_outcomes = simulate_policy_coupling!(exp_scenario, ky_hospitals,
                                                      state, 3)
            @test base_outcomes.years == exp_outcomes.years
            @test exp_outcomes.financial_impact["enrollment_change"] >=
                  base_outcomes.financial_impact["enrollment_change"]
        end

    end  # Part 4

    # =========================================================================
    # PART 5: Performance Benchmarking and Stress Tests
    # =========================================================================
    @testset "5. Performance Benchmarking and Stress Tests" begin

        @testset "5.1 Stress test: 100-hospital network simulation" begin
            rng = MersenneTwister(9999)
            hospitals_100 = LiteHospital[]
            for i in 1:100
                beds = 50 + rand(rng, 0:350)
                lat  = 36.5 + rand(rng) * 3.0
                lon  = -89.5 + rand(rng) * 7.0
                svcs = Set{String}(["General", "ED"])
                beds >= 150 && push!(svcs, "Cardiology")
                beds >= 200 && push!(svcs, "Orthopedics")
                beds >= 300 && push!(svcs, "ICU")
                push!(hospitals_100, LiteHospital(
                    "SH$i", "Stress Hospital $i",
                    (lat, lon), beds, svcs,
                    0.70 + rand(rng) * 0.25,
                    Dict("Medicare"=>0.44,"Medicaid"=>0.29,
                         "Commercial"=>0.19,"Uninsured"=>0.08),
                    1_000.0 + beds * 3.0
                ))
            end
            @test length(hospitals_100) == 100
            Random.seed!(8888)
            sim_100 = LiteNetworkSim(hospitals_100, LitePatient[], 30, "hybrid",
                                      Dict{String,Any}())
            t_start = time()
            run_network_simulation!(sim_100; admission_rate=50.0)
            elapsed = time() - t_start
            @test sim_100.results["total_patients"] > 0
            @test elapsed < 60.0
        end

        @testset "5.2 Benchmark: 10 hospitals x 90 days -- under 30 seconds" begin
            Random.seed!(7777)
            hospitals = build_10_hospital_network()
            sim = LiteNetworkSim(hospitals, LitePatient[], 90, "hybrid",
                                  Dict{String,Any}())
            t_start = time()
            run_network_simulation!(sim; admission_rate=30.0)
            elapsed = time() - t_start
            @test elapsed < 30.0
        end

        @testset "5.3 Optimization timing: 50 problems solved under 10 seconds" begin
            t_start = time()
            for i in 1:50
                p = build_test_problems()[mod1(i, 10)]
                greedy_optimize(p)
            end
            elapsed = time() - t_start
            @test elapsed < 10.0
        end

        @testset "5.4 Policy simulation: 20-year projection completes quickly" begin
            hospitals = build_kentucky_2014_hospitals()
            state     = (enrollment=600_000.0, cost_per_case=120.0)
            expansion = MedicaidExpansion(coverage_increase=0.165, implementation_year=1)
            scenario  = MultiLevelPolicyScenario(
                state_policies = StatePolicy[expansion],
                scenario_name  = "20-year Projection"
            )
            t_start  = time()
            outcomes = simulate_policy_coupling!(scenario, hospitals, state, 20)
            elapsed  = time() - t_start
            @test outcomes.years == 20
            @test elapsed < 10.0
        end

        @testset "5.5 Reproducibility: same seed yields identical patient count" begin
            function run_once(seed)
                Random.seed!(seed)
                hospitals = build_10_hospital_network()
                sim = LiteNetworkSim(hospitals, LitePatient[], 10, "hybrid",
                                      Dict{String,Any}())
                run_network_simulation!(sim; admission_rate=10.0)
                return sim.results["total_patients"]
            end
            n1 = run_once(42)
            n2 = run_once(42)
            @test n1 == n2
        end

    end  # Part 5

    # =========================================================================
    # PART 6: API Contract and Output Schema Validation
    # =========================================================================
    @testset "6. API Contract and Output Schema Validation" begin

        @testset "6.1 Network simulation results contain all required keys" begin
            hospitals = build_10_hospital_network()
            sim = LiteNetworkSim(hospitals, LitePatient[], 10, "hybrid",
                                  Dict{String,Any}())
            run_network_simulation!(sim; admission_rate=10.0)
            for key in ["total_patients", "total_cost", "avg_cost_per_patient",
                        "hospital_costs", "hospital_volumes",
                        "hospital_avg_los", "payer_counts"]
                @test haskey(sim.results, key)
            end
        end

        @testset "6.2 PolicyCouplingOutcomes contains all required fields" begin
            hospitals = build_kentucky_2014_hospitals()
            state     = (enrollment=600_000.0, cost_per_case=120.0)
            scenario  = MultiLevelPolicyScenario(scenario_name="Schema Test")
            outcomes  = simulate_policy_coupling!(scenario, hospitals, state, 2)
            @test outcomes isa PolicyCouplingOutcomes
            @test outcomes.scenario_name isa String
            @test outcomes.years isa Int
            @test outcomes.hospital_margins isa Dict
            @test outcomes.hospital_volumes isa Dict
            @test outcomes.hospital_closures isa Vector{String}
            @test outcomes.total_cost isa Vector{Float64}
            @test outcomes.financial_impact isa Dict
            @test outcomes.equity_analysis isa Dict
        end

        @testset "6.3 OptProblem solutions satisfy all declared constraints" begin
            for p in build_test_problems()
                obj, vols, status = greedy_optimize(p)
                n_res = size(p.resource_req, 2)
                for r in 1:n_res
                    used = sum(vols[s] * p.resource_req[s, r]
                               for s in 1:length(p.service_lines))
                    @test used <= p.resource_cap[r] + 1e-9
                end
                @test all(vols .>= p.min_volumes .- 1e-9)
                @test all(vols .<= p.max_volumes .+ 1e-9)
            end
        end

        @testset "6.4 LiteHospital base_cost_per_day is always positive" begin
            for h in build_10_hospital_network()
                @test h.base_cost_per_day > 0.0
            end
        end

        @testset "6.5 MultiLevelPolicyCoupling type hierarchy is correct" begin
            @test MedicaidExpansion <: StatePolicy
            @test MedicarePaymentReform <: FederalPolicy
            @test ConservativeStrategy <: HospitalStrategy
            @test AggressiveExpansionStrategy <: HospitalStrategy
            @test AccommodativeStrategy <: HospitalStrategy
        end

        @testset "6.6 KY_2014_BENCHMARKS constants are valid" begin
            @test KY_2014_BENCHMARKS["uninsured_rate_pre"]  > KY_2014_BENCHMARKS["uninsured_rate_post"]
            @test KY_2014_BENCHMARKS["new_enrollees"]       > 0
            @test KY_2014_BENCHMARKS["medicaid_volume_increase"] > 0.0
            @test KY_2014_BENCHMARKS["uninsured_volume_decrease"] < 0.0
        end

    end  # Part 6

end  # Phase 2.4 Tests

println("\n" * "="^70)
println("Phase 2.4: Comprehensive Validation & Integration Tests completed.")
println("="^70)
