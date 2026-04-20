# Service Line Profitability Analysis Guide

## Overview

The Service Line Profitability module helps rural hospital CFOs answer the critical question: **Which services make money?**

This guide walks you through analyzing service line performance in less than 2 hours.

---

## Quick Start (15 minutes)

### 1. Gather Your Data

You need financial data for each service line:
- **Volume**: Number of cases/episodes
- **Revenue**: Total charges/reimbursement
- **Direct Costs**: Labor, supplies, equipment dedicated to that service
- **Total Overhead**: Hospital-wide indirect costs (utilities, admin, etc.)

Example data structure:

```julia
services = [
    ServiceLine(
        id="ORTHO",
        name="Orthopedic Surgery",
        department="Surgical",
        drg_codes=["469", "470"],
        volume=150,
        revenue=5_000_000.0,
        direct_cost=3_000_000.0
    ),
    # ... more services
]
```

### 2. Run the Analysis

```julia
result = analyze_service_lines(
    services,
    8_500_000.0,  # Total overhead to allocate
    allocation_method=:proportional
)
```

### 3. Review the Results

The analysis returns:
- **Total margin** across all services
- **Profitable vs unprofitable** service lines
- **Recommendations** for the CFO
- **Cost drivers** by service

---

## Key Concepts

### Service Line
A distinct clinical or operational unit (e.g., Cardiology, Emergency, ICU). Each service line has:
- **Volume**: Number of patients/cases
- **Revenue**: Reimbursement from payers
- **Direct Cost**: Costs directly attributable (staff, supplies)
- **Allocated Indirect Cost**: Share of overhead

### Profitability Metrics

**Contribution Margin** = Revenue - Direct Cost
- Shows if a service covers its own direct expenses
- Best for deciding whether to continue a service

**Allocated Margin** = Revenue - Direct Cost - Allocated Overhead
- Shows true profitability after including hospital costs
- Best for strategic decisions (expand vs divest)

**Margin %** = (Profit / Revenue) × 100
- Benchmark metric: Compare across services and against peers

### Cost Allocation Methods

Three methods available; each affects results:

#### 1. Proportional (Default)
Allocate overhead based on proportion of direct costs.
- Assumes overhead is driven by direct spending
- Most common for hospitals
- **Use when**: Direct costs correlate with overhead consumption

#### 2. Activity-Based
Allocate overhead based on proportion of volume (cases).
- Assumes overhead is driven by case numbers
- **Use when**: All services consume similar overhead per case

#### 3. Step-Down
First allocates to support services, then clinical services.
- Recognizes that some overhead supports other overhead
- More complex but more accurate
- **Use when**: You want sophisticated allocation

### Example: Which Method Changes Profitability?

```
Service Line: Emergency
Revenue: $3.0M
Direct Cost: $2.9M (97% of revenue)
Allocation Method: ?

Proportional:    Allocated overhead = $500K → MARGIN = $(3.0M - 2.9M - 0.5M) = -$400K (LOSS)
Activity-Based:  Allocated overhead = $700K → MARGIN = $(3.0M - 2.9M - 0.7M) = -$600K (LOSS)

Takeaway: ED is inherently unprofitable regardless of method
```

---

## Interpreting Results

### Green Flags (Healthy Service Lines)
- ✓ Margin % > 15%
- ✓ Above benchmark 75th percentile
- ✓ Volume > typical for rural hospitals
- ✓ Cost/case < benchmark

### Yellow Flags (Monitor)
- ⚠ Margin % 5-15%
- ⚠ At benchmark median
- ⚠ Declining volume year-over-year
- ⚠ Cost/case > benchmark

### Red Flags (Action Required)
- ✗ Margin % < 0% (losing money)
- ✗ Below benchmark 25th percentile
- ✗ Declining volume
- ✗ Cost/case >> benchmark

---

## Benchmark Comparison

The module includes benchmarks for typical rural hospitals:

| Service Line | Typical Margin % | Typical Cost/Case | Typical Volume |
|---|---|---|---|
| Orthopedic Surgery | 18.5% | $18,500 | 120 |
| Cardiology | 22.0% | $16,000 | 180 |
| General Surgery | 15.0% | $12,000 | 200 |
| Oncology | 25.0% | $32,000 | 80 |
| Emergency Medicine | 5.0% | $4,500 | 400 |
| Obstetrics | 8.0% | $8,500 | 150 |
| ICU | 12.0% | $18,000 | 150 |

**Note**: These are medians. Rural hospitals vary significantly by geography, payor mix, and quality.

---

## Case Study Example

### Community Hospital (250 beds)

**Scenario**: CFO has service line data and wants to know where to invest.

**Analysis**:
```
Result: 8 service lines analyzed
Profitable: 7/8 (Obstetrics is marginally profitable)
Overall Margin: 8.2%
Top Performer: Oncology (25% margin, $4.1M annual contribution)
Needs Work: Emergency (5% margin, high volume = essential but needs efficiency)
```

**Recommendations**:
1. Expand high-margin services (Oncology, Cardiology)
2. Improve Emergency efficiency (can't divest, but can reduce costs)
3. Partner with specialists for low-volume services
4. Monitor Obstetrics for cost control

---

## Common Scenarios

### Scenario 1: "Service X is Unprofitable — Should We Close It?"

```julia
# Check if it's essential (high volume, community need)
if service.volume > 200  # High volume
    # Can't close — focus on cost reduction
    sensitivity = sensitivity_analysis(service, 0.0, -0.10)  # 10% cost reduction
    # Can we break even with efficiency gains?
else
    # Consider partnership, collaboration, or divestment
end
```

### Scenario 2: "Which Service Should We Invest In?"

```julia
# Rank by contribution margin
rankings = rank_service_lines_by_metric(services, :margin)
# Invest in top 3 — they drive profitability
# Use profits to subsidize essential but low-margin services (ED, OB)
```

### Scenario 3: "We're Losing Money Overall. What's the Problem?"

```julia
# Check case mix
case_mix = case_mix_analysis(services)
# Check if concentrated in low-margin services

# Check efficiency
efficiency = efficiency_metrics(services)
# Is cost-to-revenue ratio high?

# Check allocation impact
result_alt = analyze_service_lines(services, overhead, allocation_method=:activity_based)
# Does allocation method affect conclusion?
```

---

## Advanced Features

### Sensitivity Analysis

Stress-test a service line with revenue/cost changes:

```julia
result = sensitivity_analysis(
    service_line,
    revenue_change=-0.05,  # 5% revenue decline
    cost_change=0.10       # 10% cost increase
)
# Output: New margin, breakeven volume, margin change %
```

### Case Mix Analysis

Understand distribution of volume and complexity:

```julia
analysis = case_mix_analysis(services)
# Returns: CV (volatility), concentration, min/max/median volumes
```

### Profitability Summary

Quick overview of all services:

```julia
summary = profitability_summary(services)
# Returns: mean margin, profitable count, profitability ratio
```

### Efficiency Metrics

Compare services on unit economics:

```julia
metrics = efficiency_metrics(services)
# Returns: revenue per case, cost per case, concentration
```

---

## Implementation Steps

### Step 1: Data Preparation (30 min)
1. Extract service line data from your system
2. Assign each service to a DRG or diagnostic code
3. Allocate costs to services (use accounting system or estimates)
4. Sum up total hospital overhead

### Step 2: Initial Analysis (20 min)
```julia
include("src/episode/ServiceLineTypes.jl")
include("src/episode/ServiceLineCostAllocation.jl")
include("src/episode/ServiceLineMetrics.jl")
include("src/episode/Benchmarking.jl")

result = analyze_service_lines(
    your_services,
    your_overhead,
    allocation_method=:proportional
)
```

### Step 3: Interpretation (30 min)
- Review profitability by service
- Compare to benchmarks
- Identify red/yellow/green flags

### Step 4: Action (variable)
- Cost reduction initiatives
- Pricing adjustments
- Volume growth strategies
- Potential partnerships or divestitures

---

## Tips for Success

### ✓ DO
- **Use realistic cost data** — Garbage in = garbage out
- **Validate with operations** — "Does this match your experience?"
- **Scenario test** — "What if we reduce costs by 10%?"
- **Track trends** — Repeat analysis quarterly
- **Benchmark externally** — Compare your results to peers

### ✗ DON'T
- **Blindly close unprofitable services** — Emergency, OB often run thin but are essential
- **Over-optimize** — Allocation methods are tools, not gospel truth
- **Ignore strategic factors** — Profitability isn't everything (access, quality, referrals matter)
- **Use allocation arbitrarily** — Choose method and stick with it for consistency
- **Make decisions based on Year 1 data** — Look at trends

---

## Troubleshooting

### Issue: All my services are unprofitable
**Possible causes**:
- Total overhead too high (re-check calculation)
- Reimbursement rates are low (payer mix issue)
- Cost allocation method too aggressive
- Cost data inflated

**Fix**: Try activity-based allocation, review cost assumptions

### Issue: Results seem wrong compared to expectations
**Possible causes**:
- Missing revenue components (ancillary, other payers)
- Costs not allocated properly to services
- Volume numbers incorrect

**Fix**: Validate data inputs with accounting, operations

### Issue: Benchmark results don't match my experience
**Possible causes**:
- Your hospital has different mix (e.g., more complex cases)
- Rural benchmark may not apply to your region
- Quality/teaching status affects costs

**Fix**: Use benchmarks as reference, not absolute

---

## References

### Data Sources for External Benchmarking
- CMS HCUP (Healthcare Cost and Utilization Project)
- Your state hospital association
- MGMA (Medical Group Management Association)
- Truven Health Analytics

### Further Reading
- "Competitive Advantage: Creating and Sustaining Superior Performance" by Michael Porter
- "Healthcare Supply Chain" by Nick Haycock
- "The Lean Hospital" by Mark Graban

---

## Questions?

If you have questions about:
- **Specific service line**: Check benchmarks table
- **Allocation method**: See "Cost Allocation Methods" section
- **Interpreting metrics**: See "Interpreting Results"
- **Implementation**: See "Implementation Steps"

---

**Created**: 2026-04-15
**Version**: 1.0
**Next Update**: Planned quarterly with actual benchmark data refresh
