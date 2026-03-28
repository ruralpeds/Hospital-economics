/**
 * Shared test data and constants for e2e tests.
 * Values mirror typical rural hospital defaults used by the Stipple models.
 */

export const TEST_HOSPITAL = {
  name: 'Community Memorial Hospital',
  state: 'KS',
  county: 'Russell',
  zip: '67665',
  type: 'CAH',
  beds: 25,
  providerNumber: '171301',
} as const;

export const FINANCIAL_DEFAULTS = {
  totalRevenue: 18_000_000,
  netPatientRevenue: 15_000_000,
  totalOperatingExpenses: 17_500_000,
  operatingMargin: -0.028,
  daysCashOnHand: 45,
  casesMixIndex: 1.05,
} as const;

export const SLIDER_DEFAULTS = {
  edVisits: 4500,
  ipDischarges: 350,
  medicarePct: 0.55,
  commercialPct: 0.15,
  inflationRate: 0.035,
  travelNursePct: 0.05,
  avgLengthOfStay: 3.2,
} as const;

/** All routes defined in app/routes.jl with their expected page titles. */
export const ROUTES = [
  { path: '/dashboard', title: 'Financial Dashboard', nav: 'Financial Dashboard' },
  { path: '/profile', title: 'Hospital Profile', nav: 'Hospital Profile' },
  { path: '/scenarios', title: 'Scenario Builder', nav: 'Scenario Builder' },
  { path: '/simulate', title: 'Run Simulation', nav: 'Run Simulation' },
  { path: '/results', title: 'Results Explorer', nav: 'Results Explorer' },
  { path: '/education', title: 'Education Center', nav: 'Education Center' },
  { path: '/financial-sim', title: 'Financial Simulator' },
  { path: '/cost-structure', title: 'Cost Structure' },
  { path: '/cost-reimbursement', title: 'Cost Reimbursement' },
  { path: '/payer-margin', title: 'Payer Margin' },
  { path: '/service-lines', title: 'Service Line' },
  { path: '/340b', title: '340B' },
  { path: '/revenue-cycle', title: 'Revenue Cycle' },
  { path: '/break-even', title: 'Break-even' },
  { path: '/cash-flow', title: 'Cash Flow' },
  { path: '/sensitivity', title: 'Sensitivity' },
  { path: '/debt-capacity', title: 'Debt Capacity' },
  { path: '/workforce', title: 'Workforce' },
  { path: '/benchmark', title: 'Benchmarking' },
  { path: '/conversion', title: 'REH Conversion' },
  { path: '/closure-risk', title: 'Closure Risk' },
  { path: '/staffing', title: 'Staffing' },
  { path: '/payer-negotiation', title: 'Payer Negotiation' },
  { path: '/community-impact', title: 'Community Impact' },
  { path: '/strategic-plan', title: 'Strategic Plan' },
  { path: '/policy', title: 'Policy Impact' },
] as const;

/** Routes that appear in the left navigation drawer. */
export const NAV_DRAWER_LINKS = [
  { label: 'Financial Dashboard', href: '/dashboard' },
  { label: 'Hospital Profile', href: '/profile' },
  { label: 'Scenario Builder', href: '/scenarios' },
  { label: 'Run Simulation', href: '/simulate' },
  { label: 'Results Explorer', href: '/results' },
  { label: 'REH Conversion Wizard', href: '/conversion' },
  { label: 'Closure Risk Assessment', href: '/closure-risk' },
  { label: 'Staffing Optimizer', href: '/staffing' },
  { label: 'Education Center', href: '/education' },
] as const;

/** API simulation endpoints (POST). */
export const SIMULATION_ENDPOINTS = [
  '/api/simulate/deterministic',
  '/api/simulate/monte-carlo',
  '/api/simulate/abm',
  '/api/simulate/system-dynamics',
  '/api/simulate/des',
] as const;

/** API optimization endpoints (POST). */
export const OPTIMIZATION_ENDPOINTS = [
  '/api/optimize/staffing',
  '/api/optimize/portfolio',
] as const;

/** API data import/export endpoints (POST). */
export const DATA_ENDPOINTS = [
  '/api/import/hcris',
  '/api/import/csv',
  '/api/export/csv',
  '/api/export/json',
] as const;
