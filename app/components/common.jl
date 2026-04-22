"""
Shared UI constants and helper components for the Rural Hospital Economics
Simulator.  Included once from app/app.jl before any view or model file.

Provides:
  - APP_COLORS             — semantic color palette (mirrors CSS custom properties)
  - APP_SPACING            — canonical spacing scale in pixels
  - not_yet_implemented_html — standalone HTML for placeholder concept routes
  - page_header            — hero-header bar (title, subtitle, breadcrumbs)
  - error_banner           — dismissible error/warning strip
  - loading_overlay        — full-page loading spinner
"""

# ---------------------------------------------------------------------------
# Color palette — semantic tokens
# All values must stay in sync with the CSS custom properties in
# app/public/css/app.css (:root block).
# ---------------------------------------------------------------------------
const APP_COLORS = (
    primary   = "#1565c0",   # deep blue  — brand / interactive
    secondary = "#0288d1",   # mid blue   — secondary actions
    success   = "#2e7d32",   # green      — positive outcomes
    warning   = "#f57f17",   # amber      — caution / thresholds
    danger    = "#c62828",   # red        — errors / critical alerts
    info      = "#01579b",   # navy blue  — informational
    surface   = "#f5f7fa",   # light grey — page background
    muted     = "#607d8b",   # blue-grey  — secondary text / icons
    on_primary = "#ffffff",  # white text on primary background
)

# ---------------------------------------------------------------------------
# Spacing scale — mirrors the Quasar spacing utilities (q-pa-*, q-ma-*)
# Values are in pixels and serve as the authoritative source when CSS
# custom properties are not available (e.g. inline layout calculations).
# ---------------------------------------------------------------------------
const APP_SPACING = (
    xs  = 4,
    sm  = 8,
    md  = 16,
    lg  = 24,
    xl  = 32,
    xxl = 48,
)

# ---------------------------------------------------------------------------
# not_yet_implemented_html — standalone HTML for placeholder concept routes
#
# Returns a complete HTML document string suitable for use with Genie's
# Renderer.Html.html() function.  Used by every concept route until its full
# Stipple model and view are implemented in a later epic.
# Pure Julia — no Genie/Stipple dependencies.
#
# Arguments:
#   tab_title  (String) — human-readable name for the tab
#   subtitle   (String) — short description; omitted if empty
# ---------------------------------------------------------------------------
function not_yet_implemented_html(tab_title::String; subtitle::String = "")
    sub_line = isempty(subtitle) ? "" :
        """<p style="color:var(--color-muted);margin:.25rem 0 0">$(subtitle)</p>"""

    """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$(tab_title) — Rural Hospital Economics</title>
  <link rel="stylesheet" href="/css/app.css">
</head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
             background:var(--color-surface,#f5f7fa);margin:0;padding:2rem;">
  <div class="nyi-placeholder">
    <div style="display:flex;align-items:center;gap:.75rem;margin-bottom:1rem;">
      <span style="font-size:2rem;">🚧</span>
      <div>
        <h1 style="margin:0;font-size:1.5rem;color:var(--color-primary,#1565c0);">
          $(tab_title)
        </h1>
        $(sub_line)
      </div>
    </div>
    <p style="color:var(--color-text,#4a5568);line-height:1.6;">
      This concept tab is <strong>not yet implemented</strong>.
      It is part of the Phase&#160;A foundations (Epic&#160;E1) and will be
      fully built out in a subsequent epic.
    </p>
    <a href="/dashboard"
       style="display:inline-block;margin-top:1rem;padding:.5rem 1.25rem;
              background:var(--color-primary,#1565c0);color:#fff;
              border-radius:var(--radius-sm,6px);text-decoration:none;font-weight:500;">
      ← Back to Dashboard
    </a>
  </div>
</body>
</html>"""
end

# ---------------------------------------------------------------------------
# page_header — hero header bar
#
# Returns a Quasar card-section that displays a page title, subtitle, and
# optional breadcrumb trail.  Integrates with the CSS variable --color-primary.
#
# Arguments:
#   title        (String) — main heading text
#   subtitle     (String) — descriptive sub-heading; may be empty
#   breadcrumbs  (Vector{Pair{String,String}}) — [label => href, …]; empty = omit
# ---------------------------------------------------------------------------
function page_header(title::String, subtitle::String,
                     breadcrumbs::Vector = Pair{String,String}[])
    crumb_nodes = if isempty(breadcrumbs)
        []
    else
        [
            Html.div(class="q-breadcrumbs q-mb-xs text-caption text-muted",
                join(map(b -> """<a href="$(b.second)" class="text-primary">$(b.first)</a>""",
                         breadcrumbs), " / ")),
        ]
    end

    subtitle_node = isempty(subtitle) ? [] :
        [Html.p(subtitle, class="text-subtitle1 text-muted q-mt-xs q-mb-none")]

    Html.div(class="page-header q-pa-md q-mb-md bg-white rounded-borders shadow-1", [
        crumb_nodes...,
        Html.h1(title, class="text-h5 text-primary q-my-none"),
        subtitle_node...,
    ])
end

# ---------------------------------------------------------------------------
# error_banner — dismissible banner for surface-level errors / warnings
#
# Arguments:
#   messages   (Vector{String}) — list of error strings; empty = not rendered
#   severity   (Symbol)         — :error | :warning | :info  (default :error)
# ---------------------------------------------------------------------------
function error_banner(messages::Vector{String}; severity::Symbol = :error)
    isempty(messages) && return Html.div("")

    color_class = if severity == :warning
        "bg-warning text-dark"
    elseif severity == :info
        "bg-info text-white"
    else
        "bg-negative text-white"
    end

    icon_name = if severity == :warning
        "warning"
    elseif severity == :info
        "info"
    else
        "error"
    end

    Html.div(class="error-banner q-pa-sm q-mb-md $(color_class) rounded-borders",
        role="alert", [
        Html.div(class="row items-center", [
            Html.div(class="col-auto q-mr-sm",
                Html.span(class="material-icons", icon_name)),
            Html.div(class="col", [
                Html.ul(class="q-ma-none q-pl-md", [
                    Html.li(msg) for msg in messages
                ]),
            ]),
        ]),
    ])
end

# Convenience overload for a single message
error_banner(message::String; severity::Symbol = :error) =
    error_banner([message]; severity = severity)

# ---------------------------------------------------------------------------
# loading_overlay — full-page spinner shown while async work is in progress
#
# Arguments:
#   visible_binding  (String) — Vue/Stipple reactive variable name (string),
#                               e.g. "is_loading".  The overlay is shown when
#                               the variable is true.
# ---------------------------------------------------------------------------
function loading_overlay(visible_binding::String = "is_loading")
    Html.div(
        class="loading-overlay fixed-full flex flex-center bg-white",
        style="z-index:9999; opacity:0.85;",
        var"v-if"=visible_binding,
        [
            Html.div(class="text-center", [
                Html.div(class="q-spinner q-spinner-dots text-primary",
                    style="font-size:3rem;"),
                Html.p("Loading…", class="text-subtitle2 q-mt-sm text-muted"),
            ]),
        ]
    )
end
