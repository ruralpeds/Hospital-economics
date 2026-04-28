# Shared Component Library (`app/components/`)

This directory contains reusable UI building blocks shared across all concept
tabs in the Rural Hospital Economics Simulator.

## Files

| File | Purpose |
|------|---------|
| `common.jl` | Color palette constants, spacing helpers, `page_header`, `error_banner`, `loading_overlay` |
| `page_template.jl` | `page_template(content; …)` — wraps any tab content in a standard hero-header + content-area + export-bar layout |

## Usage

Both files are `include`d once from `app/app.jl` before any view files.
They do **not** define a Julia module — they inject helpers into the
`HospitalEconomicsApp` namespace so every view can call them directly.

```julia
# In any view file
ui_my_tab(model) = [
    page_header("My Tab", "Subtitle text", []),
    # … tab-specific content …
    error_banner(model.errors),
]
```

## Color Palette

All colors are defined as CSS custom properties in `app/public/css/app.css`
and mirrored as Julia constants in `APP_COLORS` (from `common.jl`).
**Never hard-code hex values in Julia view files** — always reference the
CSS variable or the `APP_COLORS` constant.

## Coding Standards

See `docs/WEB_UI_BUILD_PLAN.md §7` for full coding standards.
Key points:
- Every new `@in`/`@out` field must have a type and a default value.
- `@onchange` handlers must be wrapped in `try/catch` with a `@out errors::Vector{String}`.
- PHI must never be logged; uploads must be de-identified before `@out` exposure.
