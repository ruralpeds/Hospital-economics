"""
    distress_scoring.jl — Altman Z″ and Beneish M-score distress indicators

Adapted for nonprofit hospitals and private firms.
"""

# ─────────────────────────────────────────────────────────────────────────────
# Types
# ─────────────────────────────────────────────────────────────────────────────

"""
    AltmanZScore

Altman Z″-score (private firm / nonprofit variant).
Z″ = 6.56·X1 + 3.26·X2 + 6.72·X3 + 1.05·X4
Bands: Z″ > 2.60 safe; 1.10 < Z″ ≤ 2.60 grey; Z″ ≤ 1.10 distress.
"""
@kwdef struct AltmanZScore
    z_double_prime::Float64
    band::Symbol  # :safe, :grey, :distress
    x1_working_capital_ratio::Float64
    x2_retained_earnings_ratio::Float64
    x3_ebit_ratio::Float64
    x4_equity_ratio::Float64
end

"""
    BeneishMScore

Beneish M-score for earnings quality / manipulation detection.
M > -1.78 indicates likely earnings manipulation.
"""
@kwdef struct BeneishMScore
    m_score::Float64
    flag_manipulation::Bool
    dsri::Float64
    gmi::Float64
    aqi::Float64
    sgi::Float64
    depi::Float64
    sgai::Float64
    lvgi::Float64
    tata::Float64
end

# ─────────────────────────────────────────────────────────────────────────────
# Altman Z″-Score
# ─────────────────────────────────────────────────────────────────────────────

"""
    altman_z_double_prime(
        financials::NamedTuple,
        balance_sheet::BalanceSheetSnapshot
    )::AltmanZScore

Compute Altman Z″-score for nonprofit hospitals and private firms.

# Components
- X1 = Working Capital / Total Assets
- X2 = Retained Earnings / Total Assets  (≈ Net Assets Unrestricted for nonprofits)
- X3 = EBIT / Total Assets
- X4 = Book Value of Equity / Total Liabilities

# Coefficients
Z″ = 6.56·X1 + 3.26·X2 + 6.72·X3 + 1.05·X4

# Returns
AltmanZScore with components and distress band classification.
"""
function altman_z_double_prime(
    financials::NamedTuple,
    balance_sheet::BalanceSheetSnapshot
)::AltmanZScore
    # Compute total assets
    current_assets = balance_sheet.cash_and_equivalents +
                     balance_sheet.short_term_investments +
                     balance_sheet.accounts_receivable_net +
                     balance_sheet.inventory +
                     balance_sheet.other_current_assets
    net_ppe = balance_sheet.gross_ppe - balance_sheet.accumulated_depreciation
    total_assets = current_assets + net_ppe +
                   balance_sheet.long_term_investments +
                   balance_sheet.other_lt_assets

    # Compute working capital
    current_liabilities = balance_sheet.accounts_payable +
                         balance_sheet.accrued_expenses +
                         balance_sheet.current_portion_lt_debt +
                         balance_sheet.other_current_liabilities
    working_capital = current_assets - current_liabilities

    # Compute total liabilities
    total_liabilities = current_liabilities +
                        balance_sheet.long_term_debt +
                        balance_sheet.other_lt_liabilities

    # Compute net assets (retained earnings proxy for nonprofits)
    net_assets = balance_sheet.net_assets_unrestricted +
                 balance_sheet.net_assets_temp_restricted +
                 balance_sheet.net_assets_perm_restricted

    # Extract EBIT
    ebit = Float64(get(financials, :ebit, 0.0))

    # Compute Z″ components (X1, X2, X3, X4)
    x1 = total_assets > 0 ? working_capital / total_assets : 0.0
    x2 = total_assets > 0 ? net_assets / total_assets : 0.0
    x3 = total_assets > 0 ? ebit / total_assets : 0.0
    x4 = total_liabilities > 0 ? net_assets / total_liabilities : 0.0

    # Compute Z″
    z_score = 6.56 * x1 + 3.26 * x2 + 6.72 * x3 + 1.05 * x4

    # Classify band
    band = if z_score > 2.60
        :safe
    elseif z_score > 1.10
        :grey
    else
        :distress
    end

    return AltmanZScore(
        z_double_prime = z_score,
        band = band,
        x1_working_capital_ratio = x1,
        x2_retained_earnings_ratio = x2,
        x3_ebit_ratio = x3,
        x4_equity_ratio = x4
    )
end

# ─────────────────────────────────────────────────────────────────────────────
# Beneish M-Score
# ─────────────────────────────────────────────────────────────────────────────

"""
    beneish_m_score(
        financials_current::NamedTuple,
        financials_prior::NamedTuple,
        balance_sheet_current::BalanceSheetSnapshot,
        balance_sheet_prior::BalanceSheetSnapshot
    )::BeneishMScore

Compute Beneish M-score for earnings quality screening.

# Components
- DSRI = Days Sales Receivable Index
- GMI = Gross Margin Index
- AQI = Asset Quality Index
- SGI = Sales Growth Index
- DEPI = Depreciation Index
- SGAI = SG&A Index
- LVGI = Leverage Index
- TATA = Total Accruals to Total Assets

M = -4.40 - 0.920·DSRI - 0.528·GMI - 0.404·AQI + 0.892·SGI - 0.115·DEPI

# Returns
BeneishMScore with M-score and manipulation flag (M > -1.78 ⇒ likely manipulator).
"""
function beneish_m_score(
    financials_current::NamedTuple,
    financials_prior::NamedTuple,
    balance_sheet_current::BalanceSheetSnapshot,
    balance_sheet_prior::BalanceSheetSnapshot
)::BeneishMScore
    # Extract revenues
    revenue_current = Float64(get(financials_current, :total_operating_revenue, 1.0))
    revenue_prior = Float64(get(financials_prior, :total_operating_revenue, 1.0))

    # Extract cost of goods sold (proxy: operating expenses)
    cogs_current = Float64(get(financials_current, :total_operating_expenses, 0.0))
    cogs_prior = Float64(get(financials_prior, :total_operating_expenses, 0.0))

    # 1. DSRI = (AR_t / Revenue_t) / (AR_t-1 / Revenue_t-1)
    dsr_current = revenue_current > 0 ? balance_sheet_current.accounts_receivable_net / revenue_current : 0.0
    dsr_prior = revenue_prior > 0 ? balance_sheet_prior.accounts_receivable_net / revenue_prior : 0.0
    dsri = dsr_prior > 0.0001 ? dsr_current / dsr_prior : 1.0

    # 2. GMI = (1 - GM_t) / (1 - GM_t-1) where GM = (Revenue - COGS) / Revenue
    gm_current = revenue_current > 0 ? (revenue_current - cogs_current) / revenue_current : 0.5
    gm_prior = revenue_prior > 0 ? (revenue_prior - cogs_prior) / revenue_prior : 0.5
    gmi = (1.0 - gm_prior) > 0.0001 ? (1.0 - gm_current) / (1.0 - gm_prior) : 1.0

    # 3. AQI = (1 - (CA + PPE) / TA) / (1 - (CA_prior + PPE_prior) / TA_prior)
    # where CA = current assets, PPE = net property, TA = total assets
    ca_current = balance_sheet_current.cash_and_equivalents +
                 balance_sheet_current.short_term_investments +
                 balance_sheet_current.accounts_receivable_net +
                 balance_sheet_current.inventory
    ppe_current = balance_sheet_current.gross_ppe - balance_sheet_current.accumulated_depreciation
    ta_current = ca_current + ppe_current + balance_sheet_current.long_term_investments +
                 balance_sheet_current.other_lt_assets

    ca_prior = balance_sheet_prior.cash_and_equivalents +
               balance_sheet_prior.short_term_investments +
               balance_sheet_prior.accounts_receivable_net +
               balance_sheet_prior.inventory
    ppe_prior = balance_sheet_prior.gross_ppe - balance_sheet_prior.accumulated_depreciation
    ta_prior = ca_prior + ppe_prior + balance_sheet_prior.long_term_investments +
               balance_sheet_prior.other_lt_assets

    quality_current = ta_current > 0 ? 1.0 - (ca_current + ppe_current) / ta_current : 0.5
    quality_prior = ta_prior > 0 ? 1.0 - (ca_prior + ppe_prior) / ta_prior : 0.5
    aqi = quality_prior > 0.0001 ? quality_current / quality_prior : 1.0

    # 4. SGI = Revenue_t / Revenue_t-1
    sgi = revenue_prior > 0 ? revenue_current / revenue_prior : 1.0

    # 5. DEPI = Depreciation_t-1 / (Depreciation_t-1 + Net PPE_t-1) /
    #           (Depreciation_t / (Depreciation_t + Net PPE_t))
    depr_current = Float64(get(financials_current, :depreciation, 0.0))
    depr_prior = Float64(get(financials_prior, :depreciation, 0.0))

    depr_index_current = depr_current + ppe_current
    depr_index_prior = depr_prior + ppe_prior
    depi = if depr_index_current > 0.0001 && depr_index_prior > 0.0001
        (depr_prior / depr_index_prior) / (depr_current / depr_index_current)
    else
        1.0
    end

    # 6. SGAI = (SG&A_t / Revenue_t) / (SG&A_t-1 / Revenue_t-1)
    # For hospitals, use operating expenses as proxy
    sgai_current = revenue_current > 0 ? cogs_current / revenue_current : 0.95
    sgai_prior = revenue_prior > 0 ? cogs_prior / revenue_prior : 0.95
    sgai = sgai_prior > 0.0001 ? sgai_current / sgai_prior : 1.0

    # 7. LVGI = (CL + LTD) / TA / ((CL_prior + LTD_prior) / TA_prior)
    # where CL = current liabilities, LTD = long-term debt
    cl_current = balance_sheet_current.accounts_payable +
                 balance_sheet_current.accrued_expenses +
                 balance_sheet_current.current_portion_lt_debt +
                 balance_sheet_current.other_current_liabilities
    ltd_current = balance_sheet_current.long_term_debt

    cl_prior = balance_sheet_prior.accounts_payable +
               balance_sheet_prior.accrued_expenses +
               balance_sheet_prior.current_portion_lt_debt +
               balance_sheet_prior.other_current_liabilities
    ltd_prior = balance_sheet_prior.long_term_debt

    leverage_current = ta_current > 0 ? (cl_current + ltd_current) / ta_current : 0.5
    leverage_prior = ta_prior > 0 ? (cl_prior + ltd_prior) / ta_prior : 0.5
    lvgi = leverage_prior > 0.0001 ? leverage_current / leverage_prior : 1.0

    # 8. TATA = Change in WC / Total Assets (approximated)
    # Simplified: total accruals ≈ change in current liabilities - depreciation
    change_wc = (cl_current - cl_prior) - depr_current
    tata = ta_current > 0 ? change_wc / ta_current : 0.0

    # Compute M-score
    m = -4.40 - (0.920 * dsri) - (0.528 * gmi) - (0.404 * aqi) +
        (0.892 * sgi) - (0.115 * depi) - (0.172 * sgai) + (4.679 * tata)

    return BeneishMScore(
        m_score = m,
        flag_manipulation = m > -1.78,
        dsri = dsri,
        gmi = gmi,
        aqi = aqi,
        sgi = sgi,
        depi = depi,
        sgai = sgai,
        lvgi = lvgi,
        tata = tata
    )
end
