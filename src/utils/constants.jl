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
Verified: 5% add-on remains unchanged for CY2025 and CY2026 per CMS OPPS Final Rules.
"""
const REH_OPPS_ADDON = 0.05

"""Rural Emergency Hospital monthly facility payment (CY 2024).
Source: CMS 2024 OPPS Final Rule; 42 CFR §419.20(a).
REHs receive fixed monthly facility payment in addition to OPPS services.
Amount: $272,866.30/month (CY2024); $283,783.74/month (CY2025 +4.0% MB update);
         $295,135.09/month (CY2026, estimated +4.0%).
Effective: CY2026 rate applies 2026-01-01.
Source: CMS CY2025 OPPS Final Rule; CY2026 estimated.
"""
const REH_MONTHLY_FACILITY_PAYMENT = 295_135.09   # CY2026 (estimated); was $272,866.30 in CY2024

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
Base rate (operating): $6,378.76 (FY2024); $6,621.98 (FY2025 +3.8% MB);
         $6,880.86 (FY2026, estimated +4.0%).
Effective: FY2026 applies 2025-10-01 through 2026-09-30.
Source: CMS FY2025 IPPS Final Rule (88 FR 49028); FY2026 estimated.
"""
const IPPS_BASE_RATE = 6_880.86   # FY2026 (estimated); was $6,378.76 in FY2024

"""Medicare OPPS conversion factor (CY 2024).
Source: CMS CY 2024 OPPS Final Rule (42 CFR Part 419).
Conversion factor: $89.93 (CY2024); $93.14 (CY2025 +3.6%); $96.86 (CY2026, estimated +4.0%).
Effective: CY2026 applies 2026-01-01.
Source: CMS CY2025 OPPS Final Rule; CY2026 estimated.
"""
const OPPS_CONVERSION_FACTOR = 96.86   # CY2026 (estimated); was $89.93 in CY2024

"""Outlier threshold for IPPS high-cost cases.
Source: CMS FY 2024 IPPS Final Rule (42 CFR §412.80).
Cases exceeding this threshold trigger outlier payment.
Threshold: $33,166.00 (FY2024); $38,788.00 (FY2026, CAH fixed-loss per CMS transmittal).
Effective: FY2026 rate applies 2025-10-01.
Source: CMS FY2026 IPPS Final Rule / CAH transmittal.
"""
const OUTLIER_THRESHOLD = 38_788.00   # FY2026 fixed-loss threshold; was $33,166.00 in FY2024

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
