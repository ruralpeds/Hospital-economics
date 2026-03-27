# ============================================================================
# Constants for Rural Hospital Economics Simulator
# ============================================================================

module Constants

using Dates

# ---------------------------------------------------------------------------
# CMS Reimbursement Constants
# ---------------------------------------------------------------------------

"""Federal sequestration rate applied to Medicare payments (2%)."""
const SEQUESTRATION_RATE = 0.02

"""Bad debt reimbursement percentage for Medicare (65%)."""
const BAD_DEBT_REIMBURSEMENT_RATE = 0.65

"""Critical Access Hospital cost-based reimbursement rate (101%)."""
const CAH_COST_REIMBURSEMENT_RATE = 1.01

"""Rural Emergency Hospital OPPS add-on percentage (5%)."""
const REH_OPPS_ADDON = 0.05

"""Rural Emergency Hospital monthly facility payment (CY 2024)."""
const REH_MONTHLY_FACILITY_PAYMENT = 272866.30

"""Rural Emergency Hospital annual facility payment."""
const REH_ANNUAL_FACILITY_PAYMENT = REH_MONTHLY_FACILITY_PAYMENT * 12

"""Medicare wage index national average (baseline = 1.0)."""
const WAGE_INDEX_NATIONAL_AVG = 1.0

"""Medicare IPPS base rate (FY 2024 approx)."""
const IPPS_BASE_RATE = 6378.76

"""Medicare OPPS conversion factor (CY 2024 approx)."""
const OPPS_CONVERSION_FACTOR = 89.93

"""Outlier threshold for IPPS (FY 2024 approx)."""
const OUTLIER_THRESHOLD = 33166.0

"""Cost-of-living adjustment cap for CAH."""
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
