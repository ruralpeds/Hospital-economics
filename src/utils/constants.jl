# ============================================================================
# Constants for Rural Hospital Economics Simulator
# ============================================================================

module Constants

using Dates

# ---------------------------------------------------------------------------
# CMS Reimbursement Constants
# ---------------------------------------------------------------------------
# NOTE: These values are based on CY 2024 / FY 2024 rates published by CMS.
# Review and update annually when CMS publishes new rate updates (typically
# Jan 1 for CY rates, Oct 1 for FY rates).
# Last audit: 2026-04-27

"""Federal sequestration rate applied to Medicare payments.
Source: CMS Sequestration (2% permanent reduction).
Effective: 2013-present.
Value: 2% (0.02)
"""
const SEQUESTRATION_RATE = 0.02

"""Bad debt reimbursement percentage for Medicare.
Source: CMS Pub. 100-04, Chapter 3, §60.
Medicare reimburses 65% of bad debt written off under cost report.
Effective: 2020-present.
Value: 65% (0.65)
Note: CAH and certain hospitals may have different rates; see CAH_COST_REIMBURSEMENT_RATE.
"""
const BAD_DEBT_REIMBURSEMENT_RATE = 0.65

"""Critical Access Hospital cost-based reimbursement rate.
Source: 42 CFR §413.70; CMS Pub. 100-02, Chapter 12.
CAHs receive cost-based reimbursement + 1% enhancement for bad debt.
Effective: 2004-present.
Value: 101% of reasonable costs (1.01)
"""
const CAH_COST_REIMBURSEMENT_RATE = 1.01

"""Rural Emergency Hospital OPPS add-on percentage.
Source: 42 CFR §419.20; CMS REH Regulations effective 2024-01-01.
REHs receive 5% add-on to OPPS APC payment for certain services.
Effective: 2024-01-01.
Value: 5% (0.05)
TODO: Verify this is still 5% for CY 2025-2026.
"""
const REH_OPPS_ADDON = 0.05

"""Rural Emergency Hospital monthly facility payment (CY 2024).
Source: CMS 2024 OPPS Final Rule; 42 CFR §419.20(a).
REHs receive fixed monthly facility payment in addition to OPPS services.
Amount: $272,866.30/month (CY 2024).
Effective: 2024-01-01.
TODO: Update for CY 2025-2026 rates (typically indexed by market basket).
See CMS 2025 OPPS Final Rule for updated amount.
"""
const REH_MONTHLY_FACILITY_PAYMENT = 272866.30

"""Rural Emergency Hospital annual facility payment (derived from monthly).
Calculation: REH_MONTHLY_FACILITY_PAYMENT * 12
"""
const REH_ANNUAL_FACILITY_PAYMENT = REH_MONTHLY_FACILITY_PAYMENT * 12

"""Medicare wage index national average (baseline = 1.0).
Source: CMS Wage Index files (annual).
Effective: 2024.
Note: Individual hospitals apply their local wage index; this is the national average.
"""
const WAGE_INDEX_NATIONAL_AVG = 1.0

"""Medicare IPPS base rate (FY 2024).
Source: CMS FY 2024 IPPS Final Rule (42 CFR Part 412).
Base rate (operating): $6,378.76 per discharge adjusted for DRG weights.
Effective: 2023-10-01 through 2024-09-30 (Federal FY 2024).
TODO: Update for FY 2025-2026 rates (typically published in August).
See CMS FY 2025 IPPS Final Rule.
"""
const IPPS_BASE_RATE = 6378.76

"""Medicare OPPS conversion factor (CY 2024).
Source: CMS CY 2024 OPPS Final Rule (42 CFR Part 419).
Conversion factor: $89.93 per APC unit.
Effective: 2024-01-01 through 2024-12-31.
TODO: Update for CY 2025-2026 (typically January 1 effective date).
See CMS CY 2025 OPPS Final Rule.
"""
const OPPS_CONVERSION_FACTOR = 89.93

"""Outlier threshold for IPPS high-cost cases.
Source: CMS FY 2024 IPPS Final Rule (42 CFR §412.80).
Cases exceeding this threshold trigger outlier payment.
Threshold: $33,166.00 (FY 2024).
Effective: 2023-10-01 through 2024-09-30.
TODO: Update for FY 2025-2026 (typically increases with cost inflation).
See CMS FY 2025 IPPS Final Rule for updated threshold.
Note: This is approximate; actual threshold may vary by hospital type.
"""
const OUTLIER_THRESHOLD = 33166.0

"""Cost-of-living adjustment cap for CAH updates.
Source: CMS CAH Regulations (42 CFR §413.70).
CAH updates are capped at 125% of prior year.
Value: 1.25
Effective: Long-standing CAH policy.
"""
const COLA_CAP = 1.25

# ---------------------------------------------------------------------------
# Benchmark Ratios — National Medians for Critical Access Hospitals
# ---------------------------------------------------------------------------

"""Operating margin benchmark (national CAH median)."""
const BENCHMARK_OPERATING_MARGIN = -0.005

"""Total margin benchmark (national CAH median)."""
const BENCHMARK_TOTAL_MARGIN = 0.024

"""Days cash on hand benchmark (national CAH median)."""
const BENCHMARK_DAYS_CASH = 95.0

"""Current ratio benchmark (national CAH median)."""
const BENCHMARK_CURRENT_RATIO = 2.45

"""Debt-to-capitalization benchmark (national CAH median)."""
const BENCHMARK_DEBT_TO_CAP = 0.32

"""Average age of plant benchmark (years, national CAH median)."""
const BENCHMARK_AVG_AGE_OF_PLANT = 12.8

"""FTE per adjusted occupied bed benchmark (national CAH median)."""
const BENCHMARK_FTE_PER_AOB = 6.2

"""Medicare cost-to-charge ratio benchmark (national CAH median)."""
const BENCHMARK_MEDICARE_CCR = 0.42

"""Salary-to-revenue ratio benchmark (national CAH median)."""
const BENCHMARK_SALARY_TO_REVENUE = 0.52

"""Outpatient revenue share benchmark (national CAH median)."""
const BENCHMARK_OUTPATIENT_SHARE = 0.72

# ---------------------------------------------------------------------------
# Federal Fiscal Year Dates
# ---------------------------------------------------------------------------

"""Start date of the federal fiscal year for a given calendar year."""
ffy_start(year::Int) = Date(year - 1, 10, 1)

"""End date of the federal fiscal year for a given calendar year."""
ffy_end(year::Int) = Date(year, 9, 30)

"""Determine which federal fiscal year a date belongs to."""
function federal_fiscal_year(d::Date)
    return month(d) >= 10 ? year(d) + 1 : year(d)
end

# ---------------------------------------------------------------------------
# Standard Cost Center Codes (CMS Form 2552-10)
# ---------------------------------------------------------------------------

"""Standard cost center codes and names from CMS Form 2552-10."""
const COST_CENTER_CODES = Dict(
    "0500" => "Adults & Pediatrics (General)",
    "0600" => "Intensive Care Unit",
    "0700" => "Coronary Care Unit",
    "0800" => "Burn Intensive Care Unit",
    "0900" => "Surgical Intensive Care Unit",
    "1000" => "Nursery",
    "1100" => "Skilled Nursing Facility",
    "1200" => "Nursing Facility",
    "1300" => "Other Long-Term Care",
    "1400" => "Subprovider - IPF",
    "1500" => "Subprovider - IRF",
    "1600" => "Subprovider - Other",
    "2500" => "Operating Room",
    "2600" => "Recovery Room",
    "2700" => "Delivery Room & Labor Room",
    "2800" => "Anesthesiology",
    "2900" => "Radiology - Diagnostic",
    "3000" => "Radiology - Therapeutic",
    "3100" => "Radioisotope",
    "3200" => "Laboratory",
    "3300" => "Blood Storing & Processing",
    "3400" => "Respiratory Therapy",
    "3500" => "Physical Therapy",
    "3600" => "Occupational Therapy",
    "3700" => "Speech Pathology",
    "3800" => "Electrocardiology",
    "3900" => "Electroencephalography",
    "4000" => "Medical Supplies Charged to Patients",
    "4100" => "Drugs Charged to Patients",
    "4200" => "Renal Dialysis",
    "4300" => "Organ Acquisition",
    "6000" => "Clinic",
    "6100" => "Emergency",
    "6200" => "Observation",
    "6300" => "Rural Health Clinic",
    "6400" => "Federally Qualified Health Center",
    "6500" => "Other Outpatient Services",
)

# ---------------------------------------------------------------------------
# Simulation Defaults
# ---------------------------------------------------------------------------

"""Default simulation horizon (years)."""
const DEFAULT_SIMULATION_YEARS = 10

"""Default discount rate for NPV calculations."""
const DEFAULT_DISCOUNT_RATE = 0.03

"""Default inflation rate for cost projections."""
const DEFAULT_INFLATION_RATE = 0.025

"""Default Medicare payment update factor."""
const DEFAULT_MEDICARE_UPDATE_FACTOR = 0.02

end # module Constants
