# Sample HCRIS Data

These files contain **synthetic** data in the format of CMS Healthcare Cost Reporting
Information System (HCRIS) extracts. They are for development and testing only.

## Files

- `sample_hcris_extract.csv` — Report-level metadata (provider numbers, fiscal years, filing dates)
- `sample_hcris_numeric.csv` — Worksheet numeric data (costs, revenues, volumes)

## Worksheet Codes

| Code | Worksheet | Content |
|------|-----------|---------|
| S200001 | Worksheet S-2 | Hospital identification and revenue data |
| S300001 | Worksheet S-3 | Statistical data (costs, volumes, FTEs) |
| G200001 | Worksheet G-2 | Balance sheet data |

## Data Sources

Real HCRIS data is available from:
- https://www.cms.gov/data-research/statistics-trends-and-reports/cost-reports
- HCRIS User Documentation: https://www.cms.gov/Research-Statistics-Data-and-Systems/Downloadable-Public-Use-Files/Cost-Reports

## Important

This is **synthetic test data** that mimics HCRIS format. It does NOT contain
real hospital financial information. For actual analysis, download HCRIS data
from CMS.
