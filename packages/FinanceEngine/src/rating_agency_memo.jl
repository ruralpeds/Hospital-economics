"""
    rating_agency_memo.jl — Rating Agency Credit Memo Generator (MBA Gap F-02)

Generates a board-ready credit analysis memo in the narrative style used by
Moody's Investors Service, S&P Global Ratings, and Fitch Ratings for
not-for-profit hospital credits.

The memo follows the standard structure of a Moody's New Issue Report:
  1. Rating Summary and Rationale
  2. Credit Strengths and Challenges
  3. Financial Profile (5-year trend table)
  4. Operating Performance
  5. Debt Profile and Coverage
  6. Liquidity
  7. Peer Comparison (Flex Monitoring percentiles)
  8. Rating Outlook and Sensitivity
  9. Covenant Compliance

Output:
  - Markdown text (universal; for web/PDF via pandoc)
  - Typst-compilable source (for board-quality PDF via `typst compile`)
  - Structured `RatingMemoData` dict (for programmatic use)

## Data inputs
The memo is constructed from:
- `synthetic_rating()` result (from nonprofit_wacc.jl)
- `covenant_dashboard()` result (from nonprofit_wacc.jl)
- `benchmark_flex_monitoring()` result (from peer_benchmarking.jl)
- Historical financial series (5 years)

References:
- Moody's (2024). U.S. Not-for-Profit Healthcare Rating Methodology.
- S&P Global (2023). U.S. Not-for-Profit Obligors Criteria.
- Fitch Ratings (2024). U.S. Not-for-Profit Hospitals Rating Criteria.
"""

using Dates
using Printf
using Statistics

# ─────────────────────────────────────────────────────────────────────────────
# Input types
# ─────────────────────────────────────────────────────────────────────────────

"""
    RatingMemoInputs

All data needed to generate a rating agency credit memo.

# Fields
- `hospital_name::String`
- `hospital_type::String`: e.g. "Critical Access Hospital".
- `state::String`
- `reporting_date::Date`
- `analyst_name::String`: Memo preparer.

Financial profile (latest fiscal year):
- `net_patient_revenue::Float64`
- `operating_margin::Float64`: Latest FY.
- `total_margin::Float64`
- `days_cash_on_hand::Float64`
- `mads_dscr::Float64`: Maximum Annual Debt Service Coverage.
- `debt_to_cap::Float64`
- `current_ratio::Float64`
- `avg_age_of_plant::Float64`
- `long_term_debt::Float64`
- `max_annual_debt_service::Float64`

Historical series (5 years, oldest first):
- `historical_years::Vector{Int}`
- `historical_operating_margins::Vector{Float64}`
- `historical_dcoh::Vector{Float64}`
- `historical_mads_dscr::Vector{Float64}`

Synthetic rating (from nonprofit_wacc.synthetic_rating):
- `moody_equivalent::String`: e.g. "Baa2/BBB".
- `sp_equivalent::String`: e.g. "BBB".
- `rating_score::Float64`
- `rating_outlook::Symbol`: `:stable`, `:positive`, `:negative`, `:developing`.

Peer benchmarks (from peer_benchmarking.benchmark_flex_monitoring):
- `peer_operating_margin_pct::Float64`: Flex Monitoring percentile rank.
- `peer_dcoh_pct::Float64`
- `peer_dscr_pct::Float64`
- `peer_debt_to_cap_pct::Float64`

Qualitative factors:
- `credit_strengths::Vector{String}`
- `credit_challenges::Vector{String}`
- `rating_sensitivities_upward::Vector{String}`
- `rating_sensitivities_downward::Vector{String}`
- `covenant_compliant::Bool`
- `covenant_details::String`
"""
@kwdef struct RatingMemoInputs
    # Identity
    hospital_name::String
    hospital_type::String                 = "Critical Access Hospital"
    state::String                         = ""
    reporting_date::Date                  = today()
    analyst_name::String                  = "Finance Department"

    # Current financials
    net_patient_revenue::Float64
    operating_margin::Float64
    total_margin::Float64
    days_cash_on_hand::Float64
    mads_dscr::Float64
    debt_to_cap::Float64
    current_ratio::Float64
    avg_age_of_plant::Float64
    long_term_debt::Float64
    max_annual_debt_service::Float64

    # 5-year historical
    historical_years::Vector{Int}             = Int[]
    historical_operating_margins::Vector{Float64} = Float64[]
    historical_dcoh::Vector{Float64}           = Float64[]
    historical_mads_dscr::Vector{Float64}      = Float64[]

    # Rating
    moody_equivalent::String               = "Ba1/BB+"
    sp_equivalent::String                  = "BB+"
    rating_score::Float64                  = 0.0
    rating_outlook::Symbol                 = :stable

    # Peer benchmarks
    peer_operating_margin_pct::Float64     = 50.0
    peer_dcoh_pct::Float64                 = 50.0
    peer_dscr_pct::Float64                 = 50.0
    peer_debt_to_cap_pct::Float64          = 50.0

    # Qualitative
    credit_strengths::Vector{String}       = String[]
    credit_challenges::Vector{String}      = String[]
    rating_sensitivities_upward::Vector{String}   = String[]
    rating_sensitivities_downward::Vector{String} = String[]
    covenant_compliant::Bool               = true
    covenant_details::String               = ""
end

# ─────────────────────────────────────────────────────────────────────────────
# Narrative helpers
# ─────────────────────────────────────────────────────────────────────────────

function _outlook_text(o::Symbol)
    o == :stable   ? "STABLE"   :
    o == :positive ? "POSITIVE" :
    o == :negative ? "NEGATIVE" : "DEVELOPING"
end

function _rating_tier_label(moody::String)
    startswith(moody, "Aaa") ? "Prime (Aaa)" :
    startswith(moody, "Aa")  ? "High Grade (Aa)" :
    startswith(moody, "A")   ? "Upper Medium Grade (A)" :
    startswith(moody, "Baa") ? "Lower Medium Grade / Investment Grade (Baa)" :
    startswith(moody, "Ba")  ? "Speculative Grade / Non-Investment (Ba)" :
    startswith(moody, "B")   ? "Highly Speculative (B)" : "Distressed / Default Risk"
end

function _trend_word(vals::Vector{Float64})
    isempty(vals) && return "flat"
    length(vals) < 2 && return "stable"
    slope = (vals[end] - vals[1]) / length(vals)
    abs(slope) < 0.003 ? "relatively stable" :
    slope > 0 ? "improving" : "deteriorating"
end

function _peer_descriptor(pct::Float64)
    pct >= 75 ? "above the 75th percentile (peer-superior)" :
    pct >= 50 ? "in the median range (peer-average)" :
    pct >= 25 ? "below the median (peer-below-average)" :
                "below the 25th percentile (peer-weak)"
end

# ─────────────────────────────────────────────────────────────────────────────
# Section generators
# ─────────────────────────────────────────────────────────────────────────────

function _section_summary(inp::RatingMemoInputs)::String
    io = IOBuffer()
    println(io, "## Rating Summary\n")
    println(io, "**Issuer:** $(inp.hospital_name) — $(inp.hospital_type)")
    println(io, "**State:** $(inp.state)  |  **Report Date:** $(Dates.format(inp.reporting_date, "MMMM d, yyyy"))")
    println(io, "**Moody's Equivalent:** $(inp.moody_equivalent)  |  **S&P Equivalent:** $(inp.sp_equivalent)")
    println(io, "**Rating Category:** $(_rating_tier_label(inp.moody_equivalent))")
    println(io, "**Outlook:** $(_outlook_text(inp.rating_outlook))\n")
    println(io, "---\n")
    String(take!(io))
end

function _section_rationale(inp::RatingMemoInputs)::String
    io = IOBuffer()
    println(io, "## Rating Rationale\n")
    om_pct  = @sprintf("%.1f%%", inp.operating_margin * 100)
    dcoh    = @sprintf("%.0f days", inp.days_cash_on_hand)
    dscr    = @sprintf("%.2f×", inp.mads_dscr)

    println(io, """
The $(inp.moody_equivalent) rating reflects $(inp.hospital_name)'s position as \
a $(inp.hospital_type) serving a rural community in $(inp.state). \
The rating is supported by the hospital's federally-designated Critical Access \
Hospital status and associated 101% cost-based Medicare reimbursement, which \
provides a degree of revenue stability not available to prospectively-paid peers.

The operating margin of $(om_pct) is $(_peer_descriptor(inp.peer_operating_margin_pct)) \
among CAH peers tracked by the Flex Monitoring Team. Liquidity stands at $(dcoh) cash \
on hand, $(_peer_descriptor(inp.peer_dcoh_pct)), with MADS DSCR of $(dscr). \
The $(inp.mads_dscr >= 1.50 ? "adequate" : inp.mads_dscr >= 1.10 ? "modest" : "thin") \
debt service coverage reflects $(inp.mads_dscr >= 1.50 ? "sound" : "limited") \
financial flexibility.

Rating constraints include the inherent operating leverage of a small-volume \
rural hospital, exposure to rural population trends, and Medicaid payer mix \
sensitivity.
""")
    String(take!(io))
end

function _section_strengths_challenges(inp::RatingMemoInputs)::String
    io = IOBuffer()
    println(io, "## Credit Strengths and Challenges\n")
    println(io, "### Credit Strengths\n")
    strengths = isempty(inp.credit_strengths) ? [
        "Federal CAH designation providing 101% cost-based Medicare reimbursement",
        "Sole community provider status limiting direct competition within the primary service area",
        "Flex Monitoring peer benchmark positioning — operating margin P$(round(Int, inp.peer_operating_margin_pct))",
        "MADS DSCR of $(@sprintf("%.2f×", inp.mads_dscr)) $(inp.mads_dscr >= 1.50 ? "exceeding" : "above") the typical 1.10× covenant floor",
        "$(inp.days_cash_on_hand >= 55 ? "Adequate" : "Developing") liquidity at $(@sprintf("%.0f", inp.days_cash_on_hand)) days cash on hand",
    ] : inp.credit_strengths
    for s in strengths; println(io, "- $s"); end

    println(io, "\n### Credit Challenges\n")
    challenges = isempty(inp.credit_challenges) ? [
        "Thin operating margin of $(@sprintf("%.1f%%", inp.operating_margin * 100)) leaves limited cushion for adverse events",
        "Rural demographic trends including population aging and income constraints",
        "Dependence on government payers (Medicare + Medicaid) with ongoing reimbursement policy risk",
        "Capital reinvestment pressure — average age of plant $(@sprintf("%.1f years", inp.avg_age_of_plant)) requiring strategic capex planning",
        "Contract labor market exposure elevating salary-to-revenue ratios",
    ] : inp.credit_challenges
    for c in challenges; println(io, "- $c"); end
    println(io)
    String(take!(io))
end

function _section_financial_profile(inp::RatingMemoInputs)::String
    io = IOBuffer()
    println(io, "## Financial Profile\n")
    println(io, "### Key Ratios — Latest Fiscal Year\n")
    println(io, "| Metric | Value | Flex Monitoring Peer Percentile |")
    println(io, "|:---|---:|:---:|")
    rows = [
        ("Net Patient Revenue",    @sprintf("\$%.1fM", inp.net_patient_revenue/1e6), "—"),
        ("Operating Margin",       @sprintf("%.1f%%", inp.operating_margin*100),
            "P$(round(Int, inp.peer_operating_margin_pct))"),
        ("Total Margin",           @sprintf("%.1f%%", inp.total_margin*100), "—"),
        ("Days Cash on Hand",      @sprintf("%.0f d", inp.days_cash_on_hand),
            "P$(round(Int, inp.peer_dcoh_pct))"),
        ("MADS DSCR",              @sprintf("%.2f×", inp.mads_dscr),
            "P$(round(Int, inp.peer_dscr_pct))"),
        ("Debt / Capitalization",  @sprintf("%.1f%%", inp.debt_to_cap*100),
            "P$(round(Int, inp.peer_debt_to_cap_pct))"),
        ("Current Ratio",          @sprintf("%.2f×", inp.current_ratio), "—"),
        ("Avg Age of Plant",       @sprintf("%.1f yrs", inp.avg_age_of_plant), "—"),
        ("Long-Term Debt",         @sprintf("\$%.1fM", inp.long_term_debt/1e6), "—"),
        ("Max Annual Debt Service",@sprintf("\$%.0fK", inp.max_annual_debt_service/1e3), "—"),
    ]
    for (m, v, p) in rows; println(io, "| $m | $v | $p |"); end
    println(io)

    if !isempty(inp.historical_years)
        println(io, "### Five-Year Financial Trend\n")
        println(io, "| Year | Op Margin | Days Cash | MADS DSCR |")
        println(io, "|:---:|---:|---:|---:|")
        n = min(length(inp.historical_years), length(inp.historical_operating_margins),
                length(inp.historical_dcoh), length(inp.historical_mads_dscr))
        for i in 1:n
            println(io, "| $(inp.historical_years[i]) | " *
                @sprintf("%.1f%%", inp.historical_operating_margins[i]*100) * " | " *
                @sprintf("%.0f d", inp.historical_dcoh[i]) * " | " *
                @sprintf("%.2f×", inp.historical_mads_dscr[i]) * " |")
        end
        om_trend = _trend_word(inp.historical_operating_margins)
        println(io, "\n_Operating margin has been $(om_trend) over the review period._\n")
    end
    String(take!(io))
end

function _section_debt_liquidity(inp::RatingMemoInputs)::String
    io = IOBuffer()
    println(io, "## Debt Profile and Liquidity\n")
    println(io, """
Long-term debt of $(@sprintf("\$%.1fM", inp.long_term_debt/1e6)) represents \
$(@sprintf("%.0f%%", inp.debt_to_cap * 100)) of capitalisation. Maximum annual \
debt service of $(@sprintf("\$%.0fK", inp.max_annual_debt_service/1e3)) is \
covered $(string(@sprintf("%.2f×", inp.mads_dscr))) by operations, \
$(inp.mads_dscr >= 2.0 ? "comfortably above" : inp.mads_dscr >= 1.5 ? "above" :
  inp.mads_dscr >= 1.1 ? "modestly above" : "near") the standard 1.10× covenant floor.

Unrestricted cash and investments support $(@sprintf("%.0f", inp.days_cash_on_hand)) \
days of cash coverage, $(_peer_descriptor(inp.peer_dcoh_pct)). \
$(inp.days_cash_on_hand >= 55 ?
  "This liquidity position is consistent with the rating level." :
  "Management is focused on liquidity improvement initiatives including AR acceleration and working capital optimisation.")
""")
    String(take!(io))
end

function _section_outlook_sensitivity(inp::RatingMemoInputs)::String
    io = IOBuffer()
    println(io, "## Rating Outlook and Sensitivity\n")
    println(io, "**Outlook: $(_outlook_text(inp.rating_outlook))**\n")

    up = isempty(inp.rating_sensitivities_upward) ? [
        "Sustained operating margin improvement above 3% for two or more years",
        "Days cash on hand consistently exceeding 60 days",
        "Successful diversification of outpatient and RHC revenue streams",
        "Materially reduced debt burden improving MADS DSCR above 2.0×",
    ] : inp.rating_sensitivities_upward
    down = isempty(inp.rating_sensitivities_downward) ? [
        "Operating margin falling below negative 2% without credible recovery path",
        "Days cash declining below 30 days (HRSA/Flex Monitoring watch threshold)",
        "MADS DSCR approaching the 1.10× covenant floor",
        "Loss of CAH designation or significant change to cost-based reimbursement",
        "Unplanned debt issuance materially increasing debt service obligations",
    ] : inp.rating_sensitivities_downward

    println(io, "### Factors That Could Lead to an Upgrade\n")
    for s in up; println(io, "- $s"); end
    println(io, "\n### Factors That Could Lead to a Downgrade\n")
    for s in down; println(io, "- $s"); end
    println(io)
    String(take!(io))
end

function _section_covenants(inp::RatingMemoInputs)::String
    io = IOBuffer()
    println(io, "## Covenant Compliance\n")
    status = inp.covenant_compliant ? "✅ **Compliant**" : "❌ **Non-Compliant — Waiver or Cure Required**"
    println(io, "**Current Status:** $status\n")
    if !isempty(inp.covenant_details)
        println(io, inp.covenant_details)
    else
        println(io, """
Standard financial covenants tested annually:
- MADS DSCR ≥ 1.10× (Current: $(@sprintf("%.2f×", inp.mads_dscr)))
- Days Cash on Hand ≥ 30 days (Current: $(@sprintf("%.0f d", inp.days_cash_on_hand)))
- Long-term debt / capitalisation ≤ 65% (Current: $(@sprintf("%.0f%%", inp.debt_to_cap*100)))
""")
    end
    String(take!(io))
end

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

"""
    generate_rating_memo_markdown(inputs::RatingMemoInputs) -> String

Generate a complete rating agency credit memo as GitHub-Flavored Markdown.

The memo follows the Moody's New Issue Report structure and can be converted
to PDF via pandoc or Typst.

# Example
```julia
memo = generate_rating_memo_markdown(inputs)
write("valley_cah_credit_memo.md", memo)
```
"""
function generate_rating_memo_markdown(inputs::RatingMemoInputs)::String
    io = IOBuffer()
    println(io, "# Credit Analysis Memorandum\n")
    println(io, "## $(inputs.hospital_name) — $(inputs.hospital_type)\n")
    println(io, "*Prepared by: $(inputs.analyst_name)*  ")
    println(io, "*Report Date: $(Dates.format(inputs.reporting_date, "MMMM d, yyyy"))*\n")
    println(io, "---\n")
    print(io, _section_summary(inputs))
    print(io, _section_rationale(inputs))
    print(io, _section_strengths_challenges(inputs))
    print(io, _section_financial_profile(inputs))
    print(io, _section_debt_liquidity(inputs))
    print(io, _section_outlook_sensitivity(inputs))
    print(io, _section_covenants(inputs))
    println(io, "\n---")
    println(io, "*This memorandum is prepared for internal governance purposes. " *
        "It is not a public credit rating and has not been reviewed or endorsed " *
        "by Moody's Investors Service, S&P Global Ratings, or Fitch Ratings.*")
    String(take!(io))
end

"""
    generate_rating_memo_typst(inputs::RatingMemoInputs) -> String

Generate a Typst source file for the credit memo.
Compile with: `typst compile credit_memo.typ credit_memo.pdf`
"""
function generate_rating_memo_typst(inputs::RatingMemoInputs)::String
    md = generate_rating_memo_markdown(inputs)
    # Wrap in a simple Typst document
    """
#set document(title: "Credit Analysis — $(inputs.hospital_name)")
#set page(paper: "us-letter", margin: (x: 1.25in, y: 1in))
#set text(font: "Helvetica Neue", size: 10pt)
#set heading(numbering: none)

// Credit memo content (Markdown converted to Typst prose)
// For production use, convert Markdown tables to Typst #table() elements.
// This wrapper provides correct page setup; content follows.

$(replace(md,
    r"^## (.+)$"m  => s"= \1",
    r"^### (.+)$"m => s"== \1",
    r"\*\*(.+?)\*\*" => s"*\\1*",
    r"^\| .+" => "",   # strip raw MD tables (use Typst tables in production)
    r"^---$" => "#line(length: 100%)",
))

// Generated $(Dates.format(today(), "yyyy-mm-dd")) by ruralpeds/Hospital-economics
"""
end

"""
    rating_memo_data(inputs::RatingMemoInputs) -> Dict{String,Any}

Return the structured data underlying the memo (for API / JSON export).
"""
function rating_memo_data(inputs::RatingMemoInputs)::Dict{String,Any}
    Dict{String,Any}(
        "hospital_name"          => inputs.hospital_name,
        "reporting_date"         => string(inputs.reporting_date),
        "moody_equivalent"       => inputs.moody_equivalent,
        "sp_equivalent"          => inputs.sp_equivalent,
        "outlook"                => string(inputs.rating_outlook),
        "key_ratios" => Dict(
            "operating_margin"   => inputs.operating_margin,
            "days_cash_on_hand"  => inputs.days_cash_on_hand,
            "mads_dscr"          => inputs.mads_dscr,
            "debt_to_cap"        => inputs.debt_to_cap,
            "current_ratio"      => inputs.current_ratio,
        ),
        "peer_percentiles" => Dict(
            "operating_margin"   => inputs.peer_operating_margin_pct,
            "dcoh"               => inputs.peer_dcoh_pct,
            "dscr"               => inputs.peer_dscr_pct,
            "debt_to_cap"        => inputs.peer_debt_to_cap_pct,
        ),
        "covenant_compliant"     => inputs.covenant_compliant,
        "credit_strengths"       => inputs.credit_strengths,
        "credit_challenges"      => inputs.credit_challenges,
    )
end
