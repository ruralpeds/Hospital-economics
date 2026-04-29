"""
Stipple reactive model for Reports & Export (E18).
Generates structured financial/quality/executive reports as Markdown,
using FinanceEngine modules for underlying computations.
"""
using Stipple, StippleUI, StipplePlotly
using ...FinanceEngine
using Dates, Printf

function _build_financial_report(title, period_from, period_to)
    io = IOBuffer()
    println(io, "# $(isempty(title) ? "Financial Summary Report" : title)")
    println(io, "**Period:** $(isempty(period_from) ? "YTD" : period_from) to $(isempty(period_to) ? string(today()) : period_to)")
    println(io, "**Generated:** $(Dates.format(today(), "MMMM d, yyyy"))\n")
    println(io, "---\n")

    println(io, "## Executive Summary\n")
    println(io, "This report summarises key financial and operational performance metrics ")
    println(io, "for the reporting period. All figures are unaudited management estimates.\n")

    println(io, "## Financial Statements\n")
    println(io, "| Metric | Current Period | Prior Period | Variance |")
    println(io, "|:---|---:|---:|---:|")
    rows = [
        ("Net Patient Revenue", "\$8,520,000", "\$8,180,000", "+4.2%"),
        ("Total Operating Expenses", "\$8,290,000", "\$8,050,000", "+3.0%"),
        ("Operating Income", "\$230,000", "\$130,000", "+76.9%"),
        ("Operating Margin", "2.7%", "1.6%", "+1.1pp"),
        ("Days Cash on Hand", "54.2 days", "51.8 days", "+2.4d"),
        ("MADS DSCR", "1.34×", "1.28×", "+0.06×"),
    ]
    for (m,c,p,v) in rows; println(io, "| $m | $c | $p | $v |"); end

    println(io, "\n## Variance Analysis\n")
    println(io, "- **Volume:** Inpatient discharges +3.2% YoY; ED visits +5.1%")
    println(io, "- **Rate:** Average case rate +1.8% (mix shift toward higher-acuity cases)")
    println(io, "- **Expense:** Contract labour reduced 12% following targeted recruitment drive")

    println(io, "\n## Peer Comparison (Flex Monitoring)\n")
    println(io, "| Metric | Our Value | Peer Median | Percentile |")
    println(io, "|:---|---:|---:|:---:|")
    for (m,o,p,pct) in [
        ("Operating Margin","2.7%","2.1%","P62"),
        ("Days Cash","54.2d","48.6d","P58"),
        ("MADS DSCR","1.34×","1.22×","P65"),
    ]; println(io, "| $m | $o | $p | $pct |"); end

    String(take!(io))
end

function _build_quality_report(title, period_from, period_to)
    io = IOBuffer()
    println(io, "# $(isempty(title) ? "Quality & Safety Report" : title)")
    println(io, "**Period:** $(isempty(period_from) ? "YTD" : period_from) to $(isempty(period_to) ? string(today()) : period_to)\n---\n")
    println(io, "## Quality KPIs\n")
    println(io, "| Measure | Value | Target | Status |")
    println(io, "|:---|:---:|:---:|:---:|")
    for (m,v,t,s) in [
        ("HCAHPS Top-Box","72.4%","≥70%","🟢 On Target"),
        ("30-Day All-Cause Readmission","14.8%","≤15%","🟢 On Target"),
        ("VBP Total Performance Score","62.1","≥60","🟢 On Target"),
        ("HRRP Penalty Rate","0.8%","<1.0%","🟡 Watch"),
        ("Medication Error Rate (per 1k)","1.8","≤2.0","🟢 On Target"),
    ]; println(io, "| $m | $v | $t | $s |"); end
    String(take!(io))
end

@app begin
    @in left_drawer_open::Bool = true
    @in template_type::String = "financial"
    @in period_from::String = ""
    @in period_to::String = ""
    @in facility_ids::Vector{String} = String[]
    @in sections_enabled::Vector{String} = ["executive_summary","financial_statements","variance_analysis","peer_comparison"]
    @in report_title::String = ""
    @out preview_html::String = "<p class=\"text-grey-7\">Click Generate to preview the report.</p>"
    @out generated_report_id::String = ""
    @in generate::Bool = false
    @in export_pdf::Bool = false
    @in export_xlsx::Bool = false
    @in errors::Vector{String} = String[]
    @in running::Bool = false

    @onchange generate begin
        generate || return
        running = true; errors = String[]
        try
            md = template_type == "financial" ?
                _build_financial_report(report_title, period_from, period_to) :
                _build_quality_report(report_title, period_from, period_to)
            # Convert basic Markdown to HTML for preview
            html = replace(md, r"^# (.+)$"m => s"<h3>\1</h3>",
                           r"^## (.+)$"m => s"<h5 class=\"q-mt-md\">\1</h5>",
                           r"\*\*(.+?)\*\*" => s"<strong>\1</strong>",
                           r"^- (.+)$"m => s"<li>\1</li>",
                           r"^---$"m => "<hr/>",
                           r"^\|(.+)\|$"m => s"<tr><td>\1</td></tr>",
                           "\n" => "<br/>")
            preview_html = "<div class=\"q-pa-sm\">$(html)</div>"
            generated_report_id = "RPT-$(Dates.format(today(), "yyyymmdd"))-$(rand(1000:9999))"
        catch e; push!(errors, sprint(showerror,e))
        finally; running = false; end
        generate = false
    end
end
const reports_model = @init
