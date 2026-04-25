"""
CMS benchmark constants, regulatory thresholds, and standard definitions.
"""

# CMS DRG payment rates (example base rates for 2024)
const CMS_BASE_DRG_RATE = 7_200.00  # USD per discharge (2024 estimate)
const CMS_WAGE_INDEX_MIN = 0.75     # Lowest geographic adjustment factor
const CMS_WAGE_INDEX_MAX = 1.85     # Highest geographic adjustment factor

# Quality measure benchmarks (CMS target rates)
const CMS_READMISSION_BENCHMARK = 0.15  # 15% or less
const CMS_MORTALITY_BENCHMARK = 0.05    # 5% or less
const CMS_SAFETY_BENCHMARK = 0.02       # 2% or less

# Hospital bed thresholds
const CAH_MAX_BEDS = 25               # Critical Access Hospital maximum
const SMALL_HOSPITAL_BEDS = (50, 99)  # Small hospital bed range
const MEDIUM_HOSPITAL_BEDS = (100, 249)
const LARGE_HOSPITAL_BEDS = (250, 399)

# RUCA codes (Rural-Urban Commuting Area)
const RUCA_METROPOLITAN = 1:3
const RUCA_MICROPOLITAN = 4:6
const RUCA_SMALL_TOWN = 7:9
const RUCA_RURAL = 10:12

# Financial thresholds
const BREAK_EVEN_MARGIN = 0.02           # 2% operating margin considered break-even
const FINANCIAL_DISTRESS_MARGIN = -0.05  # -5% triggers financial distress alert
const MINIMUM_CASH_DAYS = 30             # Days of cash on hand to maintain

# Statistical thresholds
const MIN_SAMPLE_SIZE_HYPOTHESIS_TEST = 30
const MIN_SAMPLE_SIZE_CONFIDENCE_INTERVAL = 25
const CONFIDENCE_LEVEL_DEFAULT = 0.95
const SIGNIFICANCE_LEVEL_DEFAULT = 0.05

# Geographic constants
const EARTH_RADIUS_KM = 6371.0  # km (WGS84)
const EARTH_RADIUS_MILES = 3959.0

# API/service defaults
const DEFAULT_API_TIMEOUT = 30  # seconds
const DEFAULT_CACHE_TTL = 3600  # seconds
const MAX_REQUEST_SIZE = 10_000_000  # bytes (10 MB)
