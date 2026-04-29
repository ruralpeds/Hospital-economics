"""
    reciprocal_cost_allocation.jl — Hospital Cost Allocation Methods (MBA Gap C-06)

Implements both methods used for allocating overhead (non-patient-care)
department costs to patient-care departments:

1. **Step-Down Method** — the CMS-mandated method for Medicare cost reports
   (Worksheet A). Allocates overhead departments in sequence; once allocated,
   a department cannot receive further allocations. Simple but biased — it
   understates costs for departments allocated early in the sequence.

2. **Simultaneous Reciprocal Method** — solves a system of linear equations
   to handle mutual services between overhead departments. More accurate but
   not required by CMS. Used for internal management accounting and service-
   line costing to avoid the step-down sequence bias.

## Example: Housekeeping allocates 15% of its services to Dietary.
   Dietary allocates 8% of its services to Housekeeping.
   Step-down ignores this after one is allocated; reciprocal handles it exactly.

## Mathematical formulation (Reciprocal)
Let x_i = total cost allocated FROM overhead department i (direct + reallocated).
x_i = direct_cost_i + Σ_j (s_{ji} × x_j)  for all overhead departments j ≠ i

where s_{ji} = fraction of department j's services consumed by department i.
This is a linear system: (I − S) x = c → x = (I − S)⁻¹ c

After solving for x, allocate residual amounts to patient-care departments
using the respective allocation statistics.

References:
- CMS Form 2552-10, Worksheet A.
- Horngren C et al (2015). Cost Accounting: A Managerial Emphasis, 15e. Ch. 15.
- Finkler S, Ward D, Baker J (2007). Essentials of Cost Accounting for Healthcare.
- Ward D (2006). Reciprocal cost allocation for hospital departments. JHFM.
"""

using LinearAlgebra
using Statistics
using Printf

# ─────────────────────────────────────────────────────────────────────────────
# Cost center definitions
# ─────────────────────────────────────────────────────────────────────────────

"""
    CostCenterType

Classification of a hospital cost center.
- `:overhead`: Non-patient-care (admin, housekeeping, dietary, plant operations).
  Costs must be allocated to patient-care departments.
- `:patient_care`: Direct care departments (nursing units, OR, ED, lab).
  Receive allocations from overhead departments.
"""
@enum CostCenterType overhead=1 patient_care=2

"""
    CostCenter

One hospital cost center (department) in the allocation model.

# Fields
- `id::Symbol`
- `name::String`
- `type::CostCenterType`
- `direct_cost::Float64`: Direct cost assigned to this department (USD/yr).
- `step_sequence::Int`: Step-down allocation order (lower = allocated first).
  Used only for step-down method; ignored in reciprocal.
"""
@kwdef struct CostCenter
    id::Symbol
    name::String
    type::CostCenterType
    direct_cost::Float64
    step_sequence::Int = 99   # patient-care departments default to end
end

"""
    AllocationBase

The statistics used to allocate one overhead department's costs to other departments.

# Fields
- `from_dept::Symbol`: Source overhead department.
- `to_dept::Symbol`: Receiving department (overhead or patient-care).
- `statistic_value::Float64`: e.g. square footage, FTEs, meals served, etc.
- `statistic_name::String`: Description of the allocation statistic.
"""
@kwdef struct AllocationBase
    from_dept::Symbol
    to_dept::Symbol
    statistic_value::Float64
    statistic_name::String = "unspecified"
end

# ─────────────────────────────────────────────────────────────────────────────
# Allocation model
# ─────────────────────────────────────────────────────────────────────────────

"""
    CostAllocationModel

Complete cost allocation model for a hospital.

# Fields
- `departments::Vector{CostCenter}`
- `allocation_bases::Vector{AllocationBase}`: All department-to-department statistics.
"""
struct CostAllocationModel
    departments::Vector{CostCenter}
    allocation_bases::Vector{AllocationBase}
end

"""
    AllocationResult

Result of cost allocation for one patient-care department.

# Fields
- `dept_id::Symbol`
- `dept_name::String`
- `direct_cost::Float64`
- `allocated_overhead::Dict{Symbol,Float64}`: Amount received from each overhead dept.
- `total_allocated::Float64`
- `total_cost::Float64`: direct + total_allocated.
"""
struct AllocationResult
    dept_id::Symbol
    dept_name::String
    direct_cost::Float64
    allocated_overhead::Dict{Symbol,Float64}
    total_allocated::Float64
    total_cost::Float64
end

"""
    AllocationSummary

Summary of a full hospital cost allocation run.

# Fields
- `method::Symbol`: `:step_down` or `:reciprocal`.
- `results::Vector{AllocationResult}`: One per patient-care department.
- `overhead_dept_totals::Dict{Symbol,Float64}`: Total allocated FROM each overhead dept.
- `total_direct_cost::Float64`: Sum of all direct costs (check: should equal sum of result total costs).
- `check_sum_error::Float64`: Absolute difference between total direct costs and sum of allocated totals.
"""
struct AllocationSummary
    method::Symbol
    results::Vector{AllocationResult}
    overhead_dept_totals::Dict{Symbol,Float64}
    total_direct_cost::Float64
    check_sum_error::Float64
end

# ─────────────────────────────────────────────────────────────────────────────
# Helper: build allocation fraction matrix
# ─────────────────────────────────────────────────────────────────────────────

"""
    _build_allocation_fractions(model::CostAllocationModel) -> Dict{Symbol,Dict{Symbol,Float64}}

For each overhead department, compute the fraction of its allocation statistic
that goes to each receiving department (normalised so they sum to 1.0).
"""
function _build_allocation_fractions(
    model::CostAllocationModel,
)::Dict{Symbol, Dict{Symbol, Float64}}
    fracs = Dict{Symbol, Dict{Symbol, Float64}}()

    overhead_ids = [d.id for d in model.departments if d.type == overhead]

    for src_id in overhead_ids
        bases = filter(a -> a.from_dept == src_id, model.allocation_bases)
        isempty(bases) && continue

        total_stat = sum(a.statistic_value for a in bases)
        total_stat > 0 || continue

        fracs[src_id] = Dict(a.to_dept => a.statistic_value / total_stat for a in bases)
    end
    fracs
end

# ─────────────────────────────────────────────────────────────────────────────
# Method 1: Step-Down Allocation
# ─────────────────────────────────────────────────────────────────────────────

"""
    step_down_allocation(model::CostAllocationModel) -> AllocationSummary

Perform step-down (sequential) cost allocation.

Overhead departments are allocated in `step_sequence` order. Once a department
has been allocated, it cannot receive further overhead allocations. The
allocation base fractions are re-normalised after each step to exclude already-
allocated overhead departments.

This matches CMS Worksheet A methodology for Medicare cost reports.
"""
function step_down_allocation(model::CostAllocationModel)::AllocationSummary
    fracs = _build_allocation_fractions(model)

    # Build a mutable pool of costs (direct + received allocations)
    dept_cost = Dict(d.id => d.direct_cost for d in model.departments)
    allocated_from = Dict{Symbol, Dict{Symbol,Float64}}(
        d.id => Dict{Symbol,Float64}() for d in model.departments if d.type == patient_care
    )

    # Sort overhead depts by step_sequence
    overhead_depts = sort(
        filter(d -> d.type == overhead, model.departments);
        by=d -> d.step_sequence,
    )

    allocated_set = Set{Symbol}()

    for oh_dept in overhead_depts
        src   = oh_dept.id
        pool  = dept_cost[src]
        pool == 0.0 && (push!(allocated_set, src); continue)

        # Get allocation bases, excluding already-allocated overhead depts
        src_fracs = get(fracs, src, Dict{Symbol,Float64}())
        valid_recipients = filter(
            kv -> kv[1] ∉ allocated_set && kv[1] != src,
            src_fracs,
        )
        isempty(valid_recipients) && (push!(allocated_set, src); continue)

        # Re-normalise fractions
        total_valid = sum(values(valid_recipients))
        total_valid > 0 || (push!(allocated_set, src); continue)

        for (rec_id, frac) in valid_recipients
            alloc_amt = pool * frac / total_valid
            dept_cost[rec_id] = get(dept_cost, rec_id, 0.0) + alloc_amt
            if haskey(allocated_from, rec_id)
                allocated_from[rec_id][src] =
                    get(allocated_from[rec_id], src, 0.0) + alloc_amt
            end
        end

        dept_cost[src] = 0.0
        push!(allocated_set, src)
    end

    _build_allocation_summary(:step_down, model, dept_cost, allocated_from)
end

# ─────────────────────────────────────────────────────────────────────────────
# Method 2: Simultaneous Reciprocal Allocation
# ─────────────────────────────────────────────────────────────────────────────

"""
    reciprocal_allocation(model::CostAllocationModel) -> AllocationSummary

Perform simultaneous reciprocal cost allocation.

Solves the linear system (I − S)x = c where:
  S = matrix of inter-overhead allocation fractions
  c = vector of direct costs for overhead departments
  x = total costs to allocate from each overhead department (after reciprocation)

After solving for x, the residual (x_i minus amounts allocated to other overhead
departments) is distributed to patient-care departments.

Advantages over step-down:
1. No artificial sequence bias — all mutual dependencies resolved simultaneously.
2. Each department's allocated overhead reflects its true consumption of all services.
3. Required for accurate service-line costing and TDABC reconciliation.
"""
function reciprocal_allocation(model::CostAllocationModel)::AllocationSummary
    fracs = _build_allocation_fractions(model)

    overhead_depts = filter(d -> d.type == overhead, model.departments)
    patient_depts  = filter(d -> d.type == patient_care, model.departments)
    n_oh = length(overhead_depts)

    oh_ids = [d.id for d in overhead_depts]
    oh_idx = Dict(id => i for (i, id) in enumerate(oh_ids))

    # Build S matrix: S[i,j] = fraction of overhead dept j allocated to overhead dept i
    S = zeros(n_oh, n_oh)
    for (j, src_id) in enumerate(oh_ids)
        src_fracs = get(fracs, src_id, Dict{Symbol,Float64}())
        for (rec_id, frac) in src_fracs
            haskey(oh_idx, rec_id) || continue
            i = oh_idx[rec_id]
            S[i, j] = frac
        end
    end

    # Direct cost vector
    c = [d.direct_cost for d in overhead_depts]

    # Solve (I − S)x = c
    A = I - S
    x = try
        A \ c
    catch
        # Near-singular: use pseudo-inverse
        pinv(A) * c
    end

    # Now distribute x to patient-care departments
    dept_cost = Dict(d.id => d.direct_cost for d in model.departments)
    allocated_from = Dict{Symbol, Dict{Symbol,Float64}}(
        d.id => Dict{Symbol,Float64}() for d in patient_depts
    )

    for (j, src_id) in enumerate(oh_ids)
        src_fracs = get(fracs, src_id, Dict{Symbol,Float64}())
        total_x   = x[j]

        for pc_dept in patient_depts
            frac = get(src_fracs, pc_dept.id, 0.0)
            frac == 0.0 && continue
            alloc_amt = total_x * frac
            allocated_from[pc_dept.id][src_id] =
                get(allocated_from[pc_dept.id], src_id, 0.0) + alloc_amt
        end
    end

    # Recompute dept totals for patient-care
    for pc_dept in patient_depts
        dept_cost[pc_dept.id] = pc_dept.direct_cost +
            sum(values(allocated_from[pc_dept.id]))
    end

    # Zero out overhead departments (fully allocated)
    for oh_dept in overhead_depts
        dept_cost[oh_dept.id] = 0.0
    end

    _build_allocation_summary(:reciprocal, model, dept_cost, allocated_from)
end

# ─────────────────────────────────────────────────────────────────────────────
# Internal helper: build summary
# ─────────────────────────────────────────────────────────────────────────────

function _build_allocation_summary(
    method::Symbol,
    model::CostAllocationModel,
    dept_cost::Dict{Symbol,Float64},
    allocated_from::Dict{Symbol, Dict{Symbol,Float64}},
)::AllocationSummary
    patient_depts = filter(d -> d.type == patient_care, model.departments)
    overhead_ids  = [d.id for d in model.departments if d.type == overhead]

    results = map(patient_depts) do dept
        alloc = get(allocated_from, dept.id, Dict{Symbol,Float64}())
        total_alloc = sum(values(alloc))
        AllocationResult(
            dept.id, dept.name,
            dept.direct_cost, alloc,
            total_alloc,
            dept.direct_cost + total_alloc,
        )
    end

    oh_totals = Dict{Symbol,Float64}()
    for src in overhead_ids
        oh_totals[src] = sum(
            get(r.allocated_overhead, src, 0.0) for r in results
        )
    end

    total_direct = sum(d.direct_cost for d in model.departments)
    total_allocated = sum(r.total_cost for r in results)
    check_err = abs(total_direct - total_allocated)

    AllocationSummary(method, results, oh_totals, total_direct, check_err)
end

# ─────────────────────────────────────────────────────────────────────────────
# Comparison utility
# ─────────────────────────────────────────────────────────────────────────────

"""
    compare_allocation_methods(
        model::CostAllocationModel
    ) -> Vector{NamedTuple}

Run both step-down and reciprocal methods and compare total cost
per patient-care department.

Returns a vector of NamedTuples with:
`(dept_name, step_down_total, reciprocal_total, difference, pct_difference)`

The difference reveals the step-down sequence bias — departments with high
mutual service consumption with early-allocated overhead departments are
understated in step-down.
"""
function compare_allocation_methods(
    model::CostAllocationModel,
)::Vector{NamedTuple}
    sd = step_down_allocation(model)
    rec = reciprocal_allocation(model)

    sd_dict  = Dict(r.dept_id => r.total_cost for r in sd.results)
    rec_dict = Dict(r.dept_id => r.total_cost for r in rec.results)

    all_ids = union(keys(sd_dict), keys(rec_dict))
    rows = map(collect(all_ids)) do id
        sd_v  = get(sd_dict, id, 0.0)
        rec_v = get(rec_dict, id, 0.0)
        diff  = rec_v - sd_v
        dept_name = let d = findfirst(x -> x.id == id, model.departments)
            isnothing(d) ? string(id) : model.departments[d].name
        end
        (
            dept_id         = id,
            dept_name       = dept_name,
            step_down_total = sd_v,
            reciprocal_total = rec_v,
            difference      = diff,
            pct_difference  = sd_v > 0 ? diff / sd_v * 100 : NaN,
        )
    end
    sort(rows; by=r -> -abs(r.difference))
end
