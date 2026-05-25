# ============================================================================
# Two-Compartment Pharmacokinetic ODE Model
# ============================================================================
#
# Forward Euler solver matching the Rust cah-calc-bridge implementation.
# No dependency on DifferentialEquations.jl — intentionally kept simple
# for parity-testability against the Rust reference.

# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

"""
    PKParams

Parameters for a two-compartment pharmacokinetic model.

# Fields
- `dose::Float64`: administered dose (mg)
- `bioavailability::Float64`: fraction of dose reaching systemic circulation (0–1)
- `ka::Float64`: first-order absorption rate constant (1/hr)
- `cl_central::Float64`: central (elimination) clearance (L/hr)
- `cl_peripheral::Float64`: inter-compartmental clearance, Q (L/hr)
- `v_central::Float64`: central compartment volume (L)
- `v_peripheral::Float64`: peripheral compartment volume (L)
- `infusion_duration::Float64`: infusion duration in hours (0.0 = bolus)
"""
@kwdef struct PKParams
    dose::Float64
    bioavailability::Float64       = 1.0
    ka::Float64                    = 0.0   # 0 = IV bolus (no absorption compartment)
    cl_central::Float64
    cl_peripheral::Float64
    v_central::Float64
    v_peripheral::Float64
    infusion_duration::Float64     = 0.0
end

"""
    PKResult

Solution of a two-compartment PK simulation.

# Fields
- `times::Vector{Float64}`: time points (hours)
- `central_conc::Vector{Float64}`: central compartment concentration (mg/L)
- `peripheral_conc::Vector{Float64}`: peripheral compartment concentration (mg/L)
- `peak_concentration::Float64`: maximum central concentration (Cmax)
- `time_to_peak::Float64`: time at which Cmax occurs (Tmax, hours)
- `terminal_half_life::Float64`: derived terminal half-life (hours)
- `auc::Float64`: area under the central concentration–time curve (mg*hr/L)
"""
struct PKResult
    times::Vector{Float64}
    central_conc::Vector{Float64}
    peripheral_conc::Vector{Float64}
    peak_concentration::Float64
    time_to_peak::Float64
    terminal_half_life::Float64
    auc::Float64
end

# ---------------------------------------------------------------------------
# Core simulation
# ---------------------------------------------------------------------------

"""
    simulate_pk(params::PKParams; t_end::Float64=24.0, dt::Float64=0.1) -> PKResult

Simulate a two-compartment pharmacokinetic model using forward Euler
integration.

## ODE system (concentration form)

    dC1/dt = input(t)/V1 - (CL/V1 + Q/V1)*C1 + (Q/V1)*C2
    dC2/dt = (Q/V2)*C1 - (Q/V2)*C2

Where `input(t)` accounts for absorption (ka > 0) or direct IV bolus.

Terminal half-life is computed from the eigenvalues of the two-compartment
rate matrix: t_half = ln(2) / beta, where beta is the smaller eigenvalue.

AUC is computed via the trapezoidal rule.
"""
function simulate_pk(params::PKParams; t_end::Float64=24.0, dt::Float64=0.1)
    cl  = params.cl_central
    q   = params.cl_peripheral
    v1  = params.v_central
    v2  = params.v_peripheral
    F   = params.bioavailability
    ka  = params.ka

    n_steps = ceil(Int, t_end / dt) + 1

    times = Vector{Float64}(undef, n_steps)
    central_conc = Vector{Float64}(undef, n_steps)
    peripheral_conc = Vector{Float64}(undef, n_steps)

    # Initial conditions
    if ka > 0.0
        # Oral dosing: drug starts in absorption compartment
        c1 = 0.0
        c2 = 0.0
        drug_absorbed = params.dose * F  # amount available for absorption
    else
        # IV bolus: entire dose enters central compartment immediately
        c1 = params.dose * F / v1
        c2 = 0.0
        drug_absorbed = 0.0
    end

    peak = c1
    time_to_peak = 0.0

    for i in 1:n_steps
        t = (i - 1) * dt
        times[i] = t
        central_conc[i] = c1
        peripheral_conc[i] = c2

        if c1 > peak
            peak = c1
            time_to_peak = t
        end

        # Absorption input (first-order)
        absorption_rate = if ka > 0.0 && drug_absorbed > 0.0
            rate = ka * drug_absorbed
            drug_absorbed -= rate * dt
            if drug_absorbed < 0.0
                drug_absorbed = 0.0
            end
            rate / v1
        else
            0.0
        end

        # Two-compartment ODE (concentration form)
        dc1 = absorption_rate - (cl / v1 + q / v1) * c1 + (q / v1) * c2
        dc2 = (q / v2) * c1 - (q / v2) * c2

        c1 += dc1 * dt
        c2 += dc2 * dt
    end

    # Terminal half-life from eigenvalues of rate matrix
    half_life = _terminal_half_life(cl, q, v1, v2)

    # AUC via trapezoidal rule
    auc = _trapezoidal_auc(times, central_conc)

    return PKResult(times, central_conc, peripheral_conc,
                    peak, time_to_peak, half_life, auc)
end

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

"""
    _terminal_half_life(cl, q, v1, v2) -> Float64

Compute the terminal half-life of a two-compartment system.

Micro-rate constants:
  k10 = CL/V1,  k12 = Q/V1,  k21 = Q/V2

Eigenvalues alpha, beta (alpha > beta > 0) satisfy:
  alpha + beta = k10 + k12 + k21
  alpha * beta = k10 * k21

Terminal half-life = ln(2) / beta.
"""
function _terminal_half_life(cl::Float64, q::Float64, v1::Float64, v2::Float64)
    if cl <= 0.0 || v1 <= 0.0 || v2 <= 0.0
        return NaN
    end
    k10 = cl / v1
    k12 = q / v1
    k21 = q / v2
    s = k10 + k12 + k21
    p = k10 * k21
    disc = s * s - 4.0 * p
    if disc < 0.0
        return NaN
    end
    beta_rate = (s - sqrt(disc)) * 0.5
    if beta_rate <= 0.0
        return Inf
    end
    return log(2.0) / beta_rate
end

"""
    _trapezoidal_auc(times, concentrations) -> Float64

Compute the area under the curve via the trapezoidal rule.
"""
function _trapezoidal_auc(times::Vector{Float64}, conc::Vector{Float64})
    auc = 0.0
    for i in 2:length(times)
        dt = times[i] - times[i-1]
        auc += 0.5 * (conc[i-1] + conc[i]) * dt
    end
    return auc
end
