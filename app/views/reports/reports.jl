"""
Reports & Export UI (E18) — template picker, section toggles,
period/facility selection, preview pane, and PDF/XLSX export.
"""

function ui_reports(model)
    app_layout(model, "Reports & Export", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Reports & Export", class="q-mb-none"),
                p("Generate financial, quality, and executive reports with PDF and XLSX export",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Generate Report", icon="description", color="primary",
                    @click(:generate),
                    var":loading"="running"),
            ]),
        ]),

        # Error banner
        template(var"v-if"="errors && errors.length > 0", [
            card(class="q-mb-md bg-red-1 text-red-9", [
                card_section([
                    p("Errors:", class="text-weight-bold q-mb-xs"),
                    template(var"v-for"="(err, idx) in errors", var":key"="idx", [
                        p(class="q-mb-none", ["{{ err }}"]),
                    ]),
                ]),
            ]),
        ]),

        # Configuration
        form_grid([
            (name=:report_title,   type=:text,   label="Report Title"),
            (name=:template_type,  type=:select, label="Report Template",
             options=[
                 Dict("value"=>"financial",   "label"=>"Financial Report"),
                 Dict("value"=>"quality",     "label"=>"Quality Report"),
                 Dict("value"=>"executive",   "label"=>"Executive Summary"),
                 Dict("value"=>"regulatory",  "label"=>"Regulatory Filing"),
             ]),
            (name=:period_from,    type=:date,   label="Period From"),
            (name=:period_to,      type=:date,   label="Period To"),
        ], title="Report Settings"),

        # Section toggles
        card(class="q-mb-md", [
            card_section([
                h6("Report Sections", class="q-mb-sm"),
                p("Executive Summary, Financial Statements, Variance Analysis, Peer Comparison",
                  class="text-caption text-grey-7"),
            ]),
        ]),

        # Preview pane
        card(class="q-mb-md", [
            card_section([
                h6("Report Preview", class="q-mb-sm"),
                template(var"v-if"="preview_html", [
                    html("div", var"v-html"="preview_html", class="report-preview"),
                ]),
                template(var"v-else"="", [
                    p("Click 'Generate Report' to preview the report content here.",
                      class="text-grey-6 text-italic"),
                ]),
            ]),
        ]),

        # Export actions
        row(class="q-mb-md q-gutter-sm", [
            cell(class="col-auto", [
                btn("Export PDF", icon="picture_as_pdf", color="negative",
                    @click(:export_pdf), outline=true,
                    var":disable"="!generated_report_id"),
            ]),
            cell(class="col-auto", [
                btn("Export XLSX", icon="table_view", color="positive",
                    @click(:export_xlsx), outline=true,
                    var":disable"="!generated_report_id"),
            ]),
        ]),
    ])
end
