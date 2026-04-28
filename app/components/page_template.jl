"""
Standard page template helper.
Wraps any concept tab's content in a consistent layout:
  1. Hero header  (via page_header from common.jl)
  2. Optional upload drawer toggle button
  3. Main content area
  4. Optional export bar footer

Included once from app/app.jl after common.jl.
Note: not_yet_implemented_html is defined in common.jl (pure Julia, no Stipple).
"""

# ---------------------------------------------------------------------------
# page_template — wraps a concept tab's Stipple content nodes
#
# Call this from a concept tab's `ui_*` function instead of building the
# header/export-bar boilerplate by hand.
#
# Arguments:
#   content         — Vector of Stipple/Quasar nodes (the tab's main UI)
#   title           — page title string
#   subtitle        — short descriptive subtitle (may be empty)
#   breadcrumbs     — Vector of Pair{String,String} for breadcrumb trail
#   show_upload     — whether to show the upload drawer toggle button
#   show_export     — whether to show the export bar footer
#   loading_var     — name of the reactive Bool controlling the loading overlay
# ---------------------------------------------------------------------------
function page_template(
    content::Vector;
    title::String        = "",
    subtitle::String     = "",
    breadcrumbs::Vector  = Pair{String,String}[],
    show_upload::Bool    = false,
    show_export::Bool    = false,
    loading_var::String  = "is_loading",
)
    upload_btn = show_upload ? [
        Html.div(class="q-mb-md", [
            btn("Upload Data",
                icon  = "upload_file",
                color = "secondary",
                flat  = true,
                @click("show_upload_drawer = !show_upload_drawer")),
        ]),
    ] : []

    export_bar = show_export ? [
        Html.div(class="q-mt-lg q-pt-md",
            style="border-top:1px solid var(--color-surface);", [
            btn("Export CSV",  icon="download",      flat=true, color="primary"),
            btn("Export XLSX", icon="table_view",    flat=true, color="primary"),
            btn("Export JSON", icon="data_object",   flat=true, color="primary"),
            btn("Export PDF",  icon="picture_as_pdf",flat=true, color="primary"),
        ]),
    ] : []

    [
        loading_overlay(loading_var),
        page_header(title, subtitle, breadcrumbs),
        upload_btn...,
        Html.div(class="page-content", content),
        export_bar...,
    ]
end
