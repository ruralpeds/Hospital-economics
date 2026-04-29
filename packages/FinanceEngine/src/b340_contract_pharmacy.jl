"""
    b340_contract_pharmacy.jl — 340B Contract Pharmacy Model (MBA Gap E-05)

Extends the existing `program_340b.jl` (which covers in-house covered-entity
dispensing) with the contract pharmacy arrangement framework:

## What this module adds
1. **Contract pharmacy setup** — covered entity relationships with retail pharmacies;
   split-billing workflow; HRSA contract pharmacy registry requirements.
2. **Drug manufacturer restrictions** (post-2020) — models the AbbVie, Sanofi,
   Novo Nordisk, and other manufacturers' policies limiting 340B contract pharmacy
   arrangements to one or a limited number of pharmacies per covered entity.
3. **Savings attribution** — distinguishes in-house vs contract pharmacy savings;
   tracks by pharmacy location and restriction tier.
4. **Duplicate discount prevention** — identifies prescriptions that may create a
   duplicate discount risk (Medicaid fee-for-service exclusion requirements).
5. **In-house vs contract pharmacy financial comparison** — models net savings under
   each dispensing approach accounting for fees, audit risk, and restriction losses.
6. **HRSA audit triggers** — compliance thresholds that trigger OPAIS review.

## Background
The 340B program allows covered entities (including CAHs and DSH hospitals) to
purchase outpatient drugs at deeply discounted prices (typically 25-50% below
wholesale acquisition cost). Covered entities can dispense through:
  - Their own pharmacy (in-house) — no restriction by manufacturers.
  - Contract pharmacies — third-party retail pharmacies with written agreement.
    CMS Health Resources and Services Administration (HRSA) registers these.

After 2020, multiple drug manufacturers (AbbVie, Sanofi, Novo Nordisk, Eli Lilly,
Bristol-Myers Squibb, and others) restricted 340B pricing to contract pharmacies,
claiming HRSA had exceeded its statutory authority. Courts have split on this.

References:
- 42 U.S.C. § 256b (340B statute).
- HRSA 340B Prime Vendor Program and OPAIS database.
- HRSA (2010). Contract pharmacy guidance (75 Fed. Reg. 10272).
- American Hospital Association v. Becerra, 596 U.S. 724 (2022).
- CMS CMCS Informational Bulletin: 340B and Medicaid (Feb 2024).
"""

using Statistics
using Printf
using Dates

# ─────────────────────────────────────────────────────────────────────────────
# Covered entity types
# ─────────────────────────────────────────────────────────────────────────────

"""
    CoveredEntityType

340B-eligible facility type. Affects allowed contract pharmacy count and
manufacturer restriction exposure.
"""
@enum CoveredEntityType begin
    cah_340b         = 1   # Critical Access Hospital — full eligibility
    dsh_hospital     = 2   # Disproportionate Share Hospital
    rural_referral   = 3   # Rural Referral Center
    fqhc_340b        = 4   # Federally Qualified Health Center
    ryan_white       = 5   # Ryan White HIV/AIDS clinic
end

# ─────────────────────────────────────────────────────────────────────────────
# Manufacturer restriction policies (post-2020)
# ─────────────────────────────────────────────────────────────────────────────

"""
    ManufacturerRestrictionPolicy

A drug manufacturer's contract pharmacy restriction policy.

# Fields
- `manufacturer::String`
- `restriction_type::Symbol`:
  - `:unlimited`: No restriction (honours all contract pharmacy arrangements).
  - `:one_pharmacy`: Allows one contract pharmacy per covered entity.
  - `:ship_to_ce`: Will ship at 340B price only to covered entity; no contract pharmacy.
  - `:none`: No 340B price available through contract pharmacies.
- `exemptions::Vector{CoveredEntityType}`: Entity types exempt from restriction.
- `effective_date::Date`
- `litigation_status::Symbol`: `:active`, `:settled`, `:enjoined`.
"""
@kwdef struct ManufacturerRestrictionPolicy
    manufacturer::String
    restriction_type::Symbol
    exemptions::Vector{CoveredEntityType}  = CoveredEntityType[]
    effective_date::Date                   = Date(2020, 12, 1)
    litigation_status::Symbol              = :active
end

"""
    MANUFACTURER_RESTRICTION_POLICIES_2026

Known manufacturer contract pharmacy restriction policies as of FY2026.
Source: HRSA 340B OPAIS dispute resolution; AHA litigation tracker; manufacturer
        manufacturer publications.
"""
const MANUFACTURER_RESTRICTION_POLICIES_2026 = [
    ManufacturerRestrictionPolicy(
        manufacturer="AbbVie", restriction_type=:one_pharmacy,
        exemptions=[cah_340b, fqhc_340b], effective_date=Date(2020, 12, 1),
        litigation_status=:active),
    ManufacturerRestrictionPolicy(
        manufacturer="Sanofi", restriction_type=:one_pharmacy,
        exemptions=[cah_340b, fqhc_340b, ryan_white], effective_date=Date(2020, 12, 1),
        litigation_status=:active),
    ManufacturerRestrictionPolicy(
        manufacturer="Novo Nordisk", restriction_type=:one_pharmacy,
        exemptions=[fqhc_340b, ryan_white], effective_date=Date(2021, 3, 1),
        litigation_status=:active),
    ManufacturerRestrictionPolicy(
        manufacturer="Eli Lilly", restriction_type=:ship_to_ce,
        exemptions=[cah_340b], effective_date=Date(2021, 5, 1),
        litigation_status=:active),
    ManufacturerRestrictionPolicy(
        manufacturer="Bristol-Myers Squibb", restriction_type=:one_pharmacy,
        exemptions=CoveredEntityType[], effective_date=Date(2021, 6, 1),
        litigation_status=:active),
    ManufacturerRestrictionPolicy(
        manufacturer="Pfizer", restriction_type=:unlimited,   # reinstated after litigation
        exemptions=CoveredEntityType[], effective_date=Date(2023, 1, 1),
        litigation_status=:enjoined),
    ManufacturerRestrictionPolicy(
        manufacturer="Merck", restriction_type=:unlimited,
        exemptions=CoveredEntityType[], effective_date=Date(2020, 1, 1),
        litigation_status=:settled),
    ManufacturerRestrictionPolicy(
        manufacturer="Johnson & Johnson", restriction_type=:one_pharmacy,
        exemptions=[cah_340b, fqhc_340b], effective_date=Date(2021, 4, 1),
        litigation_status=:active),
    ManufacturerRestrictionPolicy(
        manufacturer="AstraZeneca", restriction_type=:one_pharmacy,
        exemptions=[ryan_white, fqhc_340b], effective_date=Date(2021, 8, 1),
        litigation_status=:active),
    ManufacturerRestrictionPolicy(
        manufacturer="Boehringer Ingelheim", restriction_type=:none,
        exemptions=[cah_340b], effective_date=Date(2022, 1, 1),
        litigation_status=:active),
]

# ─────────────────────────────────────────────────────────────────────────────
# Contract pharmacy arrangement
# ─────────────────────────────────────────────────────────────────────────────

"""
    ContractPharmacy

One contract pharmacy in a covered entity's 340B programme.

# Fields
- `pharmacy_id::Any`
- `name::String`
- `chain::String`: e.g. "CVS", "Walgreens", "Independent".
- `npi::String`
- `annual_script_volume::Int`: Total prescriptions dispensed under 340B.
- `admin_fee_per_script::Float64`: Pharmacy administration fee (USD/script).
- `covered_entity_id::Any`: The covered entity this pharmacy serves.
- `distance_miles::Float64`: Distance from covered entity.
- `dispensing_fee_pct::Float64`: Additional fee as % of acquisition cost.
"""
@kwdef struct ContractPharmacy
    pharmacy_id::Any
    name::String
    chain::String               = "Independent"
    npi::String                 = ""
    annual_script_volume::Int
    admin_fee_per_script::Float64 = 8.50   # typical 340B contract pharmacy admin fee
    covered_entity_id::Any      = 1
    distance_miles::Float64     = 2.0
    dispensing_fee_pct::Float64 = 0.005   # 0.5% of acquisition cost
end

"""
    ContractPharmacyDrugRecord

One drug dispensed through a contract pharmacy.

# Fields
- `drug_name::String`
- `manufacturer::String`
- `ndc::String`: National Drug Code.
- `annual_scripts::Int`
- `wac_per_script::Float64`: Wholesale acquisition cost (USD/script).
- `ceiling_price_per_script::Float64`: 340B ceiling price (USD/script).
- `is_medicaid_ffs::Bool`: Medicaid fee-for-service (duplicate discount risk).
"""
@kwdef struct ContractPharmacyDrugRecord
    drug_name::String
    manufacturer::String
    ndc::String               = ""
    annual_scripts::Int
    wac_per_script::Float64
    ceiling_price_per_script::Float64
    is_medicaid_ffs::Bool     = false
end

# ─────────────────────────────────────────────────────────────────────────────
# Savings calculation
# ─────────────────────────────────────────────────────────────────────────────

"""
    ContractPharmacyDrugResult

340B savings result for one drug at one contract pharmacy.

# Fields
- `drug_name::String`, `manufacturer::String`
- `annual_scripts::Int`
- `gross_savings_per_script::Float64`: WAC − ceiling price.
- `gross_annual_savings::Float64`
- `admin_fee_annual::Float64`: Pharmacy admin fees.
- `net_annual_savings::Float64`: After admin fees.
- `manufacturer_restricted::Bool`: Whether manufacturer restricts this drug.
- `restriction_type::Symbol`
- `savings_at_risk_annual::Float64`: Savings lost if restriction applied.
- `duplicate_discount_risk::Bool`
- `duplicate_discount_exposure::Float64`: Amount at audit risk.
"""
struct ContractPharmacyDrugResult
    drug_name::String
    manufacturer::String
    annual_scripts::Int
    gross_savings_per_script::Float64
    gross_annual_savings::Float64
    admin_fee_annual::Float64
    net_annual_savings::Float64
    manufacturer_restricted::Bool
    restriction_type::Symbol
    savings_at_risk_annual::Float64
    duplicate_discount_risk::Bool
    duplicate_discount_exposure::Float64
end

"""
    calculate_contract_pharmacy_savings(
        pharmacy::ContractPharmacy,
        drugs::Vector{ContractPharmacyDrugRecord},
        entity_type::CoveredEntityType;
        restriction_policies
    ) -> NamedTuple

Calculate net 340B savings for a contract pharmacy arrangement.

For each drug, determines:
1. Whether the manufacturer restricts this drug's availability.
2. Gross savings = (WAC − ceiling price) × scripts.
3. Net savings after admin fees.
4. Duplicate discount exposure (Medicaid FFS scripts).

# Returns NamedTuple with drug results, totals, and risk summary.
"""
function calculate_contract_pharmacy_savings(
    pharmacy::ContractPharmacy,
    drugs::Vector{ContractPharmacyDrugRecord},
    entity_type::CoveredEntityType;
    restriction_policies::Vector{ManufacturerRestrictionPolicy} =
        MANUFACTURER_RESTRICTION_POLICIES_2026,
)
    # Index policies by manufacturer
    policy_idx = Dict(p.manufacturer => p for p in restriction_policies)

    drug_results = ContractPharmacyDrugResult[]
    for drug in drugs
        gross_savings = max(0.0, drug.wac_per_script - drug.ceiling_price_per_script)
        gross_annual  = gross_savings * drug.annual_scripts
        admin_fee     = pharmacy.admin_fee_per_script * drug.annual_scripts
        net_annual    = gross_annual - admin_fee

        # Check manufacturer restriction
        policy = get(policy_idx, drug.manufacturer, nothing)
        restricted = false
        restriction_type = :unlimited
        at_risk = 0.0

        if !isnothing(policy)
            restriction_type = policy.restriction_type
            # Entity is exempt from restriction?
            exempt = entity_type in policy.exemptions
            if !exempt && policy.restriction_type != :unlimited
                restricted = true
                at_risk = gross_annual   # full savings at risk if restricted
            end
        end

        # Duplicate discount: Medicaid FFS prescriptions must be excluded
        dup_risk = drug.is_medicaid_ffs
        dup_exposure = dup_risk ? gross_annual : 0.0

        push!(drug_results, ContractPharmacyDrugResult(
            drug.drug_name, drug.manufacturer,
            drug.annual_scripts, gross_savings,
            gross_annual, admin_fee, net_annual,
            restricted, restriction_type, at_risk,
            dup_risk, dup_exposure,
        ))
    end

    total_gross   = sum(r.gross_annual_savings for r in drug_results)
    total_fees    = sum(r.admin_fee_annual for r in drug_results)
    total_net     = sum(r.net_annual_savings for r in drug_results)
    total_at_risk = sum(r.savings_at_risk_annual for r in drug_results)
    total_dup_exp = sum(r.duplicate_discount_exposure for r in drug_results)
    restricted_count = count(r -> r.manufacturer_restricted, drug_results)

    # HRSA audit trigger thresholds
    audit_trigger = total_dup_exp / max(total_gross, 1.0) > 0.10  # >10% Medicaid FFS = audit flag

    (
        pharmacy               = pharmacy,
        entity_type            = entity_type,
        drug_results           = drug_results,
        total_gross_savings    = total_gross,
        total_admin_fees       = total_fees,
        total_net_savings      = total_net,
        total_savings_at_risk  = total_at_risk,
        savings_risk_pct       = total_gross > 0 ? total_at_risk / total_gross : 0.0,
        total_dup_exposure     = total_dup_exp,
        n_restricted_drugs     = restricted_count,
        audit_trigger_flag     = audit_trigger,
        effective_savings_rate = total_gross > 0 ? total_net / total_gross : 0.0,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# In-house vs contract pharmacy comparison
# ─────────────────────────────────────────────────────────────────────────────

"""
    compare_inhouse_vs_contract(;
        annual_scripts, avg_wac_per_script, avg_ceiling_per_script,
        inhouse_ops_cost_annual, contract_admin_fee_per_script,
        pct_manufacturer_restricted, entity_type
    ) -> NamedTuple

Compare the net financial benefit of in-house pharmacy vs contract pharmacy
for a 340B covered entity.

In-house pharmacy advantages:
- No manufacturer restrictions on 340B price.
- No admin fees paid to contract pharmacy.
- Better duplicate discount control.

Contract pharmacy advantages:
- Lower capital investment (no pharmacy build-out).
- Wider geographic access for patients.
- No pharmacy operations staffing.
"""
function compare_inhouse_vs_contract(;
    annual_scripts::Int,
    avg_wac_per_script::Float64,
    avg_ceiling_per_script::Float64,
    inhouse_ops_cost_annual::Float64,
    contract_admin_fee_per_script::Float64 = 8.50,
    pct_manufacturer_restricted::Float64   = 0.35,  # ~35% of scripts are restricted drugs
    entity_type::CoveredEntityType         = cah_340b,
)
    gross_per_script = max(0.0, avg_wac_per_script - avg_ceiling_per_script)
    total_gross      = gross_per_script * annual_scripts

    # In-house: full 340B savings − operational costs
    inhouse_net = total_gross - inhouse_ops_cost_annual

    # Contract pharmacy: reduced savings (restrictions) − admin fees
    # CAHs often exempt from restrictions; others lose ~35% of savings
    restriction_loss_pct = entity_type in [cah_340b, fqhc_340b] ? 0.10 : pct_manufacturer_restricted
    restricted_savings   = total_gross * (1.0 - restriction_loss_pct)
    contract_fees        = contract_admin_fee_per_script * annual_scripts
    contract_net         = restricted_savings - contract_fees

    break_even_scripts = inhouse_ops_cost_annual > 0 ?
        round(Int, inhouse_ops_cost_annual / contract_admin_fee_per_script) : 0

    (
        annual_scripts             = annual_scripts,
        total_gross_savings        = total_gross,
        inhouse_net_savings        = inhouse_net,
        inhouse_ops_cost           = inhouse_ops_cost_annual,
        contract_net_savings       = contract_net,
        contract_admin_fees        = contract_fees,
        contract_restriction_loss  = total_gross * restriction_loss_pct,
        preferred_model            = inhouse_net >= contract_net ? :inhouse : :contract,
        net_advantage_usd          = inhouse_net - contract_net,
        break_even_scripts         = break_even_scripts,
        entity_type                = entity_type,
    )
end
