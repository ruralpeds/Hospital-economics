"""
    reporting_framework.jl — Centralized Reporting & Export Framework (T-030)

Provides a unified API for generating structured reports from any analysis
module in the platform. Replaces ad-hoc printing scattered across modules.

Design principles:
- All reports are built as `Report` structs (data only, no I/O).
- `export_report(report, format)` converts to the desired output format.
- Supported formats: `:text`, `:markdown`, `:csv`, `:json`.
- `ReportSection` → composable sections with headings, tables, key-value pairs, and prose.
- Thread-safe: no global mutable state.
"""

using Dates
using Printf
using JSON3

# ─────────────────────────────────────────────────────────────────────────────
# Core data structures
# ─────────────────────────────────────────────────────────────────────────────

"""
    ReportCell

A single cell value in a report table. Carries the raw value plus optional
display formatting.
"""
struct ReportCell
    value::Any
    format::Symbol   # :auto | :currency | :percent | :integer | :float | :string | :date
    align::Symbol    # :left | :right | :center
end
ReportCell(v) = ReportCell(v, :auto, :right)
ReportCell(v, fmt::Symbol) = ReportCell(v, fmt, :right)

"""
    ReportTable

A titled, column-labelled table of `ReportCell` values.

# Fields
- `title::String`
- `headers::Vector{String}`
- `rows::Vector{Vector{ReportCell}}`
- `footer::String`: Optional footer note (e.g. "Source: CMS HCRIS FY2025").
"""
struct ReportTable
    title::String
    headers::Vector{String}
    rows::Vector{Vector{ReportCell}}
    footer::String
end
ReportTable(title, headers, rows) = ReportTable(title, headers, rows, "")

"""
    ReportKV

A key-value metric line (e.g. "Operating Margin: 3.2%").
"""
struct ReportKV
    label::String
    value::Any
    format::Symbol
    highlight::Bool   # flag important metrics for bold rendering
end
ReportKV(l, v) = ReportKV(l, v, :auto, false)
ReportKV(l, v, f) = ReportKV(l, v, f, false)

"""
    ReportSection

A named section of a report. Contains an ordered mix of tables, KV metrics,
and narrative prose.

# Fields
- `heading::String`
- `level::Int`: Heading level (1 = top, 2 = sub, 3 = sub-sub).
- `prose::Vector{String}`: Paragraphs of narrative text.
- `metrics::Vector{ReportKV}`
- `tables::Vector{ReportTable}`
"""
struct ReportSection
    heading::String
    level::Int
    prose::Vector{String}
    metrics::Vector{ReportKV}
    tables::Vector{ReportTable}
end

ReportSection(heading::String; level::Int=2, prose=String[], metrics=ReportKV[], tables=ReportTable[]) =
    ReportSection(heading, level, prose, metrics, tables)

"""
    Report

Top-level report container.

# Fields
- `title::String`
- `subtitle::String`
- `author::String`
- `generated_at::DateTime`
- `report_type::Symbol`: E.g. `:financial_summary`, `:mc_results`, `:reh_conversion`, `:cohort`.
- `sections::Vector{ReportSection}`
- `metadata::Dict{String, Any}`: Arbitrary key-value metadata.
"""
struct Report
    title::String
    subtitle::String
    author::String
    generated_at::DateTime
    report_type::Symbol
    sections::Vector{ReportSection}
    metadata::Dict{String, Any}
end

Report(title::String, report_type::Symbol; subtitle="", author="Hospital Economics Platform",
       sections=ReportSection[], metadata=Dict{String,Any}()) =
    Report(title, subtitle, author, now(), report_type, sections, metadata)

# ─────────────────────────────────────────────────────────────────────────────
# Value formatting helpers
# ─────────────────────────────────────────────────────────────────────────────

function _fmt_value(v, fmt::Symbol)::String
    if fmt == :currency
        v isa Number ? @sprintf("\$%,.0f", v) : string(v)
    elseif fmt == :percent
        v isa Number ? @sprintf("%.1f%%", v * 100) : string(v)
    elseif fmt == :integer
        v isa Number ? @sprintf("%d", round(Int, v)) : string(v)
    elseif fmt == :float
        v isa Number ? @sprintf("%.2f", v) : string(v)
    elseif fmt == :date
        string(v)
    elseif fmt == :auto
        if v isa Float64
            abs(v) >= 1_000 ? @sprintf("\$%,.0f", v) :
            abs(v) <= 1.0   ? @sprintf("%.1f%%", v * 100) :
                               @sprintf("%.2f", v)
        elseif v isa Int
            @sprintf("%d", v)
        else
            string(v)
        end
    else
        string(v)
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Export: plain text
# ─────────────────────────────────────────────────────────────────────────────

function _export_text(r::Report)::String
    io = IOBuffer()
    println(io, "=" ^ 72)
    println(io, r.title)
    isempty(r.subtitle) || println(io, r.subtitle)
    println(io, "Generated: ", Dates.format(r.generated_at, "yyyy-mm-dd HH:MM"))
    println(io, "=" ^ 72)
    println(io)

    for section in r.sections
        prefix = section.level == 1 ? "═" : section.level == 2 ? "─" : " "
        println(io, prefix ^ 60)
        println(io, uppercase(section.heading))
        println(io)

        for p in section.prose
            println(io, p)
            println(io)
        end

        for kv in section.metrics
            val_str = _fmt_value(kv.value, kv.format)
            star = kv.highlight ? " *" : ""
            println(io, "  $(rpad(kv.label, 38)) $(lpad(val_str, 18))$star")
        end
        isempty(section.metrics) || println(io)

        for tbl in section.tables
            println(io, "  [$(tbl.title)]")
            # Header row
            col_widths = [max(length(h), 10) for h in tbl.headers]
            for row in tbl.rows
                for (j, cell) in enumerate(row)
                    col_widths[j] = max(col_widths[j], length(_fmt_value(cell.value, cell.format)))
                end
            end
            header_line = join([lpad(h, col_widths[i]) for (i, h) in enumerate(tbl.headers)], "  ")
            println(io, "  ", header_line)
            println(io, "  ", "-" ^ length(header_line))
            for row in tbl.rows
                cells = [lpad(_fmt_value(c.value, c.format), col_widths[j]) for (j, c) in enumerate(row)]
                println(io, "  ", join(cells, "  "))
            end
            isempty(tbl.footer) || println(io, "  Note: ", tbl.footer)
            println(io)
        end
    end

    String(take!(io))
end

# ─────────────────────────────────────────────────────────────────────────────
# Export: Markdown
# ─────────────────────────────────────────────────────────────────────────────

function _export_markdown(r::Report)::String
    io = IOBuffer()
    println(io, "# ", r.title)
    isempty(r.subtitle) || println(io, "*", r.subtitle, "*")
    println(io, "**Generated:** ", Dates.format(r.generated_at, "yyyy-mm-dd HH:MM"), "\n")

    for section in r.sections
        hd = "#" ^ (section.level + 1)
        println(io, "$hd ", section.heading, "\n")
        for p in section.prose; println(io, p, "\n"); end

        if !isempty(section.metrics)
            println(io, "| Metric | Value |")
            println(io, "|:---|---:|")
            for kv in section.metrics
                val_str = _fmt_value(kv.value, kv.format)
                bold = kv.highlight ? "**" : ""
                println(io, "| $(kv.label) | $bold$val_str$bold |")
            end
            println(io)
        end

        for tbl in section.tables
            println(io, "**$(tbl.title)**\n")
            println(io, "| ", join(tbl.headers, " | "), " |")
            println(io, "|", join(["---" for _ in tbl.headers], "|"), "|")
            for row in tbl.rows
                cells = [_fmt_value(c.value, c.format) for c in row]
                println(io, "| ", join(cells, " | "), " |")
            end
            isempty(tbl.footer) || println(io, "*", tbl.footer, "*")
            println(io)
        end
    end

    String(take!(io))
end

# ─────────────────────────────────────────────────────────────────────────────
# Export: CSV (flattens first table per section)
# ─────────────────────────────────────────────────────────────────────────────

function _export_csv(r::Report)::String
    io = IOBuffer()
    println(io, "Report,\"$(r.title)\"")
    println(io, "Generated,\"$(r.generated_at)\"")
    println(io)
    for section in r.sections
        for tbl in section.tables
            println(io, "\"$(section.heading) — $(tbl.title)\"")
            println(io, join(["\"$(h)\"" for h in tbl.headers], ","))
            for row in tbl.rows
                println(io, join(["\"$(_fmt_value(c.value, c.format))\"" for c in row], ","))
            end
            println(io)
        end
        if !isempty(section.metrics) && isempty(section.tables)
            println(io, "\"$(section.heading)\"")
            println(io, "Metric,Value")
            for kv in section.metrics
                println(io, "\"$(kv.label)\",\"$(_fmt_value(kv.value, kv.format))\"")
            end
            println(io)
        end
    end
    String(take!(io))
end

# ─────────────────────────────────────────────────────────────────────────────
# Export: JSON
# ─────────────────────────────────────────────────────────────────────────────

function _export_json(r::Report)::String
    doc = Dict{String, Any}(
        "title"        => r.title,
        "subtitle"     => r.subtitle,
        "generated_at" => string(r.generated_at),
        "report_type"  => string(r.report_type),
        "metadata"     => r.metadata,
        "sections"     => map(r.sections) do sec
            Dict{String, Any}(
                "heading" => sec.heading,
                "level"   => sec.level,
                "prose"   => sec.prose,
                "metrics" => map(kv -> Dict("label" => kv.label,
                                            "value" => _fmt_value(kv.value, kv.format),
                                            "highlight" => kv.highlight), sec.metrics),
                "tables"  => map(tbl -> Dict(
                    "title"   => tbl.title,
                    "headers" => tbl.headers,
                    "rows"    => map(row -> [_fmt_value(c.value, c.format) for c in row], tbl.rows),
                    "footer"  => tbl.footer,
                ), sec.tables),
            )
        end,
    )
    String(JSON3.write(doc))
end

# ─────────────────────────────────────────────────────────────────────────────
# Public export function
# ─────────────────────────────────────────────────────────────────────────────

"""
    export_report(report::Report, format::Symbol = :markdown) -> String

Convert a `Report` to the specified output format.

# Formats
- `:text`     — plain text with ASCII borders
- `:markdown` — GitHub-flavoured Markdown with tables
- `:csv`      — CSV (one table per section, flattened)
- `:json`     — JSON with all sections and metadata

# Example
```julia
md = export_report(my_report, :markdown)
write("report.md", md)

csv_str = export_report(my_report, :csv)
write("report.csv", csv_str)
```
"""
function export_report(report::Report, format::Symbol = :markdown)::String
    if format == :text
        return _export_text(report)
    elseif format == :markdown
        return _export_markdown(report)
    elseif format == :csv
        return _export_csv(report)
    elseif format == :json
        return _export_json(report)
    else
        throw(ArgumentError("Unknown export format: $(repr(format)). " *
                            "Valid: :text, :markdown, :csv, :json"))
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# Convenience builders for common report types
# ─────────────────────────────────────────────────────────────────────────────

"""
    build_financial_summary_report(financials, hospital_name; fiscal_year) -> Report

Build a standard financial summary report from an `AnnualFinancials` struct.
"""
function build_financial_summary_report(
    financials,
    hospital_name::String;
    fiscal_year::Int = year(today()),
)::Report
    ratios_section = ReportSection("Key Financial Ratios";
        level = 2,
        metrics = [
            ReportKV("Operating Margin", financials.net_patient_revenue > 0 ?
                (financials.net_patient_revenue - financials.total_operating_expenses) /
                financials.net_patient_revenue : NaN, :percent, true),
            ReportKV("Net Patient Revenue", financials.net_patient_revenue, :currency),
            ReportKV("Total Operating Expenses", financials.total_operating_expenses, :currency),
            ReportKV("Days Cash on Hand",
                financials.cash_and_investments > 0 && financials.total_operating_expenses > 0 ?
                financials.cash_and_investments / (financials.total_operating_expenses / 365) : NaN,
                :float),
            ReportKV("Current Ratio",
                financials.current_liabilities > 0 ?
                financials.current_assets / financials.current_liabilities : NaN,
                :float, true),
            ReportKV("Debt to Capitalization",
                (financials.long_term_debt + financials.net_assets) > 0 ?
                financials.long_term_debt / (financials.long_term_debt + financials.net_assets) : NaN,
                :percent),
        ],
    )

    Report("Financial Summary — $hospital_name", :financial_summary;
        subtitle  = "Fiscal Year $fiscal_year",
        sections  = [ratios_section],
        metadata  = Dict("hospital" => hospital_name, "fiscal_year" => fiscal_year),
    )
end

"""
    build_mc_results_report(mc_summary, hospital_name) -> Report

Build a Monte Carlo results report from a `MonteCarloSummary` struct.
"""
function build_mc_results_report(mc_summary, hospital_name::String)::Report
    mc_section = ReportSection("Monte Carlo Simulation Results"; level = 2,
        prose = [
            "Stochastic projection of operating margin and closure risk over " *
            "$(mc_summary.projection_years)-year horizon using $(mc_summary.n_iterations) iterations.",
        ],
        metrics = [
            ReportKV("Median Operating Margin", mc_summary.median_operating_margin, :percent, true),
            ReportKV("Mean Operating Margin",   mc_summary.mean_operating_margin,   :percent),
            ReportKV("P5 Operating Margin",     mc_summary.p5_operating_margin,     :percent),
            ReportKV("P95 Operating Margin",    mc_summary.p95_operating_margin,    :percent),
            ReportKV("Probability of Operating Loss", mc_summary.probability_of_loss, :percent, true),
            ReportKV("Mean Closure Risk Year",  mc_summary.mean_closure_risk_year,  :float),
        ],
    )

    Report("Monte Carlo Results — $hospital_name", :mc_results;
        sections = [mc_section],
        metadata = Dict("hospital" => hospital_name,
                        "n_iterations" => mc_summary.n_iterations),
    )
end

"""
    build_reh_conversion_report(analysis::REHConversionAnalysis, hospital_name) -> Report

Build a REH conversion feasibility report.
"""
function build_reh_conversion_report(analysis::REHConversionAnalysis, hospital_name::String)::Report
    summary_section = ReportSection("REH Conversion Feasibility Summary"; level = 2,
        prose = [
            "Analysis of financial viability of converting $hospital_name from " *
            "Critical Access Hospital to Rural Emergency Hospital designation.",
        ],
        metrics = [
            ReportKV("Annual REH Revenue",          analysis.reh_summary.total_revenue,    :currency, true),
            ReportKV("  — Facility Payment",        analysis.reh_summary.facility_payment, :currency),
            ReportKV("  — Outpatient Add-on (5%)", analysis.reh_summary.outpatient_addon,  :currency),
            ReportKV("  — Visit Revenue",           analysis.reh_summary.visit_revenue,    :currency),
            ReportKV("Annual Operating Expenses",   analysis.reh_summary.operating_expenses, :currency),
            ReportKV("Operating Income",            analysis.reh_summary.operating_income, :currency, true),
            ReportKV("Operating Margin",            analysis.reh_summary.operating_margin, :percent, true),
            ReportKV("Conversion Capital Cost",     analysis.conversion_capex,             :currency),
            ReportKV("Simple Payback (years)",      analysis.payback_years,                :float),
            ReportKV("5-Year NPV",                  analysis.five_year_npv,                :currency, true),
            ReportKV("Break-Even ED Visits/Year",   analysis.break_even_ed_visits,         :integer),
            ReportKV("Viability Score (0–100)",     analysis.viability_score,              :float, true),
            ReportKV("Financially Viable",          analysis.is_financially_viable ? "YES" : "NO", :string, true),
        ],
    )

    Report("REH Conversion Analysis — $hospital_name", :reh_conversion;
        sections = [summary_section],
        metadata = Dict("hospital" => hospital_name, "viable" => analysis.is_financially_viable),
    )
end
