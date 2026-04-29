"""
    hospital_type_registry.jl — Centralised hospital type metadata (T-025)

Introduces an `AbstractHospitalType` hierarchy that makes the set of
recognized hospital types a first-class, enumerable value rather than
scattered `Symbol` comparisons throughout the codebase. Provides:

- `AbstractHospitalType` + concrete subtypes
- `HospitalTypeProperties` — machine-readable metadata per type
- `hospital_types()` — registry of all known types
- `create_hospital(type_key, kwargs...)` — factory function
- `hospital_type_of(hospital)` — reverse lookup
- `hospital_type_properties(type_key)` — metadata query
"""

# ─────────────────────────────────────────────────────────────────────────────
# Abstract base
# ─────────────────────────────────────────────────────────────────────────────

"""
    AbstractHospitalType

Supertype for all hospital classification singletons. Each concrete subtype
represents one recognized CMS / regulatory hospital category.
"""
abstract type AbstractHospitalType end

# ─────────────────────────────────────────────────────────────────────────────
# Concrete type singletons
# ─────────────────────────────────────────────────────────────────────────────

"""Critical Access Hospital (CAH) — Medicare cost-based reimbursement, ≤25 beds."""
struct CriticalAccessType   <: AbstractHospitalType end

"""Rural Emergency Hospital (REH) — New CMS designation (2023+), no inpatient."""
struct RuralEmergencyType   <: AbstractHospitalType end

"""Prospective Payment System hospital — DRG-based reimbursement."""
struct ProspectivePaymentType <: AbstractHospitalType end

"""Sole Community Hospital (SCH) — PPS variant with volume-protection payment."""
struct SoleCommunityType    <: AbstractHospitalType end

"""Medicare Dependent Hospital (MDH) — PPS variant for high-Medicare-share rural."""
struct MedicareDependentType <: AbstractHospitalType end

"""Low-Volume Adjustment hospital — PPS with low-volume payment add-on."""
struct LowVolumeAdjustmentType <: AbstractHospitalType end

"""Indian Health Service / Tribal / Urban Indian Organization hospital."""
struct IndianHealthServiceType <: AbstractHospitalType end

"""Children's hospital — excluded from IPPS; receives TEFRA rate."""
struct ChildrensType        <: AbstractHospitalType end

"""Long-Term Care Hospital (LTCH) — LTCH-PPS reimbursement."""
struct LongTermCareType     <: AbstractHospitalType end

"""Psychiatric facility — IPF-PPS reimbursement."""
struct PsychiatricType      <: AbstractHospitalType end

# ─────────────────────────────────────────────────────────────────────────────
# Metadata struct
# ─────────────────────────────────────────────────────────────────────────────

"""
    HospitalTypeProperties

Structured metadata for a hospital type.

# Fields
- `key::Symbol`: Short identifier used as the registry key (e.g. `:cah`).
- `display_name::String`: Human-readable name.
- `cms_designation::String`: Official CMS program name.
- `payment_system::Symbol`: Primary payment system (`:cost_based`, `:drg`, `:ltch_pps`, `:ipf_pps`).
- `max_beds::Union{Int, Nothing}`: Statutory bed limit (`nothing` = no limit).
- `inpatient_allowed::Bool`: Whether inpatient admissions are permitted.
- `rural_focus::Bool`: Whether this type is rural-specific.
- `medicare_participating::Bool`: Whether the type has Medicare participation requirements.
- `notes::String`: Free-text notes for display.
"""
@kwdef struct HospitalTypeProperties
    key::Symbol
    display_name::String
    cms_designation::String
    payment_system::Symbol
    max_beds::Union{Int, Nothing} = nothing
    inpatient_allowed::Bool = true
    rural_focus::Bool = false
    medicare_participating::Bool = true
    notes::String = ""
end

# ─────────────────────────────────────────────────────────────────────────────
# Registry
# ─────────────────────────────────────────────────────────────────────────────

const _HOSPITAL_TYPE_REGISTRY = Dict{Symbol, Tuple{AbstractHospitalType, HospitalTypeProperties}}(
    :cah => (
        CriticalAccessType(),
        HospitalTypeProperties(
            key = :cah,
            display_name = "Critical Access Hospital",
            cms_designation = "Critical Access Hospital (CAH)",
            payment_system = :cost_based,
            max_beds = 25,
            rural_focus = true,
            notes = "101% cost-based Medicare reimbursement; max 25 acute inpatient beds; 35-mile rule or 15-mile rule in mountainous terrain.",
        ),
    ),
    :reh => (
        RuralEmergencyType(),
        HospitalTypeProperties(
            key = :reh,
            display_name = "Rural Emergency Hospital",
            cms_designation = "Rural Emergency Hospital (REH)",
            payment_system = :cost_based,
            max_beds = 0,
            inpatient_allowed = false,
            rural_focus = true,
            notes = "New CMS designation effective Jan 2023. No inpatient beds; monthly facility payment + 5% outpatient add-on. Converted from CAH or small rural PPS only.",
        ),
    ),
    :pps => (
        ProspectivePaymentType(),
        HospitalTypeProperties(
            key = :pps,
            display_name = "Prospective Payment System Hospital",
            cms_designation = "IPPS Hospital",
            payment_system = :drg,
            notes = "Medicare-Severity DRG (MS-DRG) inpatient reimbursement under the Inpatient Prospective Payment System.",
        ),
    ),
    :sch => (
        SoleCommunityType(),
        HospitalTypeProperties(
            key = :sch,
            display_name = "Sole Community Hospital",
            cms_designation = "Sole Community Hospital (SCH)",
            payment_system = :drg,
            rural_focus = true,
            notes = "PPS hospital that is the sole source of inpatient care in its area. Receives hold-harmless payment based on hospital-specific rate.",
        ),
    ),
    :mdh => (
        MedicareDependentType(),
        HospitalTypeProperties(
            key = :mdh,
            display_name = "Medicare Dependent Hospital",
            cms_designation = "Medicare Dependent Hospital (MDH)",
            payment_system = :drg,
            rural_focus = true,
            notes = "Small rural PPS hospitals where ≥60% of inpatient days/discharges are Medicare. Receives hold-harmless payments.",
        ),
    ),
    :lva => (
        LowVolumeAdjustmentType(),
        HospitalTypeProperties(
            key = :lva,
            display_name = "Low-Volume Adjustment Hospital",
            cms_designation = "Low-Volume Payment Adjustment Hospital",
            payment_system = :drg,
            rural_focus = true,
            notes = "PPS hospitals with <3,800 total discharges and >15 road miles from nearest comparable hospital. Receives per-discharge add-on payment.",
        ),
    ),
    :ihs => (
        IndianHealthServiceType(),
        HospitalTypeProperties(
            key = :ihs,
            display_name = "Indian Health Service / Tribal Hospital",
            cms_designation = "IHS / Tribal / Urban Indian Organization Hospital",
            payment_system = :cost_based,
            notes = "Operated by IHS, tribal organization, or urban Indian organization. Medicare cost-based or all-inclusive rate.",
        ),
    ),
    :childrens => (
        ChildrensType(),
        HospitalTypeProperties(
            key = :childrens,
            display_name = "Children's Hospital",
            cms_designation = "Exempt Children's Hospital",
            payment_system = :tefra,
            notes = "Excluded from IPPS. Reimbursed under TEFRA rate-of-increase limits.",
        ),
    ),
    :ltch => (
        LongTermCareType(),
        HospitalTypeProperties(
            key = :ltch,
            display_name = "Long-Term Care Hospital",
            cms_designation = "Long-Term Care Hospital (LTCH)",
            payment_system = :ltch_pps,
            notes = "Average length of stay >25 days. Reimbursed under LTCH-PPS with site-neutral payment policy for short-stay and co-located cases.",
        ),
    ),
    :psych => (
        PsychiatricType(),
        HospitalTypeProperties(
            key = :psych,
            display_name = "Inpatient Psychiatric Facility",
            cms_designation = "Inpatient Psychiatric Facility (IPF)",
            payment_system = :ipf_pps,
            notes = "Reimbursed under the Inpatient Psychiatric Facility Prospective Payment System (IPF-PPS) with per-diem rates.",
        ),
    ),
)

"""
    hospital_types() -> Dict{Symbol, HospitalTypeProperties}

Return the complete registry of known hospital types, keyed by their
short `Symbol` identifier (e.g. `:cah`, `:reh`, `:pps`).

# Example
```julia
for (key, props) in hospital_types()
    println(key, ": ", props.display_name, " (", props.payment_system, ")")
end
```
"""
function hospital_types()::Dict{Symbol, HospitalTypeProperties}
    Dict(k => v[2] for (k, v) in _HOSPITAL_TYPE_REGISTRY)
end

"""
    hospital_type_properties(key::Symbol) -> HospitalTypeProperties

Look up metadata for a hospital type by key. Throws `KeyError` for unknown keys.

# Example
```julia
props = hospital_type_properties(:cah)
props.max_beds     # 25
props.rural_focus  # true
```
"""
function hospital_type_properties(key::Symbol)::HospitalTypeProperties
    haskey(_HOSPITAL_TYPE_REGISTRY, key) ||
        throw(KeyError("Unknown hospital type key: $(repr(key)). " *
                       "Valid keys: $(sort(collect(keys(_HOSPITAL_TYPE_REGISTRY))))"))
    _HOSPITAL_TYPE_REGISTRY[key][2]
end

"""
    hospital_type_singleton(key::Symbol) -> AbstractHospitalType

Return the singleton instance for the given type key.
"""
function hospital_type_singleton(key::Symbol)::AbstractHospitalType
    haskey(_HOSPITAL_TYPE_REGISTRY, key) ||
        throw(KeyError("Unknown hospital type key: $(repr(key))"))
    _HOSPITAL_TYPE_REGISTRY[key][1]
end

# ─────────────────────────────────────────────────────────────────────────────
# Reverse lookup
# ─────────────────────────────────────────────────────────────────────────────

"""
    hospital_type_of(hospital) -> Symbol

Return the registry key (e.g. `:cah`) for a concrete hospital struct.
Returns `:unknown` if the type is not in the registry.

# Example
```julia
h = CriticalAccessHospital(...)
hospital_type_of(h)  # :cah
```
"""
function hospital_type_of(hospital)::Symbol
    T = typeof(hospital)
    type_map = Dict(
        CriticalAccessHospital     => :cah,
        RuralEmergencyHospital     => :reh,
        ProspectivePaymentHospital => :pps,
    )
    get(type_map, T, :unknown)
end

# ─────────────────────────────────────────────────────────────────────────────
# Factory
# ─────────────────────────────────────────────────────────────────────────────

"""
    create_hospital(type_key::Symbol; kwargs...) -> AbstractHospital

Factory function that constructs the appropriate hospital struct for the given
`type_key`. Keyword arguments are passed through to the constructor.

Supported keys: `:cah`, `:reh`, `:pps`.

Other keys (`:sch`, `:mdh`, `:lva`, `:ihs`, `:childrens`, `:ltch`, `:psych`)
are registered in the metadata but do not yet have dedicated Julia structs;
calling `create_hospital` with those keys raises an informative error.

# Example
```julia
h = create_hospital(:cah;
    name = "Valley Community Hospital",
    beds = 15,
    location = "rural",
    county_fips = "30049",
)
```
"""
function create_hospital(type_key::Symbol; kwargs...)
    haskey(_HOSPITAL_TYPE_REGISTRY, type_key) ||
        throw(KeyError("Unknown hospital type: $(repr(type_key)). " *
                       "Valid: $(sort(collect(keys(_HOSPITAL_TYPE_REGISTRY))))"))

    if type_key == :cah
        return CriticalAccessHospital(; kwargs...)
    elseif type_key == :reh
        return RuralEmergencyHospital(; kwargs...)
    elseif type_key == :pps
        return ProspectivePaymentHospital(; kwargs...)
    else
        props = hospital_type_properties(type_key)
        throw(ArgumentError(
            "Hospital type $(repr(type_key)) ($(props.display_name)) is registered " *
            "in the metadata registry but does not yet have a concrete Julia struct. " *
            "Construct it directly or open a feature request."
        ))
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Convenience query helpers
# ─────────────────────────────────────────────────────────────────────────────

"""
    rural_hospital_types() -> Vector{Symbol}

Return all type keys where `rural_focus == true`.
"""
rural_hospital_types() = [k for (k, p) in hospital_types() if p.rural_focus]

"""
    cost_based_hospital_types() -> Vector{Symbol}

Return all type keys where `payment_system == :cost_based`.
"""
cost_based_hospital_types() = [k for (k, p) in hospital_types() if p.payment_system == :cost_based]

"""
    inpatient_hospital_types() -> Vector{Symbol}

Return all type keys where `inpatient_allowed == true`.
"""
inpatient_hospital_types() = [k for (k, p) in hospital_types() if p.inpatient_allowed]
