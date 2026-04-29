"""
    board_packet.jl — Board-Ready Packet Generator (MBA Gap F-01)

Generates a 12-section hospital board packet in PDF format using a pure-Julia
pipeline:

  Data assembly (Julia structs) → Typst source file → PDF (via Typst binary)

## Why Typst over LaTeX/Weave
- Single binary install (`brew install typst` / `apt-get install typst`)
- Compiles in < 1 second vs 10–30 seconds for LaTeX
- Native chart embedding via SVG
- No complex dependency tree

## 12-Section Structure
  1. Cover page
  2. Executive Summary (1-page narrative)
  3. Financial Scorecard (KPI table with RAG)
  4. Volume & Case Mix
  5. Payer Mix Walk
  6. Revenue Cycle Metrics
  7. Expense & Staffing Analysis
  8. Capital & Balance Sheet
  9. Quality & Regulatory Compliance
 10. Community Benefit & SDOH
 11. Strategic Initiatives & Risks
 12. Appendix (Flex Monitoring benchmarks)

## Rendering pipeline
    generate_board_packet(data) -> BoardPacketDocument
    render_to_typst(doc) -> String           # Typst source
    write_typst_and_compile(doc, out_path)   # writes .typ + calls typst compile
    render_to_markdown(doc) -> String        # fallback for environments without Typst

## Usage
```julia
data = BoardPacketData(
    hospital_name = "Prairie View Community Hospital",
    # ... fill all fields
)
doc = generate_board_packet(data)
write_typst_and_compile(doc, "board_packet_q1_2026.pdf")
```
"""

using Dates
using Printf
using Statistics

# ─────────────────────────────────────────────────────────────────────────────
# Input data structures
# ─────────────────────────────────────────────────────────────────────────────

"""
    BoardPacketData

All data needed to generate a hospital board packet.
Fill all fields before calling `generate_board_packet`.
"""
@kwdef struct BoardPacketData
    # Identity
    hospital_name::String
    hospital_type::String                  = "Critical Access Hospital"
    ccn::String                            = ""
    address::String                        = ""
    fiscal_period::String                  = "Q1 FY2026"
    board_meeting_date::Date               = today()
    prepared_by::String                    = "Finance Department"

    # Financial KPIs (current period)
    operating_margin::Float64              = 0.0
    total_margin::Float64                  = 0.0
    days_cash_on_hand::Float64             = 0.0
    current_ratio::Float64                 = 0.0
    debt_to_cap::Float64                   = 0.0
    mads_dscr::Float64                     = 0.0
    avg_age_of_plant::Float64              = 0.0

    # KPI prior-period for comparison
    prior_operating_margin::Float64        = 0.0
    prior_days_cash::Float64               = 0.0
    prior_current_ratio::Float64           = 0.0

    # Volume metrics
    ed_visits_ytd::Int                     = 0
    inpatient_discharges_ytd::Int          = 0
    outpatient_visits_ytd::Int             = 0
    avg_daily_census::Float64              = 0.0
    case_mix_index::Float64                = 1.00
    avg_length_of_stay::Float64            = 0.0
    occupancy_rate::Float64                = 0.0

    # Payer mix (current vs prior; decimal)
    medicare_pct::Float64                  = 0.0
    medicaid_pct::Float64                  = 0.0
    commercial_pct::Float64                = 0.0
    self_pay_pct::Float64                  = 0.0
    prior_medicare_pct::Float64            = 0.0

    # Revenue cycle
    days_ar_outstanding::Float64           = 0.0
    denial_rate::Float64                   = 0.0
    clean_claim_rate::Float64              = 0.0
    cash_collection_efficiency::Float64    = 0.0
    bad_debt_pct::Float64                  = 0.0

    # Expense & staffing
    total_fte::Float64                     = 0.0
    fte_per_aob::Float64                   = 0.0
    salary_to_revenue::Float64             = 0.0
    contract_labor_pct::Float64            = 0.0
    supply_expense_per_discharge::Float64  = 0.0

    # Capital
    net_patient_revenue::Float64           = 0.0
    total_assets::Float64                  = 0.0
    long_term_debt::Float64                = 0.0
    net_assets::Float64                    = 0.0
    capital_expenditures_ytd::Float64     = 0.0
    depreciation_expense::Float64          = 0.0

    # Quality (rates; lower is better for HAC / readmission)
    hac_score::Float64                     = 0.0
    readmission_rate::Float64              = 0.0
    patient_satisfaction_score::Float64    = 0.0   # HCAHPS top-box %
    vbp_tps::Float64                       = 50.0  # VBP Total Performance Score

    # Community
    charity_care_pct::Float64              = 0.0
    community_benefit_total::Float64       = 0.0
    sdoh_risk_score::Float64               = 0.0

    # Strategic narrative (Markdown text for sections 11)
    strategic_initiatives::Vector{String}  = String[]
    key_risks::Vector{String}              = String[]
    management_responses::Vector{String}   = String[]

    # Peer benchmarks (Flex Monitoring percentiles)
    peer_operating_margin_pct::Float64     = 50.0
    peer_dcoh_pct::Float64                 = 50.0
    peer_debt_to_cap_pct::Float64          = 50.0
end

"""
    BoardPacketSection

One section of the board packet.

# Fields
- `number::Int`: Section number (1–12).
- `title::String`
- `subsections::Vector{NamedTuple}`: Tables, metrics, text blocks.
"""
struct BoardPacketSection
    number::Int
    title::String
    subsections::Vector{NamedTuple}
end

"""
    BoardPacketDocument

Complete assembled board packet, ready for rendering.
"""
struct BoardPacketDocument
    hospital_name::String
    fiscal_period::String
    board_meeting_date::Date
    prepared_by::String
    sections::Vector{BoardPacketSection}
    generated_at::DateTime
end

# ─────────────────────────────────────────────────────────────────────────────
# RAG helper
# ─────────────────────────────────────────────────────────────────────────────

function _rag_str(v, green, amber, direction=:higher)
    ok = direction == :higher ? (v >= green) : (v <= green)
    warn = direction == :higher ? (v >= amber) : (v <= amber)
    ok ? "green" : warn ? "amber" : "red"
end

function _fmt_usd(v)
    abs(v) >= 1e6 ? @sprintf("\$%.1fM", v/1e6) :
    abs(v) >= 1e3 ? @sprintf("\$%.0fK", v/1e3) :
    @sprintf("\$%.0f", v)
end

_fmt_pct(v) = @sprintf("%.1f%%", v * 100)
_fmt_days(v) = @sprintf("%.1f d", v)
_fmt_ratio(v) = @sprintf("%.2f×", v)

# ─────────────────────────────────────────────────────────────────────────────
# Assembly: generate_board_packet
# ─────────────────────────────────────────────────────────────────────────────

"""
    generate_board_packet(data::BoardPacketData) -> BoardPacketDocument

Assemble all 12 sections of the board packet from `data`.
"""
function generate_board_packet(data::BoardPacketData)::BoardPacketDocument
    sections = BoardPacketSection[
        _section_cover(data),
        _section_exec_summary(data),
        _section_financial_scorecard(data),
        _section_volume(data),
        _section_payer_mix(data),
        _section_revenue_cycle(data),
        _section_expense_staffing(data),
        _section_capital(data),
        _section_quality(data),
        _section_community(data),
        _section_strategic(data),
        _section_appendix(data),
    ]
    BoardPacketDocument(
        data.hospital_name, data.fiscal_period, data.board_meeting_date,
        data.prepared_by, sections, now(),
    )
end

function _section_cover(d::BoardPacketData)
    BoardPacketSection(1, "Cover", [(
        type   = :cover,
        title  = d.hospital_name,
        subtitle = "$(d.hospital_type) Board of Directors Meeting",
        date   = Dates.format(d.board_meeting_date, "MMMM d, yyyy"),
        period = d.fiscal_period,
        author = d.prepared_by,
    )])
end

function _section_exec_summary(d::BoardPacketData)
    om_rag = _rag_str(d.operating_margin, 0.03, 0.0)
    dcoh_rag = _rag_str(d.days_cash_on_hand, 55.0, 30.0)
    volume_trend = d.ed_visits_ytd > 0 ? "positive" : "flat"

    summary_text = """
    $(d.hospital_name) reports a $(d.fiscal_period) operating margin of \
    $(_fmt_pct(d.operating_margin)) (prior period: $(_fmt_pct(d.prior_operating_margin))), \
    reflecting $(d.operating_margin >= d.prior_operating_margin ? "improvement" : "deterioration") \
    of $(_fmt_pct(abs(d.operating_margin - d.prior_operating_margin))) period-over-period.

    Liquidity stands at $(_fmt_days(d.days_cash_on_hand)) days cash on hand, \
    $(d.days_cash_on_hand >= 55.0 ? "above" : d.days_cash_on_hand >= 30.0 ? "near" : "below") \
    the Flex Monitoring green threshold of 55 days. Volume trends are $(volume_trend), \
    with $(d.ed_visits_ytd) ED visits year-to-date.

    Management's primary financial priorities for the quarter: expense management \
    (salary-to-revenue at $(_fmt_pct(d.salary_to_revenue))), revenue cycle optimisation \
    (DSO: $(round(Int, d.days_ar_outstanding)) days), and capital planning.
    """

    BoardPacketSection(2, "Executive Summary", [
        (type=:narrative, text=summary_text),
        (type=:metric_row,
         items=[
            (label="Operating Margin", value=_fmt_pct(d.operating_margin), rag=om_rag),
            (label="Days Cash on Hand", value=_fmt_days(d.days_cash_on_hand), rag=dcoh_rag),
            (label="MADS DSCR", value=_fmt_ratio(d.mads_dscr),
             rag=_rag_str(d.mads_dscr, 1.5, 1.1)),
            (label="VBP TPS", value="$(round(Int, d.vbp_tps)) pts",
             rag=_rag_str(d.vbp_tps, 65.0, 50.0)),
         ]),
    ])
end

function _section_financial_scorecard(d::BoardPacketData)
    rows = [
        (metric="Operating Margin",       current=_fmt_pct(d.operating_margin),
         prior=_fmt_pct(d.prior_operating_margin),
         benchmark="P$(round(Int, d.peer_operating_margin_pct))",
         rag=_rag_str(d.operating_margin, 0.03, 0.0)),
        (metric="Total Margin",           current=_fmt_pct(d.total_margin),
         prior="—",                       benchmark="P50",
         rag=_rag_str(d.total_margin, 0.04, 0.01)),
        (metric="Days Cash on Hand",      current=_fmt_days(d.days_cash_on_hand),
         prior=_fmt_days(d.prior_days_cash),
         benchmark="P$(round(Int, d.peer_dcoh_pct))",
         rag=_rag_str(d.days_cash_on_hand, 55.0, 30.0)),
        (metric="Current Ratio",          current=_fmt_ratio(d.current_ratio),
         prior=_fmt_ratio(d.prior_current_ratio),
         benchmark="P50: 2.02×",
         rag=_rag_str(d.current_ratio, 1.8, 1.2)),
        (metric="Debt / Capitalization",  current=_fmt_pct(d.debt_to_cap),
         prior="—",
         benchmark="P$(round(Int, d.peer_debt_to_cap_pct))",
         rag=_rag_str(d.debt_to_cap, 0.45, 0.60, :lower)),
        (metric="Avg Age of Plant (yrs)", current=@sprintf("%.1f", d.avg_age_of_plant),
         prior="—",                       benchmark="P50: 12.6",
         rag=_rag_str(d.avg_age_of_plant, 10.0, 16.0, :lower)),
        (metric="MADS DSCR",              current=_fmt_ratio(d.mads_dscr),
         prior="—",                       benchmark="Covenant ≥ 1.10×",
         rag=_rag_str(d.mads_dscr, 1.5, 1.1)),
        (metric="Salary / Revenue",       current=_fmt_pct(d.salary_to_revenue),
         prior="—",                       benchmark="P50: 50.8%",
         rag=_rag_str(d.salary_to_revenue, 0.50, 0.58, :lower)),
    ]
    BoardPacketSection(3, "Financial Scorecard", [
        (type=:table, title="Key Financial Indicators — $(d.fiscal_period)",
         headers=["Metric","Current","Prior Period","Peer Benchmark","Status"],
         rows=rows),
    ])
end

function _section_volume(d::BoardPacketData)
    BoardPacketSection(4, "Volume & Case Mix", [
        (type=:metric_row, items=[
            (label="ED Visits YTD",       value=string(d.ed_visits_ytd)),
            (label="IP Discharges YTD",   value=string(d.inpatient_discharges_ytd)),
            (label="OP Visits YTD",       value=string(d.outpatient_visits_ytd)),
            (label="Avg Daily Census",    value=@sprintf("%.1f", d.avg_daily_census)),
            (label="Case Mix Index",      value=@sprintf("%.2f", d.case_mix_index)),
            (label="Avg LOS",             value=@sprintf("%.1f d", d.avg_length_of_stay)),
            (label="Occupancy Rate",      value=_fmt_pct(d.occupancy_rate)),
        ]),
    ])
end

function _section_payer_mix(d::BoardPacketData)
    ma_penetration_chg = d.medicare_pct - d.prior_medicare_pct
    BoardPacketSection(5, "Payer Mix Analysis", [
        (type=:table, title="Current Period Payer Mix vs Prior",
         headers=["Payer","Current %","Prior %","Change"],
         rows=[
            (payer="Medicare",   current=_fmt_pct(d.medicare_pct),
             prior=_fmt_pct(d.prior_medicare_pct),
             change=@sprintf("%+.1f pp", (d.medicare_pct - d.prior_medicare_pct)*100)),
            (payer="Medicaid",   current=_fmt_pct(d.medicaid_pct), prior="—", change="—"),
            (payer="Commercial", current=_fmt_pct(d.commercial_pct), prior="—", change="—"),
            (payer="Self-Pay",   current=_fmt_pct(d.self_pay_pct), prior="—", change="—"),
         ]),
        (type=:narrative, text="Medicare Advantage penetration trend: " *
            (abs(ma_penetration_chg) < 0.01 ? "stable" :
             ma_penetration_chg > 0 ? @sprintf("+%.1f pp vs prior period", ma_penetration_chg*100) :
             @sprintf("%.1f pp vs prior period", ma_penetration_chg*100)) *
            ". MA plans pay at 85–90% of FFS; every 1 pp shift from FFS to MA reduces " *
            "revenue approximately " * _fmt_usd(d.net_patient_revenue * 0.001 * 0.12) *
            " annually."),
    ])
end

function _section_revenue_cycle(d::BoardPacketData)
    BoardPacketSection(6, "Revenue Cycle Metrics", [
        (type=:metric_row, items=[
            (label="Days AR Outstanding",    value=@sprintf("%.1f d", d.days_ar_outstanding),
             rag=_rag_str(d.days_ar_outstanding, 45.0, 55.0, :lower)),
            (label="Denial Rate",            value=_fmt_pct(d.denial_rate),
             rag=_rag_str(d.denial_rate, 0.05, 0.10, :lower)),
            (label="Clean Claim Rate",       value=_fmt_pct(d.clean_claim_rate),
             rag=_rag_str(d.clean_claim_rate, 0.95, 0.90)),
            (label="Cash Collection Eff.",   value=_fmt_pct(d.cash_collection_efficiency),
             rag=_rag_str(d.cash_collection_efficiency, 0.95, 0.90)),
            (label="Bad Debt %",             value=_fmt_pct(d.bad_debt_pct),
             rag=_rag_str(d.bad_debt_pct, 0.02, 0.05, :lower)),
        ]),
    ])
end

function _section_expense_staffing(d::BoardPacketData)
    BoardPacketSection(7, "Expense & Staffing", [
        (type=:metric_row, items=[
            (label="Total FTE",                  value=@sprintf("%.0f", d.total_fte)),
            (label="FTE per AOB",                value=@sprintf("%.1f", d.fte_per_aob),
             rag=_rag_str(d.fte_per_aob, 6.2, 8.4, :lower)),
            (label="Salary / Revenue",           value=_fmt_pct(d.salary_to_revenue),
             rag=_rag_str(d.salary_to_revenue, 0.50, 0.58, :lower)),
            (label="Contract Labor %",           value=_fmt_pct(d.contract_labor_pct),
             rag=_rag_str(d.contract_labor_pct, 0.03, 0.07, :lower)),
            (label="Supply Expense / Discharge", value=_fmt_usd(d.supply_expense_per_discharge)),
        ]),
    ])
end

function _section_capital(d::BoardPacketData)
    BoardPacketSection(8, "Capital & Balance Sheet", [
        (type=:metric_row, items=[
            (label="Net Patient Revenue",   value=_fmt_usd(d.net_patient_revenue)),
            (label="Total Assets",          value=_fmt_usd(d.total_assets)),
            (label="Long-Term Debt",        value=_fmt_usd(d.long_term_debt)),
            (label="Net Assets",            value=_fmt_usd(d.net_assets)),
            (label="CapEx YTD",             value=_fmt_usd(d.capital_expenditures_ytd)),
            (label="Depreciation Expense",  value=_fmt_usd(d.depreciation_expense)),
            (label="Avg Age of Plant",      value=@sprintf("%.1f yrs", d.avg_age_of_plant)),
        ]),
    ])
end

function _section_quality(d::BoardPacketData)
    BoardPacketSection(9, "Quality & Regulatory Compliance", [
        (type=:metric_row, items=[
            (label="HACRP HAC Score",       value=@sprintf("%.2f", d.hac_score),
             rag=_rag_str(d.hac_score, 1.0, 1.25, :lower)),
            (label="Readmission Rate",      value=_fmt_pct(d.readmission_rate),
             rag=_rag_str(d.readmission_rate, 0.10, 0.14, :lower)),
            (label="VBP TPS",               value=@sprintf("%.0f pts", d.vbp_tps),
             rag=_rag_str(d.vbp_tps, 65.0, 50.0)),
            (label="HCAHPS (Top Box %)",   value=_fmt_pct(d.patient_satisfaction_score),
             rag=_rag_str(d.patient_satisfaction_score, 0.72, 0.65)),
        ]),
    ])
end

function _section_community(d::BoardPacketData)
    BoardPacketSection(10, "Community Benefit & SDOH", [
        (type=:metric_row, items=[
            (label="Charity Care %",         value=_fmt_pct(d.charity_care_pct)),
            (label="Community Benefit Total",value=_fmt_usd(d.community_benefit_total)),
            (label="SDOH Risk Score",        value=@sprintf("%.2f", d.sdoh_risk_score)),
        ]),
    ])
end

function _section_strategic(d::BoardPacketData)
    subs = NamedTuple[]
    if !isempty(d.strategic_initiatives)
        push!(subs, (type=:bullet_list, title="Strategic Initiatives",
                     items=d.strategic_initiatives))
    end
    if !isempty(d.key_risks)
        push!(subs, (type=:bullet_list, title="Key Risks",
                     items=d.key_risks))
    end
    if !isempty(d.management_responses)
        push!(subs, (type=:bullet_list, title="Management Responses",
                     items=d.management_responses))
    end
    if isempty(subs)
        push!(subs, (type=:narrative, text="No strategic items to report for this period."))
    end
    BoardPacketSection(11, "Strategic Initiatives & Risks", subs)
end

function _section_appendix(d::BoardPacketData)
    BoardPacketSection(12, "Appendix: Flex Monitoring Peer Benchmarks", [
        (type=:narrative, text="""
        Peer benchmark data from the Flex Monitoring Team CAH Financial Indicators
        Report (2022 fiscal year data, published 2024). Percentile ranges shown for
        $(d.hospital_name) vs all CAH respondents.

        Operating Margin: P$(round(Int, d.peer_operating_margin_pct)) vs national CAH peers.
        Days Cash on Hand: P$(round(Int, d.peer_dcoh_pct)).
        Debt-to-Capitalization: P$(round(Int, d.peer_debt_to_cap_pct)).
        """),
    ])
end

# ─────────────────────────────────────────────────────────────────────────────
# Markdown renderer (universal fallback)
# ─────────────────────────────────────────────────────────────────────────────

"""
    render_to_markdown(doc::BoardPacketDocument) -> String

Render the board packet as GitHub-Flavored Markdown. Useful when Typst is
not available or for web-based delivery.
"""
function render_to_markdown(doc::BoardPacketDocument)::String
    io = IOBuffer()

    println(io, "# $(doc.hospital_name)")
    println(io, "**Board of Directors Meeting — $(Dates.format(doc.board_meeting_date, "MMMM d, yyyy"))**  ")
    println(io, "**Period:** $(doc.fiscal_period) | **Prepared by:** $(doc.prepared_by)")
    println(io, "\n---\n")

    for section in doc.sections
        section.number == 1 && continue   # skip cover in markdown
        println(io, "## $(section.number). $(section.title)\n")
        for sub in section.subsections
            if sub.type == :narrative
                println(io, sub.text, "\n")
            elseif sub.type == :metric_row
                println(io, "| Metric | Value | Status |")
                println(io, "|:---|---:|:---:|")
                for item in sub.items
                    rag_icon = get(item, :rag, "—") == "green"  ? "🟢" :
                               get(item, :rag, "—") == "amber"  ? "🟡" :
                               get(item, :rag, "—") == "red"    ? "🔴" : "—"
                    println(io, "| $(item.label) | $(item.value) | $(rag_icon) |")
                end
                println(io)
            elseif sub.type == :table
                haskey(sub, :title) && println(io, "**$(sub.title)**\n")
                println(io, "| ", join(sub.headers, " | "), " |")
                println(io, "|", join(["---" for _ in sub.headers], "|"), "|")
                for row in sub.rows
                    vals = [string(v) for v in values(row)]
                    println(io, "| ", join(vals, " | "), " |")
                end
                println(io)
            elseif sub.type == :bullet_list
                haskey(sub, :title) && println(io, "**$(sub.title)**\n")
                for item in sub.items
                    println(io, "- $(item)")
                end
                println(io)
            elseif sub.type == :cover
                # Already in header
            end
        end
        println(io, "---\n")
    end

    println(io, "*Generated $(Dates.format(doc.generated_at, "yyyy-mm-dd HH:MM")) by ruralpeds/Hospital-economics*")
    String(take!(io))
end

# ─────────────────────────────────────────────────────────────────────────────
# Typst renderer
# ─────────────────────────────────────────────────────────────────────────────

"""
    render_to_typst(doc::BoardPacketDocument) -> String

Render the board packet as a Typst source file (.typ).
Compile with: `typst compile board_packet.typ board_packet.pdf`
"""
function render_to_typst(doc::BoardPacketDocument)::String
    io = IOBuffer()

    # Typst preamble
    println(io, """
    #set document(title: "$(doc.hospital_name) — Board Packet")
    #set page(paper: "us-letter", margin: (x: 1.25in, y: 1in))
    #set text(font: "Helvetica Neue", size: 10pt)
    #set heading(numbering: none)

    #let rag-cell(status) = {
      let color = if status == "green" { rgb("#22c55e") }
                  else if status == "amber" { rgb("#f59e0b") }
                  else { rgb("#ef4444") }
      box(fill: color, radius: 2pt, inset: 3pt,
          text(fill: white, weight: "bold", size: 8pt, upper(status)))
    }

    #let kpi-row(label, value, rag: none) = {
      table.cell(label)
      table.cell(align: right, value)
      if rag != none { table.cell(rag-cell(rag)) }
    }
    """)

    # Cover page
    println(io, """
    // ── Cover Page ──────────────────────────────────────────────────────
    #align(center)[
      #v(2in)
      #text(size: 28pt, weight: "bold")[$(doc.hospital_name)]
      #v(0.5em)
      #text(size: 16pt)[Board of Directors Meeting]
      #v(0.5em)
      #text(size: 14pt)[$(doc.fiscal_period)]
      #v(0.25em)
      #text(size: 12pt)[$(Dates.format(doc.board_meeting_date, "MMMM d, yyyy"))]
      #v(0.5em)
      #text(size: 10pt, fill: gray)[Prepared by: $(doc.prepared_by)]
    ]
    #pagebreak()
    """)

    # Sections
    for section in doc.sections
        section.number == 1 && continue   # cover handled above
        println(io, "\n// ── Section $(section.number): $(section.title) ──")
        println(io, "= $(section.number). $(section.title)\n")

        for sub in section.subsections
            if sub.type == :narrative
                println(io, sub.text, "\n")
            elseif sub.type == :metric_row
                println(io, "#table(")
                println(io, "  columns: (auto, auto, auto),")
                println(io, "  [*Metric*], [*Value*], [*Status*],")
                for item in sub.items
                    rag = get(item, :rag, nothing)
                    rag_str = isnothing(rag) ? "[]" : "[#rag-cell(\"$(rag)\")]"
                    println(io, "  [$(item.label)], [$(item.value)], $(rag_str),")
                end
                println(io, ")\n")
            elseif sub.type == :table
                haskey(sub, :title) && println(io, "*$(sub.title)*\n")
                n_cols = length(sub.headers)
                println(io, "#table(")
                println(io, "  columns: $(n_cols),")
                println(io, "  " * join(["[*$(h)*]" for h in sub.headers], ", ") * ",")
                for row in sub.rows
                    vals = [string(v) for v in values(row)]
                    println(io, "  " * join(["[$(v)]" for v in vals], ", ") * ",")
                end
                println(io, ")\n")
            elseif sub.type == :bullet_list
                haskey(sub, :title) && println(io, "*$(sub.title)*\n")
                for item in sub.items
                    println(io, "- $(item)")
                end
                println(io)
            end
        end
        println(io, "#pagebreak()")
    end

    println(io, "\n// Generated by ruralpeds/Hospital-economics")
    println(io, "// $(Dates.format(doc.generated_at, "yyyy-mm-dd HH:MM"))")

    String(take!(io))
end

# ─────────────────────────────────────────────────────────────────────────────
# Write + compile
# ─────────────────────────────────────────────────────────────────────────────

"""
    write_typst_and_compile(doc::BoardPacketDocument, output_path::String;
                             typst_binary="typst") -> Bool

Write the Typst source and compile to PDF. Returns `true` on success.

Requires the `typst` binary:
    macOS: `brew install typst`
    Linux: `curl -fsSL https://typst.community/typst-install/install.sh | sh`
    Windows: `winget install Typst.Typst`

Falls back to Markdown output if `typst` is not found.
"""
function write_typst_and_compile(
    doc::BoardPacketDocument,
    output_path::String;
    typst_binary::String = "typst",
)::Bool
    typ_path = replace(output_path, r"\.pdf$" => ".typ")
    md_path  = replace(output_path, r"\.pdf$" => ".md")

    # Always write Markdown as fallback
    md_content = render_to_markdown(doc)
    write(md_path, md_content)
    @info "Markdown fallback written: $md_path"

    # Write Typst source
    typ_content = render_to_typst(doc)
    write(typ_path, typ_content)
    @info "Typst source written: $typ_path"

    # Try to compile
    typst_available = !isempty(Sys.which(typst_binary))
    if !typst_available
        @warn "Typst binary not found ('$typst_binary'). PDF not generated." *
              " Install Typst to enable PDF output. Markdown at: $md_path"
        return false
    end

    @info "Compiling PDF with Typst..."
    result = run(ignorestatus(`$(typst_binary) compile $(typ_path) $(output_path)`))
    if result.exitcode == 0
        @info "PDF generated: $output_path"
        return true
    else
        @warn "Typst compilation failed (exit code $(result.exitcode)). Check $typ_path for errors."
        return false
    end
end
