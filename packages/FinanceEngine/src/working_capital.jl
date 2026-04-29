"""
    working_capital.jl — Hospital Working Capital Optimization (MBA Gap A-10)

Provides the working capital analytics missing from the existing `supply_chain.jl`
(which covers inventory) and `finance/costreport.jl`:

1. **Cash Conversion Cycle (CCC)** — DSO + DIO − DPO: the number of days between
   paying for inputs and collecting from patients. A lower CCC = less cash tied up.

2. **Days Sales Outstanding (DSO)** — receivables efficiency; benchmark: < 45 days.

3. **Days Inventory Outstanding (DIO)** — supply-chain efficiency.

4. **Days Payable Outstanding (DPO)** — AP leverage; extending DPO frees cash.

5. **Target DSO Model** — what DSO would the hospital need to achieve a target
   cash balance? Reverse-engineers the required AR reduction.

6. **AR Aging Analysis** — bucket-level analysis (0–30, 31–60, 61–90, 90+ days)
   with expected collection rates, bad debt provisions, and recovery projections.

7. **Working Capital Optimisation Scenarios** — model the cash-flow impact of
   DSO reduction programmes, DPO extension, or inventory rationalisation.

References:
- Gapenski L, Pink G (2015). Understanding Healthcare Financial Management, 7e. Ch. 18.
- HFMA (2022). Working Capital Benchmark Report.
- CMS HCRIS Worksheet S-10 (bad debt and uncompensated care).
"""

using Statistics
using Printf
using Dates

# ─────────────────────────────────────────────────────────────────────────────
# Core working capital metrics
# ─────────────────────────────────────────────────────────────────────────────

"""
    WorkingCapitalInputs

Current-period working capital inputs. All dollar figures in USD.

# Fields
- `net_patient_revenue::Float64`: Annual net patient revenue.
- `total_operating_expenses::Float64`: Annual total operating expenses.
- `cost_of_supplies::Float64`: Annual supply/COGS expense.
- `accounts_receivable_net::Float64`: Net AR balance (after allowances).
- `inventory::Float64`: Supplies/drugs/materials on hand.
- `accounts_payable::Float64`: AP balance.
- `current_assets::Float64`: Total current assets.
- `current_liabilities::Float64`: Total current liabilities.
- `cash_and_investments::Float64`: Cash + short-term investments.
- `days_in_period::Int = 365`: Days in the measurement period.
"""
@kwdef struct WorkingCapitalInputs
    net_patient_revenue::Float64
    total_operating_expenses::Float64
    cost_of_supplies::Float64
    accounts_receivable_net::Float64
    inventory::Float64
    accounts_payable::Float64
    current_assets::Float64
    current_liabilities::Float64
    cash_and_investments::Float64
    days_in_period::Int = 365
end

"""
    WorkingCapitalMetrics

Computed working capital ratios and cycle measures.

# Fields
- `dso::Float64`: Days Sales Outstanding = AR / (Revenue / days).
- `dio::Float64`: Days Inventory Outstanding = Inventory / (COGS / days).
- `dpo::Float64`: Days Payable Outstanding = AP / (Expenses / days).
- `ccc::Float64`: Cash Conversion Cycle = DSO + DIO − DPO.
- `current_ratio::Float64`: Current assets / current liabilities.
- `quick_ratio::Float64`: (Cash + AR) / current liabilities.
- `operating_cash_cycle_days::Float64`: Days from cash out to cash in.
- `working_capital::Float64`: Current assets − current liabilities (USD).
- `net_working_capital_pct::Float64`: Working capital / revenue.
"""
struct WorkingCapitalMetrics
    dso::Float64
    dio::Float64
    dpo::Float64
    ccc::Float64
    current_ratio::Float64
    quick_ratio::Float64
    operating_cash_cycle_days::Float64
    working_capital::Float64
    net_working_capital_pct::Float64
end

"""
    compute_working_capital(inputs::WorkingCapitalInputs) -> WorkingCapitalMetrics

Compute all working capital metrics.

CCC = DSO + DIO − DPO

A positive CCC means the hospital must finance the gap between paying suppliers
and collecting from payers. Reducing CCC frees cash without borrowing.
"""
function compute_working_capital(inputs::WorkingCapitalInputs)::WorkingCapitalMetrics
    d = Float64(inputs.days_in_period)
    rev  = inputs.net_patient_revenue
    exp  = inputs.total_operating_expenses
    cogs = inputs.cost_of_supplies

    dso = rev > 0  ? inputs.accounts_receivable_net / (rev  / d) : 0.0
    dio = cogs > 0 ? inputs.inventory / (cogs / d)                : 0.0
    dpo = exp > 0  ? inputs.accounts_payable / (exp / d)          : 0.0
    ccc = dso + dio - dpo

    cr  = inputs.current_liabilities > 0 ?
          inputs.current_assets / inputs.current_liabilities : Inf
    qr  = inputs.current_liabilities > 0 ?
          (inputs.cash_and_investments + inputs.accounts_receivable_net) /
           inputs.current_liabilities : Inf

    wc  = inputs.current_assets - inputs.current_liabilities
    wc_pct = rev > 0 ? wc / rev : NaN

    WorkingCapitalMetrics(dso, dio, dpo, ccc, cr, qr, ccc, wc, wc_pct)
end

# ─────────────────────────────────────────────────────────────────────────────
# Target DSO model
# ─────────────────────────────────────────────────────────────────────────────

"""
    target_dso_model(;
        net_patient_revenue, current_dso, target_dso,
        days_in_period, bad_debt_rate_on_old_ar
    ) -> NamedTuple

Compute the cash-flow impact of achieving a target DSO from the current DSO.

# Arguments
- `net_patient_revenue::Float64`
- `current_dso::Float64`: Current DSO in days.
- `target_dso::Float64`: Target DSO in days (lower = better).
- `days_in_period::Int = 365`
- `bad_debt_rate_on_old_ar::Float64 = 0.15`: Fraction of AR > 90 days
  expected to be uncollectable.

# Returns
- `current_ar`, `target_ar`: AR balance at current vs target DSO.
- `ar_reduction_needed::Float64`: Cash that would be released.
- `one_time_cash_benefit::Float64`: After bad-debt haircut on old AR.
- `annual_interest_savings::Float64`: At 6.5% cost of capital.
- `days_to_achieve::Int`: Estimated weeks to close the DSO gap (heuristic).

# Example
```julia
r = target_dso_model(
    net_patient_revenue          = 8_500_000.0,
    current_dso                  = 52.4,
    target_dso                   = 42.0,
)
r.ar_reduction_needed    # \$241,644 of AR to collect
r.one_time_cash_benefit  # after bad-debt haircut
```
"""
function target_dso_model(;
    net_patient_revenue::Float64,
    current_dso::Float64,
    target_dso::Float64,
    days_in_period::Int = 365,
    bad_debt_rate_on_old_ar::Float64 = 0.15,
    cost_of_capital::Float64 = 0.065,
)
    current_dso >= target_dso ||
        @warn "target_dso ($target_dso) ≥ current_dso ($current_dso) — no improvement needed"

    daily_revenue = net_patient_revenue / days_in_period
    current_ar    = current_dso * daily_revenue
    target_ar     = target_dso  * daily_revenue
    ar_reduction  = max(0.0, current_ar - target_ar)

    # Haircut: old AR is less collectible
    net_cash = ar_reduction * (1.0 - bad_debt_rate_on_old_ar)
    annual_interest_saved = ar_reduction * cost_of_capital

    # Heuristic: achieving 1-day DSO reduction takes ~3 weeks of AR management effort
    days_to_achieve = round(Int, (current_dso - target_dso) * 3 * 7)

    (
        current_ar               = current_ar,
        target_ar                = target_ar,
        ar_reduction_needed      = ar_reduction,
        one_time_cash_benefit    = net_cash,
        bad_debt_haircut         = ar_reduction * bad_debt_rate_on_old_ar,
        annual_interest_savings  = annual_interest_saved,
        dso_improvement_days     = current_dso - target_dso,
        days_to_achieve          = days_to_achieve,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# AR Aging Analysis
# ─────────────────────────────────────────────────────────────────────────────

"""
    ARAgingBucket

One aging bucket in the AR aging schedule.

# Fields
- `label::String`: e.g. "0–30 days".
- `balance::Float64`: Total AR balance in this bucket (USD).
- `collection_rate::Float64`: Expected collection rate [0,1].
- `bad_debt_provision::Float64`: Expected write-off (USD).
- `net_realizable::Float64`: `balance × collection_rate`.
"""
struct ARAgingBucket
    label::String
    balance::Float64
    collection_rate::Float64
    bad_debt_provision::Float64
    net_realizable::Float64
end

"""
    AR_COLLECTION_BENCHMARKS

Typical net collection rates by AR aging bucket for rural hospitals.
Source: HFMA and CMS HCRIS analysis.
"""
const AR_COLLECTION_BENCHMARKS = (
    days_0_30  = 0.95,   # 95% expected collection — mostly recent, clean claims
    days_31_60 = 0.82,   # 82% — some denials being worked
    days_61_90 = 0.65,   # 65% — aging; denial management critical
    days_90p   = 0.38,   # 38% — >90 days; high bad-debt risk
)

"""
    ar_aging_analysis(;
        balance_0_30, balance_31_60, balance_61_90, balance_90_plus,
        custom_collection_rates
    ) -> NamedTuple

Perform AR aging analysis with expected collection rates and bad-debt provisioning.

# Returns
- `buckets::Vector{ARAgingBucket}`
- `total_gross_ar::Float64`
- `total_net_realizable::Float64`
- `total_bad_debt_provision::Float64`
- `effective_collection_rate::Float64`
- `implied_dso::Float64`: AR-weighted average days outstanding proxy.
- `action_priority::Symbol`: `:urgent` (>90 days > 25% of total), `:moderate`, `:healthy`.
"""
function ar_aging_analysis(;
    balance_0_30::Float64,
    balance_31_60::Float64,
    balance_61_90::Float64,
    balance_90_plus::Float64,
    custom_collection_rates::Union{Nothing, NamedTuple} = nothing,
)
    rates = isnothing(custom_collection_rates) ?
        AR_COLLECTION_BENCHMARKS : custom_collection_rates

    buckets = ARAgingBucket[
        ARAgingBucket("0–30 days",   balance_0_30,
            rates.days_0_30,
            balance_0_30   * (1 - rates.days_0_30),
            balance_0_30   * rates.days_0_30),
        ARAgingBucket("31–60 days",  balance_31_60,
            rates.days_31_60,
            balance_31_60  * (1 - rates.days_31_60),
            balance_31_60  * rates.days_31_60),
        ARAgingBucket("61–90 days",  balance_61_90,
            rates.days_61_90,
            balance_61_90  * (1 - rates.days_61_90),
            balance_61_90  * rates.days_61_90),
        ARAgingBucket("91+ days",    balance_90_plus,
            rates.days_90p,
            balance_90_plus * (1 - rates.days_90p),
            balance_90_plus * rates.days_90p),
    ]

    total_gross = sum(b.balance for b in buckets)
    total_net   = sum(b.net_realizable for b in buckets)
    total_bd    = sum(b.bad_debt_provision for b in buckets)
    eff_rate    = total_gross > 0 ? total_net / total_gross : 0.0

    # Implied DSO: midpoint-weighted average
    midpoints   = [15.0, 45.0, 75.0, 120.0]
    implied_dso = total_gross > 0 ?
        sum(buckets[i].balance * midpoints[i] for i in 1:4) / total_gross : 0.0

    pct_90p = total_gross > 0 ? balance_90_plus / total_gross : 0.0
    priority = pct_90p > 0.25 ? :urgent : pct_90p > 0.15 ? :moderate : :healthy

    (
        buckets                   = buckets,
        total_gross_ar            = total_gross,
        total_net_realizable      = total_net,
        total_bad_debt_provision  = total_bd,
        effective_collection_rate = eff_rate,
        implied_dso               = implied_dso,
        pct_90_plus_days          = pct_90p,
        action_priority           = priority,
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Working capital optimisation scenarios
# ─────────────────────────────────────────────────────────────────────────────

"""
    working_capital_scenarios(inputs::WorkingCapitalInputs; levers) -> Vector{NamedTuple}

Model the cash-flow impact of working capital improvement levers.

Each lever specifies a change: DSO reduction, DPO extension, or inventory reduction.
Returns the cash released and impact on CCC for each scenario.

# Arguments
- `levers::Vector{NamedTuple}`: Each with fields `(label, dso_change, dpo_change, inventory_change_pct)`.
  Positive `dpo_change` = extending payment terms (frees cash).
  Negative `dso_change` = reducing AR (frees cash).
  Negative `inventory_change_pct` = reducing inventory (frees cash).

# Example
```julia
levers = [
    (label="AR Acceleration", dso_change=-8.0, dpo_change=0.0, inventory_change_pct=0.0),
    (label="Extend AP Terms",  dso_change=0.0,  dpo_change=10.0, inventory_change_pct=0.0),
    (label="Combined",         dso_change=-5.0, dpo_change=8.0,  inventory_change_pct=-10.0),
]
scenarios = working_capital_scenarios(inputs; levers=levers)
```
"""
function working_capital_scenarios(
    inputs::WorkingCapitalInputs;
    levers::Vector{<:NamedTuple},
)
    base = compute_working_capital(inputs)
    d = Float64(inputs.days_in_period)
    daily_rev = inputs.net_patient_revenue / d
    daily_exp = inputs.total_operating_expenses / d
    daily_cogs = inputs.cost_of_supplies / d

    map(levers) do lever
        Δdso = get(lever, :dso_change, 0.0)
        Δdpo = get(lever, :dpo_change, 0.0)
        Δinv_pct = get(lever, :inventory_change_pct, 0.0)

        new_ar  = max(0.0, (base.dso + Δdso) * daily_rev)
        new_ap  = (base.dpo + Δdpo) * daily_exp
        new_inv = inputs.inventory * (1.0 + Δinv_pct / 100.0)

        ar_cash_released  = inputs.accounts_receivable_net - new_ar
        ap_cash_released  = new_ap - inputs.accounts_payable   # extending AP frees cash
        inv_cash_released = inputs.inventory - new_inv

        total_cash = ar_cash_released + ap_cash_released + inv_cash_released

        new_ccc = (base.dso + Δdso) + base.dio * (1 + Δinv_pct/100) - (base.dpo + Δdpo)

        (
            label               = get(lever, :label, "Scenario"),
            dso_new             = base.dso + Δdso,
            dpo_new             = base.dpo + Δdpo,
            ccc_new             = new_ccc,
            ccc_improvement     = base.ccc - new_ccc,
            ar_cash_released    = ar_cash_released,
            ap_cash_released    = ap_cash_released,
            inv_cash_released   = inv_cash_released,
            total_cash_released = total_cash,
            annual_interest_benefit = total_cash * 0.065,
        )
    end |> collect
end
