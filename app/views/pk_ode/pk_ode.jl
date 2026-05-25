"""
Pharmacokinetic ODE Simulation UI — two-compartment PK model.
"""

function ui_pk_ode(model)
    app_layout(model, "PK ODE Simulation", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Pharmacokinetic ODE Simulation", class="q-mb-none"),
                p("Two-compartment PK model with oral absorption (Forward Euler solver)",
                  class="text-grey-7"),
            ]),
            cell(class="col-auto", [
                btn("Simulate", icon="science", color="primary", @click(:recalculate)),
            ]),
        ]),

        # ── KPI Cards ──────────────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Cmax", class="text-overline q-mb-none"),
                    h4("{{ peak_concentration.toFixed(2) }} mg/L", class="q-mb-none text-primary"),
                    p("Peak Concentration", class="text-caption text-grey-7"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("Tmax", class="text-overline q-mb-none"),
                    h4("{{ time_to_peak.toFixed(1) }} hr", class="q-mb-none text-green"),
                    p("Time to Peak", class="text-caption text-grey-7"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("T½", class="text-overline q-mb-none"),
                    h4("{{ terminal_half_life.toFixed(1) }} hr", class="q-mb-none text-orange"),
                    p("Terminal Half-Life", class="text-caption text-grey-7"),
                ])])
            ]),
            cell(class="col-md-3 col-sm-6 col-xs-12", [
                card([card_section(class="text-center", [
                    p("AUC", class="text-overline q-mb-none"),
                    h4("{{ auc.toFixed(1) }}", class="q-mb-none text-red"),
                    p("mg*hr/L", class="text-caption text-grey-7"),
                ])])
            ]),
        ]),

        # ── PK Parameter Inputs ────────────────────────────────────────
        row(class="q-mb-lg q-gutter-md", [
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Drug Parameters", class="q-mb-md"),
                    textfield(:dose, label="Dose (mg)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    slider(:bioavailability, label=true,
                           var":label-value"="'Bioavailability: ' + (bioavailability * 100).toFixed(0) + '%'",
                           var":min"="0.0", var":max"="1.0", var":step"="0.05", class="q-mb-sm"),
                    textfield(:ka, label="Absorption Rate Constant ka (1/hr)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    p("Set ka = 0 for IV bolus administration", class="text-caption text-grey-7"),
                ])])
            ]),
            cell(class="col-md-6 col-xs-12", [
                card([card_section([
                    h6("Compartment Parameters", class="q-mb-md"),
                    textfield(:cl_central, label="Central Clearance CL (L/hr)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:cl_peripheral, label="Peripheral Clearance Q (L/hr)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:v_central, label="Central Volume V1 (L)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:v_peripheral, label="Peripheral Volume V2 (L)", type="number",
                              filled=true, dense=true, class="q-mb-sm"),
                    textfield(:t_end, label="Simulation Duration (hours)", type="number",
                              filled=true, dense=true),
                ])])
            ]),
        ]),

        # ── Concentration-Time Chart ───────────────────────────────────
        row(class="q-mb-lg", [
            cell(class="col-12", [
                card([card_section([
                    plot(:pk_chart_data, layout=:pk_chart_layout, config="{ responsive: true }")
                ])])
            ]),
        ]),
    ])
end
