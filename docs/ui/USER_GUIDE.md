# Rural Hospital Economics Simulator — User Guide

## 1. Getting Started

Open the simulator in your browser. The left navigation drawer lists all analysis tabs. Use the **Financial Dashboard** as your starting point — it shows KPI cards for operating margin, days cash on hand, payer mix, and volume metrics.

**Basic workflow:**
1. Set up your hospital in **Hospital Profile**
2. Upload data via **Data Intake**
3. Run analyses from any tab
4. Export results with the **Export Bar** (CSV / XLSX) at the bottom of each tab

---

## 2. Data Intake Workflow

Navigate to **Data Intake** (`/data_intake`):
- Upload patient data (CSV) using the file upload component
- Supported columns: `patient_id`, `age`, `sex`, `diagnosis`, `los`, `cost`, `payer`
- Click **Validate** to check for errors; the error banner shows any field issues
- Proceed to **Data Preparation** to clean and transform records

---

## 3. Cost-Effectiveness Analysis Workflow

Navigate to **CEA** (`/cea`):
1. Enter interventions with cost and effectiveness values
2. Click **Calculate ICER** — the result table shows incremental cost-effectiveness ratios
3. Use **Sensitivity Analysis** to test assumptions across WTP thresholds
4. Export the results table as XLSX for reporting

---

## 4. Scenario Sensitivity Workflow

Navigate to **Sensitivity** (`/sensitivity`):
1. Select the parameter to vary (e.g., volume, reimbursement rate)
2. Set low / base / high values
3. Click **Run Sensitivity** — the tornado chart renders automatically
4. Use **Scenario Lab** (`/scenario_lab`) to save and compare named scenarios

---

## 5. Export & Reports

Every tab includes an **Export Bar** at the bottom with:
- **CSV** — flat comma-separated download of the current result table
- **XLSX** — multi-sheet workbook with inputs and outputs

For narrative exports, go to **Reports** (`/reports`) and click **Generate Report** to produce a PDF-ready summary of all active analyses.
