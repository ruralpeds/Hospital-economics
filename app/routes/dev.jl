# ═══════════════════════════════════════════════════════════════════════════
# Dev-only routes — Component Library showcase
# Disabled in production (GENIE_ENV == "prod")
# ═══════════════════════════════════════════════════════════════════════════

if get(ENV, "GENIE_ENV", "dev") != "prod"
    route("/dev/components") do
        model = dev_components_model |> init
        page(model, ui_dev_components) |> html
    end

    # Individual component demo sub-routes (alias to same page with hash)
    for comp in ["form_grid", "result_table", "plot_panel",
                 "export_bar", "cohort_picker", "scenario_picker",
                 "audit_log_viewer"]
        local _comp = comp
        route("/dev/components/$(_comp)") do
            redirect("/dev/components#sec-$(replace(_comp, "_" => ""))")
        end
    end
end
