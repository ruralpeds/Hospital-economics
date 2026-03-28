# Agent-Based Model (ABM) Engine
# Simulates individual patient and provider decisions using Agents.jl.

using Agents
using Random

# ---------------------------------------------------------------------------
# Agent definitions
# ---------------------------------------------------------------------------

"""
    PatientAgent <: AbstractAgent

An agent representing an individual patient in the rural health ecosystem.

# Demographics & Geography
- `id::Int`: Unique agent identifier (required by Agents.jl).
- `pos::NTuple{2, Float64}`: Continuous position (longitude, latitude proxy) in the model space.
- `age::Int`: Patient age in years.
- `sex::Symbol`: `:male` or `:female`.
- `income_level::Float64`: Household income (annual, USD).
- `insurance_type::Symbol`: `:medicare`, `:medicaid`, `:commercial`, `:uninsured`.

# Health Status
- `chronic_conditions::Int`: Count of chronic conditions (0+).
- `acuity::Float64`: Current health acuity score (0.0 = healthy, 1.0 = critical).
- `last_visit_tick::Int`: Model tick of most recent healthcare utilisation.

# Decision Factors
- `travel_tolerance::Float64`: Maximum acceptable travel distance (miles).
- `loyalty::Float64`: Preference for incumbent facility (0.0 - 1.0).
- `price_sensitivity::Float64`: Weight placed on out-of-pocket cost (0.0 - 1.0).

# State Tracking
- `assigned_hospital_id::Int`: ID of the hospital this patient is currently assigned to.
- `seeking_care::Bool`: Whether the patient is currently seeking care.
"""
@agent PatientAgent ContinuousAgent{2} begin
    age::Int
    sex::Symbol
    income_level::Float64
    insurance_type::Symbol
    chronic_conditions::Int
    acuity::Float64
    last_visit_tick::Int
    travel_tolerance::Float64
    loyalty::Float64
    price_sensitivity::Float64
    assigned_hospital_id::Int
    seeking_care::Bool
end

"""
    ProviderAgent <: AbstractAgent

An agent representing a healthcare provider (physician, nurse, etc.).

# Professional Characteristics
- `id::Int`: Unique agent identifier.
- `pos::NTuple{2, Float64}`: Position in model space.
- `specialty::Symbol`: Clinical specialty (e.g., `:family_medicine`, `:emergency`, `:nursing`).
- `experience_years::Int`: Years of professional experience.
- `is_travel::Bool`: Whether this is a temporary/travel provider.

# Employment
- `employer_hospital_id::Int`: ID of employing hospital.
- `salary::Float64`: Annual salary (USD).
- `fte::Float64`: Full-time equivalent (0.0 - 1.0).

# Retention Factors
- `burnout::Float64`: Burnout score (0.0 = none, 1.0 = severe).
- `satisfaction::Float64`: Job satisfaction (0.0 = very low, 1.0 = very high).
- `community_ties::Float64`: Strength of community attachment (0.0 - 1.0).
- `years_at_facility::Int`: Tenure at current facility.

# Productivity
- `patients_per_day::Float64`: Average patient encounters per working day.
- `quality_score::Float64`: Quality metric (0.0 - 1.0).
"""
@agent ProviderAgent ContinuousAgent{2} begin
    specialty::Symbol
    experience_years::Int
    is_travel::Bool
    employer_hospital_id::Int
    salary::Float64
    fte::Float64
    burnout::Float64
    satisfaction::Float64
    community_ties::Float64
    years_at_facility::Int
    patients_per_day::Float64
    quality_score::Float64
end

# ---------------------------------------------------------------------------
# Model parameters
# ---------------------------------------------------------------------------

"""
    ABMParams <: AbstractSimulationParams

Parameters for the agent-based model.

# Fields
- `n_patients::Int`: Initial number of patient agents.
- `n_providers::Int`: Initial number of provider agents.
- `n_ticks::Int`: Number of simulation ticks to run.
- `space_extent::NTuple{2, Float64}`: Spatial extent of the model (width, height).
- `care_seeking_probability::Float64`: Per-tick probability a patient seeks care.
- `burnout_rate::Float64`: Per-tick burnout accumulation rate for providers.
- `departure_threshold::Float64`: Burnout level triggering provider departure consideration.
- `travel_nurse_arrival_rate::Float64`: Rate at which travel nurses become available.
- `softmax_temperature::Float64`: Temperature for facility choice softmax.
- `random_seed::Int`: Random seed for reproducibility.
"""
struct ABMParams <: AbstractSimulationParams
    n_patients::Int
    n_providers::Int
    n_ticks::Int
    space_extent::NTuple{2, Float64}
    care_seeking_probability::Float64
    burnout_rate::Float64
    departure_threshold::Float64
    travel_nurse_arrival_rate::Float64
    softmax_temperature::Float64
    random_seed::Int
end

"""
    ABMParams(; kwargs...)

Construct `ABMParams` with keyword arguments and sensible defaults.
"""
function ABMParams(;
    n_patients::Int = 5000,
    n_providers::Int = 150,
    n_ticks::Int = 520,  # ~10 years of weekly ticks
    space_extent::NTuple{2, Float64} = (100.0, 100.0),
    care_seeking_probability::Float64 = 0.02,
    burnout_rate::Float64 = 0.005,
    departure_threshold::Float64 = 0.8,
    travel_nurse_arrival_rate::Float64 = 0.1,
    softmax_temperature::Float64 = 1.0,
    random_seed::Int = 42,
)
    ABMParams(n_patients, n_providers, n_ticks, space_extent,
              care_seeking_probability, burnout_rate, departure_threshold,
              travel_nurse_arrival_rate, softmax_temperature, random_seed)
end

# ---------------------------------------------------------------------------
# Model initialization
# ---------------------------------------------------------------------------

"""
    initialize_abm(params::ABMParams, hospitals) -> AgentBasedModel

Create and initialise the agent-based model.

`hospitals` should be an iterable of objects with fields `id`, `pos` (2-tuple),
`quality`, and `capacity`.
"""
function initialize_abm(params::ABMParams, hospitals)
    space = ContinuousSpace(params.space_extent; periodic = false)
    rng = MersenneTwister(params.random_seed)

    properties = Dict(
        :params => params,
        :hospitals => hospitals,
        :tick => 0,
        :departed_providers => Int[],
    )

    model = AgentBasedModel(
        Union{PatientAgent, ProviderAgent},
        space;
        rng = rng,
        properties = properties,
    )

    # Populate patient agents
    for _ in 1:params.n_patients
        pos = Tuple(rand(rng, 2) .* params.space_extent)
        add_agent!(
            PatientAgent, model, pos;
            age = rand(rng, 25:90),
            sex = rand(rng, [:male, :female]),
            income_level = 20_000.0 + rand(rng) * 80_000.0,
            insurance_type = rand(rng, [:medicare, :medicaid, :commercial, :uninsured]),
            chronic_conditions = rand(rng, 0:4),
            acuity = rand(rng) * 0.3,
            last_visit_tick = 0,
            travel_tolerance = 10.0 + rand(rng) * 50.0,
            loyalty = rand(rng),
            price_sensitivity = rand(rng),
            assigned_hospital_id = first(hospitals).id,
            seeking_care = false,
        )
    end

    # Populate provider agents
    for _ in 1:params.n_providers
        hosp = rand(rng, hospitals)
        pos = Tuple(hosp.pos .+ (randn(rng, 2) .* 2.0))
        pos = clamp.(pos, 0.0, params.space_extent)
        add_agent!(
            ProviderAgent, model, Tuple(pos);
            specialty = rand(rng, [:family_medicine, :emergency, :nursing, :internal_medicine]),
            experience_years = rand(rng, 1:30),
            is_travel = false,
            employer_hospital_id = hosp.id,
            salary = 80_000.0 + rand(rng) * 200_000.0,
            fte = rand(rng, [0.5, 0.75, 1.0]),
            burnout = rand(rng) * 0.3,
            satisfaction = 0.5 + rand(rng) * 0.5,
            community_ties = rand(rng),
            years_at_facility = rand(rng, 0:20),
            patients_per_day = 8.0 + rand(rng) * 12.0,
            quality_score = 0.6 + rand(rng) * 0.4,
        )
    end

    return model
end

# ---------------------------------------------------------------------------
# Agent step functions
# ---------------------------------------------------------------------------

"""
    patient_step!(agent::PatientAgent, model)

Per-tick behaviour for patient agents:
1. Stochastically determine whether the patient seeks care this tick.
2. Age-related acuity drift.
3. If seeking care, choose a facility via `choose_outpatient_facility`.
"""
function patient_step!(agent::PatientAgent, model)
    params = model.properties[:params]
    rng = model.rng

    # Acuity drift: chronic conditions and age increase acuity over time
    acuity_drift = agent.chronic_conditions * 0.001 + (agent.age > 65 ? 0.002 : 0.0)
    agent.acuity = clamp(agent.acuity + acuity_drift + randn(rng) * 0.005, 0.0, 1.0)

    # Determine if seeking care this tick
    seek_prob = params.care_seeking_probability * (1.0 + agent.acuity * 2.0)
    agent.seeking_care = rand(rng) < seek_prob

    if agent.seeking_care
        chosen_id = choose_outpatient_facility(agent, model)
        agent.assigned_hospital_id = chosen_id
        agent.last_visit_tick = model.properties[:tick]
        # Receiving care reduces acuity
        agent.acuity = clamp(agent.acuity - 0.05, 0.0, 1.0)
    end
end

"""
    provider_step!(agent::ProviderAgent, model)

Per-tick behaviour for provider agents:
1. Accumulate burnout (inversely related to satisfaction).
2. Update satisfaction based on workload and community ties.
3. If burnout exceeds threshold, consider departure.
"""
function provider_step!(agent::ProviderAgent, model)
    params = model.properties[:params]
    rng = model.rng

    # Burnout accumulation
    workload_factor = agent.patients_per_day / 20.0  # normalise to expected max
    burnout_increment = params.burnout_rate * workload_factor * (1.0 - agent.satisfaction * 0.5)
    agent.burnout = clamp(agent.burnout + burnout_increment + randn(rng) * 0.01, 0.0, 1.0)

    # Satisfaction decay from burnout, offset by community ties
    satisfaction_change = -0.005 * agent.burnout + 0.002 * agent.community_ties
    agent.satisfaction = clamp(agent.satisfaction + satisfaction_change, 0.0, 1.0)

    # Quality degrades with burnout
    agent.quality_score = clamp(1.0 - agent.burnout * 0.5, 0.2, 1.0)

    # Departure consideration
    if agent.burnout > params.departure_threshold
        departure_prob = (agent.burnout - params.departure_threshold) * (1.0 - agent.community_ties * 0.5)
        if rand(rng) < departure_prob
            handle_provider_departure!(agent, model)
        end
    end

    agent.years_at_facility += 0  # increment handled at year boundaries
end

# ---------------------------------------------------------------------------
# Facility choice (utility-maximisation / softmax)
# ---------------------------------------------------------------------------

"""
    choose_outpatient_facility(patient::PatientAgent, model) -> Int

Select a healthcare facility using a utility-maximising softmax model.

Utility for each facility is a weighted sum of:
- Negative travel distance (closer is better).
- Facility quality score.
- Loyalty bonus for current facility.
- Negative price sensitivity penalty.

Returns the hospital ID of the chosen facility.
"""
function choose_outpatient_facility(patient::PatientAgent, model)::Int
    hospitals = model.properties[:params] |> _ -> model.properties[:hospitals]
    params = model.properties[:params]
    rng = model.rng

    utilities = Float64[]
    ids = Int[]

    for hosp in hospitals
        dist = sqrt(sum((patient.pos .- hosp.pos) .^ 2))

        # Skip facilities beyond travel tolerance
        dist > patient.travel_tolerance && continue

        # Utility components
        distance_utility = -dist / patient.travel_tolerance
        quality_utility = hosp.quality
        loyalty_bonus = (hosp.id == patient.assigned_hospital_id) ? patient.loyalty * 0.3 : 0.0
        price_penalty = -patient.price_sensitivity * 0.1  # simplified

        utility = distance_utility + quality_utility + loyalty_bonus + price_penalty
        push!(utilities, utility)
        push!(ids, hosp.id)
    end

    # Fallback: if no facility is reachable, keep current assignment
    isempty(utilities) && return patient.assigned_hospital_id

    # Softmax selection
    temp = params.softmax_temperature
    max_u = maximum(utilities)
    exp_utilities = exp.((utilities .- max_u) ./ temp)
    probabilities = exp_utilities ./ sum(exp_utilities)

    # Weighted random selection
    r = rand(rng)
    cumprob = 0.0
    for (i, p) in enumerate(probabilities)
        cumprob += p
        if r <= cumprob
            return ids[i]
        end
    end
    return ids[end]
end

# ---------------------------------------------------------------------------
# Provider departure and cascade effects
# ---------------------------------------------------------------------------

"""
    handle_provider_departure!(provider::ProviderAgent, model)

Process a provider's departure from their facility, including cascade effects:
1. Remove the provider from active duty.
2. Increase workload on remaining providers at the same hospital.
3. Degrade hospital quality score.
4. If staffing drops below critical threshold, trigger further burnout spikes.
"""
function handle_provider_departure!(provider::ProviderAgent, model)
    hosp_id = provider.employer_hospital_id
    push!(model.properties[:departed_providers], provider.id)

    # Find remaining providers at the same hospital
    remaining = [a for a in allagents(model)
                 if a isa ProviderAgent && a.id != provider.id &&
                    a.employer_hospital_id == hosp_id]

    if !isempty(remaining)
        # Redistribute workload
        extra_load = provider.patients_per_day / length(remaining)
        for r in remaining
            r.patients_per_day += extra_load
            # Cascade: sudden workload increase spikes burnout
            r.burnout = clamp(r.burnout + 0.05, 0.0, 1.0)
            r.satisfaction = clamp(r.satisfaction - 0.03, 0.0, 1.0)
        end
    end

    # Mark provider as departed (zero out productivity, set as travel candidate)
    provider.patients_per_day = 0.0
    provider.fte = 0.0
    provider.burnout = 1.0
    provider.satisfaction = 0.0
end

# ---------------------------------------------------------------------------
# Run simulation
# ---------------------------------------------------------------------------

"""
    ABMResult <: AbstractSimulationResult

Results from an agent-based model run.

# Fields
- `params::ABMParams`: Parameters used.
- `agent_data::DataFrame`: Agent-level data collected during the run.
- `model_data::DataFrame`: Model-level data collected during the run.
- `total_departures::Int`: Total provider departures observed.
"""
struct ABMResult <: AbstractSimulationResult
    params::ABMParams
    agent_data::Any  # DataFrame when DataFrames is loaded
    model_data::Any  # DataFrame when DataFrames is loaded
    total_departures::Int
end

"""
    run_abm(params::ABMParams, hospitals) -> ABMResult

Initialise and run the agent-based model for the specified number of ticks.

Collects agent-level and model-level data at each tick using Agents.jl's
`run!` function. Returns an `ABMResult` with collected data and summary metrics.
"""
function run_abm(params::ABMParams, hospitals)::ABMResult
    model = initialize_abm(params, hospitals)

    # Define step functions
    agent_step!(agent::PatientAgent, model) = patient_step!(agent, model)
    agent_step!(agent::ProviderAgent, model) = provider_step!(agent, model)

    model_step!(model) = begin
        model.properties[:tick] += 1
    end

    # Agent data to collect
    adata = [
        (:acuity, mean, a -> a isa PatientAgent),
        (:burnout, mean, a -> a isa ProviderAgent),
        (:satisfaction, mean, a -> a isa ProviderAgent),
    ]

    # Model data to collect
    mdata = [
        :tick,
        m -> length(m.properties[:departed_providers]),
    ]

    agent_df, model_df = run!(
        model, agent_step!, model_step!, params.n_ticks;
        adata = adata,
        mdata = mdata,
    )

    total_deps = length(model.properties[:departed_providers])

    return ABMResult(params, agent_df, model_df, total_deps)
end
